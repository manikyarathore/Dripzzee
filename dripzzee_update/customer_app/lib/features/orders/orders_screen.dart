import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/drip_app_bar.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/order.dart';
import '../../data/repositories/order_repository.dart';
import '../../navigation.dart';
import '../../state/auth_controller.dart';
import '../../state/shell_controller.dart';
import 'widgets/status_chip.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  late Stream<List<DripOrder>> _stream = _create();

  Stream<List<DripOrder>> _create() => context
      .read<OrderRepository>()
      .watchOrders(context.read<AuthController>().uid!);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: dripAppBar(title: 'Your orders', automaticallyImplyLeading: false),
      body: StreamBuilder<List<DripOrder>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) {
            return ErrorState(
              message: 'Couldn\'t load your orders.',
              onRetry: () => setState(() => _stream = _create()),
            );
          }
          if (!snap.hasData) return const CenteredLoader();
          final orders = snap.data!;
          if (orders.isEmpty) {
            return EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No orders yet',
              message: 'When you order from a store near you, you can track it live here.',
              actionLabel: 'Start shopping',
              onAction: () => context.read<ShellController>().goTo(ShellTab.home),
            );
          }
          final active = orders.where((o) => o.status.isActive).toList();
          final past = orders.where((o) => !o.status.isActive).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              if (active.isNotEmpty) ...[
                Text('IN PROGRESS', style: AppTextStyles.mono(size: 11)),
                const SizedBox(height: 10),
                for (final o in active) OrderCard(order: o),
                const SizedBox(height: 14),
              ],
              if (past.isNotEmpty) ...[
                Text('PAST ORDERS', style: AppTextStyles.mono(size: 11)),
                const SizedBox(height: 10),
                for (final o in past) OrderCard(order: o),
              ],
            ],
          );
        },
      ),
    );
  }
}

class OrderCard extends StatelessWidget {
  const OrderCard({super.key, required this.order});

  final DripOrder order;

  @override
  Widget build(BuildContext context) {
    final o = order;
    final step = o.status.stepIndex;
    final steps = OrderStatus.trackingSteps.length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Pressable(
        scale: 0.985,
        onTap: () => AppNav.openOrder(context, o.id),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.panel,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(o.storeName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.heading(size: 17)),
                  ),
                  StatusChip(status: o.status),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                o.items.map((i) => '${i.quantity}× ${i.name}').join(', '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body(size: 13, color: AppColors.mute),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      [
                        shortOrderId(o.id),
                        if (o.createdAt != null) formatDateTime(o.createdAt!),
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.mono(size: 10.5),
                    ),
                  ),
                  Text(formatInr(o.pricing.total),
                      style: AppTextStyles.body(weight: FontWeight.w800)),
                ],
              ),
              if (o.status.isActive && step >= 0) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: (step + 1) / steps,
                    minHeight: 3,
                    backgroundColor: AppColors.lineStrong,
                    color: AppColors.shopper,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
