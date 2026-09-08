import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_tamil_ezhuthu_school/features/home/home_screen.dart';
import 'package:kids_tamil_ezhuthu_school/l10n/gen/app_localizations.dart';
import 'package:kids_tamil_ezhuthu_school/services/settings_store.dart';

import '../../app_harness.dart';

void main() {
  testWidgets('the sun/moon button beside Parent Zone flips the home theme',
      (tester) async {
    stillAnimations(tester);
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('ta'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const HomeScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(container.read(settingsStoreProvider).homeTheme, HomeTheme.light);
    expect(find.byTooltip('பகல் தீம்'), findsOneWidget);

    await tester.tap(find.byTooltip('பகல் தீம்'));
    await tester.pumpAndSettle();

    expect(container.read(settingsStoreProvider).homeTheme, HomeTheme.dark);
    expect(find.byTooltip('இரவு தீம்'), findsOneWidget);
  });
}
