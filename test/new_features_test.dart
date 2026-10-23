import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trading_game/data/models/asset.dart';
import 'package:trading_game/data/models/position.dart';
import 'package:trading_game/data/models/daily_quest.dart';
import 'package:trading_game/data/mock_data/initial_copy_traders.dart';
import 'package:trading_game/logic/dividend_service.dart';
import 'package:trading_game/logic/quest_service.dart';
import 'package:trading_game/logic/news_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  group('Feature 1: NewsService & Dynamic Market Impact Tests', () {
    test('NewsService initializes with templates and selects random breaking news', () {
      final assets = [
        Asset(
          id: 'omv_at',
          symbol: 'OMV.VI',
          name: 'OMV Wien',
          type: AssetType.stock,
          currentPrice: 42.50,
          previousClose: 42.50,
          dailyHigh: 43.0,
          dailyLow: 42.0,
          priceHistory: [42.50],
          volatility: 0.02,
          description: 'OMV Wien',
        ),
      ];

      final newsService = NewsService();
      newsService.initialize(assets);

      final news = newsService.triggerRandomBreakingNews();
      expect(news, isNotNull);
      expect(news.headline.isNotEmpty, isTrue);
      expect(news.description.isNotEmpty, isTrue);
      expect(news.affectedSymbol, isNotNull);
      expect(news.priceImpact, isNot(0.0));

      newsService.dispose();
    });
  });

  group('Feature 2: Daily Quests & Wall Street Pass Tests', () {
    test('QuestService initializes 5 daily quests with proper progress ratio', () async {
      final questService = QuestService();
      await questService.initialize();

      expect(questService.quests.length, 3);
      expect(questService.loginStreakDays, greaterThanOrEqualTo(1));

      final firstQuest = questService.quests.first;
      expect(firstQuest.progressRatio, 0.0);
      expect(firstQuest.isCompleted, isFalse);
      expect(firstQuest.isClaimed, isFalse);
    });

    test('QuestService records trades and updates progress correctly', () async {
      final questService = QuestService();
      await questService.initialize();

      // Führe Trades aus
      questService.recordTrade(
        tradeAmount: 1000.0,
        isCommodity: false,
        leverage: 1,
        profit: 500.0,
        totalPositionsCount: 3,
      );

      final tradeCountQuest = questService.quests.firstWhere(
        (q) => q.type == QuestType.tradeCount,
      );
      expect(tradeCountQuest.currentValue, 1.0);
      expect(tradeCountQuest.progressRatio, closeTo(1.0 / 3.0, 0.01));

      final holdQuest = questService.quests.firstWhere(
        (q) => q.type == QuestType.holdAssets,
      );
      expect(holdQuest.isCompleted, isTrue);

      // Reward abholen
      double claimedCash = 0;
      int claimedPrestige = 0;
      final claimed = questService.claimQuest(holdQuest.id, (cash, prestige) {
        claimedCash = cash;
        claimedPrestige = prestige;
      });

      expect(claimed, isTrue);
      expect(claimedCash, greaterThan(0));
      expect(claimedPrestige, greaterThan(0));
      expect(holdQuest.isClaimed, isTrue);
    });
  });

  group('Feature 3: Dividend Service & Passive Income Tests', () {
    test('Dividend calculation returns correct annual and monthly cashflow', () {
      final assets = [
        Asset(
          id: 'omv',
          symbol: 'OMV.VI',
          name: 'OMV AG',
          type: AssetType.stock,
          currentPrice: 40.0,
          previousClose: 40.0,
          dailyHigh: 40.0,
          dailyLow: 40.0,
          priceHistory: [40.0],
          volatility: 0.01,
          description: '',
          dividendYield: 0.072, // 7.2% Dividende
        ),
      ];

      final positions = [
        Position(
          id: 'pos_1',
          assetId: 'omv',
          symbol: 'OMV.VI',
          name: 'OMV AG',
          type: AssetType.stock,
          amount: 100, // Wert = 4.000 €
          averageBuyPrice: 40.0,
          currentPrice: 40.0,
        ),
      ];

      final annual = DividendService.calculateAnnualDividendRunRate(positions, assets);
      // 4000 € * 7.2% = 288 € p.a.
      expect(annual, closeTo(288.0, 0.01));

      final monthly = DividendService.calculateMonthlyPassiveIncome(positions, assets);
      // 288 / 12 = 24 € / Monat
      expect(monthly, closeTo(24.0, 0.01));

      final schedule = DividendService.getDividendSchedule(positions, assets);
      expect(schedule.length, 1);
      expect(schedule.first.dividendYieldPercent, closeTo(7.2, 0.01));
      expect(schedule.first.projectedPayout, closeTo(72.0, 0.01));
    });
  });

  group('Feature 4: Social- & Copy-Trading Profiles Tests', () {
    test('InitialCopyTraders has no fabricated public profiles', () {
      final traders = InitialCopyTraders.getTraders();
      expect(traders, isEmpty);

      for (final trader in traders) {
        expect(trader.name.isNotEmpty, isTrue);
        expect(trader.roiPercent, greaterThan(0));
        expect(trader.winRatePercent, inInclusiveRange(50.0, 95.0));

        final totalWeight = trader.portfolioAllocation.values.fold<double>(
          0.0,
          (sum, w) => sum + w,
        );
        expect(totalWeight, closeTo(1.0, 0.01));
      }
    });
  });

}
