import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/config_service.dart';
import '../../core/config/models/theme_config.dart';
import '../../core/config/models/trace_mode.dart';
import '../../data/models/letter.dart';
import '../../core/config/models/scoring_config.dart';
import '../../data/models/score.dart';
import '../../data/models/stroke.dart';
import '../../l10n/gen/app_localizations.dart';
import '../common/guide_highlight.dart';
import '../common/celebration_burst.dart';
import '../../services/audio_service.dart';
import '../../services/settings_store.dart';
import '../../services/theme_selector.dart';
import 'canvas/letter_canvas.dart';
import 'letter_providers.dart';
import 'scoring/mark_scheme.dart';
import 'scoring/scoring_engine.dart';
import 'trace/letter_paths.dart';
import 'trace/trace_controller.dart';
import '../letters/reward_icons.dart';

/// What the screen is currently doing.
enum _Phase { tutorial, preview, tracing, finished }

/// "க் + ஆ = கா" — the consonant and vowel a uyirmei letter composes from.
///
/// A uyirmei letter's `order` runs across the whole 216 rather than resetting
/// per group (13 for ங's first letter, not 1), so the vowel column is read
/// off it with `% 12` rather than off any stored index. [uyirLetters] is the
/// uyir catalogue's own list, sorted here rather than assumed pre-sorted —
/// the 13th, aaytham, is filtered out since uyirmei has no ஃ column.
String? _uyirmeiComposition(Letter letter, List<Letter> uyirLetters) {
  if (letter.category != LetterCategory.uyirmei) return null;
  final vowels = uyirLetters.where((l) => l.category == LetterCategory.uyir).toList()
    ..sort((a, b) => a.order.compareTo(b.order));
  final index = (letter.order - 1) % 12;
  if (index >= vowels.length) return null;
  final consonant = '${letter.groupTamil}்';
  return '$consonant + ${vowels[index].tamil} = ${letter.tamil}';
}

/// The landscape tracing screen: watch the letter being written, then drag
/// along it yourself. See CLAUDE.md section 4 — this is the core learning
/// loop the whole app is built around.
class LetterScreen extends ConsumerWidget {
  /// Which list this letter was opened from — the only place its metadata
  /// (transliteration, example word) lives.
  final LetterCatalogue catalogue;
  final String letterId;

  const LetterScreen({
    super.key,
    required this.catalogue,
    required this.letterId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(configServiceProvider);
    final lettersAsync = ref.watch(lettersProvider(catalogue));
    final strokeDataAsync = ref.watch(letterStrokeDataProvider(letterId));

    final error =
        configAsync.error ?? lettersAsync.error ?? strokeDataAsync.error;
    if (error != null) {
      return Scaffold(body: Center(child: Text('Failed to load: $error')));
    }
    if (!configAsync.hasValue ||
        !lettersAsync.hasValue ||
        !strokeDataAsync.hasValue) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final config = configAsync.requireValue;
    final settings = ref.watch(settingsStoreProvider);
    final letter = lettersAsync.requireValue.firstWhere((l) => l.id == letterId);

    // The consonant + vowel a uyirmei letter is built from, e.g. "க் + ஆ =
    // கா" — the same composition CLAUDE.md section 8's Word Builder already
    // teaches, shown here too rather than only in the game.
    String? composition;
    if (catalogue == LetterCatalogue.uyirmei) {
      final uyirAsync = ref.watch(lettersProvider(LetterCatalogue.uyir));
      if (uyirAsync.hasValue) {
        composition = _uyirmeiComposition(letter, uyirAsync.requireValue);
      }
    }

    return _LetterScreenBody(
      key: ValueKey(letterId),
      config: config,
      letter: letter,
      strokeData: strokeDataAsync.requireValue,
      // Read from the store rather than kept on the screen, so coming back to
      // a letter shows everything it has ever earned. The screen used to
      // start from an empty tally, which made a second visit look like the
      // first one had never happened.
      progress:
          ref.watch(progressStoreProvider)[letterId] ??
          LetterProgress(letterId: letterId),
      onAttempt: (attempt) =>
          ref.read(progressStoreProvider.notifier).record(letterId, attempt),
      audio: ref.read(audioServiceProvider),
      soundOn: config.app.featureFlags.audioEnabled && settings.soundEnabled,
      // Confirmed working on-device for uyir (see HANDOFF.md) and now on for
      // every catalogue — mei, uyirmei and grantha all speak the same way.
      speechEnabled: true,
      composition: composition,
      colors: themeColorsOf(config, settings),
    );
  }
}

class _LetterScreenBody extends StatefulWidget {
  final ConfigService config;
  final Letter letter;
  final LetterStrokeData strokeData;

  /// Everything this letter has earned so far, from the store — the single
  /// source of truth, so the tally never resets on re-entry and a worse
  /// retry can never appear to take marks away.
  final LetterProgress progress;
  final ValueChanged<AttemptResult> onAttempt;

  final AudioService audio;
  final bool soundOn;

  /// Whether this letter should be spoken at all.
  final bool speechEnabled;

  /// "க் + ஆ = கா" — null for every catalogue but uyirmei.
  final String? composition;

  /// The light or dark palette, following the home screen's toggle
  /// app-wide (`themeColorsOf`) — resolved once in [LetterScreen.build],
  /// which has the `ref` this plain `StatefulWidget` does not.
  final ThemeColors colors;

  const _LetterScreenBody({
    super.key,
    required this.config,
    required this.letter,
    required this.strokeData,
    required this.progress,
    required this.onAttempt,
    required this.audio,
    required this.soundOn,
    required this.speechEnabled,
    this.composition,
    required this.colors,
  });

  @override
  State<_LetterScreenBody> createState() => _LetterScreenBodyState();
}

class _LetterScreenBodyState extends State<_LetterScreenBody>
    with TickerProviderStateMixin {
  late final LetterPaths _letterPaths;
  late final TraceController _trace;
  late final ScoringEngine _scoringEngine;
  late final MarkScheme _markScheme;
  late final AnimationController _tutorial;
  late final AnimationController _celebration;
  Timer? _previewTimer;

  TraceMode _mode = TraceMode.easy;
  _Phase _phase = _Phase.tutorial;
  AttemptResult? _lastAttempt;
  List<SparkleParticle> _sparkles = const [];

  /// Successful attempts at the current mode. Two in a row moves the child
  /// up; it resets whenever the mode changes so each level is earned afresh.
  int _successesInMode = 0;

  @override
  void initState() {
    super.initState();
    _letterPaths = LetterPaths.fromStrokes(
      widget.strokeData.strokes,
      dotLength: widget.config.app.canvas.dotStrokeLengthFactor,
    );
    _trace = TraceController(
      letterPaths: _letterPaths,
      canvasConfig: widget.config.app.canvas,
      freeDraw: widget.config.trace.definitionFor(_mode).freeDraw,
    )..addListener(_onTraceChanged);
    _scoringEngine = ScoringEngine(widget.config.scoring);
    _markScheme = MarkScheme(widget.config.scoring);

    _tutorial = AnimationController(vsync: this, duration: _tutorialDuration)
      ..addListener(() => setState(() {}))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) _beginTracing();
      });
    _celebration =
        AnimationController(
            vsync: this,
            duration: Duration(
              milliseconds: widget.config.trace.celebration.durationMs,
            ),
          )
          ..addListener(() => setState(() {}))
          // Move up only once the child has seen their result celebrated.
          ..addStatusListener((s) {
            if (s == AnimationStatus.completed) _advanceIfEarned();
          });

    _startForCurrentMode();
    // Spoken once the screen has actually appeared rather than mid-build.
    if (widget.speechEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _speakLetter());
    }
  }

  void _speakLetter() {
    if (!widget.speechEnabled) return;
    widget.audio.speak(widget.letter.tamil, enabled: widget.soundOn);
  }

  Duration get _tutorialDuration {
    final t = widget.config.trace.tutorial;
    final strokes = math.max(_letterPaths.strokeCount, 1);
    return Duration(
      milliseconds:
          strokes * t.strokeDurationMs +
          (strokes - 1) * t.pauseBetweenStrokesMs +
          t.holdAtEndMs,
    );
  }

  @override
  void dispose() {
    _trace.removeListener(_onTraceChanged);
    _trace.dispose();
    _tutorial.dispose();
    _celebration.dispose();
    _previewTimer?.cancel();
    super.dispose();
  }

  void _onTraceChanged() {
    if (_trace.completed && _phase == _Phase.tracing) {
      _finish();
    } else {
      setState(() {});
    }
  }

  void _startForCurrentMode() {
    _trace.freeDraw = widget.config.trace.definitionFor(_mode).freeDraw;
    _trace.reset();
    _lastAttempt = null;
    _celebration.reset();
    _previewTimer?.cancel();
    final def = widget.config.trace.definitionFor(_mode);
    if (def.showTutorial) {
      _phase = _Phase.tutorial;
      _tutorial.forward(from: 0);
    } else if (def.previewDurationMs > 0) {
      _phase = _Phase.preview;
      _tutorial.reset();
      _previewTimer = Timer(Duration(milliseconds: def.previewDurationMs), _beginTracing);
    } else {
      _phase = _Phase.tracing;
      _tutorial.reset();
    }
  }

  void _beginTracing() {
    if (!mounted) return;
    setState(() {
      _phase = _Phase.tracing;
      _trace.reset();
    });
  }

  void _finish() {
    final analysis = _scoringEngine.analyse(
      userStrokes: _trace.userStrokes,
      reference: widget.strokeData,
    );
    final attempt = _markScheme.evaluate(
      mode: _mode,
      // Free-draw has no finish line, so submitting is what counts as done.
      completed: _trace.freeDraw ? _trace.hasDrawnAnything : _trace.completed,
      elapsed: _trace.elapsed,
      pathLength: _trace.referenceLength,
      analysis: analysis,
    );
    setState(() {
      _phase = _Phase.finished;
      _lastAttempt = attempt;
      if (attempt.marks > 0) _successesInMode++;
      _sparkles = _makeSparkles();
    });
    // Publish upward so the letter list can unlock what comes next.
    widget.onAttempt(attempt);
    _celebration.forward(from: 0);
    widget.audio.playCelebration(enabled: widget.soundOn);
    // "Spell the char in starting and ending" — the other half of the pair
    // begun in initState.
    _speakLetter();
  }

  List<SparkleParticle> _makeSparkles() {
    // Seeded by the letter so a given letter's burst is reproducible.
    return makeSparkles(
      widget.config.trace.celebration,
      seed: widget.letter.id.hashCode,
    );
  }

  void _selectMode(TraceMode mode) {
    if (mode == _mode) return;
    setState(() {
      _mode = mode;
      _successesInMode = 0;
    });
    _startForCurrentMode();
  }

  /// Two clean attempts at a mode and the child graduates to the next one.
  void _advanceIfEarned() {
    if (!mounted) return;
    if (_successesInMode < widget.config.trace.advanceAfterSuccesses) return;
    final next = _mode.next;
    if (next == null) return;
    _selectMode(next);
  }

  void _replayTutorial() {
    setState(() {
      _phase = _Phase.tutorial;
      _trace.reset();
      _lastAttempt = null;
    });
    _celebration.reset();
    _tutorial.forward(from: 0);
  }

  /// Freehand mode has no finish line, so the child decides when they are
  /// done and the shape is judged then.
  void _submit() {
    if (!_trace.hasDrawnAnything) return;
    _finish();
  }

  void _clear() {
    setState(() {
      _phase = _Phase.tracing;
      _lastAttempt = null;
    });
    _celebration.reset();
    _trace.reset();
  }

  /// Maps the tutorial animation clock onto a position along the strokes,
  /// so the demo draws each stroke in turn with a pause between them.
  TracePosition _tutorialPosition() {
    final t = widget.config.trace.tutorial;
    final strokes = _letterPaths.strokeCount;
    if (strokes == 0) return TracePosition.zero;
    var elapsed = _tutorial.value * _tutorialDuration.inMilliseconds;
    for (var i = 0; i < strokes; i++) {
      if (elapsed <= t.strokeDurationMs) {
        final fraction = (elapsed / t.strokeDurationMs).clamp(0.0, 1.0);
        return TracePosition(i, _letterPaths.lengthOf(i) * fraction);
      }
      elapsed -= t.strokeDurationMs;
      if (elapsed <= t.pauseBetweenStrokesMs) {
        return TracePosition(i, _letterPaths.lengthOf(i));
      }
      elapsed -= t.pauseBetweenStrokesMs;
    }
    final last = strokes - 1;
    return TracePosition(last, _letterPaths.lengthOf(last));
  }

  bool get _tutorialFinishedAllStrokes {
    final pos = _tutorialPosition();
    return pos.strokeIndex >= _letterPaths.strokeCount - 1 &&
        pos.distance >=
            _letterPaths.lengthOf(_letterPaths.strokeCount - 1) - 1e-6;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = widget.colors;
    final def = widget.config.trace.definitionFor(_mode);
    final showingTutorial = _phase == _Phase.tutorial;
    final showingPreview = _phase == _Phase.preview;
    final position = showingTutorial ? _tutorialPosition() : _trace.position;

    return Scaffold(
      backgroundColor: colors.background,
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 0.9,
            colors: [colors.backgroundGlow, colors.background],
          ),
        ),
        child: SafeArea(
          child: Row(
            children: [
              _LetterInfoPanel(
                letter: widget.letter,
                colors: colors,
                l10n: l10n,
                onReplaySound: widget.speechEnabled ? _speakLetter : null,
                composition: widget.composition,
              ),
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: LetterCanvas(
                        letterPaths: _letterPaths,
                        // The brief flash before Challenge's freehand attempt
                        // reuses the same tube + gold trace-fill every guided
                        // mode shows once finished — a still glance at the
                        // whole letter filled in, not a demo of how to draw
                        // it, so it borrows the "completed" look rather than
                        // adding a new visual.
                        showTube: def.showTube || showingPreview,
                        showDots: def.showDots && !showingTutorial,
                        // Suppressed during the demo exactly as the dots are:
                        // the position being drawn then is the demo's pen, so
                        // a waypoint would trail that instead of marking
                        // anything for the child to do.
                        showWaypoints: def.showWaypoints && !showingTutorial,
                        touchedCurrentStroke: _trace.touchedCurrentStroke,
                        showFrame: def.showFrame,
                        position: position,
                        targetPoint:
                            showingTutorial || showingPreview || _phase == _Phase.finished
                            ? null
                            : (def.showStartPoint && !_trace.hasDrawnAnything
                                  ? _letterPaths.pointAt(0, 0)
                                  : _trace.targetPoint),
                        completed:
                            _phase == _Phase.finished ||
                            (showingTutorial && _tutorialFinishedAllStrokes) ||
                            showingPreview,
                        canvasConfig: widget.config.app.canvas,
                        colors: colors,
                        tubeWidthOverride: widget.strokeData.tubeWidthFactor,
                        freeDrawStrokes: def.freeDraw
                            ? _trace.userStrokes
                            : const <List<Offset>>[],
                        sparkles: _sparkles,
                        celebrationProgress: _phase == _Phase.finished
                            ? _celebration.value
                            : 0,
                        // The whole letter's standing, not just this attempt:
                        // the star that blooms is the one they now hold.
                        celebrationStars: widget.progress.starsWith(
                          widget.config.scoring.starThresholds,
                        ),
                        celebrationStarRadius:
                            widget.config.trace.celebration.starRadiusFactor,
                        onPointerDown: _phase == _Phase.tracing
                            ? _trace.startPointer
                            : null,
                        onPointerMove: _phase == _Phase.tracing
                            ? _trace.movePointer
                            : null,
                        onPointerUp: _phase == _Phase.tracing
                            ? _trace.endPointer
                            : null,
                      ),
                    ),
                    _StatusStrip(
                      phase: _phase,
                      attempt: _lastAttempt,
                      progress: widget.progress,
                      thresholds: widget.config.scoring.starThresholds,
                      totalMarks: _markScheme.totalMarks,
                      hint: def.freeDraw
                          ? l10n.freeDrawHint
                          : l10n.tutorialHint,
                      colors: colors,
                      l10n: l10n,
                    ),
                  ],
                ),
              ),
              _ControlsPanel(
                mode: _mode,
                onModeChanged: _selectMode,
                onReplay: def.showTutorial ? _replayTutorial : null,
                onClear: _clear,
                onSubmit: def.freeDraw && _phase == _Phase.tracing
                    ? _submit
                    : null,
                // Once finished, offer the way back explicitly rather than
                // leaving the child to find the clear icon.
                onTryAgain: _phase == _Phase.finished ? _clear : null,
                colors: colors,
                l10n: l10n,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Left panel: which letter this is, and a word that uses it.
class _LetterInfoPanel extends StatelessWidget {
  final Letter letter;
  final ThemeColors colors;
  final AppLocalizations l10n;

  /// Replays the letter's pronunciation — shown as a small speaker icon
  /// rather than autoplaying on every tap, since the letter is already
  /// spoken once on opening the screen and once on finishing an attempt; a
  /// child who wants it again can ask for it without waiting for either.
  final VoidCallback? onReplaySound;

  /// "க் + ஆ = கா" — null for every catalogue but uyirmei.
  final String? composition;

  const _LetterInfoPanel({
    required this.letter,
    required this.colors,
    required this.l10n,
    this.onReplaySound,
    this.composition,
  });

  @override
  Widget build(BuildContext context) {
    // Wide enough for the widest character rather than the average one:
    // ணௌ carries a sign on each side and runs about three times the width
    // of க. The canvas is a square cut from the screen height, so on a
    // landscape phone there is horizontal room to spare here.
    return SizedBox(
      width: 176,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: BackCircleButton(
                color: colors.textSecondary,
                background: colors.canvasBackground,
                border: colors.starEmpty,
              ),
            ),
            const Spacer(),
            // Scaled down to fit, never wrapped. A uyirmei is a consonant and
            // its vowel sign, and with no break opportunity in it Flutter
            // will break *anywhere* — னி came out as ன above ி, which is not
            // the letter. Splitting a combining sign off its consonant is
            // the one thing this must never do.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                letter.tamil,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  fontSize: 76,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                  height: 1.1,
                ),
              ),
            ),
            Text(
              letter.transliteration,
              style: TextStyle(fontSize: 18, color: colors.textSecondary),
            ),
            if (composition != null) ...[
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  composition!,
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colors.primary,
                  ),
                ),
              ),
            ],
            if (onReplaySound != null) ...[
              const SizedBox(height: 4),
              Semantics(
                label: l10n.replayLetterSound,
                button: true,
                child: Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onReplaySound,
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        Icons.volume_up_rounded,
                        size: 22,
                        color: colors.secondary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
            // Omitted rather than left blank where no example word has been
            // written — every uyirmei, for now.
            if (letter.hasExampleWord) ...[
              const SizedBox(height: 18),
              Text(
                l10n.exampleWordLabel,
                style: TextStyle(fontSize: 11, color: colors.textSecondary),
              ),
              Text(
                letter.exampleWordTamil!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
            ],
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

/// Right panel: how much help you want, replay the demo, start over.
class _ControlsPanel extends StatelessWidget {
  final TraceMode mode;
  final ValueChanged<TraceMode> onModeChanged;
  final VoidCallback? onReplay;
  final VoidCallback onClear;
  final VoidCallback? onSubmit;
  final VoidCallback? onTryAgain;
  final ThemeColors colors;
  final AppLocalizations l10n;

  const _ControlsPanel({
    required this.mode,
    required this.onModeChanged,
    required this.onReplay,
    required this.onClear,
    required this.onSubmit,
    required this.onTryAgain,
    required this.colors,
    required this.l10n,
  });

  String _labelFor(TraceMode m) {
    switch (m) {
      case TraceMode.easy:
        return l10n.modeEasy;
      case TraceMode.medium:
        return l10n.modeMedium;
      case TraceMode.hard:
        return l10n.modeHard;
      case TraceMode.special:
        return l10n.modeSpecial;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 148,
      // Four modes plus the actions can outgrow a short landscape window, so
      // let the column scroll rather than overflow.
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final m in TraceMode.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _ModeButton(
                  label: _labelFor(m),
                  selected: m == mode,
                  colors: colors,
                  onTap: () => onModeChanged(m),
                ),
              ),
            const SizedBox(height: 8),
            if (onTryAgain != null) ...[
              _RoundAction(
                icon: Icons.refresh_rounded,
                label: l10n.tryAgain,
                colors: colors,
                onTap: onTryAgain!,
                emphasised: true,
              ),
              const SizedBox(height: 8),
            ],
            if (onSubmit != null) ...[
              _RoundAction(
                icon: Icons.check_rounded,
                label: l10n.submit,
                colors: colors,
                onTap: onSubmit!,
                emphasised: true,
              ),
              const SizedBox(height: 8),
            ],
            if (onReplay != null) ...[
              _RoundAction(
                icon: Icons.replay_rounded,
                label: l10n.watchAgain,
                colors: colors,
                onTap: onReplay!,
              ),
              const SizedBox(height: 8),
            ],
            _RoundAction(
              icon: Icons.delete_outline_rounded,
              label: l10n.clear,
              colors: colors,
              onTap: onClear,
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final ThemeColors colors;
  final VoidCallback onTap;

  const _ModeButton({
    required this.label,
    required this.selected,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: selected ? colors.primary : colors.canvasBackground,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : colors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final ThemeColors colors;
  final VoidCallback onTap;
  final bool emphasised;

  const _RoundAction({
    required this.icon,
    required this.label,
    required this.colors,
    required this.onTap,
    this.emphasised = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: emphasised ? colors.primary : colors.canvasBackground,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(9),
              child: Icon(
                icon,
                color: emphasised ? Colors.white : colors.primary,
                size: 24,
              ),
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: colors.textSecondary),
        ),
      ],
    );
  }
}

/// Thin strip under the canvas: a hint while writing, and once an attempt
/// finishes, what it earned plus the character's running total.
class _StatusStrip extends StatelessWidget {
  final _Phase phase;
  final AttemptResult? attempt;
  final LetterProgress progress;
  final StarThresholds thresholds;
  final int totalMarks;
  final String hint;
  final ThemeColors colors;
  final AppLocalizations l10n;

  const _StatusStrip({
    required this.phase,
    required this.attempt,
    required this.progress,
    required this.thresholds,
    required this.totalMarks,
    required this.hint,
    required this.colors,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final result = attempt;
    if (phase != _Phase.finished || result == null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          hint,
          style: TextStyle(fontSize: 13, color: colors.textSecondary),
        ),
      );
    }

    final earned = result.marks > 0;
    final accent = earned ? colors.success : colors.retry;
    final stars = progress.starsWith(thresholds);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < 3; i++)
            MagicPenStar(
              size: 28,
              color: i < stars ? colors.starFilled : colors.starEmpty,
            ),
          const SizedBox(width: 12),
          // The character's running total, not just this attempt.
          Text(
            '${l10n.scoreLabel}: ${progress.totalMarks}/$totalMarks',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '+${result.marks}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            earned ? l10n.encouragementSuccess : l10n.encouragementRetry,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}
