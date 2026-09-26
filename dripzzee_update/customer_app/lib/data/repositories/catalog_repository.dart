import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/config/app_config.dart';
import '../../core/utils/geo.dart';
import '../models/product.dart';
import '../models/review.dart';
import '../models/saved_location.dart';
import '../models/store.dart';

/// Read-only access to stores, products and store reviews.
class CatalogRepository {
  CatalogRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _stores =>
      _db.collection('stores');
  CollectionReference<Map<String, dynamic>> get _products =>
      _db.collection('products');

  /// Bounding-box query on latitude (single-field index, no composite index
  /// needed), then exact distance filtering on the device.
  Future<List<Store>> fetchNearbyStores(
    SavedLocation location, {
    double radiusKm = AppConfig.nearbyRadiusKm,
  }) async {
    final latDelta = radiusKm / 111.0;
    final snap = await _stores
        .where(
          'lat',
          isGreaterThanOrEqualTo: location.lat - latDelta,
          isLessThanOrEqualTo: location.lat + latDelta,
        )
        .get();

    final stores = <Store>[];
    for (final doc in snap.docs) {
      final store = Store.fromMap(doc.id, doc.data());
      if (!store.active || store.lat == null || store.lng == null) continue;
      final km = distanceKm(location.lat, location.lng, store.lat!, store.lng!);
      if (km <= radiusKm) stores.add(store.withDistance(km));
    }
    stores.sort((a, b) => a.distanceKm!.compareTo(b.distanceKm!));
    return stores;
  }

  /// Products for the given stores, batched to Firestore's `whereIn` limit.
  Future<List<Product>> fetchProductsForStores(List<String> storeIds) async {
    if (storeIds.isEmpty) return [];
    final futures = <Future<QuerySnapshot<Map<String, dynamic>>>>[];
    for (var i = 0; i < storeIds.length; i += 30) {
      final chunk = storeIds.sublist(
        i,
        i + 30 > storeIds.length ? storeIds.length : i + 30,
      );
      futures.add(_products.where('storeId', whereIn: chunk).get());
    }
    final snaps = await Future.wait(futures);
    return [
      for (final s in snaps)
        for (final d in s.docs) Product.fromMap(d.id, d.data()),
    ].where((p) => p.active).toList();
  }

  Future<Store?> fetchStore(String id) async {
    final snap = await _stores.doc(id).get();
    if (!snap.exists) return null;
    return Store.fromMap(snap.id, snap.data()!);
  }

  Stream<Product?> watchProduct(String id) => _products.doc(id).snapshots().map(
        (s) => s.exists ? Product.fromMap(s.id, s.data()!) : null,
      );

  Future<List<Product>> fetchProductsByIds(List<String> ids) async {
    final unique = ids.toSet().toList();
    if (unique.isEmpty) return [];
    final futures = <Future<QuerySnapshot<Map<String, dynamic>>>>[];
    for (var i = 0; i < unique.length; i += 30) {
      final chunk = unique.sublist(
        i,
        i + 30 > unique.length ? unique.length : i + 30,
      );
      futures.add(_products.where(FieldPath.documentId, whereIn: chunk).get());
    }
    final snaps = await Future.wait(futures);
    return [
      for (final s in snaps)
        for (final d in s.docs) Product.fromMap(d.id, d.data()),
    ];
  }

  Future<List<Review>> fetchStoreReviews(String storeId) async {
    final snap =
        await _db.collection('reviews').where('storeId', isEqualTo: storeId).limit(40).get();
    final list = snap.docs.map((d) => Review.fromMap(d.id, d.data())).toList()
      ..sort((a, b) => (b.createdAt ?? DateTime(2000))
          .compareTo(a.createdAt ?? DateTime(2000)));
    return list.take(10).toList();
  }
}
