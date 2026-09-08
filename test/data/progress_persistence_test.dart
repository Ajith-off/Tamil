import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kids_tamil_ezhuthu_school/core/config/models/trace_mode.dart';
import 'package:kids_tamil_ezhuthu_school/data/models/score.dart';
import 'package:kids_tamil_ezhuthu_school/data/repos/progress_repository.dart';
import 'package:kids_tamil_ezhuthu_school/features/letter/letter_providers.dart';

/// SharedPreferences namespaces every key it stores.
const _key = 'flutter.${ProgressRepository.storageKey}';

LetterProgress _progress(String id, Map<TraceMode, int> marks) =>
    LetterProgress(letterId: id, marksByMode: marks);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the saved document', () {
    test('round-trips marks and spending', () {
      const saved = SavedProgress(coinsSpent: 7);
      final full = SavedProgress(
        letters: {
          'uyir_01': _progress('uyir_01', {TraceMode.easy: 25, TraceMode.hard: 30}),
          'mei_04': _progress('mei_04', {TraceMode.special: 18}),
        },
        coinsSpent: saved.coinsSpent,
      );

      final back = ProgressRepository.decode(ProgressRepository.encode(full));

      expect(back.coinsSpent, 7);
      expect(back.letters.keys.toSet(), {'uyir_01', 'mei_04'});
      expect(back.letters['uyir_01']!.marksFor(TraceMode.easy), 25);
      expect(back.letters['uyir_01']!.marksFor(TraceMode.hard), 30);
      expect(back.letters['uyir_01']!.totalMarks, 55);
      expect(back.letters['mei_04']!.marksFor(TraceMode.special), 18);
    });

    test('a letter with nothing earned is not written at all', () {
      // 253 characters and a child has touched four of them. Writing an empty
      // record for every one would be most of the file.
      final encoded = ProgressRepository.encode(SavedProgress(
        letters: {
          'uyir_01': _progress('uyir_01', {TraceMode.easy: 25}),
          'uyir_02': _progress('uyir_02', const {}),
        },
      ));
      expect((jsonDecode(encoded) as Map)['letters'], hasLength(1));
    });

    test('an unknown mode costs that mode, not the whole file', () {
      // Renaming a TraceMode should not wipe a child's progress.
      final raw = jsonEncode({
        'coinsSpent': 2,
        'letters': {
          'uyir_01': {'easy': 25, 'someModeThatWentAway': 99},
        },
      });

      final back = ProgressRepository.decode(raw);

      expect(back.coinsSpent, 2);
      expect(back.letters['uyir_01']!.marksFor(TraceMode.easy), 25);
      expect(back.letters['uyir_01']!.totalMarks, 25);
    });
  });

  group('reading and writing', () {
    test('what was saved comes back on the next run', () async {
      SharedPreferences.setMockInitialValues({
        _key: ProgressRepository.encode(SavedProgress(
          letters: {'uyir_03': _progress('uyir_03', {TraceMode.medium: 25})},
          coinsSpent: 4,
        )),
      });

      final store = ProgressStore(ProgressRepository());
      addTearDown(store.dispose);
      await Future<void>.delayed(Duration.zero);

      expect(store.progressFor('uyir_03').marksFor(TraceMode.medium), 25);
    });

    test('a corrupt file opens the app empty rather than not at all', () async {
      SharedPreferences.setMockInitialValues({_key: 'not json'});

      final saved = await ProgressRepository().load();

      expect(saved.letters, isEmpty);
      expect(saved.coinsSpent, 0);
    });

    test('spending during launch does not wipe what was already earned', () async {
      // The failure this guards: marks and coins share one document but two
      // notifiers, so a coin spent before the read finishes could write its
      // own half beside an empty one — and take every star with it.
      SharedPreferences.setMockInitialValues({
        _key: ProgressRepository.encode(SavedProgress(
          letters: {'uyir_01': _progress('uyir_01', {TraceMode.easy: 25})},
        )),
      });

      final repository = ProgressRepository();
      final purse = CoinPurse(repository);
      addTearDown(purse.dispose);
      purse.spend(3); // deliberately not awaiting the load first
      await Future<void>.delayed(Duration.zero);

      final prefs = await SharedPreferences.getInstance();
      final back = ProgressRepository.decode(
          prefs.getString(ProgressRepository.storageKey)!);

      expect(back.letters['uyir_01']!.marksFor(TraceMode.easy), 25,
          reason: 'the coin write must not have dropped the letters');
      expect(back.coinsSpent, 3);
    });

    test('a recorded attempt reaches the file', () async {
      SharedPreferences.setMockInitialValues({});

      final repository = ProgressRepository();
      final store = ProgressStore(repository);
      addTearDown(store.dispose);
      store.record('mei_01', const AttemptResult(
        mode: TraceMode.easy,
        marks: 25,
        maxMarks: 25,
      ));
      await Future<void>.delayed(Duration.zero);

      final prefs = await SharedPreferences.getInstance();
      final back = ProgressRepository.decode(
          prefs.getString(ProgressRepository.storageKey)!);

      expect(back.letters['mei_01']!.marksFor(TraceMode.easy), 25);
    });
  });
}
