import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_game/data/models/asset.dart';
import 'package:trading_game/data/models/market_schedule.dart';
import 'package:trading_game/data/models/pending_order.dart';
import 'package:trading_game/ui/widgets/pending_order_card.dart';

PendingOrder order(String symbol, AssetType type, {bool buy = true}) =>
    PendingOrder(
      id: 'o',
      assetId: 'a',
      symbol: symbol,
      name: symbol,
      assetType: type,
      isBuy: buy,
      amount: 5,
      estimatedPrice: 100,
      totalEstimatedCost: 500,
    );

Future<void> show(WidgetTester tester, PendingOrder o, DateTime now) =>
    tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PendingOrderCard(order: o, onCancel: () {}, now: now),
        ),
      ),
    );

void main() {
  test('a schedule can be derived from symbol and type alone', () {
    expect(
      MarketSchedule.forSymbol('AAPL', AssetType.stock).region,
      MarketRegion.usWallStreet,
    );
    expect(
      MarketSchedule.forSymbol('EBS.VI', AssetType.stock).region,
      MarketRegion.viennaEurope,
    );
    expect(
      MarketSchedule.forSymbol('BTC', AssetType.crypto).region,
      MarketRegion.crypto24_7,
    );
  });

  test('nextOpeningLine names the market and the next opening', () {
    expect(
      const MarketSchedule(MarketRegion.asiaTokyoHongKong)
          .nextOpeningLine(DateTime(2026, 10, 14, 12)),
      'Tokio / Hongkong · Öffnet morgen um 02:00 Uhr',
    );
  });

  testWidgets('a waiting buy order says when the market opens next', (
    tester,
  ) async {
    // Friday evening: Wall Street is closed until Monday.
    await show(
      tester,
      order('AAPL', AssetType.stock),
      DateTime(2026, 10, 16, 23),
    );
    expect(find.text('Wartet auf die nächste Börsenöffnung'), findsOneWidget);
    expect(
      find.text('Wall Street · Öffnet Montag um 15:30 Uhr'),
      findsOneWidget,
    );
  });

  testWidgets('the text follows the weekday and time of day', (tester) async {
    await show(
      tester,
      order('EBS.VI', AssetType.stock),
      DateTime(2026, 10, 14, 7), // Wednesday before the opening bell
    );
    expect(
      find.text('Wiener Börse / Xetra · Öffnet heute um 09:00 Uhr'),
      findsOneWidget,
    );
    await show(
      tester,
      order('EBS.VI', AssetType.stock),
      DateTime(2026, 10, 14, 18), // after the close
    );
    expect(
      find.text('Wiener Börse / Xetra · Öffnet morgen um 09:00 Uhr'),
      findsOneWidget,
    );
  });

  testWidgets('sell orders and scheduled orders keep their own wording', (
    tester,
  ) async {
    await show(
      tester,
      order('AAPL', AssetType.stock, buy: false),
      DateTime(2026, 10, 17, 12), // Saturday
    );
    expect(
      find.text('Wall Street · Öffnet Montag um 15:30 Uhr'),
      findsOneWidget,
    );
  });
}
