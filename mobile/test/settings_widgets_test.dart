import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nigoh_family_parent/ui/avatar.dart';
import 'package:nigoh_family_parent/ui/nigoh_design.dart';
import 'package:nigoh_family_parent/ui/stat_meter.dart';
import 'package:nigoh_family_parent/ui/theme.dart';
import 'package:nigoh_family_parent/ui/widgets.dart';

/// The shared building blocks in lib/ui/ — used by every screen, so they are
/// tested once here instead of in each feature's tests.
void main() {
  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    bool disableAnimations = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: NigohTheme.light(),
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: disableAnimations),
          child: Scaffold(body: Center(child: child)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('SectionTitle shows its one-line purpose text', (tester) async {
    await pump(
      tester,
      const SectionTitle('Амният', subtitle: 'PIN ва иҷозатҳо.'),
    );
    expect(find.text('Амният'), findsOneWidget);
    expect(find.text('PIN ва иҷозатҳо.'), findsOneWidget);
  });

  testWidgets('ScreenHint renders text with an optional icon', (tester) async {
    await pump(
      tester,
      const ScreenHint('Чӣ кор мекунад', icon: Icons.info_outline_rounded),
    );
    expect(find.text('Чӣ кор мекунад'), findsOneWidget);
    expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
  });

  testWidgets('Pill keeps its tooltip and grows when big', (tester) async {
    await pump(
      tester,
      const Pill(
        '45 дақ',
        color: NigohDesign.amber,
        icon: Icons.timer_outlined,
        tooltip: 'Имрӯз истифода шуд',
        big: true,
      ),
    );
    expect(find.text('45 дақ'), findsOneWidget);
    expect(find.byType(Tooltip), findsOneWidget);
    expect(tester.widget<Text>(find.text('45 дақ')).style?.fontSize, 13);
  });

  testWidgets('StateMessage can show a dominant primary action', (
    tester,
  ) async {
    var taps = 0;
    await pump(
      tester,
      StateMessage(
        icon: Icons.link_rounded,
        title: 'Ҳоло фарзанд нест',
        text: 'Телефони фарзандро пайваст кунед.',
        actionLabel: 'Пайваст кардан',
        actionIcon: Icons.add_rounded,
        primaryAction: true,
        color: NigohDesign.mint,
        onAction: () => taps++,
      ),
    );
    expect(find.text('Ҳоло фарзанд нест'), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    await tester.tap(find.text('Пайваст кардан'));
    expect(taps, 1);
  });

  testWidgets('StateMessage without primaryAction stays quiet', (tester) async {
    await pump(
      tester,
      StateMessage(
        icon: Icons.wifi_off_rounded,
        title: 'Интернет нест',
        actionLabel: 'Аз нав',
        onAction: () {},
      ),
    );
    expect(find.byType(OutlinedButton), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('FadeIn animates, and paints at once with reduced motion', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: FadeIn(child: Text('Салом'))),
    );
    await tester.pump();
    final opacity = tester.widget<Opacity>(find.byType(Opacity).first).opacity;
    expect(opacity, lessThan(1));
    await tester.pumpAndSettle();
    expect(tester.widget<Opacity>(find.byType(Opacity).first).opacity, 1);

    await pump(
      tester,
      const FadeIn(child: Text('Салом')),
      disableAnimations: true,
    );
    expect(find.byType(Opacity), findsNothing);
    expect(find.text('Салом'), findsOneWidget);
  });

  testWidgets('TapScale shrinks while held and calls back', (tester) async {
    await pump(tester, const TapScale(child: Text('Пахш')));
    expect(find.byType(AnimatedScale), findsOneWidget);
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Пахш')),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('AvatarView shows the letter fallback and an optional badge', (
    tester,
  ) async {
    await pump(
      tester,
      const AvatarView(
        name: 'Сомон',
        badge: AvatarDot(color: NigohDesign.mint),
      ),
    );
    expect(find.text('С'), findsOneWidget);
    expect(find.byType(AvatarDot), findsOneWidget);
  });

  testWidgets('StatMeter prints the number with its unit and clamps the bar', (
    tester,
  ) async {
    await pump(
      tester,
      const SizedBox(
        width: 300,
        child: StatMeter(
          label: 'Имрӯз',
          value: 45,
          max: 60,
          unit: 'дақ',
          color: NigohDesign.amber,
        ),
      ),
    );
    expect(find.text('45 дақ аз 60'), findsOneWidget);
    expect(find.byType(StatBar), findsOneWidget);
    expect(
      tester.widget<StatBar>(find.byType(StatBar)).fraction,
      closeTo(.75, .001),
    );

    // Over the limit and no limit at all are both safe.
    await pump(
      tester,
      const SizedBox(
        width: 300,
        child: StatMeter(label: 'Имрӯз', value: 90, max: 60, unit: 'дақ'),
      ),
    );
    expect(tester.widget<StatBar>(find.byType(StatBar)).fraction, 1);
    await pump(
      tester,
      const SizedBox(
        width: 300,
        child: StatMeter(label: 'Имрӯз', value: 10, max: 0),
      ),
    );
    expect(tester.widget<StatBar>(find.byType(StatBar)).fraction, 0);
    expect(find.text('10 аз 0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('StatTile counts up to its value and can be tapped', (
    tester,
  ) async {
    var taps = 0;
    await pump(
      tester,
      SizedBox(
        width: 160,
        child: StatTile(
          value: 3,
          label: 'Барномаи баста',
          icon: Icons.block_rounded,
          color: NigohDesign.coral,
          onTap: () => taps++,
        ),
      ),
    );
    expect(find.text('3'), findsOneWidget);
    await tester.tap(find.text('Барномаи баста'));
    expect(taps, 1);

    await pump(
      tester,
      const SizedBox(
        width: 160,
        child: StatTile(
          value: 45,
          label: 'Вақт',
          icon: Icons.timer_outlined,
          color: NigohDesign.amber,
          unit: 'дақ',
        ),
      ),
      disableAnimations: true,
    );
    expect(find.text('45 дақ'), findsOneWidget);
  });
}
