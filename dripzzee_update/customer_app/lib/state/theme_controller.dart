import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme/app_theme.dart';

enum AppearanceMode { system, light, dark }

extension AppearanceModeLabel on AppearanceMode {
  String get label => switch (this) {
        AppearanceMode.system => 'System default',
        AppearanceMode.light => 'Light',
        AppearanceMode.dark => 'Dark',
      };
}

/// Profile → Appearance. Remembers the choice on the device and follows the
/// phone's setting in "System default".
class ThemeController extends ChangeNotifier with WidgetsBindingObserver {
  ThemeController() {
    WidgetsBinding.instance.addObserver(this);
    _load();
    _apply();
  }

  static const _key = 'appearance_mode';
  AppearanceMode _mode = AppearanceMode.system;
  AppearanceMode get mode => _mode;

  Brightness get brightness => switch (_mode) {
        AppearanceMode.light => Brightness.light,
        AppearanceMode.dark => Brightness.dark,
        AppearanceMode.system =>
          WidgetsBinding.instance.platformDispatcher.platformBrightness,
      };

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_key);
      AppearanceMode? mode;
      for (final m in AppearanceMode.values) {
        if (m.name == saved) mode = m;
      }
      if (mode != null && mode != _mode) {
        _mode = mode;
        _apply();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> setMode(AppearanceMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    _apply();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, mode.name);
    } catch (_) {}
  }

  void _apply() {
    AppColors.use(brightness);
    SystemChrome.setSystemUIOverlayStyle(systemBarsStyle());
  }

  @override
  void didChangePlatformBrightness() {
    if (_mode != AppearanceMode.system) return;
    _apply();
    notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
