import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_tamil_ezhuthu_school/features/parent/certificate_screen.dart';
import 'package:kids_tamil_ezhuthu_school/l10n/gen/app_localizations.dart';
import 'package:kids_tamil_ezhuthu_school/services/settings_store.dart';

import '../../app_harness.dart';

void main() {
  testWidgets('typing a name into the certificate saves it to settings', (tester) async {
    stillAnimations(tester);
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('ta'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const CertificateScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(container.read(settingsStoreProvider).childName, isEmpty);

    await tester.enterText(find.byType(TextField), 'Meera');
    await tester.pumpAndSettle();

    expect(container.read(settingsStoreProvider).childName, 'Meera');
  });
}
