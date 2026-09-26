import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/drip_app_bar.dart';
import '../../core/widgets/drip_image.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/order.dart';
import '../../data/repositories/order_repository.dart';
import '../../navigation.dart';
import '../cart/bill_summary.dart';
import '../profile/help_screen.dart';
import '../returns/return_request_screen.dart';
import 'widgets/review_sheet.dart';
import 'widgets/status_chip.dart';
import 'widgets/status_stepper.dart';

/// Live order tracking. Everything shown here comes from the Firestore order
/// document — no timers or client-side status changes.
class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({
    super.key,
    required this.orderId,
    this.justPlaced = false,
  });

  final String orderId;
  final bool justPlaced;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late final Stream<DripOrder?> _stream =
      context.read<OrderRepository>().watchOrder(widget.orderId);
  bool _cancelling = false;
  bool _reviewedLocally = false;

  Future<void> _cancel(DripOrder order) async {
    final ok = await confirmDialog(
      context,
      title: 'Cancel this order?',
      message: order.payment.isPaid
          ? 'The store hasn\'t accepted it yet. Your ${formatInr(order.pricing.total)} will be refunded to the original payment method.'
          : 'The store hasn\'t accepted it yet, so you can cancel for free.',
      confirmLabel: 'Cancel order',
      cancelLabel: 'Keep order',
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _cancelling = true);
    try {
      await context
          .read<OrderRepository>()
          .cancelOrder(order.id, 'Cancelled by customer');
      if (mounted) showSnack(context, 'Order cancelled.');
    } on CheckoutFailure catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  Future<void> _review(DripOrder order) async {
    final done = await showReviewSheet(context, order);
    if (done && mounted) {
      setState(() => _reviewedLocally = true);
      showSnack(context, 'Thanks for rating ${order.storeName}!');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DripOrder?>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(
            appBar: dripAppBar(title: 'Order'),
            body: const ErrorState(message: 'Couldn\'t load this order.'),
          );
        }
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return Scaffold(appBar: dripAppBar(title: 'Order'), body: const CenteredLoader());
        }
        final order = snap.data;
        if (order == null) {
          return Scaffold(
            appBar: dripAppBar(title: 'Order'),
            body: const EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Order not found',
              message: 'This order doesn\'t exist or isn\'t linked to your account.',
            ),
          );
        }
        return _build(order);
      },
    );
  }

  Widget _build(DripOrder o) {
    final status = o.status;
    final now = DateTime.now();

    return Scaffold(
      appBar: dripAppBar(title: 'Order ${shortOrderId(o.id)}'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          if (widget.justPlaced &&
              status != OrderStatus.paymentPending &&
              !status.isProblem) ...[
            InlineNotice(
              error: false,
              icon: Icons.celebration_outlined,
              message: 'Order placed! ${o.storeName} has been notified. '
                  'We\'ll update you at every step.',
            ),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              Expanded(
                child: Text(o.storeName, style: AppTextStyles.heading(size: 24)),
              ),
              StatusChip(status: status),
            ],
          ),
          if (o.createdAt != null) ...[
            const SizedBox(height: 4),
            Text('Placed ${formatDateTime(o.createdAt!)}',
                style: AppTextStyles.mono(size: 11)),
          ],
          const SizedBox(height: 20),
          _panel(child: _statusSection(o)),
          const SizedBox(height: 16),
          _panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Items · ${o.itemCount}',
                    style: AppTextStyles.body(weight: FontWeight.w700)),
                const SizedBox(height: 12),
                for (final i in o.items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: () => AppNav.openProduct(context, i.productId),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 48,
                            height: 60,
                            child: DripImage(
                              url: i.imageUrl,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(i.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.body(size: 14)),
                                Text(
                                  [
                                    'Size ${i.size}',
                                    if (i.color != null) i.color!,
                                    'Qty ${i.quantity}',
                                  ].join(' · '),
                                  style: AppTextStyles.mono(size: 10.5),
                                ),
                              ],
                            ),
                          ),
                          Text(formatInr(i.lineTotal),
                              style: AppTextStyles.body(weight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          BillCard(
            title: 'Payment · ${o.payment.methodLabel}',
            rows: [
              ('Item total', formatInr(o.pricing.subtotal)),
              (
                'Delivery fee',
                o.pricing.deliveryFee == 0 ? 'FREE' : formatInr(o.pricing.deliveryFee)
              ),
              ('Platform fee', formatInr(o.pricing.platformFee)),
              if (o.pricing.discount > 0)
                ('Discount', '-${formatInr(o.pricing.discount)}'),
              ('Payment status', o.payment.statusLabel),
              if (o.payment.refundStatus != null)
                ('Refund', _refundLabel(o.payment.refundStatus!)),
            ],
            totalLabel: 'Total',
            total: formatInr(o.pricing.total),
          ),
          if (o.address != null) ...[
            const SizedBox(height: 16),
            _panel(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.location_on_outlined, color: AppColors.shopper),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Delivering to ${o.address!.name}',
                            style: AppTextStyles.body(weight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(o.address!.fullText,
                            style: AppTextStyles.body(
                                size: 13, color: AppColors.mute, height: 1.4)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          if (status.customerCanCancel)
            SecondaryButton(
              label: 'Cancel order',
              destructive: true,
              loading: _cancelling,
              onPressed: () => _cancel(o),
            ),
          if (o.canReview && !_reviewedLocally) ...[
            PrimaryButton(
              label: 'Rate this order',
              icon: Icons.star_outline_rounded,
              onPressed: () => _review(o),
            ),
            const SizedBox(height: 10),
          ],
          if (o.canRequestReturn(now)) ...[
            SecondaryButton(
              label: 'Return or exchange',
              icon: Icons.assignment_return_outlined,
              onPressed: () => AppNav.push(context, ReturnRequestScreen(order: o)),
            ),
            const SizedBox(height: 6),
            Text(
              'Eligible until ${formatDate(o.returnDeadline!)}',
              textAlign: TextAlign.center,
              style: AppTextStyles.mono(size: 10.5),
            ),
          ],
          const SizedBox(height: 10),
          LinkButton(
            label: 'Need help with this order?',
            onPressed: () => AppNav.push(context, const HelpScreen()),
          ),
        ],
      ),
    );
  }

  String _refundLabel(String s) => switch (s) {
        'initiated' => 'Initiated (5–7 business days)',
        'processed' => 'Refunded',
        'failed' => 'Being processed by support',
        'manual' => 'Being processed by support',
        _ => s,
      };

  Widget _statusSection(DripOrder o) {
    final status = o.status;
    if (status == OrderStatus.paymentPending) {
      return Row(
        children: [
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Confirming your payment with the bank. This usually takes a few '
              'seconds. If it fails, any amount debited is refunded automatically.',
              style: AppTextStyles.body(size: 13, height: 1.45),
            ),
          ),
        ],
      );
    }
    if (status.isProblem) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            status == OrderStatus.rejected
                ? Icons.store_mall_directory_outlined
                : Icons.cancel_outlined,
            color: AppColors.danger,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(status.label,
                    style: AppTextStyles.body(weight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  o.cancelReason ?? status.description,
                  style: AppTextStyles.body(size: 13, color: AppColors.mute),
                ),
                if (o.payment.isOnline && o.payment.refundStatus == null &&
                    o.payment.isPaid) ...[
                  const SizedBox(height: 4),
                  Text('Refund will be initiated shortly.',
                      style: AppTextStyles.body(size: 13, color: AppColors.mute)),
                ],
              ],
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (status == OrderStatus.returnRequested) ...[
          InlineNotice(
            error: false,
            icon: Icons.assignment_return_outlined,
            message: status.description,
          ),
          const SizedBox(height: 16),
        ],
        StatusStepper(order: o),
      ],
    );
  }

  Widget _panel({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.panel,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.line),
        ),
        child: child,
      );
}
