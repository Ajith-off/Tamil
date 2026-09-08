import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kids_tamil_ezhuthu_school/core/config/models/app_config.dart';
import 'package:kids_tamil_ezhuthu_school/core/config/models/games_config.dart';
import 'package:kids_tamil_ezhuthu_school/core/config/models/scoring_config.dart';
import 'package:kids_tamil_ezhuthu_school/data/repos/progress_repository.dart';
import 'package:kids_tamil_ezhuthu_school/features/games/game_providers.dart';
import 'package:kids_tamil_ezhuthu_school/features/letter/letter_providers.dart';

Map<String, dynamic> _json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

final _wb = GamesConfig.fromJson(_json('assets/config/games_config.json')).wordBuilder;
final _app = AppConfig.fromJson(_json('assets/config/app_config.json'));
final _thresholds =
    ScoringConfig.fromJson(_json('assets/config/scoring_config.json')).starThresholds;

Future<GameStore> _store(ProgressRepository repository) async {
  final store = GameStore(repository, Future.value(_wb));
  addTearDown(store.dispose);
  // Two microtask turns: the config future, then the file read.
  await Future<void>.delayed(Duration.zero);
  return store;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a new player starts with the configured hearts', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await _store(ProgressRepository());

    expect(store.state.hearts, _wb.startingHearts);
    expect(store.canOpen, isTrue);
  });

  test('opening spends a heart and a clean round gives it back', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await _store(ProgressRepository());

    expect(store.openWord(), isTrue);
    expect(store.state.hearts, _wb.startingHearts - 1);

    // CLAUDE.md section 7: playing well costs nothing.
    store.finishedCleanly('word_01');
    expect(store.state.hearts, _wb.startingHearts);
  });

  test('a fumbled round keeps the heart spent', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await _store(ProgressRepository());

    store.openWord();
    // Nothing is called on a round that was not clean.
    expect(store.state.hearts, _wb.startingHearts - 1);
  });

  test('hearts are refused rather than going negative', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await _store(ProgressRepository());

    for (var i = 0; i < _wb.startingHearts; i++) {
      expect(store.openWord(), isTrue);
    }
    expect(store.state.hearts, 0);
    expect(store.canOpen, isFalse);
    expect(store.openWord(), isFalse, reason: 'refused before it is charged for');
    expect(store.state.hearts, 0);
  });

  test('a coin buys back a full set of hearts', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await _store(ProgressRepository());

    while (store.canOpen) {
      store.openWord();
    }
    store.addHeartsForCoin();
    expect(store.state.hearts, _wb.heartsPerCoin);
  });

  group('the achievement', () {
    test('is granted the first clean clear only', () async {
      SharedPreferences.setMockInitialValues({});
      final store = await _store(ProgressRepository());

      expect(store.finishedCleanly('word_03'), isTrue, reason: 'new achievement');
      expect(store.state.achievements, 1);
      expect(store.finishedCleanly('word_03'), isFalse, reason: 'already held');
      expect(store.state.achievements, 1, reason: 'replaying must not mint a second');
    });

    test('pays exactly one coin per word, however often it is replayed', () async {
      SharedPreferences.setMockInitialValues({});
      final store = await _store(ProgressRepository());

      int balance() => coinBalance(
            progress: const {},
            thresholds: _thresholds,
            coins: _app.coins,
            spent: 0,
            cleanWords: store.state.cleanWords.length,
            coinsPerCleanWord: _wb.coinsPerCleanWord,
          );

      final before = balance();
      store.finishedCleanly('word_03');
      expect(balance(), before + _wb.coinsPerCleanWord);
      // The balance counts cleared words rather than banking an event, so
      // there is nothing to replay.
      store.finishedCleanly('word_03');
      store.finishedCleanly('word_03');
      expect(balance(), before + _wb.coinsPerCleanWord);
    });
  });

  test('hearts and achievements survive a restart', () async {
    SharedPreferences.setMockInitialValues({});
    final first = await _store(ProgressRepository());
    first.openWord();
    first.finishedCleanly('word_05');
    first.openWord();
    await Future<void>.delayed(Duration.zero);

    final second = await _store(ProgressRepository());

    expect(second.state.hearts, _wb.startingHearts - 1);
    expect(second.state.cleanWords, {'word_05'});
  });

  test('a saved file already holding letters keeps them when hearts change',
      () async {
    // Marks and hearts share one document. Writing one half must never drop
    // the other — the same failure progress_persistence_test.dart guards.
    SharedPreferences.setMockInitialValues({});
    final repository = ProgressRepository();
    await repository.saveCoinsSpent(4);

    final store = await _store(repository);
    store.openWord();
    await Future<void>.delayed(Duration.zero);

    final prefs = await SharedPreferences.getInstance();
    final back =
        ProgressRepository.decode(prefs.getString(ProgressRepository.storageKey)!);
    expect(back.coinsSpent, 4, reason: 'the heart write must not drop spending');
    expect(back.hearts, _wb.startingHearts - 1);
  });
}
