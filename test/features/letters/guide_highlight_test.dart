import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kids_tamil_ezhuthu_school/features/common/guide_highlight.dart';
import 'package:kids_tamil_ezhuthu_school/main.dart';

import '../../app_harness.dart';

void main() {
  test('nothing is locked from the start', () {
    // The guide ring replaces the padlock: a child is shown where to go rather
    // than stopped from going elsewhere (CLAUDE.md section 6).
    final app = jsonDecode(File('assets/config/app_config.json').readAsStringSync())
        as Map<String, dynamic>;
    expect((app['progression'] as Map<String, dynamic>)['starsToUnlockNext'], 0);
  });

  test('a child starts with thirteen coins', () {
    final app = jsonDecode(File('assets/config/app_config.json').readAsStringSync())
        as Map<String, dynamic>;
    final coins = app['coins'] as Map<String, dynamic>;
    final games = jsonDecode(File('assets/config/games_config.json').readAsStringSync())
        as Map<String, dynamic>;
    final wb = games['wordBuilder'] as Map<String, dynamic>;

    expect(coins['startingBalance'], 13);
    // Worth knowing what that buys: 13 coins x 3 hearts, and a clean round
    // hands its heart back, so this only ever runs down on rounds that went
    // wrong.
    expect((coins['startingBalance'] as int) * (wb['heartsPerCoin'] as int), 39);
  });

  // The only booting test in this file — asset futures do not resolve for a
  // second boot in the same file (see widget_test.dart).
  testWidgets('exactly one thing on the home screen is marked as next',
      (tester) async {
    tester.view.physicalSize = const Size(892, 412);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    stillAnimations(tester);

    await tester.pumpWidget(const ProviderScope(child: TamilEzhuthuApp()));
    await tester.pumpAndSettle();

    // Two rings would be a choice, which is the thing the ring exists to
    // remove. On a fresh install it is the first category, since nothing has
    // been finished.
    final active = tester
        .widgetList<GuideHighlight>(find.byType(GuideHighlight))
        .where((g) => g.active);
    expect(active, hasLength(1), reason: 'exactly one guide, or none is guidance');

    // It is the first tile: uyir, which no child has finished on a first run.
    final tiles = find.byType(GuideHighlight);
    final guidedIndex = tester
        .widgetList<GuideHighlight>(tiles)
        .toList()
        .indexWhere((g) => g.active);
    expect(guidedIndex, 0, reason: 'the ring starts on the first unfinished set');
  });
}
