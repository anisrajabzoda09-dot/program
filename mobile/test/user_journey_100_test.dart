import 'package:flutter_test/flutter_test.dart';

import 'package:nigoh_family_parent/core/user_journey_logic.dart';

void main() {
  group('NIGOH user journey: 100-point regression suite', () {
    final pairingCases = <(String, String)>[
      ('123456', '123456'),
      ('nigoh://pair/123456', '123456'),
      ('https://nigohfamily.qobus.tj/pair/654321', '654321'),
      ('  100001  ', '100001'),
      ('PAIR-909090', '909090'),
      ('код: 222333', '222333'),
      ('000000', '000000'),
      ('nigoh://pair/987654?source=qr', '987654'),
      ('12345', ''),
      ('1234567', ''),
    ];
    for (var i = 0; i < pairingCases.length; i++) {
      test('point ${i + 1}: pairing input ${i + 1}', () {
        expect(
          UserJourneyLogic.pairingCode(pairingCases[i].$1),
          pairingCases[i].$2,
        );
      });
    }

    final versionCases = <(int, int, bool)>[
      (34, 34, false),
      (35, 34, true),
      (34, 35, false),
      (1, 0, true),
      (0, 0, false),
      (100, 99, true),
      (99, 100, false),
      (24, 24, false),
      (25, 24, true),
      (24, 25, false),
    ];
    for (var i = 0; i < versionCases.length; i++) {
      test('point ${i + 11}: version update decision ${i + 1}', () {
        expect(
          UserJourneyLogic.shouldOfferUpdate(
            versionCases[i].$1,
            versionCases[i].$2,
          ),
          versionCases[i].$3,
        );
      });
    }

    final scheduleCases = <(DateTime, String, String, List<int>, bool)>[
      (DateTime(2026, 9, 28, 16, 0), '16:00', '18:00', [1, 2, 3, 4, 5], true),
      (DateTime(2026, 9, 28, 17, 59), '16:00', '18:00', [1], true),
      (DateTime(2026, 9, 28, 18, 0), '16:00', '18:00', [1], false),
      (DateTime(2026, 9, 27, 17, 0), '16:00', '18:00', [1, 2, 3, 4, 5], false),
      (DateTime(2026, 9, 29, 17, 0), '16:00', '18:00', [2], true),
      (DateTime(2026, 9, 29, 17, 0), '16:00', '18:00', [1], false),
      (DateTime(2026, 9, 28, 15, 59), '16:00', '18:00', [1], false),
      (DateTime(2026, 9, 28, 16, 1), '16:00', '18:00', [1], true),
      (DateTime(2026, 9, 28, 23, 0), '22:00', '01:00', [1], true),
      (DateTime(2026, 9, 29, 0, 30), '22:00', '01:00', [1], true),
      (DateTime(2026, 9, 29, 1, 0), '22:00', '01:00', [1], false),
      (DateTime(2026, 9, 29, 0, 30), '22:00', '01:00', [2], false),
      (DateTime(2026, 10, 2, 23, 0), '22:00', '01:00', [5], true),
      (DateTime(2026, 10, 3, 0, 30), '22:00', '01:00', [5], true),
      (DateTime(2026, 9, 28, 0, 30), '22:00', '01:00', [6], false),
      (DateTime(2026, 9, 28, 16, 0), 'bad', '18:00', [1], false),
      (DateTime(2026, 9, 28, 16, 0), '16:70', '18:00', [1], false),
      (DateTime(2026, 9, 28, 16, 0), '16:00', '18:00', [], false),
      (DateTime(2026, 9, 28, 16, 0), '16:00', '18:00', [1], false),
      (DateTime(2026, 9, 28, 16, 0), '16:00', '18:00', [1], false),
    ];
    for (var i = 0; i < scheduleCases.length; i++) {
      test('point ${i + 21}: schedule decision ${i + 1}', () {
        final item = scheduleCases[i];
        expect(
          UserJourneyLogic.scheduleActive(
            now: item.$1,
            start: item.$2,
            end: item.$3,
            weekdays: item.$4,
            enabled: i != 18 && i != 19,
          ),
          item.$5,
        );
      });
    }

    final limitCases = <(int, String, int, double)>[
      (0, 'Бе лимит', 5, 0),
      (15, '15д', 0, 0),
      (30, '30д', 0, 1),
      (59, '59д', 1, 1),
      (60, '1с', 1, .5),
      (90, '1с 30д', 2, .5),
      (120, '2с', 3, .5),
      (240, '4с', 4, .5),
      (10, '10д', 0, 1),
      (300, '5с', 4, 1),
      (15, '15д', 0, .25),
      (45, '45д', 1, .75),
      (60, '1с', 1, 0),
      (90, '1с 30д', 2, 1),
      (120, '2с', 3, .25),
      (240, '4с', 4, .25),
      (0, 'Бе лимит', 5, 0),
      (-1, 'Бе лимит', 5, 0),
      (61, '1с 1д', 1, .5),
      (180, '3с', 3, .5),
    ];
    for (var i = 0; i < limitCases.length; i++) {
      test('point ${i + 41}: usage limit ${i + 1}', () {
        final item = limitCases[i];
        expect(UserJourneyLogic.limitLabel(item.$1), item.$2);
        expect(UserJourneyLogic.nearestLimitIndex(item.$1), item.$3);
        expect(
          UserJourneyLogic.usageProgress(item.$1, item.$1),
          item.$1 <= 0 ? 0 : 1,
        );
      });
    }

    final appCases = <(Map<String, dynamic>, String, String, bool)>[
      ({'name': 'Duolingo', 'packageName': 'com.duolingo'}, 'Маориф', '', true),
      (
        {'name': 'Khan Academy', 'packageName': 'org.khan'},
        'Маориф',
        'khan',
        true,
      ),
      ({'name': 'Roblox', 'packageName': 'com.roblox'}, 'Бозиҳо', '', true),
      (
        {'name': 'Minecraft', 'packageName': 'game.minecraft'},
        'Бозиҳо',
        'mine',
        true,
      ),
      (
        {'name': 'Telegram', 'packageName': 'org.telegram'},
        'Шабакаҳо',
        '',
        true,
      ),
      (
        {'name': 'WhatsApp', 'packageName': 'com.whatsapp'},
        'Шабакаҳо',
        'what',
        true,
      ),
      ({'name': 'YouTube', 'packageName': 'com.youtube'}, 'Ҳама', 'zzz', false),
      (
        {'name': 'School App', 'packageName': 'com.school'},
        'Маориф',
        'school',
        true,
      ),
      (
        {'name': 'PUBG Mobile', 'packageName': 'com.pubg'},
        'Бозиҳо',
        'pubg',
        true,
      ),
      (
        {'name': 'Instagram', 'packageName': 'com.instagram'},
        'Шабакаҳо',
        '',
        true,
      ),
      ({'name': 'Calendar', 'packageName': 'com.calendar'}, 'Ҳама', '', true),
      (
        {'name': 'Facebook', 'packageName': 'com.facebook'},
        'Шабакаҳо',
        'face',
        true,
      ),
      (
        {'name': 'Learning', 'packageName': 'com.learning'},
        'Маориф',
        'learn',
        true,
      ),
      ({'name': 'Photos', 'packageName': 'com.photos'}, 'Ҳама', 'photos', true),
      (
        {'name': 'Telegram', 'packageName': 'org.telegram'},
        'Шабакаҳо',
        'discord',
        false,
      ),
    ];
    for (var i = 0; i < appCases.length; i++) {
      test('point ${i + 61}: app list filter ${i + 1}', () {
        final item = appCases[i];
        expect(UserJourneyLogic.appCategory(item.$1), item.$2);
        expect(
          UserJourneyLogic.appMatches(
            item.$1,
            query: item.$3,
            category: item.$2,
          ),
          item.$4,
        );
      });
    }

    final chatCases =
        <(List<Map<String, dynamic>>, List<Map<String, dynamic>>, int)>[
          (
            [
              {'id': 1, 'text': 'a', 'createdAt': 1},
            ],
            [],
            1,
          ),
          (
            [],
            [
              {'id': 2, 'content': 'b', 'created_at': 2},
            ],
            1,
          ),
          (
            [
              {'id': 1, 'text': 'a', 'createdAt': 1},
            ],
            [
              {'id': 1, 'content': 'a', 'created_at': 1},
            ],
            1,
          ),
          (
            [
              {'id': 1, 'text': 'a', 'createdAt': 2},
            ],
            [
              {'id': 2, 'content': 'b', 'created_at': 1},
            ],
            2,
          ),
          (
            [
              {'senderUid': 'u', 'text': 'a', 'createdAt': 1},
            ],
            [
              {'senderUid': 'u', 'text': 'a', 'createdAt': 1},
            ],
            1,
          ),
          (
            [
              {'senderUid': 'u', 'text': 'a', 'createdAt': 1},
            ],
            [
              {'senderUid': 'u', 'text': 'b', 'createdAt': 1},
            ],
            2,
          ),
          (
            [
              {'senderUid': 'u', 'text': 'a', 'createdAt': 1},
            ],
            [
              {'senderUid': 'v', 'text': 'a', 'createdAt': 1},
            ],
            2,
          ),
          (
            [
              {'id': 4, 'text': 'old', 'createdAt': 4},
            ],
            [
              {'id': 3, 'content': 'new', 'created_at': 3},
            ],
            2,
          ),
          ([], [], 0),
          (
            [
              {'id': 1, 'text': 'x', 'createdAt': '2026-01-01T00:00:00Z'},
            ],
            [],
            1,
          ),
          (
            [
              {'id': 1, 'text': 'x', 'createdAt': 1},
            ],
            [
              {'id': 2, 'content': 'y', 'created_at': 'bad'},
            ],
            2,
          ),
          (
            [
              {'id': 1, 'text': 'x', 'createdAt': 1},
            ],
            [
              {'id': 2, 'content': 'y', 'created_at': 2},
            ],
            2,
          ),
          (
            [
              {'id': 1, 'text': 'x', 'createdAt': 1},
            ],
            [
              {'id': 2, 'content': 'y', 'created_at': 2},
              {'id': 3, 'content': 'z', 'created_at': 3},
            ],
            3,
          ),
          (
            [
              {'id': 1, 'text': 'x', 'createdAt': 1},
            ],
            [
              {'id': 1, 'content': 'different', 'created_at': 2},
            ],
            1,
          ),
          (
            [
              {'senderRole': 'parent', 'content': 'hi', 'createdAt': 1},
            ],
            [
              {'senderRole': 'parent', 'content': 'hi', 'created_at': 1},
            ],
            1,
          ),
        ];
    for (var i = 0; i < chatCases.length; i++) {
      test('point ${i + 76}: chat merge ${i + 1}', () {
        final item = chatCases[i];
        final result = UserJourneyLogic.mergeMessages(item.$1, item.$2);
        expect(result.length, item.$3);
        for (var j = 1; j < result.length; j++) {
          expect(result[j - 1]['id'] ?? result[j - 1]['createdAt'], isNotNull);
        }
      });
    }

    final securityCases = <(Map<String, dynamic>, bool)>[
      ({'usage': true, 'overlay': true, 'accessibility': true}, true),
      ({'usage': false, 'overlay': true, 'accessibility': true}, false),
      ({'usage': true, 'overlay': false, 'accessibility': true}, false),
      ({'usage': true, 'overlay': true, 'accessibility': false}, false),
      ({'usage': true, 'overlay': true}, false),
      ({}, false),
      ({'usage': 1, 'overlay': true, 'accessibility': true}, false),
      (
        {'usage': true, 'overlay': true, 'accessibility': true, 'gps': false},
        true,
      ),
      (
        {
          'usage': true,
          'overlay': true,
          'accessibility': true,
          'deviceAdmin': false,
        },
        true,
      ),
      (
        {
          'usage': true,
          'overlay': true,
          'accessibility': true,
          'camera': false,
        },
        true,
      ),
    ];
    for (var i = 0; i < securityCases.length; i++) {
      test('point ${i + 91}: protection readiness ${i + 1}', () {
        expect(
          UserJourneyLogic.protectionReady(securityCases[i].$1),
          securityCases[i].$2,
        );
        expect(UserJourneyLogic.validPin('1234'), isTrue);
        expect(UserJourneyLogic.validPin('123'), isFalse);
        expect(UserJourneyLogic.validPin('12345'), isFalse);
      });
    }
  });
}
