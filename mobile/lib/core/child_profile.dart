// Файл: профили маҳаллии фарзанд пеш аз пайвастшавӣ.

import 'package:shared_preferences/shared_preferences.dart';

/// Додаҳо ва рафтори марбут ба профили маҳаллии фарзанд пеш аз пайвастшавӣро ифода мекунад.
class ChildProfile {
  const ChildProfile({
    required this.name,
    required this.gender,
    required this.age,
  });

  final String name;
  final String gender; // Қимат танҳо 'boy' ё 'girl' мешавад.
  final int age;

  static const _key = 'nigoh.child_profile';

  /// load додаҳои child_profile-ро мехонад ва ҳолати ChildProfile-ро нав мекунад.
  static Future<ChildProfile?> load() async {
    final raw = (await SharedPreferences.getInstance()).getStringList(_key);
    if (raw == null || raw.length != 3) return null;
    return ChildProfile(
      name: raw[0],
      gender: raw[1],
      age: int.tryParse(raw[2]) ?? 11,
    );
  }

  /// getInstance тағйироти child_profile-ро барои истифодаи баъдӣ нигоҳ медорад.
  Future<void> save() async => (await SharedPreferences.getInstance())
      .setStringList(_key, [name, gender, '$age']);

  /// clear маълумотро ҳазф карда, ҳолати вобастаро нав мекунад.
  static Future<void> clear() async =>
      (await SharedPreferences.getInstance()).remove(_key);
}
