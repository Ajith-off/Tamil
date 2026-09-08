import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kids_tamil_ezhuthu_school/features/letters/reward_icons.dart';
import 'package:kids_tamil_ezhuthu_school/main.dart';

import '../../app_harness.dart';
import 'trace_harness.dart';

/// End-to-end check that a child dragging along the real அ stroke data
/// actually finishes the letter and gets scored.
void main() {
  testWidgets('dragging along the real அ path completes it and awards stars', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    stillAnimations(tester);

    await tester.pumpWidget(const ProviderScope(child: TamilEzhuthuApp()));
    await tester.pumpAndSettle();
    await openCategory(tester, uyirTitle);
    await tester.tap(find.text('அ'));
    await tester.pumpAndSettle();

    final paths = await traceWholeLetter(tester);
    expect(paths.strokeCount, 2, reason: 'அ is a loop+bowl body plus a vertical bar');

    // Finishing shows the score strip with a star row.
    expect(find.textContaining('மதிப்பெண்'), findsOneWidget);
    expect(find.byType(MagicPenStar), findsNWidgets(3),
        reason: 'the three-mark rating row is drawn with the shared reward mark');
  });
}
