import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/copy_trader.dart';

/// Portfolios that players chose to make public (`publicPortfolios/{uid}`).
abstract class PublicPortfolioRepository {
  Stream<List<CopyTrader>> watch();
  Future<void> publish(CopyTrader trader);
  Future<void> unpublish(String uid);
}

class FirestorePublicPortfolioRepository implements PublicPortfolioRepository {
  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('publicPortfolios');

  @override
  Stream<List<CopyTrader>> watch() => _col
      .orderBy('roiPercent', descending: true)
      .limit(50)
      .snapshots()
      .map(
        (s) => [
          for (final d in s.docs) ?_parse(d.id, d.data()),
        ],
      );

  static CopyTrader? _parse(String id, Map<String, dynamic> d) {
    try {
      return CopyTrader(
        id: id,
        name: d['name'] as String,
        title: d['title'] as String? ?? '',
        avatarEmoji: d['avatarEmoji'] as String? ?? '👤',
        netWorth: (d['netWorth'] as num).toDouble(),
        roiPercent: (d['roiPercent'] as num).toDouble(),
        winRatePercent: (d['winRatePercent'] as num?)?.toDouble() ?? 0,
        bio: '',
        riskStyle: d['riskStyle'] as String? ?? 'Ausgewogen',
        portfolioAllocation: {
          for (final e in (d['allocation'] as Map).entries)
            e.key as String: (e.value as num).toDouble(),
        },
        followersCount: 0,
      );
    } catch (_) {
      return null; // a malformed document never breaks the list
    }
  }

  @override
  Future<void> publish(CopyTrader t) => _col.doc(t.id).set({
    'uid': t.id,
    'name': t.name,
    'title': t.title,
    'avatarEmoji': t.avatarEmoji,
    'netWorth': t.netWorth,
    'roiPercent': t.roiPercent,
    'winRatePercent': t.winRatePercent,
    'riskStyle': t.riskStyle,
    'allocation': t.portfolioAllocation,
    'updatedAt': DateTime.now().millisecondsSinceEpoch,
  });

  @override
  Future<void> unpublish(String uid) => _col.doc(uid).delete();
}
