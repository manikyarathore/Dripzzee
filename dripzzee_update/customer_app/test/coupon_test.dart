import 'package:customer_app/data/models/coupon.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Coupon coupon(Map<String, dynamic> m) => Coupon.fromMap('drip50', m);

  test('flat coupon with minimum order', () {
    final c = coupon({'type': 'flat', 'value': 50, 'minOrder': 499});
    expect(c.code, 'DRIP50');
    expect(c.problemFor(subtotal: 400, storeId: 's1'), contains('₹99'));
    expect(c.problemFor(subtotal: 600, storeId: 's1'), isNull);
    expect(c.discountFor(600), 50);
    expect(c.discountFor(30), 30);
  });

  test('percent coupon is capped', () {
    final c = coupon({'type': 'percent', 'value': 15, 'maxDiscount': 300});
    expect(c.discountFor(1000), 150);
    expect(c.discountFor(5000), 300);
  });

  test('expired, inactive and store-specific coupons are rejected', () {
    final expired = coupon({
      'type': 'flat',
      'value': 50,
      'expiresAt': DateTime.now().subtract(const Duration(days: 1)),
    });
    expect(expired.problemFor(subtotal: 999, storeId: 's1'), contains('expired'));

    final inactive = coupon({'type': 'flat', 'value': 50, 'active': false});
    expect(inactive.problemFor(subtotal: 999, storeId: 's1'), isNotNull);

    final storeOnly = coupon({'type': 'flat', 'value': 50, 'storeId': 's2'});
    expect(storeOnly.problemFor(subtotal: 999, storeId: 's1'), isNotNull);
    expect(storeOnly.problemFor(subtotal: 999, storeId: 's2'), isNull);
  });
}
