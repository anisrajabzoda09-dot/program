import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nigoh_family_parent/features/settings/app_update.dart';

void main() {
  test('progress events map to Tajik labels', () {
    expect(UpdateProgress.fromEvent({'state': 'downloading', 'progress': .42}).label, 'Боргирӣ… 42%');
    expect(UpdateProgress.fromEvent({'state': 'verifying'}).label, 'Санҷиши имзо…');
    expect(UpdateProgress.fromEvent({'state': 'error', 'message': 'Имзо мувофиқ нест'}).label, 'Имзо мувофиқ нест');
    expect(UpdateProgress.fromEvent('garbage').state, 'error');
  });

  testWidgets('dialog follows download → error and allows closing', (tester) async {
    final events = StreamController<UpdateProgress>.broadcast();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: UpdateProgressDialog(version: '2.12.0', events: events.stream)),
    ));
    expect(find.text('Навсозӣ то 2.12.0'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('Пӯшидан'), findsNothing);

    events.add(const UpdateProgress('downloading', progress: .5));
    await tester.pump();
    await tester.pump();
    expect(find.text('Боргирӣ… 50%'), findsOneWidget);

    events.add(const UpdateProgress('error', message: 'Интернет нест'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Интернет нест'), findsOneWidget);
    expect(find.text('Пӯшидан'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    await events.close();
  });
}
