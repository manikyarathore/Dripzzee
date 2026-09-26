import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../core/config/app_config.dart';
import '../models/address.dart';
import '../models/cart_item.dart';
import '../models/order.dart';

class CheckoutFailure implements Exception {
  const CheckoutFailure(this.message, {this.code = 'unknown'});
  final String message;

  /// Firebase Functions error code, or `network` when the server couldn't be
  /// reached (in which case the request may or may not have been processed).
  final String code;

  /// True when the server definitely rejected the request, so a retry must
  /// use a fresh idempotency key.
  bool get definitelyRejected => const {
        'failed-precondition',
        'invalid-argument',
        'permission-denied',
        'not-found',
        'already-exists',
        'resource-exhausted',
      }.contains(code);

  @override
  String toString() => message;
}

class CreateOrderResult {
  const CreateOrderResult({
    required this.orderId,
    required this.total,
    required this.status,
    this.razorpayKeyId,
    this.razorpayOrderId,
    this.amountPaise,
  });

  final String orderId;
  final int total;
  final OrderStatus status;
  final String? razorpayKeyId;
  final String? razorpayOrderId;
  final int? amountPaise;

  bool get needsPayment => razorpayOrderId != null && razorpayKeyId != null;
}

/// Orders are *read* directly from Firestore (live listeners) but every
/// write that touches money or stock goes through Cloud Functions so the
/// client can never set prices, payment state or protected statuses.
class OrderRepository {
  OrderRepository({FirebaseFirestore? db, FirebaseFunctions? functions})
      : _db = db ?? FirebaseFirestore.instance,
        _functions = functions ??
            FirebaseFunctions.instanceFor(region: AppConfig.functionsRegion);

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  Stream<List<DripOrder>> watchOrders(String uid) => _db
      .collection('orders')
      .where('customerId', isEqualTo: uid)
      .snapshots()
      .map((s) {
        final list =
            s.docs.map((d) => DripOrder.fromMap(d.id, d.data())).toList()
              ..sort((a, b) => (b.createdAt ?? DateTime(2000))
                  .compareTo(a.createdAt ?? DateTime(2000)));
        return list;
      });

  Stream<DripOrder?> watchOrder(String orderId) =>
      _db.collection('orders').doc(orderId).snapshots().map(
            (s) => s.exists ? DripOrder.fromMap(s.id, s.data()!) : null,
          );

  Future<CreateOrderResult> createOrder({
    required String requestId,
    required String storeId,
    required List<CartItem> items,
    required Address address,
    required String paymentMethod,
    String? couponCode,
  }) async {
    final data = await _call('createOrder', {
      'requestId': requestId,
      if (couponCode != null) 'couponCode': couponCode,
      'storeId': storeId,
      'paymentMethod': paymentMethod,
      'items': [
        for (final i in items)
          {
            'productId': i.productId,
            'size': i.size,
            'color': i.color,
            'quantity': i.quantity,
          },
      ],
      'address': address.toMap(),
    });
    final rzp = data['razorpay'] is Map
        ? Map<String, dynamic>.from(data['razorpay'] as Map)
        : null;
    return CreateOrderResult(
      orderId: data['orderId'] as String,
      total: (data['total'] as num).round(),
      status: OrderStatus.fromWire(data['status'] as String?),
      razorpayKeyId: rzp?['keyId'] as String?,
      razorpayOrderId: rzp?['orderId'] as String?,
      amountPaise: (rzp?['amount'] as num?)?.round(),
    );
  }

  Future<void> verifyPayment({
    required String orderId,
    required String razorpayPaymentId,
    required String razorpayOrderId,
    required String razorpaySignature,
  }) =>
      _call('verifyPayment', {
        'orderId': orderId,
        'razorpayPaymentId': razorpayPaymentId,
        'razorpayOrderId': razorpayOrderId,
        'razorpaySignature': razorpaySignature,
      });

  /// Tells the server the payment sheet failed/was dismissed. The server
  /// double-checks with Razorpay before releasing the reserved stock and
  /// returns the order's resulting status.
  Future<OrderStatus> reportPaymentFailure({
    required String orderId,
    required String reason,
  }) async {
    final data =
        await _call('paymentFailed', {'orderId': orderId, 'reason': reason});
    return OrderStatus.fromWire(data['status'] as String?);
  }

  Future<void> cancelOrder(String orderId, String reason) =>
      _call('cancelOrder', {'orderId': orderId, 'reason': reason});

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> payload,
  ) async {
    try {
      final result = await _functions
          .httpsCallable(
            name,
            options: HttpsCallableOptions(timeout: const Duration(seconds: 40)),
          )
          .call(payload);
      final raw = result.data;
      return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    } on FirebaseFunctionsException catch (e) {
      throw CheckoutFailure(_friendly(e), code: e.code);
    } catch (_) {
      throw const CheckoutFailure(
        'We couldn\'t reach Dripzzee. Check your connection and try again.',
        code: 'network',
      );
    }
  }

  static String _friendly(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'failed-precondition':
      case 'invalid-argument':
      case 'permission-denied':
      case 'not-found':
        return e.message ?? 'This request couldn\'t be completed.';
      case 'unauthenticated':
        return 'Your session expired. Please log in again.';
      case 'unavailable':
      case 'deadline-exceeded':
        return 'The server is busy or unreachable. Please try again.';
      default:
        return e.message ?? 'Something went wrong. Please try again.';
    }
  }
}
