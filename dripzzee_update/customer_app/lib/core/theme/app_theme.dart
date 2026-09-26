import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// One complete set of colour tokens. Dripzzee ships a dark and a light set;
/// [AppColors] points at whichever is active.
class AppPalette {
  const AppPalette({
    required this.brightness,
    required this.ink,
    required this.panel,
    required this.panelHover,
    required this.line,
    required this.lineStrong,
    required this.paper,
    required this.mute,
    required this.faint,
    required this.shopper,
    required this.shopperSoft,
    required this.success,
    required this.warning,
    required this.danger,
  });

  final Brightness brightness;
  final Color ink; // background
  final Color panel; // cards, sheets, inputs
  final Color panelHover; // elevated / pressed
  final Color line;
  final Color lineStrong;
  final Color paper; // primary text
  final Color mute; // secondary text
  final Color faint; // tertiary / disabled
  final Color shopper; // accent
  final Color shopperSoft;
  final Color success;
  final Color warning;
  final Color danger;

  static const dark = AppPalette(
    brightness: Brightness.dark,
    ink: Color(0xFF0A0A0C),
    panel: Color(0xFF111114),
    panelHover: Color(0xFF17171B),
    line: Color(0x17FFFFFF),
    lineStrong: Color(0x29FFFFFF),
    paper: Color(0xFFF3F1F6),
    mute: Color(0xFF8D899A),
    faint: Color(0xFF514E5A),
    shopper: Color(0xFFC77DFF),
    shopperSoft: Color(0x1FC77DFF),
    success: Color(0xFF5BD69A),
    warning: Color(0xFFF2C14E),
    danger: Color(0xFFFF6B7A),
  );

  static const light = AppPalette(
    brightness: Brightness.light,
    ink: Color(0xFFF6F5F8),
    panel: Color(0xFFFFFFFF),
    panelHover: Color(0xFFEFEDF3),
    line: Color(0x14000000),
    lineStrong: Color(0x26000000),
    paper: Color(0xFF17151C),
    mute: Color(0xFF6B6777),
    faint: Color(0xFFB4B0BD),
    shopper: Color(0xFF8E3FD6),
    shopperSoft: Color(0x1A8E3FD6),
    success: Color(0xFF1E9A58),
    warning: Color(0xFFB7791F),
    danger: Color(0xFFD93A4B),
  );
}

/// Dripzzee design tokens. Solid, content-first surfaces; violet is reserved
/// for actions, selection and small accents. Values follow the active
/// [AppPalette] (Profile → Appearance), so read them at build time.
class AppColors {
  AppColors._();

  static AppPalette _p = AppPalette.dark;

  static AppPalette get palette => _p;
  static bool get isLight => _p.brightness == Brightness.light;

  /// Switches the palette. Call through ThemeController, which also
  /// rebuilds the widget tree.
  static void use(Brightness brightness) =>
      _p = brightness == Brightness.light ? AppPalette.light : AppPalette.dark;

  static Color get ink => _p.ink;
  static Color get panel => _p.panel;
  static Color get panelHover => _p.panelHover;
  static Color get line => _p.line;
  static Color get lineStrong => _p.lineStrong;
  static Color get paper => _p.paper;
  static Color get mute => _p.mute;
  static Color get faint => _p.faint;
  static Color get shopper => _p.shopper;
  static Color get shopperSoft => _p.shopperSoft;
  static Color get success => _p.success;
  static Color get warning => _p.warning;
  static Color get danger => _p.danger;

  // Brand colours that don't change with the theme.
  static const shopperDeep = Color(0xFF6D28D9);
  static const marigold = Color(0xFFF5B942);

  /// Text/icon colour on top of an accent-filled surface.
  static const onAccent = Color(0xFFFFFFFF);
}

class AppRadius {
  AppRadius._();
  static const sm = 10.0;
  static const md = 16.0;
  static const lg = 22.0;
}

class AppSpacing {
  AppSpacing._();
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

class AppTextStyles {
  AppTextStyles._();

  /// Fraunces — editorial headings.
  static TextStyle heading({
    double size = 20,
    FontWeight? weight,
    Color? color,
    double? height,
  }) =>
      GoogleFonts.fraunces(
        fontSize: size,
        fontWeight: weight ?? FontWeight.w500,
        color: color ?? AppColors.paper,
        height: height ?? 1.15,
      );

  /// Manrope — UI and body copy.
  static TextStyle body({
    double size = 14,
    Color? color,
    FontWeight? weight,
    double? height,
    TextDecoration? decoration,
  }) =>
      GoogleFonts.manrope(
        fontSize: size,
        fontWeight: weight ?? FontWeight.w500,
        color: color ?? AppColors.paper,
        height: height,
        decoration: decoration,
        decorationColor: color ?? AppColors.mute,
      );

  /// JetBrains Mono — metadata: distance, rating, ETA, small labels.
  static TextStyle mono({double size = 11, Color? color, FontWeight? weight}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: size,
        letterSpacing: 0.4,
        color: color ?? AppColors.mute,
        fontWeight: weight ?? FontWeight.w400,
      );
}

ThemeData buildAppTheme() {
  final light = AppColors.isLight;
  final base = ThemeData(
    brightness: light ? Brightness.light : Brightness.dark,
    useMaterial3: true,
  );
  final scheme = (light ? const ColorScheme.light() : const ColorScheme.dark())
      .copyWith(
    primary: AppColors.shopper,
    onPrimary: AppColors.onAccent,
    secondary: AppColors.shopperDeep,
    onSecondary: AppColors.onAccent,
    surface: AppColors.panel,
    onSurface: AppColors.paper,
    error: AppColors.danger,
    onError: AppColors.onAccent,
  );

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.ink,
    canvasColor: AppColors.ink,
    colorScheme: scheme,
    textTheme: GoogleFonts.manropeTextTheme(base.textTheme).apply(
      bodyColor: AppColors.paper,
      displayColor: AppColors.paper,
    ),
    iconTheme: IconThemeData(color: AppColors.paper),
    dividerTheme: DividerThemeData(
      color: AppColors.line,
      thickness: 1,
      space: 1,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.panelHover,
      contentTextStyle: AppTextStyles.body(size: 13),
      actionTextColor: AppColors.shopper,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        side: BorderSide(color: AppColors.line),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: AppColors.panel,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: AppColors.faint,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: AppColors.shopper),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: AppColors.shopper,
      selectionColor: AppColors.shopper.withValues(alpha: 0.3),
      selectionHandleColor: AppColors.shopper,
    ),
    splashFactory: InkRipple.splashFactory,
  );
}

/// Status/navigation bar colours matching the active palette.
SystemUiOverlayStyle systemBarsStyle() {
  final light = AppColors.isLight;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: light ? Brightness.dark : Brightness.light,
    statusBarBrightness: light ? Brightness.light : Brightness.dark,
    systemNavigationBarColor: AppColors.ink,
    systemNavigationBarIconBrightness: light ? Brightness.dark : Brightness.light,
  );
}
