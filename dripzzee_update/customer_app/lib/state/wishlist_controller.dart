import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/models/product.dart';
import '../data/models/wishlist_entry.dart';
import '../data/repositories/wishlist_repository.dart';

/// Live wishlist synced with Firestore; optimistic toggles keep hearts
/// consistent across every screen instantly.
class WishlistController extends ChangeNotifier {
  WishlistController(this._repo);

  final WishlistRepository _repo;
  StreamSubscription<List<WishlistEntry>>? _sub;
  String? _uid;

  List<WishlistEntry> _entries = const [];
  final Set<String> _saved = {};
  final Set<String> _pendingAdd = {};
  final Set<String> _pendingRemove = {};
  bool _loading = false;
  String? _error;

  List<WishlistEntry> get entries => _entries
      .where((e) => !_pendingRemove.contains(e.productId))
      .toList(growable: false);
  bool get loading => _loading;
  String? get error => _error;

  bool isSaved(String productId) =>
      !_pendingRemove.contains(productId) &&
      (_saved.contains(productId) || _pendingAdd.contains(productId));

  void bindUser(String? uid) {
    if (uid == _uid) return;
    _uid = uid;
    _sub?.cancel();
    _sub = null;
    _entries = const [];
    _saved.clear();
    _pendingAdd.clear();
    _pendingRemove.clear();
    _loading = uid != null;
    scheduleMicrotask(() {
      notifyListeners();
      if (uid != null) _listen(uid);
    });
  }

  void _listen(String uid) {
    _sub = _repo.watch(uid).listen(
      (list) {
        _entries = list;
        _saved
          ..clear()
          ..addAll(list.map((e) => e.productId));
        _pendingAdd.removeWhere(_saved.contains);
        _pendingRemove.removeWhere((id) => !_saved.contains(id));
        _loading = false;
        _error = null;
        notifyListeners();
      },
      onError: (Object _) {
        _loading = false;
        _error = 'Couldn\'t load your wishlist.';
        notifyListeners();
      },
    );
  }

  /// Returns true when the product is now saved.
  Future<bool> toggle(Product product) async {
    final uid = _uid;
    if (uid == null) return false;
    final wasSaved = isSaved(product.id);
    if (wasSaved) {
      _pendingRemove.add(product.id);
      _pendingAdd.remove(product.id);
    } else {
      _pendingAdd.add(product.id);
      _pendingRemove.remove(product.id);
    }
    notifyListeners();
    try {
      if (wasSaved) {
        await _repo.remove(uid, product.id);
      } else {
        await _repo.add(uid, product);
      }
    } catch (_) {
      _pendingAdd.remove(product.id);
      _pendingRemove.remove(product.id);
      notifyListeners();
      rethrow;
    }
    return !wasSaved;
  }

  Future<void> remove(String productId) async {
    final uid = _uid;
    if (uid == null) return;
    _pendingRemove.add(productId);
    notifyListeners();
    try {
      await _repo.remove(uid, productId);
    } catch (_) {
      _pendingRemove.remove(productId);
      notifyListeners();
      rethrow;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
