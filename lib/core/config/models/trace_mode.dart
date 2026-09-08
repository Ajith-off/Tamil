/// How much help the child gets, and whether they are guided at all.
///
/// Order matters: it is the display order, easiest first, and matches the
/// ordering used throughout `assets/config/*.json`.
enum TraceMode {
  /// Letter tube plus the dot trail showing exactly where to drag.
  easy,

  /// Letter tube only — the child has to find the path along it.
  medium,

  /// Blank canvas, but the finger is still guided along the hidden path,
  /// so the letter fills in correctly as they write it from memory.
  hard,

  /// A blank canvas with no guidance at all. The child draws the letter
  /// freehand, however they like, and only when they submit is the shape
  /// compared against the reference. This is the "real exam" mode.
  special;

  static TraceMode fromId(String id) {
    return TraceMode.values.firstWhere(
      (m) => m.id == id,
      orElse: () => throw ArgumentError('Unknown trace mode id: $id'),
    );
  }

  String get id => name;

  /// The next mode up, or null if this is already the last one.
  TraceMode? get next {
    final i = index + 1;
    return i < TraceMode.values.length ? TraceMode.values[i] : null;
  }
}
