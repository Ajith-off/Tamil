import 'dart:convert';
import 'dart:io';

import 'package:kids_tamil_ezhuthu_school/core/config/models/scoring_config.dart';

/// The very numbers the app ships with — read from the config rather than
/// copied, because a copy drifts. This one did: the first star moved to 30
/// marks and the duplicate here still said 50, so the tests went on proving
/// something the app no longer did.
///
/// Read synchronously: a testWidgets body runs under fake async, where a
/// real dart:io future never completes.
final scoringConfigFixture = ScoringConfig.fromJson(
  jsonDecode(File('assets/config/scoring_config.json').readAsStringSync())
      as Map<String, dynamic>,
);
