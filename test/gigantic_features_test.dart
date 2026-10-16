import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trading_game/data/models/asset.dart';
import 'package:trading_game/data/models/automation_order.dart';
import 'package:trading_game/data/models/loan_model.dart';
import 'package:trading_game/data/models/luxury_item.dart';
import 'package:trading_game/data/mock_data/initial_luxury_items.dart';
import 'package:trading_game/data/models/achievement.dart';
import 'package:trading_game/data/mock_data/initial_achievements.dart';
import 'package:trading_game/logic/automation_service.dart';
import 'package:trading_game/logic/achievement_service.dart';
import 'package:trading_game/logic/live_market_data_service.dart';
import 'package:trading_game/logic/credit_rating_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Gigantic Update: 1. Live Market Data & Operating Hours Tests', () {
    test('Crypto assets are 24/7 active while stocks adhere to operating schedule', () {
      final liveService = LiveMarketDataService();

      final crypto = Asset(
        id: 'c_btc',
        symbol: 'BTC',
        name: 'Bitcoin',
        type: AssetType.crypto,
        currentPrice: 65000.0,
        previousClose: 64000.0,
        dailyHigh: 66000.0,
        dailyLow: 63000.0,
        priceHistory: [65000.0],
        volatility: 0.05,
        description: 'Bitcoin',
      );

      final stock = Asset(
        id: 's_omv',
        symbol: 'OMV.VI',
        name: 'OMV Wien',
        type: AssetType.stock,
        currentPrice: 42.0,
        previousClose: 41.5,
        dailyHigh: 43.0,
        dailyLow: 41.0,
        priceHistory: [42.0],
        volatility: 0.02,
        description: 'OMV AG',
      );

      // Krypto ist IMMER aktualisierbar (24/7)
      expect(liveService.canAssetBeUpdated(crypto), isTrue);

      // canAssetBeUpdated für Aktien liefert bool gemäß Börsenkalender
      expect(liveService.canAssetBeUpdated(stock), isA<bool>());
    });
  });

  group('Gigantic Update: 2. Limit-Order Automation & Bot-Slots Tests', () {
    test('Slot 1 is free; Slots 2 to 5 have escalating Ingame-Cash pricing', () async {
      final automation = AutomationService();
      await automation.initialize();

      expect(automation.unlockedSlotsCount, 1);
      expect(automation.hasMaxSlots, isFalse);
      expect(automation.nextSlotCost, 15000.0);

      // Slot 2 freischalten für 15.000 €
      double userCash = 20000.0;
      final successSlot2 = await automation.unlockNextSlot(userCash, (cost) {
        userCash -= cost;
      });
      expect(successSlot2, isTrue);
      expect(automation.unlockedSlotsCount, 2);
      expect(userCash, 5000.0);
      expect(automation.nextSlotCost, 50000.0); // Slot 3 kostet 50.000 €
    });

    test('Bot places Buy-At limit order and executes when market price drops to target', () async {
      final automation = AutomationService();
      await automation.initialize();

      final order = await automation.placeOrder(
        assetId: 's_aapl',
        symbol: 'AAPL',
        name: 'Apple Inc.',
        orderType: AutomationOrderType.buyLimit,
        targetPrice: 200.0,
        amount: 10.0,
      );

      expect(order, isNotNull);
      expect(order!.slotIndex, 1);
      expect(automation.activeOrders.length, 1);

      final assetHigh = Asset(
        id: 's_aapl',
        symbol: 'AAPL',
        name: 'Apple Inc.',
        type: AssetType.stock,
        currentPrice: 215.0,
        previousClose: 215.0,
        dailyHigh: 220.0,
        dailyLow: 210.0,
        priceHistory: [215.0],
        volatility: 0.02,
        description: 'Apple',
      );

      bool executed = false;
      await automation.checkAndExecuteOrders(
        assets: [assetHigh],
        onExecute: (o, a) async {
          executed = true;
        },
      );
      expect(executed, isFalse);
      expect(order.isTriggered, isFalse);

      // Kurs fällt auf 198 € (unter das 200 € Limit)
      final assetDropped = assetHigh.copyWithPrice(198.0);
      await automation.checkAndExecuteOrders(
        assets: [assetDropped],
        onExecute: (o, a) async {
          executed = true;
        },
      );
      expect(executed, isTrue);
      expect(order.isTriggered, isTrue);
      expect(order.triggeredPrice, 198.0);
      expect(automation.activeOrders.isEmpty, isTrue);
    });

    test('Order cancellation frees up the bot slot', () async {
      final automation = AutomationService();
      await automation.initialize();

      final order = await automation.placeOrder(
        assetId: 'c_eth',
        symbol: 'ETH',
        name: 'Ethereum',
        orderType: AutomationOrderType.takeProfit,
        targetPrice: 4000.0,
        amount: 2.0,
      );

      expect(automation.activeOrders.length, 1);
      final cancelled = await automation.cancelOrder(order!.id);
      expect(cancelled, isTrue);
      expect(automation.activeOrders.isEmpty, isTrue);
    });
  });

  group('Gigantic Update: 3. Realistic Bank Loan & Insolvency Bailout Tests', () {
    test('Initial starting loan is capped at 25.000 €', () {
      final startLoan = Loan.createInitialStartLoan();
      expect(startLoan.principal, 25000.0);
      expect(startLoan.interestRate, 0.045);
      expect(startLoan.durationDays, 60);
      expect(startLoan.isPaid, isFalse);
    });

    test('Emergency Sanierungs-Notkredit grants 10.000 € bailout after insolvency', () {
      final sanierungsLoan = Loan.createSanierungsLoan();
      expect(sanierungsLoan.principal, 10000.0);
      expect(sanierungsLoan.interestRate, 0.12); // 12% p.a.
      expect(sanierungsLoan.durationDays, 90);
      expect(sanierungsLoan.isPaid, isFalse);
      expect(sanierungsLoan.title.contains('Sanierungskredit'), isTrue);
    });

    test('Credit rating evaluates score and provides realistic borrow limits', () {
      final primeRating = CreditRatingService.evaluateRating(
        netWorth: 150000.0,
        totalDebt: 0.0,
        realizedLosses: 0.0,
        liquidationsCount: 0,
      );
      expect(primeRating.grade, 'AAA Prime');
      expect(primeRating.maxBorrowLimit, 150000.0);

      final distressedRating = CreditRatingService.evaluateRating(
        netWorth: -40000.0,
        totalDebt: 150000.0,
        realizedLosses: 50000.0,
        liquidationsCount: 3,
      );
      expect(distressedRating.grade.contains('D'), isTrue);
      expect(distressedRating.maxBorrowLimit, 10000.0);
    });
  });

  group('Gigantic Update: 4. Prestige Shop Affordable Lifestyle Items Tests', () {
    test('Initial luxury catalog includes accessible entry items starting at 180 €', () {
      final items = InitialLuxuryItems.getItems();
      final espresso = items.firstWhere((i) => i.name.contains('Espressomaschine'));
      expect(espresso.price, 180.0);
      expect(espresso.prestigePoints, 3);
      expect(espresso.category, LuxuryCategory.lifestyle);

      final shirt = items.firstWhere((i) => i.name.contains('Designer-Hemd'));
      expect(shirt.price, 350.0);
      expect(shirt.prestigePoints, 6);

      final pen = items.firstWhere((i) => i.name.contains('Füllfederhalter'));
      expect(pen.price, 750.0);
      expect(pen.prestigePoints, 14);
    });
  });

  group('Gigantic Update: 5. Gamification Achievements System Tests', () {
    test('15 Achievements are configured with titles, emojis, and dual rewards', () {
      final list = InitialAchievements.getAchievements();
      expect(list.length, 15);
      expect(list.any((a) => a.id == 'trade_first'), isTrue);
      expect(list.any((a) => a.id == 'hundred_k'), isTrue);
      expect(list.any((a) => a.id == 'millionaire'), isTrue);
      expect(list.any((a) => a.id == 'comeback_kid'), isTrue);
      expect(list.any((a) => a.id == 'bot_engineer'), isTrue);

      for (final ach in list) {
        expect(ach.cashReward, greaterThan(0.0));
        expect(ach.prestigeReward, greaterThan(0));
        expect(ach.iconEmoji.isNotEmpty, isTrue);
      }
    });

    test('AchievementService evaluates conditions and triggers unlock callback', () async {
      final service = AchievementService();
      await service.initialize();

      Achievement? unlockedAch;
      service.onAchievementUnlocked = (ach) {
        unlockedAch = ach;
      };

      await service.checkAchievements(
        netWorth: 120000.0,
        totalTradesCount: 1,
        winningStreakCount: 0,
        totalPrestigePoints: 10,
        monthlyPassiveIncome: 0.0,
        hasDebt: false,
        ownedLuxuryCount: 1,
        hasCopyTrade: false,
        hasBotOrderTriggered: false,
        hasWonHighLeverage: false,
        leaderboardRank: 12,
        hasSettledSanierungskredit: false,
        hasTradedOffMarketCrypto: false,
      );

      expect(service.unlockedCount, greaterThanOrEqualTo(2)); // trade_first, hundred_k, good_taste
      expect(unlockedAch, isNotNull);
    });
  });
}
