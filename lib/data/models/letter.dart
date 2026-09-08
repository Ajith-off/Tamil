/// Top-level character categories (see CLAUDE.md section 2).
enum LetterCategory {
  uyir,
  aaytham,
  mei,
  uyirmei,

  /// The grantha letters ஜ ஷ ஸ ஹ க்ஷ ஸ்ரீ, which write sounds Tamil borrowed
  /// rather than sounds it owns. Outside the 247 by definition, and taught
  /// after them.
  vadamozhi;

  static LetterCategory fromId(String id) {
    return LetterCategory.values.firstWhere(
      (c) => c.name == id,
      orElse: () => throw ArgumentError('Unknown letter category id: $id'),
    );
  }
}

/// One catalogue file under `lib/data/letters/`, which is also one screenful
/// of the letter list.
///
/// Deliberately not the same thing as [LetterCategory]: ஃ is its own category
/// but ships inside the uyir catalogue, because it is shown as a bonus level
/// at the end of the vowels rather than a section of its own (CLAUDE.md
/// section 2).
enum LetterCatalogue {
  uyir('uyir.json'),
  mei('mei.json'),

  /// 216 characters, so never one screenful: they are navigated as 18
  /// consonant groups of 12 (CLAUDE.md section 2, "never render 216 nodes on
  /// one screen"). One file all the same — the split is [Letter.group].
  uyirmei('uyirmei.json'),

  /// The six grantha letters. Deliberately last: they are not part of the 247,
  /// and nothing about them changes any of it.
  vadamozhi('vadamozhi.json');

  final String fileName;

  const LetterCatalogue(this.fileName);

  bool get isGrouped => this == LetterCatalogue.uyirmei;

  /// Whether this catalogue is part of the 247.
  ///
  /// Grantha is not: those letters write sounds Tamil borrowed rather than
  /// sounds it owns (CLAUDE.md section 2). The home screen counts the 247 off
  /// this rather than off a number typed into it, so adding a catalogue beyond
  /// them cannot quietly change what the app claims to teach.
  bool get isPartOf247 => this != LetterCatalogue.vadamozhi;
}

/// Metadata for one of the 247 characters. Loaded from
/// `lib/data/letters/{category}.json`.
class Letter {
  final String id;
  final LetterCategory category;
  final int order;
  final String tamil;
  final String transliteration;

  /// Null where nobody has written one yet — all 216 uyirmei. There is no
  /// honest way to invent that many, and a wrong example teaches a wrong
  /// word, so the letter screen omits the panel rather than filling it in.
  final String? exampleWordTamil;
  final String? exampleWordTransliteration;

  /// Which sub-group this letter belongs to, for a catalogue too big to show
  /// at once. Null for uyir and mei, which are one screenful each.
  final String? group;

  /// The consonant a uyirmei group is named after — க for the க row.
  final String? groupTamil;

  /// Id of the stroke-data file for this letter, under
  /// `lib/data/letters/strokes/`.
  final String strokeDataId;

  const Letter({
    required this.id,
    required this.category,
    required this.order,
    required this.tamil,
    required this.transliteration,
    this.exampleWordTamil,
    this.exampleWordTransliteration,
    this.group,
    this.groupTamil,
    required this.strokeDataId,
  });

  bool get hasExampleWord => exampleWordTamil != null;

  factory Letter.fromJson(Map<String, dynamic> json) {
    return Letter(
      id: json['id'] as String,
      category: LetterCategory.fromId(json['category'] as String),
      order: (json['order'] as num).toInt(),
      tamil: json['tamil'] as String,
      transliteration: json['transliteration'] as String,
      exampleWordTamil: json['exampleWordTamil'] as String?,
      exampleWordTransliteration: json['exampleWordTransliteration'] as String?,
      group: json['group'] as String?,
      groupTamil: json['groupTamil'] as String?,
      strokeDataId: json['strokeDataId'] as String,
    );
  }
}
