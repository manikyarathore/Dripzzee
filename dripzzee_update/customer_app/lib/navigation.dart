import 'package:flutter/material.dart';

import 'data/models/catalog_filter.dart';
import 'data/models/product.dart';
import 'data/models/store.dart';
import 'features/cart/cart_screen.dart';
import 'features/catalog/product_detail_screen.dart';
import 'features/catalog/product_listing_screen.dart';
import 'features/catalog/store_detail_screen.dart';
import 'features/catalog/store_listing_screen.dart';
import 'features/orders/order_detail_screen.dart';

final navigatorKey = GlobalKey<NavigatorState>();
final messengerKey = GlobalKey<ScaffoldMessengerState>();

/// One place for every cross-feature route, so screens never build routes to
/// each other ad hoc.
class AppNav {
  AppNav._();

  static Future<T?> push<T>(BuildContext context, Widget page) =>
      Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => page));

  static Future<void> openProduct(
    BuildContext context,
    String productId, {
    Product? initial,
    String? heroTag,
  }) =>
      push(
        context,
        ProductDetailScreen(
          productId: productId,
          initial: initial,
          heroTag: heroTag,
        ),
      );

  static Future<void> openStore(
    BuildContext context,
    String storeId, {
    Store? initial,
    String? heroTag,
  }) =>
      push(
        context,
        StoreDetailScreen(storeId: storeId, initial: initial, heroTag: heroTag),
      );

  static Future<void> openProducts(BuildContext context, ProductFilter filter) =>
      push(context, ProductListingScreen(filter: filter));

  static Future<void> openStores(BuildContext context, StoreFilter filter) =>
      push(context, StoreListingScreen(filter: filter));

  static Future<void> openCart(BuildContext context) =>
      push(context, const CartScreen());

  static Future<void> openOrder(
    BuildContext context,
    String orderId, {
    bool justPlaced = false,
  }) =>
      push(context, OrderDetailScreen(orderId: orderId, justPlaced: justPlaced));

  /// After a successful checkout: clear the checkout stack and show the
  /// live order screen on top of the shell.
  static void showPlacedOrder(BuildContext context, String orderId) {
    final nav = Navigator.of(context);
    nav.popUntil((r) => r.isFirst);
    nav.push(MaterialPageRoute(
      builder: (_) => OrderDetailScreen(orderId: orderId, justPlaced: true),
    ));
  }

  /// Routes a notification tap (see NotificationService payload contract).
  static void handleNotification(Map<String, dynamic> data) {
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    final type = data['type'];
    final orderId = data['orderId'];
    final productId = data['productId'];
    if ((type == 'order' || type == 'return') && orderId is String) {
      nav.push(MaterialPageRoute(
        builder: (_) => OrderDetailScreen(orderId: orderId),
      ));
    } else if (type == 'product' && productId is String) {
      nav.push(MaterialPageRoute(
        builder: (_) => ProductDetailScreen(productId: productId),
      ));
    }
  }
}
