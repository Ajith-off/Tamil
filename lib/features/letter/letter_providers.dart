import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/models/app_config.dart';
import '../../core/config/models/scoring_config.dart';
import '../../data/models/letter.dart';
import '../../data/models/score.dart';
import '../../data/models/stroke.dart';
import '../../data/repos/letter_repository.dart';
import '../../data/repos/progress_repository.dart';
import '../../core/config/config_service.dart';
import '../games/game_providers.dart';

/// Every letter of one catalogue, in writing order — the whole set, whether
/// or not it has stroke data yet.
final lettersProvider = FutureProvider.family<List<Letter>, LetterCatalogue>((ref, catalogue) {
  return ref.watch(letterRepositoryProvider).loadCatalogue(catalogue);
});

/// Which letters have stroke data, and so can actually be traced.
final authoredStrokeIdsProvider = FutureProvider<Set<String>>((ref) {
  return ref.watch(letterRepositoryProvider).authoredStrokeDataIds();
});

/// Reference strokes for one letter.
final letterStrokeDataProvider = FutureProvider.family<LetterStrokeData, String>((ref, id) {
  return ref.watch(letterRepositoryProvider).loadStrokeData(id);
});

/// What every character has earned so far, kept between runs.
///
/// Reads what was saved at construction and writes the whole document back on
/// every change — see [ProgressRepository] for why one blob rather than a
/// database. Loading is deliberately not awaited anywhere: the app opens on
/// an empty store and fills in a frame or two later, because a splash screen
/// blocking on a disk read is a worse trade than a category tile whose star
/// count arrives a moment after the tile does.
class ProgressStore extends StateNotifier<Map<String, LetterProgress>> {
  final ProgressRepository _repository;

  ProgressStore(this._repository) : super(const {}) {
    _hydrate();
  }

  Future<void> _hydrate() async {
    final saved = await _repository.load();
    if (!mounted) return;
    // Anything earned while the read was in flight wins: it is newer, and the
    // saved file cannot contain it yet.
    state = {...saved.letters, ...state};
  }

  LetterProgress progressFor(String letterId) =>
      state[letterId] ?? LetterProgress(letterId: letterId);

  void record(String letterId, AttemptResult attempt) {
    state = {...state, letterId: progressFor(letterId).withAttempt(attempt)};
    _repository.saveLetters(state);
  }
}

final progressStoreProvider =
    StateNotifierProvider<ProgressStore, Map<String, LetterProgress>>((ref) {
  return ProgressStore(ref.watch(progressRepositoryProvider));
});

/// Which letters the child may open.
///
/// The first is always available; after that a letter opens once the one
/// before it has earned enough stars. Progression is by stars alone — never
/// by watching an ad, and nothing else blocks it (CLAUDE.md section 6).
List<bool> unlockedFlags({
  required List<Letter> letters,
  required Map<String, LetterProgress> progress,
  required StarThresholds thresholds,
  required int starsToUnlockNext,
}) {
  final unlocked = <bool>[];
  for (var i = 0; i < letters.length; i++) {
    if (i == 0) {
      unlocked.add(true);
      continue;
    }
    final previous = progress[letters[i - 1].id];
    final stars = previous?.starsWith(thresholds) ?? 0;
    unlocked.add(stars >= starsToUnlockNext);
  }
  return unlocked;
}

/// Characters taken all the way to three stars, across a set of letters.
///
/// This is the achievement a letter earns, and it is deliberately the same
/// count the coin is paid on: finishing a character completely is one thing,
/// and it is worth one of each. Word Builder's clean clears are the other
/// source (CLAUDE.md section 8), and the two add up.
int threeStarCount({
  required List<Letter> letters,
  required Map<String, LetterProgress> progress,
  required StarThresholds thresholds,
}) {
  var total = 0;
  for (final letter in letters) {
    if ((progress[letter.id]?.starsWith(thresholds) ?? 0) >= 3) total++;
  }
  return total;
}

/// Stars earned across a set of letters, for the running total a list shows.
int totalStars({
  required List<Letter> letters,
  required Map<String, LetterProgress> progress,
  required StarThresholds thresholds,
}) {
  var total = 0;
  for (final letter in letters) {
    total += progress[letter.id]?.starsWith(thresholds) ?? 0;
  }
  return total;
}

/// Coins the child has spent. What they have *earned* is deliberately not
/// stored here — see [coinBalance].
class CoinPurse extends StateNotifier<int> {
  final ProgressRepository _repository;

  CoinPurse(this._repository) : super(0) {
    _hydrate();
  }

  Future<void> _hydrate() async {
    final saved = await _repository.load();
    if (!mounted) return;
    // Anything spent while the read was in flight is added to what was
    // already spent, never replaced by it — dropping it would hand back a
    // coin the child has already had the value of.
    state = saved.coinsSpent + state;
  }

  void spend(int coins) {
    state = state + coins;
    _repository.saveCoinsSpent(state);
  }
}

final coinPurseProvider = StateNotifierProvider<CoinPurse, int>((ref) {
  return CoinPurse(ref.watch(progressRepositoryProvider));
});

/// Coins earned by watching a rewarded ad in the Parent Zone.
///
/// An event, not a progress fact — unlike three-star letters or clean words,
/// there is nothing to recount it from later, so it has to be a stored
/// counter that only ever grows, the same shape as [CoinPurse] but adding
/// instead of spending.
class AdCoinBank extends StateNotifier<int> {
  final ProgressRepository _repository;

  AdCoinBank(this._repository) : super(0) {
    _hydrate();
  }

  Future<void> _hydrate() async {
    final saved = await _repository.load();
    if (!mounted) return;
    // Anything earned while the read was in flight is added to what was
    // already saved, never replaced by it.
    state = saved.coinsFromAds + state;
  }

  void earn(int coins) {
    state = state + coins;
    _repository.saveCoinsFromAds(state);
  }
}

final adCoinBankProvider = StateNotifierProvider<AdCoinBank, int>((ref) {
  return AdCoinBank(ref.watch(progressRepositoryProvider));
});

/// Coins available: the starting balance, plus one for every letter taken all
/// the way to three stars, less whatever has been spent (CLAUDE.md section 7).
///
/// Earnings are **derived from progress rather than banked** when they
/// happen. A letter keeps its best result and stars only ever go up, so
/// counting three-star letters pays exactly once per letter however many
/// times a child re-traces it. Nothing to make idempotent, because there is
/// no event to miss or replay.
int coinBalance({
  required Map<String, LetterProgress> progress,
  required StarThresholds thresholds,
  required CoinsConfig coins,
  required int spent,
  int cleanWords = 0,
  int coinsPerCleanWord = 0,
  int fromAds = 0,
}) {
  var earned = 0;
  for (final letter in progress.values) {
    if (letter.starsWith(thresholds) >= 3) earned += coins.perThreeStarLetter;
  }
  // Game winnings are counted the same way, from the set of words cleared
  // cleanly rather than from an event: a word pays exactly once however often
  // it is replayed, and there is nothing to miss, replay or de-duplicate.
  // Ad winnings cannot be counted that way — watching an ad is an event with
  // nothing left behind to recount — so [fromAds] is the one addend here that
  // comes from a stored counter rather than a re-derived total.
  return coins.startingBalance +
      earned +
      cleanWords * coinsPerCleanWord +
      fromAds -
      spent;
}

/// Why a letter can or cannot be opened.
enum LetterAvailability {
  open,

  /// Waiting on stars from the letter before it.
  lockedByStars,

  /// No stroke data has been authored for it yet, so there is nothing to
  /// trace. A development state, not something a child earns their way past.
  notAuthored,
}

/// The state of every letter in a list.
///
/// The star chain runs over the letters that can actually be traced, skipping
/// the un-authored ones entirely. Leaving them in the chain would deadlock
/// it: a letter with no stroke data can never be opened, so it can never earn
/// a star, so nothing after it would ever unlock.
List<LetterAvailability> letterAvailability({
  required List<Letter> letters,
  required Set<String> authoredStrokeIds,
  required Map<String, LetterProgress> progress,
  required StarThresholds thresholds,
  required int starsToUnlockNext,
}) {
  bool traceable(Letter letter) => authoredStrokeIds.contains(letter.strokeDataId);

  final chain = letters.where(traceable).toList();
  final unlocked = unlockedFlags(
    letters: chain,
    progress: progress,
    thresholds: thresholds,
    starsToUnlockNext: starsToUnlockNext,
  );
  final open = {
    for (var i = 0; i < chain.length; i++)
      if (unlocked[i]) chain[i].id,
  };

  return [
    for (final letter in letters)
      if (!traceable(letter))
        LetterAvailability.notAuthored
      else if (open.contains(letter.id))
        LetterAvailability.open
      else
        LetterAvailability.lockedByStars,
  ];
}

/// The balance every screen shows, worked out once.
///
/// Four screens carry a `ScoreBadge` and all four need the same number; adding
/// a new source of coins should not mean remembering to edit four call sites.
/// Zero until the config is in, which is a frame or two.
final coinBalanceProvider = Provider<int>((ref) {
  final config = ref.watch(configServiceProvider).valueOrNull;
  if (config == null) return 0;
  return coinBalance(
    progress: ref.watch(progressStoreProvider),
    thresholds: config.scoring.starThresholds,
    coins: config.app.coins,
    spent: ref.watch(coinPurseProvider),
    cleanWords: ref.watch(gameStoreProvider).cleanWords.length,
    coinsPerCleanWord: config.games.wordBuilder.coinsPerCleanWord,
    fromAds: ref.watch(adCoinBankProvider),
  );
});

/// Achievements across the whole app: every character taken to three stars,
/// plus every word beaten without a mistake.
///
/// Derived, like the coins, so replaying something cannot mint a second one.
final achievementsProvider = Provider<int>((ref) {
  final config = ref.watch(configServiceProvider).valueOrNull;
  if (config == null) return 0;
  final progress = ref.watch(progressStoreProvider);
  final thresholds = config.scoring.starThresholds;
  var letters = 0;
  for (final letter in progress.values) {
    if (letter.starsWith(thresholds) >= 3) letters++;
  }
  return letters + ref.watch(gameStoreProvider).cleanWords.length;
});
