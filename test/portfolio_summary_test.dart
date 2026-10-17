import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:trading_game/core/utils/currency_formatter.dart';
import 'package:trading_game/data/models/asset.dart';
import 'package:trading_game/data/models/pending_order.dart';
import 'package:trading_game/data/models/position.dart';
import 'package:trading_game/logic/portfolio_provider.dart';
import 'package:trading_game/ui/screens/portfolio_screen.dart';
import 'package:trading_game/ui/widgets/portfolio_summary.dart';
import 'package:trading_game/ui/widgets/position_tile.dart';

class _Portfolio extends ChangeNotifier implements PortfolioProvider {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  bool get isLoading => false;
  @override
  double get cash => 10000;
  @override
  double get netWorth => 30000;
  @override
  double get totalPositionsValue => 20000;
  @override
  double get pendingOrderValue => 8000;
  @override
  double get totalDebt => 9000;
  @override
  double get totalLuxuryValue => 1000;
  @override
  List<Position> get positions => [
    Position(
      id: 'p',
      assetId: 'a',
      symbol: 'TEST',
      name: 'Example Aktie',
      type: AssetType.stock,
      amount: 200,
      averageBuyPrice: 90,
      currentPrice: 100,
    ),
  ];
  @override
  List<PendingOrder> get pendingOrders => [
    for (final buy in [true, false])
      PendingOrder(
        id: '$buy',
        assetId: 'a',
        symbol: 'TEST',
        name: 'Example',
        assetType: AssetType.stock,
        isBuy: buy,
        amount: buy ? 50 : 30,
        estimatedPrice: 100,
        totalEstimatedCost: buy ? 5000 : 3000,
      ),
  ];
}

Widget _app(Widget child, {double scale = 1}) => MaterialApp(
  theme: ThemeData.dark(),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: ChangeNotifierProvider<PortfolioProvider>.value(value: _Portfolio(), child: child),
);

void main() {
  testWidgets('summary separates reservations and uses starting equity', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: SingleChildScrollView(
            child: PortfolioSummary(portfolio: _Portfolio()),
          ),
        ),
      ),
    );
    expect(find.text(CurrencyFormatter.format(30000)), findsOneWidget);
    // 20k active holdings + 3k reserved sells, counted once.
    expect(find.text(CurrencyFormatter.format(23000)), findsOneWidget);
    expect(find.text(CurrencyFormatter.format(5000)), findsOneWidget);
    expect(find.text(CurrencyFormatter.format(9000)), findsOneWidget);
    expect(find.textContaining('+20.00%'), findsOneWidget);
    expect(find.text('Basis: 25.000 € Eigenkapital'), findsOneWidget);
    expect(
      find.textContaining('Bereits im investierten Wert enthalten.'),
      findsOneWidget,
    );
  });

  for (final width in [375.0, 768.0, 1440.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('portfolio fits width $width with text scale $scale', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(Size(width, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(_app(const PortfolioScreen(), scale: scale));
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(find.byType(PositionTile), 400);
        expect(tester.takeException(), isNull);
        final sell = find.widgetWithText(OutlinedButton, 'Verkaufen');
        expect(tester.getSize(sell).height, greaterThanOrEqualTo(48));
        await tester.scrollUntilVisible(
          find.text('Reservierte Menge: 30 Stk.'),
          400,
        );
        expect(tester.takeException(), isNull);
        expect(find.text('Reservierte Menge: 30 Stk.'), findsOneWidget);
        final cancel = find.widgetWithText(TextButton, 'Order stornieren').last;
        expect(tester.getSize(cancel).height, greaterThanOrEqualTo(48));
      });
    }
  }
}



