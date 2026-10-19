import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_game/data/models/asset.dart';
import 'package:trading_game/data/models/position.dart';
import 'package:trading_game/logic/net_worth_history.dart';
import 'package:trading_game/ui/widgets/allocation_chart.dart';
import 'package:trading_game/ui/widgets/net_worth_chart.dart';

void main() {
  final t0 = DateTime(2026, 10, 19, 12);

  test('samples are spaced out unless the value moves a lot', () {
    final h = NetWorthHistory();
    expect(h.record(50000, t0), isTrue);
    expect(h.record(50010, t0.add(const Duration(minutes: 1))), isFalse);
    expect(h.record(51000, t0.add(const Duration(minutes: 1))), isTrue);
    expect(h.record(51000, t0.add(const Duration(minutes: 7))), isTrue);
    expect(h.record(double.nan, t0.add(const Duration(hours: 1))), isFalse);
    expect(h.record(0, t0.add(const Duration(hours: 1))), isFalse);
  });

  test('history survives encoding and is thinned beyond the cap', () {
    final h = NetWorthHistory();
    for (var i = 0; i < NetWorthHistory.maxPoints + 5; i++) {
      h.record(50000.0 + i, t0.add(Duration(minutes: 5 * i)));
    }
    expect(h.points.length, lessThanOrEqualTo(NetWorthHistory.maxPoints));
    final copy = NetWorthHistory()..decode(h.encode());
    expect(copy.points.length, h.points.length);
    expect(copy.points.last.value, h.points.last.value);
    expect(NetWorthHistory()..decode('kaputt'), isA<NetWorthHistory>());
  });

  test('within() keeps only the window before the newest point', () {
    final h = NetWorthHistory()
      ..record(50000, t0)
      ..record(50100, t0.add(const Duration(days: 2)))
      ..record(50200, t0.add(const Duration(days: 2, hours: 1)));
    expect(h.within(const Duration(days: 1)).length, 2);
    expect(h.within(null).length, 3);
  });

  testWidgets('chart shows gain and handles too little data', (tester) async {
    final h = NetWorthHistory();
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: NetWorthChart(history: h))),
    );
    expect(find.text('Noch zu wenig Daten'), findsOneWidget);
    h
      ..record(50000, t0)
      ..record(51000, t0.add(const Duration(minutes: 10)));
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: NetWorthChart(history: h))),
    );
    expect(find.textContaining('+'), findsWidgets);
    expect(find.text('Vermögensverlauf'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('allocation groups by asset class and drops empty parts', () {
    Position pos(AssetType t, double amount) => Position(
      id: t.name,
      assetId: t.name,
      symbol: 'X',
      name: 'X',
      type: t,
      amount: amount,
      averageBuyPrice: 10,
      currentPrice: 10,
    );
    final slices = buildAllocation(
      cash: 500,
      positions: [
        pos(AssetType.stock, 10),
        pos(AssetType.stock, 20),
        pos(AssetType.crypto, 5),
      ],
      luxuryValue: 0,
    );
    expect(slices.map((s) => s.label), ['Bargeld', 'Aktien', 'Krypto']);
    expect(slices[1].value, 300);
  });
}
