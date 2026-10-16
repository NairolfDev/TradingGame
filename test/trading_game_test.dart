import 'package:flutter_test/flutter_test.dart';
import 'package:trading_game/data/models/asset.dart';
import 'package:trading_game/data/models/position.dart';
import 'package:trading_game/data/models/rank_info.dart';
import 'package:trading_game/data/models/market_schedule.dart';
import 'package:trading_game/data/mock_data/initial_assets.dart';
import 'package:trading_game/data/mock_data/initial_luxury_items.dart';

void main() {
  group('Trading Game Core Tests', () {
    test('Initial assets contain all required asset classes', () {
      final assets = InitialAssets.getAssets();
      expect(assets.any((a) => a.type == AssetType.stock), isTrue);
      expect(assets.any((a) => a.type == AssetType.crypto), isTrue);
      expect(assets.any((a) => a.type == AssetType.etf), isTrue);
      expect(assets.any((a) => a.type == AssetType.cfd), isTrue);
      expect(assets.any((a) => a.type == AssetType.bond), isTrue);
    });

    test('CFDs support high leverage up to 50x', () {
      final assets = InitialAssets.getAssets();
      final cfds = assets.where((a) => a.type == AssetType.cfd).toList();
      expect(cfds.isNotEmpty, isTrue);
      expect(cfds.any((c) => c.maxLeverage >= 50), isTrue);
    });

    test('Position liquidation calculation works for Long and Short', () {
      // 10x Long Position bei 100 €
      final longPos = Position(
        id: 'pos_1',
        assetId: 'cfd_1',
        symbol: 'BTC-50X',
        name: 'Bitcoin CFD',
        type: AssetType.cfd,
        amount: 1,
        averageBuyPrice: 100.0,
        currentPrice: 100.0,
        leverage: 10,
        isShort: false,
        collateral: 10.0,
      );

      // Bei 10x Hebel und 90% Verlustfaktor -> Liquidation bei 100 * (1 - 0.09) = 91.0 €
      expect(longPos.liquidationPrice, closeTo(91.0, 0.1));

      // 10x Short Position bei 100 € -> Liquidation bei 100 * (1 + 0.09) = 109.0 €
      final shortPos = Position(
        id: 'pos_2',
        assetId: 'cfd_2',
        symbol: 'BTC-50X',
        name: 'Bitcoin CFD',
        type: AssetType.cfd,
        amount: 1,
        averageBuyPrice: 100.0,
        currentPrice: 100.0,
        leverage: 10,
        isShort: true,
        collateral: 10.0,
      );

      expect(shortPos.liquidationPrice, closeTo(109.0, 0.1));
    });

    test('Rank progression returns correct titles based on net worth', () {
      // 0 € Start (Schulden = Startguthaben)
      final rank0 = RankInfo.getRankForNetWorth(0);
      expect(rank0.level, equals(1));
      expect(rank0.title, equals('Börsen-Praktikant'));

      // 25.000 € Reingewinn
      final rank25k = RankInfo.getRankForNetWorth(25000);
      expect(rank25k.level, equals(2));
      expect(rank25k.title, equals('Junior Retail Trader'));

      // 50.000 € Reinvermögen (Schuldenfrei)
      final rank50k = RankInfo.getRankForNetWorth(50000);
      expect(rank50k.level, equals(3));
      expect(rank50k.title, equals('Floor Broker'));

      // 200.000 € Vermögen
      final rank200k = RankInfo.getRankForNetWorth(200000);
      expect(rank200k.level, equals(4));
      expect(rank200k.title, equals('Senior Portfolio Manager'));

      // 5.000.000 € Vermögen
      final rank5m = RankInfo.getRankForNetWorth(5000000);
      expect(rank5m.level, equals(7));
      expect(rank5m.title, equals('Finanz-Oligarch'));
    });

    test('Crypto market is 24/7 always open', () {
      final btc = Asset(
        id: 'c1',
        symbol: 'BTC',
        name: 'Bitcoin',
        type: AssetType.crypto,
        currentPrice: 65000,
        previousClose: 64000,
        dailyHigh: 66000,
        dailyLow: 63000,
        priceHistory: [65000],
        volatility: 0.05,
        description: '',
      );

      final schedule = MarketSchedule.forAsset(btc);
      // Zu jedem Zeitpunkt geöffnet (egal ob Sonntag 03:00 Uhr)
      final sundayNight = DateTime(2026, 10, 18, 3, 0);
      expect(schedule.isMarketOpen(sundayNight), isTrue);
    });

    test('Vienna stock exchange is closed on Sunday', () {
      final ebs = Asset(
        id: 's1',
        symbol: 'EBS.VI',
        name: 'Erste Group Bank',
        type: AssetType.stock,
        currentPrice: 48,
        previousClose: 48,
        dailyHigh: 49,
        dailyLow: 47,
        priceHistory: [48],
        volatility: 0.02,
        description: '',
      );

      final schedule = MarketSchedule.forAsset(ebs);
      final sundayAfternoon = DateTime(2026, 10, 18, 14, 0); // Sonntag
      expect(schedule.isMarketOpen(sundayAfternoon), isFalse);

      final mondayOpen = DateTime(2026, 10, 19, 10, 30); // Montag 10:30 Uhr
      expect(schedule.isMarketOpen(mondayOpen), isTrue);
    });

    test('Luxury items catalog contains prestige watches, cars and penthouses', () {
      final items = InitialLuxuryItems.getItems();
      expect(items.length, greaterThanOrEqualTo(10));
      expect(items.any((i) => i.name.contains('Rolex')), isTrue);
      expect(items.any((i) => i.name.contains('Porsche')), isTrue);
      expect(items.any((i) => i.name.contains('Penthouse Wien')), isTrue);
      expect(items.any((i) => i.name.contains('Superyacht')), isTrue);
    });
  });
}
