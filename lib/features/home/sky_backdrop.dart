import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/config/models/theme_config.dart';

/// A quiet decorative layer behind the home screen: a sun with a couple of
/// clouds by day, a moon and a few twinkling stars by night. Purely
/// cosmetic, purely local — no asset, no network — and deliberately simple:
/// one small `CustomPainter`, one shared clock, nothing that competes with
/// the tiles a child is actually meant to look at (CLAUDE.md section 11:
/// gentle motion only). Kept soft on purpose — a background theme, not an
/// illustration — every shape here draws at low opacity.
class SkyBackdrop extends StatefulWidget {
  final ThemeColors colors;

  /// Which side of the toggle beside the Parent Zone button is picked —
  /// never read off the clock, so it stays put across a session and reads
  /// the same at any hour.
  final bool isDay;

  const SkyBackdrop({super.key, required this.colors, required this.isDay});

  @override
  State<SkyBackdrop> createState() => _SkyBackdropState();
}

class _SkyBackdropState extends State<SkyBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (still) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _SkyPainter(
            t: _controller.value,
            isDay: widget.isDay,
            sunColor: widget.colors.starFilled,
            cloudColor: widget.colors.canvasBackground,
            moonColor: widget.colors.textSecondary,
            starColor: widget.colors.starFilled,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _SkyPainter extends CustomPainter {
  final double t;
  final bool isDay;
  final Color sunColor;
  final Color cloudColor;
  final Color moonColor;
  final Color starColor;

  _SkyPainter({
    required this.t,
    required this.isDay,
    required this.sunColor,
    required this.cloudColor,
    required this.moonColor,
    required this.starColor,
  });

  // Same corner on every device, clear of the totals badge and the tile row
  // below it — a fraction of the canvas rather than a fixed pixel offset.
  static const _center = Alignment(0.82, -0.82);

  @override
  void paint(Canvas canvas, Size size) {
    final center = _center.alongSize(size);
    final breathe = 0.5 + 0.5 * math.sin(t * 2 * math.pi);
    if (isDay) {
      _paintSun(canvas, center, breathe);
      _paintClouds(canvas, size);
    } else {
      _paintMoon(canvas, center);
      _paintStars(canvas, size);
    }
  }

  void _paintSun(Canvas canvas, Offset center, double breathe) {
    final radius = 28 + breathe * 3;
    canvas.drawCircle(
      center,
      radius * 2.2,
      Paint()
        ..shader = RadialGradient(
          colors: [
            sunColor.withValues(alpha: 0.22),
            sunColor.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius * 2.2)),
    );
    // A background glow, not a bold disc — half the strength of the version
    // this replaced.
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = sunColor.withValues(alpha: 0.45),
    );
  }

  void _paintClouds(Canvas canvas, Size size) {
    // A real cloud silhouette — several overlapping ovals unioned into one
    // path, rather than a cluster of separate circles — one or two is
    // enough to read as weather without becoming a scene to look at.
    final scale = size.shortestSide * 0.09;
    _paintCloud(canvas, Offset(size.width * 0.60, size.height * 0.10), scale);
    _paintCloud(canvas, Offset(size.width * 0.17, size.height * 0.24), scale * 0.75);
  }

  void _paintCloud(Canvas canvas, Offset center, double s) {
    Path puff(Offset c, double r) => Path()..addOval(Rect.fromCircle(center: c, radius: r));

    var cloud = puff(center, s * 0.55);
    cloud = Path.combine(
      PathOperation.union,
      cloud,
      puff(center.translate(-s * 0.95, s * 0.12), s * 0.42),
    );
    cloud = Path.combine(
      PathOperation.union,
      cloud,
      puff(center.translate(s * 0.9, s * 0.14), s * 0.45),
    );
    cloud = Path.combine(
      PathOperation.union,
      cloud,
      puff(center.translate(-s * 0.35, -s * 0.3), s * 0.4),
    );
    cloud = Path.combine(
      PathOperation.union,
      cloud,
      puff(center.translate(s * 0.42, -s * 0.24), s * 0.36),
    );
    // The cloud's flat underside — an oval rather than a rounded rect stays
    // soft-edged like the rest of it.
    cloud = Path.combine(
      PathOperation.union,
      cloud,
      Path()
        ..addOval(
          Rect.fromCenter(
            center: center.translate(0, s * 0.32),
            width: s * 2.3,
            height: s * 0.7,
          ),
        ),
    );
    canvas.drawPath(cloud, Paint()..color = cloudColor.withValues(alpha: 0.55));
  }

  void _paintMoon(Canvas canvas, Offset center) {
    const radius = 26.0;
    canvas.drawCircle(
      center,
      radius * 2.0,
      Paint()
        ..shader = RadialGradient(
          colors: [
            moonColor.withValues(alpha: 0.16),
            moonColor.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius * 2.0)),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = moonColor.withValues(alpha: 0.5),
    );
    // A couple of soft craters — plain overlaid circles, not a cut-out, so
    // there is no blend-mode compositing to get wrong against whatever sits
    // behind this layer.
    canvas.drawCircle(
      center.translate(-radius * 0.35, radius * 0.2),
      radius * 0.22,
      Paint()..color = moonColor.withValues(alpha: 0.12),
    );
    canvas.drawCircle(
      center.translate(radius * 0.2, -radius * 0.3),
      radius * 0.15,
      Paint()..color = moonColor.withValues(alpha: 0.12),
    );
  }

  void _paintStars(Canvas canvas, Size size) {
    // Fixed, deterministic positions scattered across the upper third of the
    // screen, each twinkling out of phase with the others so the sky never
    // flashes as one block.
    const positions = [
      Offset(0.10, 0.20),
      Offset(0.20, 0.34),
      Offset(0.32, 0.14),
      Offset(0.48, 0.26),
      Offset(0.60, 0.12),
      Offset(0.70, 0.30),
      Offset(0.28, 0.44),
      Offset(0.55, 0.42),
    ];
    for (var i = 0; i < positions.length; i++) {
      final phase = i * 0.9;
      final twinkle =
          0.25 + 0.5 * (0.5 + 0.5 * math.sin(t * 2 * math.pi + phase));
      final p = Offset(
        positions[i].dx * size.width,
        positions[i].dy * size.height,
      );
      // A four-point sparkle, not a dot — every other one drawn a touch
      // larger so the sky reads as scattered stars rather than a repeated
      // stamp.
      final radius = i.isEven ? 4.0 : 3.0;
      canvas.drawPath(
        _sparklePath(p, radius),
        Paint()..color = starColor.withValues(alpha: twinkle),
      );
    }
  }

  /// A four-point star/sparkle: two overlapping diamonds, one long and
  /// narrow, one short and wide — reads as a twinkle rather than a plain
  /// four-pointed star.
  Path _sparklePath(Offset center, double radius) {
    Path diamond(double long, double short) => Path()
      ..moveTo(center.dx, center.dy - long)
      ..lineTo(center.dx + short, center.dy)
      ..lineTo(center.dx, center.dy + long)
      ..lineTo(center.dx - short, center.dy)
      ..close();
    return Path.combine(
      PathOperation.union,
      diamond(radius, radius * 0.28),
      diamond(radius * 0.28, radius),
    );
  }

  @override
  bool shouldRepaint(covariant _SkyPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.isDay != isDay;
}
