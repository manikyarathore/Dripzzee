import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'skeleton.dart';

/// Network image with shimmer while loading and a designed fallback when the
/// URL is missing or broken, so empty catalog images never look like a bug.
class DripImage extends StatelessWidget {
  const DripImage({
    super.key,
    required this.url,
    this.label = '',
    this.icon = Icons.checkroom_outlined,
    this.fit = BoxFit.cover,
    this.borderRadius = BorderRadius.zero,
  });

  final String? url;
  final String label;
  final IconData icon;
  final BoxFit fit;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final src = url;
    final Widget child = (src == null || src.isEmpty)
        ? _Fallback(label: label, icon: icon)
        : CachedNetworkImage(
            imageUrl: src,
            fit: fit,
            fadeInDuration: const Duration(milliseconds: 220),
            placeholder: (context, _) => const SkeletonBox(radius: 0),
            errorWidget: (context, _, __) =>
                _Fallback(label: label, icon: icon),
          );
    return ClipRRect(borderRadius: borderRadius, child: child);
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showLabel = label.isNotEmpty && constraints.maxHeight > 110;
        return Container(
          color: AppColors.panelHover,
          alignment: Alignment.center,
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: AppColors.faint, size: 30),
              if (showLabel) ...[
                const SizedBox(height: 8),
                Text(
                  label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.mono(size: 10, color: AppColors.faint),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
