import 'package:flutter/material.dart';

import '../../core/config/models/theme_config.dart';
import 'reward_icons.dart';

/// The tile the home screen and the uyirmei rows are both built from.
///
/// Shared rather than copied so the two cannot drift apart: they are the same
/// gesture at two depths — "here is a set of letters, here are some of them,
/// go in" — and a child should not have to learn it twice.
///
/// The letters are the icon. A 4-8 year old who cannot read the label yet
/// still knows which set they want from the shapes on the tile (CLAUDE.md
/// section 11).
class CategoryTile extends StatelessWidget {
  /// A few of the letters inside, e.g. `க கா கி`.
  final String sample;

  /// What the set is called, or how far through it the child is.
  final String label;

  final ThemeColors colors;
  final VoidCallback onTap;

  /// A set with nothing to trace yet is shown, but greyed and not tappable —
  /// the same way a single un-authored letter is.
  final bool enabled;

  /// Stars earned inside this set, when it is worth showing.
  final int? stars;

  /// Characters finished outright, shown as a medal. The home picker uses this
  /// rather than stars: a star total climbs to three times the size of the
  /// category and says nothing a child can act on, where "eleven done" does.
  final int? medals;

  /// Marks a tile out as a different kind of thing — play rather than
  /// practice. Defaults to the usual border.
  final Color? borderColor;

  final double width;
  final double sampleSize;

  const CategoryTile({
    super.key,
    required this.sample,
    required this.label,
    required this.colors,
    required this.onTap,
    this.enabled = true,
    this.stars,
    this.medals,
    this.borderColor,
    this.width = 220,
    this.sampleSize = 34,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: sample,
      enabled: enabled,
      button: true,
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Material(
          color: colors.canvasBackground,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: enabled ? onTap : null,
            child: Container(
              width: width,
              // Height comes from the content rather than a fixed number:
              // Tamil ascenders and descenders make the line taller than the
              // font size suggests, and a child's device may be set to larger
              // text than this was laid out at.
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: enabled ? (borderColor ?? colors.primary) : colors.starEmpty,
                  width: 3,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Scaled down rather than clipped: the rows are not all the
                  // same width — ண ணா ணி is half again as wide as த தா தி —
                  // and a sample with its last letter cut off is worse than a
                  // slightly smaller one.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      sample,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: sampleSize,
                        fontWeight: FontWeight.bold,
                        color: enabled
                            ? colors.textPrimary
                            : colors.textSecondary.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Two lines' worth of room whether or not the label needs
                  // it, so a longer name does not make its tile taller than
                  // the others. They sit in one row and an odd one out reads
                  // as a different kind of thing, which is what the colour is
                  // for — not an accident of how long the word is.
                  SizedBox(
                    height: 38,
                    child: Center(
                      child: Text(
                        label,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 14, color: colors.textSecondary),
                      ),
                    ),
                  ),
                  if (medals != null) ...[
                    const SizedBox(height: 4),
                    _Total(
                      mark: Icon(
                        Icons.military_tech_rounded,
                        size: 18,
                        color: medals! > 0 ? colors.starFilled : colors.starEmpty,
                      ),
                      value: medals!,
                      colors: colors,
                    ),
                  ] else if (stars != null) ...[
                    const SizedBox(height: 4),
                    _Total(
                      mark: MagicPenStar(
                        size: 16,
                        color: stars! > 0 ? colors.starFilled : colors.starEmpty,
                      ),
                      value: stars!,
                      colors: colors,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Total extends StatelessWidget {
  final Widget mark;
  final int value;
  final ThemeColors colors;

  const _Total({required this.mark, required this.value, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(width: 3),
        Text(
          '$value',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: colors.textSecondary,
          ),
        ),
      ],
    );
  }
}
