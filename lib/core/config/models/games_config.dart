/// Everything Word Builder measures itself by (CLAUDE.md section 8).
class WordBuilderConfig {
  /// Extra tiles offered beside the ones the word needs.
  final int distractorCount;

  /// Earned for a round finished with no wrong drop at all.
  final int coinsPerCleanWord;

  /// How many words one coin opens.
  final int heartsPerCoin;

  /// What a child has before spending anything, so the games are open on day
  /// one without a purchase.
  final int startingHearts;

  /// How long the light takes to run round a box after a tile lands.
  final int snakeDurationMs;

  /// The same, when the tile does not belong there.
  ///
  /// Deliberately slower. A four-year-old needs longer to notice something
  /// went wrong than to enjoy something going right, and a correction that
  /// flicks past before they have looked up teaches nothing. It is the only
  /// place in the app where being wrong takes more of a child's time than
  /// being right, and that is the reason.
  final int snakeWrongDurationMs;

  /// How long the green verdict is held afterwards.
  final int verdictHoldMs;

  /// How long the red one is held — longer, for the same reason.
  final int verdictWrongHoldMs;

  /// The opening demonstration: how long the ghost tile takes to travel to its
  /// box, and how long it rests there before fading.
  final int tutorialTravelMs;
  final int tutorialHoldMs;

  /// How solid the demonstration tile is. Faint on purpose — it has to read as
  /// something being shown rather than something the child did.
  final double tutorialOpacity;

  /// A beat between the last box turning green and the burst going off, so the
  /// finished word is seen whole before sparkles cover it. Without it the
  /// celebration lands on top of the thing being celebrated.
  final int completionPauseMs;

  final double slotWidth;
  final double slotHeight;
  final double slotBorderWidth;
  final double slotCornerRadius;
  final double slotGap;

  /// How faint the target character sits inside an empty box.
  final double shadowOpacity;

  /// The cross over a wrong drop, as a multiple of the border width, and how
  /// solid it is. Kept deliberately light: the point of the mark is the letter
  /// underneath it, so a cross that hides the letter defeats itself.
  final double crossWidthFactor;
  final double crossOpacity;

  final double tileSize;
  final double tileGap;

  /// How many tiles a tray row holds. The tray is sized from this and the
  /// picture takes whatever is left, so a longer word squeezes the picture
  /// rather than the letters — the letters are what a child has to aim at.
  final int tilesPerRow;
  final double tileCornerRadius;

  /// How much a tile grows while it is being dragged, so it clears the finger.
  final double tileDragScale;

  /// The sign each uyir becomes when it joins a consonant — ஆ writes as ா.
  ///
  /// Used to show a child what they actually made when the wrong vowel goes
  /// down: ட் plus அ is ட, and seeing ட crossed out says more than a red
  /// border does.
  final Map<String, String> vowelSigns;

  /// Every tile a child can be handed: 12 uyir, 18 mei, ஃ. Nothing composed
  /// is ever offered, which is what forces a uyirmei to be built.
  ///
  /// Listed here rather than derived so the game does not have to load the
  /// letter catalogues to lay out a board; `word_builder_test.dart` checks it
  /// still matches `uyir.json` and `mei.json`.
  final List<String> tilePool;

  /// Letters a child is most likely to confuse, grouped. Distractors are drawn
  /// from the group an answer belongs to first: a random tile can be rejected
  /// without reading it, which teaches nothing.
  final List<List<String>> confusable;

  const WordBuilderConfig({
    required this.distractorCount,
    required this.coinsPerCleanWord,
    required this.heartsPerCoin,
    required this.startingHearts,
    required this.snakeDurationMs,
    required this.snakeWrongDurationMs,
    required this.verdictHoldMs,
    required this.verdictWrongHoldMs,
    required this.completionPauseMs,
    required this.tutorialTravelMs,
    required this.tutorialHoldMs,
    required this.tutorialOpacity,
    required this.slotWidth,
    required this.slotHeight,
    required this.slotBorderWidth,
    required this.slotCornerRadius,
    required this.slotGap,
    required this.shadowOpacity,
    required this.crossWidthFactor,
    required this.crossOpacity,
    required this.tileSize,
    required this.tileGap,
    required this.tilesPerRow,
    required this.tileCornerRadius,
    required this.tileDragScale,
    required this.vowelSigns,
    required this.tilePool,
    required this.confusable,
  });

  factory WordBuilderConfig.fromJson(Map<String, dynamic> json) {
    return WordBuilderConfig(
      distractorCount: (json['distractorCount'] as num).toInt(),
      coinsPerCleanWord: (json['coinsPerCleanWord'] as num).toInt(),
      heartsPerCoin: (json['heartsPerCoin'] as num).toInt(),
      startingHearts: (json['startingHearts'] as num).toInt(),
      snakeDurationMs: (json['snakeDurationMs'] as num).toInt(),
      snakeWrongDurationMs: (json['snakeWrongDurationMs'] as num).toInt(),
      verdictHoldMs: (json['verdictHoldMs'] as num).toInt(),
      verdictWrongHoldMs: (json['verdictWrongHoldMs'] as num).toInt(),
      completionPauseMs: (json['completionPauseMs'] as num).toInt(),
      tutorialTravelMs: (json['tutorialTravelMs'] as num).toInt(),
      tutorialHoldMs: (json['tutorialHoldMs'] as num).toInt(),
      tutorialOpacity: (json['tutorialOpacity'] as num).toDouble(),
      slotWidth: (json['slotWidth'] as num).toDouble(),
      slotHeight: (json['slotHeight'] as num).toDouble(),
      slotBorderWidth: (json['slotBorderWidth'] as num).toDouble(),
      slotCornerRadius: (json['slotCornerRadius'] as num).toDouble(),
      slotGap: (json['slotGap'] as num).toDouble(),
      shadowOpacity: (json['shadowOpacity'] as num).toDouble(),
      crossWidthFactor: (json['crossWidthFactor'] as num).toDouble(),
      crossOpacity: (json['crossOpacity'] as num).toDouble(),
      tileSize: (json['tileSize'] as num).toDouble(),
      tileGap: (json['tileGap'] as num).toDouble(),
      tilesPerRow: (json['tilesPerRow'] as num).toInt(),
      tileCornerRadius: (json['tileCornerRadius'] as num).toDouble(),
      tileDragScale: (json['tileDragScale'] as num).toDouble(),
      vowelSigns: (json['vowelSigns'] as Map<String, dynamic>).cast<String, String>(),
      tilePool: (json['tilePool'] as List<dynamic>).cast<String>(),
      confusable: [
        for (final group in (json['confusable'] as List<dynamic>))
          (group as List<dynamic>).cast<String>(),
      ],
    );
  }
}

class GamesConfig {
  final WordBuilderConfig wordBuilder;

  const GamesConfig({required this.wordBuilder});

  factory GamesConfig.fromJson(Map<String, dynamic> json) {
    return GamesConfig(
      wordBuilder:
          WordBuilderConfig.fromJson(json['wordBuilder'] as Map<String, dynamic>),
    );
  }
}
