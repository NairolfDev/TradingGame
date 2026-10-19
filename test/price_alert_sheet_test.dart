import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:trading_game/data/mock_data/initial_assets.dart';
import 'package:trading_game/data/models/price_alert.dart';
import 'package:trading_game/data/repositories/price_alert_repository.dart';
import 'package:trading_game/logic/notification_planner.dart';
import 'package:trading_game/logic/notification_service.dart';
import 'package:trading_game/logic/price_alerts_controller.dart';
import 'package:trading_game/ui/widgets/price_alert_sheet.dart';

class _FakeRepo implements PriceAlertRepository {
  final saved = <PriceAlert>[];
  final _stream = StreamController<List<PriceAlert>>.broadcast();
  @override
  Stream<List<PriceAlert>> watch(String uid) => _stream.stream;
  @override
  Future<void> add(PriceAlert alert) async {
    saved.add(alert);
    _stream.add(List.of(saved));
  }

  final updates = <(String, Map<String, dynamic>)>[];
  @override
  Future<void> update(String id, Map<String, dynamic> data) async =>
      updates.add((id, data));
  @override
  Future<void> remove(String id) async {}
}

class _NoopNotifier implements LocalNotifier {
  @override
  Future<void> init() async {}
  @override
  Future<void> show(int id, String title, String body) async {}
  @override
  Future<void> replaceScheduled(List<PlannedNotification> planned) async {}
}

void main() {
  test('euro input accepts German and English notation', () {
    expect(parseEuroInput('1.234,56'), 1234.56);
    expect(parseEuroInput('1234,5 €'), 1234.5);
    expect(parseEuroInput('99.5'), 99.5);
    expect(parseEuroInput('abc'), isNull);
  });

  testWidgets('sheet rejects instantly-true alerts and saves valid ones', (
    tester,
  ) async {
    final repo = _FakeRepo();
    final controller = PriceAlertsController(repository: repo)..bindUser('u1');
    final service = NotificationService(local: _NoopNotifier());
    final asset = InitialAssets.getAssets().firstWhere(
      (a) => a.symbol == 'BTC',
    );
    asset.currentPrice = 1000;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: controller),
          ChangeNotifierProvider.value(value: service),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showPriceAlertSheet(
                  context,
                  asset: asset,
                  yahooSymbol: 'BTC-EUR',
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Kursalarm für BTC'), findsOneWidget);

    // Already above: "über 900" would fire immediately.
    await tester.enterText(find.byType(TextField), '900');
    await tester.tap(find.text('Alarm setzen'));
    await tester.pumpAndSettle();
    expect(find.textContaining('liegt schon über'), findsOneWidget);
    expect(repo.saved, isEmpty);

    await tester.enterText(find.byType(TextField), '1.250,50');
    await tester.tap(find.text('Wiederkehrend'));
    await tester.tap(find.text('Alarm setzen'));
    await tester.pumpAndSettle();
    expect(repo.saved.length, 1);
    final a = repo.saved.single;
    expect(a.price, 1250.5);
    expect(a.direction, AlertDirection.above);
    expect(a.recurring, isTrue);
    expect(a.yahooSymbol, 'BTC-EUR');
    expect(a.uid, 'u1');
    expect(find.textContaining('Alarm gesetzt'), findsOneWidget);
  });

  test('controller refuses anonymous users and enforces the cap', () async {
    final repo = _FakeRepo();
    final c = PriceAlertsController(repository: repo);
    Future<String?> add() => c.add(
      assetId: 'a',
      symbol: 'S',
      name: 'N',
      yahooSymbol: 'S',
      direction: AlertDirection.above,
      price: 10,
      recurring: false,
    );
    expect(await add(), contains('anmelden'));
    c.bindUser('u1');
    for (var i = 0; i < PriceAlertsController.maxAlerts; i++) {
      expect(await add(), isNull);
      await Future<void>.delayed(Duration.zero);
    }
    expect(await add(), contains('Maximal'));
    expect(
      await c.add(
        assetId: 'a',
        symbol: 'S',
        name: 'N',
        yahooSymbol: 'S',
        direction: AlertDirection.below,
        price: double.nan,
        recurring: false,
      ),
      isNotNull,
    );
  });
}
