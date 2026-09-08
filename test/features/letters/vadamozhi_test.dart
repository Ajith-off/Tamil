import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kids_tamil_ezhuthu_school/main.dart';

import '../../app_harness.dart';

/// Read synchronously throughout: a `testWidgets` body runs under fake async,
/// where a real `dart:io` future never completes and the test hangs.
List<Map<String, dynamic>> _roster(String path) =>
    (jsonDecode(File(path).readAsStringSync()) as List<dynamic>).cast<Map<String, dynamic>>();

Set<String> _authoredStrokeIds() => Directory('lib/data/letters/strokes')
    .listSync()
    .whereType<File>()
    .map((f) => f.uri.pathSegments.last)
    .where((name) => name.endsWith('.json'))
    .map((name) => name.substring(0, name.length - '.json'.length))
    .toSet();

const _grantha = ['ஜ', 'ஷ', 'ஸ', 'ஹ', 'க்ஷ', 'ஸ்ரீ'];

void main() {
  test('the vadamozhi roster is the six grantha letters', () {
    final letters = _roster('lib/data/letters/vadamozhi.json');

    expect(letters.length, 6);
    expect(letters.map((e) => e['tamil']), _grantha);
    expect(letters.map((e) => e['order']), List.generate(6, (i) => i + 1));
    expect(letters.map((e) => e['id']).toSet().length, 6, reason: 'ids are unique');
    expect(letters.every((e) => e['category'] == 'vadamozhi'), isTrue);
  });

  test('adding grantha took nothing away from the 247', () {
    // The whole point of this category is that it sits *beside* the 247, not
    // inside it. Every order in tools/orders.json names arc indices, so a
    // grantha letter that leaked into one of the three catalogues — or an id
    // it shares with one — would put a child in front of the wrong shape.
    final counts = {
      'uyir.json': 13, // 12 vowels plus ஃ, which ships in the uyir catalogue
      'mei.json': 18,
      'uyirmei.json': 216,
    };
    final ids = <String>{};
    for (final entry in counts.entries) {
      final letters = _roster('lib/data/letters/${entry.key}');
      expect(letters.length, entry.value, reason: '${entry.key} changed size');
      for (final letter in letters) {
        expect(_grantha.contains(letter['tamil']), isFalse,
            reason: '${letter['tamil']} is grantha and does not belong in ${entry.key}');
        ids.add(letter['id'] as String);
      }
    }
    expect(ids.length, 247, reason: 'the 247 are still 247 distinct characters');

    for (final letter in _roster('lib/data/letters/vadamozhi.json')) {
      expect(ids.contains(letter['id']), isFalse,
          reason: '${letter['id']} collides with one of the 247');
    }
  });

  test('every grantha letter names the glyph its skeleton was exported from', () {
    // The roster and the skeleton index are joined only by the id. Let them
    // drift and a child traces one letter while reading another — the same
    // guard mei_catalogue_test.dart puts on the consonants.
    final skeletons = {
      for (final e in _roster('assets/authoring/skeletons/index.json'))
        e['letterId'] as String: e['char'] as String,
    };

    for (final letter in _roster('lib/data/letters/vadamozhi.json')) {
      expect(skeletons[letter['strokeDataId']], letter['tamil'],
          reason: '${letter['id']} disagrees with its exported skeleton');
    }
  });

  // The only booting test in this file — asset futures do not resolve for a
  // second boot in the same file (see widget_test.dart).
  testWidgets('the picker shows a category only once something in it can be traced',
      (tester) async {
    // A Pixel 8 in landscape, which is the size that made the picker slide in
    // the first place: four tiles at 220dp do not fit here, so this exercises
    // the scrolling path rather than the roomy-tablet one.
    tester.view.physicalSize = const Size(892, 412);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    stillAnimations(tester);

    await tester.pumpWidget(const ProviderScope(child: TamilEzhuthuApp()));
    await tester.pumpAndSettle();

    // Derived rather than asserted outright, so this keeps saying something
    // true the day someone authors the grantha stroke orders: the tile is
    // supposed to appear exactly then, and not one build before.
    //
    // The authoring flag overrides it, and has to — the Author button lives
    // inside a category's letter list, so a category with no orders is exactly
    // the one that has to be walkable while someone is drawing them.
    final authored = _authoredStrokeIds();
    final traceable = _roster('lib/data/letters/vadamozhi.json')
        .any((l) => authored.contains(l['strokeDataId']));
    final authoring = ((jsonDecode(File('assets/config/app_config.json').readAsStringSync())
        as Map<String, dynamic>)['featureFlags']
        as Map<String, dynamic>)['authoringEnabled'] as bool;

    expect(
      categoryTile('வடமொழி எழுத்துக்கள்'),
      traceable || authoring ? findsOneWidget : findsNothing,
      reason: traceable
          ? 'grantha has stroke data now, so its tile belongs on the picker'
          : authoring
              ? 'authoring is on, so every category has to be reachable'
              : 'no grantha stroke data yet, so a tile would lead nowhere',
    );
    // The categories that do work are unaffected either way.
    expect(categoryTile('உயிர் எழுத்து'), findsOneWidget);
    expect(categoryTile('மெய் எழுத்து'), findsOneWidget);

    // The row that does not fit has to scroll rather than overflow. A
    // RenderFlex overflow is only a debug banner and a console line, so
    // nothing else here would fail on it.
    expect(tester.takeException(), isNull, reason: 'the picker overflowed at phone size');
    await tester.drag(categoryTile('உயிர் எழுத்து').first, const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'sliding the picker threw');
  });
}
