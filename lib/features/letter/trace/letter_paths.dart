import 'dart:ui';

import '../../../data/models/stroke.dart';

/// Where a trace currently sits: how far along which stroke.
class TracePosition {
  final int strokeIndex;

  /// Arc length already covered on [strokeIndex], in normalized units.
  final double distance;

  const TracePosition(this.strokeIndex, this.distance);

  static const zero = TracePosition(0, 0);
}

/// The reference letter as drawable geometry.
///
/// Stroke data is stored as normalized 0..1 polylines; this turns each one
/// into a [Path] plus its [PathMetric] so the canvas can measure arc length,
/// extract the already-traced portion, and look up the point at any distance.
/// Everything stays in normalized space — the canvas scales once at paint
/// time, so a letter looks identical at any size.
/// One stroke's geometry: a line to drag along, or a dot to touch.
///
/// A filled dot — the puḷḷi on every mei letter, and both of ஈ's marks — has
/// a medial axis one point wide, so it arrives as a single-point stroke.
/// There is no path to follow and nothing to drag across; it is one mark,
/// made or not made.
class _TraceStroke {
  final Path? path;
  final PathMetric? metric;
  final Offset? dot;

  /// A dot's own diameter, when the stroke data gives one.
  final double? dotWidth;

  const _TraceStroke.line(Path this.path, PathMetric this.metric)
      : dot = null,
        dotWidth = null;
  const _TraceStroke.dot(Offset this.dot, this.dotWidth)
      : path = null,
        metric = null;

  bool get isDot => dot != null;
}

class LetterPaths {
  final List<_TraceStroke> _strokes;

  /// What a dot counts as when strokes are weighed by length.
  final double dotLength;

  LetterPaths._(this._strokes, this.dotLength);

  /// [dotLength] is [CanvasConfig.dotStrokeLengthFactor] — see there for why
  /// a dot needs a notional length at all.
  factory LetterPaths.fromStrokes(List<Stroke> strokes, {double dotLength = 0}) {
    final out = <_TraceStroke>[];
    for (final stroke in strokes) {
      final points = stroke.points;
      if (points.isEmpty) continue;
      // One point is a dot, deliberately: tools/trace_letter.py collapses a
      // dot back to its centre rather than shipping the short segment the
      // skeleton carries for the authoring screen's benefit.
      if (points.length == 1) {
        out.add(_TraceStroke.dot(points.first, stroke.width));
        continue;
      }
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final p in points.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      final metricList = path.computeMetrics().toList();
      if (metricList.isEmpty) continue;
      out.add(_TraceStroke.line(path, metricList.first));
    }
    return LetterPaths._(out, dotLength);
  }

  int get strokeCount => _strokes.length;

  bool get isEmpty => _strokes.isEmpty;

  /// Whether [strokeIndex] is a dot, completed by a touch rather than a drag.
  bool isDot(int strokeIndex) => _strokes[strokeIndex].isDot;

  /// Where a dot sits, or null if [strokeIndex] is a line.
  Offset? dotCentre(int strokeIndex) => _strokes[strokeIndex].dot;

  /// A dot's own diameter, or null to fall back to the letter's tube width.
  double? dotWidth(int strokeIndex) => _strokes[strokeIndex].dotWidth;

  /// The drawable path of [strokeIndex], or null for a dot.
  Path? pathAt(int strokeIndex) => _strokes[strokeIndex].path;

  double lengthOf(int strokeIndex) =>
      _strokes[strokeIndex].metric?.length ?? dotLength;

  /// Point on [strokeIndex] at arc length [distance]. A dot is the same
  /// point wherever you ask.
  Offset? pointAt(int strokeIndex, double distance) {
    final stroke = _strokes[strokeIndex];
    if (stroke.isDot) return stroke.dot;
    final metric = stroke.metric!;
    final clamped = distance.clamp(0.0, metric.length);
    return metric.getTangentForOffset(clamped)?.position;
  }

  /// The leading [distance] of [strokeIndex] as its own path — used to draw
  /// the portion the child has already traced. Empty for a dot, which is
  /// painted as a circle instead.
  Path extractUpTo(int strokeIndex, double distance) {
    final metric = _strokes[strokeIndex].metric;
    if (metric == null) return Path();
    return metric.extractPath(0, distance.clamp(0.0, metric.length));
  }

  /// The one place the child is being asked to reach next on [strokeIndex],
  /// given how far along they already are.
  ///
  /// Until the stroke has been touched the answer is its very beginning —
  /// every stroke starts somewhere else on the page, so the child is shown
  /// where to put their finger before being shown where to take it. Once
  /// they are on it, the marker jumps a whole [spacing] ahead and stays
  /// there until they arrive, then jumps again.
  ///
  /// [spacing] is much wider than the guide dots. At the dot spacing the
  /// marker sits under the child's own fingertip and shows them where they
  /// already are, which is no guidance at all.
  /// [minLead] keeps the marker that far ahead of the finger at all times:
  /// it skips to the following waypoint once the child is nearly on this
  /// one, because otherwise the gap closes to nothing as they arrive and
  /// their own hand covers what they are aiming at.
  Offset? nextWaypoint(
    int strokeIndex,
    double distance,
    double spacing, {
    bool touched = true,
    double minLead = 0,
  }) {
    if (spacing <= 0 || strokeIndex >= _strokes.length) return null;
    final stroke = _strokes[strokeIndex];
    // A dot is the only place to go on its own stroke, touched or not.
    if (stroke.isDot) return stroke.dot;
    final metric = stroke.metric!;
    if (!touched && distance <= 0) return metric.getTangentForOffset(0)?.position;
    final ahead = (((distance + minLead) / spacing).floor() + 1) * spacing;
    return metric
        .getTangentForOffset(ahead >= metric.length ? metric.length : ahead)
        ?.position;
  }

  /// Evenly spaced points along [strokeIndex], used for the guide dots.
  ///
  /// None for a dot stroke: guide dots say "drag this way", and there is no
  /// way to drag. The mark itself is the target.
  List<Offset> dotsAlong(int strokeIndex, double spacing) {
    final metric = _strokes[strokeIndex].metric;
    final result = <Offset>[];
    if (metric == null || spacing <= 0) return result;
    for (var d = 0.0; d <= metric.length; d += spacing) {
      final t = metric.getTangentForOffset(d);
      if (t != null) result.add(t.position);
    }
    return result;
  }

  /// Bounding box across every stroke, for sizing the trace gradient.
  Rect get bounds {
    Rect? total;
    for (final stroke in _strokes) {
      final box = stroke.isDot
          ? Rect.fromCircle(center: stroke.dot!, radius: 0)
          : stroke.path!.getBounds();
      total = total == null ? box : total.expandToInclude(box);
    }
    return total ?? Rect.zero;
  }
}
