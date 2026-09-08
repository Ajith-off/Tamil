import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/config_service.dart';
import '../../../core/config/models/theme_config.dart';
import '../../../data/models/word_challenge.dart';
import '../../../data/repos/word_repository.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../common/guide_highlight.dart';
import '../../letter/letter_providers.dart';
import '../../../services/audio_service.dart';
import '../../../services/settings_store.dart';
import '../../../services/theme_selector.dart';
import '../game_providers.dart';
import 'game_hud.dart';
import 'word_builder_screen.dart';

/// One card per word: its picture, its word, and a way in.
///
/// **Opening a word costs a heart** (CLAUDE.md section 6). A clean round gives
/// it straight back, so playing well costs nothing and only a fumbled round
/// spends anything. With no hearts left the cards go quiet and the way to get
/// more is a coin.
class WordListScreen extends ConsumerWidget {
  const WordListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(configServiceProvider);
    final wordsAsync = ref.watch(wordsProvider);

    final error = configAsync.error ?? wordsAsync.error;
    if (error != null) {
      return Scaffold(body: Center(child: Text('Failed to load: $error')));
    }
    if (!configAsync.hasValue || !wordsAsync.hasValue) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final config = configAsync.requireValue;
    final l10n = AppLocalizations.of(context);
    final words = wordsAsync.requireValue;
    final game = ref.watch(gameStoreProvider);
    final coins = ref.watch(coinBalanceProvider);

    // The game gets its own, livelier loop while this list or a round is on
    // top — home reasserts the general one the moment the child steps back
    // out (home_screen.dart), so nothing here has to hand it back itself.
    final settings = ref.watch(settingsStoreProvider);
    final colors = themeColorsOf(config, settings);
    final audio = ref.read(audioServiceProvider);
    final musicOn =
        config.app.featureFlags.audioEnabled && settings.musicEnabled;
    final soundOn =
        config.app.featureFlags.audioEnabled && settings.soundEnabled;
    audio.ensureBackgroundMusic(BackgroundTrack.game, enabled: musicOn);

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
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: BackCircleButton(
                          color: colors.textSecondary,
                          background: colors.canvasBackground,
                          border: colors.starEmpty,
                        ),
                      ),
                    ),
                    Text(
                      l10n.wordGame,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: GameHud(
                          hearts: game.hearts ?? 0,
                          heartCapacity: config.games.wordBuilder.heartsPerCoin,
                          coins: coins,
                          achieved: game.achievements > 0,
                          achievementCount: ref.watch(achievementsProvider),
                          onBuyHearts: coins > 0
                              ? () {
                                  ref.read(coinPurseProvider.notifier).spend(1);
                                  ref
                                      .read(gameStoreProvider.notifier)
                                      .addHeartsForCoin();
                                }
                              : null,
                          colors: colors,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 180,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: words.length,
                  itemBuilder: (context, i) => _WordCard(
                    word: words[i],
                    colors: colors,
                    cleared: game.cleanWords.contains(words[i].id),
                    // A heart is refused before it is charged for, so the card
                    // goes quiet rather than opening onto a word that cannot
                    // be played.
                    enabled:
                        game.loaded &&
                        ref.read(gameStoreProvider.notifier).canOpen,
                    onTap: () {
                      if (!ref.read(gameStoreProvider.notifier).openWord()) {
                        return;
                      }
                      audio.playClick(enabled: soundOn);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => WordBuilderScreen(word: words[i]),
                        ),
                      );
                    },
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

class _WordCard extends StatelessWidget {
  final WordChallenge word;
  final ThemeColors colors;
  final bool cleared;
  final bool enabled;
  final VoidCallback onTap;

  const _WordCard({
    required this.word,
    required this.colors,
    required this.cleared,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: word.tamil,
      button: true,
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Material(
          color: colors.canvasBackground,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: enabled ? onTap : null,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colors.primary, width: 3),
              ),
              child: Column(
                children: [
                  Expanded(child: Image.asset(word.image, fit: BoxFit.contain)),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        word.tamil,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                      // The medal marks a word already beaten without a mistake.
                      if (cleared) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.military_tech_rounded,
                          size: 18,
                          color: colors.starFilled,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
