import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kids_tamil_ezhuthu_school/main.dart';

import '../../app_harness.dart';

void main() {
  testWidgets('the mei category shows all 18, marking the ones not yet authored',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    stillAnimations(tester);

    await tester.pumpWidget(const ProviderScope(child: TamilEzhuthuApp()));
    await tester.pumpAndSettle();
    await openCategory(tester, meiTitle);

    // Counted from the stroke files rather than written down, so this keeps
    // saying something true as mei letters are authored one at a time.
    final authored = Directory('lib/data/letters/strokes')
        .listSync()
        .whereType<File>()
        .where((f) => f.uri.pathSegments.last.startsWith('mei_'))
        .length;

    expect(find.text(meiTitle), findsOneWidget, reason: 'the list is titled for its category');
    // All 18 are on screen whatever their state — a child seeing four
    // letters would learn மெய் has four.
    expect(find.text('க்'), findsOneWidget);
    expect(find.text('ன்'), findsOneWidget);
    expect(find.text('விரைவில் வரும்'), authored == 0 ? findsOneWidget : findsNothing);

    // The two marks say different things: a padlock opens with stars, the
    // dots cannot be opened at all yet.
    expect(find.byIcon(Icons.more_horiz_rounded), findsNWidgets(18 - authored));
    final stars = ((jsonDecode(File('assets/config/app_config.json').readAsStringSync())
        as Map<String, dynamic>)['progression']
        as Map<String, dynamic>)['starsToUnlockNext'] as num;
    expect(find.byIcon(Icons.lock_rounded),
        findsNWidgets(stars == 0 || authored == 0 ? 0 : authored - 1));
  });
}
