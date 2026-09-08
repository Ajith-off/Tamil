import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_tamil_ezhuthu_school/data/models/stroke.dart';
import 'package:kids_tamil_ezhuthu_school/features/letter/canvas/letter_canvas.dart';
import 'package:kids_tamil_ezhuthu_school/features/letter/trace/letter_paths.dart';

/// Drives the tracing canvas the way a finger would, along a letter's real
/// stroke data — so what is being tested is the shape the app actually ships
/// rather than a synthetic stand-in.
Future<LetterPaths> traceWholeLetter(
  WidgetTester tester, {
  String letterId = 'uyir_01',
}) async {
  final raw = await rootBundle.loadString('lib/data/letters/strokes/$letterId.json');
  final strokeData = LetterStrokeData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  final paths = LetterPaths.fromStrokes(strokeData.strokes);

  final canvasRect = tester.getRect(find.byType(LetterCanvas));
  final side = math.min(canvasRect.width, canvasRect.height);
  final origin = Offset(
    canvasRect.left + (canvasRect.width - side) / 2,
    canvasRect.top + (canvasRect.height - side) / 2,
  );
  Offset toScreen(Offset normalized) => origin + normalized * side;

  // Many small steps, not a jump: the trace only advances while the finger
  // stays near the path and never lets it skip ahead.
  for (var s = 0; s < paths.strokeCount; s++) {
    final length = paths.lengthOf(s);
    final step = length / 120;
    final gesture = await tester.startGesture(toScreen(paths.pointAt(s, 0)!));
    for (var d = 0.0; d <= length; d += step) {
      final p = paths.pointAt(s, d);
      if (p != null) await gesture.moveTo(toScreen(p));
    }
    await gesture.up();
    await tester.pump();
  }
  await tester.pumpAndSettle();
  return paths;
}
