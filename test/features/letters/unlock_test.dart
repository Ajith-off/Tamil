import 'package:flutter_test/flutter_test.dart';
import 'package:kids_tamil_ezhuthu_school/core/config/models/scoring_config.dart';
import 'package:kids_tamil_ezhuthu_school/core/config/models/trace_mode.dart';
import 'package:kids_tamil_ezhuthu_school/data/models/letter.dart';
import 'package:kids_tamil_ezhuthu_school/data/models/score.dart';
import 'package:kids_tamil_ezhuthu_school/features/letter/letter_providers.dart';

const _thresholds = StarThresholds(one: 50, two: 75, three: 90);

Letter _letter(String id, int order) => Letter(
      id: id,
      category: LetterCategory.uyir,
      order: order,
      tamil: id,
      transliteration: id,
      exampleWordTamil: id,
      exampleWordTransliteration: id,
      strokeDataId: id,
    );

/// Marks worth exactly one star, and no more.
LetterProgress _oneStar(String id) => LetterProgress(
      letterId: id,
      marksByMode: const {TraceMode.easy: 25, TraceMode.medium: 25},
    );

void main() {
  final letters = [_letter('a', 1), _letter('b', 2), _letter('c', 3)];

  List<bool> flags(Map<String, LetterProgress> progress, {int stars = 1}) => unlockedFlags(
        letters: letters,
        progress: progress,
        thresholds: _thresholds,
        starsToUnlockNext: stars,
      );

  test('the first letter is always open, the rest start locked', () {
    expect(flags(const {}), [true, false, false]);
  });

  test('earning a star on a letter opens the next one, but not the one after', () {
    expect(flags({'a': _oneStar('a')}), [true, true, false]);
  });

  test('progress on a later letter does not open earlier gaps', () {
    // Marks on 'b' say nothing about whether 'b' itself should be reachable.
    expect(flags({'b': _oneStar('b')}), [true, false, true]);
  });

  test('partial marks that fall short of a star do not unlock anything', () {
    final almost = LetterProgress(
      letterId: 'a',
      marksByMode: const {TraceMode.easy: 25},
    );
    expect(almost.starsWith(_thresholds), 0);
    expect(flags({'a': almost}), [true, false, false]);
  });

  test('a stricter unlock requirement holds letters back', () {
    expect(flags({'a': _oneStar('a')}, stars: 2), [true, false, false]);
  });

  group('letters with no stroke data yet', () {
    List<LetterAvailability> availability(
      Set<String> authored,
      Map<String, LetterProgress> progress,
    ) =>
        letterAvailability(
          letters: letters,
          authoredStrokeIds: authored,
          progress: progress,
          thresholds: _thresholds,
          starsToUnlockNext: 1,
        );

    test('an un-authored letter is marked as such, not as locked', () {
      expect(availability({'a', 'b'}, const {}), [
        LetterAvailability.open,
        LetterAvailability.lockedByStars,
        LetterAvailability.notAuthored,
      ]);
    });

    test('the star chain steps over them rather than dead-ending', () {
      // 'a' has nothing to trace, so it can never earn a star. If it stayed
      // in the chain, 'b' would be locked behind a letter that can never be
      // opened and the category would be unplayable.
      expect(availability({'b', 'c'}, const {}), [
        LetterAvailability.notAuthored,
        LetterAvailability.open,
        LetterAvailability.lockedByStars,
      ]);
      expect(availability({'b', 'c'}, {'b': _oneStar('b')}), [
        LetterAvailability.notAuthored,
        LetterAvailability.open,
        LetterAvailability.open,
      ]);
    });

    test('nothing authored means nothing to open', () {
      expect(availability(const {}, const {}),
          List.filled(3, LetterAvailability.notAuthored));
    });
  });
}
