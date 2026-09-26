/// Display-side pricing rules.
///
/// The authoritative calculation happens in the `createOrder` Cloud Function
/// (functions/index.js → PRICING). Keep both in sync; the order document
/// always stores the server-computed amounts.
class PricingRules {
  PricingRules._();

  static const platformFee = 5;
  static const freeDeliveryThreshold = 999;
  static const defaultDeliveryFee = 49;
  static const codLimit = 5000;

  static int deliveryFee({required int subtotal, int? storeDeliveryFee}) {
    if (subtotal <= 0) return 0;
    if (subtotal >= freeDeliveryThreshold) return 0;
    return storeDeliveryFee ?? defaultDeliveryFee;
  }

  static PriceBreakdown breakdown({
    required int subtotal,
    int? storeDeliveryFee,
    int discount = 0,
  }) {
    final delivery =
        deliveryFee(subtotal: subtotal, storeDeliveryFee: storeDeliveryFee);
    final platform = subtotal > 0 ? platformFee : 0;
    final off = discount.clamp(0, subtotal);
    return PriceBreakdown(
      subtotal: subtotal,
      deliveryFee: delivery,
      platformFee: platform,
      discount: off,
      total: subtotal + delivery + platform - off,
    );
  }
}

class PriceBreakdown {
  const PriceBreakdown({
    required this.subtotal,
    required this.deliveryFee,
    required this.platformFee,
    required this.total,
    this.discount = 0,
  });

  final int subtotal;
  final int deliveryFee;
  final int platformFee;
  final int discount;
  final int total;

  /// How much more the customer needs to add for free delivery (0 if already
  /// free or the cart is empty).
  int get amountToFreeDelivery {
    if (subtotal <= 0 || deliveryFee == 0) return 0;
    return PricingRules.freeDeliveryThreshold - subtotal;
  }
}
