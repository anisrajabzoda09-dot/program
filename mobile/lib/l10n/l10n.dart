// Файл: интихоби забон ва тарҷумаи матнҳо.

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'strings_child.dart';
import 'strings_core.dart';
import 'strings_parent.dart';

/// Додаҳо ва рафтори марбут ба интихоби забон ва тарҷумаи матнҳоро ифода мекунад.
class AppLanguage extends ValueNotifier<String> {
  AppLanguage() : super('tg');

  static const supported = ['tg', 'ru', 'en'];
  static const names = {'tg': 'Тоҷикӣ', 'ru': 'Русский', 'en': 'English'};
  static const _key = 'nigoh.locale';

  /// load додаҳои l10n-ро мехонад ва ҳолати AppLanguage-ро нав мекунад.
  Future<void> load() async {
    try {
      final saved = (await SharedPreferences.getInstance()).getString(_key);
      if (saved != null && supported.contains(saved)) value = saved;
    } catch (_) {}
  }

  /// set ҳолатро тағйир дода, интерфейс ё server-ро нав мекунад.
  Future<void> set(String lang) async {
    if (!supported.contains(lang)) return;
    value = lang;
    try {
      await (await SharedPreferences.getInstance()).setString(_key, lang);
    } catch (_) {}
  }

  /// Қимати materialLocale-ро барои интихоби забон ва тарҷумаи матнҳо нигоҳ медорад.
  Locale get materialLocale => Locale(value == 'en' ? 'en' : 'ru');
}

final appLanguage = AppLanguage();

final Map<String, List<String>> _dictionary = {
  ...coreStrings,
  ...parentStrings,
  ...childStrings,
};

/// tr мантиқи зарурии интихоби забон ва тарҷумаи матнҳоро иҷро мекунад.
String tr(String tajik, [Map<String, Object?> args = const {}]) {
  final lang = appLanguage.value;
  var text = tajik;
  if (lang != 'tg') {
    final pair = _dictionary[tajik];
    if (pair != null && pair.length == 2) {
      text = lang == 'ru' ? pair[0] : pair[1];
    }
  }
  if (args.isEmpty) return text;
  return text.replaceAllMapped(
    RegExp(r'\{(\w+)\}'),
    (m) => args.containsKey(m[1]) ? '${args[m[1]]}' : m[0]!,
  );
}

/// untranslatedKeys мантиқи зарурии интихоби забон ва тарҷумаи матнҳоро иҷро мекунад.
Iterable<String> untranslatedKeys(Iterable<String> keys) =>
    keys.where((k) => !_dictionary.containsKey(k));
