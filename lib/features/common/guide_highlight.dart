import 'package:flutter/material.dart';

/// A light that travels round the edge of whatever comes next.
///
/// The app locks nothing, so a child arriving at a screen full of open letters
/// has no idea which one to touch first. This is what tells them: the *one*
/// thing that is next, and nothing else. Exactly one of these is on any screen
/// — two would be a choice, which is the thing it exists to remove.
///
/// It moves rather than merely glows because a still ring reads as decoration
/// on a screen that already has coloured borders everywhere.
///
/// **Stops under reduced motion**, where it falls back to a solid ring. That
/// is worth honouring on its own, and it is also what keeps it out of
/// `pumpAndSettle` — a repeating controller schedules frames forever.
class GuideHighlight extends StatefulWidget {
  final bool active;

  /// Rounded rectangle for a tile, a big radius for a round bubble.
  final BorderRadius borderRadius;

  final Color color;
  final Widget child;

  const GuideHighlight({
    super.key,
    required this.active,
    required this.color,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
  });

  @override
  State<GuideHighlight> createState() => _GuideHighlightState();
}

class _GuideHighlightState extends State<GuideHighlight>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  bool get _still => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(GuideHighlight old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.active && !_still) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => CustomPaint(
        foregroundPainter: _GuidePainter(
          progress: _still ? -1 : _controller.value,
          color: widget.color,
          borderRadius: widget.borderRadius,
        ),
        child: child,
      ),
      child: widget.child,
    );
  }
}

class _GuidePainter extends CustomPainter {
  /// 0..1 as the light goes round; negative for the still fallback.
  final double progress;
  final Color color;
  final BorderRadius borderRadius;

  const _GuidePainter({
    required this.progress,
    required this.color,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Scaled to what it is ringing: a fixed width reads well on a 92px letter
    // bubble and looks like a hairline on a 220px tile.
    final width = (size.shortestSide * 0.055).clamp(4.0, 8.0);
    final rect = borderRadius.toRRect(
      Rect.fromLTWH(-width, -width, size.width + width * 2, size.height + width * 2),
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..color = color;

    if (progress < 0) {
      canvas.drawRRect(rect, paint);
      return;
    }

    // A faint ring the whole way round so the shape reads even between
    // passes, with a bright segment running along it.
    canvas.drawRRect(rect, Paint.from(paint)..color = color.withValues(alpha: 0.3));
    for (final metric in (Path()..addRRect(rect)).computeMetrics()) {
      final head = metric.length * progress;
      final tail = head - metric.length * 0.28;
      canvas.drawPath(
        metric.extractPath(tail.clamp(0.0, metric.length), head),
        paint,
      );
      // The segment wraps rather than vanishing at the seam.
      if (tail < 0) {
        canvas.drawPath(metric.extractPath(metric.length + tail, metric.length), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_GuidePainter old) =>
      old.progress != progress || old.color != color;
}

/// The back arrow every screen carries, in a ring so it reads as a button.
///
/// A bare arrow on a cream background is easy for a four-year-old to miss.
/// The system gesture works, but they do not know that.
class BackCircleButton extends StatelessWidget {
  final Color color;
  final Color background;
  final Color border;

  const BackCircleButton({
    super.key,
    required this.color,
    required this.background,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    return CircleIconButton(
      icon: Icons.arrow_back_rounded,
      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      color: color,
      background: background,
      border: border,
      onPressed: () => Navigator.of(context).maybePop(),
    );
  }
}

/// A round, ringed icon button. Shared so the back arrow and the quit button
/// are visibly the same kind of control.
class CircleIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final Color background;
  final Color border;
  final VoidCallback onPressed;

  /// The ring's diameter and the icon inside it. Default to the size every
  /// existing caller (back arrows, the old bare quit button) was built at;
  /// a caller wanting its button to stand out — the Parent Zone entry, which
  /// now carries settings-weight rather than a plain nav action — can size
  /// up without every other ringed button in the app moving with it.
  final double size;
  final double iconSize;

  const CircleIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.background,
    required this.border,
    required this.onPressed,
    this.size = 44,
    this.iconSize = 24,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: tooltip,
      button: true,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: background,
          shape: CircleBorder(side: BorderSide(color: border, width: 2.5)),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(icon, size: iconSize, color: color),
            ),
          ),
        ),
      ),
    );
  }
}
