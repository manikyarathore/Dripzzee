import 'dart:async';

import 'package:razorpay_flutter/razorpay_flutter.dart';

sealed class PaymentOutcome {
  const PaymentOutcome();
}

class PaymentSucceeded extends PaymentOutcome {
  const PaymentSucceeded({
    required this.paymentId,
    required this.orderId,
    required this.signature,
  });

  final String paymentId;
  final String orderId;
  final String signature;
}

class PaymentFailed extends PaymentOutcome {
  const PaymentFailed(this.message);
  final String message;
}

class PaymentCancelled extends PaymentOutcome {
  const PaymentCancelled();
}

/// Opens Razorpay Checkout (UPI, cards, net banking) for a server-created
/// Razorpay order. Success here is NOT trusted on its own — the signature is
/// verified by the `verifyPayment` Cloud Function before the order is placed.
class PaymentService {
  Future<PaymentOutcome> checkout({
    required String keyId,
    required String razorpayOrderId,
    required int amountPaise,
    required String description,
    String? email,
    String? contact,
    String? customerName,
  }) {
    final completer = Completer<PaymentOutcome>();
    final razorpay = Razorpay();

    void finish(PaymentOutcome outcome) {
      if (!completer.isCompleted) completer.complete(outcome);
      Future.microtask(razorpay.clear);
    }

    razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse r) {
      final paymentId = r.paymentId;
      final signature = r.signature;
      if (paymentId == null || signature == null) {
        finish(const PaymentFailed(
          'Payment response was incomplete. If money was debited, it will be confirmed or refunded automatically.',
        ));
        return;
      }
      finish(PaymentSucceeded(
        paymentId: paymentId,
        orderId: r.orderId ?? razorpayOrderId,
        signature: signature,
      ));
    });

    razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse r) {
      if (r.code == Razorpay.PAYMENT_CANCELLED) {
        finish(const PaymentCancelled());
      } else if (r.code == Razorpay.NETWORK_ERROR) {
        finish(const PaymentFailed(
          'Network error during payment. Check your connection and try again.',
        ));
      } else {
        finish(const PaymentFailed('The payment did not go through.'));
      }
    });

    razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse r) {
      finish(const PaymentFailed(
        'External wallets aren\'t supported yet. Please use UPI, a card or net banking.',
      ));
    });

    try {
      razorpay.open({
        'key': keyId,
        'order_id': razorpayOrderId,
        'amount': amountPaise,
        'currency': 'INR',
        'name': 'Dripzzee',
        'description': description,
        'prefill': {
          if (email != null && email.isNotEmpty) 'email': email,
          if (contact != null && contact.isNotEmpty) 'contact': contact,
          if (customerName != null && customerName.isNotEmpty)
            'name': customerName,
        },
        'theme': {'color': '#C77DFF'},
        'retry': {'enabled': true, 'max_count': 2},
      });
    } catch (_) {
      finish(const PaymentFailed('Could not open the payment window.'));
    }

    return completer.future;
  }
}
