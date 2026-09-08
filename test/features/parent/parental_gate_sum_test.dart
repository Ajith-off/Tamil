import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_tamil_ezhuthu_school/features/parent/parental_gate_screen.dart';
import 'package:kids_tamil_ezhuthu_school/l10n/gen/app_localizations.dart';

import '../../app_harness.dart';

void main() {
  testWidgets('the sum never exceeds 10, across many regenerated questions',
      (tester) async {
    stillAnimations(tester);
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        locale: const Locale('ta'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ParentalGateScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    final sumPattern = RegExp(r'(\d+)\s*\+\s*(\d+)\s*=');
    for (var i = 0; i < 30; i++) {
      if (!tester.any(find.textContaining('+'))) break;
      final questionText = tester
          .widgetList<Text>(find.textContaining('+'))
          .map((t) => t.data ?? '')
          .firstWhere(sumPattern.hasMatch);
      final match = sumPattern.firstMatch(questionText)!;
      final a = int.parse(match.group(1)!);
      final b = int.parse(match.group(2)!);
      expect(a + b, lessThanOrEqualTo(10),
          reason: 'a gate a grown-up cannot pass locks the whole Parent Zone away');
      expect(a, greaterThanOrEqualTo(1));
      expect(b, greaterThanOrEqualTo(1));

      // Tap the first answer — right or wrong, either regenerates the
      // question or opens the gate; either way the next loop iteration
      // either finds a fresh question to check or stops.
      final answers = find.descendant(
        of: find.byType(InkWell),
        matching: find.byType(Text),
      );
      if (!tester.any(answers)) break;
      await tester.tap(answers.first);
      await tester.pumpAndSettle();
    }
  });
}
