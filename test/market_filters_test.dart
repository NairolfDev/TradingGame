import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trading_game/data/repositories/local_trading_repository.dart';
import 'package:trading_game/logic/portfolio_provider.dart';
import 'package:trading_game/ui/screens/markets_screen.dart';

void main() {
  testWidgets('market filters combine and remain usable on a narrow screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});
    late PortfolioProvider portfolio;
    await tester.runAsync(() async {
      portfolio = PortfolioProvider(repository: LocalTradingRepository());
      while (portfolio.isLoading) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      portfolio.marketEngine.stop();
    });
    addTearDown(portfolio.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: portfolio,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(size: const Size(375, 812)),
            child: child!,
          ),
          home: const MarketsScreen(),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    // On a phone the filters live in a sheet behind the filter button.
    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'ATX'));
    await tester.pumpAndSettle();
    expect(find.textContaining('20 Treffer'), findsOneWidget);
    await tester.tap(find.textContaining('Ergebnisse anzeigen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Erste');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('1 Treffer'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Zurücksetzen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Zurücksetzen'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('${portfolio.assets.length} Treffer'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('Weitere Filter'));
    await tester.tap(find.text('Weitere Filter'));
    await tester.pumpAndSettle();
    expect(find.text('Branche'), findsOneWidget);
    expect(find.text('Assetklasse'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
