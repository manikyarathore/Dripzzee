import 'package:flutter/material.dart';

import '../../core/pricing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';

class BillSummary extends StatelessWidget {
  const BillSummary({
    super.key,
    required this.breakdown,
    this.title = 'Bill details',
    this.discount = 0,
  });

  final PriceBreakdown breakdown;
  final String title;
  final int discount;

  @override
  Widget build(BuildContext context) {
    return BillCard(
      title: title,
      rows: [
        ('Item total', formatInr(breakdown.subtotal)),
        (
          'Delivery fee',
          breakdown.deliveryFee == 0 ? 'FREE' : formatInr(breakdown.deliveryFee)
        ),
        ('Platform fee', formatInr(breakdown.platformFee)),
        if (discount > 0 || breakdown.discount > 0)
          (
            'Coupon discount',
            '-${formatInr(discount > 0 ? discount : breakdown.discount)}'
          ),
      ],
      totalLabel: 'To pay',
      total: formatInr(breakdown.total),
    );
  }
}

class BillCard extends StatelessWidget {
  const BillCard({
    super.key,
    required this.title,
    required this.rows,
    required this.totalLabel,
    required this.total,
  });

  final String title;
  final List<(String, String)> rows;
  final String totalLabel;
  final String total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(title, style: AppTextStyles.body(weight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(label,
                        style: AppTextStyles.body(size: 13, color: AppColors.mute)),
                  ),
                  Text(
                    value,
                    style: AppTextStyles.body(
                      size: 13,
                      color: value == 'FREE' ? AppColors.success : AppColors.paper,
                      weight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          const Divider(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(totalLabel,
                    style: AppTextStyles.body(size: 15, weight: FontWeight.w800)),
              ),
              Text(total,
                  style: AppTextStyles.body(size: 16, weight: FontWeight.w800)),
            ],
          ),
        ],
      ),
    );
  }
}
