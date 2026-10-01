import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nigoh_family_parent/core/api.dart';
import 'package:nigoh_family_parent/core/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response json(Object body, [int status = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: {'content-type': 'application/json'},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('login stores the token and user name', () async {
    final requests = <http.Request>[];
    final session = Session(
      api: NigohApi(
        client: MockClient((request) async {
          requests.add(request);
          return json({
            'token': 'ngh_abc',
            'user': {'full_name': 'Модар', 'email': 'a@b.tj'},
          });
        }),
      ),
    );
    await session.load();
    expect(session.signedIn, isFalse);

    await session.login(' a@b.tj ', 'secret123');

    expect(session.signedIn, isTrue);
    expect(session.displayName, 'Модар');
    expect(session.email, 'a@b.tj');
    expect(jsonDecode(requests.single.body)['email'], 'a@b.tj');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('nigoh.token'), 'ngh_abc');
  });

  test('login error keeps the server detail', () async {
    final session = Session(
      api: NigohApi(
        client: MockClient(
          (_) async => json({'detail': 'Почта ё рамз нодуруст аст.'}, 401),
        ),
      ),
    );
    await session.load();
    await expectLater(
      session.login('a@b.tj', 'secret123'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          'Почта ё рамз нодуруст аст.',
        ),
      ),
    );
    expect(session.signedIn, isFalse);
  });

  test('401 on an authenticated call signs the user out', () async {
    SharedPreferences.setMockInitialValues({
      'nigoh.token': 'ngh_old',
      'nigoh.role': 'parent',
      'nigoh.user': 'Падар',
    });
    final session = Session(
      api: NigohApi(
        client: MockClient((_) async => json({'detail': 'expired'}, 401)),
      ),
    );
    await session.load();
    expect(session.signedIn, isTrue);
    expect(session.isParent, isTrue);

    await expectLater(session.api.snapshot(), throwsA(isA<ApiException>()));
    await pumpEventQueue();

    expect(session.signedIn, isFalse);
    expect(session.role, isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('nigoh.token'), isNull);
    expect(prefs.getString('nigoh.role'), isNull);
  });

  test('chosen role is persisted and sent as a header', () async {
    final roles = <String?>[];
    NigohApi api() => NigohApi(
      client: MockClient((request) async {
        roles.add(request.headers['X-NIGOH-Role']);
        return json({
          'token': 'ngh_abc',
          'user': {'full_name': 'Али'},
        });
      }),
    );
    final first = Session(api: api());
    await first.load();
    await first.login('a@b.tj', 'secret123');
    await first.chooseRole('child');
    expect(first.isChild, isTrue);
    expect(roles.last, 'child');

    final second = Session(api: api());
    await second.load();
    expect(second.signedIn, isTrue);
    expect(second.role, 'child');
    expect(second.displayName, 'Али');
  });
}
