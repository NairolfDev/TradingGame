import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trading_game/data/models/reward_event.dart';
import 'package:trading_game/data/repositories/local_trading_repository.dart';
import 'package:trading_game/logic/portfolio_provider.dart';
import 'package:trading_game/logic/theme_controller.dart';
import 'package:trading_game/ui/widgets/reward_overlay.dart';

void main() {
  late PortfolioProvider portfolio;
  late ThemeController theme;

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
    theme = ThemeController();
    addTearDown(portfolio.dispose);
    addTearDown(theme.dispose);
  }

  Future<void> show(WidgetTester tester, {bool accessible = false}) async {
    await boot(tester);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: portfolio),
          ChangeNotifierProvider.value(value: theme),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(accessibleNavigation: accessible),
            child: RewardOverlay(child: child!),
          ),
          home: const Scaffold(body: SizedBox.expand()),
        ),
      ),
    );
  }

  /// The stream delivers after the current frame, so a second pump is needed.
  Future<void> announce(WidgetTester tester, RewardEvent e) async {
    portfolio.announce(e);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  RewardEvent event(String title) =>
      RewardEvent(kind: RewardKind.orderExecuted, title: title, detail: 'BTC');

  testWidgets('feedback stays for 8 seconds, not 2.4', (tester) async {
    await show(tester);
    await announce(tester, event('Order A'));
    expect(find.textContaining('Order A'), findsWidgets);
    await tester.pump(const Duration(seconds: 7));
    expect(find.textContaining('Order A'), findsWidgets);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(find.textContaining('Order A'), findsNothing);
  });

  testWidgets('with a screen reader nothing disappears by itself', (
    tester,
  ) async {
    await show(tester, accessible: true);
    await announce(tester, event('Order B'));
    await tester.pump(const Duration(seconds: 30));
    expect(find.textContaining('Order B'), findsWidgets);
  });

  testWidgets('close button dismisses and reveals the queued event', (
    tester,
  ) async {
    await show(tester);
    portfolio.announce(event('Erste'));
    await announce(tester, event('Zweite'));
    expect(find.textContaining('Erste'), findsWidgets);
    expect(find.textContaining('Zweite'), findsNothing);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    expect(find.textContaining('Zweite'), findsWidgets);
    await tester.pump(const Duration(seconds: 10));
  });
}
