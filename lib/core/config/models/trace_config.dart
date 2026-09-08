import 'trace_mode.dart';

/// What the canvas shows for one [TraceMode]. Mirrors one entry of
/// `trace_config.json`.
class TraceModeDefinition {
  final TraceMode id;

  /// Whether the letter itself is drawn as a thick guide tube.
  final bool showTube;

  /// Whether evenly spaced dots mark the path along the tube.
  final bool showDots;

  /// Whether the path is revealed one waypoint at a time: a single marker
  /// showing the next place to reach, which moves on as the child catches
  /// up with it. Guidance a child can act on without having to read a shape
  /// first — the letter itself appears behind them as they go.
  final bool showWaypoints;

  /// Whether the animated "watch it being written" demo plays first.
  final bool showTutorial;

  /// Whether the drawing area is outlined. Challenge gives the child a blank
  /// canvas with nothing on it at all, and a blank canvas has no visible
  /// edges — the border says where the letter is meant to go.
  final bool showFrame;

  /// When true the finger is not guided along the reference path at all:
  /// the child draws freehand and the result is only judged on submit.
  final bool freeDraw;

  /// Whether the reference letter's own starting point is marked before the
  /// child begins drawing. Challenge is otherwise fully freehand — no tube,
  /// no waypoints, no demo — but a starting position is not guidance about
  /// the letter's shape, only about where the same freehand attempt begins,
  /// which keeps the mode's own scoring from mistaking "started in a
  /// slightly different spot" for "drew the wrong shape". It disappears the
  /// moment the child's finger touches the canvas.
  final bool showStartPoint;

  /// How long the reference letter is flashed in full, at actual size,
  /// before drawing begins — 0 for every mode but Challenge. Not the
  /// animated stroke-order demo [showTutorial] drives: this is a single
  /// still glance at the finished shape, the way a child might look at a
  /// flashcard before covering it, not a tutorial. It exists so a freehand
  /// attempt starts from "I just saw what this looks like" rather than pure
  /// memory of a letter they haven't traced in three other modes' worth of
  /// guidance.
  final int previewDurationMs;

  const TraceModeDefinition({
    required this.id,
    required this.showTube,
    required this.showDots,
    required this.showWaypoints,
    required this.showTutorial,
    required this.showFrame,
    required this.freeDraw,
    this.showStartPoint = false,
    this.previewDurationMs = 0,
  });

  factory TraceModeDefinition.fromJson(Map<String, dynamic> json) {
    return TraceModeDefinition(
      id: TraceMode.fromId(json['id'] as String),
      showTube: json['showTube'] as bool,
      showDots: json['showDots'] as bool,
      showWaypoints: json['showWaypoints'] as bool? ?? false,
      showTutorial: json['showTutorial'] as bool,
      showFrame: json['showFrame'] as bool? ?? false,
      freeDraw: json['freeDraw'] as bool,
      showStartPoint: json['showStartPoint'] as bool? ?? false,
      previewDurationMs: (json['previewDurationMs'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Timing for the animated stroke-order demo.
class TutorialConfig {
  final int strokeDurationMs;
  final int pauseBetweenStrokesMs;
  final int holdAtEndMs;

  const TutorialConfig({
    required this.strokeDurationMs,
    required this.pauseBetweenStrokesMs,
    required this.holdAtEndMs,
  });

  factory TutorialConfig.fromJson(Map<String, dynamic> json) {
    return TutorialConfig(
      strokeDurationMs: (json['strokeDurationMs'] as num).toInt(),
      pauseBetweenStrokesMs: (json['pauseBetweenStrokesMs'] as num).toInt(),
      holdAtEndMs: (json['holdAtEndMs'] as num).toInt(),
    );
  }
}

/// The sparkle burst played when a letter is finished.
class CelebrationConfig {
  final int durationMs;
  final int particleCount;
  final double minParticleRadiusFactor;
  final double maxParticleRadiusFactor;
  final double spreadFactor;

  /// The magic star that blooms in the middle of the burst when the attempt
  /// earned one, as a fraction of the canvas.
  final double starRadiusFactor;

  const CelebrationConfig({
    required this.durationMs,
    required this.particleCount,
    required this.minParticleRadiusFactor,
    required this.maxParticleRadiusFactor,
    required this.spreadFactor,
    this.starRadiusFactor = 0.16,
  });

  factory CelebrationConfig.fromJson(Map<String, dynamic> json) {
    return CelebrationConfig(
      durationMs: (json['durationMs'] as num).toInt(),
      particleCount: (json['particleCount'] as num).toInt(),
      minParticleRadiusFactor: (json['minParticleRadiusFactor'] as num).toDouble(),
      maxParticleRadiusFactor: (json['maxParticleRadiusFactor'] as num).toDouble(),
      spreadFactor: (json['spreadFactor'] as num).toDouble(),
      starRadiusFactor: (json['starRadiusFactor'] as num?)?.toDouble() ?? 0.16,
    );
  }
}

class TraceConfig {
  final Map<TraceMode, TraceModeDefinition> modes;
  final TutorialConfig tutorial;
  final CelebrationConfig celebration;

  /// How many successful attempts in a row move the child up to the next
  /// mode. Advancing is automatic so nobody has to notice a button.
  final int advanceAfterSuccesses;

  const TraceConfig({
    required this.modes,
    required this.tutorial,
    required this.celebration,
    required this.advanceAfterSuccesses,
  });

  TraceModeDefinition definitionFor(TraceMode mode) => modes[mode]!;

  factory TraceConfig.fromJson(Map<String, dynamic> json) {
    final list = (json['modes'] as List<dynamic>)
        .map((e) => TraceModeDefinition.fromJson(e as Map<String, dynamic>))
        .toList();
    return TraceConfig(
      modes: {for (final m in list) m.id: m},
      tutorial: TutorialConfig.fromJson(json['tutorial'] as Map<String, dynamic>),
      celebration: CelebrationConfig.fromJson(json['celebration'] as Map<String, dynamic>),
      advanceAfterSuccesses: (json['advanceAfterSuccesses'] as num).toInt(),
    );
  }
}
