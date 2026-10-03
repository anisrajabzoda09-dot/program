// Файл: нигоҳдорӣ ва иваз кардани theme.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Додаҳо ва рафтори марбут ба нигоҳдорӣ ва иваз кардани theme-ро ифода мекунад.
class ThemeModeSetting extends ValueNotifier<ThemeMode> {
  ThemeModeSetting() : super(ThemeMode.system);

  static const storageKey = 'nigoh.theme_mode';

  /// load додаҳои мавзӯи рӯзу шаб-ро мехонад ва ҳолати ThemeModeSetting-ро нав мекунад.
  Future<void> load() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(storageKey);
      value = ThemeMode.values.firstWhere(
        (mode) => mode.name == raw,
        orElse: () => ThemeMode.system,
      );
    } catch (_) {
      // Қадами дохилии нигоҳдорӣ ва иваз кардани theme.
    }
  }

  /// set ҳолатро тағйир дода, интерфейс ё server-ро нав мекунад.
  Future<void> set(ThemeMode mode) async {
    value = mode;
    await (await SharedPreferences.getInstance()).setString(
      storageKey,
      mode.name,
    );
  }
}

final themeModeSetting = ThemeModeSetting();
