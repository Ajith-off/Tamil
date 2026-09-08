import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_tamil_ezhuthu_school/features/parent/parental_gate_screen.dart';
import 'package:kids_tamil_ezhuthu_school/l10n/gen/app_localizations.dart';

import '../../app_harness.dart';

void main() {
  testWidgets('the gate shows one sum and four distinct answers', (tester) async {
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

    expect(find.textContaining('+'), findsOneWidget);
    // Four tappable answers, each showing a different number.
    final numbers = tester
        .widgetList<Text>(find.descendant(
          of: find.byType(InkWell),
          matching: find.byType(Text),
        ))
        .map((t) => t.data)
        .whereType<String>()
        .where((s) => int.tryParse(s) != null)
        .toSet();
    expect(numbers.length, 4);
  });
}
