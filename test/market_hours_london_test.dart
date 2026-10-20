import 'package:flutter_test/flutter_test.dart';
import 'package:trading_game/data/models/asset.dart';
import 'package:trading_game/data/models/market_schedule.dart';

void main() {
  final wedNoon = DateTime(2026, 10, 21, 12); // Wednesday
  final wedNight = DateTime(2026, 10, 21, 3);
  final friLate = DateTime(2026, 10, 23, 22, 30);
  final sat = DateTime(2026, 10, 24, 12);

  test('London trades 09:00-17:30 MEZ on weekdays', () {
    final lse = MarketSchedule.forSymbol('SHEL.L', AssetType.stock);
    expect(lse.region, MarketRegion.londonLse);
    expect(lse.isMarketOpen(wedNoon), isTrue);
    expect(lse.isMarketOpen(wedNight), isFalse);
    expect(lse.isMarketOpen(sat), isFalse);
  });

  test('gold and commodity CFDs follow futures hours, not Wall Street', () {
    final gold = MarketSchedule.forSymbol('XAU/EUR', AssetType.commodity);
    final cfd = MarketSchedule.forSymbol('XAU-25X', AssetType.cfd);
    for (final s in [gold, cfd]) {
      expect(s.region, MarketRegion.futures24x5);
      expect(s.isMarketOpen(wedNight), isTrue);
      expect(s.isMarketOpen(friLate), isFalse);
      expect(s.isMarketOpen(sat), isFalse);
    }
  });

  test('crypto CFDs trade around the clock, index CFDs on weekdays', () {
    final btc = MarketSchedule.forSymbol('BTC-500X', AssetType.cfd);
    expect(btc.isMarketOpen(sat), isTrue);
    final ndx = MarketSchedule.forSymbol('NDX-30X', AssetType.cfd);
    expect(ndx.isMarketOpen(wedNight), isTrue);
  });
}
