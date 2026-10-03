import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:nigoh_family_parent/core/session.dart';
import 'package:nigoh_family_parent/features/parent/family_controller.dart';
import 'package:nigoh_family_parent/features/parent/places_sheets.dart';
import 'package:nigoh_family_parent/ui/theme.dart';

import 'parent_features_test.dart' show FakeServer, richSnapshot;

/// The add-safe-place sheet opens with the keyboard up (the name field is
/// autofocused). On a small phone that used to overflow and push the save
/// button off-screen; it must scroll instead.
void main() {
  Future<void> pumpSheet(
    WidgetTester tester, {
    required Size size,
    double keyboard = 0,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
    addTearDown(tester.view.reset);

    final server = FakeServer(richSnapshot());
    final c = FamilyController(server.api, pollInterval: null);
    addTearDown(c.dispose);
    await tester.runAsync(c.refresh);

    await tester.pumpWidget(
      SessionScope(
        session: Session(api: server.api),
        child: MaterialApp(
          theme: NigohTheme.light(),
          home: Scaffold(
            body: AddPlaceSheet(
              controller: c,
              child: c.selected!,
              tapped: const LatLng(38.56, 68.78),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final (label, size, keyboard) in [
    ('360x640 with keyboard', const Size(360, 640), 300.0),
    ('320x568 with keyboard', const Size(320, 568), 280.0),
    ('360x780 no keyboard', const Size(360, 780), 0.0),
    ('1280x800 desktop', const Size(1280, 800), 0.0),
  ]) {
    testWidgets('add-place sheet fits and saves: $label', (tester) async {
      await pumpSheet(tester, size: size, keyboard: keyboard);
      expect(tester.takeException(), isNull, reason: 'layout overflow');

      // The save button must be reachable (scroll to it if needed).
      final save = find.byKey(const ValueKey('place-save'));
      expect(save, findsOneWidget);
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      expect(save.hitTestable(), findsOneWidget);
    });
  }
}
