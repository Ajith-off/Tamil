import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kids_tamil_ezhuthu_school/core/config/models/trace_mode.dart';
import 'package:kids_tamil_ezhuthu_school/data/models/score.dart';
import 'package:kids_tamil_ezhuthu_school/features/letter/letter_providers.dart';
import 'package:kids_tamil_ezhuthu_school/main.dart';

import '../../app_harness.dart';
import 'trace_harness.dart';

/// Coming back to a letter used to wipe its tally: the screen built its own
/// empty [LetterProgress] in initState and counted only what happened during
/// that visit, so finishing easy and medium (50) and then returning and
/// tracing once showed 25 out of 100 and no star.
void main() {
  testWidgets('a letter re-opened counts what it earned before', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Stand in for an earlier visit that finished the medium mode.
    container.read(progressStoreProvider.notifier).record(
          'uyir_01',
          const AttemptResult(mode: TraceMode.medium, marks: 25, maxMarks: 25),
        );

    stillAnimations(tester);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const TamilEzhuthuApp()),
    );
    await tester.pumpAndSettle();
    await openCategory(tester, uyirTitle);
    await tester.tap(find.text('அ'));
    await tester.pumpAndSettle();

    await traceWholeLetter(tester);

    // 25 carried over plus 25 just earned — not the 25 the screen used to
    // show, having forgotten the earlier visit entirely.
    expect(find.textContaining('50/100'), findsOneWidget);
    expect(container.read(progressStoreProvider)['uyir_01']!.totalMarks, 50);
  });
}
