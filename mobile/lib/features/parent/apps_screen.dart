import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../core/user_journey_logic.dart';
import '../../ui/nigoh_design.dart';
import '../../ui/widgets.dart';
import 'family_controller.dart';
import 'parent_logic.dart';
import 'parent_sheets.dart';
import 'weekly_report.dart';

const _weekdayLabels = ['Дш', 'Сш', 'Чш', 'Пш', 'Ҷм', 'Шб', 'Яш'];

/// App rules for the selected child: block, daily limit, study schedule.
class AppsScreen extends StatefulWidget {
  const AppsScreen({super.key, required this.controller});
  final FamilyController controller;

  @override
  State<AppsScreen> createState() => _AppsScreenState();
}

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
                  ? 'Ҳамаи ${category.pluralLower} аллакай баста.'
                  : 'Ҳамаи ${category.pluralLower} кушода.')
            : block
            ? 'Ҳамаи барномаҳо аллакай баста.'
            : 'Ҳамаи барномаҳо кушода.',
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          category != null
              ? (block
                    ? 'Ҳамаи ${category.pluralLower}ро бастан?'
                    : 'Ҳамаи ${category.pluralLower}ро кушодан?')
              : block
              ? 'Ҳамаро бастан?'
              : 'Ҳамаро кушодан?',
        ),
        content: Text(
          block
              ? '${targets.length} барнома дар телефони ${child.name} баста мешавад.'
              : '${targets.length} барнома дар телефони ${child.name} кушода мешавад.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Бекор'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(block ? 'Бастан' : 'Кушодан'),
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
        showMessage(context, block ? 'Ҳама баста шуд.' : 'Ҳама кушода шуд.');
      }
    } catch (e) {
      if (mounted) showMessage(context, e, error: true);
    } finally {
      if (mounted) setState(() => _bulkDone = null);
    }
  }

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

  Future<void> _bonus(FamilyChild child, ChildApp app, int minutes) async {
    try {
      await controller.giveBonus(
        controller.childById(child.id) ?? child,
        app,
        minutes,
      );
      if (!mounted) return;
      showMessage(context, '${app.name}: +$minutes дақ барои имрӯз');
    } catch (e) {
      if (mounted) showMessage(context, e, error: true);
    }
  }

  void _openReport(FamilyChild child) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WeeklyReportScreen(api: controller.api, child: child),
      ),
    );
  }

  void _openBedtime(FamilyChild child) {
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => BedtimeSheet(controller: controller, child: child),
    );
  }

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
        return const StateMessage(
          icon: Icons.family_restroom_rounded,
          title: 'Фарзанд ҳоло нест',
        );
      }
      return _buildFor(context, child);
    },
  );

  Widget _buildFor(BuildContext context, FamilyChild child) {
    if (child.apps.isEmpty) {
      return RefreshIndicator(
        onRefresh: controller.refresh,
        child: ListView(
          children: [
            const SizedBox(height: 40),
            StateMessage(
              icon: Icons.apps_rounded,
              title: 'Рӯйхати барномаҳо ҳоло нест',
              text:
                  'Рӯйхат худкор пайдо мешавад: телефони ${child.name} бояд ба интернет '
                  'пайваст бошад ва ҳамаи иҷозатҳо дода шуда бошанд. Одатан то як дақиқа.',
              actionLabel: 'Навсозӣ',
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
          _ScreenTimeSummary(
            usedMinutes: child.usageMinutesToday,
            limitMinutes: limits,
            blockedCount: child.blockedCount,
            appCount: child.apps.length,
          ),
          const SizedBox(height: 10),
          _ToolsRow(
            bedtime: child.bedtime,
            onReport: () => _openReport(child),
            onBedtime: () => _openBedtime(child),
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
              hintText: 'Ҷустуҷӯи барнома',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
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
                _chip('Ҳама', null),
                if (newCount > 0)
                  _chip('Нав ($newCount)', 'new', color: NigohDesign.mint),
                for (final c in AppCategory.values)
                  if ((counts[c] ?? 0) > 0)
                    _chip('${c.label} (${counts[c]})', c),
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
          SectionTitle('Барномаҳо (${apps.length})'),
          if (apps.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('Чизе ёфт нашуд')),
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

  Future<void> _refresh() async {
    await controller.refresh();
    if (mounted && controller.error != null) {
      showMessage(context, controller.error!, error: true);
    }
  }

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

/// «Ҳисобот» and «Вақти хоб» shortcuts above the rules.
class _ToolsRow extends StatelessWidget {
  const _ToolsRow({
    required this.bedtime,
    required this.onReport,
    required this.onBedtime,
  });

  final Bedtime bedtime;
  final VoidCallback onReport;
  final VoidCallback onBedtime;

  @override
  Widget build(BuildContext context) {
    final active = bedtime.activeAt(DateTime.now());
    return Row(
      children: [
        Expanded(
          child: FilledButton.tonalIcon(
            key: const ValueKey('open-report'),
            onPressed: onReport,
            icon: const Icon(Icons.bar_chart_rounded, size: 18),
            label: const Text('Ҳисобот'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton.tonalIcon(
            key: const ValueKey('open-bedtime'),
            style: FilledButton.styleFrom(
              backgroundColor: bedtime.enabled
                  ? NigohDesign.violet.withValues(alpha: .14)
                  : null,
              foregroundColor: bedtime.enabled ? NigohDesign.violet : null,
            ),
            onPressed: onBedtime,
            icon: Icon(
              active ? Icons.bedtime_rounded : Icons.bedtime_outlined,
              size: 18,
            ),
            label: Text(
              bedtime.enabled ? '${bedtime.start}–${bedtime.end}' : 'Вақти хоб',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
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
            'Бастани ҳамаи ${category.pluralLower}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
      const SizedBox(width: 8),
      IconButton.outlined(
        tooltip: 'Ҳамаро кушодан',
        onPressed: busy ? null : onUnblock,
        icon: const Icon(Icons.lock_open_rounded, size: 18),
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
                  'Вақти экран имрӯз',
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
                      ? 'Лимитҳо: ${formatMinutes(limitMinutes)}'
                      : 'Лимит гузошта нашудааст',
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
                      '$blockedCount баста',
                      color: NigohDesign.coral,
                      icon: Icons.lock_outline_rounded,
                    ),
                    Pill(
                      '$appCount барнома',
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
                      const Text(
                        'Ҳолати танаффус',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'Ҳамаи барномаҳоро якбора бандед ё кушоед',
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
              duration: const Duration(milliseconds: 250),
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
                          '$done / $total',
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
                            label: const Text('Ҳамаро бастан'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: onUnblockAll,
                            icon: const Icon(Icons.lock_open_rounded, size: 18),
                            label: const Text('Ҳамаро кушодан'),
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
    final limitText = UserJourneyLogic.limitLabel(shownLimit);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: scheme.surface,
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
                          const Pill('Нав', color: NigohDesign.mint),
                        ],
                      ],
                    ),
                    if (app.alwaysAllowed) ...[
                      const SizedBox(height: 3),
                      const Pill(
                        'Ҳамеша иҷозат',
                        color: NigohDesign.mint,
                        icon: Icons.verified_user_rounded,
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      minutes > 0
                          ? 'Имрӯз ${formatMinutes(minutes)}'
                          : 'Имрӯз истифода нашудааст',
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
              Pill(
                blocked ? 'Баста' : 'Фаъол',
                color: blocked ? NigohDesign.coral : NigohDesign.mint,
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
                      ? '$minutesд / ${UserJourneyLogic.limitLabel(app.effectiveLimitMinutes)}'
                      : '$minutesд',
                  style: TextStyle(
                    color: barColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
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
          Row(
            children: [
              const SizedBox(width: 4),
              Icon(Icons.timer_outlined, size: 16, color: accent),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Лимит: $limitText',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
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
                label: Text(scheduleLabel ?? 'Вақти дарс'),
              ),
              if (onOptions != null)
                IconButton(
                  key: ValueKey('options-${app.packageName}'),
                  tooltip: 'Бештар',
                  visualDensity: VisualDensity.compact,
                  onPressed: onOptions,
                  icon: const Icon(Icons.tune_rounded, size: 20),
                ),
            ],
          ),
          if (onBonus != null && app.dailyLimitMinutes > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 6, 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Вақти иловагӣ',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: BonusButtons(app: app, onBonus: onBonus!),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ScheduleSheet extends StatefulWidget {
  const _ScheduleSheet({required this.app});
  final ChildApp app;

  @override
  State<_ScheduleSheet> createState() => _ScheduleSheetState();
}

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
    return SafeArea(
      child: Padding(
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
            const Text(
              'Вақти дарс',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Дар ин вақт ${widget.app.name} худкор баста мешавад.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Ҷадвал фаъол'),
              value: enabled,
              onChanged: (v) => setState(() => enabled = v),
            ),
            Row(
              children: [
                Expanded(
                  child: _TimeTile(
                    label: 'Аз',
                    value: _format(start),
                    enabled: enabled,
                    onTap: () => _pick(true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _TimeTile(
                    label: 'То',
                    value: _format(end),
                    enabled: enabled,
                    onTap: () => _pick(false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var day = 1; day <= 7; day++)
                  FilterChip(
                    label: Text(_weekdayLabels[day - 1]),
                    selected: weekdays.contains(day),
                    onSelected: enabled
                        ? (v) => setState(
                            () => v ? weekdays.add(day) : weekdays.remove(day),
                          )
                        : null,
                  ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
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
                child: const Text('Нигоҳ доштан'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
