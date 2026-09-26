import 'package:customer_app/core/pricing.dart';
import 'package:customer_app/core/utils/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Indian rupee grouping', () {
    expect(formatInr(0), '₹0');
    expect(formatInr(999), '₹999');
    expect(formatInr(1299), '₹1,299');
    expect(formatInr(125000), '₹1,25,000');
    expect(formatInr(12345678), '₹1,23,45,678');
  });

  test('distance formatting', () {
    expect(formatDistance(0.45), '450 m');
    expect(formatDistance(2.34), '2.3 km');
    expect(formatDistance(14.6), '15 km');
  });

  test('pricing rules', () {
    expect(PricingRules.breakdown(subtotal: 0).total, 0);
    final small = PricingRules.breakdown(subtotal: 400, storeDeliveryFee: 30);
    expect(small.deliveryFee, 30);
    expect(small.total, 435);
    final big = PricingRules.breakdown(subtotal: 999);
    expect(big.deliveryFee, 0);
    expect(big.total, 1004);
  });

  test('coupon discount lowers the total and is capped at the item total', () {
    final bill = PricingRules.breakdown(subtotal: 1200, discount: 150);
    expect(bill.deliveryFee, 0);
    expect(bill.discount, 150);
    expect(bill.total, 1055);
    final capped = PricingRules.breakdown(subtotal: 100, discount: 500);
    expect(capped.discount, 100);
  });
}
