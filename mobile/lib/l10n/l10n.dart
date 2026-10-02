import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'strings_child.dart';
import 'strings_core.dart';
import 'strings_parent.dart';

/// App language: 'tg' (default, source texts), 'ru' or 'en'.
///
/// Usage: wrap every user-visible Tajik literal with [tr]:
///   Text(tr('Барномаҳо'))
///   Text(tr('Пайваст бо {name}', {'name': parentName}))
/// Translations live in strings_core.dart / strings_parent.dart /
/// strings_child.dart as `'Tajik source': ['Русский', 'English']`.
/// A missing translation falls back to the Tajik text.
class AppLanguage extends ValueNotifier<String> {
  AppLanguage() : super('tg');

  static const supported = ['tg', 'ru', 'en'];
  static const names = {'tg': 'Тоҷикӣ', 'ru': 'Русский', 'en': 'English'};
  static const _key = 'nigoh.locale';

  Future<void> load() async {
    try {
      final saved = (await SharedPreferences.getInstance()).getString(_key);
      if (saved != null && supported.contains(saved)) value = saved;
    } catch (_) {}
  }

  Future<void> set(String lang) async {
    if (!supported.contains(lang)) return;
    value = lang;
    try {
      await (await SharedPreferences.getInstance()).setString(_key, lang);
    } catch (_) {}
  }

  /// Locale for Flutter's own widgets (date/time pickers, etc.).
  /// Material has no Tajik localizations, so Tajik uses Russian ones.
  Locale get materialLocale => Locale(value == 'en' ? 'en' : 'ru');
}

final appLanguage = AppLanguage();

final Map<String, List<String>> _dictionary = {
  ...coreStrings,
  ...parentStrings,
  ...childStrings,
};

String tr(String tajik, [Map<String, Object?> args = const {}]) {
  final lang = appLanguage.value;
  var text = tajik;
  if (lang != 'tg') {
    final pair = _dictionary[tajik];
    if (pair != null && pair.length == 2) text = lang == 'ru' ? pair[0] : pair[1];
  }
  if (args.isEmpty) return text;
  return text.replaceAllMapped(
    RegExp(r'\{(\w+)\}'),
    (m) => args.containsKey(m[1]) ? '${args[m[1]]}' : m[0]!,
  );
}

/// All Tajik keys that have no translation (used by tests).
Iterable<String> untranslatedKeys(Iterable<String> keys) =>
    keys.where((k) => !_dictionary.containsKey(k));
