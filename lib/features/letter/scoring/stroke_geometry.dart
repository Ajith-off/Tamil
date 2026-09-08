import 'dart:math' as math;
import 'dart:ui';

/// Resamples [points] into exactly [n] points spaced evenly by arc length
/// along the polyline. Used so a user stroke (sampled at whatever rate the
/// touch driver delivered) and a reference stroke (authored at a different
/// point density) can be compared point-for-point.
List<Offset> resampleByArcLength(List<Offset> points, int n) {
  if (n <= 0) return const [];
  if (points.isEmpty) return List.filled(n, Offset.zero);
  if (points.length == 1) return List.filled(n, points.first);

  final cumulative = List<double>.filled(points.length, 0);
  for (var i = 1; i < points.length; i++) {
    cumulative[i] = cumulative[i - 1] + (points[i] - points[i - 1]).distance;
  }
  final total = cumulative.last;
  if (total == 0) return List.filled(n, points.first);

  final result = <Offset>[];
  var segment = 1;
  for (var k = 0; k < n; k++) {
    final target = total * k / (n - 1);
    while (segment < cumulative.length - 1 && cumulative[segment] < target) {
      segment++;
    }
    final segStart = cumulative[segment - 1];
    final segEnd = cumulative[segment];
    final segLength = segEnd - segStart;
    final t = segLength == 0 ? 0.0 : (target - segStart) / segLength;
    result.add(Offset.lerp(points[segment - 1], points[segment], t)!);
  }
  return result;
}

/// Mean Euclidean distance between two equal-length, index-aligned point
/// lists.
double meanPointDistance(List<Offset> a, List<Offset> b) {
  assert(a.length == b.length && a.isNotEmpty);
  var sum = 0.0;
  for (var i = 0; i < a.length; i++) {
    sum += (a[i] - b[i]).distance;
  }
  return sum / a.length;
}

/// [meanPointDistance], but tries [b] both forward and reversed and returns
/// whichever alignment is closer. Shape correctness shouldn't depend on
/// which end of the letter the child started drawing from — that's what
/// the separate direction score is for.
double meanPointDistanceBestOrientation(List<Offset> a, List<Offset> b) {
  final forward = meanPointDistance(a, b);
  final backward = meanPointDistance(a, b.reversed.toList());
  return math.min(forward, backward);
}

/// Every per-point nearest-neighbour distance from [from] to [to] — the raw
/// material both [meanNearestPointDistance] and [robustNearestPointDistance]
/// reduce down differently.
List<double> _nearestDistances(List<Offset> from, List<Offset> to) {
  return [
    for (final p in from)
      math.sqrt([
        for (final q in to) (p.dx - q.dx) * (p.dx - q.dx) + (p.dy - q.dy) * (p.dy - q.dy),
      ].reduce(math.min)),
  ];
}

/// How far apart two sets of points are, each measured to the nearest point
/// in the other and averaged both ways.
///
/// Index-aligned comparison asks "was the child at the same place at the same
/// moment", which is the wrong question for a freehand letter: draw the bar
/// of அ slightly longer than the reference and every point after it shifts,
/// so a letter that looks right measures badly. This asks the question that
/// matters instead — did the ink land on the letter, and did the letter get
/// covered — and it does not care about speed, stroke order, or how the
/// child divided the letter into strokes. Order and direction are scored
/// separately and deliberately earn no marks (CLAUDE.md section 5).
///
/// Measured in both directions on purpose. User-to-reference alone would let
/// a child draw one short arc inside the letter and score perfectly;
/// reference-to-user catches the parts they never covered.
double meanNearestPointDistance(List<Offset> a, List<Offset> b) {
  if (a.isEmpty || b.isEmpty) return double.infinity;
  double mean(List<double> ds) => ds.reduce((x, y) => x + y) / ds.length;
  return (mean(_nearestDistances(a, b)) + mean(_nearestDistances(b, a))) / 2;
}

/// Like [meanNearestPointDistance], but reduces each direction by its worst
/// (highest-percentile) distance instead of the average.
///
/// A mean is forgiving in a way that breaks shape *matching* specifically: a
/// wrong letter that happens to occupy the same general canvas region as the
/// right one gets most of its points near *something* in the reference, so
/// the average distance ends up close to a genuinely correct attempt's —
/// confirmed on-device, where a real child's clearly wrong doodle and their
/// correctly-shaped இ scored within a few percent of each other under the
/// mean. The parts that actually distinguish a wrong shape are the ones the
/// mean washes out: a curl the doodle never drew, or ink that strayed onto a
/// stroke the reference doesn't have there. The [percentile]-th worst
/// distance keeps that signal instead of averaging it away, while still
/// being smoother than a bare max (one wild outlier point from a jittery
/// finger shouldn't tank an otherwise-good attempt).
double robustNearestPointDistance(List<Offset> a, List<Offset> b, {double percentile = 0.85}) {
  if (a.isEmpty || b.isEmpty) return double.infinity;
  double atPercentile(List<double> ds) {
    final sorted = [...ds]..sort();
    final index = ((sorted.length - 1) * percentile).round();
    return sorted[index];
  }

  return (atPercentile(_nearestDistances(a, b)) + atPercentile(_nearestDistances(b, a))) / 2;
}

/// Average cosine similarity, mapped from [-1, 1] to [0, 1], between the
/// segment-to-segment displacement vectors of two equal-length,
/// index-aligned point lists. 1.0 means the two paths were traced in the
/// same direction; 0.0 means directly opposite.
double directionSimilarity(List<Offset> a, List<Offset> b) {
  assert(a.length == b.length);
  if (a.length < 2) return 0.5;
  var cosineSum = 0.0;
  var segments = 0;
  for (var i = 1; i < a.length; i++) {
    final va = a[i] - a[i - 1];
    final vb = b[i] - b[i - 1];
    final magA = va.distance;
    final magB = vb.distance;
    if (magA == 0 || magB == 0) continue;
    final cos = (va.dx * vb.dx + va.dy * vb.dy) / (magA * magB);
    cosineSum += cos.clamp(-1.0, 1.0);
    segments++;
  }
  if (segments == 0) return 0.5;
  final avgCos = cosineSum / segments;
  return (avgCos + 1) / 2;
}

/// Length of the longest strictly-increasing subsequence. Used to score
/// how much of the reference stroke order the child preserved.
int longestIncreasingSubsequenceLength(List<int> sequence) {
  if (sequence.isEmpty) return 0;
  final tails = <int>[];
  for (final value in sequence) {
    var lo = 0, hi = tails.length;
    while (lo < hi) {
      final mid = (lo + hi) ~/ 2;
      if (tails[mid] < value) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    if (lo == tails.length) {
      tails.add(value);
    } else {
      tails[lo] = value;
    }
  }
  return tails.length;
}
