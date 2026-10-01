import 'package:flutter/material.dart';

/// App icon from assets, with a plain shield if the asset is missing.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 72});
  final double size;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(size * .28),
    child: Image.asset(
      'assets/branding/nigoh_family_icon.png',
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Container(
        width: size,
        height: size,
        color: Theme.of(context).colorScheme.primary.withValues(alpha: .12),
        child: Icon(
          Icons.shield_rounded,
          size: size * .5,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    ),
  );
}
