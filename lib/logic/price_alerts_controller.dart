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
