import 'package:flutter/material.dart';

/// Sun/moon theme switch — a Flutter port of the «Theme switch» by Galahhad
/// on Uiverse.io (MIT). Same proportions (5.625 × 2.5 em), colours and
/// motion: sun with clouds by day, moon with craters and stars by night.
class DayNightSwitch extends StatefulWidget {
  const DayNightSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.height = 34,
    this.semanticLabel,
  });

  /// true = dark (night).
  final bool value;
  final ValueChanged<bool> onChanged;
  final double height;
  final String? semanticLabel;

  @override
  State<DayNightSwitch> createState() => _DayNightSwitchState();
}

class _DayNightSwitchState extends State<DayNightSwitch>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
    value: widget.value ? 1 : 0,
  );

  @override
  void didUpdateWidget(DayNightSwitch old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      widget.value ? _c.forward() : _c.reverse();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final em = widget.height / 2.5;
    return Semantics(
      toggled: widget.value,
      label: widget.semanticLabel,
      button: true,
      child: GestureDetector(
        onTap: () => widget.onChanged(!widget.value),
        child: SizedBox(
          width: 5.625 * em,
          height: 2.5 * em,
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, _) => CustomPaint(
              painter: _DayNightPainter(
                // cubic-bezier(0, -0.02, 0.4, 1.25) from the original CSS
                t: const Cubic(0, -0.02, 0.4, 1.25).transform(_c.value),
                em: em,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DayNightPainter extends CustomPainter {
  _DayNightPainter({required this.t, required this.em});

  final double t; // 0 day … 1 night (may overshoot slightly)
  final double em;

  static const _dayBg = Color(0xFF3D7EAE);
  static const _nightBg = Color(0xFF1D1F2C);
  static const _sun = Color(0xFFECCA2F);
  static const _moon = Color(0xFFC4C9D1);
  static const _spot = Color(0xFF959DB1);
  static const _cloud = Color(0xFFF3FDFF);
  static const _backCloud = Color(0xFFAACADF);

  @override
  void paint(Canvas canvas, Size size) {
    final k = t.clamp(0.0, 1.0);
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.height / 2),
    );
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawRRect(rrect, Paint()..color = Color.lerp(_dayBg, _nightBg, k)!);

    // Stars slide in from the top at night.
    final starsDy = (-1 + t) * size.height * .9;
    final star = Paint()..color = Colors.white.withValues(alpha: k);
    for (final s in const [
      [0.12, 0.30, 0.10],
      [0.30, 0.62, 0.08],
      [0.46, 0.28, 0.07],
      [0.20, 0.78, 0.06],
      [0.38, 0.45, 0.05],
    ]) {
      _sparkle(
        canvas,
        Offset(size.width * s[0], size.height * s[1] + starsDy),
        em * s[2] * 4,
        star,
      );
    }

    // Clouds sink below the edge at night.
    final cloudsDy = t * 3.4 * em;
    final back = Paint()..color = _backCloud;
    final front = Paint()..color = _cloud;
    final baseY = size.height + .1 * em + cloudsDy;
    for (final c in const [
      [0.0, -0.31],
      [0.81, -0.12],
      [1.56, -0.06],
      [2.31, -0.31],
      [2.94, 0.0],
      [3.69, -0.44],
      [4.31, -0.62],
    ]) {
      canvas.drawCircle(
        Offset((.31 + c[0]) * em + .6 * em, baseY + (c[1] - .3) * em),
        .62 * em,
        back,
      );
    }
    for (final c in const [
      [0.0, 0.0],
      [0.94, 0.31],
      [1.44, 0.37],
      [2.19, 0.0],
      [2.94, 0.31],
      [3.62, -0.06],
      [4.5, -0.31],
    ]) {
      canvas.drawCircle(
        Offset((.31 + c[0]) * em + .6 * em, baseY + c[1] * em),
        .62 * em,
        front,
      );
    }

    // Halo rings + sun/moon travel from left to right.
    final d = 3.375 * em;
    final offset = (d - 2.5 * em) / 2;
    final startX = -offset + d / 2;
    final endX = size.width + offset - d / 2;
    final cx = startX + (endX - startX) * t;
    final center = Offset(cx, size.height / 2);
    final halo = Paint()..color = Colors.white.withValues(alpha: .1);
    for (final r in [d / 2 + 1.25 * em, d / 2 + .625 * em, d / 2]) {
      canvas.drawCircle(center, r, halo);
    }

    final r = 2.125 * em / 2;
    canvas.drawCircle(
      center.translate(.06 * em, .1 * em),
      r,
      Paint()
        ..color = Colors.black.withValues(alpha: .25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.save();
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: center, radius: r)),
    );
    canvas.drawCircle(center, r, Paint()..color = _sun);
    // The moon slides over the sun from the right.
    final moonCenter = center.translate((1 - t) * 2 * r, 0);
    canvas.drawCircle(moonCenter, r, Paint()..color = _moon);
    final spot = Paint()..color = _spot;
    final topLeft = moonCenter - Offset(r, r);
    canvas.drawCircle(
      topLeft + Offset(.312 * em + .375 * em, .75 * em + .375 * em),
      .375 * em,
      spot,
    );
    canvas.drawCircle(
      topLeft + Offset(1.375 * em + .1875 * em, .937 * em + .1875 * em),
      .1875 * em,
      spot,
    );
    canvas.drawCircle(
      topLeft + Offset(.812 * em + .125 * em, .312 * em + .125 * em),
      .125 * em,
      spot,
    );
    canvas.restore();

    canvas.restore();
    // Inner shadow of the track, like the original's ::before.
    canvas.drawRRect(
      rrect.deflate(.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.black.withValues(alpha: .18),
    );
  }

  void _sparkle(Canvas canvas, Offset c, double s, Paint p) {
    final path = Path()
      ..moveTo(c.dx, c.dy - s)
      ..quadraticBezierTo(c.dx, c.dy, c.dx + s, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + s)
      ..quadraticBezierTo(c.dx, c.dy, c.dx - s, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - s)
      ..close();
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_DayNightPainter old) => old.t != t || old.em != em;
}
