import 'package:flutter/material.dart';

import '../../../core/pricing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/drip_image.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/rating_badge.dart';
import '../../../data/models/fashion_category.dart';
import '../../../data/models/store.dart';
import '../../../navigation.dart';

class StoreCard extends StatelessWidget {
  const StoreCard({super.key, required this.store, required this.heroTag});

  final Store store;
  final String heroTag;

  @override
  Widget build(BuildContext context) {
    final s = store;
    final meta = [
      if (s.distanceKm != null) formatDistance(s.distanceKm!),
      s.etaLabel,
      s.deliveryFee == 0
          ? 'Free delivery'
          : 'Free delivery over ${formatInr(PricingRules.freeDeliveryThreshold)}',
    ].join('  ·  ');

    return Pressable(
      semanticLabel: s.name,
      onTap: () => AppNav.openStore(context, s.id, initial: s, heroTag: heroTag),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.panel,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 7,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: heroTag,
                    child: DripImage(
                      url: s.imageUrl,
                      label: s.name,
                      icon: Icons.storefront_outlined,
                    ),
                  ),
                  if (s.tags.contains('festive'))
                    Positioned(
                      left: 10,
                      top: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.ink.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'FESTIVE EDIT',
                          style: AppTextStyles.mono(
                            size: 9,
                            color: AppColors.marigold,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          s.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.heading(size: 18),
                        ),
                      ),
                      if (s.hasRating) ...[
                        const SizedBox(width: 8),
                        RatingBadge(rating: s.rating),
                      ],
                    ],
                  ),
                  if (s.categories.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      s.categories.take(3).map(categoryLabel).join(' • '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body(size: 12, color: AppColors.mute),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    meta,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.mono(size: 10.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
