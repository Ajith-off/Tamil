import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_tamil_ezhuthu_school/l10n/gen/app_localizations.dart';
import 'package:kids_tamil_ezhuthu_school/features/parent/parent_zone_screen.dart';
import 'package:kids_tamil_ezhuthu_school/services/settings_store.dart';

import '../../app_harness.dart';

void main() {
  testWidgets('toggling the music switch flips settingsStoreProvider.musicEnabled',
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
        home: const ParentZoneScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(container.read(settingsStoreProvider).musicEnabled, isTrue);
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();

    expect(container.read(settingsStoreProvider).musicEnabled, isFalse);
  });
}
