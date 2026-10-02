import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nigoh_family_parent/ui/day_night_switch.dart';

void main() {
  testWidgets('day/night switch toggles and animates', (tester) async {
    var dark = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: StatefulBuilder(
            builder: (_, setState) => DayNightSwitch(
              value: dark,
              onChanged: (v) => setState(() => dark = v),
            ),
          ),
        ),
      ),
    ));
    final size = tester.getSize(find.byType(DayNightSwitch));
    expect(size.width / size.height, closeTo(5.625 / 2.5, .01));
    await tester.tap(find.byType(DayNightSwitch));
    await tester.pumpAndSettle();
    expect(dark, isTrue);
    await tester.tap(find.byType(DayNightSwitch));
    await tester.pumpAndSettle();
    expect(dark, isFalse);
  });
}
