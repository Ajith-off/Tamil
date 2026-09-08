import 'package:flutter/material.dart';

import '../../../core/config/models/games_config.dart';
import '../../../core/config/models/theme_config.dart';

/// What the border of a box is saying right now.
enum SlotVerdict { idle, checking, correct, wrong }

/// One box of the word: the target character as a shadow, whatever has been
/// dropped in so far, and a border that reports on the last drop.
///
/// The border is the feedback, not the letter — a child watching their own
/// finger needs the answer to arrive at the edge of the box they are looking
/// at, and a colour change alone is easy to miss mid-drag.
class WordSlotBox extends StatelessWidget {
  /// The character to show faintly while the box is empty.
  final String shadowChar;

  /// What has actually been dropped: null while empty, the consonant while
  /// half built, the whole character once full.
  final String? filledChar;

  /// Shown instead of [filledChar] while a drop is being explained: the tile
  /// that just landed, or — with [crossed] — what a wrong drop built. Either
  /// way the box goes back to [filledChar] afterwards.
  final String? overrideChar;

  /// Draws a cross over whatever is shown.
  final bool crossed;

  final SlotVerdict verdict;

  /// 0..1 while the light runs the border.
  final double snakeProgress;

  final bool isTargeted;
  final WordBuilderConfig config;
  final ThemeColors colors;

  const WordSlotBox({
    super.key,
    required this.shadowChar,
    required this.filledChar,
    this.overrideChar,
    this.crossed = false,
    required this.verdict,
    required this.snakeProgress,
    required this.isTargeted,
    required this.config,
    required this.colors,
  });

  Color get _borderColor => switch (verdict) {
        SlotVerdict.correct => colors.success,
        SlotVerdict.wrong => colors.retry,
        SlotVerdict.checking => colors.primary,
        SlotVerdict.idle => isTargeted ? colors.primary : colors.starEmpty,
      };

  @override
  Widget build(BuildContext context) {
    final shown = overrideChar ?? filledChar;
    final solid = shown != null;
    return SizedBox(
      width: config.slotWidth,
      height: config.slotHeight,
      child: CustomPaint(
        painter: _SlotBorderPainter(
          color: _borderColor,
          idleColor: colors.starEmpty,
          width: config.slotBorderWidth,
          radius: config.slotCornerRadius,
          snakeProgress: verdict == SlotVerdict.checking ? snakeProgress : 0,
          fill: colors.canvasBackground,
        ),
        foregroundPainter: !crossed
            ? null
            : _CrossPainter(
                color: colors.retry.withValues(alpha: config.crossOpacity),
                width: config.slotBorderWidth * config.crossWidthFactor,
              ),
        child: Center(
          // A wrap-sign character — கொ, கோ, கௌ — draws strokes on both sides
          // of the consonant and measures wider than a plain letter at the
          // same font size. Text wraps by default once its width outgrows
          // the box, which splits the character across two lines instead of
          // keeping it whole — the second line then spills out below the
          // fixed-height box since nothing here clips it. FittedBox scales
          // the whole glyph down to fit instead, however wide it is.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: config.slotWidth * 0.08),
              child: Text(
                solid ? shown : shadowChar,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  fontSize: config.slotHeight * 0.46,
                  fontWeight: FontWeight.bold,
                  color: solid
                      ? colors.textPrimary
                      // The shadow says which letter belongs here; it must be
                      // readable enough to aim at and faint enough not to look
                      // like an answer already given.
                      : colors.textSecondary.withValues(alpha: config.shadowOpacity),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A cross over the whole box. Drawn on top of the letter rather than beside
/// it: the mark has to be about the letter the child just made.
class _CrossPainter extends CustomPainter {
  final Color color;
  final double width;

  const _CrossPainter({required this.color, required this.width});

  @override
  void paint(Canvas canvas, Size size) {
    final inset = size.shortestSide * 0.18;
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(inset, inset),
      Offset(size.width - inset, size.height - inset),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - inset, inset),
      Offset(inset, size.height - inset),
      paint,
    );
  }

  @override
  bool shouldRepaint(_CrossPainter old) => old.color != color || old.width != width;
}

/// Draws the box, and the light that runs its border.
class _SlotBorderPainter extends CustomPainter {
  final Color color;
  final Color idleColor;
  final double width;
  final double radius;
  final double snakeProgress;
  final Color fill;

  const _SlotBorderPainter({
    required this.color,
    required this.idleColor,
    required this.width,
    required this.radius,
    required this.snakeProgress,
    required this.fill,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(width / 2, width / 2, size.width - width, size.height - width),
      Radius.circular(radius),
    );
    canvas.drawRRect(rect, Paint()..color = fill);

    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;

    if (snakeProgress <= 0) {
      canvas.drawRRect(rect, border..color = color);
      return;
    }

    // Mid-check: the resting border stays, and a bright segment runs round it.
    canvas.drawRRect(rect, border..color = idleColor);
    final path = Path()..addRRect(rect);
    for (final metric in path.computeMetrics()) {
      final head = metric.length * snakeProgress.clamp(0.0, 1.0);
      // A segment rather than a growing arc, so it reads as something
      // travelling rather than the border simply filling up.
      final tail = (head - metric.length * 0.3).clamp(0.0, metric.length);
      canvas.drawPath(metric.extractPath(tail, head), border..color = color);
    }
  }

  @override
  bool shouldRepaint(_SlotBorderPainter old) =>
      old.color != color ||
      old.snakeProgress != snakeProgress ||
      old.width != width ||
      old.radius != radius;
}
