import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/models/price_alert.dart';
import '../data/repositories/price_alert_repository.dart';

/// The signed-in player's price alerts (live from Firestore).
class PriceAlertsController extends ChangeNotifier {
  static const maxAlerts = 20;

  final PriceAlertRepository _repo;
  StreamSubscription<List<PriceAlert>>? _sub;
  String? _uid;
  List<PriceAlert> _alerts = const [];
  String? _error;

  PriceAlertsController({PriceAlertRepository? repository})
    : _repo = repository ?? FirestorePriceAlertRepository();

  List<PriceAlert> get alerts => _alerts;
  String? get error => _error;
  bool get isFull => _alerts.where((a) => a.active).length >= maxAlerts;

  List<PriceAlert> forAsset(String assetId) =>
      _alerts.where((a) => a.assetId == assetId).toList();

  void bindUser(String? uid) {
    if (uid == _uid) return;
    _uid = uid;
    _sub?.cancel();
    _alerts = const [];
    _error = null;
    if (uid != null) {
      _sub = _repo
          .watch(uid)
          .listen(
            (list) {
              _alerts = list;
              _error = null;
              notifyListeners();
            },
            onError: (Object e) {
              _error = 'Alarme konnten nicht geladen werden.';
              notifyListeners();
            },
          );
    }
    notifyListeners();
  }

  /// Returns an error text, or null on success.
  Future<String?> add({
    required String assetId,
    required String symbol,
    required String name,
    required String yahooSymbol,
    required AlertDirection direction,
    required double price,
    required bool recurring,
  }) async {
    final uid = _uid;
    if (uid == null) return 'Bitte zuerst anmelden.';
    if (!price.isFinite || price <= 0) {
      return 'Bitte einen gültigen Kurs eingeben.';
    }
    if (isFull) return 'Maximal $maxAlerts aktive Alarme.';
    try {
      await _repo.add(
        PriceAlert(
          id: '',
          uid: uid,
          assetId: assetId,
          symbol: symbol,
          name: name,
          yahooSymbol: yahooSymbol,
          direction: direction,
          price: price,
          recurring: recurring,
          active: true,
        ),
      );
      return null;
    } catch (_) {
      return 'Alarm konnte nicht gespeichert werden. Bitte Verbindung prüfen.';
    }
  }

  final _inFlight = <String>{};

  /// Checks the active alerts against [prices] (EUR, by asset id), stores the
  /// new state and returns the alerts that fired just now.
  Future<List<PriceAlert>> check(Map<String, double> prices) async {
    final fired = <PriceAlert>[];
    for (final alert in _alerts) {
      final price = prices[alert.assetId];
      if (!alert.active || price == null || !price.isFinite || price <= 0) {
        continue;
      }
      if (_inFlight.contains(alert.id)) continue;
      final result = alert.evaluate(price);
      if (!result.trigger && result.armed == alert.armed) continue;
      _inFlight.add(alert.id);
      try {
        await _repo.update(alert.id, {
          'armed': result.armed,
          if (result.trigger) ...{
            'lastTriggeredAt': DateTime.now().millisecondsSinceEpoch,
            if (!alert.recurring) 'active': false,
          },
        });
        if (result.trigger) fired.add(alert);
      } catch (_) {
        // Offline or rules hiccup: the next price update tries again.
      } finally {
        _inFlight.remove(alert.id);
      }
    }
    return fired;
  }

  Future<bool> remove(String id) async {
    try {
      await _repo.remove(id);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
