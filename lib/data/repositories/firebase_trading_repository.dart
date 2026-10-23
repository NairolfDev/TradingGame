import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/asset.dart';
import '../models/automation_order.dart';
import '../models/position.dart';
import '../models/savings_plan.dart';
import '../models/transaction.dart';
import '../models/luxury_item.dart';
import '../models/pending_order.dart';
import '../models/leaderboard_entry.dart';
import '../models/loan_model.dart';
import '../mock_data/initial_luxury_items.dart';
import 'trading_repository.dart';
import 'local_trading_repository.dart';

class FirebaseTradingRepository implements TradingRepository {
  final String userId;
  FirebaseTradingRepository({String? userId})
    : userId = userId ?? _sessionUid();
  static String _sessionUid() {
    try {
      return FirebaseAuth.instance.currentUser?.uid ?? 'local_player';
    } catch (_) {
      return 'local_player';
    }
  }

  LocalTradingRepository get _fallbackLocal =>
      LocalTradingRepository(_currentUserId);

  bool get _isFirebaseConfigured {
    try {
      return FirebaseFirestore.instance.app.name.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // Bind every asynchronous operation to the account that started it.
  String get _currentUserId => userId;

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

      final positions = snap.docs
          .map((d) => Position.fromJson(d.data()))
          .where((p) => p.amount > 0)
          .toList();
      await _fallbackLocal.savePositions(positions);
      return positions;
    } catch (_) {}

    return _fallbackLocal.getPositions();
  }

  @override
  Future<void> savePositions(List<Position> positions) async {
    await _fallbackLocal.savePositions(positions);

    if (_isFirebaseConfigured) {
      try {
        final col = FirebaseFirestore.instance
            .collection('portfolios')
            .doc(_currentUserId)
            .collection('positions');

        final activeIds = positions
            .where((p) => p.amount > 0)
            .map((p) => p.id)
            .toSet();
        final existingSnap = await col.get();
        final batch = FirebaseFirestore.instance.batch();

        for (final doc in existingSnap.docs) {
          if (!activeIds.contains(doc.id)) {
            batch.delete(doc.reference);
          }
        }

        for (final pos in positions) {
          if (pos.amount > 0) {
            batch.set(col.doc(pos.id), pos.toJson(), SetOptions(merge: true));
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

      final list = snap.docs
          .map((d) => TransactionRecord.fromJson(d.data()))
          .toList();
      await _fallbackLocal.saveAllTransactions(list);
      return list;
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
        final catalog = InitialLuxuryItems.getItems();
        final cloudItems = snap.docs
            .map((d) => LuxuryItem.fromJson(d.data()))
            .toList();
        final cloudMap = {for (final item in cloudItems) item.id: item};
        final merged = catalog.map((catItem) {
          if (cloudMap.containsKey(catItem.id)) {
            return catItem.copyWith(
              ownedCount: cloudMap[catItem.id]!.ownedCount,
            );
          }
          return catItem;
        }).toList();

        await _fallbackLocal.saveLuxuryItems(merged);
        return merged;
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

      final orders = snap.docs
          .map((d) => PendingOrder.fromJson(d.data()))
          .toList();
      await _fallbackLocal.savePendingOrders(orders);
      return orders;
    } catch (_) {}

    return _fallbackLocal.getPendingOrders();
  }

  @override
  Future<void> savePendingOrders(List<PendingOrder> orders) async {
    await _fallbackLocal.savePendingOrders(orders);

    if (_isFirebaseConfigured) {
      try {
        final col = FirebaseFirestore.instance
            .collection('portfolios')
            .doc(_currentUserId)
            .collection('pendingOrders');

        final activeIds = orders.map((o) => o.id).toSet();
        final existingSnap = await col.get();
        final batch = FirebaseFirestore.instance.batch();

        for (final doc in existingSnap.docs) {
          if (!activeIds.contains(doc.id)) {
            batch.delete(doc.reference);
          }
        }

        // Overwrite active orders
        for (final order in orders) {
          batch.set(col.doc(order.id), order.toJson(), SetOptions(merge: true));
        }
        await batch.commit();
      } catch (_) {}
    }
  }

  // --- LEADERBOARD (REAL MULTIPLAYER ONLINE RANKING) ---
  /// Only docs written by signed-in, named players count; older guest or
  /// unnamed docs (no `verified` flag) stay hidden.
  static bool _isRankedDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) =>
      d.data()['verified'] == true;

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
        final entries = snap.docs.where(_isRankedDoc).map((d) {
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
            weeklyRoiPercent: (data['weeklyRoiPercent'] as num?)?.toDouble(),
            monthlyRoiPercent: (data['monthlyRoiPercent'] as num?)?.toDouble(),
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
            final entries = snap.docs.where(_isRankedDoc).map((d) {
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
                weeklyRoiPercent:
                    (data['weeklyRoiPercent'] as num?)?.toDouble(),
                monthlyRoiPercent:
                    (data['monthlyRoiPercent'] as num?)?.toDouble(),
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

  DateTime? _lastLeaderboardCloudSave;

  @override
  Future<void> saveLeaderboard(
    List<LeaderboardEntry> entries, {
    bool forceCloud = false,
  }) async {
    await _fallbackLocal.saveLeaderboard(entries);

    if (_isFirebaseConfigured) {
      final now = DateTime.now();
      if (!forceCloud &&
          _lastLeaderboardCloudSave != null &&
          now.difference(_lastLeaderboardCloudSave!).inSeconds < 30) {
        return;
      }
      _lastLeaderboardCloudSave = now;

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
              if (player.weeklyRoiPercent != null)
                'weeklyRoiPercent': player.weeklyRoiPercent,
              if (player.monthlyRoiPercent != null)
                'monthlyRoiPercent': player.monthlyRoiPercent,
              'luxuryCount': player.luxuryCount,
              'verified': true,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));

        // 2. Speichere Benutzerprofil in /users/{uid}
        await FirebaseFirestore.instance.collection('users').doc(myUid).set({
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
      final doc = await FirebaseFirestore.instance
          .collection('portfolios')
          .doc(_currentUserId)
          .get();
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

      final loans = snap.docs.map((d) => Loan.fromJson(d.data())).toList();
      await _fallbackLocal.saveLoans(loans);
      return loans;
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
              },
            }, SetOptions(merge: true));
      } catch (_) {}
    }
  }

  // --- CLOUD AUTOMATION & SAVINGS PLANS ---
  @override
  Future<({int unlockedSlotsCount, List<AutomationOrder> orders})?>
  getCloudAutomationState() async {
    if (!_isFirebaseConfigured || _currentUserId == 'local_player') return null;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('portfolios')
          .doc(_currentUserId)
          .get();
      if (!doc.exists) return null;
      final data = doc.data();
      if (data == null || !data.containsKey('automation')) return null;
      final auto = data['automation'] as Map<String, dynamic>;
      final slots = (auto['unlockedSlotsCount'] as num?)?.toInt() ?? 1;
      final rawOrders = (auto['orders'] as List<dynamic>?) ?? const [];
      final orders = rawOrders
          .whereType<Map<String, dynamic>>()
          .map(AutomationOrder.fromJson)
          .toList();
      return (unlockedSlotsCount: slots, orders: orders);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveCloudAutomationState({
    required int unlockedSlotsCount,
    required List<AutomationOrder> orders,
  }) async {
    if (!_isFirebaseConfigured || _currentUserId == 'local_player') return;
    try {
      await FirebaseFirestore.instance
          .collection('portfolios')
          .doc(_currentUserId)
          .set({
            'automation': {
              'unlockedSlotsCount': unlockedSlotsCount,
              'orders': orders.map((o) => o.toJson()).toList(),
            },
          }, SetOptions(merge: true));
    } catch (_) {}
  }

  @override
  Future<List<SavingsPlan>?> getCloudSavingsPlans() async {
    if (!_isFirebaseConfigured || _currentUserId == 'local_player') return null;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('portfolios')
          .doc(_currentUserId)
          .get();
      if (!doc.exists) return null;
      final data = doc.data();
      if (data == null || !data.containsKey('savingsPlans')) return null;
      final list = (data['savingsPlans'] as List<dynamic>?) ?? const [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(SavingsPlan.fromJson)
          .toList();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveCloudSavingsPlans(List<SavingsPlan> plans) async {
    if (!_isFirebaseConfigured || _currentUserId == 'local_player') return;
    try {
      await FirebaseFirestore.instance
          .collection('portfolios')
          .doc(_currentUserId)
          .set({
            'savingsPlans': plans.map((p) => p.toJson()).toList(),
          }, SetOptions(merge: true));
    } catch (_) {}
  }

  // --- RESET GAME ---
  @override
  Future<void> resetGameToInitial() async {
    await _fallbackLocal.resetGameToInitial();

    if (_isFirebaseConfigured) {
      try {
        final portfolioDoc = FirebaseFirestore.instance
            .collection('portfolios')
            .doc(_currentUserId);

        final positionsSnap = await portfolioDoc.collection('positions').get();
        final ordersSnap = await portfolioDoc.collection('pendingOrders').get();
        final loansSnap = await portfolioDoc.collection('loans').get();

        final batch = FirebaseFirestore.instance.batch();
        for (final d in positionsSnap.docs) {
          batch.delete(d.reference);
        }
        for (final d in ordersSnap.docs) {
          batch.delete(d.reference);
        }
        for (final d in loansSnap.docs) {
          batch.delete(d.reference);
        }
        batch.delete(portfolioDoc);
        batch.delete(
          FirebaseFirestore.instance
              .collection('leaderboard')
              .doc(_currentUserId),
        );
        await batch.commit();
      } catch (_) {}
    }
  }
}
