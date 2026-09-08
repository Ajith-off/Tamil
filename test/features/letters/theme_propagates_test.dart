import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_tamil_ezhuthu_school/l10n/gen/app_localizations.dart';
import 'package:kids_tamil_ezhuthu_school/data/models/letter.dart';
import 'package:kids_tamil_ezhuthu_school/features/letters/letters_screen.dart';
import 'package:kids_tamil_ezhuthu_school/services/settings_store.dart';

import '../../app_harness.dart';

void main() {
  testWidgets('the dark theme picked on the home screen carries into a letter list',
      (tester) async {
    stillAnimations(tester);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    // The toggle only lives on the home screen; setting it directly here
    // stands in for a tap there, since this test is about the choice
    // reaching a screen that carries no control of its own.
    container.read(settingsStoreProvider.notifier).setHomeTheme(HomeTheme.dark);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('ta'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const LettersScreen(catalogue: LetterCatalogue.uyir),
      ),
    ));
    await tester.pumpAndSettle();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, const Color(0xFF141A2E), reason: 'dark background');
  });
}
