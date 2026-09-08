
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kids_tamil_ezhuthu_school/core/config/models/app_config.dart';
import 'package:kids_tamil_ezhuthu_school/data/models/stroke.dart';
import 'package:kids_tamil_ezhuthu_school/features/letter/trace/letter_paths.dart';
import 'package:kids_tamil_ezhuthu_school/features/letter/trace/trace_controller.dart';

/// The tolerances the app actually ships with — read from the config rather
/// than copied, because a copy drifts. This one had: it still claimed a tube
/// width the app stopped using.
final _canvasConfig = CanvasConfig.fromJson(
  (jsonDecode(File('assets/config/app_config.json').readAsStringSync())
      as Map<String, dynamic>)['canvas'] as Map<String, dynamic>,
);

/// A horizontal stroke across the middle, then a vertical one down the right.
LetterPaths _twoStrokeLetter() {
  return LetterPaths.fromStrokes([
    Stroke(index: 0, points: List.generate(21, (i) => Offset(0.1 + i * 0.03, 0.5))),
    Stroke(index: 1, points: List.generate(21, (i) => Offset(0.8, 0.2 + i * 0.02))),
  ]);
}

/// Walks the finger along a stroke in small steps, as a real drag would.
void _dragAlong(TraceController c, LetterPaths paths, int strokeIndex, {double step = 0.01}) {
  final length = paths.lengthOf(strokeIndex);
  final start = paths.pointAt(strokeIndex, 0)!;
  c.startPointer(start);
  for (var d = 0.0; d <= length; d += step) {
    final p = paths.pointAt(strokeIndex, d);
    if (p != null) c.movePointer(p);
  }
  c.endPointer();
}

void main() {
  test('dragging along every stroke in order completes the letter', () {
    final paths = _twoStrokeLetter();
    final c = TraceController(letterPaths: paths, canvasConfig: _canvasConfig);
    addTearDown(c.dispose);

    expect(c.completed, isFalse);
    _dragAlong(c, paths, 0);
    expect(c.completed, isFalse, reason: 'still has a second stroke to draw');
    expect(c.strokeIndex, 1);

    _dragAlong(c, paths, 1);
    expect(c.completed, isTrue);
    expect(c.overallFraction, closeTo(1.0, 0.001));
  });

  test('a finger far from the path never advances the trace', () {
    final paths = _twoStrokeLetter();
    final c = TraceController(letterPaths: paths, canvasConfig: _canvasConfig);
    addTearDown(c.dispose);

    c.startPointer(const Offset(0.1, 0.05));
    for (var x = 0.1; x <= 0.7; x += 0.01) {
      c.movePointer(Offset(x, 0.05)); // a long way above the stroke
    }
    c.endPointer();

    expect(c.distance, 0);
    expect(c.completed, isFalse);
  });

  test('progress only moves forward, never backward', () {
    final paths = _twoStrokeLetter();
    final c = TraceController(letterPaths: paths, canvasConfig: _canvasConfig);
    addTearDown(c.dispose);

    c.startPointer(paths.pointAt(0, 0)!);
    for (var d = 0.0; d <= 0.3; d += 0.01) {
      c.movePointer(paths.pointAt(0, d)!);
    }
    expect(c.distance, greaterThan(0));

    // Drag back toward the start; progress must never rewind at any point
    // along the way.
    var previous = c.distance;
    for (var d = 0.3; d >= 0.0; d -= 0.01) {
      c.movePointer(paths.pointAt(0, d)!);
      expect(c.distance, greaterThanOrEqualTo(previous));
      previous = c.distance;
    }
  });

  test('the finger cannot skip ahead past the lookahead window', () {
    final paths = _twoStrokeLetter();
    final c = TraceController(letterPaths: paths, canvasConfig: _canvasConfig);
    addTearDown(c.dispose);

    final length = paths.lengthOf(0);
    c.startPointer(paths.pointAt(0, 0)!);
    // Jump straight to the far end of the stroke.
    c.movePointer(paths.pointAt(0, length)!);

    expect(c.distance, lessThanOrEqualTo(_canvasConfig.traceLookaheadFactor + 1e-9));
    expect(c.completed, isFalse);
  });

  test('the raw finger path is recorded for scoring, separately from progress', () {
    final paths = _twoStrokeLetter();
    final c = TraceController(letterPaths: paths, canvasConfig: _canvasConfig);
    addTearDown(c.dispose);

    _dragAlong(c, paths, 0);
    expect(c.userStrokes, hasLength(1));
    expect(c.userStrokes.first.length, greaterThan(5));
  });

  group('free-draw (exam) mode', () {
    test('records strokes wherever they are drawn and never auto-completes', () {
      final paths = _twoStrokeLetter();
      final c = TraceController(letterPaths: paths, canvasConfig: _canvasConfig, freeDraw: true);
      addTearDown(c.dispose);

      // Draw somewhere the guided modes would have refused to follow.
      c.startPointer(const Offset(0.2, 0.1));
      for (var x = 0.2; x <= 0.7; x += 0.02) {
        c.movePointer(Offset(x, 0.1));
      }
      c.endPointer();

      expect(c.hasDrawnAnything, isTrue);
      expect(c.userStrokes, hasLength(1));
      expect(c.userStrokes.first.length, greaterThan(5));
      // Nothing is judged until the child submits.
      expect(c.completed, isFalse);
      expect(c.distance, 0);
      expect(c.targetPoint, isNull, reason: 'no target is prescribed in exam mode');
    });

    test('a stray tap is not enough to submit', () {
      final paths = _twoStrokeLetter();
      final c = TraceController(letterPaths: paths, canvasConfig: _canvasConfig, freeDraw: true);
      addTearDown(c.dispose);

      c.startPointer(const Offset(0.5, 0.5));
      c.endPointer();

      expect(c.hasDrawnAnything, isFalse);
    });
  });

  test('reset clears progress and the recorded finger path', () {
    final paths = _twoStrokeLetter();
    final c = TraceController(letterPaths: paths, canvasConfig: _canvasConfig);
    addTearDown(c.dispose);

    _dragAlong(c, paths, 0);
    c.reset();

    expect(c.distance, 0);
    expect(c.strokeIndex, 0);
    expect(c.completed, isFalse);
    expect(c.userStrokes, isEmpty);
    expect(c.hasStarted, isFalse);
  });
}
