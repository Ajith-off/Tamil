import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kids_tamil_ezhuthu_school/features/letter/canvas/letter_canvas.dart';
import 'package:kids_tamil_ezhuthu_school/main.dart';

import '../../app_harness.dart';

void main() {
  testWidgets('tapping an open letter opens its tracing screen', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    stillAnimations(tester);

    await tester.pumpWidget(const ProviderScope(child: TamilEzhuthuApp()));
    await tester.pumpAndSettle();
    await openCategory(tester, uyirTitle);

    await tester.tap(find.text('அ'));
    // The demo animation plays on arrival, so pump past it rather than
    // waiting for the tree to go completely idle.
    await tester.pump();
    await tester.pump(const Duration(seconds: 6));

    expect(find.byType(LetterCanvas), findsOneWidget);
    expect(find.text('அம்மா'), findsOneWidget, reason: 'the letter panel shows its example word');
    expect(find.text('எளிது'), findsOneWidget, reason: 'mode buttons are available');
  });
}
