import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_tamil_ezhuthu_school/features/parent/parent_zone_screen.dart';
import 'package:kids_tamil_ezhuthu_school/l10n/gen/app_localizations.dart';

import '../../app_harness.dart';

void main() {
  testWidgets('quitting from the Parent Zone asks the platform to pop the app', (tester) async {
    stillAnimations(tester);
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      calls.add(call);
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        locale: const Locale('ta'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ParentZoneScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    // The list now runs past the default test viewport's height with the
    // Share row added, so the quit row needs scrolling into view first.
    await tester.scrollUntilVisible(find.text('வெளியேறு'), 200);
    await tester.tap(find.text('வெளியேறு'));
    await tester.pumpAndSettle();

    expect(calls.map((c) => c.method), contains('SystemNavigator.pop'));
  });
}
