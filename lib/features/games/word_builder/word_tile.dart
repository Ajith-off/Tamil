import 'package:flutter/material.dart';

import '../../../core/config/models/games_config.dart';
import '../../../core/config/models/theme_config.dart';

/// The face of a letter tile.
///
/// Pulled out so the tray, the thing under the finger while dragging, and the
/// ghost that demonstrates the drag are all one widget — three copies of a
/// rounded square with a letter in it would drift apart, and the demonstration
/// has to look like the thing it is demonstrating.
class TileFace extends StatelessWidget {
  final String char;
  final WordBuilderConfig config;
  final ThemeColors colors;

  /// Grown while dragged, so it clears the child's hand.
  final double scale;

  final bool raised;

  const TileFace({
    super.key,
    required this.char,
    required this.config,
    required this.colors,
    this.scale = 1,
    this.raised = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colors.canvasBackground,
      borderRadius: BorderRadius.circular(config.tileCornerRadius * scale),
      elevation: raised ? 8 : 0,
      child: Container(
        width: config.tileSize * scale,
        height: config.tileSize * scale,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(config.tileCornerRadius * scale),
          border: Border.all(color: colors.primary, width: 3),
        ),
        child: Text(
          char,
          style: TextStyle(
            fontSize: config.tileSize * 0.46 * scale,
            fontWeight: FontWeight.bold,
            color: colors.textPrimary,
          ),
        ),
      ),
    );
  }
}
