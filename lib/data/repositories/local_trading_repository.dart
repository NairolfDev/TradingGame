import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/asset.dart';
import '../models/automation_order.dart';
import '../models/position.dart';
import '../models/savings_plan.dart';
import '../models/transaction.dart';
import '../models/luxury_item.dart';
import '../models/pending_order.dart';
import '../models/leaderboard_entry.dart';
import '../models/loan_model.dart';
import '../mock_data/initial_assets.dart';
import '../catalog/stock_catalog.dart';
import '../mock_data/initial_luxury_items.dart';
import '../mock_data/initial_leaderboard.dart';
import 'trading_repository.dart';

class LocalTradingRepository implements TradingRepository {
  final String userId;
  LocalTradingRepository([this.userId = 'local']);

  String _k(String base) =>
      (userId == 'local' || userId.isEmpty) ? 'tg_$base' : 'tg_${userId}_$base';

  String get _keyCash => _k('cash_balance');
  static const String _keyAssets = 'tg_assets';
  String get _keyPositions => _k('positions');
  String get _keyTransactions => _k('transactions');
  String get _keyLuxury => _k('luxury_items');
  String get _keyPendingOrders => _k('pending_orders');
  static const String _keyLeaderboard = 'tg_leaderboard';
  String get _keyLoans => _k('loans');
  String get _keyInsolvency => _k('insolvency_status');

  static const double initialStartingCash = 50000.0; // 50.000 € Startguthaben

  @override
  Future<double> getCashBalance() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keyCash) ?? initialStartingCash;
  }

  @override
  Future<void> saveCashBalance(double cash) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyCash, cash);
  }

  @override
  Future<List<Asset>> getAssets() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyAssets);
    if (raw == null) {
      final initial = StockCatalog.merge(InitialAssets.getAssets());
      await saveAssets(initial);
      return initial;
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final saved = list
          .map((e) => Asset.fromJson(e as Map<String, dynamic>))
          .toList();
      final defaults = {for (final a in InitialAssets.getAssets()) a.id: a};
      for (var i = 0; i < saved.length; i++) {
        final d = defaults[saved[i].id];
        if (saved[i].yahooSymbol == null && d?.yahooSymbol != null) {
          saved[i] = saved[i].copyWith(yahooSymbol: d!.yahooSymbol);
        }
      }
      final known = {for (final a in saved) a.id};
      saved.addAll(defaults.values.where((a) => !known.contains(a.id)));
      return StockCatalog.merge(saved);
    } catch (_) {
      return StockCatalog.merge(InitialAssets.getAssets());
    }
  }

  @override
  Future<void> saveAssets(List<Asset> assets) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(assets.map((a) => a.toJson()).toList());
    await prefs.setString(_keyAssets, raw);
  }

  @override
  Future<List<Position>> getPositions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyPositions);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => Position.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> savePositions(List<Position> positions) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(positions.map((p) => p.toJson()).toList());
    await prefs.setString(_keyPositions, raw);
  }

  @override
  Future<List<TransactionRecord>> getTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyTransactions);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => TransactionRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> saveTransaction(TransactionRecord transaction) async {
    final existing = await getTransactions();
    existing.insert(0, transaction);
    if (existing.length > 200) {
      existing.removeLast();
    }
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(existing.map((t) => t.toJson()).toList());
    await prefs.setString(_keyTransactions, raw);
  }

  Future<void> saveAllTransactions(List<TransactionRecord> transactions) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(transactions.map((t) => t.toJson()).toList());
    await prefs.setString(_keyTransactions, raw);
  }

  @override
  Future<List<LuxuryItem>> getLuxuryItems() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyLuxury);
    final catalog = InitialLuxuryItems.getItems();
    if (raw == null) {
      await saveLuxuryItems(catalog);
      return catalog;
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final savedItems = list
          .map((e) => LuxuryItem.fromJson(e as Map<String, dynamic>))
          .toList();
      final savedMap = {for (final item in savedItems) item.id: item};

      final merged = catalog.map((catItem) {
        if (savedMap.containsKey(catItem.id)) {
          return catItem.copyWith(ownedCount: savedMap[catItem.id]!.ownedCount);
        }
        return catItem;
      }).toList();

      return merged;
    } catch (_) {
      return catalog;
    }
  }

  @override
  Future<void> saveLuxuryItems(List<LuxuryItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(items.map((i) => i.toJson()).toList());
    await prefs.setString(_keyLuxury, raw);
  }

  @override
  Future<List<PendingOrder>> getPendingOrders() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyPendingOrders);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => PendingOrder.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> savePendingOrders(List<PendingOrder> orders) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(orders.map((o) => o.toJson()).toList());
    await prefs.setString(_keyPendingOrders, raw);
  }

  @override
  Future<List<LeaderboardEntry>> getLeaderboard() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyLeaderboard);
    if (raw == null) {
      final initial = InitialLeaderboard.getCompetitors();
      await saveLeaderboard(initial);
      return initial;
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return InitialLeaderboard.getCompetitors();
    }
  }

  @override
  Future<void> saveLeaderboard(
    List<LeaderboardEntry> entries, {
    bool forceCloud = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(entries.map((e) => e.toJson()).toList());
    await prefs.setString(_keyLeaderboard, raw);
  }

  @override
  Stream<List<LeaderboardEntry>>? streamLeaderboard() => null;

  @override
  Future<List<Loan>> getLoans() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyLoans);
    if (raw == null) {
      final initial = [Loan.createInitialStartLoan()];
      await saveLoans(initial);
      return initial;
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => Loan.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [Loan.createInitialStartLoan()];
    }
  }

  @override
  Future<void> saveLoans(List<Loan> loans) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(loans.map((l) => l.toJson()).toList());
    await prefs.setString(_keyLoans, raw);
  }

  @override
  Future<Map<String, dynamic>> getInsolvencyStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyInsolvency);
    if (raw == null) {
      return {
        'isInsolvent': false,
        'lockoutUntil': null,
        'lastLoanTakenAt': null,
      };
    }
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return {
        'isInsolvent': false,
        'lockoutUntil': null,
        'lastLoanTakenAt': null,
      };
    }
  }

  @override
  Future<void> saveInsolvencyStatus({
    required bool isInsolvent,
    DateTime? lockoutUntil,
    DateTime? lastLoanTakenAt,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final data = {
      'isInsolvent': isInsolvent,
      'lockoutUntil': lockoutUntil?.toIso8601String(),
      'lastLoanTakenAt': lastLoanTakenAt?.toIso8601String(),
    };
    await prefs.setString(_keyInsolvency, jsonEncode(data));
  }

  @override
  Future<({int unlockedSlotsCount, List<AutomationOrder> orders})?>
  getCloudAutomationState() async => null;

  @override
  Future<void> saveCloudAutomationState({
    required int unlockedSlotsCount,
    required List<AutomationOrder> orders,
  }) async {}

  @override
  Future<List<SavingsPlan>?> getCloudSavingsPlans() async => null;

  @override
  Future<void> saveCloudSavingsPlans(List<SavingsPlan> plans) async {}

  @override
  Future<void> resetGameToInitial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyCash);
    await prefs.remove(_keyPositions);
    await prefs.remove(_keyTransactions);
    await prefs.remove(_keyPendingOrders);
    await prefs.remove(_keyLuxury);
    await prefs.remove(_keyLoans);
    await prefs.remove(_keyInsolvency);
    if (userId == 'local') {
      await prefs.remove(_keyAssets);
      await prefs.remove(_keyLeaderboard);
    }
  }
}
