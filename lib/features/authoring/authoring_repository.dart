import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'glyph_skeleton.dart';

/// Loads the glyph skeletons written by `tools/export_skeletons.py`.
class AuthoringRepository {
  const AuthoringRepository();

  static const _dir = 'assets/authoring/skeletons';

  /// The letters available to author. A bundle cannot be listed at runtime,
  /// so the exporter writes the roster alongside the skeletons.
  Future<List<SkeletonIndexEntry>> loadIndex() async {
    final raw = await rootBundle.loadString('$_dir/index.json');
    return (jsonDecode(raw) as List<dynamic>)
        .map((e) => SkeletonIndexEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<GlyphSkeleton> loadSkeleton(String letterId) async {
    final raw = await rootBundle.loadString('$_dir/$letterId.json');
    return GlyphSkeleton.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }
}

final authoringRepositoryProvider =
    Provider<AuthoringRepository>((ref) => const AuthoringRepository());

final skeletonIndexProvider = FutureProvider<List<SkeletonIndexEntry>>((ref) {
  return ref.watch(authoringRepositoryProvider).loadIndex();
});

final skeletonProvider = FutureProvider.family<GlyphSkeleton, String>((ref, letterId) {
  return ref.watch(authoringRepositoryProvider).loadSkeleton(letterId);
});
