import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import '../../../core/config/models/app_config.dart';
import '../../../core/config/models/theme_config.dart';
import '../../common/celebration_burst.dart';
import '../trace/letter_paths.dart';

export '../../common/celebration_burst.dart' show SparkleParticle;

/// Draws the letter as a thick guide tube, the dots that show where to drag,
/// and the child's progress filling that same tube with a gradient.
///
/// Everything is derived from the reference stroke path — there is no font
/// glyph on the canvas — so the guide, the fill and the scoring all measure
/// against exactly the same shape.
class LetterCanvasPainter extends CustomPainter {
  final LetterPaths letterPaths;
  final bool showTube;
  final bool showDots;

  /// Reveal the path one waypoint at a time instead of showing all of it.
  final bool showWaypoints;

  /// Whether the finger has gone down on the stroke being written — decides
  /// whether the waypoint marks where the stroke begins or where to go next.
  final bool touchedCurrentStroke;

  /// Outline the drawing area. Challenge shows nothing else at all, and a
  /// blank canvas has no visible edges to write inside.
  final bool showFrame;
  final TracePosition position;
  final Offset? targetPoint;
  final bool completed;
  final CanvasConfig canvasConfig;
  final ThemeColors colors;
  final List<SparkleParticle> sparkles;
  final double celebrationProgress;

  /// Stars earned by the attempt that triggered the burst. Above zero, a
  /// magic star blooms in the middle of it — the burst says "finished", the
  /// star says "and it counted".
  final int celebrationStars;

  /// Radius of that star, as a fraction of the canvas. From
  /// `CelebrationConfig.starRadiusFactor`.
  final double celebrationStarRadius;

  /// Per-letter tube thickness, overriding [CanvasConfig.tubeWidthFactor]
  /// when the letter's stroke data supplies one.
  final double? tubeWidthOverride;

  /// Freehand strokes exactly as the child drew them. In the exam mode
  /// nothing is snapped to the reference, so this is what gets painted
  /// instead of a fill along the reference path.
  final List<List<Offset>> freeDrawStrokes;

  LetterCanvasPainter({
    required this.letterPaths,
    required this.showTube,
    required this.showDots,
    this.showWaypoints = false,
    this.touchedCurrentStroke = false,
    this.showFrame = false,
    required this.position,
    required this.targetPoint,
    required this.completed,
    required this.canvasConfig,
    required this.colors,
    this.sparkles = const [],
    this.celebrationProgress = 0,
    this.celebrationStars = 0,
    this.celebrationStarRadius = 0.16,
    this.tubeWidthOverride,
    this.freeDrawStrokes = const [],
  });

  double get _tubeWidth => tubeWidthOverride ?? canvasConfig.tubeWidthFactor;

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height);
    canvas.save();
    // Work entirely in normalized 0..1 space: one uniform scale keeps the
    // letter's proportions and makes every width factor resolution-free.
    canvas.translate((size.width - side) / 2, (size.height - side) / 2);
    canvas.scale(side, side);

    if (showFrame) _paintFrame(canvas);
    if (showTube) _paintTube(canvas);
    if (showDots) _paintDots(canvas);
    if (freeDrawStrokes.isEmpty) {
      _paintTracedFill(canvas);
    } else {
      _paintFreeDraw(canvas);
    }
    if (!completed) {
      // The waypoint replaces the target ring rather than joining it: two
      // markers a hair apart is noise, and the whole point of the waypoint
      // is that there is exactly one thing to aim at.
      if (showWaypoints) {
        _paintWaypoint(canvas);
      } else if (targetPoint != null) {
        _paintTarget(canvas, targetPoint!);
      }
    }

    canvas.restore();

    if (celebrationProgress > 0) _paintSparkles(canvas, size, side);
  }

  /// The edge of the page, for a mode that draws nothing else.
  void _paintFrame(Canvas canvas) {
    final inset = canvasConfig.frameInsetFactor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(inset, inset, 1 - inset, 1 - inset),
        Radius.circular(canvasConfig.frameCornerFactor),
      ),
      _strokePaint(canvasConfig.frameWidthFactor)
        ..color = colors.letterTubeEdge
        ..strokeCap = StrokeCap.butt,
    );
  }

  Paint _strokePaint(double width) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true;

  void _paintTube(Canvas canvas) {
    final tube = _tubeWidth;
    final edge = canvasConfig.tubeEdgeWidthFactor;
    final edgePaint = _strokePaint(tube + edge * 2)..color = colors.letterTubeEdge;
    final facePaint = _strokePaint(tube)..color = colors.letterTube;
    // Edges first across the whole letter, then faces, so one stroke's
    // outline never sits on top of another's face where they meet.
    for (var i = 0; i < letterPaths.strokeCount; i++) {
      _paintStroke(canvas, i, edgePaint, grow: edge);
    }
    for (var i = 0; i < letterPaths.strokeCount; i++) {
      _paintStroke(canvas, i, facePaint);
    }
  }

  /// A dot is drawn at its own size, not the letter's tube width: a puḷḷi is
  /// half again as wide as the strokes around it, and drawing it at the tube
  /// width leaves it visibly small. Falls back to the tube for older stroke
  /// data that carries no width.
  double _dotRadius(int index) => (letterPaths.dotWidth(index) ?? _tubeWidth) / 2;

  /// Draw one stroke as what it is: a path for a line, a filled circle for a
  /// dot. A dot's whole geometry is its centre — there is no path to stroke,
  /// and a zero-length one draws nothing at all.
  void _paintStroke(Canvas canvas, int index, Paint linePaint, {double grow = 0}) {
    if (!letterPaths.isDot(index)) {
      canvas.drawPath(letterPaths.pathAt(index)!, linePaint);
      return;
    }
    canvas.drawCircle(
      letterPaths.dotCentre(index)!,
      _dotRadius(index) + grow,
      Paint()
        ..color = linePaint.color
        ..shader = linePaint.shader
        ..isAntiAlias = true,
    );
  }

  /// Dots appear on strokes the child has reached, not on ones still to
  /// come — so the letter reveals its path one stroke at a time.
  void _paintDots(Canvas canvas) {
    final dotPaint = Paint()
      ..color = colors.dot
      ..isAntiAlias = true;
    final upTo = math.min(position.strokeIndex, letterPaths.strokeCount - 1);
    for (var i = 0; i <= upTo; i++) {
      for (final dot in letterPaths.dotsAlong(i, canvasConfig.dotSpacingFactor)) {
        canvas.drawCircle(dot, canvasConfig.dotRadiusFactor, dotPaint);
      }
    }
  }

  void _paintTracedFill(Canvas canvas) {
    final bounds = letterPaths.bounds;
    if (bounds.isEmpty) return;
    final shader = LinearGradient(
      colors: [colors.traceStart, colors.traceEnd],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).createShader(bounds);
    final fillPaint = _strokePaint(_tubeWidth)..shader = shader;

    for (var i = 0; i < letterPaths.strokeCount; i++) {
      final done = i < position.strokeIndex || completed;
      // A dot fills in whole the moment it is touched — there is no half a
      // dot, and painting it is the acknowledgement that the touch landed.
      if (letterPaths.isDot(i)) {
        if (done || (i == position.strokeIndex && position.distance > 0)) {
          _paintStroke(canvas, i, fillPaint);
        }
      } else if (done) {
        canvas.drawPath(letterPaths.pathAt(i)!, fillPaint);
      } else if (i == position.strokeIndex && position.distance > 0) {
        canvas.drawPath(letterPaths.extractUpTo(i, position.distance), fillPaint);
      }
    }
  }

  /// The child's own strokes, inked in the same gradient the guided modes
  /// fill the tube with, so freehand writing feels like the same activity.
  void _paintFreeDraw(Canvas canvas) {
    final shader = LinearGradient(
      colors: [colors.traceStart, colors.traceEnd],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).createShader(const Rect.fromLTWH(0, 0, 1, 1));
    final paint = _strokePaint(_tubeWidth)..shader = shader;
    for (final stroke in freeDrawStrokes) {
      if (stroke.length == 1) {
        canvas.drawCircle(stroke.first, _tubeWidth / 2, Paint()..shader = shader);
        continue;
      }
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (final p in stroke.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  /// The one place to touch next, and nothing else.
  ///
  /// Where the tube shows a child the whole letter and leaves them to work
  /// out where to begin, this asks for a single reachable thing at a time.
  /// The letter fills in behind them as they go, so it is drawn by being
  /// followed rather than copied.
  void _paintWaypoint(Canvas canvas) {
    if (letterPaths.isEmpty) return;
    final stroke = math.min(position.strokeIndex, letterPaths.strokeCount - 1);
    final point = letterPaths.nextWaypoint(
      stroke,
      position.distance,
      canvasConfig.waypointSpacingFactor,
      touched: touchedCurrentStroke,
      minLead: canvasConfig.waypointMinLeadFactor,
    );
    if (point == null) return;
    canvas.drawCircle(
      point,
      canvasConfig.waypointHaloFactor,
      Paint()..color = colors.primary.withValues(alpha: 0.22),
    );
    canvas.drawCircle(point, canvasConfig.waypointRadiusFactor, Paint()..color = colors.primary);
    canvas.drawCircle(
      point,
      canvasConfig.waypointRadiusFactor * 0.45,
      Paint()..color = colors.canvasBackground,
    );
  }

  /// A ring marking where the finger should go next.
  void _paintTarget(Canvas canvas, Offset point) {
    final radius = _tubeWidth * 0.5;
    canvas.drawCircle(
      point,
      radius,
      Paint()..color = colors.sparkle.withValues(alpha: 0.35),
    );
    canvas.drawCircle(
      point,
      radius,
      _strokePaint(canvasConfig.tubeEdgeWidthFactor * 2)..color = colors.primary,
    );
  }

  void _paintSparkles(Canvas canvas, Size size, double side) {
    paintCelebrationBurst(
      canvas,
      Offset(size.width / 2, size.height / 2),
      side,
      celebrationProgress,
      sparkles,
      colors,
      stars: celebrationStars,
      starRadiusFactor: celebrationStarRadius,
    );
  }

  @override
  bool shouldRepaint(covariant LetterCanvasPainter old) {
    return old.letterPaths != letterPaths ||
        old.showTube != showTube ||
        old.showDots != showDots ||
        old.showWaypoints != showWaypoints ||
        old.touchedCurrentStroke != touchedCurrentStroke ||
        old.showFrame != showFrame ||
        old.position.strokeIndex != position.strokeIndex ||
        old.position.distance != position.distance ||
        old.targetPoint != targetPoint ||
        old.completed != completed ||
        old.celebrationProgress != celebrationProgress ||
        old.celebrationStars != celebrationStars ||
        old.celebrationStarRadius != celebrationStarRadius ||
        old.tubeWidthOverride != tubeWidthOverride ||
        old.freeDrawStrokes != freeDrawStrokes ||
        old.colors != colors;
  }
}
