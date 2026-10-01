import 'package:flutter/material.dart';

import 'nigoh_design.dart';

/// App theme matching nigohfamily.qobus.tj: quiet neutral surfaces, one
/// brand blue, soft accents from [NigohDesign]. Light and dark.
abstract final class NigohTheme {
  static const ink = Color(0xFF0B1220);
  static const muted = Color(0xFF5D6676);
  static const line = Color(0xFFE6E8EC);
  static const soft = Color(0xFFF6F7F9);
  static const blue = Color(0xFF1F63E0);

  static ThemeData light() => _build(
    ColorScheme.fromSeed(
      seedColor: blue,
      primary: blue,
      surface: Colors.white,
      onSurface: ink,
      error: NigohDesign.coral,
    ).copyWith(
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: soft,
      surfaceContainer: soft,
      outlineVariant: line,
      onSurfaceVariant: muted,
    ),
    scaffold: soft,
  );

  static ThemeData dark() => _build(
    ColorScheme.fromSeed(
      seedColor: blue,
      brightness: Brightness.dark,
      primary: const Color(0xFF7FA8FF),
      surface: const Color(0xFF151A23),
      error: const Color(0xFFFF8A80),
    ).copyWith(
      surfaceContainerLowest: const Color(0xFF0E1218),
      surfaceContainerLow: const Color(0xFF11161E),
      outlineVariant: const Color(0xFF262D3A),
    ),
    scaffold: const Color(0xFF0E1218),
  );

  static ThemeData _build(ColorScheme scheme, {required Color scaffold}) {
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    final radius = BorderRadius.circular(16);
    return base.copyWith(
      scaffoldBackgroundColor: scaffold,
      textTheme: base.textTheme.apply(
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scaffold,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: radius),
          side: BorderSide(color: scheme.outlineVariant),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primary.withValues(alpha: .12),
        elevation: 0,
        height: 68,
        // Five tabs on a 360 dp phone leave ~72 dp per label («Барномаҳо»).
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            letterSpacing: -.1,
            color: scheme.onSurface,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {TargetPlatform.android: FadeForwardsPageTransitionsBuilder()},
      ),
    );
  }
}
