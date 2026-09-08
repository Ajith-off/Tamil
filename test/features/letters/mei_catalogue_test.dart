import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:kids_tamil_ezhuthu_school/data/models/letter.dart';
import 'package:kids_tamil_ezhuthu_school/data/repos/letter_repository.dart';

/// Read synchronously throughout: a `testWidgets` body runs under fake async,
/// where a real `dart:io` future never completes and the test hangs.
List<Map<String, dynamic>> _roster(String path) =>
    (jsonDecode(File(path).readAsStringSync()) as List<dynamic>).cast<Map<String, dynamic>>();

Set<String> _authoredStrokeIds() => Directory('lib/data/letters/strokes')
    .listSync()
    .whereType<File>()
    .map((f) => f.uri.pathSegments.last)
    .where((name) => name.endsWith('.json'))
    .map((name) => name.substring(0, name.length - '.json'.length))
    .toSet();

void main() {
  test('the mei roster is all 18 consonants, in the order CLAUDE.md lists them', () {
    final mei = _roster('lib/data/letters/mei.json');

    expect(mei.length, 18);
    expect(
      mei.map((e) => e['tamil']),
      ['க்', 'ங்', 'ச்', 'ஞ்', 'ட்', 'ண்', 'த்', 'ந்', 'ப்', 'ம்',
       'ய்', 'ர்', 'ல்', 'வ்', 'ழ்', 'ள்', 'ற்', 'ன்'],
    );
    expect(mei.map((e) => e['order']), List.generate(18, (i) => i + 1));
    expect(mei.map((e) => e['id']).toSet().length, 18, reason: 'ids are unique');
    expect(mei.every((e) => e['category'] == 'mei'), isTrue);
  });

  test('an example word contains its letter, since no Tamil word can start with one', () {
    // CLAUDE.md section 8: a pure consonant cannot begin a word, so its
    // example has to be a word it appears *inside* — which is also what
    // Picture Puzzle blanks out later.
    for (final letter in _roster('lib/data/letters/mei.json')) {
      expect(
        (letter['exampleWordTamil'] as String).contains(letter['tamil'] as String),
        isTrue,
        reason: '${letter['exampleWordTamil']} does not contain ${letter['tamil']}',
      );
    }
  });

  test('every letter names the glyph its skeleton was exported from', () {
    // The two files are joined only by the id: `trace_letter.py` writes
    // strokes for the character the skeleton index names, and the list shows
    // the character this roster names. Let them drift and a child traces one
    // letter while reading another.
    final skeletons = {
      for (final e in _roster('assets/authoring/skeletons/index.json'))
        e['letterId'] as String: e['char'] as String,
    };

    for (final letter in _roster('lib/data/letters/mei.json')) {
      expect(skeletons[letter['strokeDataId']], letter['tamil'],
          reason: '${letter['id']} disagrees with its exported skeleton');
    }
  });

  // The only test here that touches rootBundle — one asset-loading test per
  // file, per the note in widget_test.dart.
  testWidgets('a catalogue holds its whole set, and says which parts are traceable',
      (tester) async {
    const repo = LetterRepository();

    // The list shows all 18 whether or not they have been authored: a
    // category that hid its unfinished letters would say மெய் has four.
    expect((await repo.loadCatalogue(LetterCatalogue.mei)).length, 18);
    expect(
      (await repo.loadCatalogue(LetterCatalogue.uyir)).length,
      _roster('lib/data/letters/uyir.json').length,
    );

    // What is traceable comes from the bundle, not the roster.
    expect(await repo.authoredStrokeDataIds(), _authoredStrokeIds());
  });
}
