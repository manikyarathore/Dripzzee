import '../../core/utils/parse.dart';
import 'address.dart';

/// Shared order status contract (README → order_status). PAYMENT_PENDING is
/// customer-side only: the order exists but is hidden from retailers until
/// the online payment is verified.
enum OrderStatus {
  paymentPending('PAYMENT_PENDING'),
  placed('PLACED'),
  retailerConfirming('RETAILER_CONFIRMING'),
  accepted('ACCEPTED'),
  preparing('PREPARING'),
  readyForPickup('READY_FOR_PICKUP'),
  pickedUp('PICKED_UP'),
  outForDelivery('OUT_FOR_DELIVERY'),
  delivered('DELIVERED'),
  rejected('REJECTED'),
  cancelled('CANCELLED'),
  returnRequested('RETURN_REQUESTED'),
  unknown('UNKNOWN');

  const OrderStatus(this.wire);
  final String wire;

  static OrderStatus fromWire(String? value) {
    for (final s in OrderStatus.values) {
      if (s.wire == value) return s;
    }
    return OrderStatus.unknown;
  }

  /// The happy-path stages shown in the tracking stepper.
  static const List<OrderStatus> trackingSteps = [
    OrderStatus.placed,
    OrderStatus.retailerConfirming,
    OrderStatus.accepted,
    OrderStatus.preparing,
    OrderStatus.readyForPickup,
    OrderStatus.pickedUp,
    OrderStatus.outForDelivery,
    OrderStatus.delivered,
  ];

  String get label => switch (this) {
        OrderStatus.paymentPending => 'Awaiting payment',
        OrderStatus.placed => 'Order placed',
        OrderStatus.retailerConfirming => 'Store confirming',
        OrderStatus.accepted => 'Accepted',
        OrderStatus.preparing => 'Being packed',
        OrderStatus.readyForPickup => 'Ready for pickup',
        OrderStatus.pickedUp => 'Picked up',
        OrderStatus.outForDelivery => 'Out for delivery',
        OrderStatus.delivered => 'Delivered',
        OrderStatus.rejected => 'Declined by store',
        OrderStatus.cancelled => 'Cancelled',
        OrderStatus.returnRequested => 'Return requested',
        OrderStatus.unknown => 'Updating…',
      };

  String get description => switch (this) {
        OrderStatus.paymentPending =>
          'We are confirming your payment with the bank.',
        OrderStatus.placed => 'Your order has been sent to the store.',
        OrderStatus.retailerConfirming =>
          'The store is checking stock for your items.',
        OrderStatus.accepted => 'The store accepted your order.',
        OrderStatus.preparing => 'Your items are being packed.',
        OrderStatus.readyForPickup => 'Packed and waiting for the rider.',
        OrderStatus.pickedUp => 'The rider has collected your order.',
        OrderStatus.outForDelivery => 'On the way to you.',
        OrderStatus.delivered => 'Delivered. Enjoy the drip!',
        OrderStatus.rejected =>
          'The store could not fulfil this order. Any payment is refunded.',
        OrderStatus.cancelled => 'This order was cancelled.',
        OrderStatus.returnRequested =>
          'Your return/exchange request is with the store.',
        OrderStatus.unknown => 'Fetching the latest status.',
      };

  /// Index in [trackingSteps], or -1 when the order is off the happy path.
  int get stepIndex {
    if (this == OrderStatus.returnRequested) return trackingSteps.length - 1;
    return trackingSteps.indexOf(this);
  }

  bool get isTerminal =>
      this == OrderStatus.delivered ||
      this == OrderStatus.rejected ||
      this == OrderStatus.cancelled ||
      this == OrderStatus.returnRequested;

  bool get isActive => !isTerminal && this != OrderStatus.unknown;

  bool get isProblem =>
      this == OrderStatus.rejected || this == OrderStatus.cancelled;

  /// Customers may cancel until the store accepts.
  bool get customerCanCancel =>
      this == OrderStatus.placed || this == OrderStatus.retailerConfirming;
}

class OrderItem {
  const OrderItem({
    required this.productId,
    required this.name,
    required this.imageUrl,
    required this.size,
    required this.color,
    required this.quantity,
    required this.unitPrice,
  });

  final String productId;
  final String name;
  final String? imageUrl;
  final String size;
  final String? color;
  final int quantity;
  final int unitPrice;

  int get lineTotal => unitPrice * quantity;

  factory OrderItem.fromMap(Map<String, dynamic> d) => OrderItem(
        productId: readString(d['productId']),
        name: readString(d['name'], 'Item'),
        imageUrl: d['imageUrl'] is String ? d['imageUrl'] as String : null,
        size: readString(d['size']),
        color: d['color'] is String ? d['color'] as String : null,
        quantity: readInt(d['quantity'], 1),
        unitPrice: readInt(d['unitPrice']),
      );
}

class OrderPricing {
  const OrderPricing({
    required this.subtotal,
    required this.deliveryFee,
    required this.platformFee,
    required this.discount,
    required this.total,
  });

  final int subtotal;
  final int deliveryFee;
  final int platformFee;
  final int discount;
  final int total;

  factory OrderPricing.fromMap(Map<String, dynamic> d) => OrderPricing(
        subtotal: readInt(d['subtotal']),
        deliveryFee: readInt(d['deliveryFee']),
        platformFee: readInt(d['platformFee']),
        discount: readInt(d['discount']),
        total: readInt(d['total']),
      );
}

class PaymentInfo {
  const PaymentInfo({
    required this.method,
    required this.status,
    this.razorpayOrderId,
    this.razorpayPaymentId,
    this.refundStatus,
  });

  /// 'razorpay' | 'cod'
  final String method;

  /// 'pending' | 'paid' | 'failed' | 'cod_pending' | 'refunded'
  final String status;
  final String? razorpayOrderId;
  final String? razorpayPaymentId;

  /// null | 'initiated' | 'processed' | 'failed' | 'manual'
  final String? refundStatus;

  bool get isOnline => method == 'razorpay';
  bool get isPaid => status == 'paid';

  String get methodLabel => isOnline ? 'Paid online' : 'Cash on delivery';

  String get statusLabel => switch (status) {
        'paid' => 'Paid',
        'pending' => 'Payment pending',
        'failed' => 'Payment failed',
        'cod_pending' => 'Pay on delivery',
        'cod_collected' => 'Paid in cash',
        'refunded' => 'Refunded',
        _ => status,
      };

  factory PaymentInfo.fromMap(Map<String, dynamic> d) => PaymentInfo(
        method: readString(d['method'], 'cod'),
        status: readString(d['status'], 'pending'),
        razorpayOrderId:
            d['razorpayOrderId'] is String ? d['razorpayOrderId'] as String : null,
        razorpayPaymentId: d['razorpayPaymentId'] is String
            ? d['razorpayPaymentId'] as String
            : null,
        refundStatus:
            d['refundStatus'] is String ? d['refundStatus'] as String : null,
      );
}

class StatusEvent {
  const StatusEvent(this.status, this.at);
  final OrderStatus status;
  final DateTime? at;
}

class DripOrder {
  const DripOrder({
    required this.id,
    required this.customerId,
    required this.storeId,
    required this.storeName,
    required this.items,
    required this.pricing,
    required this.address,
    required this.payment,
    required this.status,
    required this.history,
    required this.createdAt,
    required this.deliveredAt,
    required this.returnWindowDays,
    required this.reviewed,
    required this.cancelReason,
  });

  final String id;
  final String customerId;
  final String storeId;
  final String storeName;
  final List<OrderItem> items;
  final OrderPricing pricing;
  final Address? address;
  final PaymentInfo payment;
  final OrderStatus status;
  final List<StatusEvent> history;
  final DateTime? createdAt;
  final DateTime? deliveredAt;
  final int returnWindowDays;
  final bool reviewed;
  final String? cancelReason;

  int get itemCount => items.fold(0, (sum, i) => sum + i.quantity);

  DateTime? timeOf(OrderStatus s) {
    for (final e in history.reversed) {
      if (e.status == s) return e.at;
    }
    return null;
  }

  DateTime? get returnDeadline => deliveredAt?.add(Duration(days: returnWindowDays));

  bool canRequestReturn(DateTime now) {
    final deadline = returnDeadline;
    return status == OrderStatus.delivered &&
        deadline != null &&
        now.isBefore(deadline);
  }

  bool get canReview =>
      !reviewed &&
      (status == OrderStatus.delivered ||
          status == OrderStatus.returnRequested);

  factory DripOrder.fromMap(String id, Map<String, dynamic> d) {
    final addressMap = readMap(d['address']);
    return DripOrder(
      id: id,
      customerId: readString(d['customerId']),
      storeId: readString(d['storeId']),
      storeName: readString(d['storeName'], 'Store'),
      items: readMapList(d['items']).map(OrderItem.fromMap).toList(),
      pricing: OrderPricing.fromMap(readMap(d['pricing'])),
      address: addressMap.isEmpty ? null : Address.fromMap('', addressMap),
      payment: PaymentInfo.fromMap(readMap(d['payment'])),
      status: OrderStatus.fromWire(d['status'] as String?),
      history: readMapList(d['statusHistory'])
          .map((e) => StatusEvent(
                OrderStatus.fromWire(e['status'] as String?),
                readDate(e['at']),
              ))
          .toList(),
      createdAt: readDate(d['createdAt']),
      deliveredAt: readDate(d['deliveredAt']),
      returnWindowDays: readInt(d['returnWindowDays'], 7),
      reviewed: readBool(d['reviewed']),
      cancelReason: d['cancelReason'] is String ? d['cancelReason'] as String : null,
    );
  }
}
