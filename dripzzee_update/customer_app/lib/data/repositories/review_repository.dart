import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/order.dart';

/// reviews/{orderId} — one review per delivered order. A Cloud Function
/// aggregates it into the store's rating.
class ReviewRepository {
  ReviewRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Future<void> submit({
    required DripOrder order,
    required int rating,
    required String comment,
    required String customerName,
  }) =>
      _db.collection('reviews').doc(order.id).set({
        'orderId': order.id,
        'customerId': order.customerId,
        'storeId': order.storeId,
        'rating': rating,
        'comment': comment.trim(),
        'customerName': customerName.isEmpty ? 'Shopper' : customerName,
        'createdAt': FieldValue.serverTimestamp(),
      });

  Future<bool> exists(String orderId) async =>
      (await _db.collection('reviews').doc(orderId).get()).exists;
}
