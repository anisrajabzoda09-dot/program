import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/app_categories.dart';
import '../../core/models.dart';
import '../../ui/nigoh_design.dart';
import '../../ui/widgets.dart';
import 'child_sync.dart';
import 'child_widgets.dart' show StudyNotice;

const _weekdayShort = {
  1: 'Дш',
  2: 'Сш',
  3: 'Чш',
  4: 'Пш',
  5: 'Ҷм',
  6: 'Шб',
  7: 'Яш',
};

/// «Дш, Сш, Чш» — or «Ҳар рӯз» for all seven days.
String weekdaysLabel(List<int> days) {
  final sorted = days.toSet().where(_weekdayShort.containsKey).toList()..sort();
  if (sorted.length == 7) return 'Ҳар рӯз';
  if (sorted.isEmpty) return 'Ягон рӯз';
  return sorted.map((d) => _weekdayShort[d]).join(', ');
}

/// Apps closed by «Тамаркузи дарс»: games, social and video — never
/// essentials (phone, SMS), «always allowed» or apps the parent already
/// blocked (those are listed separately).
List<ChildApp> studyClosedApps(List<ChildApp> apps) => [
  for (final a in apps)
    if (!a.alwaysAllowed &&
        !a.blocked &&
        !isEssentialApp(a.packageName) &&
        studyBlockedCategories.contains(categoryOf(a)))
      a,
];

/// «45/60 дақ» plus «, +15 бонус» when the parent gave bonus time today.
String limitUsageLabel(ChildApp app) {
  final base = '${app.usageMinutesToday}/${app.effectiveLimitMinutes} дақ';
  return app.bonusMinutesToday > 0
      ? '$base, +${app.bonusMinutesToday} бонус'
      : base;
}

/// «1 соат 5 дақ», «40 дақ».
String minutesLabel(int minutes) {
  if (minutes < 60) return '$minutes дақ';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '$h соат' : '$h соат $m дақ';
}

/// «Қоидаҳои ман»: what the parent set on this phone, plus extra-time
/// requests.
class ChildRulesScreen extends StatefulWidget {
  const ChildRulesScreen({super.key, required this.sync});
  final ChildSync sync;

  @override
  State<ChildRulesScreen> createState() => _ChildRulesScreenState();
}

class _ChildRulesScreenState extends State<ChildRulesScreen> {
  List<TimeRequest>? _requests;
  String? _requestsError;
  bool _loadingRequests = false;
  int? _lastPendingCount;

  ChildSync get sync => widget.sync;

  @override
  void initState() {
    super.initState();
    sync.addListener(_onSync);
    _lastPendingCount = sync.child?.pendingRequests;
    _loadRequests();
  }

  @override
  void dispose() {
    sync.removeListener(_onSync);
    super.dispose();
  }

  void _onSync() {
    if (!mounted) return;
    // A parent decision changes the pending count — refresh the list then.
    final pending = sync.child?.pendingRequests;
    if (pending != _lastPendingCount) {
      _lastPendingCount = pending;
      _loadRequests();
    }
    setState(() {});
  }

  Future<void> _loadRequests() async {
    final id = sync.childId;
    if (id == null || _loadingRequests) return;
    _loadingRequests = true;
    try {
      final raw = await sync.api.timeRequests(id);
      if (!mounted) return;
      setState(() {
        _requests = raw.map(TimeRequest.fromJson).toList()
          ..sort((a, b) => b.id.compareTo(a.id));
        _requestsError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _requestsError = e is ApiException ? e.message : '$e');
    } finally {
      _loadingRequests = false;
    }
  }

  Future<void> _refresh() async {
    await sync.forceSync();
    await _loadRequests();
  }

  Future<void> _askTime(ChildApp app) async {
    final id = sync.childId;
    if (id == null) return;
    final result = await showModalBottomSheet<_TimeAsk>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _TimeRequestSheet(app: app),
    );
    if (result == null || !mounted) return;
    try {
      await sync.api.requestTime(
        id,
        app.packageName,
        minutes: result.minutes,
        reason: result.reason,
      );
      if (!mounted) return;
      showMessage(context, 'Дархост фиристода шуд');
      await _loadRequests();
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 409) {
        showMessage(
          context,
          'Барои «${app.name}» аллакай дархост ҳаст — ҷавоби волидайнро интизор шавед.',
          error: true,
        );
        await _loadRequests();
      } else {
        showMessage(context, e, error: true);
      }
    } catch (e) {
      if (mounted) showMessage(context, e, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final child = sync.child;
    final scheme = Theme.of(context).colorScheme;
    final apps = child?.apps ?? const <ChildApp>[];
    final blocked = apps.where((a) => a.blocked && !a.alwaysAllowed).toList();
    final limited = apps
        .where((a) => !a.blocked && !a.alwaysAllowed && a.dailyLimitMinutes > 0)
        .toList();
    final scheduled = apps
        .where((a) => !a.alwaysAllowed && a.schedule.enabled)
        .toList();
    final allowed = apps.where((a) => a.alwaysAllowed).toList();
    final bedtime = child?.bedtime ?? const Bedtime();
    final bedtimeActive = bedtime.activeAt(sync.now());
    final study = child?.study ?? const StudyMode();
    final studyActive = study.activeAt(sync.now());
    final studyApps = study.enabled
        ? studyClosedApps(apps)
        : const <ChildApp>[];
    final empty =
        blocked.isEmpty &&
        limited.isEmpty &&
        scheduled.isEmpty &&
        allowed.isEmpty &&
        !bedtime.enabled &&
        !study.enabled;

    var index = 0;
    final children = <Widget>[
      const Text(
        'Қоидаҳои ман',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 4),
      Text(
        'Инҳоро волидайн барои ин телефон муқаррар кардаанд.',
        style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4),
      ),
      const SizedBox(height: 8),
      if (studyActive) ...[
        const SizedBox(height: 4),
        StudyNotice(study: study),
        const SizedBox(height: 4),
      ],
      if (child == null)
        Padding(
          padding: const EdgeInsets.only(top: 40),
          child: sync.lastError != null
              ? StateMessage(
                  icon: Icons.cloud_off_rounded,
                  title: 'Қоидаҳо бор нашуданд',
                  text: sync.lastError,
                  actionLabel: 'Аз нав кӯшиш',
                  onAction: _refresh,
                  error: true,
                )
              : const Center(child: CircularProgressIndicator()),
        )
      else if (empty)
        const Padding(
          padding: EdgeInsets.only(top: 24),
          child: StateMessage(
            icon: Icons.verified_user_outlined,
            title: 'Ҳоло қоида нест',
            text: 'Ҳамаи барномаҳо бе маҳдудият кушода ҳастанд.',
          ),
        )
      else ...[
        if (bedtime.enabled) ...[
          const SectionTitle('Вақти хоб'),
          FadeIn(
            index: index++,
            child: _RuleCard(
              leading: _IconTile(
                icon: Icons.bedtime_rounded,
                color: NigohDesign.violet,
              ),
              title: '${bedtime.start} – ${bedtime.end}',
              subtitle:
                  'Ҳамаи барномаҳо, ғайр аз иҷозатдодашудаҳо, баста мешаванд.',
              trailing: bedtimeActive
                  ? const Pill('Ҳозир фаъол', color: NigohDesign.violet)
                  : null,
            ),
          ),
        ],
        if (study.enabled) ...[
          const SectionTitle('Тамаркузи дарс'),
          FadeIn(
            index: index++,
            child: _RuleCard(
              leading: _IconTile(
                icon: Icons.school_rounded,
                color: NigohDesign.mint,
              ),
              title:
                  '${study.start} – ${study.end} · ${weekdaysLabel(study.weekdays)}',
              subtitle:
                  'Бозиҳо, шабакаҳо ва видео баста мешаванд. Занг, SMS ва '
                  'барномаҳои таълимӣ кушода мемонанд.',
              trailing: studyActive
                  ? const Pill('Ҳозир фаъол', color: NigohDesign.mint)
                  : null,
            ),
          ),
          if (studyApps.isNotEmpty) ...[
            SectionTitle('Дар соатҳои дарс баста (${studyApps.length})'),
            for (final app in studyApps)
              FadeIn(
                index: index++,
                child: _AppRule(
                  key: ValueKey('study-app-${app.packageName}'),
                  app: app,
                  locked: studyActive,
                  subtitle: categoryOf(app).label,
                  pill: studyActive
                      ? const Pill('Дарс', color: NigohDesign.mint)
                      : null,
                ),
              ),
          ],
        ],
        if (blocked.isNotEmpty) ...[
          SectionTitle('Баста (${blocked.length})'),
          for (final app in blocked)
            FadeIn(
              index: index++,
              child: _AppRule(
                app: app,
                locked: true,
                subtitle: 'Волидайн ин барномаро бастаанд',
                pill: const Pill('Баста', color: NigohDesign.coral),
                onAsk: () => _askTime(app),
              ),
            ),
        ],
        if (limited.isNotEmpty) ...[
          SectionTitle('Маҳдудияти рӯзона (${limited.length})'),
          for (final app in limited)
            FadeIn(
              index: index++,
              child: _AppRule(
                app: app,
                subtitle: limitUsageLabel(app),
                progress:
                    app.usageMinutesToday /
                    (app.effectiveLimitMinutes == 0
                        ? 1
                        : app.effectiveLimitMinutes),
                pill: app.usageMinutesToday >= app.effectiveLimitMinutes
                    ? const Pill('Вақт тамом', color: NigohDesign.coral)
                    : null,
                onAsk: () => _askTime(app),
              ),
            ),
        ],
        if (scheduled.isNotEmpty) ...[
          SectionTitle('Вақти дарс (${scheduled.length})'),
          for (final app in scheduled)
            FadeIn(
              index: index++,
              child: _AppRule(
                app: app,
                subtitle:
                    '${app.schedule.start} – ${app.schedule.end} · ${weekdaysLabel(app.schedule.weekdays)}',
                pill: const Pill('Ҷадвал', color: NigohDesign.amber),
              ),
            ),
        ],
        if (allowed.isNotEmpty) ...[
          SectionTitle('Ҳамеша иҷозат (${allowed.length})'),
          for (final app in allowed)
            FadeIn(
              index: index++,
              child: _AppRule(
                app: app,
                subtitle: 'Ҳатто дар вақти хоб кушода аст',
                pill: const Pill('Иҷозат', color: NigohDesign.mint),
              ),
            ),
        ],
      ],
      if (child != null) ...[
        const SectionTitle('Дархостҳои ман'),
        _RequestsList(
          requests: _requests,
          error: _requestsError,
          onRetry: _loadRequests,
        ),
      ],
    ];

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: children,
        ),
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({required this.icon, required this.color});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 44,
    height: 44,
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Icon(icon, color: color),
  );
}

class _RuleCard extends StatelessWidget {
  const _RuleCard({
    required this.leading,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.bottom,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  leading,
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 13,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 8),
                    trailing!,
                  ],
                ],
              ),
              ?bottom,
            ],
          ),
        ),
      ),
    );
  }
}

class _AppRule extends StatelessWidget {
  const _AppRule({
    super.key,
    required this.app,
    required this.subtitle,
    this.locked = false,
    this.pill,
    this.progress,
    this.onAsk,
  });

  final ChildApp app;
  final String subtitle;
  final bool locked;
  final Widget? pill;
  final double? progress;
  final VoidCallback? onAsk;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final value = progress?.clamp(0.0, 1.0);
    return _RuleCard(
      leading: NigohAppIcon(
        icon: app.iconBase64,
        seed: app.packageName,
        locked: locked,
      ),
      title: app.name,
      subtitle: subtitle,
      trailing: pill,
      bottom: value == null && onAsk == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (value != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: value,
                        minHeight: 6,
                        color: value >= 1 ? NigohDesign.coral : scheme.primary,
                        backgroundColor: scheme.surfaceContainerHighest,
                      ),
                    ),
                  if (onAsk != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: onAsk,
                        icon: const Icon(Icons.more_time_rounded, size: 18),
                        label: const Text('Вақти иловагӣ пурсидан'),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _TimeAsk {
  const _TimeAsk(this.minutes, this.reason);
  final int minutes;
  final String? reason;
}

class _TimeRequestSheet extends StatefulWidget {
  const _TimeRequestSheet({required this.app});
  final ChildApp app;

  @override
  State<_TimeRequestSheet> createState() => _TimeRequestSheetState();
}

class _TimeRequestSheetState extends State<_TimeRequestSheet> {
  int _minutes = 15;
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              NigohAppIcon(
                icon: widget.app.iconBase64,
                seed: widget.app.packageName,
                size: 40,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Вақти иловагӣ барои «${widget.app.name}»',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Чанд дақиқа лозим аст?',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final m in const [15, 30, 60])
                ChoiceChip(
                  label: Text('$m дақ'),
                  selected: _minutes == m,
                  onSelected: (_) => setState(() => _minutes = m),
                ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _reason,
            maxLength: 200,
            maxLines: 2,
            minLines: 1,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Сабаб (ихтиёрӣ)',
              counterText: '',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () {
              final reason = _reason.text.trim();
              Navigator.of(context)
                  .pop(_TimeAsk(_minutes, reason.isEmpty ? null : reason));
            },
            icon: const Icon(Icons.send_rounded),
            label: const Text('Фиристодан'),
          ),
        ],
      ),
    );
  }
}

class _RequestsList extends StatelessWidget {
  const _RequestsList({
    required this.requests,
    required this.error,
    required this.onRetry,
  });

  final List<TimeRequest>? requests;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final list = requests;
    if (list == null) {
      if (error != null) {
        return _InlineError(text: error!, onRetry: onRetry);
      }
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (error != null) _InlineError(text: error!, onRetry: onRetry),
        if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Text(
              'Ҳоло дархост нафиристодаед.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
        for (final (i, r) in list.indexed)
          FadeIn(
            index: i,
            child: _RuleCard(
              leading: const _IconTile(
                icon: Icons.more_time_rounded,
                color: NigohDesign.blue,
              ),
              title: r.appName,
              subtitle: [
                '+${r.minutes} дақ',
                if (r.createdAt != null) timeAgo(r.createdAt),
                if (r.reason != null && r.reason!.trim().isNotEmpty)
                  r.reason!.trim(),
              ].join(' · '),
              trailing: requestStatusPill(r.status),
            ),
          ),
      ],
    );
  }
}

/// Pill for a request status: интизор / иҷозат дода шуд / рад шуд.
Widget requestStatusPill(String status) => switch (status) {
  'approved' => const Pill('иҷозат дода шуд', color: NigohDesign.mint),
  'denied' => const Pill('рад шуд', color: NigohDesign.coral),
  _ => const Pill('интизор', color: NigohDesign.amber),
};

class _InlineError extends StatelessWidget {
  const _InlineError({required this.text, required this.onRetry});
  final String text;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      decoration: BoxDecoration(
        color: scheme.error.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, size: 18, color: scheme.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(color: scheme.error)),
          ),
          TextButton(onPressed: onRetry, child: const Text('Аз нав')),
        ],
      ),
    );
  }
}
