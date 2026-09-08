/// How the 100 marks for one character are divided between the four modes.
///
/// Easy and medium are completion marks: in both, the finger is snapped to
/// the path, so a child who keeps tracing will finish. That is deliberate —
/// half the score is always reachable by simply doing the work. Hard adds a
/// fluency bonus on top of completion, and challenge is the only mode where
/// the letter's actual shape is judged.
class MarksConfig {
  final int easyCompletion;
  final int mediumCompletion;
  final int hardCompletion;
  final int hardSpeed;
  final int challengeShape;

  const MarksConfig({
    required this.easyCompletion,
    required this.mediumCompletion,
    required this.hardCompletion,
    required this.hardSpeed,
    required this.challengeShape,
  });

  int get total =>
      easyCompletion + mediumCompletion + hardCompletion + hardSpeed + challengeShape;

  factory MarksConfig.fromJson(Map<String, dynamic> json) {
    return MarksConfig(
      easyCompletion: (json['easyCompletion'] as num).toInt(),
      mediumCompletion: (json['mediumCompletion'] as num).toInt(),
      hardCompletion: (json['hardCompletion'] as num).toInt(),
      hardSpeed: (json['hardSpeed'] as num).toInt(),
      challengeShape: (json['challengeShape'] as num).toInt(),
    );
  }
}

/// Cumulative marks needed for each star, out of [MarksConfig.total].
/// Marks needed for each star, out of the 100 a character is worth.
///
/// The first star sits at 30 rather than half marks so that finishing *hard*
/// on its own earns one. Hard is worth 20 + 10 fluency, so a child who skips
/// straight to the harder mode and succeeds used to score 30 and get nothing
/// — no star, and the next letter stayed locked — while an easier route
/// through easy and medium scored 50 and opened it. Rewarding the easy path
/// and not the hard one is backwards.
class StarThresholds {
  final int one;
  final int two;
  final int three;

  const StarThresholds({required this.one, required this.two, required this.three});

  factory StarThresholds.fromJson(Map<String, dynamic> json) {
    return StarThresholds(
      one: (json['one'] as num).toInt(),
      two: (json['two'] as num).toInt(),
      three: (json['three'] as num).toInt(),
    );
  }

  int starsFor(int marks) {
    if (marks >= three) return 3;
    if (marks >= two) return 2;
    if (marks >= one) return 1;
    return 0;
  }
}

/// Bounds for the hard-mode fluency bonus, expressed as seconds per unit of
/// path length so a long letter is allowed proportionally longer.
///
/// Nothing counts down and no clock is shown — see CLAUDE.md section 11, "no
/// countdown pressure". A child at or under [fastSecondsPerUnitLength] earns
/// the full bonus; at or over [slowSecondsPerUnitLength] they earn none, and
/// still keep every completion mark.
class SpeedConfig {
  final double fastSecondsPerUnitLength;
  final double slowSecondsPerUnitLength;

  const SpeedConfig({
    required this.fastSecondsPerUnitLength,
    required this.slowSecondsPerUnitLength,
  });

  factory SpeedConfig.fromJson(Map<String, dynamic> json) {
    return SpeedConfig(
      fastSecondsPerUnitLength: (json['fastSecondsPerUnitLength'] as num).toDouble(),
      slowSecondsPerUnitLength: (json['slowSecondsPerUnitLength'] as num).toDouble(),
    );
  }
}

/// Tunable technical parameters for the stroke analysis itself — never
/// hardcoded in the algorithm, always read from here.
class ScoringEngineParams {
  final int resamplePointCount;
  final double shapeToleranceRadius;
  final double countPenaltyPerExtraStroke;

  const ScoringEngineParams({
    required this.resamplePointCount,
    required this.shapeToleranceRadius,
    required this.countPenaltyPerExtraStroke,
  });

  factory ScoringEngineParams.fromJson(Map<String, dynamic> json) {
    return ScoringEngineParams(
      resamplePointCount: (json['resamplePointCount'] as num).toInt(),
      shapeToleranceRadius: (json['shapeToleranceRadius'] as num).toDouble(),
      countPenaltyPerExtraStroke: (json['countPenaltyPerExtraStroke'] as num).toDouble(),
    );
  }
}

class ScoringConfig {
  final MarksConfig marks;
  final StarThresholds starThresholds;
  final SpeedConfig speed;
  final ScoringEngineParams engine;

  const ScoringConfig({
    required this.marks,
    required this.starThresholds,
    required this.speed,
    required this.engine,
  });

  factory ScoringConfig.fromJson(Map<String, dynamic> json) {
    return ScoringConfig(
      marks: MarksConfig.fromJson(json['marks'] as Map<String, dynamic>),
      starThresholds: StarThresholds.fromJson(json['starThresholds'] as Map<String, dynamic>),
      speed: SpeedConfig.fromJson(json['speed'] as Map<String, dynamic>),
      engine: ScoringEngineParams.fromJson(json['engine'] as Map<String, dynamic>),
    );
  }
}
