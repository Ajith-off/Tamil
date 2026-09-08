/// Tuning for the stroke-order authoring screen (`assets/config/authoring_config.json`).
///
/// Dev tooling rather than a child-facing screen, but the no-magic-numbers
/// rule holds all the same — these are thresholds that get adjusted by feel
/// while authoring, and hunting them down in Dart source would be tedious.
library;

/// How a drawn finger path gets matched to the glyph's skeleton arcs.
class SnapConfig {
  /// Spacing, in normalized units, the drawn path is resampled to before
  /// matching. Small enough that a short arc still collects several samples.
  final double resampleSpacing;

  /// How far a sample may sit from an arc and still count as being on it,
  /// as a multiple of the letter's tube width. Beyond this the sample is
  /// treated as pen-in-the-air and reported rather than guessed at.
  ///
  /// Generous on purpose. Which arc a sample belongs to is decided by
  /// nearest-wins, so a loose limit costs nothing; all this threshold
  /// decides is whether the finger was over the letter at all.
  final double snapDistanceFactor;

  /// Floor under the above, in normalized units, so a hairline letter like
  /// ஔ does not demand more precision than a fingertip has.
  final double minSnapDistance;

  /// Fewest consecutive samples that count as visiting an arc. Crossing a
  /// junction clips the corner of a neighbouring arc for a sample or two.
  final int minSamplesPerArc;

  /// Fraction of an arc that must be covered before the visit is taken at
  /// face value. Below this it is flagged: probably a stray crossing.
  final double minArcCoverage;

  /// How close an arc's two ends must come, as a fraction of the arc's own
  /// length, for it to count as a closed loop — where the position along the
  /// arc wraps and direction has to be read differently. Relative rather
  /// than absolute, or a short straight connector reads as a tiny loop.
  final double closedArcRatio;

  /// How far apart, in normalized units, two arcs written back to back may
  /// end up before the pen is judged to have jumped between them. Arcs that
  /// meet share their junction point exactly, so a real join measures zero
  /// and anything above rounding means a piece of the letter is missing.
  final double maxJoinGap;

  const SnapConfig({
    required this.resampleSpacing,
    required this.snapDistanceFactor,
    required this.minSnapDistance,
    required this.minSamplesPerArc,
    required this.minArcCoverage,
    required this.closedArcRatio,
    required this.maxJoinGap,
  });

  factory SnapConfig.fromJson(Map<String, dynamic> json) {
    return SnapConfig(
      resampleSpacing: (json['resampleSpacing'] as num).toDouble(),
      snapDistanceFactor: (json['snapDistanceFactor'] as num).toDouble(),
      minSnapDistance: (json['minSnapDistance'] as num).toDouble(),
      minSamplesPerArc: (json['minSamplesPerArc'] as num).toInt(),
      minArcCoverage: (json['minArcCoverage'] as num).toDouble(),
      closedArcRatio: (json['closedArcRatio'] as num).toDouble(),
      maxJoinGap: (json['maxJoinGap'] as num).toDouble(),
    );
  }

  /// The snap limit for a letter whose tube is [tubeWidthFactor] wide.
  double snapDistanceFor(double tubeWidthFactor) =>
      (tubeWidthFactor * snapDistanceFactor) < minSnapDistance
          ? minSnapDistance
          : tubeWidthFactor * snapDistanceFactor;
}

/// Sizes on the authoring canvas, as fractions of the letter's own scale.
class AuthoringCanvasConfig {
  final double inkWidthFactor;
  final double arcLabelRadiusFactor;
  final double arcLabelFontFactor;
  final double endpointRadiusFactor;

  /// Breathing room around the letter when fitting it to the canvas, in
  /// multiples of its tube width. The child-facing canvas is square, but
  /// this one fits the letter's own bounding box — ஔ is nearly twice as
  /// wide as it is tall, and a square would waste a third of the space that
  /// a finger needs to be accurate in.
  final double fitPaddingTubes;

  const AuthoringCanvasConfig({
    required this.inkWidthFactor,
    required this.arcLabelRadiusFactor,
    required this.arcLabelFontFactor,
    required this.endpointRadiusFactor,
    required this.fitPaddingTubes,
  });

  factory AuthoringCanvasConfig.fromJson(Map<String, dynamic> json) {
    return AuthoringCanvasConfig(
      inkWidthFactor: (json['inkWidthFactor'] as num).toDouble(),
      arcLabelRadiusFactor: (json['arcLabelRadiusFactor'] as num).toDouble(),
      arcLabelFontFactor: (json['arcLabelFontFactor'] as num).toDouble(),
      endpointRadiusFactor: (json['endpointRadiusFactor'] as num).toDouble(),
      fitPaddingTubes: (json['fitPaddingTubes'] as num).toDouble(),
    );
  }
}

/// Timings for the replay that verifies an authored order.
class PreviewConfig {
  final int strokeDurationMs;
  final int pauseBetweenStrokesMs;
  final int holdAtEndMs;

  const PreviewConfig({
    required this.strokeDurationMs,
    required this.pauseBetweenStrokesMs,
    required this.holdAtEndMs,
  });

  factory PreviewConfig.fromJson(Map<String, dynamic> json) {
    return PreviewConfig(
      strokeDurationMs: (json['strokeDurationMs'] as num).toInt(),
      pauseBetweenStrokesMs: (json['pauseBetweenStrokesMs'] as num).toInt(),
      holdAtEndMs: (json['holdAtEndMs'] as num).toInt(),
    );
  }
}

class AuthoringConfig {
  final SnapConfig snap;
  final AuthoringCanvasConfig canvas;
  final PreviewConfig preview;

  const AuthoringConfig({
    required this.snap,
    required this.canvas,
    required this.preview,
  });

  factory AuthoringConfig.fromJson(Map<String, dynamic> json) {
    return AuthoringConfig(
      snap: SnapConfig.fromJson(json['snap'] as Map<String, dynamic>),
      canvas: AuthoringCanvasConfig.fromJson(json['canvas'] as Map<String, dynamic>),
      preview: PreviewConfig.fromJson(json['preview'] as Map<String, dynamic>),
    );
  }
}
