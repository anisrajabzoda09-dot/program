// Shared, animated «how much of the limit is used» widgets.
//
// Both are safe on every screen (parent, child, settings) and respect
// reduced motion: with animations switched off they paint their end state.
// Numbers always carry their unit, e.g. «45 дақ аз 60».

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import 'widgets.dart';

/// A labelled meter: title on the left, value + unit on the right, an animated
/// bar underneath. [value] and [max] are in the same unit as [unit].
///
/// Wrap the label and the unit with `tr(...)` at the call site, e.g.
/// `StatMeter(label: …, value: usedMinutes, max: limitMinutes, unit: …,
/// color: NigohDesign.amber)`.
class StatMeter extends StatelessWidget {
  const StatMeter({
    super.key,
    required this.label,
    required this.value,
    required this.max,
    this.unit,
    this.color,
    this.valueText,
    this.icon,
    this.compact = false,
  });

  final String label;
  final double value;

  /// Full scale; a value of 0 or less draws an empty bar.
  final double max;

  /// Unit shown after the value («дақ», «соат», «%»).
  final String? unit;
  final Color? color;

  /// Overrides the generated «45 дақ аз 60» text.
  final String? valueText;
  final IconData? icon;

  /// Thinner bar and smaller type, for use inside a dense list row.
  final bool compact;

  double get fraction => max <= 0 ? 0 : (value / max).clamp(0.0, 1.0);

  /// Number text without a needless ".0".
  String _number(double v) {
    final rounded = v.roundToDouble();
    return rounded == v ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = color ?? scheme.primary;
    // «45 дақ аз 60» — the number always carries its unit.
    final text =
        valueText ??
        (unit == null
            ? tr('{value} аз {max}', {
                'value': _number(value),
                'max': _number(max),
              })
            : tr('{value} {unit} аз {max}', {
                'value': _number(value),
                'unit': unit,
                'max': _number(max),
              }));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: compact ? 15 : 17, color: accent),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: compact ? 12.5 : 14,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              text,
              style: TextStyle(
                fontSize: compact ? 12.5 : 14,
                fontWeight: FontWeight.w700,
                color: accent,
              ),
            ),
          ],
        ),
        SizedBox(height: compact ? 5 : 8),
        StatBar(fraction: fraction, color: accent, height: compact ? 6 : 8),
      ],
    );
  }
}

/// Just the animated bar of [StatMeter] — for places that already have their
/// own label row.
class StatBar extends StatelessWidget {
  const StatBar({
    super.key,
    required this.fraction,
    this.color,
    this.height = 8,
  });

  /// 0…1; values outside are clamped.
  final double fraction;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = color ?? scheme.primary;
    final target = fraction.clamp(0.0, 1.0);
    final radius = BorderRadius.circular(height);
    Widget fill(double t) => Align(
      alignment: AlignmentDirectional.centerStart,
      child: FractionallySizedBox(
        widthFactor: t,
        child: DecoratedBox(
          decoration: BoxDecoration(color: accent, borderRadius: radius),
          child: SizedBox(height: height),
        ),
      ),
    );
    return Container(
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: .14),
        borderRadius: radius,
      ),
      child: reducedMotion(context)
          ? fill(target)
          : TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: target),
              duration: const Duration(milliseconds: 520),
              curve: Curves.easeOutCubic,
              builder: (_, t, _) => fill(t),
            ),
    );
  }
}

/// One number in a soft accent tile: the number counts up, the label says what
/// it is. Use for small «3 барнома баста», «2 дархост» summaries.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    this.unit,
    this.onTap,
  });

  final int value;
  final String label;
  final IconData icon;
  final Color color;

  /// Unit printed after the number («дақ», «соат»).
  final String? unit;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final number = reducedMotion(context)
        ? Text(
            '$value${unit == null ? '' : ' $unit'}',
            style: _numberStyle(color),
          )
        : TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value.toDouble()),
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutCubic,
            builder: (_, t, _) => Text(
              '${t.round()}${unit == null ? '' : ' $unit'}',
              style: _numberStyle(color),
            ),
          );
    final tile = Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          number,
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.25,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return tile;
    return TapScale(
      onTap: onTap,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: tile),
      ),
    );
  }

  /// Text style of the big number in a [StatTile].
  static TextStyle _numberStyle(Color color) => TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w800,
    height: 1.1,
    color: color,
  );
}
