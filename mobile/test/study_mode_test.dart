import 'package:flutter_test/flutter_test.dart';
import 'package:nigoh_family_parent/core/app_categories.dart';
import 'package:nigoh_family_parent/core/models.dart';

void main() {
  const study = StudyMode(
    enabled: true,
    start: '08:00',
    end: '13:00',
    weekdays: [1, 2, 3, 4, 5],
  );
  test('study mode is active only on school days and hours', () {
    expect(study.activeAt(DateTime(2026, 10, 5, 9, 0)), isTrue); // Monday
    expect(study.activeAt(DateTime(2026, 10, 5, 14, 0)), isFalse);
    expect(study.activeAt(DateTime(2026, 10, 4, 9, 0)), isFalse); // Sunday
  });

  test('study mode blocks games/social/video, keeps education, phone and always-allowed', () {
    Map<String, dynamic> rule(String pkg, {bool always = false}) => ChildApp(
      packageName: pkg,
      name: pkg,
      alwaysAllowed: always,
    ).toNativeRule(studyActive: true);
    expect(rule('com.roblox.client')['blocked'], isTrue);
    expect(rule('com.instagram.android')['blocked'], isTrue);
    expect(rule('com.google.android.youtube')['blocked'], isTrue);
    expect(rule('com.duolingo')['blocked'], isFalse);
    expect(rule('com.samsung.android.dialer')['blocked'], isFalse);
    expect(rule('com.roblox.client', always: true)['blocked'], isFalse);
  });

  test('bedtime never closes the phone app', () {
    const dialer = ChildApp(
      packageName: 'com.google.android.dialer',
      name: 'Phone',
    );
    const game = ChildApp(packageName: 'com.roblox.client', name: 'Roblox');
    expect(dialer.toNativeRule(bedtimeActive: true)['blocked'], isFalse);
    expect(game.toNativeRule(bedtimeActive: true)['blocked'], isTrue);
    expect(isEssentialApp('com.android.dialer'), isTrue);
  });
}
