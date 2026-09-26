import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'pressable.dart';

class DripChip extends StatelessWidget {
  const DripChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.enabled = true,
    this.swatch,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool enabled;
  final Color? swatch;

  @override
  Widget build(BuildContext context) {
    final fg = !enabled
        ? AppColors.faint
        : selected
            ? AppColors.shopper
            : AppColors.paper;
    return Semantics(
      selected: selected,
      enabled: enabled,
      child: Pressable(
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: selected ? AppColors.shopperSoft : AppColors.panel,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? AppColors.shopper : AppColors.line,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (swatch != null) ...[
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: swatch,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.lineStrong),
                  ),
                ),
                const SizedBox(width: 7),
              ] else if (icon != null) ...[
                Icon(icon, size: 15, color: fg),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: AppTextStyles.body(
                  size: 13,
                  color: fg,
                  weight: FontWeight.w600,
                  decoration: enabled ? null : TextDecoration.lineThrough,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
