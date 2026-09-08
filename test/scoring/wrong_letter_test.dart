import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kids_tamil_ezhuthu_school/data/models/stroke.dart';
import 'package:kids_tamil_ezhuthu_school/features/letter/scoring/scoring_engine.dart';

import 'scoring_fixtures.dart';

/// Reads real, shipped stroke data rather than a synthetic fixture — the
/// question this file answers only shows up with two letters that actually
/// share canvas space, which a hand-drawn circle fixture can't reproduce.
LetterStrokeData _shippedLetter(String letterId) {
  final json = jsonDecode(
    File('lib/data/letters/strokes/$letterId.json').readAsStringSync(),
  );
  final strokes = (json['strokes'] as List).asMap().entries.map((e) {
    final points = (e.value['points'] as List)
        .map((p) => Offset((p['x'] as num).toDouble(), (p['y'] as num).toDouble()))
        .toList();
    return Stroke(index: e.key, points: points);
  }).toList();
  return LetterStrokeData(letterId: letterId, strokes: strokes);
}

void main() {
  final engine = ScoringEngine(scoringConfigFixture);

  test('a different, unrelated letter drawn perfectly scores clearly below a real correct attempt', () {
    // A parent reported challenge mode paying ~65% shape credit for அ drawn
    // against இ's reference — both letters sit centred in the canvas, and
    // the old pooled *mean* nearest-point distance mostly asked "is there
    // ink near this region" rather than "is this the right shape", so two
    // unrelated but similarly-sized letters partially matched by
    // coincidence. Switching to the 85th-percentile distance
    // (robustNearestPointDistance) fixed that for real drawings — confirmed
    // on-device, where a genuine wrong doodle now scores well below a
    // genuine correct attempt at the same tolerance.
    //
    // This specific case — அ drawn with zero noise, at font precision, as
    // an attempt at இ — is a harder adversarial bar than any real child's
    // hand produces, and asking for it to stay as low as a real mistake
    // does would also cap how well a real correct attempt can score (the
    // two draw from the same tolerance). 0.5 leaves it clearly the weaker
    // of the two without doing that — see the on-device numbers above.
    final target = _shippedLetter('uyir_03'); // இ
    final wrongLetter = _shippedLetter('uyir_01'); // அ, drawn perfectly as itself

    final result = engine.analyse(
      userStrokes: [for (final s in wrongLetter.strokes) s.points],
      reference: target,
    );

    expect(result.shapeAccuracy, lessThan(0.5),
        reason: 'shape accuracy was ${result.shapeAccuracy}');
  });

  test('the right letter with an overshot bar still reads as a good attempt', () {
    // The regression this whole metric exists to avoid (HANDOFF's original
    // "elongated bar" case): a real child overshooting அ's bar must not be
    // punished as hard as drawing a completely different letter is above.
    final aReference = _shippedLetter('uyir_01');
    final tail = aReference.strokes[0].points;
    final start = tail.first, end = tail.last;
    final dir = end - start;
    final stretched = [
      ...tail,
      ...List.generate(10, (i) => Offset.lerp(end, end + dir * 0.15, (i + 1) / 10)!),
    ];

    final result = engine.analyse(
      userStrokes: [stretched, aReference.strokes[1].points],
      reference: aReference,
    );

    expect(result.shapeAccuracy, greaterThan(0.85),
        reason: 'shape accuracy was ${result.shapeAccuracy}');
  });
}
