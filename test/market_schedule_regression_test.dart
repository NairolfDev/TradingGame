import 'package:flutter_test/flutter_test.dart';
import 'package:trading_game/data/models/market_schedule.dart';
import 'package:trading_game/data/mock_data/initial_assets.dart';

void main() {
  test('Friday after closing points to Monday for every weekday market', () {
    final fridayNight = DateTime(2026, 10, 16, 23);
    for (final region in [MarketRegion.viennaEurope, MarketRegion.usWallStreet, MarketRegion.asiaTokyoHongKong]) {
      expect(MarketSchedule(region).getNextOpenTimeString(fridayNight), contains('Montag'));
    }
    expect(const MarketSchedule(MarketRegion.usWallStreet).getNextOpenTimeString(DateTime(2026, 10, 16, 12)), contains('heute'));
  });
  test('Amsterdam stock and euro ETF use European rather than US hours', () {
    for (final symbol in ['ASML.AS', 'VUSA', 'IS3N']) {
      final asset = InitialAssets.getAssets().firstWhere((a) => a.symbol == symbol);
      expect(MarketSchedule.forAsset(asset).region, MarketRegion.viennaEurope);
    }
  });
}
