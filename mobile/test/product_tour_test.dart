import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nigoh_family_parent/features/onboarding/product_tour_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('new user sees all five lessons and completion is saved', (
    tester,
  ) async {
    var completed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: ProductTourScreen(
          identity: 'user-42',
          onDone: () async => completed = true,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Оилаатон — дар як нигоҳ'), findsOneWidget);
    expect(find.byKey(const ValueKey('tour-progress')), findsOneWidget);
    expect(find.text('1/5'), findsOneWidget);

    for (var page = 2; page <= 5; page++) {
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('tour-next')))
          .onPressed!();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('$page/5'), findsOneWidget);
    }

    expect(find.text('NIGOH AI — ёрдамчии шумо'), findsOneWidget);
    expect(find.text('Оғоз мекунем'), findsOneWidget);
    tester
        .widget<FilledButton>(find.byKey(const ValueKey('tour-next')))
        .onPressed!();
    await tester.pump();

    expect(completed, isTrue);
    expect(await ProductTourScreen.isDone('user-42'), isTrue);
  });

  testWidgets('skip completes the tour without visiting demo pages', (
    tester,
  ) async {
    var completed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: ProductTourScreen(
          identity: 'user-7',
          onDone: () async => completed = true,
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('tour-skip')));
    await tester.pump();

    expect(completed, isTrue);
    expect(await ProductTourScreen.isDone('user-7'), isTrue);
  });
}
