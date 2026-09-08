import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/config_service.dart';
import '../../core/config/models/theme_config.dart';
import '../../data/models/letter.dart';
import '../../data/models/score.dart';
import '../../l10n/gen/app_localizations.dart';
import '../common/guide_highlight.dart';
import '../authoring/authoring_screen.dart';
import '../letter/letter_providers.dart';
import '../letter/letter_screen.dart';
import '../../services/audio_service.dart';
import '../../services/settings_store.dart';
import '../../services/theme_selector.dart';
import 'score_badge.dart';
import 'reward_icons.dart';

/// A catalogue names itself the same way wherever it is shown — as the title
/// of its own list, and on the tile that opens it.
extension LetterCatalogueLabel on LetterCatalogue {
  String titleOf(AppLocalizations l10n) => switch (this) {
    LetterCatalogue.uyir => l10n.categoryUyir,
    LetterCatalogue.mei => l10n.categoryMei,
    LetterCatalogue.uyirmei => l10n.categoryUyirmei,
    LetterCatalogue.vadamozhi => l10n.categoryVadamozhi,
  };
}

/// One category: every letter as a bubble, showing what it has earned and
/// whether it is open yet.
class LettersScreen extends ConsumerWidget {
  final LetterCatalogue catalogue;

  /// Show only this sub-group. Uyirmei arrives as 216 letters in one
  /// catalogue and is navigated 12 at a time; null means the whole file.
  final String? group;

  /// What to call the list when it is one group of a bigger catalogue.
  final String? title;

  const LettersScreen({
    super.key,
    required this.catalogue,
    this.group,
    this.title,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(configServiceProvider);
    final lettersAsync = ref.watch(lettersProvider(catalogue));
    final authoredAsync = ref.watch(authoredStrokeIdsProvider);

    final error =
        configAsync.error ?? lettersAsync.error ?? authoredAsync.error;
    if (error != null) {
      return Scaffold(body: Center(child: Text('Failed to load: $error')));
    }
    if (!configAsync.hasValue ||
        !lettersAsync.hasValue ||
        !authoredAsync.hasValue) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final config = configAsync.requireValue;
    final all = lettersAsync.requireValue;
    final letters = group == null
        ? all
        : all.where((l) => l.group == group).toList();
    final authored = authoredAsync.requireValue;
    final progress = ref.watch(progressStoreProvider);
    final settings = ref.watch(settingsStoreProvider);
    final colors = themeColorsOf(config, settings);
    final l10n = AppLocalizations.of(context);
    final soundOn =
        config.app.featureFlags.audioEnabled && settings.soundEnabled;
    final audio = ref.read(audioServiceProvider);

    final availability = letterAvailability(
      letters: letters,
      authoredStrokeIds: authored,
      progress: progress,
      thresholds: config.scoring.starThresholds,
      starsToUnlockNext: config.app.progression.starsToUnlockNext,
    );
    final pending = availability
        .where((a) => a == LetterAvailability.notAuthored)
        .length;

    int starsOf(int i) =>
        (progress[letters[i].id] ?? LetterProgress(letterId: letters[i].id))
            .starsWith(config.scoring.starThresholds);

    // The first character that can be opened and is not finished. Exactly one,
    // because two would be a choice rather than an answer.
    var guided = -1;
    for (var i = 0; i < letters.length; i++) {
      if (availability[i] == LetterAvailability.open && starsOf(i) < 3) {
        guided = i;
        break;
      }
    }

    return Scaffold(
      backgroundColor: colors.background,
      // Author this category's writing orders, all of its letters in one
      // sitting. Debug builds only — it is developer tooling, and a
      // child-facing screen must never lead anywhere like it.
      floatingActionButton: config.app.featureFlags.authoringEnabled
          ? FloatingActionButton.extended(
              backgroundColor: colors.secondary,
              foregroundColor: colors.canvasBackground,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AuthoringScreen(
                    title: catalogue.titleOf(l10n),
                    letterIds: [
                      for (final letter in letters) letter.strokeDataId,
                    ],
                  ),
                ),
              ),
              icon: const Icon(Icons.edit_note_rounded),
              label: Text(
                pending == 0
                    ? 'Author (${letters.length})'
                    : 'Author ($pending left)',
              ),
            )
          : null,
      body: Container(
        // Without an explicit size the column only claims the width of its
        // widest child, leaving the backdrop and the bubbles hugging the
        // left edge.
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
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Row(
                  children: [
                    // Centred title with a way back on one side and the
                    // totals on the other, so the heading stays put whatever
                    // the totals grow to.
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        // A way back that does not depend on knowing the
                        // system gesture. Same arrow the letter screen uses.
                        child: BackCircleButton(
                          color: colors.textSecondary,
                          background: colors.canvasBackground,
                          border: colors.starEmpty,
                        ),
                      ),
                    ),
                    Text(
                      title ?? catalogue.titleOf(l10n),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: ScoreBadge(
                          stars: totalStars(
                            letters: letters,
                            progress: progress,
                            thresholds: config.scoring.starThresholds,
                          ),
                          coins: ref.watch(coinBalanceProvider),
                          colors: colors,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                pending == letters.length
                    ? l10n.categoryEmpty
                    : l10n.tapALetter,
                style: TextStyle(fontSize: 13, color: colors.textSecondary),
              ),
              Expanded(
                child: SingleChildScrollView(
                  // Room under the last row for the authoring button, which
                  // otherwise sits on top of the letters in that corner.
                  padding: EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    config.app.featureFlags.authoringEnabled ? 96 : 16,
                  ),
                  child: Center(
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      alignment: WrapAlignment.center,
                      children: [
                        for (var i = 0; i < letters.length; i++)
                          _LetterBubble(
                            letter: letters[i],
                            stars: starsOf(i),
                            // Nothing is locked, so the ring is what says
                            // "this one next" — the first character of the set
                            // that is not finished yet.
                            guided: i == guided,
                            availability: availability[i],
                            colors: colors,
                            onTap: () {
                              audio.playClick(enabled: soundOn);
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => LetterScreen(
                                    catalogue: catalogue,
                                    letterId: letters[i].id,
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
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

class _LetterBubble extends StatelessWidget {
  final Letter letter;
  final int stars;
  final bool guided;
  final LetterAvailability availability;
  final ThemeColors colors;
  final VoidCallback onTap;

  const _LetterBubble({
    required this.letter,
    required this.stars,
    required this.guided,
    required this.availability,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final unlocked = availability == LetterAvailability.open;
    // The achievement — three stars — is what turns the ring green. Orange
    // still says "open and waiting"; green says "done", the same colour the
    // certificate and the celebration burst already use for success.
    final mastered = stars >= 3;
    return Semantics(
      label: letter.tamil,
      enabled: unlocked,
      button: true,
      child: Opacity(
        opacity: unlocked ? 1 : 0.45,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GuideHighlight(
              active: guided,
              color: colors.secondary,
              borderRadius: const BorderRadius.all(Radius.circular(999)),
              child: Material(
                color: colors.canvasBackground,
                shape: CircleBorder(
                  side: BorderSide(
                    color: !unlocked
                        ? colors.starEmpty
                        : mastered
                        ? colors.success
                        : colors.primary,
                    width: 3,
                  ),
                ),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: unlocked ? onTap : null,
                  child: SizedBox(
                    width: 92,
                    height: 92,
                    // A locked letter still shows its own shape, greyed back
                    // behind the padlock. A wall of identical padlocks tells a
                    // child nothing; seeing the letter they are working towards
                    // is half the reason to keep going.
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Scaled to fit, never wrapped. Uyirmei are not all the
                        // same width — கௌ is nearly three times கி — and at a
                        // fixed size the wide ones broke out of the bubble and
                        // spilled onto a second line.
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              letter.tamil,
                              maxLines: 1,
                              softWrap: false,
                              style: TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                color: unlocked
                                    ? colors.textPrimary
                                    : colors.textSecondary.withValues(
                                        alpha: 0.35,
                                      ),
                              ),
                            ),
                          ),
                        ),
                        // A padlock says "earn stars and this opens". An
                        // un-authored letter cannot be opened that way at all,
                        // so it gets its own mark rather than a promise the
                        // app cannot keep.
                        if (!unlocked)
                          Align(
                            alignment: Alignment.bottomRight,
                            child: Padding(
                              padding: const EdgeInsets.only(
                                right: 14,
                                bottom: 12,
                              ),
                              child: Icon(
                                availability == LetterAvailability.notAuthored
                                    ? Icons.more_horiz_rounded
                                    : Icons.lock_rounded,
                                color: colors.textSecondary,
                                size: 24,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 3; i++)
                  MagicPenStar(
                    size: 16,
                    color: i < stars ? colors.starFilled : colors.starEmpty,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
