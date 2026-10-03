// Reusable child-phone widgets: the hold-to-send SOS button and its sending
// logic, bedtime/study notices, screen-time cards and small progress/icon UI.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models.dart';
import '../../ui/nigoh_design.dart';
import '../../ui/widgets.dart';
import 'child_rules.dart' show minutesLabel;
import '../../l10n/l10n.dart';

/// True when the phone asks for less motion (accessibility setting):
/// progress bars and entry animations then jump straight to their end state.
bool childReducedMotion(BuildContext context) =>
    MediaQuery.maybeOf(context)?.disableAnimations ?? false;

/// Text of the SOS chat message (message_type 'urgent').
String sosMessageText({double? latitude, double? longitude, int? battery}) {
  final lines = [tr('SOS — ба кӯмак ниёз дорам!')];
  if (latitude != null && longitude != null) {
    lines.add(
      tr('Ҷойгиршавӣ: {url}', {
        'url':
            'https://maps.google.com/?q='
            '${latitude.toStringAsFixed(6)},${longitude.toStringAsFixed(6)}',
      }),
    );
  } else {
    lines.add(tr('Ҷойгиршавӣ ҳоло маълум нест.'));
  }
  if (battery != null) {
    lines.add(tr('Батарея: {battery}%', {'battery': battery}));
  }
  return lines.join('\n');
}

/// Rounded progress bar that animates to a new [value] (0..1) instead of
/// jumping, so a child sees the bar grow.
class ChildProgressBar extends StatelessWidget {
  const ChildProgressBar({
    super.key,
    required this.value,
    required this.color,
    this.height = 7,
  });

  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final end = value.isNaN ? 0.0 : value.clamp(0.0, 1.0);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: end),
      duration: childReducedMotion(context)
          ? Duration.zero
          : const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      builder: (_, t, _) => ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: LinearProgressIndicator(
          value: t,
          minHeight: height,
          color: color,
          backgroundColor: scheme.surfaceContainerHighest,
        ),
      ),
    );
  }
}

/// Soft coloured tile with an icon — the leading element of every card on the
/// child's phone.
class ChildIconTile extends StatelessWidget {
  const ChildIconTile({
    super.key,
    required this.icon,
    required this.color,
    this.size = 44,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: childReducedMotion(context)
        ? Duration.zero
        : const Duration(milliseconds: 250),
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(size * .32),
    ),
    child: Icon(icon, color: color, size: size * .5),
  );
}

/// The one button the child must never miss: it must be held for
/// [holdDuration] (a ring fills up) so it is never sent by accident, and it
/// says in plain words what happens when it is sent.
class SosButton extends StatefulWidget {
  const SosButton({
    super.key,
    required this.onTriggered,
    this.holdDuration = const Duration(milliseconds: 1500),
  });

  final Future<void> Function() onTriggered;
  final Duration holdDuration;

  @override
  State<SosButton> createState() => _SosButtonState();
}

/// Fills a ring while the SOS button is held and fires once it completes.
class _SosButtonState extends State<SosButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hold = AnimationController(
    vsync: this,
    duration: widget.holdDuration,
  )..addStatusListener(_onStatus);
  bool _sending = false;

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  /// Sends the SOS when the hold animation completes.
  Future<void> _onStatus(AnimationStatus status) async {
    if (status != AnimationStatus.completed || _sending) return;
    setState(() => _sending = true);
    HapticFeedback.heavyImpact();
    try {
      await widget.onTriggered();
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        _hold.value = 0;
      }
    }
  }

  /// Starts the hold animation when the finger goes down.
  void _down() {
    if (_sending) return;
    HapticFeedback.selectionClick();
    _hold.forward(from: 0);
  }

  /// Cancels the SOS when the finger is lifted before the hold completes.
  void _release() {
    if (_sending || _hold.isCompleted) return;
    _hold.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const red = NigohDesign.coral;
    return Card(
      child: Container(
        decoration: BoxDecoration(
          color: red.withValues(alpha: .05),
          borderRadius: BorderRadius.circular(19),
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const ChildIconTile(
                  icon: Icons.emergency_share_rounded,
                  color: red,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('SOS — кӯмак пурсидан'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tr(
                          'Волидайн фавран хабар мегиранд — ҷои шумо ва '
                          'батарея фиристода мешавад.',
                        ),
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
            const SizedBox(height: 14),
            Center(
              child: Semantics(
                button: true,
                label: tr('SOS. Барои фиристодан пахш карда нигоҳ доред.'),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (_) => _down(),
                  onTapUp: (_) => _release(),
                  onTapCancel: _release,
                  child: AnimatedBuilder(
                    animation: _hold,
                    builder: (context, _) => SizedBox(
                      width: 140,
                      height: 140,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox.expand(
                            child: CircularProgressIndicator(
                              value: _sending ? null : _hold.value,
                              strokeWidth: 7,
                              color: red,
                              backgroundColor: red.withValues(alpha: .14),
                            ),
                          ),
                          Container(
                            width: 112 - 8 * _hold.value,
                            height: 112 - 8 * _hold.value,
                            decoration: BoxDecoration(
                              color: red,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: red.withValues(alpha: .28),
                                  blurRadius: 18 + 10 * _hold.value,
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: _sending
                                ? const SizedBox(
                                    width: 28,
                                    height: 28,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 3,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'SOS',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 32,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 2,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            AnimatedBuilder(
              animation: _hold,
              builder: (context, _) {
                final holding = !_sending && _hold.value > 0.02;
                return AnimatedSwitcher(
                  duration: childReducedMotion(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 180),
                  child: Text(
                    _sending
                        ? tr('Фиристода мешавад…')
                        : holding
                        ? tr('Нигоҳ доред…')
                        : tr('Дар ҳолати хатар пахш карда нигоҳ доред'),
                    key: ValueKey(_sending ? 2 : (holding ? 1 : 0)),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: holding || _sending
                          ? red
                          : scheme.onSurfaceVariant,
                      fontSize: 13,
                      fontWeight: holding || _sending
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Coloured notice with one short sentence — used for bedtime and study mode.
class ChildNotice extends StatelessWidget {
  const ChildNotice({
    super.key,
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: .30)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: scheme.onSurface,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Calm notice while bedtime is active.
class BedtimeNotice extends StatelessWidget {
  const BedtimeNotice({super.key, required this.bedtime});
  final Bedtime bedtime;

  @override
  Widget build(BuildContext context) => ChildNotice(
    icon: Icons.bedtime_rounded,
    color: NigohDesign.violet,
    text: tr('Вақти хоб — барномаҳо то {end} баста ҳастанд', {
      'end': bedtime.end,
    }),
  );
}

/// Calm notice while «Тамаркузи дарс» is active.
class StudyNotice extends StatelessWidget {
  const StudyNotice({super.key, required this.study});
  final StudyMode study;

  @override
  Widget build(BuildContext context) => KeyedSubtree(
    key: const ValueKey('study-notice'),
    child: ChildNotice(
      icon: Icons.school_rounded,
      color: NigohDesign.mint,
      text: tr('Тамаркузи дарс — бозиҳо ва шабакаҳо то {end} баста ҳастанд', {
        'end': study.end,
      }),
    ),
  );
}

/// «Вақти экрани ман»: today's total in words plus the most used apps with
/// animated bars.
class ScreenTimeCard extends StatelessWidget {
  const ScreenTimeCard({super.key, required this.apps, this.top = 5});
  final List<ChildApp> apps;
  final int top;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final used = apps.where((a) => a.usageMinutesToday > 0).toList()
      ..sort((a, b) => b.usageMinutesToday.compareTo(a.usageMinutesToday));
    final total = used.fold<int>(0, (s, a) => s + a.usageMinutesToday);
    final most = used.isEmpty ? 1 : used.first.usageMinutesToday;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const ChildIconTile(
                  icon: Icons.hourglass_bottom_rounded,
                  color: NigohDesign.blue,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('Вақти экрани ман'),
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        minutesLabel(total),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                Pill(tr('Имрӯз'), color: NigohDesign.blue),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              used.isEmpty
                  ? tr('Имрӯз ҳоло барнома истифода нашудааст.')
                  : tr('Имрӯз чӣ қадар вақт дар кадом барнома гузаштед.'),
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 13,
                height: 1.35,
              ),
            ),
            for (final (i, app) in used.take(top).indexed)
              FadeIn(
                index: i,
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    children: [
                      NigohAppIcon(
                        icon: app.iconBase64,
                        seed: app.packageName,
                        size: 34,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    app.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  minutesLabel(app.usageMinutesToday),
                                  style: TextStyle(
                                    color: scheme.onSurfaceVariant,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ChildProgressBar(
                              value: app.usageMinutesToday / most,
                              color: NigohDesign.accentFor(app.packageName),
                              height: 6,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
