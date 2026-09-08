import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_tamil_ezhuthu_school/features/parent/certificate_screen.dart';
import 'package:kids_tamil_ezhuthu_school/l10n/gen/app_localizations.dart';

import '../../app_harness.dart';

void main() {
  testWidgets('the info button explains how the 100 marks are worked out', (tester) async {
    stillAnimations(tester);
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        locale: const Locale('ta'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const CertificateScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.info_outline_rounded));
    await tester.pumpAndSettle();

    expect(find.text('மதிப்பெண் எப்படி கணக்கிடப்படுகிறது?'), findsOneWidget);
    expect(find.text('247 எழுத்துப் பயிற்சி மதிப்பெண்கள்'), findsWidgets);
    // No progress at all yet, so every line reads 0 out of its own maximum.
    expect(find.text('0/50'), findsWidgets);
  });
}
