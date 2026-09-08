import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The two things a child collects, defined once.
///
/// Every reward mark in the app — the three under a letter, the totals on a
/// tile, the badge in a corner — comes from here, so it reads as one thing
/// wherever it appears and changing it is a single edit.
class RewardIcons {
  const RewardIcons._();

  /// A token, not money. Material's coin icons all carry a dollar sign,
  /// which is the wrong currency and the wrong idea — these buy game hearts and
  /// nothing else (CLAUDE.md section 7).
  static const IconData coin = Icons.toll_rounded;
}

/// A magic wand: a slim handle running up from the lower left to a big
/// five-pointed star, a light on each of its five corners.
///
/// Drawn rather than picked from Material, which has a wand
/// (`auto_fix_high`) and a pencil (`edit`) but neither with the star large
/// enough to be the point of the mark. The wand is the pen the child has
/// been dragging round the canvas; the star is what it just made.
///
/// **Shaded from the colour it is given, never from a fixed gold.** The same
/// mark has to serve as earned and unearned, so the highlight and shadow are
/// lerped off [color] — pass gold and it looks like polished gold, pass the
/// empty grey and it stays a quiet grey with the same form.
class MagicPenStar extends StatelessWidget {
  final double size;
  final Color color;

  const MagicPenStar({super.key, required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _MagicPenStarPainter(color)),
    );
  }
}

/// Paints the same shaded star the reward mark uses, straight onto a canvas.
///
/// Shared so the star that blooms in the middle of the completion burst is
/// the *same* star a child collects, rather than a second one that happens to
/// look similar.
void paintShadedStar(
  Canvas canvas,
  Offset centre,
  double radius,
  Color base, {
  double turn = -0.035,
  double opacity = 1,
  bool facets = true,
}) {
  if (radius <= 0) return;
  final light = Color.lerp(base, Colors.white, 0.55)!.withValues(alpha: opacity);
  final deep =
      Color.lerp(base, const Color(0xFF8A5A00), 0.34)!.withValues(alpha: opacity);
  final body = base.withValues(alpha: opacity);

  canvas.drawPath(
    _starPathAt(centre, radius, 5, 0.46, turn),
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [light, body, deep],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: centre, radius: radius))
      ..isAntiAlias = true,
  );
  if (!facets) return;

  final inner = radius * 0.46;
  final lit = Paint()
    ..color = light.withValues(alpha: 0.55 * opacity)
    ..isAntiAlias = true;
  final shade = Paint()
    ..color = deep.withValues(alpha: 0.38 * opacity)
    ..isAntiAlias = true;
  for (var k = 0; k < 5; k++) {
    final point = -math.pi / 2 + turn * 2 * math.pi + k * 2 * math.pi / 5;
    Offset at(double a, double r) => centre + Offset(math.cos(a), math.sin(a)) * r;
    canvas.drawPath(
      Path()
        ..moveTo(centre.dx, centre.dy)
        ..lineTo(at(point, radius).dx, at(point, radius).dy)
        ..lineTo(at(point - math.pi / 5, inner).dx, at(point - math.pi / 5, inner).dy)
        ..close(),
      lit,
    );
    canvas.drawPath(
      Path()
        ..moveTo(centre.dx, centre.dy)
        ..lineTo(at(point, radius).dx, at(point, radius).dy)
        ..lineTo(at(point + math.pi / 5, inner).dx, at(point + math.pi / 5, inner).dy)
        ..close(),
      shade,
    );
  }
}

/// A [points]-pointed star. [innerRatio] sets how deep the notches cut —
/// 0.46 for the solid five-pointed star, 0.28 for the pinched four-pointed
/// sparkles. [turn] rotates it, in turns.
Path _starPathAt(
    Offset centre, double radius, int points, double innerRatio, double turn) {
  final path = Path();
  if (radius <= 0) return path;
  for (var i = 0; i < points * 2; i++) {
    final r = i.isEven ? radius : radius * innerRatio;
    final angle = -math.pi / 2 + turn * 2 * math.pi + i * math.pi / points;
    final p = centre + Offset(math.cos(angle) * r, math.sin(angle) * r);
    i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
  }
  return path..close();
}

class _MagicPenStarPainter extends CustomPainter {
  final Color color;

  _MagicPenStarPainter(this.color);

  // The whole mark, as fractions of the box.
  static const _starCentre = Offset(0.545, 0.435);
  static const _starRadius = 0.265;

  /// Turned a little, so the star sits on the handle rather than balancing
  /// on a point.
  static const _starTurn = -0.035;

  /// Sparkles sit on the star's own points, one per corner, this far out
  /// along the same spokes.
  static const _sparkleReach = 1.28;
  static const _sparkleRadius = 0.068;

  /// Handle ends *inside* the star body so the join disappears behind it —
  /// otherwise the barrel lies across the lower-left point and hides it.
  static const _handleFrom = Offset(0.135, 0.895);
  static const _handleTo = Offset(0.475, 0.555);
  static const _handleWidth = 0.10;

  Color get _light => Color.lerp(color, Colors.white, 0.55)!;
  Color get _deep => Color.lerp(color, const Color(0xFF8A5A00), 0.34)!;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final centre = _starCentre * s;
    final radius = s * _starRadius;

    _paintHandle(canvas, s);

    // The star body, lit from the top left the way the handle is. Facets —
    // each point split into a lit half and a shadowed one — are what make it
    // read as gold rather than a flat shape, but they are too fine to
    // survive a small mark.
    paintShadedStar(canvas, centre, radius, color,
        turn: _starTurn, facets: s >= 24);

    // A light on every corner, taken from the star's own spokes rather than
    // placed by hand — so there is exactly one per point and they cannot
    // drift off the tips if the star is resized or turned.
    //
    // Dropped below about 18 logical pixels: at that size they are a pixel
    // across and turn the outline to mush. The star alone still reads.
    if (s < 18) return;
    final sparkle = Paint()
      ..color = _light
      ..isAntiAlias = true;
    for (final angle in _pointAngles()) {
      final at = centre + Offset(math.cos(angle), math.sin(angle)) * (radius * _sparkleReach);
      canvas.drawPath(_starPathAt(at, s * _sparkleRadius, 4, 0.28, 0), sparkle);
    }
  }

  void _paintHandle(Canvas canvas, double s) {
    final from = _handleFrom * s;
    final to = _handleTo * s;
    canvas.drawLine(
      from,
      to,
      Paint()
        ..shader = LinearGradient(
          // Across the barrel, not along it: a rod is lit down one side.
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [_light, color, _deep],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromPoints(from, to))
        ..strokeWidth = s * _handleWidth
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke
        ..isAntiAlias = true,
    );
  }

  /// The direction of each of the star's five outer points.
  Iterable<double> _pointAngles() sync* {
    for (var k = 0; k < 5; k++) {
      yield -math.pi / 2 + _starTurn * 2 * math.pi + k * 2 * math.pi / 5;
    }
  }

  @override
  bool shouldRepaint(covariant _MagicPenStarPainter old) => old.color != color;
}
