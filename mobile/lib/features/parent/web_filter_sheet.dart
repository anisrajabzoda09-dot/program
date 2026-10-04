// Файл: равзанаи «Филтри сайтҳо» барои волидайн — сатҳи синну сол, сайтҳои манъшуда ва ҳолати телефон.

import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../l10n/l10n.dart';
import '../../ui/nigoh_design.dart';
import '../../ui/widgets.dart';
import 'family_controller.dart';

/// Номи кӯтоҳи сатҳ барои корт ва рӯйхат.
String webFilterLevelLabel(String level) => switch (level) {
  WebFilter.levelKids => tr('То 12 сола'),
  WebFilter.levelTeen => tr('13–17 сола'),
  _ => tr('хомӯш'),
};

/// Шарҳи он ки ҳар сатҳ чиро мебандад.
String webFilterLevelHint(String level) => switch (level) {
  WebFilter.levelKids => tr(
    'Сайтҳои калонсолон, прокси ва VPN баста мешаванд. Дар Google ва YouTube ҷустуҷӯи бехатар ҳатмист.',
  ),
  WebFilter.levelTeen => tr(
    'Сайтҳои калонсолон баста мешаванд. Дар Google ва Bing ҷустуҷӯи бехатар ҳатмист.',
  ),
  _ => tr('Ҳамаи сайтҳо кушодаанд.'),
};

/// Матни ҳолати филтр дар телефони фарзанд барои волидайн.
String webFilterStateLabel(WebFilter f) {
  if (!f.enabled) return tr('Филтр хомӯш аст');
  return switch (f.state) {
    WebFilter.stateActive => tr('Дар телефони фарзанд фаъол аст'),
    WebFilter.stateNeedsPermission => tr(
      'Фарзанд бояд дар телефонаш иҷозат диҳад',
    ),
    WebFilter.stateOff => tr('Дар телефони фарзанд хомӯш аст'),
    _ => tr('Интизори телефони фарзанд'),
  };
}

/// Равзанаи танзими филтри сайтҳо.
class WebFilterSheet extends StatefulWidget {
  const WebFilterSheet({
    super.key,
    required this.controller,
    required this.child,
  });

  final FamilyController controller;
  final FamilyChild child;

  /// Ҳолати WebFilterSheet-ро месозад.
  @override
  State<WebFilterSheet> createState() => _WebFilterSheetState();
}

/// Сатҳи интихобшуда, рӯйхати сайтҳо ва ҳолати нигоҳдорӣ.
class _WebFilterSheetState extends State<WebFilterSheet> {
  late String level;
  late List<String> blocked;
  final _site = TextEditingController();
  String? _siteError;
  bool saving = false;

  /// Танзими ҳозираро мегирад; агар филтр ҳанӯз нагузошта бошад, сатҳро аз синну сол пешниҳод мекунад.
  @override
  void initState() {
    super.initState();
    final f = widget.child.webFilter;
    level = f.enabled
        ? f.level
        : (f.blocked.isEmpty
              ? WebFilter.suggestedLevel(widget.child.age)
              : WebFilter.levelOff);
    blocked = [...f.blocked];
  }

  /// Майдони матнро озод мекунад.
  @override
  void dispose() {
    _site.dispose();
    super.dispose();
  }

  /// Сайти навиштаро ба рӯйхат илова мекунад (агар дуруст ва нав бошад).
  void _addSite() {
    final domain = WebFilter.normalizeDomain(_site.text);
    setState(() {
      if (domain == null) {
        _siteError = tr('Суроғаи сайтро дуруст нависед, масалан tiktok.com');
      } else if (blocked.contains(domain)) {
        _siteError = tr('Ин сайт аллакай дар рӯйхат аст');
      } else if (blocked.length >= 100) {
        _siteError = tr('Ҳадди аксар 100 сайт');
      } else {
        blocked.add(domain);
        _site.clear();
        _siteError = null;
      }
    });
  }

  /// Танзимро ба сервер мефиристад ва равзанаро мебандад.
  Future<void> _save() async {
    setState(() => saving = true);
    try {
      await widget.controller.setWebFilter(
        widget.child,
        widget.child.webFilter.copyWith(level: level, blocked: blocked),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => saving = false);
      showMessage(context, e, error: true);
    }
  }

  /// Равзанаро бо се сатҳ, рӯйхати сайтҳо ва ҳолати телефон месозад.
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final suggested = WebFilter.suggestedLevel(widget.child.age);
    final current = widget.child.webFilter;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('Филтри сайтҳо'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              tr(
                'Сайтҳоеро, ки ба синну соли {name} мувофиқ нестанд, дар ҳама браузерҳо мебандад.',
                {'name': widget.child.name},
              ),
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            if (current.enabled) ...[
              const SizedBox(height: 12),
              _StateBanner(filter: current),
            ],
            const SizedBox(height: 16),
            for (final l in WebFilter.levels)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _LevelOption(
                  key: ValueKey('web-filter-$l'),
                  level: l,
                  selected: level == l,
                  suggested: l == suggested && l != WebFilter.levelOff,
                  onTap: () => setState(() => level = l),
                ),
              ),
            const SizedBox(height: 12),
            Text(
              tr('Сайтҳои иловагии манъшуда'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              tr('Ин сайтҳо ҳамроҳи филтри синну сол баста мешаванд.'),
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('web-filter-site'),
                    controller: _site,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _addSite(),
                    decoration: InputDecoration(
                      hintText: 'tiktok.com',
                      errorText: _siteError,
                      prefixIcon: const Icon(Icons.language_rounded),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  key: const ValueKey('web-filter-add'),
                  tooltip: tr('Илова кардан'),
                  onPressed: _addSite,
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
            if (blocked.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final d in blocked)
                    InputChip(
                      key: ValueKey('web-filter-chip-$d'),
                      label: Text(d),
                      onDeleted: () => setState(() => blocked.remove(d)),
                      deleteButtonTooltipMessage: tr('Хориҷ кардан'),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            Text(
              tr(
                'Филтр бо VPN-и маҳаллӣ дар телефони фарзанд кор мекунад: танҳо номи сайтҳо санҷида мешаванд, на мазмуни саҳифаҳо ва паёмҳо.',
              ),
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const ValueKey('web-filter-save'),
                onPressed: saving ? null : _save,
                child: saving
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(tr('Нигоҳ доштан')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Як сатҳи филтр ҳамчун корти интихобшаванда.
class _LevelOption extends StatelessWidget {
  const _LevelOption({
    super.key,
    required this.level,
    required this.selected,
    required this.suggested,
    required this.onTap,
  });

  final String level;
  final bool selected;
  final bool suggested;
  final VoidCallback onTap;

  /// Корти сатҳро бо нишона, ном, шарҳ ва белгии «тавсия» месозад.
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (level) {
      WebFilter.levelKids => NigohDesign.mint,
      WebFilter.levelTeen => NigohDesign.blue,
      _ => scheme.outline,
    };
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? color.withValues(alpha: .10) : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: selected ? color : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: selected ? color : scheme.outline,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            level == WebFilter.levelOff
                                ? tr('Хомӯш')
                                : webFilterLevelLabel(level),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          if (suggested)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: .15),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                tr('Барои синну сол'),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: color,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        webFilterLevelHint(level),
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Хати ҳолат: филтр дар телефони фарзанд кор мекунад ё иҷозат лозим аст.
class _StateBanner extends StatelessWidget {
  const _StateBanner({required this.filter});

  final WebFilter filter;

  /// Хатро бо ранги мувофиқи ҳолат месозад.
  @override
  Widget build(BuildContext context) {
    final ok = filter.state == WebFilter.stateActive;
    final color = ok ? NigohDesign.mint : NigohDesign.amber;
    return Container(
      key: const ValueKey('web-filter-state'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            ok ? Icons.verified_user_rounded : Icons.info_outline_rounded,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(webFilterStateLabel(filter))),
        ],
      ),
    );
  }
}
