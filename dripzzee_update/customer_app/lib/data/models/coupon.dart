import '../../core/utils/formatters.dart';
import '../../core/utils/parse.dart';

/// coupons/{CODE} — created by the Dripzzee team (admin), read by customers,
/// enforced again by the createOrder function.
class Coupon {
  const Coupon({
    required this.code,
    required this.type,
    required this.value,
    required this.minOrder,
    required this.maxDiscount,
    required this.description,
    required this.active,
    required this.expiresAt,
    required this.oncePerUser,
    required this.storeId,
  });

  final String code;

  /// 'flat' (₹ off) or 'percent'.
  final String type;
  final int value;
  final int minOrder;

  /// Cap for percent coupons (0 = no cap).
  final int maxDiscount;
  final String description;
  final bool active;
  final DateTime? expiresAt;
  final bool oncePerUser;

  /// Limits the coupon to one store (null = every store).
  final String? storeId;

  String get title => type == 'percent'
      ? '$value% off${maxDiscount > 0 ? ' up to ${formatInr(maxDiscount)}' : ''}'
      : '${formatInr(value)} off';

  /// Why it can't be used for this cart, or null if it can.
  String? problemFor({required int subtotal, required String storeId}) {
    if (!active) return 'This coupon is no longer active.';
    if (expiresAt != null && DateTime.now().isAfter(expiresAt!)) {
      return 'This coupon has expired.';
    }
    if (this.storeId != null && this.storeId != storeId) {
      return 'This coupon isn\'t valid for this store.';
    }
    if (subtotal < minOrder) {
      return 'Add ${formatInr(minOrder - subtotal)} more to use $code.';
    }
    return null;
  }

  int discountFor(int subtotal) {
    final raw = type == 'percent' ? (subtotal * value / 100).floor() : value;
    final capped = (type == 'percent' && maxDiscount > 0 && raw > maxDiscount)
        ? maxDiscount
        : raw;
    return capped.clamp(0, subtotal);
  }

  factory Coupon.fromMap(String id, Map<String, dynamic> d) => Coupon(
        code: id.toUpperCase(),
        type: readString(d['type'], 'flat'),
        value: readInt(d['value']),
        minOrder: readInt(d['minOrder']),
        maxDiscount: readInt(d['maxDiscount']),
        description: readString(d['description']),
        active: readBool(d['active'], true),
        expiresAt: readDate(d['expiresAt']),
        oncePerUser: readBool(d['oncePerUser'], false),
        storeId: d['storeId'] is String && (d['storeId'] as String).isNotEmpty
            ? d['storeId'] as String
            : null,
      );
}
