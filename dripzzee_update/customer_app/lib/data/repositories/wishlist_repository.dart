import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/product.dart';
import '../models/wishlist_entry.dart';

/// users/{uid}/wishlist/{productId}. Stored server-side so restock
/// notifications (Cloud Function) know who saved what.
class WishlistRepository {
  WishlistRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection('wishlist');

  Stream<List<WishlistEntry>> watch(String uid) => _col(uid).snapshots().map(
        (s) {
          final list = s.docs
              .map((d) => WishlistEntry.fromMap(d.id, d.data()))
              .toList()
            ..sort((a, b) => (b.addedAt ?? DateTime(2000))
                .compareTo(a.addedAt ?? DateTime(2000)));
          return list;
        },
      );

  Future<void> add(String uid, Product p) => _col(uid).doc(p.id).set({
        'productId': p.id,
        'storeId': p.storeId,
        'storeName': p.storeName,
        'name': p.name,
        'imageUrl': p.primaryImage,
        'price': p.price,
        'addedAt': FieldValue.serverTimestamp(),
      });

  Future<void> remove(String uid, String productId) =>
      _col(uid).doc(productId).delete();
}
