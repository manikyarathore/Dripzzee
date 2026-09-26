import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../data/catalog_search.dart';
import '../data/models/catalog_filter.dart';
import '../data/models/product.dart';
import '../data/models/saved_location.dart';
import '../data/models/store.dart';
import '../data/repositories/catalog_repository.dart';

enum LoadState { idle, loading, ready, error }

/// Holds the "fashion around you" catalog for the selected location: nearby
/// stores and their products. Home, categories, campaigns and search are all
/// views over this single source of truth.
class CatalogController extends ChangeNotifier {
  CatalogController(this._repo);

  final CatalogRepository _repo;

  LoadState _state = LoadState.idle;
  String? _error;
  List<Store> _stores = const [];
  List<Product> _products = const [];
  Map<String, Store> _storeIndex = const {};
  SavedLocation? _location;
  int _generation = 0;

  LoadState get state => _state;
  String? get error => _error;
  List<Store> get stores => _stores;
  List<Product> get products => _products;
  SavedLocation? get location => _location;
  CatalogRepository get repository => _repo;

  bool get isEmpty => _state == LoadState.ready && _stores.isEmpty;

  /// Wired to LocationController through a ProxyProvider.
  void onLocationChanged(SavedLocation? location) {
    if (location == null) {
      if (_location != null) {
        _location = null;
        scheduleMicrotask(_reset);
      }
      return;
    }
    final prev = _location;
    if (prev != null &&
        prev.lat == location.lat &&
        prev.lng == location.lng) {
      return;
    }
    _location = location;
    scheduleMicrotask(load);
  }

  void _reset() {
    _generation++;
    _state = LoadState.idle;
    _stores = const [];
    _products = const [];
    _storeIndex = const {};
    notifyListeners();
  }

  Future<void> load() async {
    final location = _location;
    if (location == null) return;
    final generation = ++_generation;
    _state = LoadState.loading;
    _error = null;
    notifyListeners();
    try {
      final stores = await _repo.fetchNearbyStores(location);
      final products =
          await _repo.fetchProductsForStores(stores.map((s) => s.id).toList());
      if (generation != _generation) return;
      _stores = stores;
      _storeIndex = {for (final s in stores) s.id: s};
      _products = products;
      _state = LoadState.ready;
    } catch (e) {
      if (generation != _generation) return;
      _error = describeError(e);
      _state = LoadState.error;
    }
    notifyListeners();
  }

  Future<void> refresh() => load();

  Store? storeById(String id) => _storeIndex[id];
  double? distanceTo(String storeId) => _storeIndex[storeId]?.distanceKm;

  Map<String, double> get _distances => {
        for (final s in _stores)
          if (s.distanceKm != null) s.id: s.distanceKm!,
      };

  List<Product> productsFor(ProductFilter filter, {ProductSort? sort}) =>
      sortProducts(
        _products.where(filter.matches),
        sort ?? filter.sort,
        storeDistances: _distances,
      );

  List<Product> recommended({int limit = 12}) => sortProducts(
        _products.where((p) => p.inStock),
        ProductSort.popular,
      ).take(limit).toList();

  /// A varied mix of everything nearby that changes daily but stays stable
  /// while scrolling. In-stock items first.
  List<Product> discover({int limit = 40}) {
    final now = DateTime.now();
    final daySeed = now.year * 1000 + now.month * 50 + now.day;
    int score(Product p) => Object.hash(p.id, daySeed);
    final list = _products.where((p) => p.active).toList()
      ..sort((a, b) {
        final stock = (b.inStock ? 1 : 0) - (a.inStock ? 1 : 0);
        return stock != 0 ? stock : score(a).compareTo(score(b));
      });
    return list.take(limit).toList();
  }

  List<Product> newArrivals({int limit = 12}) => sortProducts(
        _products.where((p) => p.inStock),
        ProductSort.newest,
      ).take(limit).toList();

  List<Product> storeProducts(String storeId) => sortProducts(
        _products.where((p) => p.storeId == storeId),
        ProductSort.popular,
      );

  List<Store> storesFor(StoreFilter filter, StoreSort sort) =>
      sortStores(_stores.where(filter.matches), sort);

  int countStoresWithTag(String tag) =>
      _stores.where((s) => s.tags.contains(tag)).length;

  SearchResults search(String query) =>
      searchCatalog(query, _products, _stores);

  static String describeError(Object e) {
    if (e is FirebaseException) {
      switch (e.code) {
        case 'unavailable':
          return 'You seem to be offline. Check your connection and try again.';
        case 'permission-denied':
          return 'Access to the catalog was denied. Make sure the Firestore rules are deployed.';
        case 'failed-precondition':
          return 'The database needs an index that isn\'t deployed yet.';
      }
      return e.message ?? 'Couldn\'t load stores near you.';
    }
    return 'Couldn\'t load stores near you. Please try again.';
  }
}
