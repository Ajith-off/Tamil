import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../../../core/config/models/app_config.dart';
import 'letter_paths.dart';

/// Drives the "drag along the letter" interaction.
///
/// Progress only moves forward, and only while the finger stays within
/// [CanvasConfig.traceToleranceFactor] of the path, so the trace fills in
/// exactly along the letter however wobbly the child's finger is. A
/// lookahead window stops them jumping across a loop to a later part of the
/// same stroke.
///
/// The raw finger positions are recorded separately from the progress, so
/// the scoring engine can still judge how accurately the child actually
/// moved rather than just that they finished.
class TraceController extends ChangeNotifier {
  final LetterPaths letterPaths;
  final CanvasConfig canvasConfig;

  /// In free-draw ("exam") mode the finger is not snapped to the reference
  /// path at all: strokes are recorded exactly as drawn and nothing is
  /// judged until the child submits.
  bool freeDraw;

  TraceController({
    required this.letterPaths,
    required this.canvasConfig,
    this.freeDraw = false,
  });

  int _strokeIndex = 0;
  double _distance = 0;
  bool _completed = false;
  bool _touchedCurrentStroke = false;
  final List<List<Offset>> _userStrokes = [];
  final Stopwatch _clock = Stopwatch();

  int get strokeIndex => _strokeIndex;
  double get distance => _distance;
  bool get completed => _completed;
  TracePosition get position => TracePosition(_strokeIndex, _distance);

  /// Raw finger paths, one list per stroke the child drew.
  List<List<Offset>> get userStrokes =>
      List.unmodifiable(_userStrokes.map(List<Offset>.unmodifiable));

  bool get hasStarted => _strokeIndex > 0 || _distance > 0;

  /// Whether the finger has gone down on the stroke now being written.
  ///
  /// Waypoint guidance needs this to know the difference between "you have
  /// not begun this stroke, so here is where it starts" and "you are on it,
  /// so here is the next place to reach". Distance alone cannot tell them
  /// apart: it is zero in both cases, and every stroke after the first
  /// begins at zero again.
  bool get touchedCurrentStroke => _touchedCurrentStroke;

  /// Time spent writing, measured from the first touch. Used only for the
  /// silent hard-mode fluency bonus — nothing counts down and the child is
  /// never shown a clock.
  Duration get elapsed => _clock.elapsed;

  /// Total arc length of the reference, so the fluency bonus can allow a
  /// long letter proportionally longer.
  double get referenceLength {
    var total = 0.0;
    for (var i = 0; i < letterPaths.strokeCount; i++) {
      total += letterPaths.lengthOf(i);
    }
    return total;
  }

  /// Where the child should put their finger next. Free-draw mode has no
  /// such place — they choose for themselves.
  Offset? get targetPoint {
    if (freeDraw || _completed || letterPaths.isEmpty) return null;
    return letterPaths.pointAt(_strokeIndex, _distance);
  }

  /// True once there is something worth submitting in free-draw mode.
  bool get hasDrawnAnything => _userStrokes.any((s) => s.length >= 2);

  /// 0..1 across the whole letter, for progress display.
  double get overallFraction {
    if (letterPaths.isEmpty) return 0;
    var total = 0.0;
    var done = 0.0;
    for (var i = 0; i < letterPaths.strokeCount; i++) {
      final len = letterPaths.lengthOf(i);
      total += len;
      if (i < _strokeIndex) {
        done += len;
      } else if (i == _strokeIndex) {
        done += _distance;
      }
    }
    return total == 0 ? 0 : (done / total).clamp(0.0, 1.0);
  }

  void reset() {
    _strokeIndex = 0;
    _distance = 0;
    _completed = false;
    _touchedCurrentStroke = false;
    _userStrokes.clear();
    _clock
      ..stop()
      ..reset();
    notifyListeners();
  }

  void startPointer(Offset normalizedPoint) {
    if (!_clock.isRunning && !_completed) _clock.start();
    _touchedCurrentStroke = true;
    _userStrokes.add([normalizedPoint]);
    _advanceTowards(normalizedPoint);
    notifyListeners();
  }

  void movePointer(Offset normalizedPoint) {
    if (_userStrokes.isNotEmpty) {
      final last = _userStrokes.last.last;
      if ((normalizedPoint - last).distance >= canvasConfig.minPointDistance) {
        _userStrokes.last.add(normalizedPoint);
      }
    }
    _advanceTowards(normalizedPoint);
    notifyListeners();
  }

  void endPointer() {
    notifyListeners();
  }

  void _advanceTowards(Offset finger) {
    if (freeDraw || _completed || letterPaths.isEmpty) return;

    // A dot is made or not made. There is no path to creep along and no
    // direction to get right, so touching it is the whole gesture — asking a
    // child to drag across a mark the size of their fingertip would be
    // asking for precision the mark does not have.
    if (letterPaths.isDot(_strokeIndex)) {
      final centre = letterPaths.dotCentre(_strokeIndex)!;
      if ((centre - finger).distance <= canvasConfig.traceToleranceFactor) {
        _distance = letterPaths.lengthOf(_strokeIndex);
        _finishCurrentStroke();
      }
      return;
    }

    final metricLength = letterPaths.lengthOf(_strokeIndex);
    final step = canvasConfig.traceSampleStepFactor;
    final limit = math.min(metricLength, _distance + canvasConfig.traceLookaheadFactor);

    var bestDistance = _distance;
    var bestGap = double.infinity;
    for (var d = _distance; d <= limit; d += step) {
      final point = letterPaths.pointAt(_strokeIndex, d);
      if (point == null) continue;
      final gap = (point - finger).distance;
      if (gap < bestGap) {
        bestGap = gap;
        bestDistance = d;
      }
    }

    if (bestGap > canvasConfig.traceToleranceFactor || bestDistance <= _distance) return;

    _distance = bestDistance;
    // Snap to the end once the remaining arc is within the same "close
    // enough" radius used everywhere else. A child who lifts their finger a
    // hair short of the end has still drawn the stroke, and should not be
    // stuck unable to finish it.
    if (metricLength - _distance <= canvasConfig.traceToleranceFactor) {
      _finishCurrentStroke();
    }
  }

  void _finishCurrentStroke() {
    if (_strokeIndex >= letterPaths.strokeCount - 1) {
      _distance = letterPaths.lengthOf(_strokeIndex);
      _completed = true;
      _clock.stop();
    } else {
      _strokeIndex++;
      _distance = 0;
      // A new stroke starts somewhere else on the page, so the child is told
      // where it begins before being told where to go next.
      _touchedCurrentStroke = false;
    }
  }
}
