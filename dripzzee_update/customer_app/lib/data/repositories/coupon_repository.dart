import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/coupon.dart';

class CouponRepository {
  CouponRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  /// Active coupons to show as suggestions at checkout.
  Future<List<Coupon>> fetchAvailable() async {
    final snap = await _db
        .collection('coupons')
        .where('active', isEqualTo: true)
        .limit(20)
        .get();
    final now = DateTime.now();
    return snap.docs
        .map((d) => Coupon.fromMap(d.id, d.data()))
        .where((c) => c.expiresAt == null || c.expiresAt!.isAfter(now))
        .toList();
  }

  /// Looks up a code typed by the customer (case-insensitive).
  Future<Coupon?> find(String code) async {
    final clean = code.trim().toUpperCase();
    if (clean.isEmpty || clean.contains('/')) return null;
    final snap = await _db.collection('coupons').doc(clean).get();
    return snap.exists ? Coupon.fromMap(snap.id, snap.data()!) : null;
  }
}
