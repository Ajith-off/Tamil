import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/config_service.dart';
import '../../core/config/models/authoring_config.dart';
import '../../core/config/models/theme_config.dart';
import 'authored_order.dart';
import 'authoring_canvas.dart';
import 'authoring_repository.dart';
import 'glyph_skeleton.dart';
import 'order_solver.dart';

/// Where a letter's writing order comes from.
///
/// The font gives the shape and nothing else. Deriving the order from a
/// handwriting animation failed three separate ways, each contradicting the
/// one letter whose order had been checked by hand, because the animation
/// and the font are different letterforms (HANDOFF.md). Here a person draws
/// the order instead, over the font's own geometry — same coordinate space,
/// so there is nothing to match up and nothing to get wrong.
///
/// What comes out is a list of arc indices, not new geometry: the shape that
/// ships is still the font's exact medial axis, so a shaky finger costs
/// nothing. Nothing is written to disk from here — the order is a few dozen
/// characters of JSON that goes to `tools/orders.json`, and
/// `tools/trace_letter.py` turns it into the letter's stroke data.
///
/// A whole category is authored in one sitting: **Keep** files the letter's
/// order and moves to the next one still missing, and **Export all** emits
/// every order kept, as one `tools/orders.json` object. Eighteen letters is
/// eighteen chances to lose a clipboard, so each Keep also prints its own
/// entry to the console as it happens — nothing is held only in memory.
///
/// Dev tooling. Never reachable from a child-facing screen.
class AuthoringScreen extends ConsumerStatefulWidget {
  /// Which letters this session covers, by skeleton id. Null means all of
  /// them; a letter list passes its own, so the tool opens on the category
  /// being worked on rather than on all 31.
  final List<String>? letterIds;

  /// What the session is called, for the header.
  final String? title;

  const AuthoringScreen({super.key, this.letterIds, this.title});

  @override
  ConsumerState<AuthoringScreen> createState() => _AuthoringScreenState();
}

class _AuthoringScreenState extends ConsumerState<AuthoringScreen>
    with SingleTickerProviderStateMixin {
  String? _letterId;
  final List<List<Offset>> _ink = [];

  /// Orders kept so far this sitting, in the order they were kept.
  final Map<String, AuthoredOrder> _kept = {};

  OrderSolution? _solution;
  AuthoredOrder? _order;
  List<List<Offset>>? _preview;
  PreviewTimeline? _timeline;

  late final AnimationController _replay = AnimationController(vsync: this);

  @override
  void dispose() {
    _replay.dispose();
    super.dispose();
  }

  void _selectLetter(String letterId) {
    setState(() {
      _letterId = letterId;
      _clear();
    });
  }

  void _clear() {
    _ink.clear();
    _solution = null;
    _order = null;
    _preview = null;
    _timeline = null;
    _replay.stop();
    _replay.value = 0;
  }

  void _derive(GlyphSkeleton skeleton, AuthoringConfig config) {
    final solution =
        OrderSolver(skeleton: skeleton, config: config.snap).solve(_ink);
    final order = AuthoredOrder.fromSolution(skeleton, solution);
    final preview = order.compose(skeleton, config.snap.closedArcRatio);
    final timeline = PreviewTimeline(preview.length, config.preview);

    setState(() {
      _solution = solution;
      _order = order;
      _preview = preview;
      _timeline = timeline;
    });

    // Reading the order off a list of numbers is exactly the mistake that
    // shipped a doubled-back stroke on அ. Watch it instead.
    if (preview.isNotEmpty) {
      _replay
        ..duration = timeline.total
        ..forward(from: 0);
    }
  }

  /// File this letter's order and move to the next one still missing.
  ///
  /// The console line goes out now rather than at the end: an order held only
  /// in memory is one crash away from being redrawn, and redrawing is the
  /// expensive part.
  void _keep(AuthoredOrder order, List<SkeletonIndexEntry> index) {
    debugPrint('=== kept: ${order.letterId} ${order.char} — ${order.summary}');
    debugPrint(order.toPrettyJson());
    setState(() {
      _kept[order.letterId] = order;
      _clear();
      _letterId = _nextUnkept(index) ?? order.letterId;
    });
  }

  String? _nextUnkept(List<SkeletonIndexEntry> index) {
    final start = index.indexWhere((e) => e.letterId == _letterId);
    for (var i = 1; i <= index.length; i++) {
      final entry = index[(start + i) % index.length];
      if (!_kept.containsKey(entry.letterId)) return entry.letterId;
    }
    return null;
  }

  /// Every order kept this sitting, as one `tools/orders.json` object.
  Future<void> _exportAll() async {
    final merged = <String, dynamic>{};
    for (final order in _kept.values) {
      merged.addAll(order.toJson());
    }
    final json = const JsonEncoder.withIndent('  ').convert(merged);
    // The console is the path of least friction: the screen runs under
    // `flutter run`, so this lands in the terminal next to the editor where
    // tools/orders.json is waiting.
    //
    // Printed a line at a time, not as one block. debugPrint throttles, and a
    // whole category's worth of pretty JSON is far past what survives it —
    // the first Export all of 18 mei letters came out cut off mid-way
    // through the seventeenth. Individual lines get through.
    debugPrint('=== authored orders: ${_kept.keys.join(', ')} ===');
    for (final line in json.split('\n')) {
      debugPrint(line);
    }
    await Clipboard.setData(ClipboardData(text: json));
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${_kept.length} order${_kept.length == 1 ? '' : 's'} '
            '— copied, paste into tools/orders.json'),
        content: SingleChildScrollView(child: SelectableText(json)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(configServiceProvider);
    final indexAsync = ref.watch(skeletonIndexProvider);

    final error = configAsync.error ?? indexAsync.error;
    if (error != null) {
      return Scaffold(body: Center(child: Text('Failed to load: $error')));
    }
    if (!configAsync.hasValue || !indexAsync.hasValue) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final config = configAsync.requireValue;
    final wanted = widget.letterIds;
    final index = wanted == null
        ? indexAsync.requireValue
        : [
            for (final id in wanted)
              ...indexAsync.requireValue.where((e) => e.letterId == id),
          ];
    if (index.isEmpty) {
      return const Scaffold(body: Center(child: Text('No skeletons for these letters')));
    }

    final colors = config.theme.colors;
    final letterId = _letterId ?? index.first.letterId;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            _SessionBar(
              title: widget.title ?? 'All letters',
              kept: _kept.length,
              total: index.length,
              colors: colors,
              onExportAll: _kept.isEmpty ? null : _exportAll,
            ),
            Expanded(
              child: Row(
                children: [
                  _LetterPicker(
                    entries: index,
                    selected: letterId,
                    kept: _kept.keys.toSet(),
                    colors: colors,
                    onSelect: _selectLetter,
                  ),
                  Expanded(child: _buildBody(letterId, index, config.authoring, colors)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(String letterId, List<SkeletonIndexEntry> index,
      AuthoringConfig authoring, ThemeColors colors) {
    final skeletonAsync = ref.watch(skeletonProvider(letterId));
    if (skeletonAsync.hasError) {
      return Center(child: Text('Failed to load $letterId: ${skeletonAsync.error}'));
    }
    if (!skeletonAsync.hasValue) {
      return const Center(child: CircularProgressIndicator());
    }
    final skeleton = skeletonAsync.requireValue;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colors.canvasBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: AnimatedBuilder(
              animation: _replay,
              builder: (context, _) => AuthoringCanvas(
                skeleton: skeleton,
                ink: _ink,
                preview: _preview,
                previewProgress: _replay.value,
                timeline: _timeline,
                canvasConfig: authoring.canvas,
                colors: colors,
                onPointerDown: (p) => setState(() {
                  if (_preview != null) _clear();
                  _ink.add([p]);
                }),
                onPointerMove: (p) => setState(() {
                  if (_ink.isNotEmpty) _ink.last.add(p);
                }),
              ),
            ),
          ),
        ),
        SizedBox(
          width: 280,
          child: _SidePanel(
            skeleton: skeleton,
            inkStrokeCount: _ink.length,
            solution: _solution,
            order: _order,
            keptOrder: _kept[letterId],
            snap: authoring.snap,
            colors: colors,
            onDerive: _ink.isEmpty ? null : () => _derive(skeleton, authoring),
            onUndo: _ink.isEmpty ? null : () => setState(() => _clearLast()),
            onClear: _ink.isEmpty ? null : () => setState(_clear),
            onReplay: _preview == null ? null : () => _replay.forward(from: 0),
            onKeep: _order == null || _order!.isEmpty ? null : () => _keep(_order!, index),
          ),
        ),
      ],
    );
  }

  void _clearLast() {
    if (_ink.isNotEmpty) _ink.removeLast();
    _solution = null;
    _order = null;
    _preview = null;
    _timeline = null;
  }
}

/// How far through the category this sitting has got, and the one button
/// that ends it.
class _SessionBar extends StatelessWidget {
  final String title;
  final int kept;
  final int total;
  final ThemeColors colors;
  final VoidCallback? onExportAll;

  const _SessionBar({
    required this.title,
    required this.kept,
    required this.total,
    required this.colors,
    required this.onExportAll,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded),
            color: colors.textPrimary,
          ),
          const SizedBox(width: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : kept / total,
                minHeight: 8,
                backgroundColor: colors.starEmpty,
                valueColor: AlwaysStoppedAnimation(colors.success),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$kept / $total kept',
            style: TextStyle(fontSize: 13, color: colors.textSecondary),
          ),
          const SizedBox(width: 12),
          _Action(
            label: 'Export all',
            onTap: onExportAll,
            colors: colors,
            primary: true,
          ),
        ],
      ),
    );
  }
}

class _LetterPicker extends StatelessWidget {
  final List<SkeletonIndexEntry> entries;
  final String selected;
  final Set<String> kept;
  final ThemeColors colors;
  final ValueChanged<String> onSelect;

  const _LetterPicker({
    required this.entries,
    required this.selected,
    required this.kept,
    required this.colors,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      child: ListView.builder(
        itemCount: entries.length,
        itemBuilder: (context, i) {
          final entry = entries[i];
          final isSelected = entry.letterId == selected;
          final isKept = kept.contains(entry.letterId);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            child: Material(
              color: isSelected ? colors.primary : colors.canvasBackground,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => onSelect(entry.letterId),
                child: SizedBox(
                  height: 48,
                  // The tick is what makes eighteen letters trackable at a
                  // glance: which are done, and which the sitting still owes.
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        entry.char,
                        style: TextStyle(
                          fontSize: 24,
                          color: isSelected ? colors.canvasBackground : colors.textPrimary,
                        ),
                      ),
                      if (isKept)
                        Align(
                          alignment: Alignment.topRight,
                          child: Icon(
                            Icons.check_circle_rounded,
                            size: 14,
                            color: colors.success,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SidePanel extends StatelessWidget {
  final GlyphSkeleton skeleton;
  final int inkStrokeCount;
  final OrderSolution? solution;
  final AuthoredOrder? order;

  /// What was already kept for this letter, if it has been drawn once
  /// already. Redrawing a letter is how a bad order gets fixed, so the panel
  /// says what it would replace.
  final AuthoredOrder? keptOrder;
  final SnapConfig snap;
  final ThemeColors colors;
  final VoidCallback? onDerive;
  final VoidCallback? onUndo;
  final VoidCallback? onClear;
  final VoidCallback? onReplay;
  final VoidCallback? onKeep;

  const _SidePanel({
    required this.skeleton,
    required this.inkStrokeCount,
    required this.solution,
    required this.order,
    required this.keptOrder,
    required this.snap,
    required this.colors,
    required this.onDerive,
    required this.onUndo,
    required this.onClear,
    required this.onReplay,
    required this.onKeep,
  });

  @override
  Widget build(BuildContext context) {
    final gaps = order == null
        ? const <OrderGap>[]
        : order!.discontinuities(skeleton, snap.maxJoinGap, snap.closedArcRatio);

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${skeleton.char}   ${skeleton.letterId}',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
          Text(
            '${skeleton.arcs.length} arcs · ${skeleton.componentCount} '
            'piece${skeleton.componentCount == 1 ? '' : 's'} · '
            '$inkStrokeCount drawn',
            style: TextStyle(fontSize: 12, color: colors.textSecondary),
          ),
          if (keptOrder != null)
            Text(
              'kept: ${keptOrder!.summary}',
              style: TextStyle(fontSize: 11, color: colors.success),
            ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _Action(label: 'Derive', onTap: onDerive, colors: colors, primary: true),
              _Action(label: 'Replay', onTap: onReplay, colors: colors),
              _Action(label: 'Undo', onTap: onUndo, colors: colors),
              _Action(label: 'Clear', onTap: onClear, colors: colors),
              _Action(
                label: keptOrder == null ? 'Keep →' : 'Replace →',
                onTap: onKeep,
                colors: colors,
                primary: true,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: _Report(
                skeleton: skeleton,
                solution: solution,
                order: order,
                gaps: gaps,
                colors: colors,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Report extends StatelessWidget {
  final GlyphSkeleton skeleton;
  final OrderSolution? solution;
  final AuthoredOrder? order;
  final List<OrderGap> gaps;
  final ThemeColors colors;

  const _Report({
    required this.skeleton,
    required this.solution,
    required this.order,
    required this.gaps,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final current = solution;
    if (current == null) {
      return Text(
        'Draw the letter over the tube, lifting your finger between strokes. '
        'The numbers are the arc indices tools/glyph_skeleton.py prints.',
        style: TextStyle(fontSize: 12, color: colors.textSecondary),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText(
          order!.summary.isEmpty ? '(nothing recognised)' : order!.summary,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'R = drawn against the arc\'s stored direction.',
          style: TextStyle(fontSize: 11, color: colors.textSecondary),
        ),
        const SizedBox(height: 12),
        // A gap means the pen would have to jump mid-stroke, which is only
        // ever a missing piece. Loudest of the three for that reason.
        if (gaps.isNotEmpty)
          _Note(
            colors: colors,
            tone: colors.retry,
            title: 'Pen jumps ${gaps.length}x mid-stroke',
            body: gaps
                .map((g) => 'stroke ${g.strokeIndex + 1} before step '
                    '${g.stepIndex + 1} — ${g.distance.toStringAsFixed(3)}')
                .join('\n'),
          ),
        if (current.unvisitedArcs.isNotEmpty)
          _Note(
            colors: colors,
            tone: colors.retry,
            title: 'Arcs never drawn',
            body: current.unvisitedArcs.join(', '),
          ),
        if (current.ignoredCrossings.isNotEmpty)
          _Note(
            colors: colors,
            tone: colors.textSecondary,
            title: '${current.ignoredCrossings.length} crossings ignored',
            body: (current.ignoredCrossings.toList()
                  ..sort((a, b) => b.coverage.compareTo(a.coverage)))
                .take(6)
                .map((v) => 'arc ${v.arcIndex} — '
                    '${(v.coverage * 100).round()}% covered')
                .join('\n'),
          ),
        if (current.strandedSamples > 0)
          _Note(
            colors: colors,
            tone: colors.textSecondary,
            title: '${current.strandedSamples} of ${current.totalSamples} '
                'samples off the letter',
            body: skeleton.componentCount > 1
                ? 'Expected — ${skeleton.char} is in '
                    '${skeleton.componentCount} pieces.'
                : 'This letter is one piece, so the finger should not have '
                    'left it.',
          ),
        if (gaps.isEmpty &&
            current.unvisitedArcs.isEmpty &&
            !current.isEmpty)
          _Note(
            colors: colors,
            tone: colors.success,
            title: 'Every arc accounted for',
            body: 'Watch the replay before exporting — direction and order '
                'are what a still picture cannot show.',
          ),
      ],
    );
  }
}

class _Note extends StatelessWidget {
  final ThemeColors colors;
  final Color tone;
  final String title;
  final String body;

  const _Note({
    required this.colors,
    required this.tone,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: tone,
            ),
          ),
          Text(body, style: TextStyle(fontSize: 11, color: colors.textSecondary)),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final ThemeColors colors;
  final bool primary;

  const _Action({
    required this.label,
    required this.onTap,
    required this.colors,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: primary ? colors.primary : colors.canvasBackground,
          foregroundColor: primary ? colors.canvasBackground : colors.textPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          textStyle: const TextStyle(fontSize: 13),
        ),
        onPressed: onTap,
        child: Text(label),
      ),
    );
  }
}
