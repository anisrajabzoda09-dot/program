import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nigoh_family_parent/l10n/l10n.dart';
import 'package:nigoh_family_parent/l10n/strings_child.dart';
import 'package:nigoh_family_parent/l10n/strings_core.dart';
import 'package:nigoh_family_parent/l10n/strings_parent.dart';

/// Final guard: every tr('…') key used anywhere in lib/ has a Russian and an
/// English translation with the same {placeholders}.
void main() {
  const lit = r"""(?:'(?:[^'\\\n]|\\.)*'|"(?:[^"\\\n]|\\.)*")""";
  final call = RegExp(r'\btr\(\s*(' + lit + r'(?:\s*' + lit + r')*)');
  final part = RegExp(lit);

  String join(String group) => part
      .allMatches(group)
      .map(
        (m) => m[0]!
            .substring(1, m[0]!.length - 1)
            .replaceAll(r'\n', '\n')
            .replaceAll(r"\'", "'")
            .replaceAll(r'\"', '"'),
      )
      .join();

  Set<String> usedKeys() {
    final keys = <String>{};
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File ||
          !f.path.endsWith('.dart') ||
          f.uri.pathSegments.contains('l10n')) {
        continue;
      }
      for (final m in call.allMatches(f.readAsStringSync())) {
        keys.add(join(m[1]!));
      }
    }
    return keys;
  }

  test('every tr() key in the app is translated', () {
    final keys = usedKeys();
    expect(keys.length, greaterThan(300));
    final missing = untranslatedKeys(keys).toList()..sort();
    expect(
      missing,
      isEmpty,
      reason: 'Missing translations:\n${missing.join('\n')}',
    );
  });

  test('all entries have ru/en with identical placeholders', () {
    final ph = RegExp(r'\{(\w+)\}');
    Set<String> names(String s) => ph.allMatches(s).map((m) => m[1]!).toSet();
    for (final dict in [coreStrings, parentStrings, childStrings]) {
      dict.forEach((tg, pair) {
        expect(pair.length, 2, reason: tg);
        expect(pair[0].trim(), isNotEmpty, reason: tg);
        expect(pair[1].trim(), isNotEmpty, reason: tg);
        expect(names(pair[0]), names(tg), reason: 'ru placeholders: $tg');
        expect(names(pair[1]), names(tg), reason: 'en placeholders: $tg');
      });
    }
  });

  test('switching language changes tr() output', () {
    appLanguage.value = 'ru';
    expect(tr('Барномаҳо'), isNot('Барномаҳо'));
    appLanguage.value = 'en';
    expect(tr('Барномаҳо'), isNot('Барномаҳо'));
    appLanguage.value = 'tg';
    expect(tr('Барномаҳо'), 'Барномаҳо');
  });
}
