import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_tamil_ezhuthu_school/core/config/models/trace_config.dart';
import 'package:kids_tamil_ezhuthu_school/core/config/models/trace_mode.dart';

/// Guards the shape of the mode ladder itself, straight from the shipped
/// config, so a stray edit cannot silently strand a child in one mode.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TraceConfig config;

  setUpAll(() async {
    final raw = await rootBundle.loadString('assets/config/trace_config.json');
    config = TraceConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  });

  test('every mode is defined and they run easiest to hardest', () {
    expect(TraceMode.values, [
      TraceMode.easy,
      TraceMode.medium,
      TraceMode.hard,
      TraceMode.special,
    ]);
    for (final mode in TraceMode.values) {
      expect(config.modes.containsKey(mode), isTrue, reason: 'missing config for $mode');
    }
  });

  test('each mode leads to the next, and challenge is the last', () {
    expect(TraceMode.easy.next, TraceMode.medium);
    expect(TraceMode.medium.next, TraceMode.hard);
    expect(TraceMode.hard.next, TraceMode.special);
    expect(TraceMode.special.next, isNull);
  });

  test('help falls away as the modes get harder', () {
    final easy = config.definitionFor(TraceMode.easy);
    final medium = config.definitionFor(TraceMode.medium);
    final hard = config.definitionFor(TraceMode.hard);
    final special = config.definitionFor(TraceMode.special);

    // Easy shows the letter and leads the child along it, one waypoint at a
    // time. The full dot trail is gone — the waypoint replaced it.
    expect([easy.showWaypoints, easy.showTube, easy.showDots], [true, true, false]);
    // Medium keeps the letter but stops leading.
    expect([medium.showWaypoints, medium.showTube], [false, true],
        reason: 'the waypoint goes first, the letter stays');
    expect([hard.showTube, hard.showDots], [false, false], reason: 'then the letter itself');
    expect([special.showTube, special.showDots], [false, false]);
  });

  test('only challenge outlines the page, because it draws nothing else', () {
    for (final mode in TraceMode.values) {
      expect(
        config.definitionFor(mode).showFrame,
        mode == TraceMode.special,
        reason: '$mode showFrame',
      );
    }
  });

  test('only easy is led by waypoints', () {
    for (final mode in TraceMode.values) {
      expect(
        config.definitionFor(mode).showWaypoints,
        mode == TraceMode.easy,
        reason: '$mode showWaypoints',
      );
    }
  });

  test('hard still gets the demo, because otherwise nothing shows the way', () {
    // Hard hides the letter, so the animated demo is the only thing telling
    // the child which direction to write in.
    expect(config.definitionFor(TraceMode.hard).showTutorial, isTrue);
    expect(config.definitionFor(TraceMode.hard).freeDraw, isFalse);
  });

  test('only challenge is freehand, and it gets no demo', () {
    for (final mode in TraceMode.values) {
      expect(
        config.definitionFor(mode).freeDraw,
        mode == TraceMode.special,
        reason: '$mode freeDraw',
      );
    }
    expect(config.definitionFor(TraceMode.special).showTutorial, isFalse);
  });

  test('advancing takes more than a single lucky attempt', () {
    expect(config.advanceAfterSuccesses, greaterThanOrEqualTo(2));
  });
}
