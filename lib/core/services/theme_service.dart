import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Theme mode preference — persisted across sessions.
enum AppThemeMode { system, light, dark }

/// Persists the user's theme preference and exposes it as [ThemeMode].
class ThemeService extends ChangeNotifier {
  static const String _key = 'theme_mode';

  AppThemeMode _mode = AppThemeMode.system;

  /// Current persisted mode.
  AppThemeMode get mode => _mode;

  /// Converts [AppThemeMode] to Flutter's [ThemeMode].
  ThemeMode get flutterMode => switch (_mode) {
        AppThemeMode.system => ThemeMode.system,
        AppThemeMode.light  => ThemeMode.light,
        AppThemeMode.dark   => ThemeMode.dark,
      };

  /// Loads the persisted preference from [SharedPreferences].
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      _mode = AppThemeMode.values.firstWhere(
        (e) => e.name == raw,
        orElse: () => AppThemeMode.system,
      );
      notifyListeners();
    }
  }

  /// Persists [m] to [SharedPreferences] and notifies listeners.
  Future<void> setMode(AppThemeMode m) async {
    _mode = m;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, m.name);
  }
}
