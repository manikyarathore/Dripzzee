import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/order.dart';

Color statusColor(OrderStatus s) {
  if (s.isProblem) return AppColors.danger;
  if (s == OrderStatus.delivered) return AppColors.success;
  if (s == OrderStatus.paymentPending || s == OrderStatus.returnRequested) {
    return AppColors.warning;
  }
  return AppColors.shopper;
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final color = statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.label.toUpperCase(),
        style: AppTextStyles.mono(size: 9.5, color: color, weight: FontWeight.w700),
      ),
    );
  }
}
