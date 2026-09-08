import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kids_tamil_ezhuthu_school/data/models/stroke.dart';
import 'package:kids_tamil_ezhuthu_school/features/letter/scoring/scoring_engine.dart';

import 'scoring_fixtures.dart';

List<Offset> _circleStroke({
  required Offset center,
  required double radius,
  double startDeg = 0,
  double endDeg = 300,
  int n = 40,
}) {
  return List.generate(n, (i) {
    final t = i / (n - 1);
    final rad = (startDeg + (endDeg - startDeg) * t) * pi / 180;
    return Offset(center.dx + radius * cos(rad), center.dy + radius * sin(rad));
  });
}

void main() {
  final referencePoints = _circleStroke(center: const Offset(0.5, 0.5), radius: 0.3);
  final reference = LetterStrokeData(
    letterId: 'test_letter',
    strokes: [Stroke(index: 0, points: referencePoints)],
  );
  final engine = ScoringEngine(scoringConfigFixture);

  test('tracing the reference stroke almost exactly matches on every component', () {
    final result = engine.analyse(userStrokes: [referencePoints], reference: reference);

    expect(result.shapeAccuracy, greaterThan(0.99));
    expect(result.countAccuracy, equals(1.0));
    expect(result.orderAccuracy, equals(1.0));
    expect(result.directionAccuracy, greaterThan(0.99));
  });

  test('an unrelated scribble far from the reference scores low on shape', () {
    final scribble = [
      const Offset(0.05, 0.05),
      const Offset(0.08, 0.9),
      const Offset(0.12, 0.06),
      const Offset(0.15, 0.92),
    ];
    final result = engine.analyse(userStrokes: [scribble], reference: reference);
    expect(result.shapeAccuracy, lessThan(0.2));
  });

  test('drawing the same shape in reverse direction hurts direction accuracy specifically', () {
    // A straight stroke isolates the direction signal cleanly: per-segment
    // tangents are constant along its length, so reversing it flips every
    // tangent by exactly 180 degrees with no curvature-driven ambiguity.
    final straightLine = List.generate(40, (i) => Offset(0.1 + i * 0.02, 0.1 + i * 0.02));
    final straightReference = LetterStrokeData(
      letterId: 'straight_test_letter',
      strokes: [Stroke(index: 0, points: straightLine)],
    );

    final result = engine.analyse(
      userStrokes: [straightLine.reversed.toList()],
      reference: straightReference,
    );

    // Shape is still a near-perfect match; direction should be the outlier.
    expect(result.shapeAccuracy, greaterThan(0.95));
    expect(result.directionAccuracy, lessThan(0.15));
  });

  test('splitting one reference stroke into two user strokes penalizes count but not shape', () {
    final mid = referencePoints.length ~/ 2;
    final result = engine.analyse(
      userStrokes: [referencePoints.sublist(0, mid), referencePoints.sublist(mid)],
      reference: reference,
    );

    expect(result.countAccuracy, closeTo(0.5, 0.01));
    expect(result.shapeAccuracy, greaterThan(0.95));
  });

  test('drawing strokes out of reference order penalizes order accuracy', () {
    final mid = referencePoints.length ~/ 2;
    final firstHalf = referencePoints.sublist(0, mid);
    final secondHalf = referencePoints.sublist(mid);
    final twoStrokeReference = LetterStrokeData(
      letterId: 'test_letter_2',
      strokes: [Stroke(index: 0, points: firstHalf), Stroke(index: 1, points: secondHalf)],
    );

    final inOrder = engine.analyse(
      userStrokes: [firstHalf, secondHalf],
      reference: twoStrokeReference,
    );
    final swapped = engine.analyse(
      userStrokes: [secondHalf, firstHalf],
      reference: twoStrokeReference,
    );

    expect(inOrder.orderAccuracy, equals(1.0));
    expect(swapped.orderAccuracy, lessThan(1.0));
  });

  group('a freehand attempt that looks right scores like it', () {
    // Challenge mode is judged on shape alone, and the shape a child draws
    // freehand is never the reference to the pixel. A recognisable அ was
    // scoring 9 out of 20, which reads as failure for a letter drawn well.

    /// The reference wobbled sideways and stretched, the way a hand does.
    List<Offset> handDrawn(List<Offset> path, double wobble, double stretch) {
      return List.generate(path.length, (i) {
        final p = path[i];
        final scaled = Offset(0.5 + (p.dx - 0.5) * stretch, 0.5 + (p.dy - 0.5) * stretch);
        return scaled + Offset(sin(i * 0.7) * wobble, cos(i * 0.5) * wobble);
      });
    }

    test('a wobbly but well-placed attempt scores most of the marks', () {
      final result = engine.analyse(
        userStrokes: [handDrawn(referencePoints, 0.012, 1.04)],
        reference: reference,
      );
      expect(result.shapeAccuracy, greaterThan(0.8),
          reason: 'shape accuracy was ${result.shapeAccuracy}');
    });

    test('the same letter drawn a bit small still reads as the letter', () {
      final result = engine.analyse(
        userStrokes: [handDrawn(referencePoints, 0.01, 0.88)],
        reference: reference,
      );
      expect(result.shapeAccuracy, greaterThan(0.7),
          reason: 'shape accuracy was ${result.shapeAccuracy}');
    });

    test('covering only part of the letter still loses marks', () {
      // The forgiving measure must not make a half-drawn letter look whole:
      // the reference-to-user half of the distance is what catches this.
      final half = referencePoints.sublist(0, referencePoints.length ~/ 2);
      final result = engine.analyse(userStrokes: [half], reference: reference);
      expect(result.shapeAccuracy, lessThan(0.8),
          reason: 'shape accuracy was ${result.shapeAccuracy}');
    });
  });

  test('an empty attempt analyses as zero without throwing', () {
    final result = engine.analyse(userStrokes: const [], reference: reference);
    expect(result.shapeAccuracy, equals(0));
    expect(result.directionAccuracy, equals(0));
  });
}
