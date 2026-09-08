import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_tamil_ezhuthu_school/features/home/home_screen.dart';
import 'package:kids_tamil_ezhuthu_school/features/parent/parent_zone_screen.dart';
import 'package:kids_tamil_ezhuthu_school/features/parent/parental_gate_screen.dart';
import 'package:kids_tamil_ezhuthu_school/l10n/gen/app_localizations.dart';

import '../../app_harness.dart';

void main() {
  testWidgets(
      'the home screen carries a Parent Zone button in its top-left corner, behind a gate, '
      'and no bare quit button', (tester) async {
    stillAnimations(tester);
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        locale: const Locale('ta'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const HomeScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    // Quitting now lives inside the Parent Zone, behind the gate — a child
    // must not be able to close the app from the home screen on their own.
    expect(find.byTooltip('வெளியேறு'), findsNothing);

    // A ringed icon button, not a row-scrolling tile — always on screen in
    // the same corner quitting used to occupy.
    final button = find.byTooltip('பெற்றோர் பகுதி');
    expect(button, findsOneWidget);
    await tester.tap(button);
    await tester.pumpAndSettle();

    // The gate stands between the button and the zone — tapping it must not
    // open the zone directly (CLAUDE.md section 1, "parental gate required").
    expect(find.byType(ParentalGateScreen), findsOneWidget);
    expect(find.byType(ParentZoneScreen), findsNothing);
  });
}
