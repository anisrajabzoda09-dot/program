import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/models.dart';
import '../../ui/nigoh_design.dart';
import '../../ui/widgets.dart';
import 'family_controller.dart';
import 'parent_logic.dart';
import '../../l10n/l10n.dart';

/// «Ҳисобот»: 7-day screen time, today vs average, top apps of a day.
class WeeklyReportScreen extends StatefulWidget {
  const WeeklyReportScreen({super.key, required this.api, required this.child});
  final NigohApi api;
  final FamilyChild child;

  @override
  State<WeeklyReportScreen> createState() => _WeeklyReportScreenState();
}

class _WeeklyReportScreenState extends State<WeeklyReportScreen> {
  List<UsageDay>? _days;
  String? _error;
  int? _selected;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final raw = await widget.api.usageHistory(widget.child.id, days: 7);
      if (!mounted) return;
      final days = UsageDay.listFromJson(raw);
      setState(() {
        _days = days;
        _selected = days.isEmpty ? null : days.length - 1;
      });
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _error = e is ApiException
            ? e.message
            : tr('Ҳисобот гирифта нашуд: {e}', {'e': e}),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final days = _days;
    Widget body;
    if (days == null && _error == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (days == null) {
      body = StateMessage(
        icon: Icons.cloud_off_rounded,
        title: tr('Ҳисобот гирифта нашуд'),
        text: _error,
        actionLabel: tr('Аз нав кӯшиш'),
        onAction: _load,
        error: true,
      );
    } else if (days.isEmpty) {
      body = StateMessage(
        icon: Icons.bar_chart_rounded,
        title: tr('Ҳоло маълумот нест'),
        text: tr('Ҳисобот пас аз истифодаи телефони фарзанд пайдо мешавад.'),
        actionLabel: tr('Навсозӣ'),
        actionIcon: Icons.refresh_rounded,
        onAction: _load,
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            WeeklyReportView(
              days: days,
              selected: _selected ?? days.length - 1,
              onSelect: (i) => setState(() => _selected = i),
              icons: {
                for (final a in widget.child.apps) a.packageName: a.iconBase64,
              },
            ),
          ],
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Ҳисобот · {name}', {'name': widget.child.name})),
      ),
      body: AnimatedSwitcher(
        duration: Duration(milliseconds: reducedMotion(context) ? 0 : 220),
        child: body,
      ),
    );
  }
}

/// Summary + bar chart + top apps of the selected day.
class WeeklyReportView extends StatelessWidget {
  const WeeklyReportView({
    super.key,
    required this.days,
    required this.selected,
    required this.onSelect,
    this.icons = const {},
  });

  final List<UsageDay> days;
  final int selected;
  final ValueChanged<int> onSelect;

  /// package → icon (base64) of the child's apps.
  final Map<String, String> icons;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final today = days.last.minutes;
    final average = (days.fold<int>(0, (s, d) => s + d.minutes) / days.length)
        .round();
    final diff = today - average;
    final day = days[selected.clamp(0, days.length - 1)];
    final total = days.fold<int>(0, (s, d) => s + d.minutes);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr(
            'Вақти экрани 7 рӯзи охир. Рӯзро пахш кунед, то барномаҳои он рӯзро бинед.',
          ),
          key: const ValueKey('report-purpose'),
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _SummaryTile(
                label: tr('Имрӯз'),
                value: formatMinutes(today),
                color: NigohDesign.blue,
                icon: Icons.today_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SummaryTile(
                label: tr('Миёна дар рӯз'),
                value: formatMinutes(average),
                color: NigohDesign.violet,
                icon: Icons.timeline_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          average == 0 && today == 0
              ? tr('Дар ин ҳафта вақти экран қайд нашудааст.')
              : diff > 0
              ? tr('Имрӯз {time} зиёдтар аз миёна', {
                  'time': formatMinutes(diff),
                })
              : diff < 0
              ? tr('Имрӯз {time} камтар аз миёна', {
                  'time': formatMinutes(-diff),
                })
              : tr('Имрӯз баробари миёна'),
          style: TextStyle(
            color: diff > 0 ? NigohDesign.coral : NigohDesign.mint,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 10),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('7 рӯзи охир · ҳамагӣ {time}', {
                  'time': formatMinutes(total),
                }),
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
              ),
              const SizedBox(height: 12),
              WeeklyBarChart(
                days: days,
                selected: selected,
                onSelect: onSelect,
              ),
            ],
          ),
        ),
        SectionTitle(
          tr('Барномаҳои асосӣ · {day}', {
            'day': _dayLabel(day.date, days.last.date),
          }),
        ),
        if (day.top.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Icon(
                  Icons.event_busy_rounded,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tr(
                      'Дар ин рӯз истифода қайд нашудааст. Рӯзи дигарро интихоб кунед.',
                    ),
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        for (final (index, app) in day.top.take(5).indexed)
          FadeIn(
            key: ValueKey('top-${day.date}-${app.packageName}'),
            index: index,
            child: _TopAppRow(
              app: app,
              max: day.top.first.minutes,
              icon: icons[app.packageName] ?? '',
            ),
          ),
      ],
    );
  }

  static String _dayLabel(DateTime date, DateTime last) {
    if (date == last) return tr('имрӯз');
    return '${tr(weekdayShort[date.weekday - 1])}, ${two(date.day)}.${two(date.month)}';
  }
}

/// Plain-widget bar chart; tap a bar to select the day.
class WeeklyBarChart extends StatelessWidget {
  const WeeklyBarChart({
    super.key,
    required this.days,
    required this.selected,
    required this.onSelect,
    this.height = 150,
  });

  final List<UsageDay> days;
  final int selected;
  final ValueChanged<int> onSelect;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final max = days.fold<int>(1, (m, d) => d.minutes > m ? d.minutes : m);
    return SizedBox(
      height: height + 40,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final (i, day) in days.indexed)
            Expanded(
              child: Tooltip(
                message: tr('{day}: {time}', {
                  'day': tr(weekdayShort[day.date.weekday - 1]),
                  'time': formatMinutes(day.minutes),
                }),
                child: GestureDetector(
                  key: ValueKey('report-bar-$i'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onSelect(i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        day.minutes == 0 ? '' : _short(day.minutes),
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 10,
                          color: i == selected
                              ? NigohDesign.blue
                              : scheme.onSurfaceVariant,
                          fontWeight: i == selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      AnimatedContainer(
                        duration: Duration(
                          milliseconds: reducedMotion(context) ? 0 : 260,
                        ),
                        curve: Curves.easeOutCubic,
                        width: 22,
                        height: 4 + (height - 24) * (day.minutes / max),
                        decoration: BoxDecoration(
                          color: i == selected
                              ? NigohDesign.blue
                              : NigohDesign.blue.withValues(alpha: .22),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        tr(weekdayShort[day.date.weekday - 1]),
                        style: TextStyle(
                          fontSize: 11,
                          color: i == selected
                              ? scheme.onSurface
                              : scheme.onSurfaceVariant,
                          fontWeight: i == selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _short(int minutes) {
    if (minutes < 60) return tr('{minutes}д', {'minutes': minutes});
    final h = minutes / 60;
    return tr('{hours}с', {
      'hours': h >= 10 ? h.round() : h.toStringAsFixed(1),
    });
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopAppRow extends StatelessWidget {
  const _TopAppRow({required this.app, required this.max, this.icon = ''});
  final UsageTopApp app;
  final int max;
  final String icon;

  @override
  Widget build(BuildContext context) {
    final accent = NigohDesign.accentFor(app.packageName);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          NigohAppIcon(icon: icon, seed: app.packageName, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        app.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      formatMinutes(app.minutes),
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                LinearProgressIndicator(
                  value: max <= 0 ? 0 : app.minutes / max,
                  minHeight: 5,
                  borderRadius: BorderRadius.circular(6),
                  backgroundColor: accent.withValues(alpha: .12),
                  color: accent,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
