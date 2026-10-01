import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:nigoh_family_parent/core/api.dart';
import 'package:nigoh_family_parent/core/models.dart';

void main() {
  test('client against local server', () async {
    final s = Random().nextInt(1 << 30).toRadixString(16);
    final parent = NigohApi(baseUrl: 'http://127.0.0.1:8765')..role = 'parent';
    final child = NigohApi(baseUrl: 'http://127.0.0.1:8765')..role = 'child';
    parent.token = (await parent.register('qa_e2e_p$s@example.com', 'parentpass1', 'Падар'))['token'];
    child.token = (await child.register('qa_e2e_c$s@example.com', 'childpass1', 'Али'))['token'];
    expect((await child.snapshot())['child'], isNull);
    final code = await child.createPairCode(childName: 'Али', gender: 'boy', age: 11);
    final cid = code['child_id'] as int;
    await parent.pair(code['pairing_code'] as String);
    await child.syncApps(cid, [{'package_name': 'com.whatsapp', 'app_name': 'WhatsApp', 'usage_minutes': 9}]);
    final kids = ((await parent.snapshot())['children'] as List).map((e) => FamilyChild.fromJson(Map<String, dynamic>.from(e))).toList();
    final kid = kids.firstWhere((k) => k.id == cid);
    expect(kid.apps.single.name, 'WhatsApp');
    expect(kid.apps.single.usageMinutesToday, 9);
    await parent.updateRule(cid, 'com.whatsapp', {'is_blocked': true, 'schedule': const AppSchedule(enabled: true).toJson()});
    final mine = FamilyChild.fromJson(Map<String, dynamic>.from((await child.snapshot())['child']));
    expect(mine.apps.single.blocked, isTrue);
    expect(mine.apps.single.schedule.enabled, isTrue);
    expect(mine.parentName, 'Падар');
    await parent.sendChat(cid, 'Салом');
    await child.sendChat(cid, 'Занг', messageType: 'call');
    final msgs = (await parent.chat(cid)).map(ChatMessage.fromJson).toList();
    expect(msgs.map((m) => m.type), ['text', 'call']);
    expect((await parent.chat(cid, afterId: msgs.last.id)), isEmpty);
    await child.syncLocation(cid, {'latitude': 38.5, 'longitude': 68.7, 'is_online': true});
    final withLoc = FamilyChild.fromJson(Map<String, dynamic>.from(((await parent.snapshot())['children'] as List).firstWhere((e) => e['id'] == cid)));
    expect(withLoc.online, isTrue, reason: 'location updated_at must parse as recent');
    try { await child.unlinkChild(cid); fail('child unlinked'); } on ApiException catch (e) { expect(e.statusCode, 403); }
    await parent.unlinkChild(cid);
    await child.logout();
    try { await child.snapshot(); fail('token still valid'); } on ApiException catch (e) { expect(e.unauthorized, isTrue); }
    try { await parent.login('qa_e2e_p$s@example.com', 'wrongpass'); fail('bad login'); } on ApiException catch (e) { expect(e.message, 'Почта ё рамз нодуруст аст'); }
  });
}
