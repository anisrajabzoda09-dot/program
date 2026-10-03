import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

/// Short code shown next to the globe icon.
String languageCode(String lang) => switch (lang) {
  'ru' => 'RU',
  'en' => 'EN',
  _ => 'TJ',
};

/// Bottom sheet with Тоҷикӣ / Русский / English. Picking one saves it and
/// the whole app switches language right away.
Future<void> showLanguageSheet(BuildContext context) async {
  final picked = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
        child: RadioGroup<String>(
          groupValue: appLanguage.value,
          onChanged: (value) => Navigator.pop(sheetContext, value),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  tr('Забон'),
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
              ),
              for (final lang in AppLanguage.supported)
                RadioListTile<String>(
                  key: ValueKey('lang-$lang'),
                  value: lang,
                  title: Text(AppLanguage.names[lang]!),
                  secondary: Text(
                    languageCode(lang),
                    style: TextStyle(
                      color: Theme.of(sheetContext)
                          .colorScheme
                          .onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
  if (picked != null && picked != appLanguage.value) {
    await appLanguage.set(picked);
  }
}

/// Compact globe + code button for screens before sign-in.
class LanguageButton extends StatelessWidget {
  const LanguageButton({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String>(
    valueListenable: appLanguage,
    builder: (_, lang, _) => TextButton.icon(
      key: const ValueKey('language-button'),
      onPressed: () => showLanguageSheet(context),
      style: TextButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        minimumSize: const Size(48, 40),
      ),
      icon: const Icon(Icons.language_rounded, size: 20),
      label: Text(
        languageCode(lang),
        semanticsLabel: tr('Забон: {language}', {
          'language': AppLanguage.names[lang],
        }),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
  );
}
