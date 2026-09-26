import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/order.dart';
import '../models/return_request.dart';

/// return_requests/{orderId} — shared with the retailer app's Returns tab.
class ReturnRepository {
  ReturnRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('return_requests');

  Future<void> submit({
    required DripOrder order,
    required String type,
    required List<ReturnRequestItem> items,
    required String reason,
    required String details,
  }) =>
      _col.doc(order.id).set({
        'orderId': order.id,
        'customerId': order.customerId,
        'storeId': order.storeId,
        'storeName': order.storeName,
        'type': type,
        'items': items.map((i) => i.toMap()).toList(),
        'reason': reason,
        'details': details.trim(),
        'status': 'REQUESTED',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Stream<List<ReturnRequest>> watchForCustomer(String uid) => _col
      .where('customerId', isEqualTo: uid)
      .snapshots()
      .map((s) {
        final list = s.docs
            .map((d) => ReturnRequest.fromMap(d.id, d.data()))
            .toList()
          ..sort((a, b) => (b.createdAt ?? DateTime(2000))
              .compareTo(a.createdAt ?? DateTime(2000)));
        return list;
      });
}
