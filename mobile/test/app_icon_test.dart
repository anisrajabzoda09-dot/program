import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nigoh_family_parent/ui/nigoh_design.dart';

void main() {
  Future<void> pump(WidgetTester tester, String icon) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: NigohAppIcon(icon: icon, seed: 'com.example.app'),
      ),
    ),
  );

  testWidgets('emoji placeholder from the server does not throw', (
    tester,
  ) async {
    await pump(tester, '🎵');
    expect(tester.takeException(), isNull);
    expect(find.text('🎵'), findsOneWidget);
  });

  testWidgets('invalid base64 falls back to an icon', (tester) async {
    await pump(tester, 'this is definitely not base64 !!!');
    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.apps_rounded), findsOneWidget);
  });

  test('accent colour is stable per package', () {
    expect(
      NigohDesign.accentFor('com.whatsapp'),
      NigohDesign.accentFor('com.whatsapp'),
    );
  });
}
