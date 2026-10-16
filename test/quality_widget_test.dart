import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trading_game/data/repositories/local_trading_repository.dart';
import 'package:trading_game/logic/portfolio_provider.dart';
import 'package:trading_game/ui/screens/dashboard_screen.dart';
import 'package:trading_game/data/mock_data/initial_assets.dart';
import 'package:trading_game/data/models/asset.dart';
import 'package:trading_game/ui/screens/social_trading_screen.dart';
import 'package:trading_game/ui/widgets/interactive_broker_chart.dart';
import 'package:trading_game/ui/widgets/order_book_widget.dart';

void main() {
  testWidgets('dashboard keeps title and account metrics readable at 375px', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    late PortfolioProvider portfolio;
    await tester.runAsync(() async {
      portfolio = PortfolioProvider(repository: LocalTradingRepository());
      while (portfolio.isLoading) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      portfolio.marketEngine.stop();
    });
    addTearDown(portfolio.dispose);
    await tester.pumpWidget(ChangeNotifierProvider.value(value: portfolio,
      child: MaterialApp(home: DashboardScreen(onNavigateTab: (_) {})),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Cash'), findsOneWidget);
    expect(find.text('Schulden'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('missing market depth is explicit on a small phone', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 667));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OrderBookWidget(asset: InitialAssets.getAssets().first),
        ),
      ),
    );
    expect(find.text('Markttiefe nicht verfügbar'), findsOneWidget);
    expect(find.textContaining('Kaufdruck'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing chart history never creates an invented line', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 667));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 320,
            child: InteractiveBrokerChart(
              asset: InitialAssets.getAssets().firstWhere(
                (a) => a.type == AssetType.bond,
              ),
              isPositive: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Keine Kursdaten für diesen Zeitraum'), findsOneWidget);
    await tester.tap(find.text('1Y'));
    await tester.pump();
    expect(find.text('Keine Kursdaten für diesen Zeitraum'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('social trading shows an honest empty state with large text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 667));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: const SocialTradingScreen(),
      ),
    );
    expect(find.text('Noch keine öffentlichen Portfolios'), findsOneWidget);
    expect(find.text('Jetzt kopieren'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
