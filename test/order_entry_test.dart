import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:trading_game/ui/screens/trade_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trading_game/data/mock_data/initial_assets.dart';
import 'package:trading_game/data/repositories/local_trading_repository.dart';
import 'package:trading_game/logic/portfolio_provider.dart';
import 'package:trading_game/logic/trading_fee_service.dart';
import 'package:trading_game/ui/widgets/order_entry.dart';
import 'package:trading_game/ui/widgets/order_routing_dialog.dart';
import 'package:trading_game/ui/widgets/sell_order_sheet.dart';

void main() {
  testWidgets('EUR budget includes fees; fractions preserve intent; manual Stück clears fraction', (tester) async {
    final asset = InitialAssets.getAssets().first.copyWith(currentPrice: 100);
    double amount = 1;
    double? fraction;
    double? euros;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: StatefulBuilder(
      builder: (context, update) => SingleChildScrollView(child: OrderEntry(
        amount: amount, fraction: fraction,
        eurosForAmount: (value) => TradingFeeService.calculateBuyFee(asset: asset, amount: value).totalCashRequired,
        amountForEuros: (value) => TradingFeeService.maximumBuyAmount(asset: asset, cash: value),
        amountForFraction: (value) => TradingFeeService.maximumBuyAmount(asset: asset, cash: 1000 * value),
        onChanged: (value, selected, budget) => update(() { amount = value; fraction = selected; euros = budget; }),
      )),
    ))));
    await tester.tap(find.text('EUR'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '500,00');
    await tester.pump();
    expect(euros, 500);
    expect(TradingFeeService.calculateBuyFee(asset: asset, amount: amount).totalCashRequired, closeTo(500, 1e-8));
    await tester.tap(find.text('100%'));
    await tester.pump();
    expect(fraction, 1);
    expect(euros, isNull);
    expect(TradingFeeService.calculateBuyFee(asset: asset, amount: amount).totalCashRequired, closeTo(1000, 1e-8));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Stück'));
    await tester.pump();
    expect(fraction, 1);
    await tester.enterText(find.byType(TextField), '2.5');
    await tester.pump();
    expect(amount, 2.5);
    expect(fraction, isNull);
    await tester.enterText(find.byType(TextField), 'NaN');
    expect(amount, 0);
  });

  for (final width in [375.0, 768.0, 1440.0]) {
    testWidgets('order entry wraps at $width with 200% text and keyboard', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 812));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(home: MediaQuery(
        data: MediaQueryData(size: Size(width, 812), textScaler: const TextScaler.linear(2), viewInsets: const EdgeInsets.only(bottom: 300)),
        child: Scaffold(body: SingleChildScrollView(child: Padding(padding: const EdgeInsets.all(20),
          child: OrderEntry(amount: 1, fraction: 1, amountForEuros: (v) => v / 100,
            eurosForAmount: (v) => v * 100, amountForFraction: (v) => v * 10,
            onChanged: (_, _, _) {})))),
      )));
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('100%'));
      await tester.tap(find.text('100%'));
      expect(tester.takeException(), isNull);
    });
  }

  group('execution receipts and sell layout', () {
    late PortfolioProvider portfolio;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      portfolio = PortfolioProvider(repository: LocalTradingRepository());
      while (portfolio.isLoading) { await Future<void>.delayed(const Duration(milliseconds: 10)); }
      portfolio.marketEngine.stop();
      portfolio.newsService.dispose();
      await portfolio.setRealisticOrderDelay(false);
    });
    tearDown(() => portfolio.dispose());

    for (final width in [375.0, 768.0, 1440.0]) {
      testWidgets('trade order section at $width supports 200% text', (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final asset = portfolio.assets.firstWhere((a) => a.symbol == 'BTC');
        await tester.pumpWidget(ChangeNotifierProvider.value(value: portfolio,
          child: MaterialApp(home: MediaQuery(data: MediaQueryData(size: Size(width, 1000),
            textScaler: const TextScaler.linear(2)), child: TradeDetailScreen(asset: asset)))));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.byType(OrderEntry));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.textContaining('Kauf prüfen'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      });
    }

    testWidgets('receipt shows actual executed quantity after 100% repricing, not preview', (tester) async {
      final asset = portfolio.assets.firstWhere((a) => a.symbol == 'BTC');
      await tester.pumpWidget(MaterialApp(home: OrderRoutingDialog(symbol: asset.symbol,
        assetName: asset.name, isBuy: true, amount: 9999, price: 1, provider: portfolio,
        onExecute: () => portfolio.executeBuy(asset: asset, amount: 9999, cashFraction: 1))));
      await tester.runAsync(() async { await Future<void>.delayed(const Duration(milliseconds: 100)); });
      await tester.pumpAndSettle();
      expect(find.text('Kauf ausgeführt'), findsOneWidget);
      expect(find.textContaining('9999'), findsNothing);
      expect(find.textContaining('Abgebucht inkl. Gebühren'), findsOneWidget);
      expect(portfolio.cash, closeTo(0, 1e-7));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('pending receipt clearly distinguishes queued quantity from execution', (tester) async {
      await portfolio.setRealisticOrderDelay(true);
      final asset = portfolio.assets.firstWhere((a) => a.symbol == 'BTC');
      await tester.pumpWidget(MaterialApp(home: OrderRoutingDialog(symbol: asset.symbol,
        assetName: asset.name, isBuy: true, amount: 9999, price: 1, provider: portfolio,
        onExecute: () => portfolio.executeBuy(asset: asset, amount: 9999, cashFraction: 1))));
      await tester.runAsync(() async { await Future<void>.delayed(const Duration(milliseconds: 100)); });
      await tester.pumpAndSettle();
      expect(find.text('Order gespeichert – Ausführung ausstehend'), findsOneWidget);
      expect(find.textContaining('9999'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('sell form is scroll safe at 375px, 200% text, keyboard; 100% sells all', (tester) async {
      final asset = portfolio.assets.firstWhere((a) => a.symbol == 'BTC');
      await portfolio.executeBuy(asset: asset, amount: .01);
      await tester.binding.setSurfaceSize(const Size(375, 812));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(home: MediaQuery(
        data: const MediaQueryData(size: Size(375, 812), textScaler: TextScaler.linear(2), viewInsets: EdgeInsets.only(bottom: 300)),
        child: Scaffold(body: Builder(builder: (context) => TextButton(onPressed: () =>
          SellOrderSheet.show(context: context, position: portfolio.positions.single, provider: portfolio), child: const Text('Verkaufen')))),
      )));
      await tester.tap(find.text('Verkaufen'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('100%'));
      await tester.tap(find.text('100%'));
      await tester.pump();
      await tester.ensureVisible(find.text('Verkauf verbindlich bestätigen'));
      await tester.tap(find.text('Verkauf verbindlich bestätigen'));
      await tester.runAsync(() async { await Future<void>.delayed(const Duration(milliseconds: 100)); });
      await tester.pumpAndSettle();
      expect(find.text('Verkauf ausgeführt'), findsOneWidget);
      expect(portfolio.positions, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
