import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_tamil_ezhuthu_school/features/parent/certificate_screen.dart';
import 'package:kids_tamil_ezhuthu_school/features/parent/parent_zone_screen.dart';
import 'package:kids_tamil_ezhuthu_school/l10n/gen/app_localizations.dart';

import '../../app_harness.dart';

void main() {
  testWidgets('the Parent Zone lists every row, including quit, and opens the certificate',
      (tester) async {
    stillAnimations(tester);
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        locale: const Locale('ta'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ParentZoneScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('நாணயம் பெற விளம்பரம் பார்'), findsOneWidget);
    expect(find.text('சான்றிதழ்'), findsOneWidget);
    expect(find.text('திட்ட விவரங்கள்'), findsOneWidget);
    expect(find.text('தனியுரிமைக் கொள்கை'), findsOneWidget);
    expect(find.text('ஆப்பைப் பகிர்'), findsOneWidget);
    // Moved here from the home screen's top-left corner, behind the gate.
    expect(find.text('வெளியேறு'), findsOneWidget);

    await tester.tap(find.text('சான்றிதழ்'));
    await tester.pumpAndSettle();

    expect(find.byType(CertificateScreen), findsOneWidget);
  });
}
