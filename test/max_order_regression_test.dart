import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trading_game/data/repositories/local_trading_repository.dart';
import 'package:trading_game/logic/portfolio_provider.dart';
import 'package:trading_game/logic/trading_fee_service.dart';
import 'package:trading_game/data/mock_data/initial_assets.dart';
import 'package:trading_game/ui/screens/trade_detail_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('maximum quantity covers every fee type, crypto tier and leverage', () {
    for (final asset in InitialAssets.getAssets()) {
      for (final budget in [1.0, 25.0, 150.0, 5000.0, 50000.0]) {
        for (final leverage in {1, asset.maxLeverage}) {
          final amount = TradingFeeService.maximumBuyAmount(
            asset: asset,
            cash: budget,
            leverage: leverage,
          );
          expect(amount.isFinite, isTrue);
          if (amount == 0) continue;
          final cost = TradingFeeService.calculateBuyFee(
            asset: asset,
            amount: amount,
            leverage: leverage,
          ).totalCashRequired;
          expect(cost, lessThanOrEqualTo(budget));
          expect(cost, closeTo(budget, 0.0000001));
        }
      }
    }
    final asset = InitialAssets.getAssets().first;
    for (final cash in [0.0, -1.0, double.nan, double.infinity]) {
      expect(TradingFeeService.maximumBuyAmount(asset: asset, cash: cash), 0);
    }
    for (final price in [0.0, -1.0, double.nan, double.infinity]) {
      expect(
        TradingFeeService.maximumBuyAmount(
          asset: asset.copyWith(currentPrice: price),
          cash: 1000,
        ),
        0,
      );
    }
  });

  group('execution-time percentage orders', () {
    late PortfolioProvider portfolio;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      portfolio = PortfolioProvider(repository: LocalTradingRepository());
      while (portfolio.isLoading) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      portfolio.marketEngine.stop();
      portfolio.newsService.dispose();
      await portfolio.setRealisticOrderDelay(false);
    });
    tearDown(() => portfolio.dispose());

    test('MAX adapts stale quote and cash change and includes fees', () async {
      final asset = portfolio.assets.firstWhere((a) => a.symbol == 'BTC');
      final stale = asset.copyWith();
      final oldAmount = TradingFeeService.maximumBuyAmount(
        asset: stale,
        cash: portfolio.cash,
      );
      await portfolio.executeBuy(asset: asset, amount: 0.01);
      asset.currentPrice *= 1.1;
      final budget = portfolio.cash;
      expect(
        await portfolio.executeBuy(
          asset: stale,
          amount: oldAmount,
          cashFraction: 1,
        ),
        isTrue,
      );
      expect(portfolio.cash, inInclusiveRange(0.0, 0.0000001));
      expect(
        portfolio.transactions.first.totalAmount,
        closeTo(budget, 0.0000001),
      );
      expect(portfolio.transactions.first.price, asset.currentPrice);
    });

    test(
      'percentage spends the current fraction, manual amount remains fixed',
      () async {
        final asset = portfolio.assets.firstWhere((a) => a.symbol == 'BTC');
        final before = portfolio.cash;
        expect(
          await portfolio.executeBuy(
            asset: asset,
            amount: 999999,
            cashFraction: 0.25,
          ),
          isTrue,
        );
        expect(portfolio.cash, closeTo(before * 0.75, 0.0000001));
        final cash = portfolio.cash;
        expect(
          await portfolio.executeBuy(asset: asset, amount: 999999),
          isFalse,
        );
        expect(portfolio.cash, cash);
      },
    );

    test('sell all uses current holding after a partial sale', () async {
      final asset = portfolio.assets.firstWhere((a) => a.symbol == 'BTC');
      await portfolio.executeBuy(asset: asset, amount: 0.1);
      final stale = portfolio.positions.single;
      await portfolio.executeSell(position: stale, sellAmount: 0.025);
      expect(
        await portfolio.executeSell(
          position: stale,
          sellAmount: stale.amount,
          sellFraction: 1,
        ),
        isTrue,
      );
      expect(portfolio.positions, isEmpty);
      expect(portfolio.transactions.first.amount, closeTo(0.075, 1e-12));
    });

    test('sell all includes additions since dialog opened', () async {
      final asset = portfolio.assets.firstWhere((a) => a.symbol == 'BTC');
      await portfolio.executeBuy(asset: asset, amount: 0.1);
      final stale = portfolio.positions.single;
      await portfolio.executeBuy(asset: asset, amount: 0.025);
      expect(
        await portfolio.executeSell(
          position: stale,
          sellAmount: stale.amount,
          sellFraction: 1,
        ),
        isTrue,
      );
      expect(portfolio.positions, isEmpty);
      expect(portfolio.transactions.first.amount, closeTo(0.125, 1e-12));
    });

    test('invalid fractions fail without changing cash or holdings', () async {
      final asset = portfolio.assets.firstWhere((a) => a.symbol == 'BTC');
      await portfolio.executeBuy(asset: asset, amount: 0.1);
      final position = portfolio.positions.single;
      final cash = portfolio.cash;
      for (final fraction in [0.0, -1.0, 1.01, double.nan, double.infinity]) {
        expect(
          await portfolio.executeBuy(
            asset: asset,
            amount: 1,
            cashFraction: fraction,
          ),
          isFalse,
        );
        expect(
          await portfolio.executeSell(
            position: position,
            sellAmount: 0.1,
            sellFraction: fraction,
          ),
          isFalse,
        );
      }
      expect(portfolio.cash, cash);
      expect(portfolio.positions.single.amount, 0.1);
    });

    test(
      'MAX reserves only available cash when realistic routing is enabled',
      () async {
        await portfolio.setRealisticOrderDelay(true);
        final asset = portfolio.assets.firstWhere((a) => a.symbol == 'BTC');
        final budget = portfolio.cash;
        expect(
          await portfolio.executeBuy(
            asset: asset,
            amount: 999,
            cashFraction: 1,
          ),
          isTrue,
        );
        expect(portfolio.cash, inInclusiveRange(0.0, 0.0000001));
        expect(
          portfolio.pendingOrders.single.totalEstimatedCost,
          closeTo(budget, 0.0000001),
        );
      },
    );
  });

  testWidgets('MAX stays affordable including fees after the price moves', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(1100, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    late PortfolioProvider portfolio;
    await tester.runAsync(() async {
      portfolio = PortfolioProvider(repository: LocalTradingRepository());
      while (portfolio.isLoading) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      portfolio.marketEngine.stop();
      portfolio.newsService.dispose();
    });
    addTearDown(portfolio.dispose);
    final asset = portfolio.assets.firstWhere((a) => a.symbol == 'BTC');
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: portfolio,
        child: MaterialApp(home: TradeDetailScreen(asset: asset)),
      ),
    );
    await tester.ensureVisible(find.text('MAX'));
    await tester.tap(find.text('MAX'));
    await tester.pump();
    final orderButton = find.ancestor(
      of: find.textContaining('ORDER PRÜFEN & KAUFEN'),
      matching: find.byType(ElevatedButton),
    );
    expect(tester.widget<ElevatedButton>(orderButton).onPressed, isNotNull);
    asset.currentPrice *= 1.1;
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: portfolio,
        child: MaterialApp(home: TradeDetailScreen(asset: asset)),
      ),
    );
    expect(tester.widget<ElevatedButton>(orderButton).onPressed, isNotNull);
    await tester.pumpWidget(const SizedBox());
  });
}
