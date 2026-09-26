import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class RatingBadge extends StatelessWidget {
  const RatingBadge({super.key, required this.rating, this.count});

  final double rating;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: 13, color: AppColors.success),
          const SizedBox(width: 3),
          Text(
            count == null
                ? rating.toStringAsFixed(1)
                : '${rating.toStringAsFixed(1)} · $count',
            style: AppTextStyles.mono(
              size: 11,
              color: AppColors.success,
              weight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
