import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/asset.dart';
import '../models/position.dart';
import '../models/transaction.dart';
import '../models/luxury_item.dart';
import '../models/pending_order.dart';
import '../models/leaderboard_entry.dart';
import '../models/loan_model.dart';
import 'trading_repository.dart';
import 'local_trading_repository.dart';

class FirebaseTradingRepository implements TradingRepository {
  final LocalTradingRepository _fallbackLocal = LocalTradingRepository();

  bool get _isFirebaseConfigured {
    try {
      return FirebaseFirestore.instance.app.name.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  String get _currentUserId {
    try {
      final user = FirebaseAuth.instance.currentUser;
      return user?.uid ?? 'local_user';
    } catch (_) {
      return 'local_user';
    }
  }

  @override
  Future<double> getCashBalance() async {
    if (!_isFirebaseConfigured) return _fallbackLocal.getCashBalance();

    try {
      final doc = await FirebaseFirestore.instance
          .collection('portfolios')
          .doc(_currentUserId)
          .get();

      if (doc.exists && doc.data()?['cash'] != null) {
        final cash = (doc.data()!['cash'] as num).toDouble();
        await _fallbackLocal.saveCashBalance(cash);
        return cash;
      }
    } catch (_) {}

    return _fallbackLocal.getCashBalance();
  }

  @override
  Future<void> saveCashBalance(double cash) async {
    await _fallbackLocal.saveCashBalance(cash);

    if (_isFirebaseConfigured) {
      try {
        await FirebaseFirestore.instance
            .collection('portfolios')
            .doc(_currentUserId)
            .set({'cash': cash, 'updatedAt': FieldValue.serverTimestamp()},
                SetOptions(merge: true));
      } catch (_) {}
    }
  }

  @override
  Future<List<Asset>> getAssets() async {
    return _fallbackLocal.getAssets();
  }

  @override
  Future<void> saveAssets(List<Asset> assets) async {
    await _fallbackLocal.saveAssets(assets);
  }

  @override
  Future<List<Position>> getPositions() async {
    if (!_isFirebaseConfigured) return _fallbackLocal.getPositions();

    try {
      final snap = await FirebaseFirestore.instance
          .collection('portfolios')
          .doc(_currentUserId)
          .collection('positions')
          .get();

      if (snap.docs.isNotEmpty) {
        final positions = snap.docs
            .map((d) => Position.fromJson(d.data()))
            .toList();
        await _fallbackLocal.savePositions(positions);
        return positions;
      }
    } catch (_) {}

    return _fallbackLocal.getPositions();
  }

  @override
  Future<void> savePositions(List<Position> positions) async {
    await _fallbackLocal.savePositions(positions);

    if (_isFirebaseConfigured) {
      try {
        final batch = FirebaseFirestore.instance.batch();
        final col = FirebaseFirestore.instance
            .collection('portfolios')
            .doc(_currentUserId)
            .collection('positions');

        for (final pos in positions) {
          batch.set(col.doc(pos.id), pos.toJson(), SetOptions(merge: true));
        }
        await batch.commit();
      } catch (_) {}
    }
  }

  @override
  Future<List<TransactionRecord>> getTransactions() async {
    if (!_isFirebaseConfigured) return _fallbackLocal.getTransactions();

    try {
      final snap = await FirebaseFirestore.instance
          .collection('portfolios')
          .doc(_currentUserId)
          .collection('transactions')
          .orderBy('timestamp', descending: true)
          .limit(100)
          .get();

      if (snap.docs.isNotEmpty) {
        final list = snap.docs
            .map((d) => TransactionRecord.fromJson(d.data()))
            .toList();
        return list;
      }
    } catch (_) {}

    return _fallbackLocal.getTransactions();
  }

  @override
  Future<void> saveTransaction(TransactionRecord transaction) async {
    await _fallbackLocal.saveTransaction(transaction);

    if (_isFirebaseConfigured) {
      try {
        await FirebaseFirestore.instance
            .collection('portfolios')
            .doc(_currentUserId)
            .collection('transactions')
            .doc(transaction.id)
            .set(transaction.toJson());
      } catch (_) {}
    }
  }

  @override
  Future<List<LuxuryItem>> getLuxuryItems() async {
    return _fallbackLocal.getLuxuryItems();
  }

  @override
  Future<void> saveLuxuryItems(List<LuxuryItem> items) async {
    await _fallbackLocal.saveLuxuryItems(items);
  }

  @override
  Future<List<PendingOrder>> getPendingOrders() async {
    return _fallbackLocal.getPendingOrders();
  }

  @override
  Future<void> savePendingOrders(List<PendingOrder> orders) async {
    await _fallbackLocal.savePendingOrders(orders);
  }

  @override
  Future<List<LeaderboardEntry>> getLeaderboard() async {
    if (!_isFirebaseConfigured) return _fallbackLocal.getLeaderboard();

    try {
      final snap = await FirebaseFirestore.instance
          .collection('leaderboard')
          .orderBy('netWorth', descending: true)
          .limit(50)
          .get();

      if (snap.docs.isNotEmpty) {
        final entries = snap.docs.map((d) {
          final data = d.data();
          return LeaderboardEntry.fromJson(data);
        }).toList();

        await _fallbackLocal.saveLeaderboard(entries);
        return entries;
      }
    } catch (_) {}

    return _fallbackLocal.getLeaderboard();
  }

  @override
  Future<void> saveLeaderboard(List<LeaderboardEntry> entries) async {
    await _fallbackLocal.saveLeaderboard(entries);

    if (_isFirebaseConfigured) {
      try {
        final batch = FirebaseFirestore.instance.batch();
        final col = FirebaseFirestore.instance.collection('leaderboard');

        for (final entry in entries) {
          batch.set(col.doc(entry.id), entry.toJson(), SetOptions(merge: true));
        }
        await batch.commit();
      } catch (_) {}
    }
  }

  @override
  Future<List<Loan>> getLoans() async {
    if (!_isFirebaseConfigured) return _fallbackLocal.getLoans();

    try {
      final snap = await FirebaseFirestore.instance
          .collection('portfolios')
          .doc(_currentUserId)
          .collection('loans')
          .get();

      if (snap.docs.isNotEmpty) {
        final loans = snap.docs.map((d) => Loan.fromJson(d.data())).toList();
        await _fallbackLocal.saveLoans(loans);
        return loans;
      }
    } catch (_) {}

    return _fallbackLocal.getLoans();
  }

  @override
  Future<void> saveLoans(List<Loan> loans) async {
    await _fallbackLocal.saveLoans(loans);

    if (_isFirebaseConfigured) {
      try {
        final batch = FirebaseFirestore.instance.batch();
        final col = FirebaseFirestore.instance
            .collection('portfolios')
            .doc(_currentUserId)
            .collection('loans');

        for (final loan in loans) {
          batch.set(col.doc(loan.id), loan.toJson(), SetOptions(merge: true));
        }
        await batch.commit();
      } catch (_) {}
    }
  }

  @override
  Future<void> resetGameToInitial() async {
    await _fallbackLocal.resetGameToInitial();

    if (_isFirebaseConfigured) {
      try {
        await FirebaseFirestore.instance
            .collection('portfolios')
            .doc(_currentUserId)
            .delete();
      } catch (_) {}
    }
  }
}
