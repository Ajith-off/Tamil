import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kids_tamil_ezhuthu_school/features/letter/canvas/letter_canvas.dart';
import 'package:kids_tamil_ezhuthu_school/main.dart';

import '../../app_harness.dart';

/// What each mode asks the canvas for, checked on the real screen.
///
/// The mode config and the painter can both be perfectly correct while the
/// screen quietly fails to pass one to the other — which is exactly what
/// happened: easy was configured for waypoints, the painter could draw them,
/// and the screen never said so, leaving a blank canvas that felt like the
/// hardest mode. Config tests and painter tests both passed throughout.
void main() {
  testWidgets('easy asks for waypoints and nothing else; challenge asks for the frame',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    stillAnimations(tester);

    await tester.pumpWidget(const ProviderScope(child: TamilEzhuthuApp()));
    await tester.pumpAndSettle();
    await openCategory(tester, uyirTitle);
    await tester.tap(find.text('அ'));
    // Settles once the demo has played out, which is when the guidance for
    // the child — rather than for the demo's own pen — is what is on screen.
    await tester.pumpAndSettle();

    LetterCanvas canvas() => tester.widget<LetterCanvas>(find.byType(LetterCanvas));

    expect(canvas().showWaypoints, isTrue, reason: 'easy is led by waypoints');
    expect(canvas().showTube, isTrue, reason: 'easy shows the letter to trace');
    expect(canvas().showDots, isFalse, reason: 'the waypoint replaced the dot trail');
    expect(canvas().showFrame, isFalse);

    await tester.tap(find.text('சவால்'));
    await tester.pump();

    // Challenge flashes the tube briefly before drawing starts (see
    // TraceModeDefinition.previewDurationMs) — advance past that first,
    // rather than asserting mid-flash.
    expect(canvas().showTube, isTrue, reason: 'the pre-attempt flash shows the letter');
    await tester.pump(const Duration(milliseconds: 1100));

    expect(canvas().showFrame, isTrue, reason: 'challenge outlines the blank page');
    expect(canvas().showWaypoints, isFalse, reason: 'challenge guides nothing');
    expect(canvas().showTube, isFalse, reason: 'the flash is over; drawing is freehand');
  });
}
