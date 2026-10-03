// Parent "Apps" tab: the selected child's installed apps with block switches,
// daily limits, schedules, category filters, search, bulk pause and the
// bedtime / study / weekly-report tools.

import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../core/user_journey_logic.dart';
import '../../ui/nigoh_design.dart';
import '../../ui/widgets.dart';
import 'family_controller.dart';
import 'parent_logic.dart';
import 'parent_sheets.dart';
import 'study_sheet.dart';
import 'weekly_report.dart';
import '../../l10n/l10n.dart';

const _weekdayLabels = ['Дш', 'Сш', 'Чш', 'Пш', 'Ҷм', 'Шб', 'Яш'];

/// App rules for the selected child: block, daily limit, study schedule.
class AppsScreen extends StatefulWidget {
  const AppsScreen({super.key, required this.controller});
  final FamilyController controller;

  @override
  State<AppsScreen> createState() => _AppsScreenState();
}

/// Holds search, filter, limit-slider drafts and bulk-pause progress.
class _AppsScreenState extends State<AppsScreen> {
  final _search = TextEditingController();
  String _query = '';

  /// Filter chip: null = all, 'new' = installed in the last 24 h, or a category.
  Object? _filter;

  /// Slider position while dragging (package → limit index).
  final Map<String, int> _draftLimit = {};

  /// Bulk pause progress: done / total, null when idle.
  int? _bulkDone;
  int _bulkTotal = 0;

  FamilyController get controller => widget.controller;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Runs a rule change and shows any error as a snackbar.
  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (mounted) showMessage(context, e, error: true);
    }
  }

  /// Blocks/unblocks every app (quick pause) or only [category].
  Future<void> _bulk(
    FamilyChild child,
    bool block, {
    AppCategory? category,
  }) async {
    final targets = child.apps
        .where(
          (a) =>
              a.blocked != block &&
              (category == null ||
                  (categoryOf(a) == category && !(block && a.alwaysAllowed))),
        )
        .toList();
    if (targets.isEmpty) {
      showMessage(
        context,
        category != null
            ? (block
                  ? tr('Ҳамаи {group} аллакай баста.', {
                      'group': tr(category.pluralLower),
                    })
                  : tr('Ҳамаи {group} кушода.', {
                      'group': tr(category.pluralLower),
                    }))
            : block
            ? tr('Ҳамаи барномаҳо аллакай баста.')
            : tr('Ҳамаи барномаҳо кушода.'),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          category != null
              ? (block
                    ? tr('Ҳамаи {group}ро бастан?', {
                        'group': tr(category.pluralLower),
                      })
                    : tr('Ҳамаи {group}ро кушодан?', {
                        'group': tr(category.pluralLower),
                      }))
              : block
              ? tr('Ҳамаро бастан?')
              : tr('Ҳамаро кушодан?'),
        ),
        content: Text(
          block
              ? tr('{count} барнома дар телефони {name} баста мешавад.', {
                  'count': targets.length,
                  'name': child.name,
                })
              : tr('{count} барнома дар телефони {name} кушода мешавад.', {
                  'count': targets.length,
                  'name': child.name,
                }),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(tr('Бекор')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(110, 44)),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(block ? tr('Бастан') : tr('Кушодан')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      _bulkDone = 0;
      _bulkTotal = targets.length;
    });
    try {
      for (final app in targets) {
        final fresh = controller.childById(child.id) ?? child;
        await controller.setBlocked(fresh, app, block);
        if (!mounted) return;
        setState(() => _bulkDone = (_bulkDone ?? 0) + 1);
      }
      if (mounted) {
        showMessage(
          context,
          block ? tr('Ҳама баста шуд.') : tr('Ҳама кушода шуд.'),
        );
      }
    } catch (e) {
      if (mounted) showMessage(context, e, error: true);
    } finally {
      if (mounted) setState(() => _bulkDone = null);
    }
  }

  /// Opens the schedule sheet for [app] and saves the chosen schedule.
  Future<void> _editSchedule(FamilyChild child, ChildApp app) async {
    final result = await showModalBottomSheet<AppSchedule>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ScheduleSheet(app: app),
    );
    if (result == null || !mounted) return;
    final fresh = controller.childById(child.id) ?? child;
    await _run(() => controller.setSchedule(fresh, app, result));
  }

  /// Opens the per-app options sheet (bonus time, always allowed…).
  void _openOptions(FamilyChild child, ChildApp app) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => AppOptionsSheet(
        controller: controller,
        childId: child.id,
        packageName: app.packageName,
      ),
    );
  }

  /// Grants [minutes] of bonus time in [app] and confirms it.
  Future<void> _bonus(FamilyChild child, ChildApp app, int minutes) async {
    try {
      await controller.giveBonus(
        controller.childById(child.id) ?? child,
        app,
        minutes,
      );
      if (!mounted) return;
      showMessage(
        context,
        tr('{name}: +{minutes} дақ барои имрӯз', {
          'name': app.name,
          'minutes': minutes,
        }),
      );
    } catch (e) {
      if (mounted) showMessage(context, e, error: true);
    }
  }

  /// Opens the weekly screen-time report of [child].
  void _openReport(FamilyChild child) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WeeklyReportScreen(api: controller.api, child: child),
      ),
    );
  }

  /// Opens the bedtime settings sheet.
  void _openBedtime(FamilyChild child) {
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => BedtimeSheet(controller: controller, child: child),
    );
  }

  /// Opens the study-mode settings sheet.
  void _openStudy(FamilyChild child) {
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => StudySheet(controller: controller, child: child),
    );
  }

  /// Whether [app] passes the selected filter chip (new / category).
  bool _matchesFilter(ChildApp app) {
    final filter = _filter;
    if (filter == null) return true;
    if (filter == 'new') return app.isNew;
    return categoryOf(app) == filter;
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final child = controller.selected;
      if (child == null) {
        return StateMessage(
          icon: Icons.family_restroom_rounded,
          title: tr('Фарзанд ҳоло нест'),
        );
      }
      return _buildFor(context, child);
    },
  );

  /// Builds the apps tab for [child]: tools, summary, filters and the app list.
  Widget _buildFor(BuildContext context, FamilyChild child) {
    if (child.apps.isEmpty) {
      return RefreshIndicator(
        onRefresh: controller.refresh,
        child: ListView(
          children: [
            const SizedBox(height: 40),
            StateMessage(
              icon: Icons.apps_rounded,
              title: tr('Рӯйхати барномаҳо ҳоло нест'),
              text: tr(
                'Рӯйхат худкор пайдо мешавад: телефони {name} бояд ба интернет пайваст бошад ва ҳамаи иҷозатҳо дода шуда бошанд. Одатан то як дақиқа.',
                {'name': child.name},
              ),
              actionLabel: tr('Навсозӣ'),
              actionIcon: Icons.refresh_rounded,
              primaryAction: true,
              onAction: () => _refresh(),
            ),
            if (controller.error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  controller.error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      );
    }
    final needle = _query.trim().toLowerCase();
    final apps = child.apps
        .where(
          (a) =>
              (needle.isEmpty ||
                  a.name.toLowerCase().contains(needle) ||
                  a.packageName.toLowerCase().contains(needle)) &&
              _matchesFilter(a),
        )
        .toList();
    final newCount = child.newAppsCount;
    final counts = <AppCategory, int>{};
    for (final a in child.apps) {
      counts.update(categoryOf(a), (v) => v + 1, ifAbsent: () => 1);
    }
    final category = _filter is AppCategory ? _filter as AppCategory : null;
    final limits = child.apps
        .where((a) => a.dailyLimitMinutes > 0)
        .fold<int>(0, (sum, a) => sum + a.dailyLimitMinutes);
    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // What this screen is for, in one line.
          Text(
            tr(
              'Қоидаҳои телефони {name}: барномаро бандед, лимити рӯзона ва вақти дарс гузоред.',
              {'name': child.name},
            ),
            key: const ValueKey('apps-purpose'),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          _ScreenTimeSummary(
            usedMinutes: child.usageMinutesToday,
            limitMinutes: limits,
            blockedCount: child.blockedCount,
            appCount: child.apps.length,
          ),
          SectionTitle(tr('Реҷаҳо ва ҳисобот')),
          _ToolsRow(
            bedtime: child.bedtime,
            onReport: () => _openReport(child),
            onBedtime: () => _openBedtime(child),
            study: _StudyButton(
              study: child.study,
              onTap: () => _openStudy(child),
            ),
          ),
          const SizedBox(height: 12),
          _PauseCard(
            busy: _bulkDone != null,
            done: _bulkDone ?? 0,
            total: _bulkTotal,
            onBlockAll: () => _bulk(child, true),
            onUnblockAll: () => _bulk(child, false),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _search,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: tr('Ҷустуҷӯи барнома'),
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: tr('Ҷустуҷӯро тоза кардан'),
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _search.clear();
                        setState(() => _query = '');
                      },
                    ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _chip(tr('Ҳама ({count})', {'count': child.apps.length}), null),
                if (newCount > 0)
                  _chip(
                    tr('Нав ({newCount})', {'newCount': newCount}),
                    'new',
                    color: NigohDesign.mint,
                  ),
                for (final c in AppCategory.values)
                  if ((counts[c] ?? 0) > 0)
                    _chip('${tr(c.label)} (${counts[c]})', c),
              ],
            ),
          ),
          if (category != null && (counts[category] ?? 0) > 0) ...[
            const SizedBox(height: 10),
            _CategoryActions(
              category: category,
              busy: _bulkDone != null,
              onBlock: () => _bulk(child, true, category: category),
              onUnblock: () => _bulk(child, false, category: category),
            ),
          ],
          SectionTitle(
            tr('Барномаҳо ({count})', {'count': apps.length}),
            trailing: apps.length == child.apps.length
                ? null
                : Text(
                    tr('аз {total}', {'total': child.apps.length}),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
          if (apps.isEmpty)
            StateMessage(
              icon: Icons.search_off_rounded,
              title: tr('Чизе ёфт нашуд'),
              text: tr(
                'Ҷустуҷӯ ё филтрро иваз кунед, то ҳамаи барномаҳо бинед.',
              ),
              actionLabel: tr('Ҳамаи барномаҳоро нишон додан'),
              actionIcon: Icons.filter_alt_off_rounded,
              onAction: () {
                _search.clear();
                setState(() {
                  _query = '';
                  _filter = null;
                });
              },
            ),
          for (final (index, app) in apps.indexed)
            FadeIn(
              key: ValueKey('app-${child.id}-${app.packageName}'),
              index: index,
              child: _appCard(child, app),
            ),
        ],
      ),
    );
  }

  /// Pull-to-refresh: reloads the family and reports a failure.
  Future<void> _refresh() async {
    await controller.refresh();
    if (mounted && controller.error != null) {
      showMessage(context, controller.error!, error: true);
    }
  }

  /// Rule card of one app wired to the controller actions.
  Widget _appCard(FamilyChild child, ChildApp app) {
    final limitIndex =
        _draftLimit[app.packageName] ??
        UserJourneyLogic.nearestLimitIndex(app.dailyLimitMinutes);
    final shownLimit = UserJourneyLogic.limitChoices[limitIndex];
    final schedule = app.schedule;
    return AppRuleCard(
      app: app,
      limitIndex: limitIndex,
      shownLimit: shownLimit,
      scheduleLabel: schedule.enabled
          ? '${schedule.start}–${schedule.end}'
          : null,
      onBlocked: (value) => _run(
        () => controller.setBlocked(
          controller.childById(child.id) ?? child,
          app,
          value,
        ),
      ),
      onLimitChanged: (index) =>
          setState(() => _draftLimit[app.packageName] = index),
      onLimitDone: (index) async {
        final minutes = UserJourneyLogic.limitChoices[index];
        await _run(
          () => controller.setLimit(
            controller.childById(child.id) ?? child,
            app,
            minutes,
          ),
        );
        if (mounted) setState(() => _draftLimit.remove(app.packageName));
      },
      onSchedule: () => _editSchedule(child, app),
      onOptions: () => _openOptions(child, app),
      onBonus: (m) => _bonus(child, app, m),
    );
  }

  /// One filter chip (all / new / a category).
  Widget _chip(String label, Object? value, {Color? color}) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      key: ValueKey('filter-$label'),
      label: Text(label),
      selected: _filter == value,
      showCheckmark: false,
      avatar: color == null
          ? null
          : Icon(Icons.fiber_new_rounded, size: 18, color: color),
      onSelected: (_) => setState(() => _filter = value),
    ),
  );
}

/// Report, bedtime and study-mode tiles: each says what it is and its
/// current value, instead of a bare time range on a button.
class _ToolsRow extends StatelessWidget {
  const _ToolsRow({
    required this.bedtime,
    required this.onReport,
    required this.onBedtime,
    required this.study,
  });

  final Bedtime bedtime;
  final VoidCallback onReport;
  final VoidCallback onBedtime;
  final Widget study;

  @override
  Widget build(BuildContext context) {
    final active = bedtime.activeAt(DateTime.now());
    // IntrinsicHeight: the three tiles share the tallest one's height; inside
    // a scroll view «stretch» alone would be an unbounded constraint.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _ToolTile(
              tileKey: const ValueKey('open-report'),
              icon: Icons.bar_chart_rounded,
              color: NigohDesign.blue,
              label: tr('Ҳисобот'),
              value: tr('7 рӯзи охир'),
              tooltip: tr('Вақти экран дар 7 рӯзи охир'),
              onTap: onReport,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ToolTile(
              tileKey: const ValueKey('open-bedtime'),
              icon: active ? Icons.bedtime_rounded : Icons.bedtime_outlined,
              color: NigohDesign.violet,
              label: tr('Вақти хоб'),
              value: bedtime.enabled
                  ? '${bedtime.start}–${bedtime.end}'
                  : tr('хомӯш'),
              on: bedtime.enabled,
              activeNow: active,
              tooltip: bedtime.enabled
                  ? bedtimeLabel(bedtime)
                  : tr('Вақти хоб гузошта нашудааст'),
              onTap: onBedtime,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: study),
        ],
      ),
    );
  }
}

/// «Тамаркузи дарс» tile next to the bedtime one.
class _StudyButton extends StatelessWidget {
  const _StudyButton({required this.study, required this.onTap});

  final StudyMode study;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = study.activeAt(DateTime.now());
    return _ToolTile(
      tileKey: const ValueKey('open-study'),
      icon: active ? Icons.school_rounded : Icons.school_outlined,
      color: NigohDesign.mint,
      label: tr('Тамаркузи дарс'),
      value: study.enabled ? '${study.start}–${study.end}' : tr('хомӯш'),
      on: study.enabled,
      activeNow: active,
      tooltip: study.enabled
          ? '${studyLabel(study)}${active ? ' · ${tr('Ҳозир фаъол')}' : ''}'
          : tr('Тамаркузи дарс хомӯш аст'),
      onTap: onTap,
    );
  }
}

/// Tile of the tools row showing a label, its current value and state.
class _ToolTile extends StatelessWidget {
  const _ToolTile({
    required this.tileKey,
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.tooltip,
    required this.onTap,
    this.on = true,
    this.activeNow = false,
  });

  final Key tileKey;
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String tooltip;
  final VoidCallback onTap;

  /// The feature is switched on (coloured) rather than off (quiet).
  final bool on;

  /// It is running right now — shown with a dot.
  final bool activeNow;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = on ? color : scheme.onSurfaceVariant;
    return Tooltip(
      message: tooltip,
      child: TapScale(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Duration(milliseconds: reducedMotion(context) ? 0 : 220),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: on ? color.withValues(alpha: .10) : scheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: on ? color.withValues(alpha: .35) : scheme.outlineVariant,
            ),
          ),
          child: Material(
            key: tileKey,
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(icon, size: 18, color: fg),
                        if (activeNow) ...[
                          const Spacer(),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: fg,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// «Бастани ҳамаи бозиҳо» for the selected category.
class _CategoryActions extends StatelessWidget {
  const _CategoryActions({
    required this.category,
    required this.busy,
    required this.onBlock,
    required this.onUnblock,
  });

  final AppCategory category;
  final bool busy;
  final VoidCallback onBlock;
  final VoidCallback onUnblock;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: FilledButton.tonalIcon(
          key: const ValueKey('category-block'),
          onPressed: busy ? null : onBlock,
          icon: const Icon(Icons.lock_rounded, size: 18),
          label: Text(
            tr('Бастани ҳамаи {group}', {'group': tr(category.pluralLower)}),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
      const SizedBox(width: 8),
      OutlinedButton.icon(
        key: const ValueKey('category-unblock'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        onPressed: busy ? null : onUnblock,
        icon: const Icon(Icons.lock_open_rounded, size: 18),
        label: Text(tr('Кушодан')),
      ),
    ],
  );
}

/// Soft summary of today's screen time (ported from the old overview).
class _ScreenTimeSummary extends StatelessWidget {
  const _ScreenTimeSummary({
    required this.usedMinutes,
    required this.limitMinutes,
    required this.blockedCount,
    required this.appCount,
  });

  final int usedMinutes;
  final int limitMinutes;
  final int blockedCount;
  final int appCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final progress = limitMinutes > 0
        ? (usedMinutes / limitMinutes).clamp(0.0, 1.0)
        : 0.0;
    final ringColor = progress >= 1
        ? NigohDesign.coral
        : progress >= .75
        ? NigohDesign.amber
        : NigohDesign.blue;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        gradient: LinearGradient(
          colors: [
            NigohDesign.blue.withValues(alpha: .08),
            NigohDesign.violet.withValues(alpha: .05),
            NigohDesign.mint.withValues(alpha: .06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 84,
            height: 84,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: limitMinutes > 0 ? progress : 0,
                    strokeWidth: 8,
                    strokeCap: StrokeCap.round,
                    backgroundColor: ringColor.withValues(alpha: .14),
                    color: ringColor,
                  ),
                ),
                Icon(Icons.schedule_rounded, color: ringColor, size: 28),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('Вақти экран имрӯз'),
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formatMinutes(usedMinutes),
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  limitMinutes > 0
                      ? tr('Ҳамаи лимитҳо: {time} дар рӯз', {
                          'time': formatMinutes(limitMinutes),
                        })
                      : tr('Лимит гузошта нашудааст'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: ringColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    Pill(
                      tr('{blockedCount} баста', {
                        'blockedCount': blockedCount,
                      }),
                      tooltip: tr('{count} барнома баста аст', {
                        'count': blockedCount,
                      }),
                      color: NigohDesign.coral,
                      icon: Icons.lock_outline_rounded,
                    ),
                    Pill(
                      tr('{appCount} барнома', {'appCount': appCount}),
                      tooltip: tr('Ҳамагӣ {count} барнома дар телефон', {
                        'count': appCount,
                      }),
                      color: NigohDesign.blue,
                      icon: Icons.apps_rounded,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Pause all" card that blocks or unblocks every app, with progress.
class _PauseCard extends StatelessWidget {
  const _PauseCard({
    required this.busy,
    required this.done,
    required this.total,
    required this.onBlockAll,
    required this.onUnblockAll,
  });

  final bool busy;
  final int done;
  final int total;
  final VoidCallback onBlockAll;
  final VoidCallback onUnblockAll;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: NigohDesign.amber.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.pause_circle_outline_rounded,
                    color: NigohDesign.amber,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('Ҳолати танаффус'),
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        tr('Ҳамаи барномаҳоро якбора бандед ё кушоед'),
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: Duration(
                milliseconds: reducedMotion(context) ? 0 : 250,
              ),
              child: busy
                  ? Column(
                      key: const ValueKey('busy'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LinearProgressIndicator(
                          value: total == 0 ? null : done / total,
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          tr('{done} аз {total} барнома', {
                            'done': done,
                            'total': total,
                          }),
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      key: const ValueKey('idle'),
                      children: [
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed: onBlockAll,
                            icon: const Icon(Icons.lock_rounded, size: 18),
                            label: Text(tr('Ҳамаро бастан')),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: onUnblockAll,
                            icon: const Icon(Icons.lock_open_rounded, size: 18),
                            label: Text(tr('Ҳамаро кушодан')),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One app with its block switch, usage bar, limit slider and schedule.
class AppRuleCard extends StatelessWidget {
  const AppRuleCard({
    super.key,
    required this.app,
    required this.limitIndex,
    required this.shownLimit,
    required this.scheduleLabel,
    required this.onBlocked,
    required this.onLimitChanged,
    required this.onLimitDone,
    required this.onSchedule,
    this.onOptions,
    this.onBonus,
  });

  /// Opens «Ҳамеша иҷозат» / bonus sheet.
  final VoidCallback? onOptions;

  /// Adds today's extra minutes (shown when the app has a limit).
  final ValueChanged<int>? onBonus;

  final ChildApp app;
  final int limitIndex;
  final int shownLimit;
  final String? scheduleLabel;
  final ValueChanged<bool> onBlocked;
  final ValueChanged<int> onLimitChanged;
  final ValueChanged<int> onLimitDone;
  final VoidCallback onSchedule;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final blocked = app.blocked;
    final accent = blocked
        ? NigohDesign.coral
        : NigohDesign.accentFor(app.packageName);
    final minutes = app.usageMinutesToday;
    final progress = UserJourneyLogic.usageProgress(
      minutes,
      app.dailyLimitMinutes,
    );
    final barColor = progress >= 1 ? NigohDesign.coral : accent;
    final count = UserJourneyLogic.limitChoices.length;
    final limitText = limitLabelText(shownLimit);
    return AnimatedContainer(
      duration: Duration(milliseconds: reducedMotion(context) ? 0 : 240),
      curve: Curves.easeOut,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: blocked
            ? Color.alphaBlend(
                NigohDesign.coral.withValues(alpha: .05),
                scheme.surface,
              )
            : scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: blocked
              ? NigohDesign.coral.withValues(alpha: .35)
              : scheme.outlineVariant,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              NigohAppIcon(
                icon: app.iconBase64,
                seed: app.packageName,
                size: 44,
                locked: blocked,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            app.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (app.isNew) ...[
                          const SizedBox(width: 6),
                          Pill(tr('Нав'), color: NigohDesign.mint),
                        ],
                      ],
                    ),
                    if (app.alwaysAllowed) ...[
                      const SizedBox(height: 3),
                      Pill(
                        tr('Ҳамеша иҷозат'),
                        color: NigohDesign.mint,
                        icon: Icons.verified_user_rounded,
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      minutes > 0
                          ? tr('Имрӯз {time}', {'time': formatMinutes(minutes)})
                          : tr('Имрӯз истифода нашудааст'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedSwitcher(
                duration: Duration(
                  milliseconds: reducedMotion(context) ? 0 : 200,
                ),
                child: Pill(
                  key: ValueKey(blocked),
                  blocked ? tr('Баста') : tr('Кушода'),
                  color: blocked ? NigohDesign.coral : NigohDesign.mint,
                  icon: blocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                ),
              ),
              Switch(
                key: ValueKey('block-${app.packageName}'),
                value: blocked,
                activeTrackColor: NigohDesign.coral,
                onChanged: onBlocked,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(8),
                    backgroundColor: accent.withValues(alpha: .12),
                    color: barColor,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  app.dailyLimitMinutes > 0
                      ? tr('{minutes} дақ аз {limit}', {
                          'minutes': minutes,
                          'limit': formatMinutes(app.effectiveLimitMinutes),
                        })
                      : tr('{minutes} дақ', {'minutes': minutes}),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: barColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Labelled limit group: the slider alone said nothing.
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Row(
              children: [
                Icon(Icons.timer_outlined, size: 16, color: accent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    tr('Лимити рӯзона'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                AnimatedSwitcher(
                  duration: Duration(
                    milliseconds: reducedMotion(context) ? 0 : 180,
                  ),
                  child: Pill(
                    key: ValueKey(shownLimit),
                    shownLimit <= 0
                        ? tr('Бе лимит')
                        : formatMinutes(shownLimit),
                    tooltip: shownLimit <= 0
                        ? tr('Барнома бе маҳдудияти вақт кор мекунад')
                        : tr('Ҳар рӯз {time} иҷозат дода мешавад', {
                            'time': formatMinutes(shownLimit),
                          }),
                    color: accent,
                    big: true,
                  ),
                ),
              ],
            ),
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: accent,
              inactiveTrackColor: accent.withValues(alpha: .15),
              thumbColor: accent,
              overlayColor: accent.withValues(alpha: .12),
              valueIndicatorColor: accent,
              trackHeight: 4,
            ),
            child: Slider(
              value: limitIndex.toDouble(),
              min: 0,
              max: (count - 1).toDouble(),
              divisions: count - 1,
              label: limitText,
              onChanged: (v) => onLimitChanged(v.round()),
              onChangeEnd: (v) => onLimitDone(v.round()),
            ),
          ),
          // Icon + label, never bare icons: both actions say what they do.
          Padding(
            padding: const EdgeInsets.only(right: 6, bottom: 2),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                TextButton.icon(
                  onPressed: onSchedule,
                  style: TextButton.styleFrom(
                    foregroundColor: scheduleLabel != null
                        ? NigohDesign.violet
                        : scheme.primary,
                    backgroundColor:
                        (scheduleLabel != null
                                ? NigohDesign.violet
                                : scheme.primary)
                            .withValues(alpha: .08),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: Icon(
                    scheduleLabel != null
                        ? Icons.event_available_rounded
                        : Icons.menu_book_rounded,
                    size: 18,
                  ),
                  label: Text(
                    scheduleLabel == null
                        ? tr('Вақти дарс')
                        : tr('Дарс {hours}', {'hours': scheduleLabel}),
                  ),
                ),
                if (onOptions != null)
                  TextButton.icon(
                    key: ValueKey('options-${app.packageName}'),
                    onPressed: onOptions,
                    style: TextButton.styleFrom(
                      foregroundColor: scheme.onSurfaceVariant,
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.tune_rounded, size: 18),
                    label: Text(tr('Танзимоти дигар')),
                  ),
              ],
            ),
          ),
          if (onBonus != null && app.dailyLimitMinutes > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 2, 6, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('Вақти иловагӣ барои имрӯз'),
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  BonusButtons(app: app, onBonus: onBonus!),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Bottom sheet for editing an app's allowed-time schedule.
class _ScheduleSheet extends StatefulWidget {
  const _ScheduleSheet({required this.app});
  final ChildApp app;

  @override
  State<_ScheduleSheet> createState() => _ScheduleSheetState();
}

/// Holds the schedule being edited (on/off, start, end, weekdays).
class _ScheduleSheetState extends State<_ScheduleSheet> {
  late bool enabled;
  late TimeOfDay start;
  late TimeOfDay end;
  late Set<int> weekdays;

  @override
  void initState() {
    super.initState();
    final s = widget.app.schedule;
    // Opening the editor means the parent wants a schedule: start switched on.
    enabled = true;
    start = _parse(s.start, const TimeOfDay(hour: 8, minute: 0));
    end = _parse(s.end, const TimeOfDay(hour: 13, minute: 0));
    weekdays = s.weekdays.toSet();
  }

  /// Parses "HH:mm" into a time, or [fallback] when invalid.
  static TimeOfDay _parse(String value, TimeOfDay fallback) {
    final parts = value.split(':');
    if (parts.length != 2) return fallback;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
      return fallback;
    }
    return TimeOfDay(hour: h, minute: m);
  }

  static String _format(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  /// Opens a 24-hour time picker for the start or end time.
  Future<void> _pick(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? start : end,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() => isStart ? start = picked : end = picked);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Scrolls so the weekday chips and save button stay reachable on small
    // phones and with large system fonts.
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('Вақти дарс'),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              tr('Дар ин вақт {name} худкор баста мешавад.', {
                'name': widget.app.name,
              }),
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(tr('Ҷадвал фаъол')),
              subtitle: Text(
                enabled
                    ? tr('Дар рӯзҳо ва соатҳои зер баста мешавад')
                    : tr('Ҳоло ҷадвал кор намекунад'),
              ),
              value: enabled,
              onChanged: (v) => setState(() => enabled = v),
            ),
            SectionTitle(tr('Соатҳои дарс')),
            Row(
              children: [
                Expanded(
                  child: _TimeTile(
                    label: tr('Аз соати'),
                    value: _format(start),
                    enabled: enabled,
                    onTap: () => _pick(true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _TimeTile(
                    label: tr('То соати'),
                    value: _format(end),
                    enabled: enabled,
                    onTap: () => _pick(false),
                  ),
                ),
              ],
            ),
            SectionTitle(tr('Рӯзҳои ҳафта')),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var day = 1; day <= 7; day++)
                  FilterChip(
                    label: Text(tr(_weekdayLabels[day - 1])),
                    selected: weekdays.contains(day),
                    onSelected: enabled
                        ? (v) => setState(
                            () => v ? weekdays.add(day) : weekdays.remove(day),
                          )
                        : null,
                  ),
              ],
            ),
            if (enabled && weekdays.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  tr('Ақаллан як рӯзро интихоб кунед.'),
                  style: TextStyle(color: scheme.error, fontSize: 12),
                ),
              ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                ),
                onPressed: enabled && weekdays.isEmpty
                    ? null
                    : () => Navigator.pop(
                        context,
                        AppSchedule(
                          enabled: enabled,
                          start: _format(start),
                          end: _format(end),
                          weekdays: weekdays.toList()..sort(),
                        ),
                      ),
                icon: const Icon(Icons.check_rounded),
                label: Text(tr('Нигоҳ доштан')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tappable start/end time field of the schedule sheet.
class _TimeTile extends StatelessWidget {
  const _TimeTile({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final String value;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: .5),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: enabled ? scheme.onSurface : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
