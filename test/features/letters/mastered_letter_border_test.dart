import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kids_tamil_ezhuthu_school/core/config/models/trace_mode.dart';
import 'package:kids_tamil_ezhuthu_school/data/models/score.dart';
import 'package:kids_tamil_ezhuthu_school/data/repos/progress_repository.dart';
import 'package:kids_tamil_ezhuthu_school/main.dart';

import '../../app_harness.dart';

const _key = 'flutter.${ProgressRepository.storageKey}';

void main() {
  testWidgets('a letter taken to three stars shows a green ring, not orange', (tester) async {
    SharedPreferences.setMockInitialValues({
      _key: ProgressRepository.encode(SavedProgress(
        letters: {'uyir_01': LetterProgress(letterId: 'uyir_01', marksByMode: const {TraceMode.easy: 100})},
      )),
    });

    stillAnimations(tester);
    await tester.pumpWidget(const ProviderScope(child: TamilEzhuthuApp()));
    await tester.pumpAndSettle();
    await openCategory(tester, uyirTitle);

    // அ (uyir_01) is mastered; ஆ (uyir_02) has nothing earned yet.
    final masteredCircle = tester
        .widgetList<Material>(find.ancestor(
          of: find.text('அ'),
          matching: find.byType(Material),
        ))
        .firstWhere((m) => m.shape is CircleBorder);
    final untouchedCircle = tester
        .widgetList<Material>(find.ancestor(
          of: find.text('ஆ'),
          matching: find.byType(Material),
        ))
        .firstWhere((m) => m.shape is CircleBorder);

    final masteredBorder = (masteredCircle.shape as CircleBorder).side.color;
    final untouchedBorder = (untouchedCircle.shape as CircleBorder).side.color;

    expect(masteredBorder, const Color(0xFF2EC4B6), reason: 'success green');
    expect(untouchedBorder, isNot(masteredBorder));
  });
}
