// Файл: нишондиҳандаҳои аниматсионии омор ва маҳдудият.

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import 'widgets.dart';

/// Додаҳо ва рафтори марбут ба нишондиҳандаҳои аниматсионии омор ва маҳдудиятро ифода мекунад.
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

  /// Қимати max-ро барои нишондиҳандаҳои аниматсионии омор ва маҳдудият нигоҳ медорад.
  final double max;

  /// Қимати unit-ро барои нишондиҳандаҳои аниматсионии омор ва маҳдудият нигоҳ медорад.
  final String? unit;
  final Color? color;

  /// Қимати valueText-ро барои нишондиҳандаҳои аниматсионии омор ва маҳдудият нигоҳ медорад.
  final String? valueText;
  final IconData? icon;

  /// Қимати compact-ро барои нишондиҳандаҳои аниматсионии омор ва маҳдудият нигоҳ медорад.
  final bool compact;

  /// Қимати ҳисобшудаи fraction-ро аз ҳолати ҷорӣ бармегардонад.
  double get fraction => max <= 0 ? 0 : (value / max).clamp(0.0, 1.0);

  /// number мантиқи зарурии нишондиҳандаҳои аниматсионии омор ва маҳдудиятро иҷро мекунад.
  String _number(double v) {
    final rounded = v.roundToDouble();
    return rounded == v ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
  }

  /// Widget-и StatMeter-ро барои нишондиҳандаҳои омор ва маҳдудият месозад.
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = color ?? scheme.primary;
    // Қадами дохилии нишондиҳандаҳои аниматсионии омор ва маҳдудият.
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

/// Додаҳо ва рафтори марбут ба нишондиҳандаҳои аниматсионии омор ва маҳдудиятро ифода мекунад.
class StatBar extends StatelessWidget {
  const StatBar({
    super.key,
    required this.fraction,
    this.color,
    this.height = 8,
  });

  /// Қимати fraction-ро барои нишондиҳандаҳои аниматсионии омор ва маҳдудият нигоҳ медорад.
  final double fraction;
  final Color? color;
  final double height;

  /// Widget-и StatBar-ро барои нишондиҳандаҳои омор ва маҳдудият месозад.
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = color ?? scheme.primary;
    final target = fraction.clamp(0.0, 1.0);
    final radius = BorderRadius.circular(height);
    /// fill мантиқи зарурии нишондиҳандаҳои аниматсионии омор ва маҳдудиятро иҷро мекунад.
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

/// Widget-и StatTile-ро барои нишондиҳандаҳои аниматсионии омор ва маҳдудият месозад.
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

  /// Қимати unit-ро барои нишондиҳандаҳои аниматсионии омор ва маҳдудият нигоҳ медорад.
  final String? unit;
  final VoidCallback? onTap;

  /// Widget-и StatTile-ро барои нишондиҳандаҳои омор ва маҳдудият месозад.
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

  /// numberStyle мантиқи зарурии нишондиҳандаҳои аниматсионии омор ва маҳдудиятро иҷро мекунад.
  static TextStyle _numberStyle(Color color) => TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w800,
    height: 1.1,
    color: color,
  );
}
