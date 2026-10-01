import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models.dart';
import '../../ui/nigoh_design.dart';
import 'child_rules.dart' show minutesLabel;

/// Text of the SOS chat message (message_type 'urgent').
String sosMessageText({double? latitude, double? longitude, int? battery}) {
  final lines = ['SOS — ба кӯмак ниёз дорам!'];
  if (latitude != null && longitude != null) {
    lines.add(
      'Ҷойгиршавӣ: https://maps.google.com/?q='
      '${latitude.toStringAsFixed(6)},${longitude.toStringAsFixed(6)}',
    );
  } else {
    lines.add('Ҷойгиршавӣ ҳоло маълум нест.');
  }
  if (battery != null) lines.add('Батарея: $battery%');
  return lines.join('\n');
}

/// Big SOS button: must be held for [holdDuration] (a ring fills up) so it
/// is never sent by accident.
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

  void _down() {
    if (_sending) return;
    HapticFeedback.selectionClick();
    _hold.forward(from: 0);
  }

  void _release() {
    if (_sending || _hold.isCompleted) return;
    _hold.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const red = NigohDesign.coral;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
        child: Column(
          children: [
            Semantics(
              button: true,
              label: 'SOS. Барои фиристодан пахш карда нигоҳ доред.',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (_) => _down(),
                onTapUp: (_) => _release(),
                onTapCancel: _release,
                child: AnimatedBuilder(
                  animation: _hold,
                  builder: (context, _) => SizedBox(
                    width: 132,
                    height: 132,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox.expand(
                          child: CircularProgressIndicator(
                            value: _sending ? null : _hold.value,
                            strokeWidth: 6,
                            color: red,
                            backgroundColor: red.withValues(alpha: .14),
                          ),
                        ),
                        Container(
                          width: 108 - 8 * _hold.value,
                          height: 108 - 8 * _hold.value,
                          decoration: const BoxDecoration(
                            color: red,
                            shape: BoxShape.circle,
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
                                    fontSize: 30,
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
            const SizedBox(height: 12),
            Text(
              _sending
                  ? 'Фиристода мешавад…'
                  : 'Дар ҳолати хатар пахш карда нигоҳ доред',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Calm notice while bedtime is active.
class BedtimeNotice extends StatelessWidget {
  const BedtimeNotice({super.key, required this.bedtime});
  final Bedtime bedtime;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const color = NigohDesign.violet;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: .30)),
      ),
      child: Row(
        children: [
          const Icon(Icons.bedtime_rounded, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Вақти хоб — барномаҳо то ${bedtime.end} баста ҳастанд',
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

/// «Вақти экрани ман»: today's total and the most used apps.
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
            Text(
              'Имрӯз',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 2),
            Text(
              minutesLabel(total),
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
            ),
            if (used.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Имрӯз ҳоло барнома истифода нашудааст.',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              )
            else ...[
              const SizedBox(height: 12),
              for (final app in used.take(top))
                Padding(
                  padding: const EdgeInsets.only(top: 10),
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
                                Text(
                                  minutesLabel(app.usageMinutesToday),
                                  style: TextStyle(
                                    color: scheme.onSurfaceVariant,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(99),
                              child: LinearProgressIndicator(
                                value: app.usageMinutesToday / most,
                                minHeight: 5,
                                color: NigohDesign.accentFor(app.packageName),
                                backgroundColor:
                                    scheme.surfaceContainerHighest,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
