import 'package:flutter/material.dart';

import '../../core/config/models/theme_config.dart';
import 'reward_icons.dart';

/// The running totals a list screen carries in its top corner: stars earned
/// across everything on this screen, and coins in the purse.
///
/// Read-only and undramatic on purpose. It says what a child has, never what
/// they are about to lose — no streak counter, no countdown (CLAUDE.md
/// section 11).
class ScoreBadge extends StatelessWidget {
  /// Null hides the stars pill entirely — the Parent Zone shows the coin
  /// balance on its own, since stars and achievements are a child's tally,
  /// not something a grown-up checking on ad earnings needs alongside it.
  final int? stars;
  final int? coins;

  /// Characters and words finished outright. Shown on the home screen, where
  /// it is the total a child is actually collecting.
  final int? achievements;

  final ThemeColors colors;

  const ScoreBadge({
    super.key,
    this.stars,
    this.coins,
    this.achievements,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final pills = [
      if (stars != null)
        _Pill(
          mark: MagicPenStar(size: 18, color: colors.starFilled),
          value: '$stars',
          colors: colors,
        ),
      if (achievements != null)
        _Pill(
          mark: Icon(Icons.military_tech_rounded, size: 18, color: colors.starFilled),
          value: '$achievements',
          colors: colors,
        ),
      if (coins != null)
        _Pill(
          // Blue, so the two totals never read as the same currency.
          mark: Icon(RewardIcons.coin, size: 18, color: colors.secondary),
          value: '$coins',
          colors: colors,
        ),
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < pills.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          pills[i],
        ],
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final Widget mark;
  final String value;
  final ThemeColors colors;

  const _Pill({
    required this.mark,
    required this.value,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colors.canvasBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.starEmpty, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          mark,
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
