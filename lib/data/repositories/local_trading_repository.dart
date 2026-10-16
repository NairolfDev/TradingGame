import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/asset.dart';
import '../models/position.dart';
import '../models/transaction.dart';
import '../models/luxury_item.dart';
import '../models/pending_order.dart';
import '../models/leaderboard_entry.dart';
import '../models/loan_model.dart';
import '../mock_data/initial_assets.dart';
import '../mock_data/initial_luxury_items.dart';
import '../mock_data/initial_leaderboard.dart';
import 'trading_repository.dart';

class LocalTradingRepository implements TradingRepository {
  static const String _keyCash = 'tg_cash_balance';
  static const String _keyAssets = 'tg_assets';
  static const String _keyPositions = 'tg_positions';
  static const String _keyTransactions = 'tg_transactions';
  static const String _keyLuxury = 'tg_luxury_items';
  static const String _keyPendingOrders = 'tg_pending_orders';
  static const String _keyLeaderboard = 'tg_leaderboard';
  static const String _keyLoans = 'tg_loans';

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
      final initial = InitialAssets.getAssets();
      await saveAssets(initial);
      return initial;
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => Asset.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return InitialAssets.getAssets();
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

  @override
  Future<List<LuxuryItem>> getLuxuryItems() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyLuxury);
    if (raw == null) {
      final initial = InitialLuxuryItems.getItems();
      await saveLuxuryItems(initial);
      return initial;
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => LuxuryItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return InitialLuxuryItems.getItems();
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
  Future<void> saveLeaderboard(List<LeaderboardEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(entries.map((e) => e.toJson()).toList());
    await prefs.setString(_keyLeaderboard, raw);
  }

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
  Future<void> resetGameToInitial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyCash);
    await prefs.remove(_keyPositions);
    await prefs.remove(_keyTransactions);
    await prefs.remove(_keyPendingOrders);
    await prefs.remove(_keyAssets);
    await prefs.remove(_keyLuxury);
    await prefs.remove(_keyLeaderboard);
    await prefs.remove(_keyLoans);
  }
}
