import '../models/asset.dart';
import '../models/position.dart';
import '../models/transaction.dart';
import '../models/luxury_item.dart';
import '../models/pending_order.dart';
import '../models/leaderboard_entry.dart';
import '../models/loan_model.dart';

abstract class TradingRepository {
  Future<double> getCashBalance();
  Future<void> saveCashBalance(double cash);

  Future<List<Asset>> getAssets();
  Future<void> saveAssets(List<Asset> assets);

  Future<List<Position>> getPositions();
  Future<void> savePositions(List<Position> positions);

  Future<List<TransactionRecord>> getTransactions();
  Future<void> saveTransaction(TransactionRecord transaction);

  Future<List<LuxuryItem>> getLuxuryItems();
  Future<void> saveLuxuryItems(List<LuxuryItem> items);

  Future<List<PendingOrder>> getPendingOrders();
  Future<void> savePendingOrders(List<PendingOrder> orders);

  Future<List<LeaderboardEntry>> getLeaderboard();
  Future<void> saveLeaderboard(List<LeaderboardEntry> entries);
  Stream<List<LeaderboardEntry>>? streamLeaderboard() => null;

  Future<List<Loan>> getLoans();
  Future<void> saveLoans(List<Loan> loans);

  Future<Map<String, dynamic>> getInsolvencyStatus();
  Future<void> saveInsolvencyStatus({
    required bool isInsolvent,
    DateTime? lockoutUntil,
    DateTime? lastLoanTakenAt,
  });

  Future<void> resetGameToInitial();
}
