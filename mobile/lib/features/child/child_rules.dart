// Файл: татбиқи маҳдудиятҳои барнома, хоб ва дарс.

import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/app_categories.dart';
import '../../core/models.dart';
import '../../ui/nigoh_design.dart';
import '../../ui/widgets.dart';
import 'child_sync.dart';
import 'child_widgets.dart'
    show
        BedtimeNotice,
        ChildIconTile,
        ChildProgressBar,
        StudyNotice,
        childReducedMotion;
import '../../l10n/l10n.dart';

const _weekdayShort = <int, String>{
  1: 'Дш',
  2: 'Сш',
  3: 'Чш',
  4: 'Пш',
  5: 'Ҷм',
  6: 'Шб',
  7: 'Яш',
};

/// weekdaysLabel мантиқи зарурии татбиқи маҳдудиятҳои барнома, хоб ва дарсро иҷро мекунад.
String weekdaysLabel(List<int> days) {
  final sorted = days.toSet().where(_weekdayShort.containsKey).toList()..sort();
  if (sorted.length == 7) return tr('Ҳар рӯз');
  if (sorted.isEmpty) return tr('Ягон рӯз');
  return sorted.map((d) => tr(_weekdayShort[d]!)).join(', ');
}

/// studyClosedApps мантиқи зарурии татбиқи маҳдудиятҳои барнома, хоб ва дарсро иҷро мекунад.
List<ChildApp> studyClosedApps(List<ChildApp> apps) => [
  for (final a in apps)
    if (!a.alwaysAllowed &&
        !a.blocked &&
        !isEssentialApp(a.packageName) &&
        studyBlockedCategories.contains(categoryOf(a)))
      a,
];

/// limitUsageLabel мантиқи зарурии татбиқи маҳдудиятҳои барнома, хоб ва дарсро иҷро мекунад.
String limitUsageLabel(ChildApp app) {
  final base = tr('{used} дақ аз {limit}', {
    'used': app.usageMinutesToday,
    'limit': app.effectiveLimitMinutes,
  });
  return app.bonusMinutesToday > 0
      ? tr('{base}, +{bonus} бонус', {
          'base': base,
          'bonus': app.bonusMinutesToday,
        })
      : base;
}

/// minutesLabel мантиқи зарурии татбиқи маҳдудиятҳои барнома, хоб ва дарсро иҷро мекунад.
String minutesLabel(int minutes) {
  if (minutes < 60) return tr('{m} дақ', {'m': minutes});
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0
      ? tr('{h} соат', {'h': h})
      : tr('{h} соат {m} дақ', {'h': h, 'm': m});
}

/// Экрани ChildRulesScreen-ро барои татбиқи маҳдудиятҳои барнома, хоб ва дарс месозад.
class ChildRulesScreen extends StatefulWidget {
  const ChildRulesScreen({super.key, required this.sync});
  final ChildSync sync;

  /// Ҳолати ChildRulesScreen-ро барои қоидаҳо ва дархостҳои вақти фарзанд месозад.
  @override
  State<ChildRulesScreen> createState() => _ChildRulesScreenState();
}

/// Ҳолат ва рафтори ChildRulesScreenState-ро барои навсозии интерфейс идора мекунад.
class _ChildRulesScreenState extends State<ChildRulesScreen> {
  List<TimeRequest>? _requests;
  String? _requestsError;
  bool _loadingRequests = false;
  int? _lastPendingCount;

  /// Қимати ҳисобшудаи sync-ро аз ҳолати ҷорӣ бармегардонад.
  ChildSync get sync => widget.sync;

  /// Тағйири ҳамоҳангсозиро мешунавад ва дархостҳои вақти фарзандро бор мекунад.
  @override
  void initState() {
    super.initState();
    sync.addListener(_onSync);
    _lastPendingCount = sync.child?.pendingRequests;
    _loadRequests();
  }

  /// Controller ва listener-ҳои ChildRulesScreen-ро озод мекунад.
  @override
  void dispose() {
    sync.removeListener(_onSync);
    super.dispose();
  }

  /// onSync рӯйдодро коркард карда, ҳолати вобастаро нав мекунад.
  void _onSync() {
    if (!mounted) return;
    // Қадами дохилии татбиқи маҳдудиятҳои барнома, хоб ва дарс.
    final pending = sync.child?.pendingRequests;
    if (pending != _lastPendingCount) {
      _lastPendingCount = pending;
      _loadRequests();
    }
    setState(() {});
  }

  /// loadRequests додаҳоро мехонад ва ҳолати экранро нав мекунад.
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

  /// refresh додаҳои қоидаҳои фарзанд-ро боз мехонад ва ChildRulesScreen-ро нав мекунад.
  Future<void> _refresh() async {
    await sync.forceSync();
    await _loadRequests();
  }

  /// askTime иҷозат ё маълумоти лозимро дархост мекунад.
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
      showMessage(context, tr('Дархост фиристода шуд'));
      await _loadRequests();
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 409) {
        showMessage(
          context,
          tr(
            'Барои «{app}» аллакай дархост ҳаст — ҷавоби волидайнро интизор шавед.',
            {'app': app.name},
          ),
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

  /// Қоидаҳои фаъол, лимитҳои барномаҳо ва дархостҳои вақти фарзандро нишон медиҳад.
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
      Text(
        tr('Қоидаҳои ман'),
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 4),
      Text(
        tr('Инҳоро волидайн барои ин телефон муқаррар кардаанд.'),
        style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4),
      ),
      const SizedBox(height: 8),
      // Қадами дохилии татбиқи маҳдудиятҳои барнома, хоб ва дарс.
      if (bedtimeActive) ...[
        const SizedBox(height: 4),
        FadeIn(child: BedtimeNotice(bedtime: bedtime)),
        const SizedBox(height: 4),
      ] else if (studyActive) ...[
        const SizedBox(height: 4),
        FadeIn(child: StudyNotice(study: study)),
        const SizedBox(height: 4),
      ],
      if (child == null)
        Padding(
          padding: const EdgeInsets.only(top: 40),
          child: sync.lastError != null
              ? StateMessage(
                  icon: Icons.cloud_off_rounded,
                  title: tr('Қоидаҳо бор нашуданд'),
                  text: sync.lastError,
                  actionLabel: tr('Аз нав кӯшиш'),
                  onAction: _refresh,
                  error: true,
                )
              : const Center(child: CircularProgressIndicator()),
        )
      else if (empty)
        Padding(
          padding: const EdgeInsets.only(top: 24),
          child: StateMessage(
            icon: Icons.verified_user_outlined,
            title: tr('Ҳоло қоида нест'),
            text: tr('Ҳамаи барномаҳо бе маҳдудият кушода ҳастанд.'),
          ),
        )
      else ...[
        if (blocked.isNotEmpty) ...[
          _GroupHeader(
            icon: Icons.block_rounded,
            color: NigohDesign.coral,
            title: tr('Баста ({n})', {'n': blocked.length}),
            text: tr('Ин барномаҳо ҳоло кушода намешаванд.'),
          ),
          for (final app in blocked)
            FadeIn(
              index: index++,
              child: _AppRule(
                app: app,
                locked: true,
                subtitle: tr('Волидайн ин барномаро бастаанд'),
                pill: Pill(tr('Баста'), color: NigohDesign.coral),
                onAsk: () => _askTime(app),
              ),
            ),
        ],
        if (limited.isNotEmpty) ...[
          _GroupHeader(
            icon: Icons.timelapse_rounded,
            color: NigohDesign.amber,
            title: tr('Лимити рӯзона ({n})', {'n': limited.length}),
            text: tr('Ҳар рӯз вақти муайян; баъд барнома баста мешавад.'),
          ),
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
                    ? Pill(tr('Вақт тамом'), color: NigohDesign.coral)
                    : null,
                onAsk: () => _askTime(app),
              ),
            ),
        ],
        if (scheduled.isNotEmpty) ...[
          _GroupHeader(
            icon: Icons.schedule_rounded,
            color: NigohDesign.amber,
            title: tr('Вақти дарс ({n})', {'n': scheduled.length}),
            text: tr('Танҳо дар ин соатҳо кушода мешаванд.'),
          ),
          for (final app in scheduled)
            FadeIn(
              index: index++,
              child: _AppRule(
                app: app,
                subtitle:
                    '${app.schedule.start} – ${app.schedule.end} · ${weekdaysLabel(app.schedule.weekdays)}',
                pill: Pill(tr('Ҷадвал'), color: NigohDesign.amber),
              ),
            ),
        ],
        if (bedtime.enabled) ...[
          _GroupHeader(
            icon: Icons.bedtime_rounded,
            color: NigohDesign.violet,
            title: tr('Вақти хоб'),
            text: tr('Шабона телефон истироҳат мекунад.'),
          ),
          FadeIn(
            index: index++,
            child: _RuleCard(
              leading: ChildIconTile(
                icon: Icons.bedtime_rounded,
                color: NigohDesign.violet,
              ),
              title: '${bedtime.start} – ${bedtime.end}',
              subtitle: tr(
                'Ҳамаи барномаҳо, ғайр аз иҷозатдодашудаҳо, баста мешаванд.',
              ),
              trailing: bedtimeActive
                  ? Pill(tr('Ҳозир фаъол'), color: NigohDesign.violet)
                  : null,
            ),
          ),
        ],
        if (study.enabled) ...[
          _GroupHeader(
            icon: Icons.school_rounded,
            color: NigohDesign.mint,
            title: tr('Тамаркузи дарс'),
            text: tr('Дар соатҳои дарс танҳо чизҳои лозимӣ кушодаанд.'),
          ),
          FadeIn(
            index: index++,
            child: _RuleCard(
              leading: ChildIconTile(
                icon: Icons.school_rounded,
                color: NigohDesign.mint,
              ),
              title:
                  '${study.start} – ${study.end} · ${weekdaysLabel(study.weekdays)}',
              subtitle: tr(
                'Бозиҳо, шабакаҳо ва видео баста мешаванд. Занг, SMS ва '
                'барномаҳои таълимӣ кушода мемонанд.',
              ),
              trailing: studyActive
                  ? Pill(tr('Ҳозир фаъол'), color: NigohDesign.mint)
                  : null,
            ),
          ),
          if (studyApps.isNotEmpty) ...[
            _GroupHeader(
              icon: Icons.lock_clock_rounded,
              color: NigohDesign.mint,
              title: tr('Дар соатҳои дарс баста ({n})', {
                'n': studyApps.length,
              }),
              text: tr('Инҳо дар вақти дарс пӯшида мешаванд.'),
            ),
            for (final app in studyApps)
              FadeIn(
                index: index++,
                child: _AppRule(
                  key: ValueKey('study-app-${app.packageName}'),
                  app: app,
                  locked: studyActive,
                  subtitle: categoryOf(app).label,
                  pill: studyActive
                      ? Pill(tr('Дарс'), color: NigohDesign.mint)
                      : null,
                ),
              ),
          ],
        ],
        if (allowed.isNotEmpty) ...[
          _GroupHeader(
            icon: Icons.verified_rounded,
            color: NigohDesign.mint,
            title: tr('Ҳамеша иҷозат ({n})', {'n': allowed.length}),
            text: tr('Инҳо ҳамеша кушодаанд — ҳатто дар вақти хоб.'),
          ),
          for (final app in allowed)
            FadeIn(
              index: index++,
              child: _AppRule(
                app: app,
                subtitle: tr('Ҳатто дар вақти хоб кушода аст'),
                pill: Pill(tr('Иҷозат'), color: NigohDesign.mint),
              ),
            ),
        ],
      ],
      if (child != null) ...[
        _GroupHeader(
          icon: Icons.more_time_rounded,
          color: NigohDesign.blue,
          title: tr('Дархостҳои ман'),
          text: tr('Ҷавоби волидайн ба дархостҳои вақти иловагӣ.'),
        ),
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

/// Widget-и GroupHeader-ро барои татбиқи маҳдудиятҳои барнома, хоб ва дарс месозад.
class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.icon,
    required this.color,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String text;

  /// Widget-и GroupHeader-ро барои қоидаҳо ва дархостҳои вақти фарзанд месозад.
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 22, 2, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ChildIconTile(icon: icon, color: color, size: 32),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12.5,
                    height: 1.3,
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

/// Widget-и RuleCard-ро барои татбиқи маҳдудиятҳои барнома, хоб ва дарс месозад.
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

  /// Widget-и RuleCard-ро барои қоидаҳо ва дархостҳои вақти фарзанд месозад.
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
                    AnimatedSwitcher(
                      duration: childReducedMotion(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 250),
                      child: trailing,
                    ),
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

/// AppRule додаҳо ва рафтори қоидаҳои фарзанд-ро ифода мекунад.
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

  /// Widget-и AppRule-ро барои қоидаҳо ва дархостҳои вақти фарзанд месозад.
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
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (value != null)
                    ChildProgressBar(
                      value: value,
                      color: value >= 1
                          ? NigohDesign.coral
                          : value >= .8
                          ? NigohDesign.amber
                          : scheme.primary,
                    ),
                  if (onAsk != null) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.tonalIcon(
                        onPressed: onAsk,
                        icon: const Icon(Icons.more_time_rounded, size: 18),
                        label: Text(tr('Вақти иловагӣ пурсидан')),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

/// TimeAsk додаҳо ва рафтори қоидаҳои фарзанд-ро ифода мекунад.
class _TimeAsk {
  const _TimeAsk(this.minutes, this.reason);
  final int minutes;
  final String? reason;
}

/// Равзанаи TimeRequestSheet-ро барои татбиқи маҳдудиятҳои барнома, хоб ва дарс нишон медиҳад.
class _TimeRequestSheet extends StatefulWidget {
  const _TimeRequestSheet({required this.app});
  final ChildApp app;

  /// Ҳолати TimeRequestSheet-ро барои қоидаҳо ва дархостҳои вақти фарзанд месозад.
  @override
  State<_TimeRequestSheet> createState() => _TimeRequestSheetState();
}

/// Ҳолат ва рафтори TimeRequestSheetState-ро барои навсозии интерфейс идора мекунад.
class _TimeRequestSheetState extends State<_TimeRequestSheet> {
  int _minutes = 15;
  final _reason = TextEditingController();

  /// Controller ва listener-ҳои TimeRequestSheet-ро озод мекунад.
  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  /// Widget-и TimeRequestSheet-ро барои қоидаҳо ва дархостҳои вақти фарзанд месозад.
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
                  tr('Вақти иловагӣ барои «{app}»', {'app': widget.app.name}),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            tr('Волидайн дархости шуморо мебинанд ва ҷавоб медиҳанд.'),
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 13,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            tr('Чанд дақиқа лозим аст?'),
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final m in const [15, 30, 60])
                ChoiceChip(
                  label: Text(tr('{m} дақ', {'m': m})),
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
            decoration: InputDecoration(
              labelText: tr('Сабаб (ихтиёрӣ)'),
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
            label: Text(tr('Фиристодан')),
          ),
        ],
      ),
    );
  }
}

/// RequestsList додаҳо ва рафтори қоидаҳои фарзанд-ро ифода мекунад.
class _RequestsList extends StatelessWidget {
  const _RequestsList({
    required this.requests,
    required this.error,
    required this.onRetry,
  });

  final List<TimeRequest>? requests;
  final String? error;
  final VoidCallback onRetry;

  /// Widget-и RequestsList-ро барои қоидаҳо ва дархостҳои вақти фарзанд месозад.
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
              tr('Ҳоло дархост нафиристодаед.'),
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
        for (final (i, r) in list.indexed)
          FadeIn(
            index: i,
            child: _RuleCard(
              leading: const ChildIconTile(
                icon: Icons.more_time_rounded,
                color: NigohDesign.blue,
              ),
              title: r.appName,
              subtitle: [
                tr('+{m} дақ', {'m': r.minutes}),
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

/// requestStatusPill иҷозат ё маълумоти лозимро дархост мекунад.
Widget requestStatusPill(String status) => switch (status) {
  'approved' => Pill(
    tr('иҷозат дода шуд'),
    color: NigohDesign.mint,
    icon: Icons.check_circle_rounded,
  ),
  'denied' => Pill(
    tr('рад шуд'),
    color: NigohDesign.coral,
    icon: Icons.cancel_rounded,
  ),
  _ => Pill(
    tr('интизор'),
    color: NigohDesign.amber,
    icon: Icons.hourglass_top_rounded,
  ),
};

/// InlineError додаҳо ва рафтори қоидаҳои фарзанд-ро ифода мекунад.
class _InlineError extends StatelessWidget {
  const _InlineError({required this.text, required this.onRetry});
  final String text;
  final VoidCallback onRetry;

  /// Widget-и InlineError-ро барои қоидаҳо ва дархостҳои вақти фарзанд месозад.
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
          TextButton(onPressed: onRetry, child: Text(tr('Аз нав'))),
        ],
      ),
    );
  }
}
