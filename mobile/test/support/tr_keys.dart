import 'dart:io';

/// A literal key passed to `tr(...)` and where it was found.
class TrKey {
  TrKey(this.key, this.file, this.line);
  final String key;
  final String file;
  final int line;
}

/// Finds the first argument of every `tr(...)` call whose first argument is
/// a string literal (or several adjacent literals, `'a' 'b'`, possibly on
/// different lines). Handles both quote styles, triple quotes, raw strings
/// and escapes. Calls like `tr(variable)` are ignored. Literals containing
/// `$` interpolation are reported with the raw `$...` text kept, so tests can
/// flag them.
List<TrKey> extractTrKeys(String root) {
  final result = <TrKey>[];
  final files = Directory(root)
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final file in files) {
    final src = file.readAsStringSync();
    for (final (key, offset) in extractTrKeysFromSource(src)) {
      final line = '\n'.allMatches(src.substring(0, offset)).length + 1;
      result.add(TrKey(key, file.path, line));
    }
  }
  return result;
}

bool _isIdent(int c) =>
    (c >= 0x30 && c <= 0x39) ||
    (c >= 0x41 && c <= 0x5a) ||
    (c >= 0x61 && c <= 0x7a) ||
    c == 0x5f ||
    c == 0x24;

/// Returns (key, offset of `tr`) pairs from Dart [src].
List<(String, int)> extractTrKeysFromSource(String src) {
  final out = <(String, int)>[];
  var i = 0;
  final n = src.length;

  // Skips whitespace and comments starting at [p].
  int skipWs(int p) {
    while (p < n) {
      final c = src[p];
      if (c == ' ' || c == '\n' || c == '\r' || c == '\t') {
        p++;
      } else if (src.startsWith('//', p)) {
        final e = src.indexOf('\n', p);
        p = e < 0 ? n : e + 1;
      } else if (src.startsWith('/*', p)) {
        final e = src.indexOf('*/', p + 2);
        p = e < 0 ? n : e + 2;
      } else {
        break;
      }
    }
    return p;
  }

  // Parses a string literal at [p]; returns (value, end) or null.
  (String, int)? literal(int p) {
    var raw = false;
    if (p < n && src[p] == 'r') {
      raw = true;
      p++;
    }
    if (p >= n || (src[p] != "'" && src[p] != '"')) return null;
    final q = src[p];
    final triple = src.startsWith(q * 3, p);
    final close = triple ? q * 3 : q;
    p += close.length;
    final b = StringBuffer();
    while (p < n) {
      if (src.startsWith(close, p)) return (b.toString(), p + close.length);
      final c = src[p];
      if (!raw && c == r'\') {
        final e = src[p + 1];
        switch (e) {
          case 'n':
            b.write('\n');
          case 't':
            b.write('\t');
          case 'r':
            b.write('\r');
          case 'u':
            if (src[p + 2] == '{') {
              final end = src.indexOf('}', p + 3);
              b.writeCharCode(int.parse(src.substring(p + 3, end), radix: 16));
              p = end + 1;
              continue;
            }
            b.writeCharCode(int.parse(src.substring(p + 2, p + 6), radix: 16));
            p += 6;
            continue;
          default:
            b.write(e);
        }
        p += 2;
        continue;
      }
      if (!triple && c == '\n') return null;
      b.write(c);
      p++;
    }
    return null;
  }

  while (true) {
    final at = src.indexOf('tr(', i);
    if (at < 0) break;
    i = at + 3;
    if (at > 0 && _isIdent(src.codeUnitAt(at - 1))) continue;
    // Skip definitions like `String tr(String tajik, ...)`.
    var p = skipWs(at + 3);
    final parts = <String>[];
    while (true) {
      final lit = literal(p);
      if (lit == null) break;
      parts.add(lit.$1);
      p = skipWs(lit.$2);
    }
    if (parts.isEmpty) continue;
    if (p < n && (src[p] == ',' || src[p] == ')')) {
      out.add((parts.join(), at));
    }
  }
  return out;
}

/// Keys of `tr()` calls in [root] (default `lib`).
Set<String> trKeys([String root = 'lib']) =>
    extractTrKeys(root).map((k) => k.key).toSet();
