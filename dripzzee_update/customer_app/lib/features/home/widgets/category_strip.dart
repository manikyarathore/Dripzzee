import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/pressable.dart';
import '../../../data/models/fashion_category.dart';
import '../../../navigation.dart';

/// Gradient behind each category icon (falls back to the brand violet).
const _categoryGradients = <String, List<Color>>{
  'women': [Color(0xFFFF8FB8), Color(0xFFC2185B)],
  'men': [Color(0xFF7CB7FF), Color(0xFF3949AB)],
  'ethnic': [Color(0xFFFFC857), Color(0xFFE5484D)],
  'festive': [Color(0xFFFFB25B), Color(0xFFB8327A)],
  'sneakers': [Color(0xFF5EEAD4), Color(0xFF0F766E)],
  'streetwear': [Color(0xFFB0B6C3), Color(0xFF3F4452)],
  'accessories': [Color(0xFFE9C46A), Color(0xFF9C6B1F)],
  'new': [Color(0xFFD9A7FF), Color(0xFF6D28D9)],
};

class CategoryStrip extends StatelessWidget {
  const CategoryStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final height = 76 + MediaQuery.textScalerOf(context).scale(34);
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: kCategories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, i) {
          final c = kCategories[i];
          final colors = _categoryGradients[c.id] ??
              const [Color(0xFFC77DFF), AppColors.shopperDeep];
          return Pressable(
            semanticLabel: c.label,
            onTap: () => AppNav.openProducts(context, c.filter),
            child: SizedBox(
              width: 70,
              child: Column(
                children: [
                  Container(
                    width: 66,
                    height: 66,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: colors,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colors.last.withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Soft highlight for depth.
                        Positioned(
                          left: -10,
                          top: -14,
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.18),
                            ),
                          ),
                        ),
                        Center(
                          child: Icon(c.icon, color: Colors.white, size: 28),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    c.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body(size: 12, weight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
