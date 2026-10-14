import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The ARB files gen-l10n builds the UI strings from (see l10n.yaml).
const _files = ['app_zh.arb', 'app_zh_CN.arb', 'app_en.arb'];

Map<String, dynamic> _read(String name) =>
    jsonDecode(File('lib/l10n/$name').readAsStringSync()) as Map<String, dynamic>;

/// Message keys (no `@@locale` or `@key` metadata).
Set<String> _keys(Map<String, dynamic> arb) => arb.keys.where((k) => !k.startsWith('@')).toSet();

/// Placeholder names used in a message, outside plural/select selectors'
/// own syntax (`{count, plural, ...}` uses `count`).
Set<String> _placeholdersIn(String message) =>
    RegExp(r'(?<![\w=])\{(\w+)(?=[,}])').allMatches(message).map((m) => m.group(1)!).toSet();

void main() {
  final arbs = {for (final f in _files) f: _read(f)};
  final template = arbs['app_zh.arb']!;

  test('every ARB file has the same keys', () {
    final keys = _keys(template);
    expect(keys, isNotEmpty);
    for (final entry in arbs.entries) {
      final other = _keys(entry.value);
      expect(other.difference(keys), isEmpty, reason: '${entry.key} has keys missing from the template');
      expect(keys.difference(other), isEmpty, reason: '${entry.key} is missing keys');
    }
  });

  test('no message is empty', () {
    for (final entry in arbs.entries) {
      for (final key in _keys(entry.value)) {
        final value = entry.value[key];
        expect(value, isA<String>(), reason: '${entry.key}: $key');
        expect((value as String).trim(), isNotEmpty, reason: '${entry.key}: $key is empty');
      }
    }
  });

  test('messages only use the placeholders the template declares', () {
    for (final key in _keys(template)) {
      final meta = template['@$key'] as Map<String, dynamic>?;
      final declared = (meta?['placeholders'] as Map<String, dynamic>?)?.keys.toSet() ?? <String>{};
      for (final entry in arbs.entries) {
        final used = _placeholdersIn(entry.value[key] as String);
        expect(used.difference(declared), isEmpty, reason: '${entry.key}: $key uses undeclared placeholders');
      }
    }
  });

  test('locales are declared and Chinese variants really differ where they should', () {
    expect(arbs['app_zh.arb']!['@@locale'], 'zh');
    expect(arbs['app_zh_CN.arb']!['@@locale'], 'zh_CN');
    expect(arbs['app_en.arb']!['@@locale'], 'en');
    // Spot checks: Traditional vs Simplified with mainland wording.
    expect(arbs['app_zh.arb']!['settings'], '設定');
    expect(arbs['app_zh_CN.arb']!['settings'], '设置');
    expect(arbs['app_zh.arb']!['authLogin'], '登入');
    expect(arbs['app_zh_CN.arb']!['authLogin'], '登录');
  });
}
