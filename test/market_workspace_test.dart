import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trading_game/data/repositories/local_trading_repository.dart';
import 'package:trading_game/logic/portfolio_provider.dart';
import 'package:trading_game/ui/screens/markets_screen.dart';

void main() {
  testWidgets(
    'a saved combined view restores after recreation and can be deleted',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(768, 1000));
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
      Future<void> showMarkets() async {
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: portfolio,
            child: MaterialApp(home: const MarketsScreen()),
          ),
        );
        await tester.pumpAndSettle();
      }

      await showMarkets();
      await tester.tap(find.widgetWithText(FilterChip, 'ATX'));
      await tester.enterText(find.byType(TextField), 'Erste');
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('1 Treffer'), findsOneWidget);
      await tester.tap(find.text('Ansicht speichern'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Name der Ansicht'),
        'Meine Banken',
      );
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await showMarkets();
      await tester.tap(find.text('Ansichten'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Meine Banken'));
      await tester.pumpAndSettle();
      expect(find.textContaining('1 Treffer'), findsOneWidget);
      expect(find.text('Index: ATX'), findsOneWidget);
      expect(find.text('Suche: Erste'), findsOneWidget);
      await tester.tap(find.byTooltip('Persönliche Ansicht löschen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Meine Banken'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await showMarkets();
      await tester.tap(find.text('Ansichten'));
      await tester.pumpAndSettle();
      expect(find.text('Meine Banken'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
  for (final width in [375.0, 768.0, 1440.0]) {
    testWidgets(
      'markets offer saved views and adapt at $width with large text',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        await tester.binding.setSurfaceSize(Size(width, 1000));
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
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: portfolio,
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  size: Size(width, 1000),
                  textScaler: const TextScaler.linear(2),
                ),
                child: child!,
              ),
              home: const MarketsScreen(),
            ),
          ),
        );
        await tester.pump();
        expect(find.text('Ansichten'), findsOneWidget);
        expect(
          find.byType(DataTable),
          width >= 1000 ? findsOneWidget : findsNothing,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );
  }
}
