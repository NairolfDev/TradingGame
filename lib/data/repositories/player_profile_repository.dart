import 'package:cloud_firestore/cloud_firestore.dart';

abstract class PlayerProfileRepository {
  Future<Map<String, dynamic>?> load(String uid);
  Future<void> save(
    String uid, {
    required String displayName,
    required String countryCode,
  });
}

class FirebasePlayerProfileRepository implements PlayerProfileRepository {
  @override
  Future<Map<String, dynamic>?> load(String uid) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('profiles')
        .doc(uid)
        .get();
    return snapshot.data();
  }

  @override
  Future<void> save(
    String uid, {
    required String displayName,
    required String countryCode,
  }) {
    return FirebaseFirestore.instance.collection('profiles').doc(uid).set({
      'displayName': displayName,
      'countryCode': countryCode,
    });
  }
}
