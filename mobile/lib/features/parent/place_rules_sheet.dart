// Файл: равзанаи «Қоидаҳои ин ҷой» — вақте фарзанд дар ҷойи интихобшуда (масалан мактаб) аст,
// кадом барномаҳо баста, бо лимит ё ҳамеша кушодаанд, ва огоҳии «расид / баромад».

import 'package:flutter/material.dart';

import '../../core/app_categories.dart';
import '../../core/models.dart';
import '../../l10n/l10n.dart';
import '../../ui/nigoh_design.dart';
import '../../ui/widgets.dart';
import 'family_controller.dart';

/// Лимитҳое, ки волидайн дар ҷой интихоб карда метавонанд (дақиқа).
const placeLimitChoices = [10, 15, 20, 30, 45, 60, 90, 120];

/// Категорияҳое, ки тугмаи «Мисли мактаб» мебандад.
const placeQuickBlockCategories = {
  AppCategory.games,
  AppCategory.social,
  AppCategory.video,
};

/// Матни кӯтоҳи қоида барои рӯйхат: «Баста», «Лимит 20 дақ», «Ҳамеша кушода».
String placeRuleLabel(PlaceAppRule? rule) => switch (rule?.mode) {
  PlaceAppRule.block => tr('Баста'),
  PlaceAppRule.limit => tr('Лимит {n} дақ', {'n': rule!.minutes}),
  PlaceAppRule.allow => tr('Ҳамеша кушода'),
  _ => tr('Мисли ҳамеша'),
};

/// Шарҳи кӯтоҳи ҷой барои рӯйхати ҷойҳо: «3 қоида · огоҳӣ».
String placeRulesSummary(SafePlace place) {
  final parts = <String>[
    if (place.rules.isNotEmpty) tr('{n} қоида', {'n': place.rules.length}),
    if (place.notify) tr('огоҳӣ'),
  ];
  return parts.isEmpty ? tr('қоида нест') : parts.join(' · ');
}

/// Равзанаи танзими қоидаҳои як ҷой.
class PlaceRulesSheet extends StatefulWidget {
  const PlaceRulesSheet({
    super.key,
    required this.controller,
    required this.child,
    required this.place,
  });

  final FamilyController controller;
  final FamilyChild child;
  final SafePlace place;

  /// Ҳолати PlaceRulesSheet-ро месозад.
  @override
  State<PlaceRulesSheet> createState() => _PlaceRulesSheetState();
}

/// Қоидаҳои таҳриршаванда, ҷустуҷӯ ва ҳолати нигоҳдорӣ.
class _PlaceRulesSheetState extends State<PlaceRulesSheet> {
  late Map<String, PlaceAppRule> rules = {...widget.place.rules};
  late bool notify = widget.place.notify;
  String query = '';
  bool saving = false;

  /// Барномаҳои фарзанд, ки ба ҷустуҷӯ мувофиқанд; барномаҳои бо қоида аввал.
  List<ChildApp> get _apps {
    final q = query.trim().toLowerCase();
    final list = widget.child.apps
        .where((a) => q.isEmpty || a.name.toLowerCase().contains(q))
        .toList();
    list.sort((a, b) {
      final ra = rules.containsKey(a.packageName) ? 0 : 1;
      final rb = rules.containsKey(b.packageName) ? 0 : 1;
      return ra != rb
          ? ra - rb
          : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return list;
  }

  /// Қоидаи як барномаро иваз мекунад (null — «мисли ҳамеша»).
  void _set(String package, PlaceAppRule? rule) => setState(() {
    if (rule == null) {
      rules.remove(package);
    } else {
      rules[package] = rule;
    }
  });

  /// Бозиҳо, видео ва шабакаҳоро дар ин ҷой мебандад (занг ва SMS дахл намебинанд).
  void _quickSchool() => setState(() {
    for (final a in widget.child.apps) {
      if (isEssentialApp(a.packageName)) continue;
      if (placeQuickBlockCategories.contains(categoryOf(a))) {
        rules[a.packageName] = const PlaceAppRule(PlaceAppRule.block);
      }
    }
  });

  /// Қоидаҳоро ба сервер мефиристад ва равзанаро мебандад.
  Future<void> _save() async {
    setState(() => saving = true);
    try {
      await widget.controller.setPlaceRules(
        widget.child.id,
        widget.place,
        rules: rules,
        notify: notify,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => saving = false);
      showMessage(context, e, error: true);
    }
  }

  /// Равзанаро бо огоҳӣ, тугмаи зуд, ҷустуҷӯ ва рӯйхати барномаҳо месозад.
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final apps = _apps;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .88,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('Қоидаҳои «{place}»', {'place': widget.place.name}),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tr(
                      'Вақте {name} дар ин ҷой аст, ин қоидаҳо амал мекунанд — ҳатто бе интернет. Занг ва SMS ҳеҷ гоҳ баста намешаванд.',
                      {'name': widget.child.name},
                    ),
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                  SwitchListTile(
                    key: const ValueKey('place-notify'),
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(
                      Icons.notifications_active_rounded,
                      color: NigohDesign.blue,
                    ),
                    title: Text(tr('Огоҳӣ: расид ва баромад')),
                    subtitle: Text(
                      tr(
                        'Ба шумо хабар меояд, вақте {name} ба ин ҷо меояд ё меравад.',
                        {'name': widget.child.name},
                      ),
                    ),
                    value: notify,
                    onChanged: (v) => setState(() => notify = v),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ActionChip(
                        key: const ValueKey('place-quick-school'),
                        avatar: const Icon(Icons.school_rounded, size: 18),
                        label: Text(tr('Бозиҳо, видео ва шабакаҳоро бастан')),
                        onPressed: widget.child.apps.isEmpty
                            ? null
                            : _quickSchool,
                      ),
                      if (rules.isNotEmpty)
                        ActionChip(
                          key: const ValueKey('place-clear'),
                          avatar: const Icon(
                            Icons.restart_alt_rounded,
                            size: 18,
                          ),
                          label: Text(tr('Ҳамаро пок кардан')),
                          onPressed: () => setState(rules.clear),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const ValueKey('place-search'),
                    onChanged: (v) => setState(() => query = v),
                    decoration: InputDecoration(
                      hintText: tr('Ҷустуҷӯи барнома'),
                      prefixIcon: const Icon(Icons.search_rounded),
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: widget.child.apps.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        tr(
                          'Рӯйхати барномаҳо ҳанӯз аз телефони фарзанд наомадааст.',
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: apps.length,
                      itemBuilder: (_, i) => _AppRuleRow(
                        app: apps[i],
                        rule: rules[apps[i].packageName],
                        onChanged: (r) => _set(apps[i].packageName, r),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: FilledButton(
                key: const ValueKey('place-save'),
                onPressed: saving ? null : _save,
                child: saving
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        rules.isEmpty
                            ? tr('Нигоҳ доштан')
                            : tr('Нигоҳ доштан ({n} қоида)', {
                                'n': rules.length,
                              }),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Як сатри барнома: нишона, ном ва интихоби қоида дар ин ҷой.
class _AppRuleRow extends StatelessWidget {
  const _AppRuleRow({
    required this.app,
    required this.rule,
    required this.onChanged,
  });

  final ChildApp app;
  final PlaceAppRule? rule;
  final ValueChanged<PlaceAppRule?> onChanged;

  /// Сатрро бо менюи қоида месозад; барномаҳои занг ва SMS баста намешаванд.
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final essential = isEssentialApp(app.packageName);
    final color = switch (rule?.mode) {
      PlaceAppRule.block => NigohDesign.coral,
      PlaceAppRule.limit => NigohDesign.amber,
      PlaceAppRule.allow => NigohDesign.mint,
      _ => scheme.onSurfaceVariant,
    };
    return ListTile(
      key: ValueKey('place-rule-${app.packageName}'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: NigohAppIcon(
        icon: app.iconBase64,
        seed: app.packageName,
        size: 38,
        locked: rule?.mode == PlaceAppRule.block,
      ),
      title: Text(app.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        essential ? tr('Занг ва SMS ҳамеша кушода') : placeRuleLabel(rule),
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
      trailing: essential
          ? null
          : PopupMenuButton<String>(
              key: ValueKey('place-menu-${app.packageName}'),
              tooltip: tr('Қоида дар ин ҷой'),
              icon: const Icon(Icons.tune_rounded),
              onSelected: (value) {
                if (value == 'same') return onChanged(null);
                if (value == PlaceAppRule.block ||
                    value == PlaceAppRule.allow) {
                  return onChanged(PlaceAppRule(value));
                }
                onChanged(
                  PlaceAppRule(
                    PlaceAppRule.limit,
                    minutes: int.parse(value.substring('limit:'.length)),
                  ),
                );
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'same', child: Text(tr('Мисли ҳамеша'))),
                PopupMenuItem(
                  value: PlaceAppRule.block,
                  child: Text(tr('Баста')),
                ),
                for (final m in placeLimitChoices)
                  PopupMenuItem(
                    value: 'limit:$m',
                    child: Text(tr('Лимит {n} дақ', {'n': m})),
                  ),
                PopupMenuItem(
                  value: PlaceAppRule.allow,
                  child: Text(tr('Ҳамеша кушода')),
                ),
              ],
            ),
    );
  }
}
