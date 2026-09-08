import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kids_tamil_ezhuthu_school/core/config/models/app_config.dart';
import 'package:kids_tamil_ezhuthu_school/data/models/stroke.dart';
import 'package:kids_tamil_ezhuthu_school/features/letter/trace/letter_paths.dart';
import 'package:kids_tamil_ezhuthu_school/features/letter/trace/trace_controller.dart';

/// Easy mode is led by a single waypoint: the child is shown one place to
/// reach, and it moves on only once they get there.
void main() {
  final canvasConfig = CanvasConfig.fromJson(
    (jsonDecode(File('assets/config/app_config.json').readAsStringSync())
        as Map<String, dynamic>)['canvas'] as Map<String, dynamic>,
  );
  final spacing = canvasConfig.waypointSpacingFactor;
  final minLead = canvasConfig.waypointMinLeadFactor;

  /// A straight horizontal stroke, so arc length and x are interchangeable.
  LetterPaths straightLetter() => LetterPaths.fromStrokes([
        Stroke(index: 0, points: List.generate(41, (i) => Offset(0.1 + i * 0.02, 0.5))),
      ]);

  void expectSamePoint(Offset? actual, Offset? expected, {String? reason}) {
    expect(actual, isNotNull, reason: reason);
    expect((actual! - expected!).distance, lessThan(1e-6), reason: reason);
  }

  test('before the stroke is touched, the waypoint is its very start', () {
    final paths = straightLetter();
    expectSamePoint(
        paths.nextWaypoint(0, 0, spacing, touched: false), paths.pointAt(0, 0));
  });

  test('touching the stroke moves the marker on at once', () {
    // The child should never be left staring at a marker under their own
    // fingertip: touching the first one is what reveals the next.
    final paths = straightLetter();
    final start = paths.pointAt(0, 0)!;
    final touched = paths.nextWaypoint(0, 0, spacing, touched: true)!;
    expect(touched.dx, greaterThan(start.dx));
    expectSamePoint(touched, paths.pointAt(0, spacing));
  });

  test('a waypoint is far enough ahead to be worth aiming at', () {
    // At the guide-dot spacing the marker landed inside a fingertip, which
    // is what made the guidance read as no guidance.
    expect(spacing, greaterThan(canvasConfig.dotSpacingFactor * 2));
    // ...and close enough that one movement can reach it.
    expect(spacing, lessThan(canvasConfig.traceLookaheadFactor));
  });

  /// Smallest lead seen while walking the whole stroke.
  double smallestLead(LetterPaths paths, double lead) {
    var smallest = double.infinity;
    final limit = paths.lengthOf(0) - spacing - lead;
    for (var d = 0.0; d < limit; d += spacing / 7) {
      final waypoint = paths.nextWaypoint(0, d, spacing, minLead: lead)!;
      final ahead = waypoint.dx - paths.pointAt(0, d)!.dx;
      if (ahead < smallest) smallest = ahead;
    }
    return smallest;
  }

  test('without a lead the marker ends up under the finger', () {
    // The behaviour being fixed, stated plainly so the fix cannot be undone
    // without this failing: the gap closes to nothing as the child arrives.
    expect(smallestLead(straightLetter(), 0), lessThan(0.01));
  });

  test('the lead keeps the marker clear of the hand at all times', () {
    // Deliberately an absolute figure rather than the config value, so this
    // still means something if the config is changed to zero.
    expect(smallestLead(straightLetter(), minLead), greaterThan(0.05));
  });

  test('and it never runs further ahead than one step plus the lead', () {
    final paths = straightLetter();
    final limit = paths.lengthOf(0) - spacing - minLead;
    for (var d = 0.0; d < limit; d += spacing / 7) {
      final waypoint = paths.nextWaypoint(0, d, spacing, minLead: minLead)!;
      final ahead = waypoint.dx - paths.pointAt(0, d)!.dx;
      expect(ahead, lessThanOrEqualTo(spacing + minLead + 1e-6), reason: 'at $d');
    }
  });

  test('the shipped lead is wider than the marker a hand would cover', () {
    expect(minLead, greaterThan(canvasConfig.waypointRadiusFactor * 2));
  });

  test('it stops at the end of the stroke rather than running off it', () {
    final paths = straightLetter();
    final length = paths.lengthOf(0);
    final end = paths.pointAt(0, length)!;

    // Once the last evenly spaced waypoint is behind the child, the end of
    // the stroke is the only place left to go. Where that last one falls
    // depends on how the spacing divides into the stroke, so step past it
    // rather than assuming.
    final lastRegular = (length / spacing).floor() * spacing;
    expectSamePoint(paths.nextWaypoint(0, lastRegular + spacing / 10, spacing), end);
    expectSamePoint(paths.nextWaypoint(0, length, spacing), end);

    // And it never points past the stroke, wherever the child has got to.
    for (var d = 0.0; d <= length; d += spacing / 5) {
      final waypoint = paths.nextWaypoint(0, d, spacing)!;
      expect(waypoint.dx, lessThanOrEqualTo(end.dx + 1e-6), reason: 'overshot at $d');
    }
  });

  test('reaching a waypoint is what moves it on', () {
    final paths = straightLetter();
    final controller = TraceController(letterPaths: paths, canvasConfig: canvasConfig);
    addTearDown(controller.dispose);

    Offset marker() => paths.nextWaypoint(
          controller.strokeIndex,
          controller.distance,
          spacing,
          touched: controller.touchedCurrentStroke,
        )!;

    final startPoint = paths.pointAt(0, 0)!;
    expectSamePoint(marker(), startPoint, reason: 'untouched: show where to begin');

    controller.startPointer(startPoint);
    final first = marker();
    expect(first.dx, greaterThan(startPoint.dx), reason: 'touching it reveals the next');

    // Still short of it, it stays put — the child has not arrived yet. The
    // controller advances in sample-sized steps, so landing a hair short of
    // a waypoint is the normal case, not an edge one.
    controller.movePointer(paths.pointAt(0, spacing * 0.9)!);
    expectSamePoint(marker(), first, reason: 'moved on before being reached');

    // Past it, and it moves on again.
    controller.movePointer(paths.pointAt(0, spacing * 1.2)!);
    expect(marker().dx, greaterThan(first.dx));
  });

  test('a second stroke starts the waypoints again at its own beginning', () {
    final paths = LetterPaths.fromStrokes([
      Stroke(index: 0, points: List.generate(21, (i) => Offset(0.1 + i * 0.03, 0.5))),
      Stroke(index: 1, points: List.generate(21, (i) => Offset(0.8, 0.2 + i * 0.02))),
    ]);
    // Distance zero on any stroke means it has not been started yet, so the
    // waypoint sits at that stroke's first point — not the letter's.
    expectSamePoint(
        paths.nextWaypoint(1, 0, spacing, touched: false), paths.pointAt(1, 0));
  });
}
