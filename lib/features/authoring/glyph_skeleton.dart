import 'dart:math' as math;
import 'dart:ui';

/// One arc of a glyph's medial axis, as written by `tools/export_skeletons.py`.
///
/// An arc is undirected: [points] runs from one end to the other, but that
/// order is an artefact of how the skeleton was walked, not a writing
/// direction. Supplying the direction is the whole point of the authoring
/// screen.
class SkeletonArc {
  /// Position in the arc list. This is the number the diagram labels, the
  /// number `trace_letter.ORDERS` names, and the number an authored order
  /// reports back — all three must agree.
  final int index;

  final List<Offset> points;

  /// Arc length from [points].first to each point, so a position along the
  /// arc can be turned into a 0..1 fraction without re-walking it.
  final List<double> _cumulative;

  final double length;

  SkeletonArc._(this.index, this.points, this._cumulative, this.length);

  factory SkeletonArc({required int index, required List<Offset> points}) {
    final cumulative = <double>[0];
    var total = 0.0;
    for (var i = 1; i < points.length; i++) {
      total += (points[i] - points[i - 1]).distance;
      cumulative.add(total);
    }
    return SkeletonArc._(index, points, cumulative, total);
  }

  factory SkeletonArc.fromJson(Map<String, dynamic> json) {
    return SkeletonArc(
      index: (json['index'] as num).toInt(),
      points: (json['points'] as List<dynamic>)
          .map((p) => Offset(
                ((p as Map<String, dynamic>)['x'] as num).toDouble(),
                (p['y'] as num).toDouble(),
              ))
          .toList(),
    );
  }

  /// True when the arc closes on itself — a bowl or a dot. Position along a
  /// closed arc wraps, so direction has to be read by unwrapping.
  ///
  /// Judged against the arc's own length, never an absolute distance: a loop
  /// is long and returns to where it began, while a short connector's ends
  /// are close together simply because it is short. அ's arc 6 is a 22px
  /// straight line whose ends are 23px apart, and an absolute tolerance
  /// called it a loop.
  /// [maxGap] additionally requires the two ends to actually meet. The ratio
  /// alone called ஆ's bottom curl a ring — 997px long with its ends 133px
  /// apart — and closing it drew a segment the font does not contain, welding
  /// the curl to the vertical bar. A real loop's ends sit on the same node.
  /// Mirrors `is_closed` in tools/trace_letter.py, which is what actually
  /// ships; the replay is only worth watching if it agrees with that.
  bool isClosed(double ratio, {double? maxGap}) {
    if (points.length <= 2 || length <= 0) return false;
    final gap = (points.last - points.first).distance;
    if (maxGap != null && gap > maxGap) return false;
    return gap <= length * ratio;
  }

  /// Nearest point on this arc to [p]: how far away it is, and where along
  /// the arc it lands as a 0..1 fraction. Null for a degenerate arc.
  ArcHit? nearest(Offset p) {
    if (points.length < 2 || length <= 0) return null;
    var bestDistance = double.infinity;
    var bestAlong = 0.0;
    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];
      final ab = b - a;
      final lengthSquared = ab.dx * ab.dx + ab.dy * ab.dy;
      if (lengthSquared == 0) continue;
      final ap = p - a;
      final t = ((ap.dx * ab.dx + ap.dy * ab.dy) / lengthSquared).clamp(0.0, 1.0);
      final projection = a + ab * t;
      final distance = (p - projection).distance;
      if (distance < bestDistance) {
        bestDistance = distance;
        bestAlong = _cumulative[i] + (ab.distance * t);
      }
    }
    if (bestDistance.isInfinite) return null;
    return ArcHit(arcIndex: index, distance: bestDistance, t: bestAlong / length);
  }

  /// The arc's points, reversed if asked — the geometry of one visit.
  List<Offset> oriented({required bool reversed}) =>
      reversed ? points.reversed.toList() : List.of(points);

  /// Re-start a closed arc at whichever of its points is nearest [pen].
  ///
  /// A loop has no inherent beginning — the pen joins it wherever it arrives
  /// and comes back round to the same place. Pinning it to the stored first
  /// point instead leaves a gap of however far that point happens to be.
  /// Direction is untouched. Mirrors `rotate_ring` in trace_letter.py.
  static List<Offset> rotateRing(List<Offset> chain, Offset pen) {
    final ring = (chain.first - chain.last).distance < 1e-9
        ? chain.sublist(0, chain.length - 1)
        : List<Offset>.of(chain);
    if (ring.length < 2) return List.of(chain);
    var start = 0;
    var best = double.infinity;
    for (var i = 0; i < ring.length; i++) {
      final d = (pen - ring[i]).distance;
      if (d < best) {
        best = d;
        start = i;
      }
    }
    return [...ring.sublist(start), ...ring.sublist(0, start), ring[start]];
  }
}

/// Where a drawn sample landed on the skeleton.
class ArcHit {
  final int arcIndex;
  final double distance;

  /// Position along the arc, 0 at its first point, 1 at its last.
  final double t;

  const ArcHit({required this.arcIndex, required this.distance, required this.t});
}

/// A glyph's medial axis: arcs plus the metrics needed to draw it.
class GlyphSkeleton {
  final String letterId;
  final String char;
  final List<SkeletonArc> arcs;

  /// Tube thickness for this letter as a fraction of the canvas, matching
  /// what the final stroke data will carry.
  final double tubeWidthFactor;

  /// Disconnected pieces of the glyph — a floor on how many pen lifts the
  /// letter needs. ஃ is three dots, so three.
  final int componentCount;

  const GlyphSkeleton({
    required this.letterId,
    required this.char,
    required this.arcs,
    required this.tubeWidthFactor,
    required this.componentCount,
  });

  factory GlyphSkeleton.fromJson(Map<String, dynamic> json) {
    return GlyphSkeleton(
      letterId: json['letterId'] as String,
      char: json['char'] as String,
      arcs: (json['arcs'] as List<dynamic>)
          .map((a) => SkeletonArc.fromJson(a as Map<String, dynamic>))
          .toList(),
      tubeWidthFactor: (json['tubeWidthFactor'] as num).toDouble(),
      componentCount: (json['componentCount'] as num).toInt(),
    );
  }

  /// Nearest arc to [p] across the whole skeleton.
  ArcHit? nearestArc(Offset p) {
    ArcHit? best;
    for (final arc in arcs) {
      final hit = arc.nearest(p);
      if (hit != null && (best == null || hit.distance < best.distance)) {
        best = hit;
      }
    }
    return best;
  }

  Rect get bounds {
    var left = double.infinity, top = double.infinity;
    var right = -double.infinity, bottom = -double.infinity;
    for (final arc in arcs) {
      for (final p in arc.points) {
        left = math.min(left, p.dx);
        top = math.min(top, p.dy);
        right = math.max(right, p.dx);
        bottom = math.max(bottom, p.dy);
      }
    }
    if (left.isInfinite) return Rect.zero;
    return Rect.fromLTRB(left, top, right, bottom);
  }
}

/// One entry in the letter picker.
class SkeletonIndexEntry {
  final String letterId;
  final String char;

  const SkeletonIndexEntry({required this.letterId, required this.char});

  factory SkeletonIndexEntry.fromJson(Map<String, dynamic> json) {
    return SkeletonIndexEntry(
      letterId: json['letterId'] as String,
      char: json['char'] as String,
    );
  }
}
