// Persisted light/dark/system theme choice.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide light/dark choice, persisted on the phone.
/// `main.dart` listens to [themeModeSetting]; Settings changes it.
class ThemeModeSetting extends ValueNotifier<ThemeMode> {
  ThemeModeSetting() : super(ThemeMode.system);

  static const storageKey = 'nigoh.theme_mode';

  /// Restores the saved theme mode (system when none or unreadable).
  Future<void> load() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(storageKey);
      value = ThemeMode.values.firstWhere(
        (mode) => mode.name == raw,
        orElse: () => ThemeMode.system,
      );
    } catch (_) {
      // Unreadable preference: the system theme is a safe default.
    }
  }

  /// Applies and saves a new theme mode.
  Future<void> set(ThemeMode mode) async {
    value = mode;
    await (await SharedPreferences.getInstance()).setString(
      storageKey,
      mode.name,
    );
  }
}

final themeModeSetting = ThemeModeSetting();
