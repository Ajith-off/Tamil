import 'dart:math' as math;

import '../../../core/config/models/games_config.dart';
import '../../../data/models/word_challenge.dart';

/// The rules of one round of Word Builder, with no widgets in them.
///
/// Kept separate from the screen because this is the part that can be wrong in
/// a way nobody sees: which tile a box will take next, whether the round is
/// still clean, and whether the tiles on offer can actually build the word.
class WordRound {
  final WordChallenge word;

  /// The tiles on offer, in the order they are laid out.
  final List<String> tiles;

  /// How many tiles each box has taken so far.
  final List<int> _placed;

  /// False once any tile has been dropped on the wrong box. A round is only
  /// worth a coin, an achievement and its heart back if this survives.
  bool _clean = true;

  WordRound._(this.word, this.tiles, this._placed);

  /// Builds a round, choosing distractors and shuffling.
  ///
  /// Seeded by the word so the same word always offers the same tiles in the
  /// same places: a child who comes back to a word they failed meets the board
  /// they remember, and a screenshot of it is worth comparing against.
  factory WordRound.forWord(WordChallenge word, WordBuilderConfig config) {
    final rng = math.Random(word.id.hashCode);
    final answer = word.answerTiles;
    final tiles = [...answer, ..._distractors(answer, config, rng)]..shuffle(rng);
    return WordRound._(word, tiles, List.filled(word.slots.length, 0));
  }

  /// Tiles that are *not* in the word, drawn first from the confusable group
  /// each answer tile belongs to.
  static List<String> _distractors(
    List<String> answer,
    WordBuilderConfig config,
    math.Random rng,
  ) {
    final used = answer.toSet();
    final picked = <String>{};

    // Nearest misses first — ண் against ன், ழ் against ள்.
    final wanted = [...answer]..shuffle(rng);
    for (final tile in wanted) {
      if (picked.length >= config.distractorCount) break;
      for (final group in config.confusable) {
        if (!group.contains(tile)) continue;
        final options = group.where((c) => !used.contains(c) && !picked.contains(c));
        if (options.isEmpty) continue;
        picked.add(options.elementAt(rng.nextInt(options.length)));
        break;
      }
    }

    // A short word may not have enough confusable neighbours to fill the
    // quota — ஈ has one answer tile — so the rest come from the whole pool.
    if (picked.length < config.distractorCount) {
      final rest = [
        for (final tile in config.tilePool)
          if (!used.contains(tile) && !picked.contains(tile)) tile,
      ]..shuffle(rng);
      for (final tile in rest) {
        if (picked.length >= config.distractorCount) break;
        picked.add(tile);
      }
    }
    return picked.toList();
  }

  int placedIn(int slot) => _placed[slot];

  bool get clean => _clean;

  bool get isComplete {
    for (var i = 0; i < word.slots.length; i++) {
      if (_placed[i] < word.slots[i].tiles.length) return false;
    }
    return true;
  }

  bool isSlotFull(int slot) => _placed[slot] >= word.slots[slot].tiles.length;

  /// The tile this box will take next, or null once it is full.
  String? expects(int slot) =>
      isSlotFull(slot) ? null : word.slots[slot].tiles[_placed[slot]];

  /// What the box should show right now: nothing while empty, the consonant
  /// once it is half built, the whole character once it is full.
  ///
  /// The half-built state is the point of the game — the child sees ம் sitting
  /// there and has to work out that a vowel turns it into மா.
  String? shownIn(int slot) {
    if (_placed[slot] == 0) return null;
    if (isSlotFull(slot)) return word.slots[slot].char;
    return word.slots[slot].tiles[_placed[slot] - 1];
  }

  /// What this box *would* have read had the tile been taken.
  ///
  /// Dropping அ onto a box already holding ட் makes ட, and showing the child
  /// ட with a cross through it says something a red border cannot: not "wrong
  /// place" but "that is the letter you just built, and it is not this one".
  /// Falls back to the tile itself where there is nothing to combine with.
  String previewOf(int slot, String tile, Map<String, String> vowelSigns) {
    final consonant = _placed[slot] == 1 ? word.slots[slot].tiles[0] : null;
    final sign = vowelSigns[tile];
    if (consonant == null || sign == null) return tile;
    return consonant.substring(0, consonant.length - 1) + sign;
  }

  /// Takes a tile if it belongs. A refusal marks the round no longer clean —
  /// but does not undo anything, so the word can always still be finished.
  bool drop(int slot, String tile) {
    if (expects(slot) != tile) {
      _clean = false;
      return false;
    }
    _placed[slot]++;
    return true;
  }
}
