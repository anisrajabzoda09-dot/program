// Файл: avatar ва нишондиҳандаи online.

import 'package:flutter/material.dart';

import 'nigoh_design.dart';

/// Widget-и AvatarView-ро барои avatar ва нишондиҳандаи online месозад.
class AvatarView extends StatelessWidget {
  const AvatarView({
    super.key,
    required this.name,
    this.url,
    this.size = 48,
    this.color,
    this.border,
    this.badge,
  });

  final String name;
  final String? url;
  final double size;

  /// Қимати color-ро барои avatar ва нишондиҳандаи online нигоҳ медорад.
  final Color? color;

  /// Қимати border-ро барои avatar ва нишондиҳандаи online нигоҳ медорад.
  final BoxBorder? border;

  /// Қимати badge-ро барои avatar ва нишондиҳандаи online нигоҳ медорад.
  final Widget? badge;

  /// letterOf мантиқи зарурии avatar ва нишондиҳандаи online-ро иҷро мекунад.
  static String letterOf(String name) {
    final trimmed = name.trim();
    return trimmed.isEmpty ? '?' : trimmed.characters.first.toUpperCase();
  }

  /// Widget-и AvatarView-ро барои аватар ва ҳолати он месозад.
  @override
  Widget build(BuildContext context) {
    final accent = color ?? NigohDesign.accentFor(name);
    final letter = Center(
      child: Text(
        letterOf(name),
        style: TextStyle(
          color: accent,
          fontSize: size * .42,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
    final image = url;
    final circle = Container(
      key: const ValueKey('avatar'),
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          accent.withValues(alpha: .14),
          Theme.of(context).colorScheme.surface,
        ),
        shape: BoxShape.circle,
        border: border,
      ),
      child: image == null || image.isEmpty
          ? letter
          : Image.network(
              image,
              key: ValueKey(image),
              width: size,
              height: size,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              // Додаҳо ба шакли бехатар табдил ва санҷида мешаванд.
              cacheWidth: (size * MediaQuery.devicePixelRatioOf(context))
                  .round(),
              // Қадами дохилии avatar ва нишондиҳандаи online.
              frameBuilder: (_, child, frame, sync) =>
                  sync || frame != null ? child : letter,
              errorBuilder: (_, _, _) => letter,
            ),
    );
    final mark = badge;
    if (mark == null) return circle;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          circle,
          Positioned(right: -1, bottom: -1, child: mark),
        ],
      ),
    );
  }
}

/// Додаҳо ва рафтори марбут ба avatar ва нишондиҳандаи online-ро ифода мекунад.
class AvatarDot extends StatelessWidget {
  const AvatarDot({super.key, required this.color, this.size = 13});
  final Color color;
  final double size;

  /// Widget-и AvatarDot-ро барои аватар ва ҳолати он месозад.
  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 240),
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(
        color: Theme.of(context).colorScheme.surface,
        width: size * .16,
      ),
    ),
  );
}
