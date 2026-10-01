import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nigoh_family_parent/main.dart';

void main() {
  testWidgets('renders the NIGOH brand mark', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: BrandMark())),
    );
    expect(find.byType(Image), findsOneWidget);
  });
}
