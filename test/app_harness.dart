import 'dart:ui' show AccessibilityFeatures;

import 'package:flutter/widgets.dart' show Text;
import 'package:flutter_test/flutter_test.dart';

/// Category titles as the picker shows them, from `app_ta.arb`.
const uyirTitle = 'உயிர் எழுத்து';
const meiTitle = 'மெய் எழுத்து';

/// Ask for reduced motion before the app boots.
///
/// The games tile breathes forever to mark itself out from the letter
/// categories, and a repeating controller schedules frames forever — so
/// `pumpAndSettle` never returns unless something stops it. The tile honours
/// the platform's reduce-motion setting, which is worth honouring anyway, so
/// turning it on is how a test gets a still screen rather than a special case
/// in production code.
void stillAnimations(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const _ReducedMotion();
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

/// Only [disableAnimations] matters here. `noSuchMethod` answers the rest as
/// false, so this keeps compiling when `AccessibilityFeatures` gains a member
/// — which it does between Flutter versions.
class _ReducedMotion implements AccessibilityFeatures {
  const _ReducedMotion();

  @override
  bool get disableAnimations => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => false;
}

/// The picker tile for a category.
///
/// Matched on the *start* of the label, not exactly and not by containment: a
/// home tile reads "உயிர் எழுத்து (13)" — the label plus how many characters
/// are in it — and "மெய் எழுத்து" sits inside "உயிர்மெய் எழுத்து", so
/// anything looser than a prefix matches two tiles.
Finder categoryTile(String title) => find.byWidgetPredicate(
      (widget) => widget is Text && (widget.data ?? '').startsWith(title),
      description: 'category tile "$title"',
    );

/// Get from the app's first screen to a category's letter list.
///
/// The app boots into the category picker, so a test that wants letters has a
/// tile to get through first. One helper rather than the same tap copied into
/// every booting test, because the route from launch to a letter is the thing
/// most likely to grow another step.
Future<void> openCategory(WidgetTester tester, String title) async {
  await tester.tap(categoryTile(title).first);
  await tester.pumpAndSettle();
}
