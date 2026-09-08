import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_tamil_ezhuthu_school/features/parent/parent_zone_screen.dart';
import 'package:kids_tamil_ezhuthu_school/l10n/gen/app_localizations.dart';

import '../../app_harness.dart';

const _shareChannel = MethodChannel('dev.fluttercommunity.plus/share');

void main() {
  testWidgets('sharing the app hands the platform share sheet the app title and its URL',
      (tester) async {
    stillAnimations(tester);
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_shareChannel, (call) async {
      calls.add(call);
      return 'dev.fluttercommunity.plus/share/success';
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_shareChannel, null));

    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        locale: const Locale('ta'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ParentZoneScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    // The language/music/sound rows added above push Share past the default
    // test viewport's height.
    await tester.scrollUntilVisible(find.text('ஆப்பைப் பகிர்'), 200);
    await tester.tap(find.text('ஆப்பைப் பகிர்'));
    await tester.pumpAndSettle();

    expect(calls, hasLength(1));
    expect(calls.single.method, 'share');
    final text = (calls.single.arguments as Map)['text'] as String;
    expect(text, contains('அஆஇஈ தமிழ் எழுத்து'));
    expect(text, contains('play.google.com'));
  });
}
