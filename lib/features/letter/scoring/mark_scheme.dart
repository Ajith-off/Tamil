import 'dart:math' as math;

import '../../../core/config/models/scoring_config.dart';
import '../../../core/config/models/trace_mode.dart';
import '../../../data/models/score.dart';

/// Turns one finished attempt into marks.
///
/// The 100 marks for a character are split across the four modes (see
/// [MarksConfig]): easy and medium pay for completion, hard adds a fluency
/// bonus, and challenge is the only mode that judges the letter's shape.
class MarkScheme {
  final ScoringConfig config;

  const MarkScheme(this.config);

  AttemptResult evaluate({
    required TraceMode mode,
    required bool completed,
    required Duration elapsed,
    required double pathLength,
    StrokeAnalysis? analysis,
  }) {
    final marks = config.marks;
    switch (mode) {
      case TraceMode.easy:
        return AttemptResult(
          mode: mode,
          marks: completed ? marks.easyCompletion : 0,
          maxMarks: marks.easyCompletion,
          analysis: analysis,
        );

      case TraceMode.medium:
        return AttemptResult(
          mode: mode,
          marks: completed ? marks.mediumCompletion : 0,
          maxMarks: marks.mediumCompletion,
          analysis: analysis,
        );

      case TraceMode.hard:
        if (!completed) {
          return AttemptResult(
            mode: mode,
            marks: 0,
            maxMarks: marks.hardCompletion + marks.hardSpeed,
            analysis: analysis,
          );
        }
        final speed = _speedMarks(elapsed: elapsed, pathLength: pathLength);
        return AttemptResult(
          mode: mode,
          marks: marks.hardCompletion + speed,
          maxMarks: marks.hardCompletion + marks.hardSpeed,
          analysis: analysis,
          speedMarks: speed,
        );

      case TraceMode.special:
        // Shape alone, exactly as a written exam would judge it.
        final shape = analysis?.shapeAccuracy ?? 0;
        return AttemptResult(
          mode: mode,
          marks: (shape * marks.challengeShape).round(),
          maxMarks: marks.challengeShape,
          analysis: analysis,
        );
    }
  }

  /// Full bonus at or under the fast pace, none at or over the slow pace,
  /// sliding linearly between. Never negative — a slow, careful child simply
  /// misses the bonus, they are not penalised for taking their time.
  int _speedMarks({required Duration elapsed, required double pathLength}) {
    if (pathLength <= 0) return 0;
    final secondsPerUnit = (elapsed.inMilliseconds / 1000) / pathLength;
    final fast = config.speed.fastSecondsPerUnitLength;
    final slow = config.speed.slowSecondsPerUnitLength;
    if (slow <= fast) return config.marks.hardSpeed;
    final fraction = ((slow - secondsPerUnit) / (slow - fast)).clamp(0.0, 1.0);
    return (fraction * config.marks.hardSpeed).round();
  }

  /// Marks available for a mode, used to show "x / y" while practising.
  int maxMarksFor(TraceMode mode) {
    final marks = config.marks;
    return switch (mode) {
      TraceMode.easy => marks.easyCompletion,
      TraceMode.medium => marks.mediumCompletion,
      TraceMode.hard => marks.hardCompletion + marks.hardSpeed,
      TraceMode.special => marks.challengeShape,
    };
  }

  int get totalMarks => math.max(config.marks.total, 1);
}
