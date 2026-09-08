import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kids_tamil_ezhuthu_school/core/config/models/app_config.dart';
import 'package:kids_tamil_ezhuthu_school/data/models/stroke.dart';
import 'package:kids_tamil_ezhuthu_school/features/letter/trace/letter_paths.dart';
import 'package:kids_tamil_ezhuthu_school/features/letter/trace/trace_controller.dart';

/// The tolerances the app ships with, read rather than copied.
final _canvasConfig = CanvasConfig.fromJson(
  (jsonDecode(File('assets/config/app_config.json').readAsStringSync())
      as Map<String, dynamic>)['canvas'] as Map<String, dynamic>,
);

const _dotCentre = Offset(0.8, 0.2);

/// A line to drag, then a dot to touch — the shape of every mei letter.
LetterPaths _lineThenDot() {
  return LetterPaths.fromStrokes(
    [
      Stroke(index: 0, points: List.generate(21, (i) => Offset(0.1 + i * 0.03, 0.5))),
      Stroke(index: 1, points: const [_dotCentre]),
    ],
    dotLength: _canvasConfig.dotStrokeLengthFactor,
  );
}

void _dragAlong(TraceController c, LetterPaths paths, int strokeIndex) {
  final length = paths.lengthOf(strokeIndex);
  c.startPointer(paths.pointAt(strokeIndex, 0)!);
  for (var d = 0.0; d <= length; d += 0.01) {
    final p = paths.pointAt(strokeIndex, d);
    if (p != null) c.movePointer(p);
  }
  c.endPointer();
}

void main() {
  test('a single-point stroke is kept, as a dot', () {
    final paths = _lineThenDot();

    // It used to be dropped outright — `points.length < 2` was skipped — so
    // a letter's puḷḷi simply was not on the canvas.
    expect(paths.strokeCount, 2);
    expect(paths.isDot(0), isFalse);
    expect(paths.isDot(1), isTrue);
    expect(paths.dotCentre(1), _dotCentre);
    expect(paths.pathAt(1), isNull, reason: 'a dot has no path to stroke');
  });

  test('a dot carries a notional length so it is not weighed as nothing', () {
    final paths = _lineThenDot();

    expect(paths.lengthOf(1), _canvasConfig.dotStrokeLengthFactor);
    expect(paths.lengthOf(1), greaterThan(0),
        reason: 'at zero the demo treats the dot as finished on arrival');
    // Wherever you ask along it, a dot is the same point.
    expect(paths.pointAt(1, 0), _dotCentre);
    expect(paths.pointAt(1, 999), _dotCentre);
  });

  test('guide dots do not string along a dot — the mark is the target', () {
    final paths = _lineThenDot();

    expect(paths.dotsAlong(0, _canvasConfig.dotSpacingFactor), isNotEmpty);
    expect(paths.dotsAlong(1, _canvasConfig.dotSpacingFactor), isEmpty);
    // And the one place to aim at on that stroke is the dot itself.
    expect(
      paths.nextWaypoint(1, 0, _canvasConfig.waypointSpacingFactor, touched: false),
      _dotCentre,
    );
  });

  test('touching a dot completes it — no drag, and no direction to get wrong', () {
    final paths = _lineThenDot();
    final c = TraceController(letterPaths: paths, canvasConfig: _canvasConfig);
    addTearDown(c.dispose);

    _dragAlong(c, paths, 0);
    expect(c.strokeIndex, 1, reason: 'the line is done, the dot is next');
    expect(c.completed, isFalse);

    c.startPointer(_dotCentre);
    c.endPointer();

    expect(c.completed, isTrue, reason: 'one touch is the whole gesture');
  });

  test('a touch that misses the dot leaves it unmade', () {
    final paths = _lineThenDot();
    final c = TraceController(letterPaths: paths, canvasConfig: _canvasConfig);
    addTearDown(c.dispose);

    _dragAlong(c, paths, 0);
    // Well outside traceToleranceFactor, which is what "near enough" means
    // everywhere else on the canvas.
    c.startPointer(_dotCentre + const Offset(0.4, 0.4));
    c.endPointer();

    expect(c.completed, isFalse);
    expect(c.strokeIndex, 1);
  });

  test('a dot carries its own width, because it is wider than the strokes', () {
    final paths = LetterPaths.fromStrokes(
      [Stroke(index: 0, points: const [_dotCentre], width: 0.148)],
      dotLength: _canvasConfig.dotStrokeLengthFactor,
    );

    expect(paths.dotWidth(0), 0.148);
    // Null means "use the letter's tube", which is what a dot must NOT do:
    // a puḷḷi is 95px where the letter's stroke is 54-62px.
    expect(_lineThenDot().dotWidth(1), isNull);
  });

  test('every mei puḷḷi ships wider than its letter tube', () {
    for (var i = 1; i <= 18; i++) {
      final id = 'mei_${i.toString().padLeft(2, '0')}';
      final data = jsonDecode(
        File('lib/data/letters/strokes/$id.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final tube = (data['tubeWidthFactor'] as num).toDouble();
      final dots = (data['strokes'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .where((s) => (s['points'] as List<dynamic>).length == 1)
          .toList();

      expect(dots.length, 1, reason: '$id has exactly one puḷḷi');
      final width = (dots.single['width'] as num).toDouble();
      expect(width, greaterThan(tube * 1.3),
          reason: '$id draws its dot at $width against a tube of $tube');
    }
  });

  test('ஈ ships its two marks as dots', () {
    // The real file, so this fails if the pipeline ever goes back to
    // emitting the short segment that drew a little bar.
    final data = jsonDecode(
      File('lib/data/letters/strokes/uyir_04.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final strokes = (data['strokes'] as List<dynamic>)
        .map((s) => (s as Map<String, dynamic>)['points'] as List<dynamic>)
        .toList();

    expect(strokes.where((p) => p.length == 1).length, 2,
        reason: 'ஈ has two filled dots');
  });
}
