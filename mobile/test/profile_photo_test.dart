import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nigoh_family_parent/core/api.dart';
import 'package:nigoh_family_parent/core/session.dart';
import 'package:nigoh_family_parent/features/settings/profile_photo.dart';
import 'package:nigoh_family_parent/ui/avatar.dart';

class _Server {
  final requests = <http.Request>[];
  http.Response Function(http.Request r)? reply;

  late final api = NigohApi(
    client: MockClient((r) async {
      requests.add(r);
      return reply?.call(r) ??
          http.Response(
            jsonEncode({'avatar': '/static/avatars/u1.jpg'}),
            200,
            headers: {'content-type': 'application/json'},
          );
    }),
  );
}

Future<Session> _pump(
  WidgetTester tester,
  _Server server, {
  String? avatar,
}) async {
  final session = Session(api: server.api)
    ..user = {'full_name': 'Модар Каримова', 'avatar': ?avatar};
  await tester.pumpWidget(
    SessionScope(
      session: session,
      child: MaterialApp(
        home: Scaffold(
          body: Center(child: ProfileAvatarButton(session: session)),
        ),
      ),
    ),
  );
  return session;
}

Future<void> _choose(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(const ValueKey('profile-avatar')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

void main() {
  final jpeg = Uint8List.fromList(List.generate(2000, (i) => i % 256));
  ImageSource? pickedFrom;

  setUp(() {
    pickedFrom = null;
    ProfileAvatarButton.debugPicker = (source) async {
      pickedFrom = source;
      return jpeg;
    };
  });
  tearDown(() => ProfileAvatarButton.debugPicker = null);

  testWidgets('AvatarView shows the letter without a photo', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AvatarView(name: 'сино', size: 40)),
    );
    expect(find.text('С'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('AvatarView falls back to the letter while/if the photo fails', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AvatarView(name: 'Алӣ', url: 'https://x.invalid/a.jpg'),
      ),
    );
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('А'), findsOneWidget);
  });

  testWidgets('sheet offers gallery and camera; no delete without a photo', (
    tester,
  ) async {
    await _pump(tester, _Server());
    await tester.tap(find.byKey(const ValueKey('profile-avatar')));
    await tester.pumpAndSettle();
    expect(find.text('Аз галерея'), findsOneWidget);
    expect(find.text('Сурат гирифтан'), findsOneWidget);
    expect(find.text('Нест кардан'), findsNothing);
  });

  testWidgets('gallery photo is uploaded and the session updated', (
    tester,
  ) async {
    final server = _Server();
    final session = await _pump(tester, server);
    await _choose(tester, 'avatar-gallery');
    expect(pickedFrom, ImageSource.gallery);
    final post = server.requests.single;
    expect(post.method, 'POST');
    expect(post.url.path, '/api/mobile/v3/me/avatar');
    expect(jsonDecode(post.body)['image_base64'], base64Encode(jpeg));
    expect(session.avatar, '/static/avatars/u1.jpg');
    expect(find.text('Сурат нигоҳ дошта шуд.'), findsOneWidget);
    final view = tester.widget<AvatarView>(find.byType(AvatarView));
    expect(view.url, 'https://nigohfamily.qobus.tj/static/avatars/u1.jpg');
  });

  testWidgets('camera uses the camera source', (tester) async {
    await _pump(tester, _Server());
    await _choose(tester, 'avatar-camera');
    expect(pickedFrom, ImageSource.camera);
  });

  testWidgets('server error is shown and the avatar stays', (tester) async {
    final server = _Server()
      ..reply = (_) => http.Response(
        jsonEncode({'detail': 'Сурат хеле калон аст'}),
        413,
        headers: {'content-type': 'application/json'},
      );
    final session = await _pump(tester, server);
    await _choose(tester, 'avatar-gallery');
    expect(find.text('Сурат хеле калон аст'), findsOneWidget);
    expect(session.avatar, isNull);
  });

  testWidgets('too large picture is refused before uploading', (tester) async {
    ProfileAvatarButton.debugPicker = (_) async =>
        Uint8List(maxAvatarBytes + 1);
    final server = _Server();
    await _pump(tester, server);
    await _choose(tester, 'avatar-gallery');
    expect(server.requests, isEmpty);
    expect(find.textContaining('хеле калон'), findsOneWidget);
  });

  testWidgets('delete removes the photo', (tester) async {
    final server = _Server()..reply = (_) => http.Response('{}', 200);
    final session = await _pump(
      tester,
      server,
      avatar: '/static/avatars/u1.jpg',
    );
    await _choose(tester, 'avatar-delete');
    expect(server.requests.single.method, 'DELETE');
    expect(session.avatar, isNull);
    expect(find.text('Сурат нест карда шуд.'), findsOneWidget);
  });
}
