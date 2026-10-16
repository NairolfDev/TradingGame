import '../data/models/asset.dart';
import '../data/models/position.dart';

class DividendScheduleItem {
  final String assetSymbol;
  final String assetName;
  final double dividendYieldPercent;
  final double projectedPayout;
  final DateTime nextExDate;

  const DividendScheduleItem({
    required this.assetSymbol,
    required this.assetName,
    required this.dividendYieldPercent,
    required this.projectedPayout,
    required this.nextExDate,
  });
}

class DividendService {
  static double calculateAnnualDividendRunRate(
    List<Position> positions,
    List<Asset> assets,
  ) {
    double total = 0.0;
    for (final pos in positions) {
      if (pos.isShort || pos.isLeveraged) continue;

      final matching = assets.where((a) => a.symbol == pos.symbol);
      if (matching.isEmpty) continue;
      final asset = matching.first;

      if (asset.dividendYield != null && asset.dividendYield! > 0) {
        final positionValue = pos.amount * asset.currentPrice;
        total += positionValue * asset.dividendYield!;
      }
    }
    return total;
  }

  static double calculateMonthlyPassiveIncome(
    List<Position> positions,
    List<Asset> assets,
  ) {
    return calculateAnnualDividendRunRate(positions, assets) / 12.0;
  }

  static List<DividendScheduleItem> getDividendSchedule(
    List<Position> positions,
    List<Asset> assets,
  ) {
    final list = <DividendScheduleItem>[];
    final now = DateTime.now();

    for (int i = 0; i < positions.length; i++) {
      final pos = positions[i];
      if (pos.isShort || pos.isLeveraged) continue;

      final matching = assets.where((a) => a.symbol == pos.symbol);
      if (matching.isEmpty) continue;
      final asset = matching.first;

      if (asset.dividendYield != null && asset.dividendYield! > 0) {
        final positionValue = pos.amount * asset.currentPrice;
        final annualPayout = positionValue * asset.dividendYield!;
        final quarterPayout = annualPayout / 4.0;

        list.add(DividendScheduleItem(
          assetSymbol: asset.symbol,
          assetName: asset.name,
          dividendYieldPercent: asset.dividendYield! * 100,
          projectedPayout: quarterPayout,
          nextExDate: now.add(Duration(days: (i + 1) * 7)),
        ));
      }
    }
    return list;
  }
}
