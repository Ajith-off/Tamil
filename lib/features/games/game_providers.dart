import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/config_service.dart';
import '../../core/config/models/games_config.dart';
import '../../data/repos/progress_repository.dart';

/// Hearts left, and which words have been cleared without a mistake.
class GameState {
  /// Null until the saved file has been read. The screens show nothing
  /// spendable in the meantime rather than a wrong number that then jumps.
  final int? hearts;
  final Set<String> cleanWords;

  const GameState({this.hearts, this.cleanWords = const {}});

  bool get loaded => hearts != null;

  /// Achievement points: one per word cleared cleanly, ever (CLAUDE.md §8).
  int get achievements => cleanWords.length;

  GameState copyWith({int? hearts, Set<String>? cleanWords}) => GameState(
        hearts: hearts ?? this.hearts,
        cleanWords: cleanWords ?? this.cleanWords,
      );
}

/// Hearts, and the record of which words have been beaten cleanly.
///
/// Hearts are the one thing here that has to be *stored* rather than derived.
/// Coins are counted from what a child has achieved, so they cannot drift; a
/// heart is spent and given back, which is a running total and nothing else.
class GameStore extends StateNotifier<GameState> {
  final ProgressRepository _repository;
  final Future<WordBuilderConfig> _config;

  /// Cached once the config is in, so buying hearts does not have to await.
  int _heartsPerCoin = 0;

  GameStore(this._repository, this._config) : super(const GameState()) {
    _hydrate();
  }

  Future<void> _hydrate() async {
    final config = await _config;
    final saved = await _repository.load();
    if (!mounted) return;
    _heartsPerCoin = config.heartsPerCoin;
    state = GameState(
      hearts: saved.hearts ?? config.startingHearts,
      cleanWords: {...saved.cleanWords, ...state.cleanWords},
    );
    // A file that had never been written now has a heart count, so the
    // allowance is granted once rather than every launch.
    if (saved.hearts == null) _persist();
  }

  void _persist() {
    _repository.saveGame(hearts: state.hearts ?? 0, cleanWords: state.cleanWords);
  }

  bool get canOpen => (state.hearts ?? 0) > 0;

  /// Spends the heart that opens a word. Refuses rather than going negative —
  /// a heart is refused before it is charged for, which is the game's job and
  /// not the balance's.
  bool openWord() {
    if (!canOpen) return false;
    state = state.copyWith(hearts: state.hearts! - 1);
    _persist();
    return true;
  }

  /// A clean round gives the heart back and records the achievement.
  ///
  /// Returns true the first time this word is cleared cleanly, which is when
  /// the achievement point is new and the coin it pays is a new coin.
  bool finishedCleanly(String wordId) {
    final first = !state.cleanWords.contains(wordId);
    state = state.copyWith(
      hearts: (state.hearts ?? 0) + 1,
      cleanWords: {...state.cleanWords, wordId},
    );
    _persist();
    return first;
  }

  /// Buys [WordBuilderConfig.heartsPerCoin] hearts. The coin itself is taken
  /// by the caller through `CoinPurse`, which is the only thing that knows the
  /// balance.
  void addHeartsForCoin() {
    state = state.copyWith(hearts: (state.hearts ?? 0) + _heartsPerCoin);
    _persist();
  }
}

final gameStoreProvider = StateNotifierProvider<GameStore, GameState>((ref) {
  return GameStore(
    ref.watch(progressRepositoryProvider),
    ref.watch(configServiceProvider.future).then((c) => c.games.wordBuilder),
  );
});
