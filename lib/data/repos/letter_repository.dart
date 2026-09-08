import 'dart:convert';

import 'package:flutter/services.dart' show AssetManifest, rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/letter.dart';
import '../models/stroke.dart';

/// Loads letter metadata and reference stroke data from
/// `lib/data/letters/`.
class LetterRepository {
  const LetterRepository();

  static const _dir = 'lib/data/letters';

  /// Every letter of a catalogue, in writing order.
  ///
  /// The whole set, including letters nobody has authored stroke data for
  /// yet. A category that showed only its finished letters would tell a child
  /// மெய் has four letters in it. The list shows all 18 and marks the ones
  /// that cannot be traced yet — see [authoredStrokeDataIds].
  Future<List<Letter>> loadCatalogue(LetterCatalogue catalogue) async {
    final raw = await rootBundle.loadString('$_dir/${catalogue.fileName}');
    final list = (jsonDecode(raw) as List<dynamic>).cast<Map<String, dynamic>>();
    return list.map(Letter.fromJson).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
  }

  /// Which stroke files the build actually bundled — that is, which letters
  /// have been authored and so can actually be traced.
  ///
  /// `pubspec.yaml` ships `strokes/` as a directory, so the manifest holds
  /// exactly the files that existed at build time. Note the build, not the
  /// run: a stroke file written while the app is running needs a rebuild
  /// rather than a hot restart before it shows up.
  Future<Set<String>> authoredStrokeDataIds() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    const prefix = '$_dir/strokes/';
    return manifest
        .listAssets()
        .where((path) => path.startsWith(prefix) && path.endsWith('.json'))
        .map((path) => path.substring(prefix.length, path.length - '.json'.length))
        .toSet();
  }

  Future<LetterStrokeData> loadStrokeData(String strokeDataId) async {
    final raw = await rootBundle.loadString('$_dir/strokes/$strokeDataId.json');
    return LetterStrokeData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }
}

final letterRepositoryProvider = Provider<LetterRepository>((ref) => const LetterRepository());
