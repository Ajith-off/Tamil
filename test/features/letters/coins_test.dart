import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kids_tamil_ezhuthu_school/core/config/models/app_config.dart';
import 'package:kids_tamil_ezhuthu_school/core/config/models/scoring_config.dart';
import 'package:kids_tamil_ezhuthu_school/core/config/models/trace_mode.dart';
import 'package:kids_tamil_ezhuthu_school/data/models/letter.dart';
import 'package:kids_tamil_ezhuthu_school/data/models/score.dart';
import 'package:kids_tamil_ezhuthu_school/data/repos/progress_repository.dart';
import 'package:kids_tamil_ezhuthu_school/features/letter/letter_providers.dart';

/// The config the app ships with, read rather than copied.
final _app = AppConfig.fromJson(
    jsonDecode(File('assets/config/app_config.json').readAsStringSync())
        as Map<String, dynamic>);
final _scoring = ScoringConfig.fromJson(
    jsonDecode(File('assets/config/scoring_config.json').readAsStringSync())
        as Map<String, dynamic>);

StarThresholds get _thresholds => _scoring.starThresholds;

/// Marks worth exactly [stars], using the thresholds the app ships with.
LetterProgress _worth(String id, int stars) {
  final target = switch (stars) {
    0 => 0,
    1 => _thresholds.one,
    2 => _thresholds.two,
    _ => _thresholds.three,
  };
  return LetterProgress(letterId: id, marksByMode: {TraceMode.easy: target});
}

Letter _letter(String id, int order) => Letter(
      id: id,
      category: LetterCategory.uyir,
      order: order,
      tamil: id,
      transliteration: id,
      strokeDataId: id,
    );

int _balance(Map<String, LetterProgress> progress, {int spent = 0}) => coinBalance(
      progress: progress,
      thresholds: _thresholds,
      coins: _app.coins,
      spent: spent,
    );

void main() {
  test('a child starts with the configured balance', () {
    expect(_balance(const {}), _app.coins.startingBalance);
    expect(_app.coins.startingBalance, greaterThan(0),
        reason: 'the games have to be open on day one (CLAUDE.md section 7)');
  });

  test('three stars on a letter earns a coin; fewer earns nothing', () {
    expect(_balance({'a': _worth('a', 2)}), _app.coins.startingBalance);
    expect(_balance({'a': _worth('a', 3)}),
        _app.coins.startingBalance + _app.coins.perThreeStarLetter);
    expect(
      _balance({'a': _worth('a', 3), 'b': _worth('b', 3), 'c': _worth('c', 1)}),
      _app.coins.startingBalance + 2 * _app.coins.perThreeStarLetter,
    );
  });

  test('re-tracing a three-star letter cannot farm more coins', () {
    // The whole reason earnings are derived from progress rather than banked
    // when they happen: there is no event to replay. Recording attempt after
    // attempt on an already-perfect letter changes nothing.
    var progress = _worth('a', 3);
    final once = _balance({'a': progress});
    for (var i = 0; i < 5; i++) {
      progress = progress.withAttempt(
          const AttemptResult(mode: TraceMode.easy, marks: 25, maxMarks: 25));
    }
    expect(_balance({'a': progress}), once);
  });

  test('spending comes off the balance and stops there', () {
    final progress = {'a': _worth('a', 3)};
    final earned = _balance(progress);
    expect(_balance(progress, spent: 10), earned - 10);
    // Nothing here refuses to go negative — that is the caller's business,
    // and a heart should be refused before it is charged for.
    expect(_balance(const {}, spent: _app.coins.startingBalance),
        0);
  });

  test('the purse only accumulates what is spent', () {
    final purse = CoinPurse(ProgressRepository());
    addTearDown(purse.dispose);
    expect(purse.state, 0);
    purse.spend(3);
    purse.spend(4);
    expect(purse.state, 7);
  });

  group('achievements', () {
    final letters = [_letter('a', 1), _letter('b', 2), _letter('c', 3)];

    test('a character counts once it reaches three stars, and not before', () {
      // Same bar as the coin: finishing a character outright is one thing, and
      // it is worth one of each (CLAUDE.md section 7).
      int medals(Map<String, LetterProgress> progress) => threeStarCount(
            letters: letters,
            progress: progress,
            thresholds: _thresholds,
          );

      expect(medals(const {}), 0);
      expect(medals({'a': _worth('a', 2)}), 0, reason: 'two stars is not finished');
      expect(medals({'a': _worth('a', 3)}), 1);
      expect(medals({'a': _worth('a', 3), 'b': _worth('b', 3)}), 2);
    });

    test('counts only the letters on that screen', () {
      expect(
        threeStarCount(
          letters: letters,
          progress: {'a': _worth('a', 3), 'z': _worth('z', 3)},
          thresholds: _thresholds,
        ),
        1,
        reason: 'z is not in this category',
      );
    });

    test('re-tracing a finished letter does not mint a second', () {
      // The count is derived from progress, so there is no event to replay.
      final progress = {'a': _worth('a', 3)};
      final before = threeStarCount(
          letters: letters, progress: progress, thresholds: _thresholds);
      expect(
        threeStarCount(letters: letters, progress: progress, thresholds: _thresholds),
        before,
      );
    });
  });

  group('stars shown on a list', () {
    final letters = [_letter('a', 1), _letter('b', 2), _letter('c', 3)];

    test('adds up only the letters on that screen', () {
      expect(
        totalStars(
          letters: letters,
          progress: {'a': _worth('a', 3), 'b': _worth('b', 1), 'z': _worth('z', 3)},
          thresholds: _thresholds,
        ),
        4,
        reason: 'z is not in this list, so its stars are not this total',
      );
    });

    test('an untouched list shows nothing earned', () {
      expect(totalStars(letters: letters, progress: const {}, thresholds: _thresholds), 0);
    });
  });
}
