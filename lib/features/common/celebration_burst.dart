import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/config/models/theme_config.dart';
import '../../core/config/models/trace_config.dart';
import '../letters/reward_icons.dart';

/// One sparkle in a completion burst. Positions are normalized and generated
/// once per celebration so the burst does not reshuffle on every repaint.
class SparkleParticle {
  final Offset origin;
  final double angle;
  final double distance;
  final double radius;
  final double phase;

  const SparkleParticle({
    required this.origin,
    required this.angle,
    required this.distance,
    required this.radius,
    required this.phase,
  });
}

/// The burst a finished letter and a finished word both set off.
///
/// Shared rather than copied, for the reason `CategoryTile` is: they are the
/// same moment — "you finished it" — and a child should not have to read two
/// different celebrations as meaning one thing. It also means the burst is
/// tuned in one place, from one block of `trace_config.json`.
///
/// [seed] makes a given letter or word's burst reproducible, so a screenshot
/// of it is worth comparing against.
List<SparkleParticle> makeSparkles(CelebrationConfig config, {required int seed}) {
  final rng = math.Random(seed);
  return List.generate(config.particleCount, (_) {
    return SparkleParticle(
      origin: Offset(rng.nextDouble(), rng.nextDouble()),
      angle: rng.nextDouble() * math.pi * 2,
      distance: config.spreadFactor * (0.35 + rng.nextDouble() * 0.65),
      radius: config.minParticleRadiusFactor +
          rng.nextDouble() *
              (config.maxParticleRadiusFactor - config.minParticleRadiusFactor),
      phase: rng.nextDouble(),
    );
  });
}

/// Paints the burst around [origin], scaled by [side].
///
/// [progress] runs 0..1. Sparkles fly outward quickly and fade; above zero
/// [stars] a magic star blooms in the middle — the burst says "finished", the
/// star says "and it counted".
void paintCelebrationBurst(
  Canvas canvas,
  Offset origin,
  double side,
  double progress,
  List<SparkleParticle> sparkles,
  ThemeColors colors, {
  int stars = 0,
  double starRadiusFactor = 0.16,
}) {
  if (progress <= 0) return;
  final travel = Curves.easeOutCubic.transform(progress.clamp(0.0, 1.0));
  final fade = (1 - progress).clamp(0.0, 1.0);
  for (final s in sparkles) {
    final reach = s.distance * travel * side;
    final pos = origin +
        Offset(math.cos(s.angle), math.sin(s.angle)) * reach +
        Offset(0, (s.origin.dy - 0.5) * side * 0.2);
    final twinkle = 0.55 + 0.45 * math.sin((progress + s.phase) * math.pi * 4);
    canvas.drawCircle(
      pos,
      s.radius * side * twinkle,
      Paint()..color = colors.sparkle.withValues(alpha: fade * twinkle),
    );
  }
  if (stars <= 0) return;

  // Springs past its final size and settles back, so it lands rather than
  // merely appears.
  final overshoot = math.sin(travel * math.pi) * 0.25;
  final radius = starRadiusFactor * side * (travel + overshoot);
  if (radius <= 0) return;
  canvas.drawCircle(
    origin,
    radius * 1.5,
    Paint()..color = colors.sparkle.withValues(alpha: fade * 0.28),
  );
  // The same shaded star the child collects, not a second one that resembles it.
  paintShadedStar(canvas, origin, radius, colors.starFilled, opacity: fade);
}
