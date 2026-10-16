import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/savings_plan.dart';

class SavingsPlanService {
  static const String _keySavings = 'tg_savings_plans_v1';

  final List<SavingsPlan> _plans = [];

  List<SavingsPlan> get plans => List.unmodifiable(_plans);
  List<SavingsPlan> get activePlans =>
      List.unmodifiable(_plans.where((p) => p.isActive));

  Future<void> initialize() async {
    _plans.clear();
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keySavings);
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        for (final item in list) {
          _plans.add(SavingsPlan.fromJson(item as Map<String, dynamic>));
        }
      } catch (e) {
        debugPrint('Fehler beim Laden der Sparpläne: $e');
      }
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(_plans.map((p) => p.toJson()).toList());
    await prefs.setString(_keySavings, raw);
  }

  Future<SavingsPlan> createPlan({
    required String assetSymbol,
    required String assetName,
    required double amountEur,
    required SavingsPlanFrequency frequency,
  }) async {
    final plan = SavingsPlan(
      id: 'sp_${DateTime.now().millisecondsSinceEpoch}',
      assetSymbol: assetSymbol,
      assetName: assetName,
      amountEur: amountEur,
      frequency: frequency,
    );
    _plans.add(plan);
    await _save();
    return plan;
  }

  Future<void> togglePlan(String planId) async {
    final index = _plans.indexWhere((p) => p.id == planId);
    if (index != -1) {
      _plans[index].isActive = !_plans[index].isActive;
      await _save();
    }
  }

  Future<void> deletePlan(String planId) async {
    _plans.removeWhere((p) => p.id == planId);
    await _save();
  }

  /// Prüft, welche Sparpläne fällig sind
  List<SavingsPlan> getDuePlans() {
    final now = DateTime.now();
    final due = <SavingsPlan>[];

    for (final plan in _plans) {
      if (!plan.isActive) continue;

      if (plan.lastExecutedAt == null) {
        due.add(plan);
        continue;
      }

      final diff = now.difference(plan.lastExecutedAt!);
      switch (plan.frequency) {
        case SavingsPlanFrequency.daily:
          if (diff.inHours >= 24) due.add(plan);
          break;
        case SavingsPlanFrequency.weekly:
          if (diff.inDays >= 7) due.add(plan);
          break;
        case SavingsPlanFrequency.monthly:
          if (diff.inDays >= 30) due.add(plan);
          break;
      }
    }
    return due;
  }

  Future<void> markExecuted(String planId, double executedAmount) async {
    final index = _plans.indexWhere((p) => p.id == planId);
    if (index != -1) {
      _plans[index].lastExecutedAt = DateTime.now();
      _plans[index].totalInvested += executedAmount;
      await _save();
    }
  }
}
