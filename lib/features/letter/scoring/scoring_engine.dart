import 'dart:ui';

import '../../../core/config/models/scoring_config.dart';
import '../../../data/models/score.dart';
import '../../../data/models/stroke.dart';
import 'stroke_geometry.dart';

/// Measures how closely one drawing attempt (a list of strokes, each a raw
/// ordered list of normalized 0..1 points as captured off the canvas)
/// matches a letter's reference stroke data.
///
/// This only reports accuracy; turning accuracy into marks is
/// [MarkScheme]'s job. Every tolerance comes from [ScoringConfig]
/// (assets/config/scoring_config.json) — nothing is hardcoded here.
class ScoringEngine {
  final ScoringConfig config;

  const ScoringEngine(this.config);

  StrokeAnalysis analyse({
    required List<List<Offset>> userStrokes,
    required LetterStrokeData reference,
  }) {
    final n = config.engine.resamplePointCount;

    final cleanUserStrokes = userStrokes.where((s) => s.length >= 2).toList();
    final refStrokes = reference.strokes;

    if (cleanUserStrokes.isEmpty || refStrokes.isEmpty) {
      return StrokeAnalysis.zero;
    }

    final shapeAccuracy = _shapeAccuracy(cleanUserStrokes, refStrokes, n);
    final countAccuracy = _countAccuracy(cleanUserStrokes.length, refStrokes.length);
    final match = _matchStrokes(cleanUserStrokes, refStrokes, n);
    final orderAccuracy = _orderAccuracy(match, refStrokes.length);
    final directionAccuracy = _directionAccuracy(match, cleanUserStrokes, refStrokes, n);

    return StrokeAnalysis(
      shapeAccuracy: shapeAccuracy,
      countAccuracy: countAccuracy,
      orderAccuracy: orderAccuracy,
      directionAccuracy: directionAccuracy,
    );
  }

  /// Whole-attempt shape accuracy: how far the child's ink sits from the
  /// letter, and how much of the letter it covered.
  ///
  /// Each stroke is resampled to [n] points so a slow hand and a quick one
  /// weigh the same, then all the points are pooled and compared as sets
  /// (see [robustNearestPointDistance]).
  ///
  /// This used to concatenate every stroke into one path and compare
  /// point-for-point by index, which measured the wrong thing: draw அ's bar
  /// a little longer than the reference and every point after it is compared
  /// against the wrong part of the letter, so a good freehand attempt scored
  /// like a bad one. Whether the child started at the "wrong" end, or split
  /// the letter into different strokes, is not this score's business.
  ///
  /// The distance itself used to be the plain mean, which turned out too
  /// forgiving for shape *matching* specifically: a wrong letter that
  /// happens to occupy the same general canvas region as the right one
  /// still gets most of its points near *something* in the reference, so
  /// the average distance ends up close to a correctly-shaped attempt's —
  /// confirmed on a real device, where a clearly wrong doodle and a
  /// correctly-drawn இ scored within a few percent of each other. The 85th
  /// percentile keeps the signal the mean washes out — a curl the doodle
  /// never drew, or ink that strayed onto a stroke the reference doesn't
  /// have there — while still tolerating a handful of stray points from a
  /// jittery finger the way a bare max would not.
  double _shapeAccuracy(List<List<Offset>> userStrokes, List<Stroke> refStrokes, int n) {
    final userPoints = [for (final s in userStrokes) ...resampleByArcLength(s, n)];
    final refPoints = [for (final s in refStrokes) ...resampleByArcLength(s.points, n)];
    final distance = robustNearestPointDistance(userPoints, refPoints);
    final tolerance = config.engine.shapeToleranceRadius;
    return (1 - distance / tolerance).clamp(0.0, 1.0);
  }

  double _countAccuracy(int userCount, int refCount) {
    final diff = (userCount - refCount).abs();
    return (1 - diff * config.engine.countPenaltyPerExtraStroke).clamp(0.0, 1.0);
  }

  /// Greedily matches each reference stroke (in reference order) to the
  /// closest still-unmatched user stroke by resampled shape distance.
  /// Returns, for each reference stroke index, the matched user stroke
  /// index (or -1 if no user stroke was left to match).
  List<int> _matchStrokes(List<List<Offset>> userStrokes, List<Stroke> refStrokes, int n) {
    final resampledUser = userStrokes.map((s) => resampleByArcLength(s, n)).toList();
    final resampledRef = refStrokes.map((s) => resampleByArcLength(s.points, n)).toList();
    final used = List<bool>.filled(userStrokes.length, false);
    final matches = List<int>.filled(refStrokes.length, -1);

    for (var r = 0; r < resampledRef.length; r++) {
      var bestIndex = -1;
      var bestDistance = double.infinity;
      for (var u = 0; u < resampledUser.length; u++) {
        if (used[u]) continue;
        final distance = meanPointDistanceBestOrientation(resampledRef[r], resampledUser[u]);
        if (distance < bestDistance) {
          bestDistance = distance;
          bestIndex = u;
        }
      }
      if (bestIndex != -1) {
        used[bestIndex] = true;
        matches[r] = bestIndex;
      }
    }
    return matches;
  }

  /// Fraction of reference strokes whose matched user stroke preserves the
  /// reference drawing order (via longest increasing subsequence of the
  /// matched user indices).
  double _orderAccuracy(List<int> matches, int refCount) {
    if (refCount == 0) return 0;
    final matchedSequence = matches.where((m) => m != -1).toList();
    final lis = longestIncreasingSubsequenceLength(matchedSequence);
    return lis / refCount;
  }

  /// Average direction similarity across matched stroke pairs; unmatched
  /// reference strokes contribute zero.
  double _directionAccuracy(
    List<int> matches,
    List<List<Offset>> userStrokes,
    List<Stroke> refStrokes,
    int n,
  ) {
    if (refStrokes.isEmpty) return 0;
    var sum = 0.0;
    for (var r = 0; r < matches.length; r++) {
      final u = matches[r];
      if (u == -1) continue;
      final userResampled = resampleByArcLength(userStrokes[u], n);
      final refResampled = resampleByArcLength(refStrokes[r].points, n);
      sum += directionSimilarity(refResampled, userResampled);
    }
    return sum / refStrokes.length;
  }
}
