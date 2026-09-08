import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Read synchronously: a `testWidgets` body runs under fake async, where a
/// real `dart:io` future never completes and the test hangs.
List<Map<String, dynamic>> _roster(String path) =>
    (jsonDecode(File(path).readAsStringSync()) as List<dynamic>)
        .cast<Map<String, dynamic>>();

const _pulli = '்';
const _uyir = 'அஆஇஈஉஊஎஏஐஒஓஔ';
const _consonants = 'கஙசஞடணதநபமயரலவழளறன';

/// The tile pool: 12 uyir + 18 mei + ஃ (CLAUDE.md section 8). A child can
/// build every other Tamil character from these, which is the whole lesson.
final _pool = {
  ..._uyir.split(''),
  ..._consonants.split('').map((c) => '$c$_pulli'),
  'ஃ',
};

void main() {
  final words = _roster('lib/data/games/word_builder.json');

  test('the pool is exactly the 31 base characters', () {
    expect(_pool, hasLength(31));
  });

  test('every tile is one a child can be handed', () {
    // The one rule that makes the game teachable: nothing composed is ever
    // given out ready-made, so a uyirmei has to be built.
    for (final word in words) {
      for (final slot in (word['slots'] as List)) {
        for (final tile in (slot['tiles'] as List).cast<String>()) {
          expect(_pool, contains(tile),
              reason: '${word['tamil']} hands out $tile, which is not in the pool');
        }
      }
    }
  });

  test('every slot is spelled by its own tiles', () {
    // A consonant-vowel slot is consonant + vowel with no exceptions, so the
    // tiles have to actually reconstruct the character shown in the box.
    const signs = {
      'அ': '', 'ஆ': 'ா', 'இ': 'ி', 'ஈ': 'ீ',
      'உ': 'ு', 'ஊ': 'ூ', 'எ': 'ெ', 'ஏ': 'ே',
      'ஐ': 'ை', 'ஒ': 'ொ', 'ஓ': 'ோ', 'ஔ': 'ௌ',
    };
    for (final word in words) {
      for (final slot in (word['slots'] as List)) {
        final tiles = (slot['tiles'] as List).cast<String>();
        final char = slot['char'] as String;
        if (tiles.length == 1) {
          expect(tiles.single, char);
          continue;
        }
        expect(tiles, hasLength(2), reason: '$char needs one or two tiles');
        final consonant = tiles[0];
        expect(consonant.endsWith(_pulli), isTrue,
            reason: '$char should start from a mei letter');
        expect(consonant.substring(0, 1) + signs[tiles[1]]!, char,
            reason: '${tiles[0]} + ${tiles[1]} does not spell $char');
      }
    }
  });

  test('every word is inside the limits CLAUDE.md section 8 sets', () {
    for (final word in words) {
      final slots = (word['slots'] as List);
      expect(slots.length, lessThanOrEqualTo(4), reason: '${word['tamil']} is too long');
      final composed = slots.where((s) => (s['tiles'] as List).length == 2).length;
      expect(composed, lessThanOrEqualTo(2),
          reason: '${word['tamil']} has more than two uyirmei');
    }
  });

  test('ids and order are unique and contiguous, easiest first', () {
    expect(words.map((w) => w['id']).toSet(), hasLength(words.length));
    expect(words.map((w) => w['order']), List.generate(words.length, (i) => i + 1));
    final tileCounts = [
      for (final w in words)
        (w['slots'] as List).fold<int>(0, (a, s) => a + (s['tiles'] as List).length),
    ];
    final slotCounts = [for (final w in words) (w['slots'] as List).length];
    for (var i = 1; i < words.length; i++) {
      expect(
        slotCounts[i] > slotCounts[i - 1] ||
            (slotCounts[i] == slotCounts[i - 1] && tileCounts[i] >= tileCounts[i - 1]),
        isTrue,
        reason: '${words[i]['tamil']} is easier than the word before it',
      );
    }
  });

  test('every word has its picture on disk', () {
    for (final word in words) {
      expect(File(word['image'] as String).existsSync(), isTrue,
          reason: '${word['tamil']} points at a missing picture');
    }
  });
}
