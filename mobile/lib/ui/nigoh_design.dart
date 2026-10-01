import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Shared visual language for the NIGOH Family experience.
///
/// The components are intentionally brand-owned: they follow familiar family
/// safety patterns without copying third-party artwork or layouts.
abstract final class NigohDesign {
  static const navy = Color(0xFF111827);
  static const blue = Color(0xFF2563EB);
  static const sky = Color(0xFF38A5FF);
  static const mint = Color(0xFF19B88A);
  static const coral = Color(0xFFEF5350);
  static const amber = Color(0xFFFFB020);
  static const violet = Color(0xFF7C5CFF);
  static const pink = Color(0xFFEC4899);

  /// Soft accent palette used to give each app a stable, gentle colour.
  static const accents = <Color>[blue, mint, violet, amber, pink, sky, coral];

  static Color accentFor(String seed) {
    var hash = 0;
    for (final unit in seed.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return accents[hash % accents.length];
  }

  static const heroGradient = LinearGradient(
    colors: [Colors.white, Colors.white],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class NigohHeroCard extends StatelessWidget {
  const NigohHeroCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.badge,
    this.footer,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String? badge;
  final Widget? footer;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (badge != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary
                            .withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary
                              .withValues(alpha: .16),
                        ),
                      ),
                      child: Text(
                        badge!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    title,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 22,
                      height: 1.12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface
                          .withValues(alpha: .65),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary
                    .withValues(alpha: .08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary
                      .withValues(alpha: .16),
                ),
              ),
              child: Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
                size: 28,
              ),
            ),
          ],
        ),
        if (footer != null) ...[const SizedBox(height: 18), footer!],
      ],
    ),
  );
}

class NigohSectionHeader extends StatelessWidget {
  const NigohSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -.3),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 3),
              Text(
                subtitle!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface
                      .withValues(alpha: .62),
                  fontSize: 12.5,
                ),
              ),
            ],
          ],
        ),
      ),
      ?trailing,
    ],
  );
}

class NigohActionCard extends StatelessWidget {
  const NigohActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: scheme.onSurface.withValues(alpha: .36),
                    size: 19,
                  ),
                ],
              ),
              const Spacer(),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: scheme.onSurface.withValues(alpha: .60),
                  fontSize: 11.5,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NigohStatusPill extends StatelessWidget {
  const NigohStatusPill({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    this.onDark = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool onDark;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: onDark ? const Color(0xFFEFF6FF) : color.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(
        color: onDark ? const Color(0xFFDBEAFE) : color.withValues(alpha: .18),
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: onDark ? NigohDesign.blue : color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: onDark ? NigohDesign.blue : color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

/// App icon that never throws: invalid or non-base64 icons (for example the
/// emoji placeholders stored by the server) fall back to text or an icon.
class NigohAppIcon extends StatelessWidget {
  const NigohAppIcon({
    super.key,
    required this.icon,
    required this.seed,
    this.size = 44,
    this.locked = false,
  });

  final String icon;
  final String seed;
  final double size;
  final bool locked;

  static final Map<String, Uint8List?> _cache = <String, Uint8List?>{};

  static Uint8List? decode(String raw) {
    if (raw.length < 16) return null;
    return _cache.putIfAbsent(raw, () {
      try {
        final bytes = base64Decode(raw);
        return bytes.isEmpty ? null : bytes;
      } catch (_) {
        return null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final accent = locked ? NigohDesign.coral : NigohDesign.accentFor(seed);
    final bytes = decode(icon);
    final fallback = icon.isNotEmpty && icon.runes.length <= 4 && bytes == null
        ? Text(icon, style: TextStyle(fontSize: size * .46))
        : Icon(
            locked ? Icons.lock_rounded : Icons.apps_rounded,
            color: accent,
            size: size * .5,
          );
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * .14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(size * .3),
        border: Border.all(color: accent.withValues(alpha: .22)),
      ),
      alignment: Alignment.center,
      child: bytes == null
          ? fallback
          : ClipRRect(
              borderRadius: BorderRadius.circular(size * .2),
              child: Image.memory(
                bytes,
                gaplessPlayback: true,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => fallback,
              ),
            ),
    );
  }
}
