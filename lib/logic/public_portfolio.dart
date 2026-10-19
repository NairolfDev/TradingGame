import '../data/models/asset.dart';
import '../data/models/copy_trader.dart';
import '../data/models/position.dart';
import '../data/models/transaction.dart';

/// What others see of a public portfolio: weights by instrument (never
/// amounts or cash), the result and the hit rate.
CopyTrader buildPublicPortfolio({
  required String uid,
  required String name,
  required String title,
  required double netWorth,
  required double roiPercent,
  required List<Position> positions,
  required List<TransactionRecord> transactions,
  int maxHoldings = 8,
}) {
  // Only spot holdings can be copied; leveraged contracts are left out.
  final spot = positions.where((p) => !p.isLeveraged && p.currentValue > 0)
      .toList()
    ..sort((a, b) => b.currentValue.compareTo(a.currentValue));
  final top = spot.take(maxHoldings).toList();
  final sum = top.fold<double>(0, (s, p) => s + p.currentValue);
  final allocation = <String, double>{
    if (sum > 0)
      for (final p in top)
        p.symbol: p.currentValue / sum,
  };

  final sells = transactions.where(
    (t) => t.type == TransactionType.sell && t.realizedPnL != null,
  );
  final wins = sells.where((t) => t.realizedPnL! > 0).length;
  final winRate = sells.isEmpty ? 0.0 : wins / sells.length * 100;

  final total = positions.fold<double>(0, (s, p) => s + p.currentValue);
  final crypto = positions
      .where((p) => p.type == AssetType.crypto)
      .fold<double>(0, (s, p) => s + p.currentValue);
  final risk = positions.any((p) => p.isLeveraged)
      ? 'Aggressiv'
      : (total > 0 && crypto / total > 0.5 ? 'Krypto-Whale' : 'Ausgewogen');

  return CopyTrader(
    id: uid,
    name: name,
    title: title,
    avatarEmoji: '😎',
    netWorth: netWorth,
    roiPercent: roiPercent,
    winRatePercent: winRate,
    bio: '',
    riskStyle: risk,
    portfolioAllocation: allocation,
    followersCount: 0,
  );
}
