import 'package:flutter_test/flutter_test.dart';
import 'package:kids_tamil_ezhuthu_school/core/config/models/app_config.dart';
import 'package:kids_tamil_ezhuthu_school/core/config/models/scoring_config.dart';
import 'package:kids_tamil_ezhuthu_school/core/config/models/trace_mode.dart';
import 'package:kids_tamil_ezhuthu_school/data/models/letter.dart';
import 'package:kids_tamil_ezhuthu_school/data/models/score.dart';
import 'package:kids_tamil_ezhuthu_school/features/parent/certificate_score.dart';

const _thresholds = StarThresholds(one: 30, two: 75, three: 90);

const _certConfig = CertificateConfig(
  allLettersStarredMarks: 50,
  uyirCategoryMarks: 10,
  meiCategoryMarks: 10,
  uyirmeiCategoryMarks: 20,
  gameCategoryMarks: 10,
);

Letter _letter(String id, LetterCatalogue catalogue) => Letter(
      id: id,
      category: switch (catalogue) {
        LetterCatalogue.uyir => LetterCategory.uyir,
        LetterCatalogue.mei => LetterCategory.mei,
        LetterCatalogue.uyirmei => LetterCategory.uyirmei,
        LetterCatalogue.vadamozhi => LetterCategory.vadamozhi,
      },
      order: 0,
      tamil: id,
      transliteration: id,
      strokeDataId: id,
    );

LetterProgress _starred(String id, int stars) {
  // one star at 30, three stars at 90 — see _thresholds above.
  final marks = switch (stars) {
    3 => 90,
    1 => 30,
    _ => 0,
  };
  return LetterProgress(letterId: id, marksByMode: {TraceMode.easy: marks});
}

void main() {
  group('computeCertificateScore', () {
    final uyir = [_letter('u1', LetterCatalogue.uyir), _letter('u2', LetterCatalogue.uyir)];
    final mei = [_letter('m1', LetterCatalogue.mei), _letter('m2', LetterCatalogue.mei)];
    final uyirmei = [_letter('um1', LetterCatalogue.uyirmei)];
    final vadamozhi = [_letter('v1', LetterCatalogue.vadamozhi)];

    final catalogues = {
      LetterCatalogue.uyir: uyir,
      LetterCatalogue.mei: mei,
      LetterCatalogue.uyirmei: uyirmei,
      LetterCatalogue.vadamozhi: vadamozhi,
    };

    test('nothing earned scores zero', () {
      final score = computeCertificateScore(
        catalogues: catalogues,
        progress: const {},
        thresholds: _thresholds,
        wordCount: 5,
        cleanWordCount: 0,
        config: _certConfig,
      );
      expect(score.total, 0);
    });

    test('every core letter at one star earns the full base 50', () {
      final progress = {
        for (final letter in [...uyir, ...mei, ...uyirmei]) letter.id: _starred(letter.id, 1),
      };
      final score = computeCertificateScore(
        catalogues: catalogues,
        progress: progress,
        thresholds: _thresholds,
        wordCount: 5,
        cleanWordCount: 0,
        config: _certConfig,
      );
      expect(score.total, 50);
    });

    test('one core letter of five starred pays a fifth of the base, not zero', () {
      // Proportional, not all-or-nothing: "1/50" for early progress is the
      // honest number the certificate is meant to show.
      final progress = {uyir.first.id: _starred(uyir.first.id, 1)};
      final score = computeCertificateScore(
        catalogues: catalogues,
        progress: progress,
        thresholds: _thresholds,
        wordCount: 5,
        cleanWordCount: 0,
        config: _certConfig,
      );
      final base = score.lines.firstWhere((l) => l.achievement == CertificateAchievement.allStarred);
      expect(base.achievedCount, 1);
      expect(base.totalCount, 5);
      expect(base.marks, 10); // round(1/5 * 50)
    });

    test('grantha letters do not count toward the 247 base mark', () {
      // Every grantha letter starred, nothing else — the base stays at 0
      // because it is not part of the 247 (CLAUDE.md section 2).
      final progress = {for (final letter in vadamozhi) letter.id: _starred(letter.id, 1)};
      final score = computeCertificateScore(
        catalogues: catalogues,
        progress: progress,
        thresholds: _thresholds,
        wordCount: 5,
        cleanWordCount: 0,
        config: _certConfig,
      );
      expect(score.total, 0);
    });

    test('mastering one category pays that bonus plus the base it implies', () {
      final progress = {for (final letter in uyir) letter.id: _starred(letter.id, 3)};
      final score = computeCertificateScore(
        catalogues: catalogues,
        progress: progress,
        thresholds: _thresholds,
        wordCount: 5,
        cleanWordCount: 0,
        config: _certConfig,
      );
      // Mastering uyir (3 stars each) also means both uyir letters hold at
      // least one star — 2 of the 5 core letters, so the base pays its own
      // proportional share too: round(2/5*50)=20, plus the uyir bonus 10.
      expect(score.total, 30);
    });

    test('everything mastered, including every word cleared, scores 100', () {
      final progress = {
        for (final letter in [...uyir, ...mei, ...uyirmei]) letter.id: _starred(letter.id, 3),
      };
      final score = computeCertificateScore(
        catalogues: catalogues,
        progress: progress,
        thresholds: _thresholds,
        wordCount: 5,
        cleanWordCount: 5,
        config: _certConfig,
      );
      expect(score.total, CertificateScore.maxTotal);
    });

    test('a clean-word count short of the total pays its own fraction, not zero', () {
      final progress = {
        for (final letter in [...uyir, ...mei, ...uyirmei]) letter.id: _starred(letter.id, 3),
      };
      final score = computeCertificateScore(
        catalogues: catalogues,
        progress: progress,
        thresholds: _thresholds,
        wordCount: 5,
        cleanWordCount: 4,
        config: _certConfig,
      );
      final game = score.lines.firstWhere((l) => l.achievement == CertificateAchievement.game);
      expect(game.marks, 8); // round(4/5 * 10)
      expect(game.complete, isFalse);
      expect(score.total, CertificateScore.maxTotal - 2);
    });
  });
}
