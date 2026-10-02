import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../ui/nigoh_design.dart';
import '../../ui/widgets.dart';
import 'family_controller.dart';
import 'parent_logic.dart';
import '../../l10n/l10n.dart';

TimeOfDay parseHhmm(String value, TimeOfDay fallback) {
  final parts = value.split(':');
  if (parts.length != 2) return fallback;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
    return fallback;
  }
  return TimeOfDay(hour: h, minute: m);
}

String formatHhmm(TimeOfDay t) => '${two(t.hour)}:${two(t.minute)}';

/// «Вақти хоб»: switch + start/end. Saves through the controller and
/// closes with `true` on success; errors are shown and the sheet stays open.
class BedtimeSheet extends StatefulWidget {
  const BedtimeSheet({
    super.key,
    required this.controller,
    required this.child,
  });
  final FamilyController controller;
  final FamilyChild child;

  @override
  State<BedtimeSheet> createState() => _BedtimeSheetState();
}

class _BedtimeSheetState extends State<BedtimeSheet> {
  late bool enabled;
  late TimeOfDay start;
  late TimeOfDay end;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final b = widget.child.bedtime;
    enabled = b.enabled;
    start = parseHhmm(b.start, const TimeOfDay(hour: 21, minute: 30));
    end = parseHhmm(b.end, const TimeOfDay(hour: 7, minute: 0));
  }

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

  Future<void> _save() async {
    final bedtime = Bedtime(
      enabled: enabled,
      start: formatHhmm(start),
      end: formatHhmm(end),
    );
    setState(() => saving = true);
    try {
      await widget.controller.setBedtime(widget.child, bedtime);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => saving = false);
      showMessage(context, e, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final same = formatHhmm(start) == formatHhmm(end);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('Вақти хоб'),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              tr(
                'Дар ин вақт ҳамаи барномаҳои {name} баста мешаванд, ба ғайр аз барномаҳои «Ҳамеша иҷозат».',
                {'name': widget.child.name},
              ),
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              key: const ValueKey('bedtime-switch'),
              contentPadding: EdgeInsets.zero,
              title: Text(tr('Вақти хоб фаъол')),
              value: enabled,
              onChanged: (v) => setState(() => enabled = v),
            ),
            Row(
              children: [
                Expanded(
                  child: TimeTile(
                    key: const ValueKey('bedtime-start'),
                    label: tr('Оғоз'),
                    value: formatHhmm(start),
                    enabled: enabled,
                    onTap: () => _pick(true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TimeTile(
                    key: const ValueKey('bedtime-end'),
                    label: tr('Анҷом'),
                    value: formatHhmm(end),
                    enabled: enabled,
                    onTap: () => _pick(false),
                  ),
                ),
              ],
            ),
            if (enabled && same)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  tr('Оғоз ва анҷом бояд гуногун бошанд.'),
                  style: TextStyle(color: scheme.error, fontSize: 12),
                ),
              ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const ValueKey('bedtime-save'),
                onPressed: saving || (enabled && same) ? null : _save,
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
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

class TimeTile extends StatelessWidget {
  const TimeTile({
    super.key,
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

/// Per-app extras: «Ҳамеша иҷозат» and today's bonus time.
class AppOptionsSheet extends StatefulWidget {
  const AppOptionsSheet({
    super.key,
    required this.controller,
    required this.childId,
    required this.packageName,
  });

  final FamilyController controller;
  final int childId;
  final String packageName;

  @override
  State<AppOptionsSheet> createState() => _AppOptionsSheetState();
}

class _AppOptionsSheetState extends State<AppOptionsSheet> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) showMessage(context, done);
    } catch (e) {
      if (mounted) showMessage(context, e, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final child = widget.controller.childById(widget.childId);
      final app = child?.apps
          .where((a) => a.packageName == widget.packageName)
          .firstOrNull;
      if (child == null || app == null) return const SizedBox(height: 80);
      final scheme = Theme.of(context).colorScheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  NigohAppIcon(
                    icon: app.iconBase64,
                    seed: app.packageName,
                    size: 40,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      app.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                key: ValueKey('always-${app.packageName}'),
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(
                  Icons.verified_user_rounded,
                  color: NigohDesign.mint,
                ),
                title: Text(tr('Ҳамеша иҷозат')),
                subtitle: Text(
                  tr(
                    'Ин барнома ҳеҷ гоҳ бо танаффус ё вақти хоб баста намешавад. Масалан, барои занг ё харита.',
                  ),
                ),
                value: app.alwaysAllowed,
                onChanged: _busy
                    ? null
                    : (v) => _run(
                        () => widget.controller.setAlwaysAllowed(child, app, v),
                        v
                            ? tr('Ҳамеша иҷозат дода шуд')
                            : tr('Қоидаи муқаррарӣ'),
                      ),
              ),
              const Divider(height: 24),
              Text(
                tr('Вақти иловагӣ'),
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                app.dailyLimitMinutes > 0
                    ? tr('Танҳо барои имрӯз ба лимит илова мешавад.')
                    : tr(
                        'Барои ин барнома лимит нест. Вақти иловагӣ пас аз гузоштани лимит кор мекунад.',
                      ),
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 10),
              BonusButtons(
                app: app,
                enabled: !_busy && app.dailyLimitMinutes > 0,
                onBonus: (m) => _run(
                  () => widget.controller.giveBonus(child, app, m),
                  tr('{name}: +{m} дақ барои имрӯз', {
                    'name': app.name,
                    'm': m,
                  }),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// «+15 / +30 / +60» and the current «+N дақ имрӯз».
class BonusButtons extends StatelessWidget {
  const BonusButtons({
    super.key,
    required this.app,
    required this.onBonus,
    this.enabled = true,
  });

  final ChildApp app;
  final ValueChanged<int> onBonus;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 6,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      for (final m in const [15, 30, 60])
        ActionChip(
          key: ValueKey('bonus-${app.packageName}-$m'),
          avatar: const Icon(Icons.more_time_rounded, size: 16),
          label: Text('+$m'),
          onPressed: enabled ? () => onBonus(m) : null,
        ),
      if (app.bonusMinutesToday > 0)
        Pill(
          tr('+{bonusMinutesToday} дақ имрӯз', {
            'bonusMinutesToday': app.bonusMinutesToday,
          }),
          color: NigohDesign.amber,
        ),
    ],
  );
}
