import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:kids_tamil_ezhuthu_school/data/models/letter.dart';
import 'package:kids_tamil_ezhuthu_school/data/repos/letter_repository.dart';

List<Map<String, dynamic>> _roster() =>
    (jsonDecode(File('lib/data/letters/uyirmei.json').readAsStringSync()) as List<dynamic>)
        .cast<Map<String, dynamic>>();

void main() {
  test('216 characters in 18 rows of 12', () {
    final rows = _roster();

    expect(rows.length, 216);
    expect(rows.map((e) => e['id']).toSet().length, 216, reason: 'ids are unique');

    final groups = <String, int>{};
    for (final r in rows) {
      groups[r['group'] as String] = (groups[r['group'] as String] ?? 0) + 1;
    }
    expect(groups.length, 18);
    expect(groups.values.every((n) => n == 12), isTrue,
        reason: 'every consonant takes all 12 vowels');
  });

  test('each row is one consonant taking the vowels in order', () {
    final rows = _roster();
    final first = rows.take(12).toList();

    // The inherent vowel is written with no sign at all: க already says "ka".
    expect(first.first['tamil'], 'க');
    expect(first.first['transliteration'], 'ka');
    expect(first.map((e) => e['tamil']),
        ['க', 'கா', 'கி', 'கீ', 'கு', 'கூ', 'கெ', 'கே', 'கை', 'கொ', 'கோ', 'கௌ']);
    expect(first.every((e) => e['groupTamil'] == 'க'), isTrue);
    expect(rows.last['tamil'], 'னௌ');
  });

  test('the consonants match mei.json, so the two files cannot drift', () {
    final mei = (jsonDecode(File('lib/data/letters/mei.json').readAsStringSync())
            as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final bare = mei.map((e) => (e['tamil'] as String).replaceAll('்', '')).toList();

    final groups = <String>[];
    for (final r in _roster()) {
      final g = r['groupTamil'] as String;
      if (groups.isEmpty || groups.last != g) groups.add(g);
    }
    expect(groups, bare);
  });

  test('uyirmei carries no example words, and the model allows that', () {
    // 216 invented example words would be 216 chances to teach a wrong one.
    expect(_roster().any((e) => e.containsKey('exampleWordTamil')), isFalse);

    final letter = Letter.fromJson(_roster().first);
    expect(letter.hasExampleWord, isFalse);
    expect(letter.exampleWordTamil, isNull);
    expect(letter.group, 'uyirmei_01');
  });

  test('uyir and mei still carry theirs', () {
    final uyir = (jsonDecode(File('lib/data/letters/uyir.json').readAsStringSync())
            as List<dynamic>)
        .cast<Map<String, dynamic>>();
    expect(Letter.fromJson(uyir.first).hasExampleWord, isTrue);
    expect(Letter.fromJson(uyir.first).group, isNull,
        reason: 'uyir is one screenful, so it has no sub-groups');
  });

  testWidgets('the catalogue loads all 216, none traceable yet', (tester) async {
    const repo = LetterRepository();
    final letters = await repo.loadCatalogue(LetterCatalogue.uyirmei);
    final authored = await repo.authoredStrokeDataIds();

    expect(letters.length, 216);
    expect(LetterCatalogue.uyirmei.isGrouped, isTrue);
    expect(LetterCatalogue.uyir.isGrouped, isFalse);

    // Every uyirmei stroke file that exists must belong to a letter in the
    // roster — a stray id would be a letter nobody can ever reach. Written
    // this way rather than "expect zero", so it keeps holding as rows are
    // authored.
    final ids = letters.map((l) => l.strokeDataId).toSet();
    expect(
      authored.where((a) => a.startsWith('uyirmei_')).where((a) => !ids.contains(a)),
      isEmpty,
    );
  });
}
