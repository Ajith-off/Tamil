import 'package:flutter_test/flutter_test.dart';
import 'package:kids_tamil_ezhuthu_school/core/config/models/trace_mode.dart';
import 'package:kids_tamil_ezhuthu_school/data/models/score.dart';
import 'package:kids_tamil_ezhuthu_school/features/letter/scoring/mark_scheme.dart';

import 'scoring_fixtures.dart';

const _pathLength = 2.5; // roughly one letter's worth of normalized arc

StrokeAnalysis _shape(double accuracy) => StrokeAnalysis(
      shapeAccuracy: accuracy,
      countAccuracy: 1,
      orderAccuracy: 1,
      directionAccuracy: 1,
    );

void main() {
  final scheme = MarkScheme(scoringConfigFixture);

  AttemptResult run(
    TraceMode mode, {
    bool completed = true,
    Duration elapsed = const Duration(seconds: 10),
    StrokeAnalysis? analysis,
  }) {
    return scheme.evaluate(
      mode: mode,
      completed: completed,
      elapsed: elapsed,
      pathLength: _pathLength,
      analysis: analysis ?? _shape(1),
    );
  }

  test('the four modes divide exactly 100 marks between them', () {
    expect(scheme.totalMarks, 100);
    final perMode = TraceMode.values.map(scheme.maxMarksFor).toList();
    expect(perMode, [25, 25, 30, 20]);
    expect(perMode.reduce((a, b) => a + b), 100);
  });

  group('easy and medium pay purely for completion', () {
    test('finishing earns the full marks regardless of how well it was drawn', () {
      // A poor shape must not reduce these — the finger was snapped to the
      // path, so completing is the whole point.
      expect(run(TraceMode.easy, analysis: _shape(0.1)).marks, 25);
      expect(run(TraceMode.medium, analysis: _shape(0.1)).marks, 25);
    });

    test('not finishing earns nothing', () {
      expect(run(TraceMode.easy, completed: false).marks, 0);
      expect(run(TraceMode.medium, completed: false).marks, 0);
    });
  });

  group('hard pays for completion plus a fluency bonus', () {
    test('a fast, complete attempt earns the full 30', () {
      final fast = Duration(milliseconds: (2.0 * _pathLength * 1000).round());
      expect(run(TraceMode.hard, elapsed: fast).marks, 30);
    });

    test('a slow but complete attempt still keeps every completion mark', () {
      final slow = Duration(milliseconds: (30.0 * _pathLength * 1000).round());
      final result = run(TraceMode.hard, elapsed: slow);
      expect(result.speedMarks, 0);
      expect(result.marks, 20, reason: 'taking your time must never cost marks');
    });

    test('a middling pace earns part of the bonus', () {
      final middling = Duration(milliseconds: (6.5 * _pathLength * 1000).round());
      final result = run(TraceMode.hard, elapsed: middling);
      expect(result.speedMarks, greaterThan(0));
      expect(result.speedMarks, lessThan(10));
    });

    test('not finishing earns nothing, however fast', () {
      expect(run(TraceMode.hard, completed: false, elapsed: Duration.zero).marks, 0);
    });
  });

  group('challenge judges shape alone', () {
    test('marks scale with shape accuracy', () {
      expect(run(TraceMode.special, analysis: _shape(1.0)).marks, 20);
      expect(run(TraceMode.special, analysis: _shape(0.5)).marks, 10);
      expect(run(TraceMode.special, analysis: _shape(0.0)).marks, 0);
    });

    test('speed and stroke order do not affect the mark', () {
      final quick = run(
        TraceMode.special,
        elapsed: const Duration(seconds: 1),
        analysis: const StrokeAnalysis(
          shapeAccuracy: 0.8,
          countAccuracy: 0,
          orderAccuracy: 0,
          directionAccuracy: 0,
        ),
      );
      final slow = run(
        TraceMode.special,
        elapsed: const Duration(minutes: 5),
        analysis: _shape(0.8),
      );
      expect(quick.marks, slow.marks);
      expect(quick.marks, 16);
    });
  });

  group('a character accumulates across modes', () {
    test('stars arrive at the cumulative thresholds', () {
      final thresholds = scoringConfigFixture.starThresholds;
      var progress = const LetterProgress(letterId: 'uyir_01');
      expect(progress.starsWith(thresholds), 0);

      progress = progress.withAttempt(run(TraceMode.easy));
      expect(progress.totalMarks, 25,
          reason: 'easy alone already clears the first star — see the '
              'per-mode group below');
      expect(progress.starsWith(thresholds), 1);

      progress = progress.withAttempt(run(TraceMode.medium));
      expect(progress.totalMarks, 50);
      expect(progress.starsWith(thresholds), 1);

      final fast = Duration(milliseconds: (2.0 * _pathLength * 1000).round());
      progress = progress.withAttempt(run(TraceMode.hard, elapsed: fast));
      expect(progress.totalMarks, 80);
      expect(progress.starsWith(thresholds), 2);

      progress = progress.withAttempt(run(TraceMode.special, analysis: _shape(1)));
      expect(progress.totalMarks, 100);
      expect(progress.starsWith(thresholds), 3);
    });

    test('every mode is worth a star entirely on its own, in any order', () {
      // The four modes are never locked (CLAUDE.md section 6) and a child
      // can open any of them first. Originally only hard (20 + 10 fluency =
      // 30) could clear the first-star bar alone — easy, medium and
      // especially challenge (max 20) could not, so a child who tried
      // challenge first and did well still walked away with nothing. The
      // first-star threshold moved down so whichever mode a child reaches
      // for first, doing well in it is never a dead end.
      final thresholds = scoringConfigFixture.starThresholds;

      final easyOnly =
          const LetterProgress(letterId: 'uyir_01').withAttempt(run(TraceMode.easy));
      expect(easyOnly.starsWith(thresholds), greaterThanOrEqualTo(1),
          reason: 'easy alone: ${easyOnly.totalMarks} marks');

      final mediumOnly =
          const LetterProgress(letterId: 'uyir_01').withAttempt(run(TraceMode.medium));
      expect(mediumOnly.starsWith(thresholds), greaterThanOrEqualTo(1),
          reason: 'medium alone: ${mediumOnly.totalMarks} marks');

      final fast = Duration(milliseconds: (2.0 * _pathLength * 1000).round());
      final hardOnly = const LetterProgress(letterId: 'uyir_01')
          .withAttempt(run(TraceMode.hard, elapsed: fast));
      expect(hardOnly.totalMarks, 30);
      expect(hardOnly.starsWith(thresholds), greaterThanOrEqualTo(1),
          reason: 'hard alone: ${hardOnly.totalMarks} marks');

      final challengeOnly = const LetterProgress(letterId: 'uyir_01')
          .withAttempt(run(TraceMode.special, analysis: _shape(1)));
      expect(challengeOnly.totalMarks, 20);
      expect(challengeOnly.starsWith(thresholds), greaterThanOrEqualTo(1),
          reason: 'challenge alone, drawn well: ${challengeOnly.totalMarks} marks');
    });

    test('a worse retry never takes marks away', () {
      // The screen reads this straight out of the store now, so what it shows
      // is whatever is best — going back to a letter and having a poor go at
      // it must not appear to undo the good one.
      final fast = Duration(milliseconds: (2.0 * _pathLength * 1000).round());
      var progress = const LetterProgress(letterId: 'uyir_01')
          .withAttempt(run(TraceMode.easy))
          .withAttempt(run(TraceMode.medium))
          .withAttempt(run(TraceMode.hard, elapsed: fast));
      final best = progress.totalMarks;

      progress = progress
          .withAttempt(run(TraceMode.hard, elapsed: const Duration(minutes: 5)))
          .withAttempt(run(TraceMode.easy));

      expect(progress.totalMarks, best);
    });

    test('a worse later attempt never takes marks away', () {
      var progress = const LetterProgress(letterId: 'uyir_01')
          .withAttempt(run(TraceMode.special, analysis: _shape(1.0)));
      expect(progress.marksFor(TraceMode.special), 20);

      progress = progress.withAttempt(run(TraceMode.special, analysis: _shape(0.2)));
      expect(progress.marksFor(TraceMode.special), 20);
    });

    test('repeating the same mode does not double-count it', () {
      var progress = const LetterProgress(letterId: 'uyir_01');
      progress = progress.withAttempt(run(TraceMode.easy));
      progress = progress.withAttempt(run(TraceMode.easy));
      expect(progress.totalMarks, 25);
    });
  });
}
