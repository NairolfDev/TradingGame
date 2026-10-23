import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trading_game/data/mock_data/initial_assets.dart';
import 'package:trading_game/data/models/asset.dart';
import 'package:trading_game/data/models/automation_order.dart';
import 'package:trading_game/data/models/savings_plan.dart';
import 'package:trading_game/data/repositories/local_trading_repository.dart';
import 'package:trading_game/logic/automation_service.dart';
import 'package:trading_game/logic/live_market_data_service.dart';
import 'package:trading_game/logic/news_service.dart';
import 'package:trading_game/logic/portfolio_provider.dart';
import 'package:trading_game/logic/savings_plan_service.dart';
import 'package:trading_game/logic/version_gate.dart';
import 'package:trading_game/ui/widgets/order_book_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('v1.18.0+26 Improvements & New Features', () {
    test(
      'AutomationService and SavingsPlanService isolate state per profileId',
      () async {
        final auto = AutomationService();
        await auto.initialize(profileId: 'user_alice');
        await auto.placeOrder(
          assetId: 'c_btc',
          symbol: 'BTC',
          name: 'Bitcoin',
          orderType: AutomationOrderType.buyLimit,
          targetPrice: 50000,
          amount: 0.5,
        );
        expect(auto.activeOrders, hasLength(1));

        // Switch to Bob: must start clean without Alice's orders
        await auto.initialize(profileId: 'user_bob');
        expect(auto.activeOrders, isEmpty);

        // Switch back to Alice: her order is preserved
        await auto.initialize(profileId: 'user_alice');
        expect(auto.activeOrders, hasLength(1));

        final savings = SavingsPlanService();
        await savings.initialize(profileId: 'user_alice');
        await savings.createPlan(
          assetSymbol: 'BTC',
          assetName: 'Bitcoin',
          amountEur: 250,
          frequency: SavingsPlanFrequency.monthly,
        );
        expect(savings.plans, hasLength(1));

        await savings.initialize(profileId: 'user_bob');
        expect(savings.plans, isEmpty);
      },
    );

    test(
      'Trailing-Stop ratchets target price up on gains and triggers on pullback',
      () async {
        final auto = AutomationService();
        await auto.initialize(profileId: 'trailing_tester');

        final order = await auto.placeOrder(
          assetId: 'c_btc',
          symbol: 'BTC',
          name: 'Bitcoin',
          orderType: AutomationOrderType.trailingStop,
          targetPrice: 95.0,
          amount: 1.0,
          trailingPercent: 5.0,
          initialObservedPrice: 100.0,
        );
        expect(order, isNotNull);
        expect(order!.targetPrice, closeTo(95.0, 0.01));

        final baseAsset = Asset(
          id: 'c_btc',
          symbol: 'BTC',
          name: 'Bitcoin',
          type: AssetType.crypto,
          currentPrice: 120.0,
          previousClose: 100.0,
          dailyHigh: 120.0,
          dailyLow: 100.0,
          priceHistory: [100.0, 120.0],
          volatility: 0.03,
          description: 'BTC',
        );

        bool triggered = false;
        await auto.checkAndExecuteOrders(
          assets: [baseAsset],
          onExecute: (o, a) async {
            triggered = true;
          },
        );
        // Price rose to 120 -> new stop should ratchet up to 114.0 (5% below 120)
        expect(triggered, isFalse);
        expect(order.highestObservedPrice, closeTo(120.0, 0.01));
        expect(order.targetPrice, closeTo(114.0, 0.01));

        // Pullback to 113.5 triggers the trailing stop
        await auto.checkAndExecuteOrders(
          assets: [baseAsset.copyWithPrice(113.5)],
          onExecute: (o, a) async {
            triggered = true;
          },
        );
        expect(triggered, isTrue);
        expect(order.isTriggered, isTrue);
      },
    );

    test(
      'executeBuy attaches direct Stop-Loss and Take-Profit orders and KESt loss pot offsets gains',
      () async {
        final portfolio = PortfolioProvider(
          repository: LocalTradingRepository('tax_tester'),
        );
        while (portfolio.isLoading) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        addTearDown(portfolio.dispose);
        portfolio.marketEngine.stop();
        portfolio.newsService.dispose();
        await portfolio.setRealisticOrderDelay(false);
        await portfolio.setTaxModeEnabled(true);

        final btc = portfolio.assets.firstWhere((a) => a.symbol == 'BTC');
        final entryPrice = btc.currentPrice;

        final ok = await portfolio.executeBuy(
          asset: btc,
          amount: 0.1,
          stopLossPrice: entryPrice * 0.9,
          takeProfitPrice: entryPrice * 1.2,
        );
        expect(ok, isTrue);
        expect(portfolio.activeAutomationOrders.length, 2);

        // Simulate a losing sell first -> populates taxLossCarryforward
        final idx = portfolio.assets.indexWhere((a) => a.symbol == 'BTC');
        portfolio.assets[idx] = btc.copyWithPrice(entryPrice * 0.9);
        final pos1 = portfolio.positions.firstWhere((p) => p.symbol == 'BTC');
        expect(
          await portfolio.executeSell(position: pos1, sellAmount: 0.05),
          isTrue,
        );
        expect(portfolio.taxLossCarryforward, greaterThan(0));
        expect(portfolio.totalTaxPaid, 0.0);

        // Simulate a large winning sell -> offsets loss pot first, then pays 27.5% KESt on remainder
        portfolio.assets[idx] = btc.copyWithPrice(entryPrice * 1.5);
        final pos2 = portfolio.positions.firstWhere((p) => p.symbol == 'BTC');
        expect(
          await portfolio.executeSell(position: pos2, sellAmount: pos2.amount),
          isTrue,
        );
        expect(portfolio.taxLossCarryforward, 0.0);
        expect(portfolio.totalTaxPaid, greaterThan(0.0));
      },
    );

    test('NewsService generates data-driven market reports without altering prices', () {
      final newsService = NewsService();
      final assets = [
        InitialAssets.getAssets().first.copyWith(
          currentPrice: 110.0,
          previousClose: 100.0,
          dailyHigh: 112.0,
          dailyLow: 99.0,
        ),
      ];
      final reports = newsService.buildMarketFeedReports(assets);
      expect(reports, isNotEmpty);
      expect(reports.first.headline, contains('+10.00 %'));
      expect(assets.first.currentPrice, 110.0);
    });

    testWidgets('OrderBookWidget renders live Bid/Ask depth table when data is supplied', (
      tester,
    ) async {
      final asset = InitialAssets.getAssets().firstWhere((a) => a.symbol == 'BTC');
      const sampleBook = OrderBookData(
        bids: [
          OrderBookEntry(price: 64990.0, amount: 0.85),
          OrderBookEntry(price: 64980.0, amount: 1.40),
        ],
        asks: [
          OrderBookEntry(price: 65010.0, amount: 0.65),
          OrderBookEntry(price: 65025.0, amount: 1.20),
        ],
        spread: 20.0,
        spreadPercent: 0.0308,
        source: 'Binance Level-2',
        isLiveLevel2: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OrderBookWidget(asset: asset, initialData: sampleBook),
          ),
        ),
      );
      expect(find.textContaining('Binance Level-2'), findsOneWidget);
      expect(find.textContaining('Spread'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('VersionConfig enforces minBuild 26 as required version', () {
      const config = VersionConfig(minBuild: 26, version: '1.18.0');
      expect(config.blocks(25), isTrue);
      expect(config.blocks(26), isFalse);
    });
  });
}
