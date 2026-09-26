import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

InputDecoration appInputDecoration({
  String? label,
  String? hint,
  IconData? prefixIcon,
  Widget? suffix,
  String? helper,
}) {
  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color, width: width),
      );

  return InputDecoration(
    labelText: label,
    hintText: hint,
    helperText: helper,
    filled: true,
    fillColor: AppColors.panel,
    isDense: false,
    prefixIcon: prefixIcon == null
        ? null
        : Icon(prefixIcon, size: 20, color: AppColors.mute),
    suffixIcon: suffix,
    labelStyle: AppTextStyles.body(size: 14, color: AppColors.mute),
    floatingLabelStyle: AppTextStyles.body(size: 13, color: AppColors.shopper),
    hintStyle: AppTextStyles.body(size: 14, color: AppColors.faint),
    helperStyle: AppTextStyles.body(size: 12, color: AppColors.mute),
    errorStyle: AppTextStyles.body(size: 12, color: AppColors.danger),
    helperMaxLines: 2,
    errorMaxLines: 2,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: border(AppColors.line),
    enabledBorder: border(AppColors.line),
    disabledBorder: border(AppColors.line),
    focusedBorder: border(AppColors.shopper, 1.4),
    errorBorder: border(AppColors.danger),
    focusedErrorBorder: border(AppColors.danger, 1.4),
  );
}

class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.controller,
    this.label,
    this.hint,
    this.helper,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.autofillHints,
    this.prefixIcon,
    this.obscure = false,
    this.enabled = true,
    this.maxLines = 1,
    this.maxLength,
    this.textCapitalization = TextCapitalization.none,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String? label;
  final String? hint;
  final String? helper;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String>? autofillHints;
  final IconData? prefixIcon;
  final bool obscure;
  final bool enabled;
  final int maxLines;
  final int? maxLength;
  final TextCapitalization textCapitalization;
  final bool autofocus;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _hidden = widget.obscure;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      validator: widget.validator,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onSubmitted,
      autofillHints: widget.autofillHints,
      obscureText: _hidden,
      enabled: widget.enabled,
      maxLines: widget.obscure ? 1 : widget.maxLines,
      maxLength: widget.maxLength,
      autofocus: widget.autofocus,
      textCapitalization: widget.textCapitalization,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      style: AppTextStyles.body(size: 15),
      decoration: appInputDecoration(
        label: widget.label,
        hint: widget.hint,
        helper: widget.helper,
        prefixIcon: widget.prefixIcon,
        suffix: widget.obscure
            ? IconButton(
                tooltip: _hidden ? 'Show password' : 'Hide password',
                icon: Icon(
                  _hidden
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20,
                  color: AppColors.mute,
                ),
                onPressed: () => setState(() => _hidden = !_hidden),
              )
            : null,
      ),
    );
  }
}
