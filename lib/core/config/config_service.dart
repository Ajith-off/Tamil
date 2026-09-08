import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/app_config.dart';
import 'models/authoring_config.dart';
import 'models/games_config.dart';
import 'models/scoring_config.dart';
import 'models/theme_config.dart';
import 'models/trace_config.dart';

/// Loads and holds every `assets/config/*.json` file, parsed into typed
/// models. This is the ONLY place feature code should get thresholds,
/// weights, colors, or durations from — no magic numbers in features.
class ConfigService {
  final AppConfig app;
  final ScoringConfig scoring;
  final TraceConfig trace;
  final ThemeConfig theme;
  final AuthoringConfig authoring;
  final GamesConfig games;

  const ConfigService({
    required this.app,
    required this.scoring,
    required this.trace,
    required this.theme,
    required this.authoring,
    required this.games,
  });

  static Future<ConfigService> load() async {
    final results = await Future.wait([
      _loadJson('assets/config/app_config.json'),
      _loadJson('assets/config/scoring_config.json'),
      _loadJson('assets/config/trace_config.json'),
      _loadJson('assets/config/theme_config.json'),
      _loadJson('assets/config/authoring_config.json'),
      _loadJson('assets/config/games_config.json'),
    ]);

    return ConfigService(
      app: AppConfig.fromJson(results[0]),
      scoring: ScoringConfig.fromJson(results[1]),
      trace: TraceConfig.fromJson(results[2]),
      theme: ThemeConfig.fromJson(results[3]),
      authoring: AuthoringConfig.fromJson(results[4]),
      games: GamesConfig.fromJson(results[5]),
    );
  }

  static Future<Map<String, dynamic>> _loadJson(String assetPath) async {
    final raw = await rootBundle.loadString(assetPath);
    return jsonDecode(raw) as Map<String, dynamic>;
  }
}

final configServiceProvider = FutureProvider<ConfigService>((ref) {
  return ConfigService.load();
});
