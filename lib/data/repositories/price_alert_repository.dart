import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/price_alert.dart';

abstract class PriceAlertRepository {
  Stream<List<PriceAlert>> watch(String uid);
  Future<void> add(PriceAlert alert);
  Future<void> update(String id, Map<String, dynamic> data);
  Future<void> remove(String id);
}

class FirestorePriceAlertRepository implements PriceAlertRepository {
  final FirebaseFirestore? _override;
  FirestorePriceAlertRepository({FirebaseFirestore? firestore})
    : _override = firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      (_override ?? FirebaseFirestore.instance).collection('priceAlerts');

  @override
  Stream<List<PriceAlert>> watch(String uid) => _col
      .where('uid', isEqualTo: uid)
      .snapshots()
      .map(
        (s) =>
            s.docs.map((d) => PriceAlert.fromJson(d.id, d.data())).toList()
              ..sort((a, b) => a.symbol.compareTo(b.symbol)),
      );

  @override
  Future<void> add(PriceAlert alert) => _col.add(alert.toCreateJson());

  @override
  Future<void> update(String id, Map<String, dynamic> data) =>
      _col.doc(id).update(data);

  @override
  Future<void> remove(String id) => _col.doc(id).delete();
}
