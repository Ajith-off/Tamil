import 'dart:ui';

Color _parseHex(String hex) {
  final cleaned = hex.replaceFirst('#', '');
  return Color(int.parse('FF$cleaned', radix: 16));
}

class ThemeColors {
  final Color background;
  final Color backgroundGlow;
  final Color primary;
  final Color secondary;
  final Color canvasBackground;

  /// The letter's guide tube and the darker line around it.
  final Color letterTube;
  final Color letterTubeEdge;

  /// Dots marking the path along the tube.
  final Color dot;

  /// Gradient the child's completed trace is filled with.
  final Color traceStart;
  final Color traceEnd;

  final Color sparkle;
  final Color ink;
  final Color success;
  final Color retry;
  final Color starFilled;
  final Color starEmpty;
  final Color textPrimary;
  final Color textSecondary;

  const ThemeColors({
    required this.background,
    required this.backgroundGlow,
    required this.primary,
    required this.secondary,
    required this.canvasBackground,
    required this.letterTube,
    required this.letterTubeEdge,
    required this.dot,
    required this.traceStart,
    required this.traceEnd,
    required this.sparkle,
    required this.ink,
    required this.success,
    required this.retry,
    required this.starFilled,
    required this.starEmpty,
    required this.textPrimary,
    required this.textSecondary,
  });

  factory ThemeColors.fromJson(Map<String, dynamic> json) {
    return ThemeColors(
      background: _parseHex(json['background'] as String),
      backgroundGlow: _parseHex(json['backgroundGlow'] as String),
      primary: _parseHex(json['primary'] as String),
      secondary: _parseHex(json['secondary'] as String),
      canvasBackground: _parseHex(json['canvasBackground'] as String),
      letterTube: _parseHex(json['letterTube'] as String),
      letterTubeEdge: _parseHex(json['letterTubeEdge'] as String),
      dot: _parseHex(json['dot'] as String),
      traceStart: _parseHex(json['traceStart'] as String),
      traceEnd: _parseHex(json['traceEnd'] as String),
      sparkle: _parseHex(json['sparkle'] as String),
      ink: _parseHex(json['ink'] as String),
      success: _parseHex(json['success'] as String),
      retry: _parseHex(json['retry'] as String),
      starFilled: _parseHex(json['starFilled'] as String),
      starEmpty: _parseHex(json['starEmpty'] as String),
      textPrimary: _parseHex(json['textPrimary'] as String),
      textSecondary: _parseHex(json['textSecondary'] as String),
    );
  }
}

class ThemeConfig {
  final ThemeColors colors;

  /// The home screen's dark (moon) palette — picked by the toggle beside the
  /// Parent Zone button, never the system theme, so it reads the same on
  /// every device (CLAUDE.md section 11 rules out anything not deliberately
  /// chosen). Scoped to the home screen only: the rest of the app keeps
  /// [colors], the same way it always has.
  final ThemeColors darkColors;

  const ThemeConfig({required this.colors, required this.darkColors});

  factory ThemeConfig.fromJson(Map<String, dynamic> json) {
    return ThemeConfig(
      colors: ThemeColors.fromJson(json['colors'] as Map<String, dynamic>),
      darkColors: ThemeColors.fromJson(json['darkColors'] as Map<String, dynamic>),
    );
  }
}
