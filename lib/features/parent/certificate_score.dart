import '../../core/config/models/app_config.dart';
import '../../core/config/models/scoring_config.dart';
import '../../data/models/letter.dart';
import '../../data/models/score.dart';

/// One line of the certificate: an achievement, how much of it has been
/// reached, and the marks that earns. [achievement] names which one this is,
/// for the screen to look up its own sentence by.
enum CertificateAchievement { allStarred, uyir, mei, uyirmei, game }

class CertificateLine {
  final CertificateAchievement achievement;

  /// How many of [totalCount] have been reached — letters holding a star,
  /// letters mastered, or words cleared, depending on the line.
  final int achievedCount;
  final int totalCount;
  final int maxMarks;

  const CertificateLine({
    required this.achievement,
    required this.achievedCount,
    required this.totalCount,
    required this.maxMarks,
  });

  /// Marks earned on this line, proportional to progress rather than
  /// all-or-nothing — "1/50" for one letter out of 247 is the honest number,
  /// not zero. Rounded to the nearest whole mark.
  int get marks => totalCount == 0 ? 0 : (achievedCount * maxMarks / totalCount).round();

  bool get complete => totalCount > 0 && achievedCount >= totalCount;
}

/// The progress certificate's breakdown, out of [maxTotal].
class CertificateScore {
  final List<CertificateLine> lines;

  const CertificateScore(this.lines);

  int get total => lines.fold(0, (sum, line) => sum + line.marks);

  static const maxTotal = 100;
}

/// Builds the certificate's 100-mark breakdown: 50 marks spread across the
/// 247 core letters holding at least one star, then bonus marks (10/10/20/10)
/// spread across the uyir, mei, uyirmei and Word Builder categories reaching
/// mastery — three stars on a letter, or a clean clear on a word.
///
/// Each line pays proportionally to how much of it is done — a child partway
/// through earns partway through the marks, shown as "achieved/possible" on
/// the certificate, rather than nothing until the whole line is finished.
///
/// Live, not generated-and-stored — it reads the same progress the letter
/// screens write, so it is always exactly as current as the letter lists are.
CertificateScore computeCertificateScore({
  required Map<LetterCatalogue, List<Letter>> catalogues,
  required Map<String, LetterProgress> progress,
  required StarThresholds thresholds,
  required int wordCount,
  required int cleanWordCount,
  required CertificateConfig config,
}) {
  int starsOf(Letter letter) => progress[letter.id]?.starsWith(thresholds) ?? 0;

  final core = [
    for (final entry in catalogues.entries)
      if (entry.key.isPartOf247) ...entry.value,
  ];
  final starredCount = core.where((letter) => starsOf(letter) >= 1).length;

  int masteredCount(LetterCatalogue catalogue) {
    final letters = catalogues[catalogue] ?? const [];
    return letters.where((letter) => starsOf(letter) >= 3).length;
  }

  return CertificateScore([
    CertificateLine(
      achievement: CertificateAchievement.allStarred,
      achievedCount: starredCount,
      totalCount: core.length,
      maxMarks: config.allLettersStarredMarks,
    ),
    CertificateLine(
      achievement: CertificateAchievement.uyir,
      achievedCount: masteredCount(LetterCatalogue.uyir),
      totalCount: (catalogues[LetterCatalogue.uyir] ?? const []).length,
      maxMarks: config.uyirCategoryMarks,
    ),
    CertificateLine(
      achievement: CertificateAchievement.mei,
      achievedCount: masteredCount(LetterCatalogue.mei),
      totalCount: (catalogues[LetterCatalogue.mei] ?? const []).length,
      maxMarks: config.meiCategoryMarks,
    ),
    CertificateLine(
      achievement: CertificateAchievement.uyirmei,
      achievedCount: masteredCount(LetterCatalogue.uyirmei),
      totalCount: (catalogues[LetterCatalogue.uyirmei] ?? const []).length,
      maxMarks: config.uyirmeiCategoryMarks,
    ),
    CertificateLine(
      achievement: CertificateAchievement.game,
      achievedCount: cleanWordCount,
      totalCount: wordCount,
      maxMarks: config.gameCategoryMarks,
    ),
  ]);
}
