import 'dart:convert';
import 'dart:ui';

import 'glyph_skeleton.dart';
import 'order_solver.dart';

/// One arc of a stroke, and whether it runs against the arc's stored order.
class ArcStep {
  final int arcIndex;
  final bool reversed;

  const ArcStep(this.arcIndex, this.reversed);
}

/// A finished writing order for one letter: what goes into
/// `tools/orders.json` and, through `trace_letter.py`, into the letter's
/// stroke data.
class AuthoredOrder {
  final String letterId;
  final String char;
  final List<List<ArcStep>> strokes;

  const AuthoredOrder({
    required this.letterId,
    required this.char,
    required this.strokes,
  });

  factory AuthoredOrder.fromSolution(GlyphSkeleton skeleton, OrderSolution solution) {
    return AuthoredOrder(
      letterId: skeleton.letterId,
      char: skeleton.char,
      strokes: [
        for (final stroke in solution.strokes)
          [for (final visit in stroke.visits) ArcStep(visit.arcIndex, visit.reversed)],
      ],
    );
  }

  bool get isEmpty => strokes.isEmpty;

  /// The pen path this order describes, one polyline per stroke.
  ///
  /// Deliberately a line-for-line mirror of `build_stroke` in
  /// tools/trace_letter.py, including its nearer-end flip — the preview is
  /// only worth trusting if it shows what the Python will actually emit,
  /// quirks and all.
  List<List<Offset>> compose(GlyphSkeleton skeleton, double closedRatio) {
    final byIndex = {for (final arc in skeleton.arcs) arc.index: arc};
    final result = <List<Offset>>[];
    for (final stroke in strokes) {
      final path = <Offset>[];
      for (final step in stroke) {
        final arc = byIndex[step.arcIndex];
        if (arc == null) continue;
        var chain = arc.oriented(reversed: step.reversed);
        // A loop begins and ends in the same place, so the nearer-end test
        // below is decided by a pixel or two of rounding — a coin toss that
        // would silently overrule the direction the arc was drawn in. ஓ's
        // bottom circle came out backwards on a 2px margin. Join a loop
        // wherever the pen reaches it instead; direction is untouched.
        if (path.isNotEmpty && arc.isClosed(closedRatio, maxGap: _maxGap(skeleton))) {
          chain = SkeletonArc.rotateRing(chain, path.last);
        } else if (path.isNotEmpty &&
            (path.last - chain.first).distance > (path.last - chain.last).distance) {
          // Whichever end is nearer the pen is where this arc really starts.
          chain = chain.reversed.toList();
        }
        if (path.isNotEmpty && (path.last - chain.first).distance < 1e-6) {
          chain = chain.sublist(1);
        }
        path.addAll(chain);
      }
      if (path.length > 1) result.add(path);
    }
    return result;
  }

  /// Places where the pen would have to jump mid-stroke.
  ///
  /// Arcs that meet share their junction point exactly, so two arcs written
  /// back to back land on each other to within rounding. A real gap means
  /// the order skips a piece of the letter — usually a short connector the
  /// finger swung too wide to touch. Nothing else catches this: the arc was
  /// never nearest to any sample, so there is no crossing to report.
  List<OrderGap> discontinuities(
      GlyphSkeleton skeleton, double maxJoinGap, double closedRatio) {
    final byIndex = {for (final arc in skeleton.arcs) arc.index: arc};
    final gaps = <OrderGap>[];
    for (var s = 0; s < strokes.length; s++) {
      final path = <Offset>[];
      for (var i = 0; i < strokes[s].length; i++) {
        final arc = byIndex[strokes[s][i].arcIndex];
        if (arc == null) continue;
        var chain = arc.oriented(reversed: strokes[s][i].reversed);
        if (path.isNotEmpty) {
          double gap;
          if (arc.isClosed(closedRatio, maxGap: _maxGap(skeleton))) {
            chain = SkeletonArc.rotateRing(chain, path.last);
            gap = (path.last - chain.first).distance;
          } else {
            final toStart = (path.last - chain.first).distance;
            final toEnd = (path.last - chain.last).distance;
            if (toStart > toEnd) chain = chain.reversed.toList();
            gap = toStart < toEnd ? toStart : toEnd;
          }
          if (gap > maxJoinGap) {
            gaps.add(OrderGap(strokeIndex: s, stepIndex: i, distance: gap));
          }
        }
        path.addAll(chain);
      }
    }
    return gaps;
  }

  /// The `tools/orders.json` entry, ready to paste.
  Map<String, dynamic> toJson() => {
        letterId: {
          'char': char,
          'strokes': [
            for (final stroke in strokes)
              [
                for (final step in stroke) [step.arcIndex, step.reversed],
              ],
          ],
        },
      };

  String toPrettyJson() => const JsonEncoder.withIndent('  ').convert(toJson());

  /// A one-line summary for the console, e.g. `1 -> 2 -> 6R | 3R -> 4`.
  String get summary => strokes
      .map((s) => s.map((e) => '${e.arcIndex}${e.reversed ? 'R' : ''}').join(' → '))
      .join('  |  ');
}

/// Half a tube width: how near an arc's two ends must be to count as
/// meeting. Mirrors CLOSED_ARC_MAX_GAP_FACTOR in tools/trace_letter.py.
double _maxGap(GlyphSkeleton skeleton) => skeleton.tubeWidthFactor * 0.5;

/// A jump the pen would have to make between two arcs of one stroke.
class OrderGap {
  final int strokeIndex;

  /// Which step of the stroke the pen jumps *into*.
  final int stepIndex;

  final double distance;

  const OrderGap({
    required this.strokeIndex,
    required this.stepIndex,
    required this.distance,
  });
}
