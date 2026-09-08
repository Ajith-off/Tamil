import 'package:flutter/material.dart';

import '../../../core/config/models/theme_config.dart';
import '../../letters/reward_icons.dart';

/// Hearts left, whether this word has been beaten cleanly, and the coin
/// balance — the three things a child needs to know before they start.
///
/// Hearts are drawn as a fixed row rather than a number: a four-year-old reads
/// "two of my three are left" off shapes long before they read it off digits.
/// A spent heart keeps its outline in place rather than disappearing, so what
/// is missing is visible.
class GameHud extends StatelessWidget {
  final int hearts;

  /// How many outlines to draw, so a spent heart leaves a gap behind.
  final int heartCapacity;

  final int coins;

  /// Whether *this word* already carries its achievement — the game screen,
  /// where there is one word and the medal is lit or it is not.
  final bool achieved;

  /// How many have been earned altogether. The card list shows this instead,
  /// because there the medal is a running total rather than one word's state.
  final int? achievementCount;

  /// Offered when there are no hearts left. Null hides it.
  final VoidCallback? onBuyHearts;

  final ThemeColors colors;

  const GameHud({
    super.key,
    required this.hearts,
    required this.heartCapacity,
    required this.coins,
    required this.achieved,
    this.achievementCount,
    required this.onBuyHearts,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: '$hearts',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < heartCapacity; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: Icon(
                    i < hearts ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    size: 22,
                    color: i < hearts
                        ? colors.retry
                        : colors.textSecondary.withValues(alpha: 0.35),
                  ),
                ),
              // Nothing left to play with, so the way to get more is put where
              // the missing hearts are rather than somewhere else.
              if (hearts <= 0 && onBuyHearts != null)
                IconButton(
                  onPressed: onBuyHearts,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.add_circle_rounded, size: 24, color: colors.primary),
                  tooltip: MaterialLocalizations.of(context).moreButtonTooltip,
                ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Icon(
          Icons.military_tech_rounded,
          size: 24,
          color: (achievementCount ?? 0) > 0 || achieved
              ? colors.starFilled
              : colors.starEmpty,
        ),
        if (achievementCount != null) ...[
          const SizedBox(width: 4),
          Text(
            '$achievementCount',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: colors.textSecondary,
            ),
          ),
        ],
        const SizedBox(width: 14),
        Icon(RewardIcons.coin, size: 20, color: colors.secondary),
        const SizedBox(width: 4),
        Text(
          '$coins',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: colors.textSecondary,
          ),
        ),
      ],
    );
  }
}
