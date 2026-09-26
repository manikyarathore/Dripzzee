import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

PreferredSizeWidget dripAppBar({
  required String title,
  List<Widget>? actions,
  PreferredSizeWidget? bottom,
  bool automaticallyImplyLeading = true,
}) {
  return AppBar(
    backgroundColor: AppColors.ink,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    automaticallyImplyLeading: automaticallyImplyLeading,
    foregroundColor: AppColors.paper,
    titleSpacing: automaticallyImplyLeading ? 0 : 16,
    title: Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTextStyles.heading(size: 20),
    ),
    actions: actions,
    bottom: bottom,
  );
}
