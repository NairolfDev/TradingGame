import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trading_game/data/mock_data/initial_assets.dart';
import 'package:trading_game/data/models/asset.dart';
import 'package:trading_game/data/repositories/local_trading_repository.dart';
import 'package:trading_game/logic/portfolio_provider.dart';
import 'package:trading_game/ui/screens/markets_screen.dart';
import 'package:trading_game/ui/widgets/asset_card.dart';

class _QuoteProvider extends ChangeNotifier implements PortfolioProvider {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  DateTime? quoteUpdatedAt(Asset asset) => DateTime(2026, 10, 16, 22);
  @override
  String quoteStatus(Asset asset) =>
      'Yahoo Finance · Stand 16.10. 22:00 · ggf. verzögert · EUR zum aktuellen FX-Kurs';
  @override
  String quoteStatusShort(Asset asset) => 'Stand 16.10. 22:00 · ggf. verzögert';
  @override
  String getMarketStatusString(Asset asset) => 'Öffnet Montag um 15:30 Uhr';
}

void main() {
  testWidgets('asset card keeps provider details out of the list', (
    tester,
  ) async {
    final asset = InitialAssets.getAssets().firstWhere(
      (a) => a.symbol == 'BTC',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<PortfolioProvider>.value(
          value: _QuoteProvider(),
          child: Scaffold(
            body: AssetCard(asset: asset, onTap: () {}),
          ),
        ),
      ),
    );
    expect(find.text('Stand 16.10. 22:00 · ggf. verzögert'), findsOneWidget);
    expect(find.textContaining('Yahoo Finance'), findsNothing);
    expect(find.textContaining('FX-Kurs'), findsNothing);
  });

  group('markets on a phone', () {
    late PortfolioProvider portfolio;

    Future<void> open(WidgetTester tester, Size size) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        portfolio = PortfolioProvider(repository: LocalTradingRepository());
        while (portfolio.isLoading) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        portfolio.marketEngine.stop();
        portfolio.newsService.dispose();
      });
      addTearDown(portfolio.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: portfolio,
          child: const MaterialApp(home: MarketsScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('results start high on the screen', (tester) async {
      await open(tester, const Size(375, 812));
      expect(find.byType(AssetCard), findsWidgets);
      expect(tester.getTopLeft(find.byType(AssetCard).first).dy, lessThan(260));
      // The index chips live in the filter sheet, not in the header.
      expect(find.widgetWithText(FilterChip, 'ATX'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('the filter sheet narrows the results live', (tester) async {
      await open(tester, const Size(375, 812));
      int hits() {
        final label = find
            .textContaining('Ergebnisse anzeigen')
            .evaluate()
            .map((e) => (e.widget as Text).data!)
            .single;
        return int.parse(
          RegExp(r'\d+').firstMatch(label.replaceAll('.', ''))!.group(0)!,
        );
      }

      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();
      final before = hits();
      await tester.tap(find.widgetWithText(FilterChip, 'ATX'));
      await tester.pumpAndSettle();
      expect(hits(), lessThan(before));
      expect(find.widgetWithText(Badge, '1'), findsOneWidget);
      await tester.tap(find.textContaining('Ergebnisse anzeigen'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilterChip, 'ATX'), findsNothing);
      expect(find.widgetWithText(InputChip, 'Index: ATX'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('on a tablet the chips stay inline', (tester) async {
      await open(tester, const Size(768, 1000));
      expect(find.widgetWithText(FilterChip, 'ATX'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  });
}
