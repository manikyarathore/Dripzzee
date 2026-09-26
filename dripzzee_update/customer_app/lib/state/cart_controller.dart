import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/pricing.dart';
import '../data/models/cart_item.dart';
import '../data/models/product.dart';

abstract class CartStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String? value);
}

class PrefsCartStorage implements CartStorage {
  @override
  Future<String?> read(String key) async =>
      (await SharedPreferences.getInstance()).getString(key);

  @override
  Future<void> write(String key, String? value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value == null) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, value);
    }
  }
}

class MemoryCartStorage implements CartStorage {
  final Map<String, String> data = {};

  @override
  Future<String?> read(String key) async => data[key];

  @override
  Future<void> write(String key, String? value) async {
    if (value == null) {
      data.remove(key);
    } else {
      data[key] = value;
    }
  }
}

enum AddToCartResult { added, differentStore, outOfStock, limitReached }

/// Single-retailer cart (MVP rule), persisted per user on this device.
class CartController extends ChangeNotifier {
  CartController({CartStorage? storage})
      : _storage = storage ?? PrefsCartStorage();

  final CartStorage _storage;
  final List<CartItem> _items = [];
  String? _uid;

  List<CartItem> get items => List.unmodifiable(_items);
  bool get isEmpty => _items.isEmpty;
  int get itemCount => _items.fold(0, (sum, i) => sum + i.quantity);
  String? get storeId => _items.isEmpty ? null : _items.first.storeId;
  String? get storeName => _items.isEmpty ? null : _items.first.storeName;
  int get subtotal => _items.fold(0, (sum, i) => sum + i.lineTotal);

  PriceBreakdown get breakdown => PricingRules.breakdown(
        subtotal: subtotal,
        storeDeliveryFee: _items.isEmpty ? null : _items.first.storeDeliveryFee,
      );

  String _key(String uid) => 'cart_$uid';

  void bindUser(String? uid) {
    if (uid == _uid) return;
    _uid = uid;
    _items.clear();
    scheduleMicrotask(() async {
      notifyListeners();
      if (uid != null) await _load(uid);
    });
  }

  Future<void> _load(String uid) async {
    try {
      final raw = await _storage.read(_key(uid));
      if (raw == null || _uid != uid) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      _items
        ..clear()
        ..addAll(decoded
            .whereType<Map>()
            .map((m) => CartItem.fromJson(Map<String, dynamic>.from(m)))
            .whereType<CartItem>());
      notifyListeners();
    } catch (_) {
      // Corrupt cache: start with an empty cart.
    }
  }

  Future<void> _save() async {
    final uid = _uid;
    if (uid == null) return;
    await _storage.write(
      _key(uid),
      _items.isEmpty ? null : jsonEncode(_items.map((i) => i.toJson()).toList()),
    );
  }

  int quantityOf(String productId, String size, [String? color]) {
    for (final i in _items) {
      if (i.productId == productId && i.size == size && i.color == color) {
        return i.quantity;
      }
    }
    return 0;
  }

  AddToCartResult add(CartItem item) {
    final lockedStore = storeId;
    if (lockedStore != null && lockedStore != item.storeId) {
      return AddToCartResult.differentStore;
    }
    if (item.maxStock <= 0) return AddToCartResult.outOfStock;

    final index = _items.indexWhere((i) => i.key == item.key);
    if (index >= 0) {
      final existing = _items[index];
      final nextQty = existing.quantity + item.quantity;
      if (nextQty > item.maxStock) return AddToCartResult.limitReached;
      _items[index] = existing.copyWith(
        quantity: nextQty,
        unitPrice: item.unitPrice,
        maxStock: item.maxStock,
      );
    } else {
      if (item.quantity > item.maxStock) return AddToCartResult.limitReached;
      _items.add(item);
    }
    notifyListeners();
    unawaited(_save());
    return AddToCartResult.added;
  }

  /// Clears a cart from another store and adds [item] (after the user
  /// confirms replacing it).
  AddToCartResult replaceWith(CartItem item) {
    _items.clear();
    return add(item);
  }

  void setQuantity(String key, int quantity) {
    final index = _items.indexWhere((i) => i.key == key);
    if (index < 0) return;
    if (quantity <= 0) {
      _items.removeAt(index);
    } else {
      final item = _items[index];
      _items[index] = item.copyWith(
        quantity: quantity > item.maxStock ? item.maxStock : quantity,
      );
    }
    notifyListeners();
    unawaited(_save());
  }

  void remove(String key) => setQuantity(key, 0);

  void clear() {
    _items.clear();
    notifyListeners();
    unawaited(_save());
  }

  /// Reconciles the cart with fresh product data. Removes unavailable items,
  /// updates prices and caps quantities to stock. Returns human-readable
  /// notes describing every change (empty when nothing changed).
  List<String> reconcile(List<Product> fresh) {
    final byId = {for (final p in fresh) p.id: p};
    final notes = <String>[];
    final next = <CartItem>[];
    for (final item in _items) {
      final p = byId[item.productId];
      if (p == null || !p.active) {
        notes.add('${item.name} is no longer available and was removed.');
        continue;
      }
      final stock = p.stockFor(item.size);
      if (stock <= 0) {
        notes.add('${item.name} (${item.size}) is sold out and was removed.');
        continue;
      }
      var updated = item.copyWith(maxStock: stock, mrp: p.mrp);
      if (item.quantity > stock) {
        notes.add('Only $stock left of ${item.name} (${item.size}); quantity updated.');
        updated = updated.copyWith(quantity: stock);
      }
      if (p.price != item.unitPrice) {
        notes.add('Price of ${item.name} changed to ₹${p.price}.');
        updated = updated.copyWith(unitPrice: p.price);
      }
      next.add(updated);
    }
    _items
      ..clear()
      ..addAll(next);
    notifyListeners();
    unawaited(_save());
    return notes;
  }
}
