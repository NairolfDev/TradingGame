import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:trading_game/data/models/price_alert.dart';
import 'package:trading_game/data/repositories/price_alert_repository.dart';
import 'package:trading_game/logic/price_alerts_controller.dart';

class _Repo implements PriceAlertRepository {
  final stream = StreamController<List<PriceAlert>>.broadcast();
  final updates = <(String, Map<String, dynamic>)>[];
  @override
  Stream<List<PriceAlert>> watch(String uid) => stream.stream;
  @override
  Future<void> add(PriceAlert alert) async {}
  @override
  Future<void> update(String id, Map<String, dynamic> data) async =>
      updates.add((id, data));
  @override
  Future<void> remove(String id) async {}
}

PriceAlert alert({
  AlertDirection direction = AlertDirection.above,
  bool recurring = false,
  bool armed = true,
}) => PriceAlert(
  id: 'a1',
  uid: 'u',
  assetId: 'btc',
  symbol: 'BTC',
  name: 'Bitcoin',
  yahooSymbol: 'BTC-EUR',
  direction: direction,
  price: 100,
  recurring: recurring,
  active: true,
  armed: armed,
);

Future<(PriceAlertsController, _Repo)> controllerWith(PriceAlert a) async {
  final repo = _Repo();
  final c = PriceAlertsController(repository: repo)..bindUser('u');
  repo.stream.add([a]);
  await Future<void>.delayed(Duration.zero);
  return (c, repo);
}

void main() {
  test('a one-shot alert fires once and deactivates', () async {
    final (c, repo) = await controllerWith(alert());
    expect(await c.check({'btc': 99}), isEmpty);
    expect(repo.updates, isEmpty);
    expect(await c.check({'btc': 101}), hasLength(1));
    expect(repo.updates.single.$2['active'], false);
    expect(repo.updates.single.$2['armed'], false);
  });

  test(
    'a recurring alert stays active but disarms until price crosses back',
    () async {
      final (c, repo) = await controllerWith(alert(recurring: true));
      await c.check({'btc': 101});
      expect(repo.updates.single.$2.containsKey('active'), isFalse);
      expect(repo.updates.single.$2['armed'], false);
    },
  );

  test('a disarmed alert never fires but re-arms below the threshold', () {
    final disarmed = alert(recurring: true, armed: false);
    expect(disarmed.evaluate(101), (trigger: false, armed: false));
    expect(disarmed.evaluate(99), (trigger: false, armed: true));
  });

  test('below alerts fire at or under the threshold', () {
    final a = alert(direction: AlertDirection.below);
    expect(a.evaluate(100).trigger, isTrue);
    expect(a.evaluate(101).trigger, isFalse);
  });

  test('unknown assets and invalid prices are ignored', () async {
    final (c, repo) = await controllerWith(alert());
    expect(await c.check({'eth': 500, 'btc': double.nan}), isEmpty);
    expect(repo.updates, isEmpty);
  });
}
