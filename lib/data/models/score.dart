import '../../core/config/models/scoring_config.dart';
import '../../core/config/models/trace_mode.dart';

/// How closely one attempt matched the reference, component by component.
///
/// Only [shapeAccuracy] earns marks (in challenge mode). The rest are kept
/// because stroke order and direction are real Tamil handwriting pedagogy —
/// they are recorded so the Parent Zone report can show whether a child is
/// forming letters correctly, even though they never affect the score.
class StrokeAnalysis {
  final double shapeAccuracy;
  final double countAccuracy;
  final double orderAccuracy;
  final double directionAccuracy;

  const StrokeAnalysis({
    required this.shapeAccuracy,
    required this.countAccuracy,
    required this.orderAccuracy,
    required this.directionAccuracy,
  });

  static const zero = StrokeAnalysis(
    shapeAccuracy: 0,
    countAccuracy: 0,
    orderAccuracy: 0,
    directionAccuracy: 0,
  );
}

/// What a single attempt earned.
class AttemptResult {
  final TraceMode mode;
  final int marks;
  final int maxMarks;

  /// Present when the attempt was analysed against the reference strokes.
  final StrokeAnalysis? analysis;

  /// The fluency part of the hard-mode marks, for explaining the result.
  final int speedMarks;

  const AttemptResult({
    required this.mode,
    required this.marks,
    required this.maxMarks,
    this.analysis,
    this.speedMarks = 0,
  });
}

/// Everything a child has earned on one character, across all four modes.
///
/// Each mode keeps its best result, so a later worse attempt never takes
/// marks away — see CLAUDE.md section 11, "no streak-loss guilt".
class LetterProgress {
  final String letterId;
  final Map<TraceMode, int> marksByMode;

  const LetterProgress({required this.letterId, this.marksByMode = const {}});

  int marksFor(TraceMode mode) => marksByMode[mode] ?? 0;

  int get totalMarks => marksByMode.values.fold(0, (a, b) => a + b);

  int starsWith(StarThresholds thresholds) => thresholds.starsFor(totalMarks);

  /// Records an attempt, keeping whichever result was better.
  LetterProgress withAttempt(AttemptResult result) {
    final existing = marksFor(result.mode);
    if (result.marks <= existing) return this;
    return LetterProgress(
      letterId: letterId,
      marksByMode: {...marksByMode, result.mode: result.marks},
    );
  }
}
