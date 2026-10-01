import 'package:shared_preferences/shared_preferences.dart';

/// Name, gender and age the child entered on this phone. Sent to the server
/// when the pairing code is created.
class ChildProfile {
  const ChildProfile({required this.name, required this.gender, required this.age});

  final String name;
  final String gender; // 'boy' | 'girl'
  final int age;

  static const _key = 'nigoh.child_profile';

  static Future<ChildProfile?> load() async {
    final raw = (await SharedPreferences.getInstance()).getStringList(_key);
    if (raw == null || raw.length != 3) return null;
    return ChildProfile(name: raw[0], gender: raw[1], age: int.tryParse(raw[2]) ?? 11);
  }

  Future<void> save() async => (await SharedPreferences.getInstance())
      .setStringList(_key, [name, gender, '$age']);

  static Future<void> clear() async =>
      (await SharedPreferences.getInstance()).remove(_key);
}
