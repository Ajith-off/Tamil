import 'dart:ui';

/// A single stroke as an ordered polyline of points, normalized to the
/// 0..1 unit square. Point order encodes the drawing direction: index 0
/// is where the stroke starts, the last index is where it ends.
class Stroke {
  final int index;
  final List<Offset> points;

  /// This stroke's own width, when it differs from the letter's tube.
  ///
  /// Only a dot carries one. A puḷḷi is 1.5x to 1.8x the letter's stroke
  /// width — 95px against 54-62px on every mei letter — so drawn at the tube
  /// width it is visibly too small. Null means "use the letter's tube width".
  final double? width;

  const Stroke({required this.index, required this.points, this.width});

  factory Stroke.fromJson(Map<String, dynamic> json) {
    final pts = (json['points'] as List<dynamic>)
        .map((p) => Offset(
              ((p as Map<String, dynamic>)['x'] as num).toDouble(),
              (p['y'] as num).toDouble(),
            ))
        .toList();
    return Stroke(
      index: (json['index'] as num).toInt(),
      points: pts,
      width: (json['width'] as num?)?.toDouble(),
    );
  }
}

/// The full reference stroke set for one letter, i.e. what a perfect
/// trace looks like.
class LetterStrokeData {
  final String letterId;
  final List<Stroke> strokes;

  /// How thick to draw this letter's guide tube, as a fraction of the
  /// canvas. The font's stroke width is fixed, but each letter is scaled to
  /// fill the canvas by its own bounding box, so a wide letter ends up with
  /// a proportionally thinner tube. Emitted per letter by
  /// tools/trace_letter.py; null falls back to the canvas config default.
  final double? tubeWidthFactor;

  const LetterStrokeData({
    required this.letterId,
    required this.strokes,
    this.tubeWidthFactor,
  });

  factory LetterStrokeData.fromJson(Map<String, dynamic> json) {
    final strokesJson = json['strokes'] as List<dynamic>;
    return LetterStrokeData(
      letterId: json['letterId'] as String,
      strokes: strokesJson.map((s) => Stroke.fromJson(s as Map<String, dynamic>)).toList(),
      tubeWidthFactor: (json['tubeWidthFactor'] as num?)?.toDouble(),
    );
  }
}
