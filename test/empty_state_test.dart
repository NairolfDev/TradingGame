import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trading_game/data/repositories/local_trading_repository.dart';
import 'package:trading_game/logic/portfolio_provider.dart';
import 'package:trading_game/ui/screens/history_news_screen.dart';
import 'package:trading_game/ui/screens/markets_screen.dart';
import 'package:trading_game/ui/screens/portfolio_screen.dart';
import 'package:trading_game/ui/widgets/empty_state.dart';

void main() {
  testWidgets('EmptyState shows title, text and a working action', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmptyState(
            icon: Icons.inbox_outlined,
            title: 'Nichts da',
            message: 'Lege los.',
            actionLabel: 'Los',
            onAction: () => taps++,
          ),
        ),
      ),
    );
    expect(find.text('Nichts da'), findsOneWidget);
    expect(find.text('Lege los.'), findsOneWidget);
    final button = find.widgetWithText(FilledButton, 'Los');
    expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
    await tester.tap(button);
    expect(taps, 1);
  });

  testWidgets('EmptyState without an action has no button', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EmptyState(
            icon: Icons.inbox_outlined,
            title: 'Nichts da',
            message: 'Nur Info.',
          ),
        ),
      ),
    );
    expect(find.byType(FilledButton), findsNothing);
  });

  group('with a fresh portfolio', () {
    late PortfolioProvider portfolio;

    Future<void> boot(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.runAsync(() async {
        portfolio = PortfolioProvider(repository: LocalTradingRepository());
        while (portfolio.isLoading) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        portfolio.marketEngine.stop();
        portfolio.newsService.dispose();
      });
      addTearDown(portfolio.dispose);
    }

    Widget app(Widget child) => ChangeNotifierProvider.value(
      value: portfolio,
      child: MaterialApp(home: child),
    );

    testWidgets('portfolio without positions leads to the markets', (
      tester,
    ) async {
      await boot(tester);
      await tester.binding.setSurfaceSize(const Size(400, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var opened = 0;
      await tester.pumpWidget(
        app(PortfolioScreen(onOpenMarkets: () => opened++)),
      );
      expect(find.text('Noch keine Positionen'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Märkte entdecken'));
      expect(opened, 1);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('empty order history leads to the markets', (tester) async {
      await boot(tester);
      var opened = 0;
      await tester.pumpWidget(
        app(HistoryNewsScreen(onOpenMarkets: () => opened++)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Noch keine Transaktionen'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Märkte entdecken'));
      expect(opened, 1);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('markets without hits offer to reset the filters', (
      tester,
    ) async {
      await boot(tester);
      await tester.binding.setSurfaceSize(const Size(768, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(app(const MarketsScreen()));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'zzzzqqqq');
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Keine Treffer'), findsOneWidget);
      await tester.tap(
        find.widgetWithText(FilledButton, 'Filter zurücksetzen'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Keine Treffer'), findsNothing);
      expect(find.textContaining('Treffer ·'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  });
}
