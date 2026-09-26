import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/feedback.dart';
import '../../../data/models/cart_item.dart';
import '../../../navigation.dart';
import '../../../state/cart_controller.dart';

/// Adds an item to the cart and handles every outcome with UI feedback,
/// including the single-retailer rule. Returns true when the item was added.
Future<bool> addToCartWithFeedback(
  BuildContext context,
  CartItem item, {
  bool quiet = false,
}) async {
  final cart = context.read<CartController>();
  var result = cart.add(item);

  if (result == AddToCartResult.differentStore) {
    final replace = await confirmDialog(
      context,
      title: 'Start a new cart?',
      message:
          'Your cart has items from ${cart.storeName}. Dripzzee orders ship '
          'from one store at a time, so adding this will clear your current cart.',
      confirmLabel: 'Replace cart',
      cancelLabel: 'Keep current',
    );
    if (!replace || !context.mounted) return false;
    result = cart.replaceWith(item);
  }

  if (!context.mounted) return result == AddToCartResult.added;

  if (result == AddToCartResult.added) {
    if (!quiet) {
      showSnack(
        context,
        'Added to cart · size ${item.size}',
        action: SnackBarAction(
          label: 'View cart',
          onPressed: () => AppNav.openCart(context),
        ),
      );
    }
    return true;
  }
  if (result == AddToCartResult.outOfStock) {
    showSnack(context, 'Size ${item.size} is sold out.', error: true);
  } else if (result == AddToCartResult.limitReached) {
    showSnack(
      context,
      'Only ${item.maxStock} in stock for size ${item.size} — that\'s all in your cart.',
      error: true,
    );
  }
  return false;
}
