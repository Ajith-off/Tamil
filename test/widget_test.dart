import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kids_tamil_ezhuthu_school/main.dart';

import 'app_harness.dart';

// Only one test per file boots the app: asset-loading futures do not resolve
// for a second boot inside the same file, and Flutter isolates files rather
// than individual tests.
void main() {
  testWidgets('opens the uyir list, locking letters as the config says', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    stillAnimations(tester);

    await tester.pumpWidget(const ProviderScope(child: TamilEzhuthuApp()));
    await tester.pumpAndSettle();
    await openCategory(tester, uyirTitle);

    // Counted from the data rather than hard-coded, so authoring another
    // letter does not break the test. Read synchronously: a testWidgets body
    // runs under fake async, where a real dart:io future never completes and
    // the test simply hangs until it is killed.
    final letters = jsonDecode(File('lib/data/letters/uyir.json').readAsStringSync())
        as List<dynamic>;
    // Progression is a config knob, and it is currently turned off so the
    // whole set can be play-tested. Read it rather than assume it, so this
    // keeps saying something true whichever way it is set.
    final stars = ((jsonDecode(File('assets/config/app_config.json').readAsStringSync())
        as Map<String, dynamic>)['progression']
        as Map<String, dynamic>)['starsToUnlockNext'] as num;

    expect(find.text('உயிர் எழுத்து'), findsOneWidget);
    expect(find.text('அ'), findsOneWidget, reason: 'the first letter is always open');
    // A locked letter still shows its glyph, greyed back behind a padlock —
    // so the padlocks are what say it is locked, not a missing letter.
    expect(find.text('உ'), findsOneWidget, reason: 'locked letters still show their shape');
    expect(
      find.byIcon(Icons.lock_rounded),
      findsNWidgets(stars == 0 ? 0 : letters.length - 1),
      reason: stars == 0
          ? 'progression is off, so nothing is locked'
          : 'every letter but the first starts locked',
    );
  });
}
