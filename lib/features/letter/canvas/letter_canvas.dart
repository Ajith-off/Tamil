import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/config/models/app_config.dart';
import '../../../core/config/models/theme_config.dart';
import '../trace/letter_paths.dart';
import 'letter_canvas_painter.dart';

/// The square tracing area. Pointer positions are converted into the same
/// normalized 0..1 space the stroke data uses, so nothing downstream needs
/// to know the screen size.
class LetterCanvas extends StatelessWidget {
  final LetterPaths letterPaths;
  final bool showTube;
  final bool showDots;

  /// Reveal the path one waypoint at a time instead of showing all of it.
  final bool showWaypoints;

  /// Whether the finger has gone down on the stroke being written.
  final bool touchedCurrentStroke;

  /// Outline the drawing area, for a mode that draws nothing else.
  final bool showFrame;
  final TracePosition position;
  final Offset? targetPoint;
  final bool completed;
  final CanvasConfig canvasConfig;
  final ThemeColors colors;
  final List<SparkleParticle> sparkles;
  final double celebrationProgress;

  /// Stars the finished attempt earned, and how big the star in the middle
  /// of the burst should be.
  final int celebrationStars;
  final double celebrationStarRadius;
  final double? tubeWidthOverride;
  final List<List<Offset>> freeDrawStrokes;
  final ValueChanged<Offset>? onPointerDown;
  final ValueChanged<Offset>? onPointerMove;
  final VoidCallback? onPointerUp;

  const LetterCanvas({
    super.key,
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
    this.onPointerDown,
    this.onPointerMove,
    this.onPointerUp,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final side = math.min(size.width, size.height);
        final originX = (size.width - side) / 2;
        final originY = (size.height - side) / 2;

        Offset toNormalized(Offset local) => Offset(
              ((local.dx - originX) / side).clamp(0.0, 1.0),
              ((local.dy - originY) / side).clamp(0.0, 1.0),
            );

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (d) => onPointerDown?.call(toNormalized(d.localPosition)),
          onPanUpdate: (d) => onPointerMove?.call(toNormalized(d.localPosition)),
          onPanEnd: (_) => onPointerUp?.call(),
          child: CustomPaint(
            size: size,
            painter: LetterCanvasPainter(
              letterPaths: letterPaths,
              showTube: showTube,
              showDots: showDots,
              showWaypoints: showWaypoints,
              touchedCurrentStroke: touchedCurrentStroke,
              showFrame: showFrame,
              position: position,
              targetPoint: targetPoint,
              completed: completed,
              canvasConfig: canvasConfig,
              colors: colors,
              sparkles: sparkles,
              celebrationProgress: celebrationProgress,
              celebrationStars: celebrationStars,
              celebrationStarRadius: celebrationStarRadius,
              tubeWidthOverride: tubeWidthOverride,
              freeDrawStrokes: freeDrawStrokes,
            ),
          ),
        );
      },
    );
  }
}
