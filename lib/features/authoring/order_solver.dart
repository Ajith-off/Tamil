import 'dart:math' as math;
import 'dart:ui';

import '../../core/config/models/authoring_config.dart';
import 'glyph_skeleton.dart';

/// Turns a drawn finger path into a writing order for a glyph's skeleton.
///
/// The font supplies the shape and nothing else; which arc is written first,
/// and in which direction, is a handwriting fact no font contains. Deriving
/// it from a handwriting animation failed three times over, because the
/// animation and the font are different letterforms and point-to-point
/// matching between them is unreliable (HANDOFF.md).
///
/// Drawing supplies the order in the *same* coordinate space as the target,
/// which is why this works where that did not. And because the answer is a
/// list of arc indices rather than fresh geometry, the shape that ships is
/// still the font's own medial axis, exact — a shaky finger costs nothing.
class OrderSolver {
  final GlyphSkeleton skeleton;
  final SnapConfig config;

  const OrderSolver({required this.skeleton, required this.config});

  /// [drawnStrokes] are raw finger paths in normalized 0..1 space, already
  /// split at pen lifts.
  OrderSolution solve(List<List<Offset>> drawnStrokes) {
    final maxSnap = config.snapDistanceFor(skeleton.tubeWidthFactor);
    final strokes = <AuthoredStroke>[];
    final ignored = <ArcVisit>[];
    var stranded = 0;
    var sampled = 0;

    for (final drawn in drawnStrokes) {
      final samples = resample(drawn, config.resampleSpacing);
      sampled += samples.length;

      // Nearest arc per sample; null where the finger was over nothing.
      final hits = <ArcHit?>[];
      for (final sample in samples) {
        final hit = skeleton.nearestArc(sample);
        if (hit == null || hit.distance > maxSnap) {
          stranded++;
          hits.add(null);
        } else {
          hits.add(hit);
        }
      }

      final resolved = _visitsFrom(hits);
      ignored.addAll(resolved.ignored);
      if (resolved.visits.isNotEmpty) strokes.add(AuthoredStroke(resolved.visits));
    }

    final visited = {
      for (final stroke in strokes)
        for (final visit in stroke.visits) visit.arcIndex,
    };

    return OrderSolution(
      strokes: strokes,
      unvisitedArcs: [
        for (final arc in skeleton.arcs)
          if (!visited.contains(arc.index)) arc.index,
      ],
      strandedSamples: stranded,
      totalSamples: sampled,
      ignoredCrossings: ignored,
    );
  }

  _Resolved _visitsFrom(List<ArcHit?> hits) {
    // Consecutive samples on one arc are one run. A stranded sample breaks
    // the run but does not end the stroke — the finger may wander off the
    // letter and come back.
    var runs = <_Run>[];
    for (final hit in hits) {
      if (hit == null) {
        runs.add(_Run.gap());
        continue;
      }
      if (runs.isNotEmpty && runs.last.arcIndex == hit.arcIndex) {
        runs.last.ts.add(hit.t);
      } else {
        runs.add(_Run(hit.arcIndex)..ts.add(hit.t));
      }
    }
    // Every run that gets discarded is recorded. Whatever the reason, a
    // dropped run means the finger touched an arc and the order will not say
    // so, and the one time that matters is the time it was not noise.
    final ignored = <ArcVisit>[];
    final longEnough = <_Run>[];
    for (final run in runs.where((r) => !r.isGap)) {
      if (run.ts.length < config.minSamplesPerArc) {
        ignored.add(_describe(run, _arc(run.arcIndex)));
      } else {
        longEnough.add(run);
      }
    }

    // Where two arcs meet, a finger rounding the corner sits nearer the arc
    // it is leaving than the one it is on, for as long as it takes to get
    // clear of the junction — enough samples that counting them cannot tell
    // the crossing from a real visit. How much of the arc got covered can:
    // running the length of an arc is what writing it means, and a spec can
    // only name whole arcs anyway, so a fragment is unusable either way.
    final kept = <_Run>[];
    for (final run in _merge(longEnough)) {
      final visit = _describe(run, _arc(run.arcIndex));
      if (visit.coverage < config.minArcCoverage) {
        ignored.add(visit);
      } else {
        kept.add(run);
      }
    }

    return _Resolved(
      visits: [for (final run in _merge(kept)) _describe(run, _arc(run.arcIndex))],
      ignored: ignored,
    );
  }

  SkeletonArc _arc(int index) => skeleton.arcs.firstWhere((a) => a.index == index);

  /// Join runs that ended up adjacent on the same arc — either side of a
  /// dropped crossing, or of a wobble that briefly favoured a neighbour.
  static List<_Run> _merge(Iterable<_Run> runs) {
    final merged = <_Run>[];
    for (final run in runs) {
      if (merged.isNotEmpty && merged.last.arcIndex == run.arcIndex) {
        merged.last.ts.addAll(run.ts);
      } else {
        merged.add(_Run(run.arcIndex)..ts.addAll(run.ts));
      }
    }
    return merged;
  }

  ArcVisit _describe(_Run run, SkeletonArc arc) {
    final closed = arc.isClosed(config.closedArcRatio);
    final unwrapped = _unwrap(run.ts, closed: closed);
    final displacement = unwrapped.last - unwrapped.first;
    final span = unwrapped.reduce(math.max) - unwrapped.reduce(math.min);
    return ArcVisit(
      arcIndex: run.arcIndex,
      reversed: displacement < 0,
      coverage: span.abs().clamp(0.0, 1.0),
      entryT: run.ts.first,
      exitT: run.ts.last,
      sampleCount: run.ts.length,
    );
  }

  /// Position along a closed arc wraps from 1 back to 0, which would read as
  /// a huge jump backwards. Undo the wrap so direction and coverage measure
  /// the journey the finger actually made.
  static List<double> _unwrap(List<double> ts, {required bool closed}) {
    final out = <double>[ts.first];
    for (var i = 1; i < ts.length; i++) {
      var step = ts[i] - ts[i - 1];
      if (closed) {
        if (step > 0.5) {
          step -= 1;
        } else if (step < -0.5) {
          step += 1;
        }
      }
      out.add(out.last + step);
    }
    return out;
  }

  /// Even out point density, so an arc collects samples in proportion to how
  /// much of it was covered rather than to how slowly the finger moved.
  /// Mirrors `resample` in tools/trace_letter.py.
  static List<Offset> resample(List<Offset> points, double spacing) {
    if (points.length < 2 || spacing <= 0) return List.of(points);
    final out = <Offset>[points.first];
    var carry = 0.0;
    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];
      final segment = (b - a).distance;
      if (segment == 0) continue;
      var travelled = spacing - carry;
      while (travelled <= segment) {
        out.add(a + (b - a) * (travelled / segment));
        travelled += spacing;
      }
      carry = (carry + segment) % spacing;
    }
    if ((out.last - points.last).distance > spacing * 0.25) out.add(points.last);
    return out;
  }
}

class _Run {
  final int arcIndex;
  final List<double> ts = [];
  bool get isGap => arcIndex < 0;

  _Run(this.arcIndex);

  _Run.gap() : arcIndex = -1;
}

class _Resolved {
  final List<ArcVisit> visits;
  final List<ArcVisit> ignored;

  const _Resolved({required this.visits, required this.ignored});
}

/// One arc, written once, in one direction.
class ArcVisit {
  final int arcIndex;

  /// Whether the finger ran against the arc's stored point order.
  final bool reversed;

  /// Fraction of the arc the finger covered.
  final double coverage;

  final double entryT;
  final double exitT;
  final int sampleCount;

  const ArcVisit({
    required this.arcIndex,
    required this.reversed,
    required this.coverage,
    required this.entryT,
    required this.exitT,
    required this.sampleCount,
  });
}

/// One pen-down to pen-up: the arcs crossed, in order.
class AuthoredStroke {
  final List<ArcVisit> visits;

  const AuthoredStroke(this.visits);
}

class OrderSolution {
  final List<AuthoredStroke> strokes;

  /// Arcs the finger never went near. Usually a missed piece of the letter,
  /// occasionally a skeleton artefact worth looking at.
  final List<int> unvisitedArcs;

  /// Samples that were over no arc at all — expected while crossing between
  /// the separate pieces of a letter like ஃ, suspicious otherwise.
  final int strandedSamples;

  final int totalSamples;

  /// Arcs the finger clipped without really writing — dropped from the order,
  /// but reported, because one of them might be a piece genuinely missed.
  final List<ArcVisit> ignoredCrossings;

  const OrderSolution({
    required this.strokes,
    required this.unvisitedArcs,
    required this.strandedSamples,
    required this.totalSamples,
    required this.ignoredCrossings,
  });

  bool get isEmpty => strokes.isEmpty;

  List<ArcVisit> get allVisits => [for (final s in strokes) ...s.visits];

  /// An arc written more than once. Legitimate — அ runs back along its
  /// centre line — but worth seeing before accepting.
  List<int> get repeatedArcs {
    final counts = <int, int>{};
    for (final visit in allVisits) {
      counts[visit.arcIndex] = (counts[visit.arcIndex] ?? 0) + 1;
    }
    return [
      for (final entry in counts.entries)
        if (entry.value > 1) entry.key,
    ]..sort();
  }
}
