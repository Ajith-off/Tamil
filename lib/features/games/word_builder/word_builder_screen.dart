import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/config_service.dart';
import '../../../core/config/models/games_config.dart';
import '../../../core/config/models/theme_config.dart';
import '../../../data/models/word_challenge.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../common/guide_highlight.dart';
import '../../common/celebration_burst.dart';
import '../../letter/letter_providers.dart';
import '../../../services/audio_service.dart';
import '../../../services/settings_store.dart';
import '../../../services/theme_selector.dart';
import '../game_providers.dart';
import 'finished_panel.dart';
import 'game_hud.dart';
import 'word_round.dart';
import 'word_slot_box.dart';
import 'word_tile.dart';

/// How far the dragged tile's feedback is shifted from the finger — see
/// [_Tile]'s `Draggable.feedback`. Shared with the hover/drop math in
/// [_WordBuilderScreenState] so the two can never drift apart: Flutter's
/// `DragTarget` always hit-tests at the raw finger position, never at a
/// visually-offset feedback widget, so a tile deliberately lifted off the
/// finger for visibility needs its *drop* detection corrected by the same
/// amount or the box that lights up stops matching the box the child is
/// actually aiming the tile at.
const _kFeedbackTranslation = Offset(-0.5, -0.8);

/// Build the word under the picture by dragging letters into its boxes.
///
/// The tiles are only ever the 31 base characters, so every consonant-vowel
/// box has to be built out of two of them — ம் then ஆ for மா. That is the
/// whole lesson, and it is why nothing composed is offered ready-made
/// (CLAUDE.md section 8).
class WordBuilderScreen extends ConsumerStatefulWidget {
  final WordChallenge word;

  const WordBuilderScreen({super.key, required this.word});

  @override
  ConsumerState<WordBuilderScreen> createState() => _WordBuilderScreenState();
}

class _WordBuilderScreenState extends ConsumerState<WordBuilderScreen>
    with TickerProviderStateMixin {
  WordRound? _round;

  /// Which box is mid-verdict, and what that verdict is.
  int? _judging;
  SlotVerdict _verdict = SlotVerdict.idle;

  /// Shown in the judged box instead of its natural state: the tile that just
  /// landed, or what a wrong drop built. [_crossed] says which.
  String? _override;
  bool _crossed = false;

  int? _hovered;
  bool _finished = false;
  bool _earnedCoin = false;

  /// The opening demonstration, and the keys it measures its path between.
  /// The "to" end reuses [_slotKeys]'s first entry — the box a drag lands in
  /// and the box the tutorial ghost travels to are the same widget.
  bool _showingTutorial = true;
  final _tutorialTileKey = GlobalKey();
  Rect? _tutorialFrom;
  Rect? _tutorialTo;

  /// One key per box, so a drag can be matched against each box's real
  /// on-screen position rather than relying on `DragTarget`'s own
  /// finger-position hit-testing — see [_kFeedbackTranslation]. Words are
  /// at most 4 characters (CLAUDE.md section 8), so 4 is always enough;
  /// keys past the real slot count simply have no widget attached.
  final _slotKeys = List.generate(4, (_) => GlobalKey());

  late final AnimationController _snake = AnimationController(vsync: this);
  late final AnimationController _burst = AnimationController(vsync: this);
  late final AnimationController _tutorial = AnimationController(vsync: this);
  List<SparkleParticle> _sparkles = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _playTutorial());
    WidgetsBinding.instance.addPostFrameCallback((_) => _speakWord());
  }

  /// The word's name, spoken once as the picture appears and once again on
  /// finishing — the same "spell it at the start and the end" pairing the
  /// letter screen does, so hearing the word is part of the round rather
  /// than something that only happens if a child notices to ask for it.
  void _speakWord() {
    if (!mounted) return;
    final config = ref.read(configServiceProvider).requireValue.app;
    ref
        .read(audioServiceProvider)
        .speak(
          widget.word.tamil,
          enabled:
              config.featureFlags.audioEnabled &&
              ref.read(settingsStoreProvider).soundEnabled,
        );
  }

  @override
  void dispose() {
    _snake.dispose();
    _burst.dispose();
    _tutorial.dispose();
    super.dispose();
  }

  WordRound _roundFor(WordBuilderConfig config) =>
      _round ??= WordRound.forWord(widget.word, config);

  /// Shows the drag once, with a faint tile, before the child touches
  /// anything. Measured off the real widgets rather than guessed at, so it
  /// always points at the tile and box actually on screen.
  Future<void> _playTutorial() async {
    final config = ref
        .read(configServiceProvider)
        .valueOrNull
        ?.games
        .wordBuilder;
    if (config == null || !mounted) return;

    Rect? rectOf(GlobalKey key) {
      final box = key.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return null;
      return box.localToGlobal(Offset.zero) & box.size;
    }

    final from = rectOf(_tutorialTileKey);
    final to = rectOf(_slotKeys[0]);
    if (from == null || to == null) {
      setState(() => _showingTutorial = false);
      return;
    }

    setState(() {
      _tutorialFrom = from;
      _tutorialTo = to;
    });
    _tutorial.duration = Duration(milliseconds: config.tutorialTravelMs);
    await _tutorial.forward(from: 0);
    if (!mounted) return;
    await Future<void>.delayed(Duration(milliseconds: config.tutorialHoldMs));
    if (!mounted) return;
    setState(() => _showingTutorial = false);
  }

  void _skipTutorial() {
    if (!_showingTutorial) return;
    _tutorial.stop();
    setState(() => _showingTutorial = false);
  }

  /// Which box, if any, contains [globalPosition]. Bounded to the round's
  /// real slot count — keys past that belong to no widget this word uses
  /// and are skipped.
  int? _slotAt(WordRound round, Offset globalPosition) {
    for (var i = 0; i < round.word.slots.length; i++) {
      final box = _slotKeys[i].currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) continue;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      if (rect.contains(globalPosition)) return i;
    }
    return null;
  }

  /// Where the dragged tile visually sits, given the finger's real
  /// position — the same shift [_kFeedbackTranslation] draws the feedback
  /// with. `FractionalTranslation` moves a widget by a fraction of its own
  /// size, so the tile's rendered centre is offset from the finger by
  /// `(translation + 0.5) * size` on each axis; the x term cancels out to
  /// exactly 0 (a -0.5 shift centres the tile on the finger horizontally),
  /// leaving only the vertical lift to correct for.
  Offset _visualTileCenter(Offset pointerGlobal, WordBuilderConfig config) {
    final size = config.tileSize * config.tileDragScale;
    final dyFraction = _kFeedbackTranslation.dy + 0.5;
    return pointerGlobal + Offset(0, dyFraction * size);
  }

  void _onTileDragUpdate(Offset globalPosition, WordBuilderConfig config) {
    final round = _roundFor(config);
    final at = _slotAt(round, _visualTileCenter(globalPosition, config));
    final next = (at != null && !round.isSlotFull(at)) ? at : null;
    if (next != _hovered) setState(() => _hovered = next);
  }

  void _onTileDragEnd(String tile, WordBuilderConfig config) {
    final slot = _hovered;
    if (slot != null) _drop(slot, tile, config);
  }

  Future<void> _drop(int slot, String tile, WordBuilderConfig config) async {
    final round = _roundFor(config);
    if (_judging != null || _finished || round.isSlotFull(slot)) return;
    _skipTutorial();

    // Worked out before the drop, while the box still holds what it held.
    final preview = round.previewOf(slot, tile, config.vowelSigns);
    final accepted = round.drop(slot, tile);
    setState(() {
      _judging = slot;
      _verdict = SlotVerdict.checking;
      // The dropped letter goes in straight away and stays there while the
      // light runs the border, so a child watching their own finger sees what
      // they let go of rather than a box that has not changed yet.
      _override = tile;
      _crossed = false;
      _hovered = null;
    });

    // A wrong drop runs slower and rests longer. The audience is three to
    // eight: a correction that flicks past before they have looked up is a
    // correction they never saw.
    _snake.duration = Duration(
      milliseconds: accepted
          ? config.snakeDurationMs
          : config.snakeWrongDurationMs,
    );
    await _snake.forward(from: 0);
    if (!mounted) return;

    // The border has finished, so the letters join: ட் was already there, உ
    // went down, and டு is what the two of them make. Clearing the override
    // lets the box show its own state, which is the composed character. A
    // wrong drop shows what it built instead, crossed out.
    setState(() {
      _verdict = accepted ? SlotVerdict.correct : SlotVerdict.wrong;
      _override = accepted ? null : preview;
      _crossed = !accepted;
    });
    await Future<void>.delayed(
      Duration(
        milliseconds: accepted
            ? config.verdictHoldMs
            : config.verdictWrongHoldMs,
      ),
    );
    if (!mounted) return;

    // Back to exactly what stood there before. Nothing a wrong drop does is
    // ever kept.
    setState(() {
      _judging = null;
      _verdict = SlotVerdict.idle;
      _override = null;
      _crossed = false;
    });

    if (!round.isComplete) return;
    // A beat with the word standing finished and nothing happening to it,
    // before the sparkles arrive.
    await Future<void>.delayed(
      Duration(milliseconds: config.completionPauseMs),
    );
    if (!mounted) return;
    _finish(round);
  }

  void _finish(WordRound round) {
    final celebration = ref
        .read(configServiceProvider)
        .requireValue
        .trace
        .celebration;
    // Only a clean round pays, and only the first clean clear of a word pays a
    // new coin — the balance counts cleared words, so a replay cannot mint one.
    final earned =
        round.clean &&
        ref.read(gameStoreProvider.notifier).finishedCleanly(widget.word.id);
    setState(() {
      _finished = true;
      _earnedCoin = earned;
      _sparkles = makeSparkles(celebration, seed: widget.word.id.hashCode);
    });
    _burst.duration = Duration(milliseconds: celebration.durationMs);
    _burst.forward(from: 0);
    final config = ref.read(configServiceProvider).requireValue.app;
    ref
        .read(audioServiceProvider)
        .playCelebration(
          enabled:
              config.featureFlags.audioEnabled &&
              ref.read(settingsStoreProvider).soundEnabled,
        );
    _speakWord();
  }

  void _restart() {
    // Playing again is opening the word again, so it costs a heart like any
    // other opening. Refused rather than charged for, as everywhere else.
    if (!ref.read(gameStoreProvider.notifier).openWord()) return;
    setState(() {
      _round = null;
      _finished = false;
      _earnedCoin = false;
      _judging = null;
      _verdict = SlotVerdict.idle;
      _override = null;
      _crossed = false;
    });
    _burst.reset();
  }

  void _buyHearts() {
    ref.read(coinPurseProvider.notifier).spend(1);
    ref.read(gameStoreProvider.notifier).addHeartsForCoin();
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(configServiceProvider);
    if (configAsync.hasError) {
      return Scaffold(
        body: Center(child: Text('Failed to load: ${configAsync.error}')),
      );
    }
    if (!configAsync.hasValue) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final config = configAsync.requireValue;
    final wb = config.games.wordBuilder;
    final colors = themeColorsOf(config, ref.watch(settingsStoreProvider));
    final l10n = AppLocalizations.of(context);
    final round = _roundFor(wb);
    final game = ref.watch(gameStoreProvider);
    final coins = ref.watch(coinBalanceProvider);

    // The tile the demonstration picks up: the one the first box wants.
    final firstWanted = round.expects(0);
    final tutorialIndex = firstWanted == null
        ? -1
        : round.tiles.indexOf(firstWanted);

    return Scaffold(
      backgroundColor: colors.background,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 0.9,
            colors: [colors.backgroundGlow, colors.background],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 4, right: 20),
                    child: Row(
                      children: [
                        BackCircleButton(
                          color: colors.textSecondary,
                          background: colors.canvasBackground,
                          border: colors.starEmpty,
                        ),
                        const Spacer(),
                        GameHud(
                          hearts: game.hearts ?? 0,
                          heartCapacity: wb.heartsPerCoin,
                          coins: coins,
                          achieved: game.cleanWords.contains(widget.word.id),
                          onBuyHearts: coins > 0 ? _buyHearts : null,
                          colors: colors,
                        ),
                      ],
                    ),
                  ),
                  // The picture and the word it names on one side, the letters
                  // to drag on the other. They belong together — the word is
                  // what the picture *is* — and it gives them the whole left
                  // half rather than squeezing both into a strip.
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              // The picture takes whatever is left once the
                              // word has its room. Tiles and boxes are what a
                              // child aims a finger at, so they keep their
                              // size and the picture gives way — a goat that
                              // is a little smaller is still a goat.
                              Expanded(child: _Picture(word: widget.word)),
                              const SizedBox(height: 8),
                              _SlotRow(
                                round: round,
                                judging: _judging,
                                verdict: _verdict,
                                overrideChar: _override,
                                crossed: _crossed,
                                hovered: _hovered,
                                snake: _snake,
                                config: wb,
                                colors: colors,
                                slotKeys: _slotKeys,
                              ),
                              const SizedBox(height: 10),
                              // Sized to what is there rather than reserving
                              // the panel's height throughout, which cost the
                              // picture room it needed.
                              if (_finished)
                                FinishedPanel(
                                  earnedCoin: _earnedCoin,
                                  canRestart: ref
                                      .read(gameStoreProvider.notifier)
                                      .canOpen,
                                  onRestart: _restart,
                                  onBuyHearts: coins > 0 ? _buyHearts : null,
                                  onDone: () =>
                                      Navigator.of(context).maybePop(),
                                  colors: colors,
                                )
                              else
                                Text(
                                  _showingTutorial
                                      ? l10n.tutorialDrag
                                      : l10n.wordBuilderHint,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: colors.textSecondary,
                                  ),
                                ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                        SizedBox(
                          width:
                              wb.tilesPerRow * wb.tileSize +
                              (wb.tilesPerRow - 1) * wb.tileGap +
                              wb.tileGap * 2,
                          child: _TileTray(
                            round: round,
                            config: wb,
                            colors: colors,
                            enabled: _judging == null && !_finished,
                            highlightKey: _tutorialTileKey,
                            highlightIndex: tutorialIndex,
                            onDragUpdate: (pos) => _onTileDragUpdate(pos, wb),
                            onDragEnd: (tile) => _onTileDragEnd(tile, wb),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_finished)
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _burst,
                      builder: (context, _) => CustomPaint(
                        painter: _BurstPainter(
                          progress: _burst.value,
                          sparkles: _sparkles,
                          colors: colors,
                          stars: _earnedCoin ? 1 : 0,
                          starRadiusFactor:
                              config.trace.celebration.starRadiusFactor,
                        ),
                      ),
                    ),
                  ),
                ),
              if (_showingTutorial &&
                  _tutorialFrom != null &&
                  _tutorialTo != null)
                Positioned.fill(
                  child: IgnorePointer(
                    child: _TutorialGhost(
                      char: round.tiles.isEmpty
                          ? ''
                          : round.tiles[tutorialIndex.clamp(
                              0,
                              round.tiles.length - 1,
                            )],
                      from: _tutorialFrom!,
                      to: _tutorialTo!,
                      animation: _tutorial,
                      config: wb,
                      colors: colors,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Picture extends StatelessWidget {
  final WordChallenge word;

  const _Picture({required this.word});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      // Semantics carries the word, since the picture is the only prompt and a
      // screen reader has nothing else to say about it.
      child: Semantics(
        label: word.tamil,
        image: true,
        child: Image.asset(word.image, fit: BoxFit.contain),
      ),
    );
  }
}

class _SlotRow extends StatelessWidget {
  final WordRound round;
  final int? judging;
  final SlotVerdict verdict;
  final String? overrideChar;
  final bool crossed;
  final int? hovered;
  final Animation<double> snake;
  final WordBuilderConfig config;
  final ThemeColors colors;

  /// One per box (see [_WordBuilderScreenState._slotKeys]) — [hovered]
  /// itself is worked out from these against the drag's real position, not
  /// from anything this row does; it just reads the result back.
  final List<GlobalKey> slotKeys;

  const _SlotRow({
    required this.round,
    required this.judging,
    required this.verdict,
    required this.overrideChar,
    required this.crossed,
    required this.hovered,
    required this.snake,
    required this.config,
    required this.colors,
    required this.slotKeys,
  });

  @override
  Widget build(BuildContext context) {
    // Centred while the word fits, sliding when it does not. A word must never
    // wrap onto a second line: the boxes are read left to right as one word,
    // and a word broken across two rows is a different thing to look at.
    return AnimatedBuilder(
      animation: snake,
      builder: (context, _) => LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < round.word.slots.length; i++) ...[
                  if (i > 0) SizedBox(width: config.slotGap),
                  WordSlotBox(
                    key: slotKeys[i],
                    shadowChar: round.word.slots[i].char,
                    filledChar: round.shownIn(i),
                    overrideChar: judging == i ? overrideChar : null,
                    crossed: judging == i && crossed,
                    verdict: judging == i ? verdict : SlotVerdict.idle,
                    snakeProgress: snake.value,
                    isTargeted: hovered == i,
                    config: config,
                    colors: colors,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TileTray extends StatelessWidget {
  final WordRound round;
  final WordBuilderConfig config;
  final ThemeColors colors;
  final bool enabled;
  final GlobalKey highlightKey;
  final int highlightIndex;
  final void Function(Offset) onDragUpdate;
  final void Function(String) onDragEnd;

  const _TileTray({
    required this.round,
    required this.config,
    required this.colors,
    required this.enabled,
    required this.highlightKey,
    required this.highlightIndex,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: config.tileGap,
          runSpacing: config.tileGap,
          children: [
            // A tile is never used up: the same letter can be needed twice
            // (குகை wants க் twice), and taking one away would leave a box
            // that cannot be filled.
            for (var i = 0; i < round.tiles.length; i++)
              _Tile(
                key: i == highlightIndex ? highlightKey : null,
                char: round.tiles[i],
                config: config,
                colors: colors,
                enabled: enabled,
                onDragUpdate: onDragUpdate,
                onDragEnd: onDragEnd,
              ),
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final String char;
  final WordBuilderConfig config;
  final ThemeColors colors;
  final bool enabled;
  final void Function(Offset) onDragUpdate;
  final void Function(String) onDragEnd;

  const _Tile({
    super.key,
    required this.char,
    required this.config,
    required this.colors,
    required this.enabled,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    final face = TileFace(char: char, config: config, colors: colors);
    if (!enabled) return Opacity(opacity: 0.5, child: face);
    return Draggable<String>(
      data: char,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      // Grown and lifted off the pointer so the child's own hand is not
      // covering the letter they are trying to place. Flutter's own drag
      // targets hit-test the raw finger position and know nothing about
      // this shift, so hover/drop is worked out separately in the parent
      // using the same offset — see [_kFeedbackTranslation].
      feedback: FractionalTranslation(
        translation: _kFeedbackTranslation,
        child: TileFace(
          char: char,
          config: config,
          colors: colors,
          scale: config.tileDragScale,
          raised: true,
        ),
      ),
      onDragUpdate: (details) => onDragUpdate(details.globalPosition),
      onDragEnd: (_) => onDragEnd(char),
      childWhenDragging: Opacity(opacity: 0.35, child: face),
      child: face,
    );
  }
}

/// The opening demonstration: a faint tile that carries itself from the tray
/// into the box a child would put it in.
///
/// Faint on purpose. It has to read as something being shown rather than
/// something that happened, or a child will think the first letter is done.
class _TutorialGhost extends StatelessWidget {
  final String char;
  final Rect from;
  final Rect to;
  final Animation<double> animation;
  final WordBuilderConfig config;
  final ThemeColors colors;

  const _TutorialGhost({
    required this.char,
    required this.from,
    required this.to,
    required this.animation,
    required this.config,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(animation.value);
        final centre = Rect.lerp(from, to, t)!.center;
        return Stack(
          children: [
            Positioned(
              left: centre.dx - config.tileSize / 2,
              top: centre.dy - config.tileSize / 2,
              child: Opacity(
                opacity: config.tutorialOpacity,
                child: TileFace(
                  char: char,
                  config: config,
                  colors: colors,
                  raised: true,
                ),
              ),
            ),
            // A hand-sized dot at the same place, so the gesture reads as a
            // finger dragging rather than a letter drifting on its own.
            Positioned(
              left: centre.dx - 12,
              top: centre.dy + config.tileSize / 2 - 6,
              child: Opacity(
                opacity: config.tutorialOpacity,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: colors.textSecondary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BurstPainter extends CustomPainter {
  final double progress;
  final List<SparkleParticle> sparkles;
  final ThemeColors colors;
  final int stars;
  final double starRadiusFactor;

  const _BurstPainter({
    required this.progress,
    required this.sparkles,
    required this.colors,
    required this.stars,
    required this.starRadiusFactor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    paintCelebrationBurst(
      canvas,
      Offset(size.width / 2, size.height / 2),
      size.shortestSide,
      progress,
      sparkles,
      colors,
      stars: stars,
      starRadiusFactor: starRadiusFactor,
    );
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.progress != progress;
}
