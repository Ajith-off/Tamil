import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/config_service.dart';
import '../../core/config/models/theme_config.dart';
import '../../data/models/letter.dart';
import '../../l10n/gen/app_localizations.dart';
import '../common/guide_highlight.dart';
import '../authoring/authoring_screen.dart';
import '../letter/letter_providers.dart';
import '../../services/audio_service.dart';
import '../../services/settings_store.dart';
import '../../services/theme_selector.dart';
import 'category_tile.dart';
import 'score_badge.dart';
import 'letters_screen.dart';

/// The 18 consonant rows of உயிர்மெய், each holding 12 letters.
///
/// 216 characters never go on one screen (CLAUDE.md section 2). A row is
/// named by its consonant and shows the whole row's first letter, because
/// "க row" means nothing to a child who cannot read the label yet — the
/// shape does.
class LetterGroupsScreen extends ConsumerWidget {
  final LetterCatalogue catalogue;

  const LetterGroupsScreen({super.key, required this.catalogue});

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
    final letters = lettersAsync.requireValue;
    final authored = authoredAsync.requireValue;
    final progress = ref.watch(progressStoreProvider);
    final settings = ref.watch(settingsStoreProvider);
    final colors = themeColorsOf(config, settings);
    final l10n = AppLocalizations.of(context);
    final soundOn = config.app.featureFlags.audioEnabled && settings.soundEnabled;
    final audio = ref.read(audioServiceProvider);

    // Grouped in the catalogue's own order, so the rows read க ங ச ... as
    // the spec lists them rather than however a map happens to iterate.
    final groups = <String, List<Letter>>{};
    for (final letter in letters) {
      (groups[letter.group ?? letter.id] ??= []).add(letter);
    }

    // The row to go to next: the first one not finished. Nothing here is
    // locked, so without a mark a child meets eighteen identical doors.
    String? guided;
    for (final entry in groups.entries) {
      final done = threeStarCount(
        letters: entry.value,
        progress: progress,
        thresholds: config.scoring.starThresholds,
      );
      if (done < entry.value.length) {
        guided = entry.key;
        break;
      }
    }

    return Scaffold(
      backgroundColor: colors.background,
      floatingActionButton: config.app.featureFlags.authoringEnabled
          ? FloatingActionButton.extended(
              backgroundColor: colors.secondary,
              foregroundColor: colors.canvasBackground,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AuthoringScreen(
                    title: catalogue.titleOf(l10n),
                    letterIds: [for (final l in letters) l.strokeDataId],
                  ),
                ),
              ),
              icon: const Icon(Icons.edit_note_rounded),
              label: Text('Author (${letters.length})'),
            )
          : null,
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
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child:
                            // A way back that does not depend on knowing the
                            // system gesture. Same arrow the letter screen uses.
                            BackCircleButton(
                              color: colors.textSecondary,
                              background: colors.canvasBackground,
                              border: colors.starEmpty,
                            ),
                      ),
                    ),
                    Text(
                      catalogue.titleOf(l10n),
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
                          achievements: ref.watch(achievementsProvider),
                          coins: ref.watch(coinBalanceProvider),
                          colors: colors,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                l10n.pickAGroup,
                style: TextStyle(fontSize: 13, color: colors.textSecondary),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    config.app.featureFlags.authoringEnabled ? 96 : 16,
                  ),
                  child: Center(
                    child: Wrap(
                      spacing: 14,
                      runSpacing: 14,
                      alignment: WrapAlignment.center,
                      children: [
                        for (final entry in groups.entries)
                          GuideHighlight(
                            active: entry.key == guided,
                            color: colors.secondary,
                            child: _groupTile(
                              context: context,
                              letters: entry.value,
                              authored: authored,
                              l10n: l10n,
                              // Characters finished outright, matching the home
                              // picker: a row of twelve is a set to complete,
                              // and "four done" is what a child can act on.
                              medals: threeStarCount(
                                letters: entry.value,
                                progress: progress,
                                thresholds: config.scoring.starThresholds,
                              ),
                              colors: colors,
                              onTap: () {
                                audio.playClick(enabled: soundOn);
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => LettersScreen(
                                      catalogue: catalogue,
                                      group: entry.key,
                                      title: entry.value.first.groupTamil,
                                    ),
                                  ),
                                );
                              },
                            ),
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

/// One consonant row, shown exactly like a category on the home screen —
/// same tile, one level down. The sample is the row's own first letters, so
/// the row identifies itself by shape rather than by a label a child may not
/// read yet; the count says how much of it can be traced.
Widget _groupTile({
  required BuildContext context,
  required List<Letter> letters,
  required Set<String> authored,
  required AppLocalizations l10n,
  required int medals,
  required ThemeColors colors,
  required VoidCallback onTap,
}) {
  final ready = letters.where((l) => authored.contains(l.strokeDataId)).length;
  return CategoryTile(
    sample: letters.take(3).map((l) => l.tamil).join(' '),
    // Named for its consonant rather than counted. "9 / 12" was progress
    // through authoring, which is the developer's business; "க வரிசை" is what
    // the row *is*, which is the child's.
    label: l10n.groupRow(letters.first.groupTamil ?? ''),
    medals: medals,
    colors: colors,
    onTap: onTap,
    enabled: ready > 0,
    width: 178,
    sampleSize: 26,
  );
}
