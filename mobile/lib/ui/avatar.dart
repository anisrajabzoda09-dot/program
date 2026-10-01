import 'package:flutter/material.dart';

import 'nigoh_design.dart';

/// Round profile picture: the photo at [url] when there is one, otherwise
/// (and while it fails to load) the first letter of [name] on a soft accent.
///
/// Callers resolve a server path with `NigohApi.fileUrl(path)`.
class AvatarView extends StatelessWidget {
  const AvatarView({
    super.key,
    required this.name,
    this.url,
    this.size = 48,
    this.color,
    this.border,
  });

  final String name;
  final String? url;
  final double size;

  /// Accent for the letter fallback; defaults to one derived from [name].
  final Color? color;

  /// Optional ring (e.g. white on the map marker).
  final BoxBorder? border;

  static String letterOf(String name) {
    final trimmed = name.trim();
    return trimmed.isEmpty ? '?' : trimmed.characters.first.toUpperCase();
  }

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
    return Container(
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
              // Decode at display size: avatars are small.
              cacheWidth: (size * MediaQuery.devicePixelRatioOf(context))
                  .round(),
              // Letter until the first frame arrives (and on errors).
              frameBuilder: (_, child, frame, sync) =>
                  sync || frame != null ? child : letter,
              errorBuilder: (_, _, _) => letter,
            ),
    );
  }
}
