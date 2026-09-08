/// Canvas geometry, all expressed as fractions of the canvas's shorter side
/// so the letter scales identically on any screen.
class CanvasConfig {
  /// Thickness of the letter guide tube.
  final double tubeWidthFactor;

  /// Thickness of the darker outline drawn around the tube.
  final double tubeEdgeWidthFactor;

  /// Arc-length gap between the dots that mark the path.
  final double dotSpacingFactor;

  final double dotRadiusFactor;

  /// How far apart the waypoints sit. Deliberately far larger than
  /// [dotSpacingFactor]: at the dot spacing the marker lands under the
  /// child's own fingertip, showing where they already are instead of where
  /// to go, which made the guidance useless. It has to stay under
  /// [traceLookaheadFactor] so each one is reachable in a single movement.
  final double waypointSpacingFactor;

  /// How far ahead of the finger the waypoint must always stay.
  ///
  /// Without this the gap closes to nothing as the child arrives, and their
  /// own hand covers the very thing they are aiming at. The marker skips to
  /// the next one once they are within this much of it, so it is always
  /// somewhere they can see.
  final double waypointMinLeadFactor;

  /// The single "go here next" marker used by the waypoint guidance, and the
  /// soft ring around it. Much larger than a trail dot: it is the only thing
  /// on the canvas a child has to aim at, so it has to be worth aiming at.
  final double waypointRadiusFactor;
  final double waypointHaloFactor;

  /// The outline around the drawing area in challenge mode.
  final double frameInsetFactor;
  final double frameWidthFactor;
  final double frameCornerFactor;

  /// How far the finger may stray from the path and still advance the trace.
  /// Arc length a dot stroke counts as, for anything that weighs strokes by
  /// how long they are — the progress fraction, the fluency reference and
  /// how far the demo has got through one.
  ///
  /// A dot has no length: it is one point. Left at zero it would count for
  /// nothing, a letter that is only a dot would have nothing to divide by,
  /// and the demo would treat the puḷḷi as finished the instant it reached
  /// it. Nothing to do with [dotRadiusFactor], which sizes the guide dots
  /// strung along a path.
  final double dotStrokeLengthFactor;

  final double traceToleranceFactor;

  /// How far ahead along the path the finger may jump in one move — stops a
  /// child from skipping across a loop to a later part of the same stroke.
  final double traceLookaheadFactor;

  /// Arc-length step used when sampling the path to find the point nearest
  /// the finger.
  final double traceSampleStepFactor;

  /// Minimum movement (in normalized units) before a new point is recorded.
  final double minPointDistance;

  const CanvasConfig({
    required this.tubeWidthFactor,
    required this.tubeEdgeWidthFactor,
    required this.dotSpacingFactor,
    required this.dotRadiusFactor,
    required this.waypointSpacingFactor,
    required this.waypointMinLeadFactor,
    required this.waypointRadiusFactor,
    required this.waypointHaloFactor,
    required this.frameInsetFactor,
    required this.frameWidthFactor,
    required this.frameCornerFactor,
    required this.dotStrokeLengthFactor,
    required this.traceToleranceFactor,
    required this.traceLookaheadFactor,
    required this.traceSampleStepFactor,
    required this.minPointDistance,
  });

  factory CanvasConfig.fromJson(Map<String, dynamic> json) {
    return CanvasConfig(
      tubeWidthFactor: (json['tubeWidthFactor'] as num).toDouble(),
      tubeEdgeWidthFactor: (json['tubeEdgeWidthFactor'] as num).toDouble(),
      dotSpacingFactor: (json['dotSpacingFactor'] as num).toDouble(),
      dotRadiusFactor: (json['dotRadiusFactor'] as num).toDouble(),
      waypointSpacingFactor: (json['waypointSpacingFactor'] as num).toDouble(),
      waypointMinLeadFactor: (json['waypointMinLeadFactor'] as num).toDouble(),
      waypointRadiusFactor: (json['waypointRadiusFactor'] as num).toDouble(),
      waypointHaloFactor: (json['waypointHaloFactor'] as num).toDouble(),
      frameInsetFactor: (json['frameInsetFactor'] as num).toDouble(),
      frameWidthFactor: (json['frameWidthFactor'] as num).toDouble(),
      frameCornerFactor: (json['frameCornerFactor'] as num).toDouble(),
      dotStrokeLengthFactor: (json['dotStrokeLengthFactor'] as num).toDouble(),
      traceToleranceFactor: (json['traceToleranceFactor'] as num).toDouble(),
      traceLookaheadFactor: (json['traceLookaheadFactor'] as num).toDouble(),
      traceSampleStepFactor: (json['traceSampleStepFactor'] as num).toDouble(),
      minPointDistance: (json['minPointDistance'] as num).toDouble(),
    );
  }
}

class FeatureFlags {
  /// Master switch for every sound in the app — background music, click,
  /// celebration and letter speech (`lib/services/audio_service.dart`). The
  /// Parent Zone's music/sound switches (`AppSettings`) sit under this one:
  /// both have to be true for a given sound to actually play, so a device
  /// with no working audio output can be shipped silent by flipping this
  /// alone rather than three settings at once.
  final bool audioEnabled;

  /// Shows the stroke-order authoring button on the letter lists. Off now
  /// that all 247 characters are authored — it is developer tooling, and a
  /// child-facing screen must never lead anywhere like it. The screen itself
  /// is still there; turn this on to reach it again.
  final bool authoringEnabled;

  const FeatureFlags({
    required this.audioEnabled,
    this.authoringEnabled = false,
  });

  factory FeatureFlags.fromJson(Map<String, dynamic> json) {
    return FeatureFlags(
      audioEnabled: json['audioEnabled'] as bool,
      authoringEnabled: json['authoringEnabled'] as bool? ?? false,
    );
  }
}

/// How a child works their way along a category.
class ProgressionConfig {
  /// Stars needed on a letter before the next one opens up.
  ///
  /// **Zero: nothing is locked.** A child picks any character in any order,
  /// and what tells them where to go next is the guide highlight rather than
  /// a wall of padlocks (CLAUDE.md section 6). The chain logic is still here
  /// and still tested, so raising this brings gating back intact.
  final int starsToUnlockNext;

  const ProgressionConfig({required this.starsToUnlockNext});

  factory ProgressionConfig.fromJson(Map<String, dynamic> json) {
    return ProgressionConfig(
      starsToUnlockNext: (json['starsToUnlockNext'] as num).toInt(),
    );
  }
}

/// Coins (CLAUDE.md section 7).
///
/// One sink: game hearts. There are no hints — a paid shortcut past forming a
/// letter is not teaching, and a second sink competing with play is what makes
/// a balance impossible to reason about.
class CoinsConfig {
  /// What a child starts with, so the games are open on day one.
  ///
  /// Thirteen, which buys 39 word openings — and a clean round hands its heart
  /// straight back, so in practice it only ever runs down on rounds that went
  /// wrong. Generous without being infinite.
  final int startingBalance;

  /// Earned for taking a character all the way to three stars. Letters
  /// themselves never cost coins and are never gated on them — coins reach
  /// the games and nothing else (CLAUDE.md section 6).
  final int perThreeStarLetter;

  const CoinsConfig({
    required this.startingBalance,
    required this.perThreeStarLetter,
  });

  factory CoinsConfig.fromJson(Map<String, dynamic> json) {
    return CoinsConfig(
      startingBalance: (json['startingBalance'] as num).toInt(),
      perThreeStarLetter: (json['perThreeStarLetter'] as num).toInt(),
    );
  }
}

/// The rewarded ad and the outbound links in the Parent Zone (CLAUDE.md:
/// "Watch Ads to Earn Coin, Certificate, Project Details(link), Privacy
/// Policy(link)").
///
/// [rewardedAdUnitId] is the real AdMob "Coin Earn Ad" unit — the app id
/// itself lives in `AndroidManifest.xml`'s `APPLICATION_ID` meta-data
/// (google_mobile_ads reads that on its own; only the ad unit id is needed
/// at runtime, in `AdService`). The two URLs are placeholders until real
/// ones are supplied; see HANDOFF.md.
class ParentZoneConfig {
  final int adCoinsPerWatch;
  final String rewardedAdUnitId;
  final String projectDetailsUrl;
  final String privacyPolicyUrl;

  /// Where the Share row points a child's grown-up — a Play Store listing
  /// URL, live or not yet, rather than raw app-store boilerplate typed into
  /// the share text itself.
  final String appShareUrl;

  const ParentZoneConfig({
    required this.adCoinsPerWatch,
    required this.rewardedAdUnitId,
    required this.projectDetailsUrl,
    required this.privacyPolicyUrl,
    required this.appShareUrl,
  });

  factory ParentZoneConfig.fromJson(Map<String, dynamic> json) {
    return ParentZoneConfig(
      adCoinsPerWatch: (json['adCoinsPerWatch'] as num).toInt(),
      rewardedAdUnitId: json['rewardedAdUnitId'] as String,
      projectDetailsUrl: json['projectDetailsUrl'] as String,
      privacyPolicyUrl: json['privacyPolicyUrl'] as String,
      appShareUrl: json['appShareUrl'] as String,
    );
  }
}

/// Marks the progress certificate is built from, out of 100
/// (`lib/features/parent/certificate_score.dart`). Each is a bonus paid once,
/// in full, when its condition is met — not proportional — matching the
/// achievement marks coins are already paid on.
class CertificateConfig {
  /// Every character of the 247 has earned at least one star.
  final int allLettersStarredMarks;

  /// All uyir (12+1) taken to three stars.
  final int uyirCategoryMarks;

  /// All 18 mei taken to three stars.
  final int meiCategoryMarks;

  /// All 216 uyirmei taken to three stars.
  final int uyirmeiCategoryMarks;

  /// Every Word Builder word cleared without a wrong drop.
  final int gameCategoryMarks;

  const CertificateConfig({
    required this.allLettersStarredMarks,
    required this.uyirCategoryMarks,
    required this.meiCategoryMarks,
    required this.uyirmeiCategoryMarks,
    required this.gameCategoryMarks,
  });

  factory CertificateConfig.fromJson(Map<String, dynamic> json) {
    return CertificateConfig(
      allLettersStarredMarks: (json['allLettersStarredMarks'] as num).toInt(),
      uyirCategoryMarks: (json['uyirCategoryMarks'] as num).toInt(),
      meiCategoryMarks: (json['meiCategoryMarks'] as num).toInt(),
      uyirmeiCategoryMarks: (json['uyirmeiCategoryMarks'] as num).toInt(),
      gameCategoryMarks: (json['gameCategoryMarks'] as num).toInt(),
    );
  }
}

class AppConfig {
  final CanvasConfig canvas;
  final FeatureFlags featureFlags;
  final ProgressionConfig progression;
  final CoinsConfig coins;
  final ParentZoneConfig parentZone;
  final CertificateConfig certificate;

  const AppConfig({
    required this.canvas,
    required this.featureFlags,
    required this.progression,
    required this.coins,
    required this.parentZone,
    required this.certificate,
  });

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    return AppConfig(
      canvas: CanvasConfig.fromJson(json['canvas'] as Map<String, dynamic>),
      featureFlags: FeatureFlags.fromJson(json['featureFlags'] as Map<String, dynamic>),
      progression: ProgressionConfig.fromJson(json['progression'] as Map<String, dynamic>),
      coins: CoinsConfig.fromJson(json['coins'] as Map<String, dynamic>),
      parentZone: ParentZoneConfig.fromJson(json['parentZone'] as Map<String, dynamic>),
      certificate: CertificateConfig.fromJson(json['certificate'] as Map<String, dynamic>),
    );
  }
}
