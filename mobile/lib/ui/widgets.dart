import 'package:flutter/material.dart';

import '../core/api.dart';
import '../l10n/l10n.dart';

/// Small shared building blocks so every screen looks the same.

/// True when the user asked the system for less motion (accessibility) — all
/// decorative animations below collapse to their end state then.
bool reducedMotion(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

void showMessage(BuildContext context, Object message, {bool error = false}) {
  final text = message is ApiException ? message.message : '$message';
  final scheme = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? scheme.error : null,
      ),
    );
}

/// Calm empty / error state with an optional action.
class StateMessage extends StatelessWidget {
  const StateMessage({
    super.key,
    required this.icon,
    required this.title,
    this.text,
    this.actionLabel,
    this.onAction,
    this.error = false,
    this.color,
    this.actionIcon,
    this.primaryAction = false,
  });

  final IconData icon;
  final String title;
  final String? text;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool error;

  /// Accent for the icon tile and the action (defaults to the primary colour,
  /// or the error colour when [error]). Use a NigohDesign accent for meaning.
  final Color? color;

  /// Optional icon on the action button.
  final IconData? actionIcon;

  /// Makes the action a filled (dominant) button — for empty states where
  /// tapping it is the one thing to do next.
  final bool primaryAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = this.color ?? (error ? scheme.error : scheme.primary);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            if (text != null) ...[
              const SizedBox(height: 6),
              Text(
                text!,
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              if (primaryAction)
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(180, 50),
                    backgroundColor: color,
                  ),
                  onPressed: onAction,
                  icon: actionIcon == null ? null : Icon(actionIcon),
                  label: Text(actionLabel!),
                )
              else
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(160, 46),
                    foregroundColor: color,
                  ),
                  onPressed: onAction,
                  icon: actionIcon == null ? null : Icon(actionIcon, size: 18),
                  label: Text(actionLabel!),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Section title used above groups of cards. [subtitle] is the one plain
/// sentence that says what the group is for — keep it short.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.subtitle, this.trailing});
  final String text;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hint = subtitle;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (hint != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    hint,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// One muted sentence that says what a screen is for.
class ScreenHint extends StatelessWidget {
  const ScreenHint(this.text, {super.key, this.icon});
  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = TextStyle(
      fontSize: 13,
      height: 1.4,
      color: scheme.onSurfaceVariant,
    );
    if (icon == null) return Text(text, style: style);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: scheme.onSurfaceVariant),
        const SizedBox(width: 7),
        Expanded(child: Text(text, style: style)),
      ],
    );
  }
}

/// Rounded status label, e.g. «Онлайн», «Баста».
class Pill extends StatelessWidget {
  const Pill(
    this.text, {
    super.key,
    required this.color,
    this.icon,
    this.tooltip,
    this.big = false,
  });
  final String text;
  final Color color;
  final IconData? icon;

  /// Long-press / hover explanation, so a short pill can stay short.
  final String? tooltip;

  /// Slightly larger type and padding for pills that carry a number + unit.
  final bool big;

  @override
  Widget build(BuildContext context) {
    final pill = Container(
      padding: big
          ? const EdgeInsets.symmetric(horizontal: 11, vertical: 5)
          : const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: big ? 15 : 13, color: color),
            const SizedBox(width: 4),
          ],
          // Flexible so a long label ellipsizes in a narrow row instead of
          // overflowing it.
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: big ? 13 : 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    final hint = tooltip;
    return hint == null ? pill : Tooltip(message: hint, child: pill);
  }
}

/// Fades and slides its child in once (staggered with [index]).
/// Collapses to the end state when the user asked for less motion.
class FadeIn extends StatelessWidget {
  const FadeIn({super.key, required this.child, this.index = 0});
  final Widget child;
  final int index;

  @override
  Widget build(BuildContext context) {
    if (reducedMotion(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 320 + 50 * index.clamp(0, 8)),
      curve: Curves.easeOutCubic,
      builder: (_, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - t)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// Presses its child in a little while it is held down — use it on big tap
/// targets (role cards, action cards) so a tap feels answered.
class TapScale extends StatefulWidget {
  const TapScale({
    super.key,
    required this.child,
    this.onTap,
    this.scale = .97,
  });
  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  @override
  State<TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<TapScale> {
  bool down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null && !reducedMotion(context);
    return GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      onTapDown: enabled ? (_) => setState(() => down = true) : null,
      onTapUp: enabled ? (_) => setState(() => down = false) : null,
      onTapCancel: enabled ? () => setState(() => down = false) : null,
      child: AnimatedScale(
        scale: down ? widget.scale : 1,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Relative time in Tajik: «ҳозир», «5 дақ пеш», «2 соат пеш», «12.09 14:30».
String timeAgo(DateTime? time) {
  if (time == null) return '—';
  final diff = DateTime.now().difference(time.toLocal());
  if (diff.inMinutes < 1) return tr('ҳозир');
  if (diff.inMinutes < 60) return tr('{n} дақ пеш', {'n': diff.inMinutes});
  if (diff.inHours < 24) return tr('{n} соат пеш', {'n': diff.inHours});
  final t = time.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(t.day)}.${two(t.month)} ${two(t.hour)}:${two(t.minute)}';
}

/// Server timestamps come as 'YYYY-MM-DD HH:MM:SS' (UTC) or ISO.
DateTime? parseServerTime(Object? raw) {
  if (raw == null) return null;
  final text = raw.toString().trim();
  if (text.isEmpty) return null;
  final iso = text.contains('T') ? text : text.replaceFirst(' ', 'T');
  final hasZone = iso.endsWith('Z') || RegExp(r'[+-]\d\d:\d\d$').hasMatch(iso);
  return DateTime.tryParse(hasZone ? iso : '${iso}Z');
}
