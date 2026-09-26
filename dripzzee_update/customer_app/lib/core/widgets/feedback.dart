import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

void showSnack(
  BuildContext context,
  String message, {
  bool error = false,
  SnackBarAction? action,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(buildSnack(message, error: error, action: action));
}

SnackBar buildSnack(String message, {bool error = false, SnackBarAction? action}) {
  return SnackBar(
    action: action,
    content: Row(
      children: [
        Icon(
          error ? Icons.error_outline : Icons.check_circle_outline,
          color: error ? AppColors.danger : AppColors.success,
          size: 18,
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(message)),
      ],
    ),
  );
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.panel,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: AppColors.line),
      ),
      title: Text(title, style: AppTextStyles.heading(size: 20)),
      content: Text(
        message,
        style: AppTextStyles.body(size: 14, color: AppColors.mute, height: 1.45),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(
            cancelLabel,
            style: AppTextStyles.body(color: AppColors.mute, weight: FontWeight.w700),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(
            confirmLabel,
            style: AppTextStyles.body(
              color: destructive ? AppColors.danger : AppColors.shopper,
              weight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
  return result ?? false;
}
