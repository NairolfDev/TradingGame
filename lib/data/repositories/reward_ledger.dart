import 'package:cloud_firestore/cloud_firestore.dart';

enum ClaimResult { granted, alreadyClaimed, failed }

/// One record per account of every reward that was paid out, so a bonus is
/// paid once even when the same account plays on web, Android and Windows.
abstract class RewardLedger {
  /// Reserves [key] for this account. Only [ClaimResult.granted] pays out.
  Future<ClaimResult> claim(String key);

  /// Keys already paid out on any device.
  Future<Set<String>> claimed();
}

/// Guests and offline play: the device is the only place that can pay out.
class LocalRewardLedger implements RewardLedger {
  @override
  Future<ClaimResult> claim(String key) async => ClaimResult.granted;

  @override
  Future<Set<String>> claimed() async => const {};
}

/// `portfolios/{uid}/meta/rewards.claimed` (array of keys), checked and
/// extended in one transaction so two devices cannot both win the race.
class FirestoreRewardLedger implements RewardLedger {
  final String uid;
  final FirebaseFirestore? _override;
  FirestoreRewardLedger(this.uid, {FirebaseFirestore? firestore})
    : _override = firestore;

  DocumentReference<Map<String, dynamic>> get _doc =>
      (_override ?? FirebaseFirestore.instance)
          .collection('portfolios')
          .doc(uid)
          .collection('meta')
          .doc('rewards');

  @override
  Future<ClaimResult> claim(String key) async {
    try {
      final db = _override ?? FirebaseFirestore.instance;
      return await db
          .runTransaction<ClaimResult>((tx) async {
            final snap = await tx.get(_doc);
            final list = (snap.data()?['claimed'] as List?) ?? const [];
            if (list.contains(key)) return ClaimResult.alreadyClaimed;
            tx.set(_doc, {
              'claimed': FieldValue.arrayUnion([key]),
            }, SetOptions(merge: true));
            return ClaimResult.granted;
          })
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      // Offline or blocked: no payout now, the next check tries again.
      return ClaimResult.failed;
    }
  }

  @override
  Future<Set<String>> claimed() async {
    try {
      final snap = await _doc.get().timeout(const Duration(seconds: 8));
      return {...((snap.data()?['claimed'] as List?) ?? const []).cast<String>()};
    } catch (_) {
      return const {};
    }
  }
}
