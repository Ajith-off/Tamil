import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/models/trace_mode.dart';
import '../models/score.dart';

/// Everything the child has earned, kept between runs.
///
/// One JSON document under one key, written whole on every change. That is
/// the right shape for this data rather than a database: it is a few hundred
/// small records, it is read once at launch and never queried, and the whole
/// thing is smaller than a single letter's stroke file. CLAUDE.md section 10
/// names Hive or Isar; both earn their keep on partial updates and queries at
/// scale, and there are none here.
///
/// Local only, no cloud, no login, no identifier of any kind — the file holds
/// letter ids and marks and nothing else (CLAUDE.md section 1).
class SavedProgress {
  final Map<String, LetterProgress> letters;
  final int coinsSpent;

  /// Coins earned by watching a rewarded ad in the Parent Zone
  /// (CLAUDE.md section 7). Kept separate from the derived balance in
  /// [coinBalance] because watching an ad is an event, not a progress fact —
  /// there is nothing about it to recount later, so like [coinsSpent] it has
  /// to be a stored, only-ever-growing counter.
  final int coinsFromAds;

  /// Hearts left. Null means nothing has been saved yet, so the store starts
  /// from the configured allowance rather than from zero — a child whose file
  /// has never been written must not open the app with nothing to play.
  final int? hearts;

  /// Words cleared without a single wrong drop. This is the achievement, and
  /// it is also where the coins those rounds paid are derived from: a word in
  /// this set pays exactly once however often it is replayed, which is the
  /// same trick three-star letters use.
  final Set<String> cleanWords;

  const SavedProgress({
    this.letters = const {},
    this.coinsSpent = 0,
    this.coinsFromAds = 0,
    this.hearts,
    this.cleanWords = const {},
  });

  static const empty = SavedProgress();
}

class ProgressRepository {
  ProgressRepository();

  /// Versioned so a later change of shape can migrate rather than guess.
  static const storageKey = 'progress.v1';

  /// The document as last read or written. Marks and coins live in one file
  /// but are owned by two different notifiers, so each has to be able to
  /// rewrite its own half without knowing the other's — this is what holds
  /// the other half while it does.
  SavedProgress _last = SavedProgress.empty;
  Future<SavedProgress>? _loaded;

  /// Reads once and remembers. Both callers race to do this at launch and
  /// must not each get their own answer.
  Future<SavedProgress> load() => _loaded ??= _read();

  Future<SavedProgress> _read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(storageKey);
      _last = (raw == null || raw.isEmpty) ? SavedProgress.empty : decode(raw);
    } catch (_) {
      // A child whose file cannot be read still gets to play. Losing a
      // session's stars is bad; refusing to open the app is worse.
      _last = SavedProgress.empty;
    }
    return _last;
  }

  Future<void> saveLetters(Map<String, LetterProgress> letters) =>
      _write((prev) => SavedProgress(
            letters: letters,
            coinsSpent: prev.coinsSpent,
            coinsFromAds: prev.coinsFromAds,
            hearts: prev.hearts,
            cleanWords: prev.cleanWords,
          ));

  Future<void> saveCoinsSpent(int spent) => _write((prev) => SavedProgress(
        letters: prev.letters,
        coinsSpent: spent,
        coinsFromAds: prev.coinsFromAds,
        hearts: prev.hearts,
        cleanWords: prev.cleanWords,
      ));

  Future<void> saveCoinsFromAds(int earned) => _write((prev) => SavedProgress(
        letters: prev.letters,
        coinsSpent: prev.coinsSpent,
        coinsFromAds: earned,
        hearts: prev.hearts,
        cleanWords: prev.cleanWords,
      ));

  Future<void> saveGame({required int hearts, required Set<String> cleanWords}) =>
      _write((prev) => SavedProgress(
            letters: prev.letters,
            coinsSpent: prev.coinsSpent,
            coinsFromAds: prev.coinsFromAds,
            hearts: hearts,
            cleanWords: cleanWords,
          ));

  /// Each half is replaced against whatever the *other* half is by then.
  ///
  /// The await matters: without it, a save that lands before the read has
  /// finished writes its own half beside an empty one — which is exactly how
  /// a child who spent a coin during launch would lose every star they had.
  Future<void> _write(SavedProgress Function(SavedProgress) update) async {
    await load();
    _last = update(_last);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(storageKey, encode(_last));
    } catch (_) {
      // A failed write must never interrupt play.
    }
  }

  /// Kept separate from [load] and [save] so the format can be tested without
  /// a platform channel — the part that can silently corrupt a child's
  /// progress is the encoding, not the plugin.
  static String encode(SavedProgress progress) => jsonEncode({
        'coinsSpent': progress.coinsSpent,
        'coinsFromAds': progress.coinsFromAds,
        if (progress.hearts != null) 'hearts': progress.hearts,
        'cleanWords': progress.cleanWords.toList()..sort(),
        'letters': {
          for (final entry in progress.letters.entries)
            if (entry.value.marksByMode.isNotEmpty)
              entry.key: {
                for (final mark in entry.value.marksByMode.entries)
                  mark.key.id: mark.value,
              },
        },
      });

  static SavedProgress decode(String raw) {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final letters = <String, LetterProgress>{};
    final saved = (json['letters'] as Map<String, dynamic>?) ?? const {};
    for (final entry in saved.entries) {
      final marks = <TraceMode, int>{};
      for (final mark in (entry.value as Map<String, dynamic>).entries) {
        // An unknown mode is skipped rather than thrown on: renaming one
        // should cost a child that mode's marks, not their whole file.
        final mode = TraceMode.values.where((m) => m.id == mark.key).firstOrNull;
        if (mode != null) marks[mode] = (mark.value as num).toInt();
      }
      letters[entry.key] = LetterProgress(letterId: entry.key, marksByMode: marks);
    }
    return SavedProgress(
      letters: letters,
      coinsSpent: ((json['coinsSpent'] as num?) ?? 0).toInt(),
      coinsFromAds: ((json['coinsFromAds'] as num?) ?? 0).toInt(),
      hearts: (json['hearts'] as num?)?.toInt(),
      cleanWords: ((json['cleanWords'] as List<dynamic>?) ?? const [])
          .cast<String>()
          .toSet(),
    );
  }
}

/// One instance, because it holds the document both notifiers write through.
final progressRepositoryProvider = Provider<ProgressRepository>((ref) => ProgressRepository());
