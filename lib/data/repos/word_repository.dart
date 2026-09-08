import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/word_challenge.dart';

/// The Word Builder roster, written by `tools/gen_word_builder.py`.
class WordRepository {
  const WordRepository();

  static const _path = 'lib/data/games/word_builder.json';

  /// Every word, easiest first — fewest boxes, then fewest tiles.
  Future<List<WordChallenge>> load() async {
    final raw = await rootBundle.loadString(_path);
    return (jsonDecode(raw) as List<dynamic>)
        .map((e) => WordChallenge.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
  }
}

final wordRepositoryProvider = Provider<WordRepository>((ref) => const WordRepository());

final wordsProvider = FutureProvider<List<WordChallenge>>((ref) {
  return ref.watch(wordRepositoryProvider).load();
});
