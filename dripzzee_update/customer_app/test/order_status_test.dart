import 'package:customer_app/data/models/order.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('wire values round-trip and unknown values are safe', () {
    for (final s in OrderStatus.values) {
      expect(OrderStatus.fromWire(s.wire), s);
    }
    expect(OrderStatus.fromWire('SOMETHING_NEW'), OrderStatus.unknown);
    expect(OrderStatus.fromWire(null), OrderStatus.unknown);
  });

  test('tracking steps follow the shared README order', () {
    expect(OrderStatus.trackingSteps.map((s) => s.wire).toList(), [
      'PLACED',
      'RETAILER_CONFIRMING',
      'ACCEPTED',
      'PREPARING',
      'READY_FOR_PICKUP',
      'PICKED_UP',
      'OUT_FOR_DELIVERY',
      'DELIVERED',
    ]);
    expect(OrderStatus.placed.stepIndex, 0);
    expect(OrderStatus.delivered.stepIndex, 7);
    expect(OrderStatus.returnRequested.stepIndex, 7);
    expect(OrderStatus.cancelled.stepIndex, -1);
    expect(OrderStatus.paymentPending.stepIndex, -1);
  });

  test('cancellation only before acceptance', () {
    expect(OrderStatus.placed.customerCanCancel, isTrue);
    expect(OrderStatus.retailerConfirming.customerCanCancel, isTrue);
    expect(OrderStatus.accepted.customerCanCancel, isFalse);
    expect(OrderStatus.outForDelivery.customerCanCancel, isFalse);
  });

  test('terminal / active classification', () {
    expect(OrderStatus.delivered.isTerminal, isTrue);
    expect(OrderStatus.rejected.isProblem, isTrue);
    expect(OrderStatus.preparing.isActive, isTrue);
    expect(OrderStatus.paymentPending.isActive, isTrue);
  });

  DripOrder order({required String status, DateTime? deliveredAt, int window = 7}) =>
      DripOrder.fromMap('o1', {
        'customerId': 'u1',
        'storeId': 's1',
        'storeName': 'Store',
        'status': status,
        'items': [
          {'productId': 'p1', 'name': 'Kurta', 'size': 'M', 'quantity': 2, 'unitPrice': 900},
        ],
        'pricing': {'subtotal': 1800, 'deliveryFee': 0, 'platformFee': 5, 'total': 1805},
        'payment': {'method': 'cod', 'status': 'cod_pending'},
        'deliveredAt': deliveredAt,
        'returnWindowDays': window,
      });

  test('order parsing and return window', () {
    final now = DateTime.now();
    final o = order(status: 'DELIVERED', deliveredAt: now.subtract(const Duration(days: 2)));
    expect(o.itemCount, 2);
    expect(o.items.single.lineTotal, 1800);
    expect(o.pricing.total, 1805);
    expect(o.canRequestReturn(now), isTrue);
    expect(o.canReview, isTrue);

    final late = order(status: 'DELIVERED', deliveredAt: now.subtract(const Duration(days: 8)));
    expect(late.canRequestReturn(now), isFalse);

    final active = order(status: 'PREPARING');
    expect(active.canRequestReturn(now), isFalse);
    expect(active.canReview, isFalse);
  });
}
