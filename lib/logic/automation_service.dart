import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../data/models/asset.dart';
import '../data/models/automation_order.dart';

class AutomationService {
  static const String _legacyKeyUnlockedSlots = 'automation_unlocked_slots_v1';
  static const String _legacyKeyOrders = 'automation_orders_v1';

  String _profileId = 'local';
  String get _keyUnlockedSlots =>
      (_profileId == 'local' || _profileId.isEmpty)
          ? _legacyKeyUnlockedSlots
          : '${_legacyKeyUnlockedSlots}_$_profileId';
  String get _keyOrders =>
      (_profileId == 'local' || _profileId.isEmpty)
          ? _legacyKeyOrders
          : '${_legacyKeyOrders}_$_profileId';

  final Uuid _uuid = const Uuid();
  int _unlockedSlotsCount = 1; // Slot 1 ist von Beginn an kostenlos & frei
  final List<AutomationOrder> _orders = [];

  // Bepreisung der Automatisierungs-Slots (stufenweise ansteigend)
  static const Map<int, double> slotCosts = {
    1: 0.0,        // Kostenlos
    2: 15000.0,    // 15.000 €
    3: 50000.0,    // 50.000 €
    4: 150000.0,   // 150.000 €
    5: 500000.0,   // 500.000 € (Quant High-Frequency Bot)
  };

  int get unlockedSlotsCount => _unlockedSlotsCount;
  List<AutomationOrder> get allOrders => List.unmodifiable(_orders);
  List<AutomationOrder> get activeOrders =>
      _orders.where((o) => o.isActive).toList();

  int get maxSlots => 5;
  bool get hasMaxSlots => _unlockedSlotsCount >= maxSlots;

  double? get nextSlotCost {
    if (hasMaxSlots) return null;
    return slotCosts[_unlockedSlotsCount + 1];
  }

  Future<void> initialize({String profileId = 'local'}) async {
    _profileId = profileId.trim().isEmpty ? 'local' : profileId;
    _orders.clear();
    final prefs = await SharedPreferences.getInstance();
    _unlockedSlotsCount = prefs.getInt(_keyUnlockedSlots) ?? 1;

    final raw = prefs.getString(_keyOrders);
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        _orders.addAll(
          list.map((e) => AutomationOrder.fromJson(e as Map<String, dynamic>)),
        );
      } catch (e) {
        debugPrint('Fehler beim Laden der Automation Orders: $e');
      }
    }
  }

  /// Synchronizes cloud-stored state into local profile storage.
  Future<void> applyCloudState({
    required int unlockedSlotsCount,
    required List<AutomationOrder> orders,
  }) async {
    _unlockedSlotsCount = unlockedSlotsCount.clamp(1, maxSlots);
    _orders
      ..clear()
      ..addAll(orders);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyUnlockedSlots, _unlockedSlotsCount);
    await _saveOrders();
  }

  Future<void> resetForProfile() async {
    _unlockedSlotsCount = 1;
    _orders.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUnlockedSlots);
    await prefs.remove(_keyOrders);
  }

  Future<bool> unlockNextSlot(
    double currentCash,
    void Function(double cost) onDeduct,
  ) async {
    final cost = nextSlotCost;
    if (cost == null || currentCash < cost) return false;

    onDeduct(cost);
    _unlockedSlotsCount++;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyUnlockedSlots, _unlockedSlotsCount);
    return true;
  }

  Future<AutomationOrder?> placeOrder({
    required String assetId,
    required String symbol,
    required String name,
    required AutomationOrderType orderType,
    required double targetPrice,
    required double amount,
    double? trailingPercent,
    double? initialObservedPrice,
    bool bypassSlotLimit = false,
  }) async {
    if (!bypassSlotLimit && activeOrders.length >= _unlockedSlotsCount) {
      return null; // Kein freier Slot vorhanden
    }

    // Finde den ersten freien Slot (1 bis unlockedSlotsCount)
    final occupiedSlots = activeOrders.map((o) => o.slotIndex).toSet();
    int chosenSlot = 1;
    for (int s = 1; s <= _unlockedSlotsCount; s++) {
      if (!occupiedSlots.contains(s)) {
        chosenSlot = s;
        break;
      }
    }

    final validTrailing = (trailingPercent != null &&
            trailingPercent.isFinite &&
            trailingPercent > 0 &&
            trailingPercent < 95)
        ? trailingPercent
        : null;
    final observedHigh = initialObservedPrice != null &&
            initialObservedPrice.isFinite &&
            initialObservedPrice > 0
        ? initialObservedPrice
        : null;
    final effectiveTarget =
        (orderType == AutomationOrderType.trailingStop &&
                validTrailing != null &&
                observedHigh != null)
            ? observedHigh * (1.0 - validTrailing / 100.0)
            : targetPrice;

    final order = AutomationOrder(
      id: _uuid.v4(),
      assetId: assetId,
      symbol: symbol,
      name: name,
      orderType: orderType,
      targetPrice: effectiveTarget,
      amount: amount,
      slotIndex: chosenSlot,
      createdAt: DateTime.now(),
      trailingPercent: validTrailing,
      highestObservedPrice: observedHigh,
    );

    _orders.insert(0, order);
    await _saveOrders();
    return order;
  }

  Future<bool> cancelOrder(String orderId) async {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index != -1 && _orders[index].isActive) {
      _orders[index].isCancelled = true;
      await _saveOrders();
      return true;
    }
    return false;
  }

  Future<void> checkAndExecuteOrders({
    required List<Asset> assets,
    required Future<void> Function(AutomationOrder order, Asset asset) onExecute,
  }) async {
    bool changes = false;

    for (final order in activeOrders) {
      final matchingAssets = assets.where(
        (a) => a.id == order.assetId || a.symbol == order.symbol,
      );
      if (matchingAssets.isEmpty) continue;
      final matching = matchingAssets.first;
      if (!matching.currentPrice.isFinite || matching.currentPrice <= 0) {
        continue;
      }

      bool triggered = false;

      switch (order.orderType) {
        case AutomationOrderType.buyLimit:
          // Kaufe wenn Marktpreis <= Zielpreis
          if (matching.currentPrice <= order.targetPrice) {
            triggered = true;
          }
          break;
        case AutomationOrderType.takeProfit:
          // Verkaufe mit Gewinn wenn Marktpreis >= Zielpreis
          if (matching.currentPrice >= order.targetPrice) {
            triggered = true;
          }
          break;
        case AutomationOrderType.stopLoss:
          // Verkaufe zur Schadensbegrenzung wenn Marktpreis <= Zielpreis
          if (matching.currentPrice <= order.targetPrice) {
            triggered = true;
          }
          break;
        case AutomationOrderType.trailingStop:
          final pct = (order.trailingPercent ?? 5.0).clamp(0.1, 90.0);
          final prevHigh = order.highestObservedPrice ?? matching.currentPrice;
          if (matching.currentPrice > prevHigh) {
            order.highestObservedPrice = matching.currentPrice;
            order.targetPrice = matching.currentPrice * (1.0 - pct / 100.0);
            changes = true;
          } else if (order.highestObservedPrice == null) {
            order.highestObservedPrice = prevHigh;
            order.targetPrice = prevHigh * (1.0 - pct / 100.0);
            changes = true;
          }
          if (matching.currentPrice <= order.targetPrice) {
            triggered = true;
          }
          break;
      }

      if (triggered) {
        order.isTriggered = true;
        order.triggeredAt = DateTime.now();
        order.triggeredPrice = matching.currentPrice;
        changes = true;

        await onExecute(order, matching);
      }
    }

    if (changes) {
      await _saveOrders();
    }
  }

  Future<void> _saveOrders() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(_orders.map((o) => o.toJson()).toList());
    await prefs.setString(_keyOrders, raw);
  }
}
