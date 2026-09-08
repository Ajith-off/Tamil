import 'package:flutter/material.dart';

import '../../../core/config/models/theme_config.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../letters/reward_icons.dart';

/// What appears once the word is built: play it again, or take the tick and
/// go back. Plus the coin, if the round earned one.
///
/// Two buttons and nothing else. A child who has just finished something wants
/// to do it again or to leave, and any third option is a thing to get wrong.
class FinishedPanel extends StatelessWidget {
  /// Shown only when the round was clean — a round with a wrong drop earns
  /// nothing, and saying so with a silent absence is kinder than a zero.
  final bool earnedCoin;

  /// Playing again costs a heart like any other opening, so with none left
  /// there is nothing to offer but the way to get one.
  final bool canRestart;

  final VoidCallback onRestart;

  /// Buys hearts with a coin. Null when there is no coin to spend, in which
  /// case only the way out is shown — an offer that cannot be taken is worse
  /// than no offer.
  final VoidCallback? onBuyHearts;

  final VoidCallback onDone;
  final ThemeColors colors;

  const FinishedPanel({
    super.key,
    required this.earnedCoin,
    required this.canRestart,
    required this.onRestart,
    required this.onBuyHearts,
    required this.onDone,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (earnedCoin) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: colors.canvasBackground,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colors.secondary, width: 2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(RewardIcons.coin, size: 20, color: colors.secondary),
                const SizedBox(width: 6),
                Text(
                  l10n.coinEarned,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
        ],
        if (canRestart)
          _RoundButton(
            icon: Icons.refresh_rounded,
            label: l10n.playAgain,
            color: colors.primary,
            onTap: onRestart,
            colors: colors,
          )
        else if (onBuyHearts != null)
          _RoundButton(
            icon: Icons.favorite_rounded,
            label: l10n.needHearts,
            color: colors.retry,
            onTap: onBuyHearts!,
            colors: colors,
            badge: RewardIcons.coin,
          ),
        if (canRestart || onBuyHearts != null) const SizedBox(width: 16),
        _RoundButton(
          icon: Icons.check_rounded,
          label: l10n.done,
          color: colors.success,
          onTap: onDone,
          colors: colors,
        ),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final ThemeColors colors;

  /// A small mark in the corner saying what the button costs.
  final IconData? badge;

  const _RoundButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    required this.colors,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      child: Material(
        color: color,
        shape: const CircleBorder(),
        elevation: 4,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 58,
            height: 58,
            child: badge == null
                ? Icon(icon, size: 30, color: colors.canvasBackground)
                : Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(icon, size: 30, color: colors.canvasBackground),
                      Positioned(
                        right: 6,
                        bottom: 6,
                        child: Icon(badge, size: 16, color: colors.canvasBackground),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
