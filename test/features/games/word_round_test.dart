import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:kids_tamil_ezhuthu_school/core/config/models/games_config.dart';
import 'package:kids_tamil_ezhuthu_school/data/models/word_challenge.dart';
import 'package:kids_tamil_ezhuthu_school/features/games/word_builder/word_round.dart';

/// The config the app ships with, read rather than copied — the numbers here
/// drifting from `games_config.json` would prove something the app no longer
/// does, which is how the scoring fixtures went stale once already.
final _config = GamesConfig.fromJson(
  jsonDecode(File('assets/config/games_config.json').readAsStringSync())
      as Map<String, dynamic>,
).wordBuilder;

List<WordChallenge> _words() =>
    (jsonDecode(File('lib/data/games/word_builder.json').readAsStringSync())
            as List<dynamic>)
        .map((e) => WordChallenge.fromJson(e as Map<String, dynamic>))
        .toList();

WordChallenge _word(String tamil) => _words().firstWhere((w) => w.tamil == tamil);

void main() {
  test('a wrong drop is shown for longer than a right one', () {
    // The audience is four years old. Being right can be quick; being told you
    // were wrong has to last long enough to be noticed and understood.
    expect(_config.snakeWrongDurationMs, greaterThan(_config.snakeDurationMs));
    expect(_config.verdictWrongHoldMs, greaterThan(_config.verdictHoldMs));
  });

  group('what a wrong drop is shown to have built', () {
    test('a wrong vowel on a half-built box reads as the letter it makes', () {
      // ஆடு: box 1 wants ட் then உ. Put அ down instead and the child has
      // built ட — which is what gets crossed out, not a bare அ.
      final round = WordRound.forWord(_word('ஆடு'), _config);
      round.drop(1, 'ட்');

      expect(round.previewOf(1, 'அ', _config.vowelSigns), 'ட');
      expect(round.previewOf(1, 'ஆ', _config.vowelSigns), 'டா');
      expect(round.previewOf(1, 'உ', _config.vowelSigns), 'டு',
          reason: 'the right vowel builds the right letter');
    });

    test('an empty box has nothing to combine with, so shows the tile', () {
      final round = WordRound.forWord(_word('ஆடு'), _config);
      expect(round.previewOf(0, 'உ', _config.vowelSigns), 'உ');
      expect(round.previewOf(1, 'வ்', _config.vowelSigns), 'வ்');
    });

    test('a consonant dropped on a half-built box shows itself', () {
      // Two consonants cannot combine, so there is nothing to preview.
      final round = WordRound.forWord(_word('ஆடு'), _config);
      round.drop(1, 'ட்');
      expect(round.previewOf(1, 'வ்', _config.vowelSigns), 'வ்');
    });

    test('every uyir tile has a sign to combine with', () {
      // A missing entry would silently fall back to showing the bare vowel,
      // which is the wrong lesson rather than a visible bug.
      final uyir = _config.tilePool.where((t) => !t.endsWith('்') && t != 'ஃ');
      expect(uyir, hasLength(12));
      for (final vowel in uyir) {
        expect(_config.vowelSigns.containsKey(vowel), isTrue, reason: '$vowel has no sign');
      }
    });
  });

  test('the pool config is exactly the 31 base characters', () {
    // Derived from the letter catalogues rather than restated, so the config
    // cannot quietly drift from what the app teaches.
    final uyir = (jsonDecode(File('lib/data/letters/uyir.json').readAsStringSync())
            as List<dynamic>)
        .map((e) => (e as Map<String, dynamic>)['tamil'] as String);
    final mei = (jsonDecode(File('lib/data/letters/mei.json').readAsStringSync())
            as List<dynamic>)
        .map((e) => (e as Map<String, dynamic>)['tamil'] as String);

    expect(_config.tilePool.toSet(), {...uyir, ...mei});
    expect(_config.tilePool, hasLength(31));
  });

  group('a round of ஆடு', () {
    test('offers every tile the word needs, plus distractors', () {
      final round = WordRound.forWord(_word('ஆடு'), _config);

      // ஆ + ட் + உ, and a tile is never used up, so all three have to be there.
      for (final tile in ['ஆ', 'ட்', 'உ']) {
        expect(round.tiles, contains(tile));
      }
      expect(round.tiles, hasLength(3 + _config.distractorCount));
    });

    test('takes the consonant before the vowel, and nothing else', () {
      final round = WordRound.forWord(_word('ஆடு'), _config);

      expect(round.expects(1), 'ட்');
      expect(round.drop(1, 'உ'), isFalse, reason: 'the vowel cannot go first');
      expect(round.clean, isFalse);
      // A refusal must not undo anything — the word is always finishable.
      expect(round.placedIn(1), 0);
      expect(round.drop(1, 'ட்'), isTrue);
      expect(round.expects(1), 'உ');
      expect(round.drop(1, 'உ'), isTrue);
      expect(round.isSlotFull(1), isTrue);
      expect(round.expects(1), isNull);
    });

    test('shows the consonant while half built, the character once whole', () {
      final round = WordRound.forWord(_word('ஆடு'), _config);

      expect(round.shownIn(1), isNull, reason: 'empty boxes show only their shadow');
      round.drop(1, 'ட்');
      expect(round.shownIn(1), 'ட்',
          reason: 'seeing ட் sitting there is what poses the question');
      round.drop(1, 'உ');
      expect(round.shownIn(1), 'டு');
    });

    test('is complete only when every box is full', () {
      final round = WordRound.forWord(_word('ஆடு'), _config);

      expect(round.isComplete, isFalse);
      round.drop(0, 'ஆ');
      expect(round.isComplete, isFalse);
      round.drop(1, 'ட்');
      expect(round.isComplete, isFalse);
      round.drop(1, 'உ');
      expect(round.isComplete, isTrue);
      expect(round.clean, isTrue);
    });
  });

  test('a repeated letter is still offered once and reusable', () {
    // குகை is க் + உ then க் + ஐ. A tile that vanished when used would leave
    // the second box unfillable.
    final round = WordRound.forWord(_word('குகை'), _config);

    expect(round.tiles.where((t) => t == 'க்'), hasLength(2),
        reason: 'the word needs க் twice, so it is laid out twice');
    expect(round.drop(0, 'க்'), isTrue);
    expect(round.drop(0, 'உ'), isTrue);
    expect(round.drop(1, 'க்'), isTrue);
    expect(round.drop(1, 'ஐ'), isTrue);
    expect(round.isComplete, isTrue);
  });

  test('every word can be built from the tiles it is dealt', () {
    // The failure this catches is a board that cannot be finished at all.
    for (final word in _words()) {
      final round = WordRound.forWord(word, _config);
      final available = [...round.tiles];
      for (var slot = 0; slot < word.slots.length; slot++) {
        for (final tile in word.slots[slot].tiles) {
          expect(available.remove(tile), isTrue,
              reason: '${word.tamil} was never dealt $tile');
          expect(round.drop(slot, tile), isTrue);
        }
      }
      expect(round.isComplete, isTrue, reason: '${word.tamil} could not be completed');
      expect(round.clean, isTrue);
    }
  });

  test('distractors are never tiles the word needs', () {
    for (final word in _words()) {
      final round = WordRound.forWord(word, _config);
      final needed = [...word.answerTiles];
      final extra = <String>[];
      for (final tile in round.tiles) {
        if (!needed.remove(tile)) extra.add(tile);
      }
      expect(extra, hasLength(_config.distractorCount),
          reason: '${word.tamil} was dealt the wrong number of distractors');
      expect(extra.toSet().length, extra.length,
          reason: '${word.tamil} repeats a distractor');
      for (final tile in extra) {
        expect(_config.tilePool, contains(tile));
      }
    }
  });

  test('the same word always deals the same board', () {
    // A child coming back to a word they fumbled should meet the board they
    // remember rather than a fresh puzzle.
    final first = WordRound.forWord(_word('யானை'), _config).tiles;
    final second = WordRound.forWord(_word('யானை'), _config).tiles;
    expect(first, second);
  });
}
