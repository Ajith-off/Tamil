import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kids_tamil_ezhuthu_school/core/config/models/authoring_config.dart';
import 'package:kids_tamil_ezhuthu_school/features/authoring/authored_order.dart';
import 'package:kids_tamil_ezhuthu_school/features/authoring/glyph_skeleton.dart';
import 'package:kids_tamil_ezhuthu_school/features/authoring/order_solver.dart';

/// The solver's job is to recover a writing order from a drawn path. The two
/// letters whose order is already hand-verified — அ and உ, checked against a
/// stroke-order reference and a filmstrip — are the only ground truth there
/// is, so the tests walk their known orders, draw over them like a wobbly
/// finger would, and insist the answer comes back.
void main() {
  late SnapConfig snap;

  setUpAll(() async {
    final raw = jsonDecode(await File('assets/config/authoring_config.json').readAsString())
        as Map<String, dynamic>;
    snap = SnapConfig.fromJson(raw['snap'] as Map<String, dynamic>);
  });

  Future<GlyphSkeleton> loadSkeleton(String letterId) async {
    final raw = await File('assets/authoring/skeletons/$letterId.json').readAsString();
    return GlyphSkeleton.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  /// tools/trace_letter.py ORDERS, as at the time of writing. These are the
  /// specs that produced the shipped stroke data.
  const knownOrders = <String, List<List<ArcStep>>>{
    'uyir_01': [
      [
        ArcStep(1, true),
        ArcStep(2, false),
        ArcStep(6, false),
        ArcStep(0, true),
        ArcStep(6, true),
        ArcStep(5, false),
      ],
      [ArcStep(3, false), ArcStep(4, false)],
    ],
    'uyir_05': [
      [ArcStep(1, true), ArcStep(0, true)],
    ],
  };

  /// Nudge every point sideways by a smooth wobble, so the solver is fed
  /// something a hand might produce rather than the exact centreline.
  List<Offset> wobble(List<Offset> path, double amplitude) {
    final out = <Offset>[];
    for (var i = 0; i < path.length; i++) {
      final ahead = path[math.min(i + 1, path.length - 1)];
      final behind = path[math.max(i - 1, 0)];
      final tangent = ahead - behind;
      final norm = tangent.distance;
      if (norm == 0) {
        out.add(path[i]);
        continue;
      }
      final normal = Offset(-tangent.dy / norm, tangent.dx / norm);
      out.add(path[i] + normal * (math.sin(i * 0.31) * amplitude));
    }
    return out;
  }

  for (final letterId in knownOrders.keys) {
    group(letterId, () {
      test('recovers the known writing order from a traced path', () async {
        final skeleton = await loadSkeleton(letterId);
        final known = AuthoredOrder(
          letterId: letterId,
          char: skeleton.char,
          strokes: knownOrders[letterId]!,
        );

        final drawn = known
            .compose(skeleton, snap.closedArcRatio)
            .map((s) => wobble(s, skeleton.tubeWidthFactor * 0.3))
            .toList();

        final solution = OrderSolver(skeleton: skeleton, config: snap).solve(drawn);
        final recovered = AuthoredOrder.fromSolution(skeleton, solution);

        expect(
          recovered.strokes.map((s) => s.map((e) => e.arcIndex).toList()).toList(),
          known.strokes.map((s) => s.map((e) => e.arcIndex).toList()).toList(),
          reason: 'arc sequence should survive the round trip\n'
              'known:     ${known.summary}\n'
              'recovered: ${recovered.summary}',
        );
      });

      test('the recovered order redraws the same letter', () async {
        final skeleton = await loadSkeleton(letterId);
        final known = AuthoredOrder(
          letterId: letterId,
          char: skeleton.char,
          strokes: knownOrders[letterId]!,
        );
        final original = known.compose(skeleton, snap.closedArcRatio);
        final drawn =
            original.map((s) => wobble(s, skeleton.tubeWidthFactor * 0.3)).toList();

        final solution = OrderSolver(skeleton: skeleton, config: snap).solve(drawn);
        final redrawn = AuthoredOrder.fromSolution(skeleton, solution).compose(skeleton, snap.closedArcRatio);

        expect(redrawn.length, original.length);
        for (var i = 0; i < original.length; i++) {
          expect(redrawn[i].length, original[i].length,
              reason: 'stroke $i should have the same point count');
          // A recovered direction flag may differ from the authored one where
          // build_stroke's nearer-end flip already decided the direction; what
          // has to match is the path itself.
          for (var j = 0; j < original[i].length; j++) {
            expect((redrawn[i][j] - original[i][j]).distance, lessThan(1e-9),
                reason: 'stroke $i point $j should land in the same place');
          }
        }
      });

      test('every arc of the letter is accounted for', () async {
        final skeleton = await loadSkeleton(letterId);
        final known = AuthoredOrder(
          letterId: letterId,
          char: skeleton.char,
          strokes: knownOrders[letterId]!,
        );
        final drawn = known
            .compose(skeleton, snap.closedArcRatio)
            .map((s) => wobble(s, skeleton.tubeWidthFactor * 0.3))
            .toList();

        final solution = OrderSolver(skeleton: skeleton, config: snap).solve(drawn);
        final expectedUnvisited = {
          for (final arc in skeleton.arcs) arc.index,
        }..removeAll(known.strokes.expand((s) => s).map((e) => e.arcIndex));

        expect(solution.unvisitedArcs.toSet(), expectedUnvisited);
        expect(solution.strandedSamples, 0,
            reason: 'a path traced along the letter never leaves it');
      });
    });
  }

  // A hand is not a plotter, so the order has to survive being drawn badly.
  // It survives a wobble of up to about half the tube width. Past that, அ's
  // arc 6 — a 22px connector, 3% of the letter — is shorter than the wobble
  // is wide, and a finger swinging that far genuinely does miss it. No
  // threshold recovers an arc the finger did not go near, which is the whole
  // reason the screen makes you watch the preview before accepting.
  for (final amplitude in [0.25, 0.5]) {
    test('uyir_01 survives a wobble of ${amplitude}x the tube width', () async {
      final skeleton = await loadSkeleton('uyir_01');
      final known = AuthoredOrder(
        letterId: 'uyir_01',
        char: skeleton.char,
        strokes: knownOrders['uyir_01']!,
      );
      final drawn = known
          .compose(skeleton, snap.closedArcRatio)
          .map((s) => wobble(s, skeleton.tubeWidthFactor * amplitude))
          .toList();

      final recovered = AuthoredOrder.fromSolution(
        skeleton,
        OrderSolver(skeleton: skeleton, config: snap).solve(drawn),
      );

      expect(
        recovered.strokes.map((s) => s.map((e) => e.arcIndex).toList()).toList(),
        known.strokes.map((s) => s.map((e) => e.arcIndex).toList()).toList(),
        reason: 'recovered: ${recovered.summary}',
      );
    });
  }

  test('an arc lost to a wild wobble shows up as a gap in the order', () async {
    final skeleton = await loadSkeleton('uyir_01');
    final known = AuthoredOrder(
      letterId: 'uyir_01',
      char: skeleton.char,
      strokes: knownOrders['uyir_01']!,
    );
    final drawn = known
        .compose(skeleton, snap.closedArcRatio)
        .map((s) => wobble(s, skeleton.tubeWidthFactor * 1.0))
        .toList();

    final solution = OrderSolver(skeleton: skeleton, config: snap).solve(drawn);
    final recovered = AuthoredOrder.fromSolution(skeleton, solution);

    // At this amplitude the finger swings wider than arc 6 is long, and the
    // return pass over it is genuinely lost — no sample is ever nearest to
    // it, so there is no crossing to report either.
    expect(recovered.summary, isNot(contains('0R → 6R')));

    // What gives it away is that the surviving order no longer joins up.
    final gaps = recovered.discontinuities(skeleton, snap.maxJoinGap, snap.closedArcRatio);
    expect(gaps, isNotEmpty,
        reason: 'skipping arc 6 leaves arc 0 and arc 5 not meeting');
  });

  test('a good order joins up everywhere', () async {
    for (final letterId in knownOrders.keys) {
      final skeleton = await loadSkeleton(letterId);
      final known = AuthoredOrder(
        letterId: letterId,
        char: skeleton.char,
        strokes: knownOrders[letterId]!,
      );
      expect(known.discontinuities(skeleton, snap.maxJoinGap, snap.closedArcRatio), isEmpty,
          reason: '$letterId is hand-verified and should have no pen jumps');
    }
  });

  test('a loop keeps the direction it was drawn in', () async {
    // ஓ's bottom circle is a self-loop whose ends sit ~0.002 apart rather
    // than exactly together. That was enough for the nearer-end flip — which
    // asks which end of an arc is closer to the pen — to decide the
    // direction on rounding noise and overrule what was actually drawn.
    final skeleton = await loadSkeleton('uyir_11');
    final loop = skeleton.arcs.firstWhere((a) => a.isClosed(snap.closedArcRatio) && a.length > 0.5);

    // Reached from another arc, so the flip is in play.
    final approach = skeleton.arcs.firstWhere((a) =>
        a.index != loop.index &&
        ((a.points.last - loop.points.first).distance < snap.maxJoinGap ||
            (a.points.first - loop.points.first).distance < snap.maxJoinGap));

    List<Offset> compose(bool reversed) => AuthoredOrder(
          letterId: 'uyir_11',
          char: skeleton.char,
          strokes: [
            [ArcStep(approach.index, false), ArcStep(loop.index, reversed)],
          ],
        ).compose(skeleton, snap.closedArcRatio).single;

    final forward = compose(false);
    final backward = compose(true);

    expect(forward.length, backward.length);
    // A ring joined at the pen starts and ends in the same place whichever
    // way it is written, so the endpoints cannot tell the two apart — where
    // the pen is partway round can. If the nearer-end flip had overruled the
    // direction flag, the two paths would coincide at every point.
    var widest = 0.0;
    for (var i = 0; i < forward.length; i++) {
      final apart = (forward[i] - backward[i]).distance;
      if (apart > widest) widest = apart;
    }
    expect(widest, greaterThan(snap.maxJoinGap),
        reason: 'reversing a loop must actually reverse it');
  });

  test('a pen lift becomes a separate stroke', () async {
    final skeleton = await loadSkeleton('aaytham_01');
    // ஃ is three dots: three pen-downs, one arc each, nothing shared.
    final drawn = [
      for (final arc in skeleton.arcs) List<Offset>.of(arc.points),
    ];

    final solution = OrderSolver(skeleton: skeleton, config: snap).solve(drawn);

    expect(solution.strokes.length, 3);
    expect(solution.strokes.map((s) => s.visits.length), everyElement(1));
    expect(solution.unvisitedArcs, isEmpty);
  });

  test('drawing an arc backwards is reported as reversed', () async {
    final skeleton = await loadSkeleton('uyir_04'); // ஈ, three plain arcs
    final arc = skeleton.arcs.first;

    final forward = OrderSolver(skeleton: skeleton, config: snap)
        .solve([List<Offset>.of(arc.points)]);
    final backward = OrderSolver(skeleton: skeleton, config: snap)
        .solve([arc.points.reversed.toList()]);

    expect(forward.strokes.single.visits.single.reversed, isFalse);
    expect(backward.strokes.single.visits.single.reversed, isTrue);
  });

  test('a finger that strays off the letter is reported, not guessed at', () async {
    final skeleton = await loadSkeleton('uyir_04');
    final arc = skeleton.arcs.first;
    final strayed = [
      ...arc.points,
      // Off into the corner, well beyond any arc.
      for (var i = 1; i <= 20; i++) arc.points.last + Offset(i * 0.02, i * 0.02),
    ];

    final solution =
        OrderSolver(skeleton: skeleton, config: snap).solve([strayed]);

    expect(solution.strandedSamples, greaterThan(0));
    expect(solution.strokes.single.visits.first.arcIndex, arc.index);
  });
}
