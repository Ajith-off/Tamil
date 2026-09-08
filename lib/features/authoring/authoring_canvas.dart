import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/config/models/authoring_config.dart';
import '../../core/config/models/theme_config.dart';
import 'glyph_skeleton.dart';

/// Maps the letter's normalized 0..1 space onto the canvas.
///
/// The child-facing canvas is square, because a letter has to sit the same
/// way every time it is seen. This one is not: it fits the letter's own
/// bounding box, so a wide letter like ஔ — nearly twice as wide as tall —
/// gets the full width instead of a third of it going to empty margin. Only
/// the arc order comes off this screen, so nothing downstream cares how the
/// letter was framed while it was drawn, and a bigger letter is one a finger
/// can follow more accurately.
class CanvasFit {
  final double scale;

  /// Where normalized (0,0) lands, in local pixels.
  final Offset origin;

  const CanvasFit(this.scale, this.origin);

  factory CanvasFit.of(Size box, Rect bounds, double padding) {
    final width = bounds.width + 2 * padding;
    final height = bounds.height + 2 * padding;
    if (width <= 0 || height <= 0) return CanvasFit(box.shortestSide, Offset.zero);
    final scale = math.min(box.width / width, box.height / height);
    return CanvasFit(
      scale,
      Offset(
        (box.width - width * scale) / 2 - (bounds.left - padding) * scale,
        (box.height - height * scale) / 2 - (bounds.top - padding) * scale,
      ),
    );
  }

  Offset toLocal(Offset normalized) => origin + normalized * scale;

  Offset toNormalized(Offset local) => (local - origin) / scale;
}

/// The authoring surface: the glyph as a tube, numbered arcs, whatever has
/// been drawn on it, and — once an order exists — a replay of the pen path
/// that order describes.
class AuthoringCanvas extends StatelessWidget {
  final GlyphSkeleton skeleton;

  /// Raw finger paths, one per pen-down, in normalized 0..1 space.
  final List<List<Offset>> ink;

  /// The pen path an authored order composes to. Non-null puts the canvas in
  /// replay mode: the ink is hidden and this is animated instead.
  final List<List<Offset>>? preview;

  /// How far through the replay, 0..1 across all strokes including pauses.
  final double previewProgress;

  /// When each stroke of the replay runs. Required whenever [preview] is set.
  final PreviewTimeline? timeline;

  final bool showArcLabels;
  final AuthoringCanvasConfig canvasConfig;
  final ThemeColors colors;
  final ValueChanged<Offset>? onPointerDown;
  final ValueChanged<Offset>? onPointerMove;
  final VoidCallback? onPointerUp;

  const AuthoringCanvas({
    super.key,
    required this.skeleton,
    required this.ink,
    required this.canvasConfig,
    required this.colors,
    this.preview,
    this.previewProgress = 0,
    this.timeline,
    this.showArcLabels = true,
    this.onPointerDown,
    this.onPointerMove,
    this.onPointerUp,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final fit = CanvasFit.of(
          size,
          skeleton.bounds,
          skeleton.tubeWidthFactor * canvasConfig.fitPaddingTubes,
        );

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (d) => onPointerDown?.call(fit.toNormalized(d.localPosition)),
          onPanUpdate: (d) => onPointerMove?.call(fit.toNormalized(d.localPosition)),
          onPanEnd: (_) => onPointerUp?.call(),
          child: CustomPaint(
            size: size,
            painter: _AuthoringPainter(
              skeleton: skeleton,
              fit: fit,
              ink: ink,
              preview: preview,
              previewProgress: previewProgress,
              timeline: timeline,
              showArcLabels: showArcLabels,
              canvasConfig: canvasConfig,
              colors: colors,
            ),
          ),
        );
      },
    );
  }
}

class _AuthoringPainter extends CustomPainter {
  final GlyphSkeleton skeleton;
  final CanvasFit fit;
  final List<List<Offset>> ink;
  final List<List<Offset>>? preview;
  final double previewProgress;
  final PreviewTimeline? timeline;
  final bool showArcLabels;
  final AuthoringCanvasConfig canvasConfig;
  final ThemeColors colors;

  _AuthoringPainter({
    required this.skeleton,
    required this.fit,
    required this.ink,
    required this.preview,
    required this.previewProgress,
    required this.timeline,
    required this.showArcLabels,
    required this.canvasConfig,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(fit.origin.dx, fit.origin.dy);
    canvas.scale(fit.scale);

    _paintTube(canvas);
    final replay = preview;
    if (replay != null) {
      _paintPreview(canvas, replay);
    } else {
      _paintInk(canvas);
    }
    canvas.restore();

    // Labels carry text, which does not survive being drawn into a scaled
    // canvas legibly, so they go on in pixel space.
    if (showArcLabels && preview == null) _paintArcLabels(canvas);
  }

  Paint _strokePaint(double width) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true;

  Path _pathOf(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    return path;
  }

  /// Every arc, as the letter the author is writing over.
  void _paintTube(Canvas canvas) {
    final paint = _strokePaint(skeleton.tubeWidthFactor)..color = colors.letterTube;
    for (final arc in skeleton.arcs) {
      if (arc.points.length < 2) continue;
      canvas.drawPath(_pathOf(arc.points), paint);
    }
  }

  void _paintInk(Canvas canvas) {
    final paint = _strokePaint(canvasConfig.inkWidthFactor)..color = colors.primary;
    for (final stroke in ink) {
      if (stroke.length < 2) {
        if (stroke.length == 1) {
          canvas.drawCircle(stroke.first, canvasConfig.inkWidthFactor / 2,
              Paint()..color = colors.primary);
        }
        continue;
      }
      canvas.drawPath(_pathOf(stroke), paint);
    }
  }

  /// The replay. Strokes already finished stay on the canvas, the current one
  /// grows, and a dot rides the pen — the whole point being to see the order
  /// and direction, which a still picture cannot show.
  void _paintPreview(Canvas canvas, List<List<Offset>> strokes) {
    if (strokes.isEmpty) return;
    final donePaint = _strokePaint(skeleton.tubeWidthFactor * 0.7)
      ..color = colors.traceEnd.withValues(alpha: 0.55);
    final livePaint = _strokePaint(skeleton.tubeWidthFactor * 0.7)..color = colors.traceEnd;

    final spans = timeline ?? PreviewTimeline.even(strokes.length);
    for (var i = 0; i < strokes.length; i++) {
      final fraction = spans.fractionAt(i, previewProgress);
      if (fraction <= 0) continue;
      final points = _leading(strokes[i], fraction);
      if (points.length < 2) continue;
      canvas.drawPath(_pathOf(points), fraction >= 1 ? donePaint : livePaint);
      if (fraction < 1) {
        canvas.drawCircle(points.last, skeleton.tubeWidthFactor * 0.55,
            Paint()..color = colors.primary);
      }
      // Where each stroke starts, so the order reads at a glance.
      canvas.drawCircle(strokes[i].first, canvasConfig.endpointRadiusFactor,
          Paint()..color = colors.success);
    }
  }

  List<Offset> _leading(List<Offset> points, double fraction) {
    if (fraction >= 1) return points;
    final upTo = (points.length * fraction).ceil().clamp(2, points.length);
    return points.sublist(0, upTo);
  }

  /// Number every arc, without the numbers landing on top of each other.
  ///
  /// The midpoint is the obvious spot and usually the right one, but where
  /// short arcs cluster at a junction their midpoints can be closer together
  /// than the labels are wide — ஔ had two 0.017 apart with a label radius of
  /// 0.028, so one hid the other completely. Each arc therefore gets a few
  /// candidate spots along its own length, and takes whichever is furthest
  /// from the labels already placed. Shortest arcs choose first, because
  /// they have the least room to move.
  void _paintArcLabels(Canvas canvas) {
    final radius = canvasConfig.arcLabelRadiusFactor * fit.scale;
    final placed = <Offset>[];
    final byNeed = skeleton.arcs.toList()
      ..sort((a, b) => a.length.compareTo(b.length));

    final positions = <int, Offset>{};
    for (final arc in byNeed) {
      if (arc.points.isEmpty) continue;
      Offset? best;
      var bestClearance = -1.0;
      for (final candidate in _labelCandidates(arc, radius)) {
        final clearance = placed.isEmpty
            ? double.infinity
            : placed.map((p) => (p - candidate).distance).reduce(math.min);
        if (clearance > bestClearance) {
          bestClearance = clearance;
          best = candidate;
        }
        if (clearance.isInfinite || clearance > radius * 2.2) break;
      }
      if (best == null) continue;
      placed.add(best);
      positions[arc.index] = best;
    }

    for (final entry in positions.entries) {
      canvas.drawCircle(
          entry.value, radius, Paint()..color = colors.ink.withValues(alpha: 0.8));
      final label = TextPainter(
        text: TextSpan(
          text: '${entry.key}',
          style: TextStyle(
            color: colors.canvasBackground,
            fontSize: canvasConfig.arcLabelFontFactor * fit.scale,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, entry.value - Offset(label.width / 2, label.height / 2));
    }
  }

  /// Spots on or just beside [arc] where its number could go, best first.
  Iterable<Offset> _labelCandidates(SkeletonArc arc, double radius) sync* {
    const alongs = [0.5, 0.35, 0.65, 0.22, 0.78];
    for (final push in [0.0, 1.0, -1.0, 2.0, -2.0]) {
      for (final along in alongs) {
        final i = ((arc.points.length - 1) * along).round();
        final point = fit.toLocal(arc.points[i]);
        if (push == 0.0) {
          yield point;
          continue;
        }
        // Sidestep perpendicular to the arc, so the label still reads as
        // belonging to it.
        final ahead = arc.points[math.min(i + 1, arc.points.length - 1)];
        final behind = arc.points[math.max(i - 1, 0)];
        final tangent = fit.toLocal(ahead) - fit.toLocal(behind);
        final norm = tangent.distance;
        if (norm == 0) {
          yield point;
          continue;
        }
        yield point +
            Offset(-tangent.dy / norm, tangent.dx / norm) * (push * radius * 1.15);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AuthoringPainter old) {
    return old.skeleton != skeleton ||
        old.fit.scale != fit.scale ||
        old.fit.origin != fit.origin ||
        old.ink != ink ||
        old.preview != preview ||
        old.previewProgress != previewProgress ||
        old.timeline != timeline ||
        old.showArcLabels != showArcLabels ||
        old.colors != colors;
  }
}

/// When each stroke of a replay runs, as fractions of the whole.
///
/// Strokes get equal time rather than time by length, and there is a pause
/// between them and a hold at the end — the replay is being watched to judge
/// an order, so where one stroke stops and the next begins has to be
/// unmissable.
class PreviewTimeline {
  final List<double> _starts;
  final List<double> _ends;
  final Duration total;

  const PreviewTimeline._(this._starts, this._ends, this.total);

  factory PreviewTimeline(int strokeCount, PreviewConfig config) {
    if (strokeCount <= 0) {
      return const PreviewTimeline._([], [], Duration.zero);
    }
    final totalMs = strokeCount * config.strokeDurationMs +
        (strokeCount - 1) * config.pauseBetweenStrokesMs +
        config.holdAtEndMs;
    final starts = <double>[];
    final ends = <double>[];
    for (var i = 0; i < strokeCount; i++) {
      final startMs = i * (config.strokeDurationMs + config.pauseBetweenStrokesMs);
      starts.add(startMs / totalMs);
      ends.add((startMs + config.strokeDurationMs) / totalMs);
    }
    return PreviewTimeline._(starts, ends, Duration(milliseconds: totalMs));
  }

  /// Equal spans with no pauses — the fallback when no config is to hand.
  factory PreviewTimeline.even(int strokeCount) {
    final starts = <double>[];
    final ends = <double>[];
    for (var i = 0; i < strokeCount; i++) {
      starts.add(i / strokeCount);
      ends.add((i + 1) / strokeCount);
    }
    return PreviewTimeline._(starts, ends, Duration.zero);
  }

  double fractionAt(int strokeIndex, double progress) {
    if (strokeIndex >= _starts.length) return 0;
    final start = _starts[strokeIndex];
    final end = _ends[strokeIndex];
    if (end <= start) return 1;
    return ((progress - start) / (end - start)).clamp(0.0, 1.0);
  }
}
