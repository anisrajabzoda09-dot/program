import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nigoh_family_parent/features/auth/brand_logo.dart';

void main() {
  testWidgets('renders the NIGOH brand logo', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: BrandLogo())),
    );
    expect(find.byType(Image), findsOneWidget);
  });
}
