import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_tamil_ezhuthu_school/l10n/gen/app_localizations.dart';
import 'package:kids_tamil_ezhuthu_school/features/parent/parent_zone_screen.dart';
import 'package:kids_tamil_ezhuthu_school/services/settings_store.dart';

import '../../app_harness.dart';

/// Mirrors how `TamilEzhuthuApp` itself drives `MaterialApp.locale` off
/// [settingsStoreProvider] (main.dart) — a test that hardcoded the locale
/// instead would tap the switch and never see the screen actually change
/// language.
class _App extends ConsumerWidget {
  const _App();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(settingsStoreProvider).locale;
    return MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const ParentZoneScreen(),
    );
  }
}

void main() {
  testWidgets('picking English in the Parent Zone switches the screen to English',
      (tester) async {
    stillAnimations(tester);
    await tester.pumpWidget(const ProviderScope(child: _App()));
    await tester.pumpAndSettle();

    expect(find.text('மொழி'), findsOneWidget);
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(find.text('Language'), findsOneWidget);
  });
}
