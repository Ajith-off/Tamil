import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/config_service.dart';
import '../../core/config/models/theme_config.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../services/settings_store.dart';
import '../../services/theme_selector.dart';
import '../common/guide_highlight.dart';
import 'parent_zone_screen.dart';

/// A simple sum a young child cannot yet do, standing between the app and
/// everything the Parent Zone leads to — ads, purchases, outbound links
/// (CLAUDE.md section 1, "Parental gate required before...").
///
/// One gate at the entrance covers every one of those, since none of them is
/// reachable without passing it first.
class ParentalGateScreen extends ConsumerStatefulWidget {
  const ParentalGateScreen({super.key});

  @override
  ConsumerState<ParentalGateScreen> createState() => _ParentalGateScreenState();
}

class _ParentalGateScreenState extends ConsumerState<ParentalGateScreen> {
  final _random = Random();
  late _Question _question = _newQuestion();
  bool _wrong = false;

  _Question _newQuestion() {
    // Addition only, and the sum never exceeds 10 — this exists to keep a
    // toddler out, not to test a grown-up's arithmetic. A gate a parent
    // cannot pass is worse than no gate at all: it locks the whole Parent
    // Zone away, ads and privacy policy included.
    final a = 1 + _random.nextInt(9);
    final b = 1 + _random.nextInt(10 - a);
    final correct = a + b;
    final options = <int>{correct};
    while (options.length < 4) {
      // Distractors close enough to the right answer that guessing the
      // shape of the number is not enough — an off-by-one slip, not a wild
      // number.
      final delta = 1 + _random.nextInt(4);
      final candidate = _random.nextBool() ? correct + delta : max(1, correct - delta);
      options.add(candidate);
    }
    final order = options.toList()..shuffle(_random);
    return _Question(a: a, b: b, correct: correct, options: order);
  }

  void _answer(int value) {
    if (value == _question.correct) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ParentZoneScreen()),
      );
      return;
    }
    setState(() {
      _wrong = true;
      _question = _newQuestion();
    });
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(configServiceProvider);
    if (!configAsync.hasValue) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final colors = themeColorsOf(configAsync.requireValue, ref.watch(settingsStoreProvider));
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  BackCircleButton(
                    color: colors.textSecondary,
                    background: colors.canvasBackground,
                    border: colors.starEmpty,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shield_rounded, size: 48, color: colors.secondary),
                    const SizedBox(height: 12),
                    Text(
                      l10n.parentalGateTitle,
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: colors.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.parentalGateInstruction,
                      style: TextStyle(fontSize: 14, color: colors.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      l10n.parentalGateQuestion('${_question.a}', '${_question.b}'),
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: colors.textPrimary),
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: [
                        for (final option in _question.options)
                          _AnswerButton(
                            value: option,
                            colors: colors,
                            onTap: () => _answer(option),
                          ),
                      ],
                    ),
                    if (_wrong) ...[
                      const SizedBox(height: 16),
                      Text(
                        l10n.encouragementRetry,
                        style: TextStyle(fontSize: 14, color: colors.retry, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Question {
  final int a;
  final int b;
  final int correct;
  final List<int> options;

  const _Question({required this.a, required this.b, required this.correct, required this.options});
}

class _AnswerButton extends StatelessWidget {
  final int value;
  final ThemeColors colors;
  final VoidCallback onTap;

  const _AnswerButton({required this.value, required this.colors, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colors.canvasBackground,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: 84,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.primary, width: 2.5),
          ),
          child: Text(
            '$value',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: colors.textPrimary),
          ),
        ),
      ),
    );
  }
}
