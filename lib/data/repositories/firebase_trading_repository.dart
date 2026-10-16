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
      if (user != null && user.uid.isNotEmpty) {
        return user.uid;
      }
    } catch (_) {}
    return 'local_player';
  }

  // --- CASH BALANCE ---
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
            .set({
          'cash': cash,
          'uid': _currentUserId,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {}
    }
  }

  // --- ASSETS ---
  @override
  Future<List<Asset>> getAssets() async {
    return _fallbackLocal.getAssets();
  }

  @override
  Future<void> saveAssets(List<Asset> assets) async {
    await _fallbackLocal.saveAssets(assets);
  }

  // --- POSITIONS ---
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
            .where((p) => p.amount > 0)
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
          if (pos.amount > 0) {
            batch.set(col.doc(pos.id), pos.toJson(), SetOptions(merge: true));
          } else {
            batch.delete(col.doc(pos.id));
          }
        }
        await batch.commit();
      } catch (_) {}
    }
  }

  // --- TRANSACTIONS ---
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

  // --- LUXURY ITEMS ---
  @override
  Future<List<LuxuryItem>> getLuxuryItems() async {
    if (!_isFirebaseConfigured) return _fallbackLocal.getLuxuryItems();

    try {
      final snap = await FirebaseFirestore.instance
          .collection('portfolios')
          .doc(_currentUserId)
          .collection('luxuryItems')
          .get();

      if (snap.docs.isNotEmpty) {
        final items = snap.docs
            .map((d) => LuxuryItem.fromJson(d.data()))
            .toList();
        await _fallbackLocal.saveLuxuryItems(items);
        return items;
      }
    } catch (_) {}

    return _fallbackLocal.getLuxuryItems();
  }

  @override
  Future<void> saveLuxuryItems(List<LuxuryItem> items) async {
    await _fallbackLocal.saveLuxuryItems(items);

    if (_isFirebaseConfigured) {
      try {
        final batch = FirebaseFirestore.instance.batch();
        final col = FirebaseFirestore.instance
            .collection('portfolios')
            .doc(_currentUserId)
            .collection('luxuryItems');

        for (final item in items) {
          batch.set(col.doc(item.id), item.toJson(), SetOptions(merge: true));
        }
        await batch.commit();
      } catch (_) {}
    }
  }

  // --- PENDING ORDERS ---
  @override
  Future<List<PendingOrder>> getPendingOrders() async {
    if (!_isFirebaseConfigured) return _fallbackLocal.getPendingOrders();

    try {
      final snap = await FirebaseFirestore.instance
          .collection('portfolios')
          .doc(_currentUserId)
          .collection('pendingOrders')
          .get();

      if (snap.docs.isNotEmpty) {
        final orders = snap.docs
            .map((d) => PendingOrder.fromJson(d.data()))
            .toList();
        await _fallbackLocal.savePendingOrders(orders);
        return orders;
      }
    } catch (_) {}

    return _fallbackLocal.getPendingOrders();
  }

  @override
  Future<void> savePendingOrders(List<PendingOrder> orders) async {
    await _fallbackLocal.savePendingOrders(orders);

    if (_isFirebaseConfigured) {
      try {
        final batch = FirebaseFirestore.instance.batch();
        final col = FirebaseFirestore.instance
            .collection('portfolios')
            .doc(_currentUserId)
            .collection('pendingOrders');

        // Overwrite active orders
        for (final order in orders) {
          batch.set(col.doc(order.id), order.toJson(), SetOptions(merge: true));
        }
        await batch.commit();
      } catch (_) {}
    }
  }

  // --- LEADERBOARD (REAL MULTIPLAYER ONLINE RANKING) ---
  @override
  Future<List<LeaderboardEntry>> getLeaderboard() async {
    if (!_isFirebaseConfigured) return _fallbackLocal.getLeaderboard();

    try {
      final snap = await FirebaseFirestore.instance
          .collection('leaderboard')
          .orderBy('netWorth', descending: true)
          .limit(100)
          .get();

      if (snap.docs.isNotEmpty) {
        final myUid = _currentUserId;
        final entries = snap.docs.map((d) {
          final data = d.data();
          final isPlayer = (d.id == myUid || data['id'] == myUid);
          final rawName = data['name'] as String? ?? 'Trader';
          return LeaderboardEntry(
            id: d.id,
            name: isPlayer ? 'Du ($rawName)' : rawName,
            city: data['city'] as String? ?? 'Österreich',
            title: data['title'] as String? ?? 'Retail Trader',
            badge: data['badge'] as String? ?? '📈',
            avatarEmoji: data['avatarEmoji'] as String? ?? '👤',
            strategy: data['strategy'] as String? ?? 'Multi-Asset',
            netWorth: (data['netWorth'] as num?)?.toDouble() ?? 50000.0,
            roiPercent: (data['roiPercent'] as num?)?.toDouble() ?? 0.0,
            isPlayer: isPlayer,
            luxuryCount: (data['luxuryCount'] as num?)?.toInt() ?? 0,
            rank: 0,
          );
        }).toList();

        // Sort descending by netWorth and assign real ranks
        entries.sort((a, b) => b.netWorth.compareTo(a.netWorth));
        for (int i = 0; i < entries.length; i++) {
          entries[i].rank = i + 1;
        }

        await _fallbackLocal.saveLeaderboard(entries);
        return entries;
      }
    } catch (_) {}

    return _fallbackLocal.getLeaderboard();
  }

  @override
  Stream<List<LeaderboardEntry>>? streamLeaderboard() {
    if (!_isFirebaseConfigured) return null;

    try {
      return FirebaseFirestore.instance
          .collection('leaderboard')
          .orderBy('netWorth', descending: true)
          .limit(100)
          .snapshots()
          .map((snap) {
        final myUid = _currentUserId;
        final entries = snap.docs.map((d) {
          final data = d.data();
          final isPlayer = (d.id == myUid || data['id'] == myUid);
          final rawName = data['name'] as String? ?? 'Trader';
          return LeaderboardEntry(
            id: d.id,
            name: isPlayer ? 'Du ($rawName)' : rawName,
            city: data['city'] as String? ?? 'Österreich',
            title: data['title'] as String? ?? 'Retail Trader',
            badge: data['badge'] as String? ?? '📈',
            avatarEmoji: data['avatarEmoji'] as String? ?? '👤',
            strategy: data['strategy'] as String? ?? 'Multi-Asset',
            netWorth: (data['netWorth'] as num?)?.toDouble() ?? 50000.0,
            roiPercent: (data['roiPercent'] as num?)?.toDouble() ?? 0.0,
            isPlayer: isPlayer,
            luxuryCount: (data['luxuryCount'] as num?)?.toInt() ?? 0,
            rank: 0,
          );
        }).toList();

        entries.sort((a, b) => b.netWorth.compareTo(a.netWorth));
        for (int i = 0; i < entries.length; i++) {
          entries[i].rank = i + 1;
        }

        return entries;
      });
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveLeaderboard(List<LeaderboardEntry> entries) async {
    await _fallbackLocal.saveLeaderboard(entries);

    if (_isFirebaseConfigured) {
      try {
        final myUid = _currentUserId;
        final player = entries.firstWhere(
          (e) => e.isPlayer || e.id == myUid,
          orElse: () => entries.first,
        );

        String cleanName = player.name;
        final match = RegExp(r'^Du \((.*)\)$').firstMatch(cleanName);
        if (match != null) {
          cleanName = match.group(1) ?? cleanName;
        } else if (cleanName.startsWith('Du (')) {
          cleanName = cleanName.replaceAll('Du (', '').replaceAll(')', '');
        }
        cleanName = cleanName.trim();
        if (cleanName.isEmpty || cleanName == r'$1') cleanName = 'Trader';

        // 1. Speichere Spieler-Rang im echten Firestore Cloud Leaderboard
        await FirebaseFirestore.instance
            .collection('leaderboard')
            .doc(myUid)
            .set({
          'id': myUid,
          'name': cleanName,
          'city': player.city,
          'title': player.title,
          'badge': player.badge,
          'avatarEmoji': player.avatarEmoji,
          'strategy': player.strategy,
          'netWorth': player.netWorth,
          'roiPercent': player.roiPercent,
          'luxuryCount': player.luxuryCount,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // 2. Speichere Benutzerprofil in /users/{uid}
        await FirebaseFirestore.instance
            .collection('users')
            .doc(myUid)
            .set({
          'uid': myUid,
          'displayName': cleanName,
          'currentRank': player.title,
          'netWorth': player.netWorth,
          'lastActive': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // 3. Speichere Portfolio-Zusammenfassung in /portfolios/{uid}
        await FirebaseFirestore.instance
            .collection('portfolios')
            .doc(myUid)
            .set({
          'uid': myUid,
          'netWorth': player.netWorth,
          'roiPercent': player.roiPercent,
          'rankTitle': player.title,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        // Fallback gracefully on network error
      }
    }
  }

  /// Synchronisiert den lokalen Stand in die Cloud, falls in Firestore noch kein Portfolio existiert
  Future<void> syncUserToCloud({
    required double cash,
    required List<Position> positions,
    required List<TransactionRecord> transactions,
    required List<LuxuryItem> luxuryItems,
    required List<Loan> loans,
    required List<PendingOrder> pendingOrders,
  }) async {
    if (!_isFirebaseConfigured || _currentUserId == 'local_player') return;
    try {
      final doc = await FirebaseFirestore.instance.collection('portfolios').doc(_currentUserId).get();
      if (!doc.exists) {
        await saveCashBalance(cash);
        await savePositions(positions);
        await saveLuxuryItems(luxuryItems);
        await saveLoans(loans);
        await savePendingOrders(pendingOrders);
      }
    } catch (_) {}
  }

  // --- LOANS ---
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

  // --- INSOLVENCY STATUS ---
  @override
  Future<Map<String, dynamic>> getInsolvencyStatus() async {
    if (!_isFirebaseConfigured) return _fallbackLocal.getInsolvencyStatus();

    try {
      final doc = await FirebaseFirestore.instance
          .collection('portfolios')
          .doc(_currentUserId)
          .get();

      if (doc.exists && doc.data()?['insolvency'] != null) {
        final data = doc.data()!['insolvency'] as Map<String, dynamic>;
        await _fallbackLocal.saveInsolvencyStatus(
          isInsolvent: data['isInsolvent'] as bool? ?? false,
          lockoutUntil: data['lockoutUntil'] != null
              ? DateTime.parse(data['lockoutUntil'] as String)
              : null,
          lastLoanTakenAt: data['lastLoanTakenAt'] != null
              ? DateTime.parse(data['lastLoanTakenAt'] as String)
              : null,
        );
        return data;
      }
    } catch (_) {}

    return _fallbackLocal.getInsolvencyStatus();
  }

  @override
  Future<void> saveInsolvencyStatus({
    required bool isInsolvent,
    DateTime? lockoutUntil,
    DateTime? lastLoanTakenAt,
  }) async {
    await _fallbackLocal.saveInsolvencyStatus(
      isInsolvent: isInsolvent,
      lockoutUntil: lockoutUntil,
      lastLoanTakenAt: lastLoanTakenAt,
    );

    if (_isFirebaseConfigured) {
      try {
        await FirebaseFirestore.instance
            .collection('portfolios')
            .doc(_currentUserId)
            .set({
          'insolvency': {
            'isInsolvent': isInsolvent,
            'lockoutUntil': lockoutUntil?.toIso8601String(),
            'lastLoanTakenAt': lastLoanTakenAt?.toIso8601String(),
          }
        }, SetOptions(merge: true));
      } catch (_) {}
    }
  }

  // --- RESET GAME ---
  @override
  Future<void> resetGameToInitial() async {
    await _fallbackLocal.resetGameToInitial();

    if (_isFirebaseConfigured) {
      try {
        await FirebaseFirestore.instance
            .collection('portfolios')
            .doc(_currentUserId)
            .delete();
        await FirebaseFirestore.instance
            .collection('leaderboard')
            .doc(_currentUserId)
            .delete();
      } catch (_) {}
    }
  }
}
