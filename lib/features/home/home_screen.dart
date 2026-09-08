import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/config_service.dart';
import '../../data/models/letter.dart';
import '../../l10n/gen/app_localizations.dart';
import '../letters/category_tile.dart';
import '../letters/letter_groups_screen.dart';
import '../letters/letters_screen.dart';
import '../../data/repos/word_repository.dart';
import '../games/word_builder/word_list_screen.dart';
import '../letters/score_badge.dart';
import '../games/game_providers.dart';
import '../common/guide_highlight.dart';
import '../letter/letter_providers.dart';
import '../parent/parental_gate_screen.dart';
import '../../services/audio_service.dart';
import '../../services/settings_store.dart';
import '../../services/theme_selector.dart';
import 'sky_backdrop.dart';

/// Where the app opens: one tile per category (CLAUDE.md section 3).
///
/// Only the categories that exist are here. Profile and Performance are not
/// tiles-in-waiting — a child tapping something that does nothing learns the
/// app is broken, so each appears when it works. The Parent Zone is reached
/// through the ringed button in the top-left corner, past a parental gate
/// (CLAUDE.md section 1) — the same corner quitting used to sit in, since
/// quitting now lives inside the zone it is gated behind rather than loose
/// on a child-facing screen.
///
/// Stroke-order authoring is reached from a letter list rather than here, so
/// the tool opens already scoped to the letters of one category.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(configServiceProvider);
    // Every catalogue, so a category tile can show what it has earned and the
    // badge can total the lot.
    final catalogues = {
      for (final c in LetterCatalogue.values) c: ref.watch(lettersProvider(c)),
    };
    final authoredAsync = ref.watch(authoredStrokeIdsProvider);
    final wordsAsync = ref.watch(wordsProvider);

    final error =
        configAsync.error ??
        authoredAsync.error ??
        wordsAsync.error ??
        catalogues.values
            .map((a) => a.error)
            .firstWhere((e) => e != null, orElse: () => null);
    if (error != null) {
      return Scaffold(body: Center(child: Text('Failed to load: $error')));
    }
    if (!configAsync.hasValue ||
        !authoredAsync.hasValue ||
        !wordsAsync.hasValue ||
        catalogues.values.any((a) => !a.hasValue)) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final config = configAsync.requireValue;
    final l10n = AppLocalizations.of(context);
    final progress = ref.watch(progressStoreProvider);
    final thresholds = config.scoring.starThresholds;

    // Home is the "general" screen for background music — every screen
    // reached from here keeps whatever is already playing except the game,
    // which asserts its own track the same way when it is on top
    // (word_list_screen.dart). ensureBackgroundMusic is a no-op once this
    // track is already looping, so calling it on every rebuild is safe.
    final settings = ref.watch(settingsStoreProvider);
    // The toggle beside the Parent Zone button picks this, never the system
    // clock — and it now applies app-wide (themeColorsOf), not just here;
    // this is simply the one screen that carries the control itself.
    final isDay = settings.homeTheme == HomeTheme.light;
    final colors = themeColorsOf(config, settings);
    final audio = ref.read(audioServiceProvider);
    final musicOn =
        config.app.featureFlags.audioEnabled && settings.musicEnabled;
    final soundOn =
        config.app.featureFlags.audioEnabled && settings.soundEnabled;
    audio.ensureBackgroundMusic(BackgroundTrack.general, enabled: musicOn);

    // How big a set is, as the tile says it. Uyir reads "12+1" rather than
    // "13" because ஃ is a bonus level inside the vowels rather than a
    // thirteenth vowel (CLAUDE.md section 2) — and it is derived from the
    // catalogue's own categories, so a roster change cannot leave it lying.
    String countOf(LetterCatalogue c) {
      final parts = <LetterCategory, int>{};
      for (final letter in catalogues[c]!.requireValue) {
        parts[letter.category] = (parts[letter.category] ?? 0) + 1;
      }
      return parts.values.join('+');
    }

    // Characters finished outright rather than stars earned. A star total
    // climbs to three times the size of a category and says nothing a child
    // can act on; "eleven done, of thirteen" does.
    int medalsIn(LetterCatalogue c) => threeStarCount(
      letters: catalogues[c]!.requireValue,
      progress: progress,
      thresholds: thresholds,
    );

    // A category appears once something inside it can actually be traced. The
    // roster lands in the repo well before anyone has drawn the stroke orders
    // for it, and a tile leading to six padlocked-looking letters teaches a
    // child the app is broken — the same reason the games and the parent zone
    // are not tiles-in-waiting either.
    //
    // Unless the authoring tool is on, where the opposite is true: a category
    // with no orders yet is precisely the one somebody needs to walk into, and
    // the Author button lives inside its letter list. The flag is what makes
    // that safe — it is off in a child's build, so this only ever widens the
    // picker for whoever is drawing the orders.
    final authored = authoredAsync.requireValue;
    final authoring = config.app.featureFlags.authoringEnabled;
    final shown = [
      for (final c in LetterCatalogue.values)
        if (authoring ||
            catalogues[c]!.requireValue.any(
              (l) => authored.contains(l.strokeDataId),
            ))
          c,
    ];

    // The 247, counted rather than asserted.
    final core = [
      for (final c in LetterCatalogue.values)
        if (c.isPartOf247) catalogues[c]!.requireValue.length,
    ].fold(0, (a, b) => a + b);

    // Which tile is next. Nothing is locked, so without this a child meets a
    // row of equal-looking doors and no reason to pick one; the first set they
    // have not finished is the answer, and only ever one of them is marked.
    LetterCatalogue? guided;
    for (final c in shown) {
      if (medalsIn(c) < catalogues[c]!.requireValue.length) {
        guided = c;
        break;
      }
    }
    final gameGuided =
        guided == null &&
        ref.watch(gameStoreProvider).cleanWords.length <
            wordsAsync.requireValue.length;

    Widget categoryTile(LetterCatalogue catalogue) => GuideHighlight(
      active: catalogue == guided,
      color: colors.secondary,
      child: CategoryTile(
        sample: _sampleOf(catalogue),
        // The count says how big the set is, so a child and whoever is
        // watching them can see how far through it they are.
        label: l10n.countedLabel(catalogue.titleOf(l10n), countOf(catalogue)),
        medals: medalsIn(catalogue),
        colors: colors,
        onTap: () {
          audio.playClick(enabled: soundOn);
          Navigator.of(context).push(
            MaterialPageRoute(
              // Uyirmei is 216 letters, so it opens on its 18 consonant
              // rows rather than one enormous list.
              builder: (_) => catalogue.isGrouped
                  ? LetterGroupsScreen(catalogue: catalogue)
                  : LettersScreen(catalogue: catalogue),
            ),
          );
        },
      ),
    );

    // The 247 first, then the game, then the letters that sit outside them.
    // The game is the same size and shape as the rest — only the colour and
    // the slow breathing say it is play rather than practice, which is what a
    // child who cannot read the label goes on.
    final tiles = <Widget>[
      for (final c in shown)
        if (c.isPartOf247) categoryTile(c),
      _BreathingTile(
        child: GuideHighlight(
          active: gameGuided,
          color: colors.secondary,
          child: CategoryTile(
            // The tile reads எழுத்து / விளையாட்டு down the same two lines every
            // other tile uses: what it is on top, what kind of thing underneath.
            sample: 'எழுத்து',
            label: l10n.countedLabel(
              l10n.games,
              '${wordsAsync.requireValue.length}',
            ),
            medals: ref.watch(gameStoreProvider).cleanWords.length,
            borderColor: colors.success,
            colors: colors,
            onTap: () {
              audio.playClick(enabled: soundOn);
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const WordListScreen()));
            },
          ),
        ),
      ),
      for (final c in shown)
        if (!c.isPartOf247) categoryTile(c),
    ];

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
        child: Stack(
          children: [
            Positioned.fill(child: SkyBackdrop(colors: colors, isDay: isDay)),
            SafeArea(
              child: Column(
                children: [
                  // The running totals sit in the corner here too, so a child
                  // sees what they have without opening anything.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Row(
                      children: [
                        // Where a grown-up expects a settings-style entry and a
                        // child is not led to it. Quitting used to live here
                        // ungated (HANDOFF.md); it now lives inside the zone this
                        // button opens, behind the parental gate. Sized up and
                        // coloured rather than the plain grey every other ringed
                        // icon uses — the rest are navigation, this one opens a
                        // whole separate area of the app and reads as such.
                        CircleIconButton(
                          icon: Icons.shield_rounded,
                          tooltip: l10n.parentZone,
                          color: colors.secondary,
                          background: colors.canvasBackground,
                          border: colors.secondary,
                          size: 56,
                          iconSize: 30,
                          onPressed: () {
                            audio.playClick(enabled: soundOn);
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ParentalGateScreen(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 10),
                        // Picks the sky backdrop and this screen's palette
                        // by hand rather than the system clock — see
                        // sky_backdrop.dart.
                        CircleIconButton(
                          icon: isDay
                              ? Icons.wb_sunny_rounded
                              : Icons.nightlight_round,
                          tooltip: isDay ? l10n.themeLight : l10n.themeDark,
                          color: isDay ? colors.starFilled : colors.secondary,
                          background: colors.canvasBackground,
                          border: colors.starEmpty,
                          onPressed: () {
                            audio.playClick(enabled: soundOn);
                            ref
                                .read(settingsStoreProvider.notifier)
                                .setHomeTheme(
                                  isDay ? HomeTheme.dark : HomeTheme.light,
                                );
                          },
                        ),
                        const Spacer(),
                        ScoreBadge(
                          stars: [
                            for (final c in shown)
                              totalStars(
                                letters: catalogues[c]!.requireValue,
                                progress: progress,
                                thresholds: thresholds,
                              ),
                          ].fold<int>(0, (a, b) => a + b),
                          achievements: ref.watch(achievementsProvider),
                          coins: ref.watch(coinBalanceProvider),
                          colors: colors,
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    // The number is counted off the catalogues rather than typed
                    // in, so it cannot end up claiming something the app does not
                    // teach. Grantha is outside the 247 and so is not in it.
                    l10n.appTitleCounted(l10n.appTitle, '$core'),
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // One row that slides, rather than a grid that wraps.
                  //
                  // Wrapping put the fourth category on a second line on a phone,
                  // where it sat alone under three others and read as a different
                  // kind of thing. A single row keeps every category the same
                  // size and in one order, and the tile that does not fit peeks in
                  // from the edge — which is what tells a child there is more to
                  // see. Centred while they all fit, so nothing moves on a tablet.
                  LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: (constraints.maxWidth - 40).clamp(
                            0.0,
                            double.infinity,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var i = 0; i < tiles.length; i++) ...[
                              if (i > 0) const SizedBox(width: 20),
                              tiles[i],
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _sampleOf(LetterCatalogue catalogue) => switch (catalogue) {
    LetterCatalogue.uyir => 'அ ஆ இ',
    LetterCatalogue.mei => 'க் ங் ச்',
    LetterCatalogue.uyirmei => 'க கா கி',
    LetterCatalogue.vadamozhi => 'ஜ ஷ ஸ',
  };
}

/// A tile that rocks and swells very slightly, forever.
///
/// The games tile sits in a row of tiles that all look alike, and a child who
/// cannot read the label needs something other than the label to tell them
/// this one is play rather than practice. Deliberately small and slow:
/// CLAUDE.md section 11 rules out pressure, and a tile that jumps for
/// attention is exactly that.
///
/// **Stops when the device asks for reduced motion.** That is an accessibility
/// setting worth honouring on its own, and it is also what makes the tile
/// testable: a repeating controller schedules frames forever, so `pumpAndSettle`
/// never returns while one is running.
class _BreathingTile extends StatefulWidget {
  final Widget child;

  const _BreathingTile({required this.child});

  @override
  State<_BreathingTile> createState() => _BreathingTileState();
}

class _BreathingTileState extends State<_BreathingTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (still) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    return AnimatedBuilder(
      animation: curve,
      builder: (context, child) => Transform.rotate(
        angle: (curve.value - 0.5) * 0.045,
        child: Transform.scale(scale: 1 + curve.value * 0.04, child: child),
      ),
      child: widget.child,
    );
  }
}
