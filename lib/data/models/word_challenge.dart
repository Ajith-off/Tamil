/// One box of a word, and the tiles that fill it.
///
/// A consonant-vowel box always takes two tiles — ம் then ஆ for மா, ம் then அ
/// for ம — because the tile pool is only the 31 base characters and nothing
/// composed is ever handed over ready-made (CLAUDE.md section 8).
class WordSlot {
  /// The character shown as a shadow inside the empty box, and solid once the
  /// box is full.
  final String char;

  /// In the order they go down. Consonant first, then vowel.
  final List<String> tiles;

  const WordSlot({required this.char, required this.tiles});

  bool get isComposed => tiles.length > 1;

  factory WordSlot.fromJson(Map<String, dynamic> json) => WordSlot(
        char: json['char'] as String,
        tiles: (json['tiles'] as List<dynamic>).cast<String>(),
      );
}

/// A picture and the word that names it.
class WordChallenge {
  final String id;
  final int order;
  final String tamil;
  final String english;
  final String image;
  final List<WordSlot> slots;

  const WordChallenge({
    required this.id,
    required this.order,
    required this.tamil,
    required this.english,
    required this.image,
    required this.slots,
  });

  /// Every tile the word needs, with repeats — கை needs க் twice over a word
  /// like குகை, and offering it once would leave the second box unfillable.
  List<String> get answerTiles => [for (final slot in slots) ...slot.tiles];

  factory WordChallenge.fromJson(Map<String, dynamic> json) => WordChallenge(
        id: json['id'] as String,
        order: (json['order'] as num).toInt(),
        tamil: json['tamil'] as String,
        english: json['english'] as String,
        image: json['image'] as String,
        slots: [
          for (final slot in (json['slots'] as List<dynamic>))
            WordSlot.fromJson(slot as Map<String, dynamic>),
        ],
      );
}
