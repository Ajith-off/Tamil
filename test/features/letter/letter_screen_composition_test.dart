import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kids_tamil_ezhuthu_school/features/letter/canvas/letter_canvas.dart';
import 'package:kids_tamil_ezhuthu_school/main.dart';

import '../../app_harness.dart';

void main() {
  testWidgets('a uyirmei letter shows the consonant + vowel it composes from',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    stillAnimations(tester);

    await tester.pumpWidget(const ProviderScope(child: TamilEzhuthuApp()));
    await tester.pumpAndSettle();
    await openCategory(tester, 'உயிர்மெய் எழுத்து');

    // க வரிசை is the first row — its tile shows க கா கி.
    await tester.tap(find.textContaining('க கா கி'));
    await tester.pumpAndSettle();

    // கா is the second letter of the row: அ then ஆ.
    await tester.tap(find.text('கா'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 6));

    expect(find.byType(LetterCanvas), findsOneWidget);
    expect(find.text('க் + ஆ = கா'), findsOneWidget);
  });
}
