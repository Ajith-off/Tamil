import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/config/config_service.dart';
import '../../core/config/models/theme_config.dart';
import '../../data/models/letter.dart';
import '../../data/repos/word_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../services/settings_store.dart';
import '../../services/theme_selector.dart';
import '../common/guide_highlight.dart';
import '../games/game_providers.dart';
import '../letter/letter_providers.dart';
import 'certificate_score.dart';

/// The progress certificate — generated live from the same progress the
/// letter screens write, never from a stored snapshot, so it can never go
/// stale (CLAUDE.md: "updated/generated automatically based on progress").
///
/// Styled like an actual e-course certificate rather than a checklist card:
/// a name a grown-up can type in (remembered in [AppSettings.childName], so
/// it does not have to be retyped next visit), and an export button that
/// captures the certificate itself as an image and hands it to the platform
/// share sheet — "download" here means "save via whichever app the share
/// sheet offers", the same mechanism [ParentZoneScreen]'s Share row already
/// uses, rather than a second, storage-permission-hungry way of doing it.
class CertificateScreen extends ConsumerStatefulWidget {
  const CertificateScreen({super.key});

  @override
  ConsumerState<CertificateScreen> createState() => _CertificateScreenState();
}

class _CertificateScreenState extends ConsumerState<CertificateScreen> {
  final _captureKey = GlobalKey();
  late final TextEditingController _nameController = TextEditingController(
    text: ref.read(settingsStoreProvider).childName,
  );
  bool _exporting = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _onNameChanged(String value) {
    ref.read(settingsStoreProvider.notifier).setChildName(value);
  }

  Future<void> _export(String appTitle) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _exporting = true);
    try {
      final boundary =
          _captureKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/tamil_ezhuthu_certificate.png');
      await file.writeAsBytes(bytes, flush: true);

      final name = _nameController.text.trim();
      final shareText = name.isEmpty
          ? l10n.certificateShareTextNoName(appTitle)
          : l10n.certificateShareText(name, appTitle);
      if (!mounted) return;
      await Share.shareXFiles([XFile(file.path)], text: shareText);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.certificateExportFailed)));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _showHowCalculated(CertificateScore score, ThemeColors colors) {
    final l10n = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colors.canvasBackground,
        title: Text(
          l10n.certificateHowCalculated,
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.certificateHowCalculatedIntro,
                style: TextStyle(color: colors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 12),
              for (final line in score.lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _labelOf(line.achievement, l10n),
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Text(
                        l10n.certMarksFraction(
                          '${line.marks}',
                          '${line.maxMarks}',
                        ),
                        style: TextStyle(
                          color: colors.starFilled,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.done),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(configServiceProvider);
    final catalogueAsyncs = {
      for (final c in LetterCatalogue.values) c: ref.watch(lettersProvider(c)),
    };
    final wordsAsync = ref.watch(wordsProvider);

    final error =
        configAsync.error ??
        wordsAsync.error ??
        catalogueAsyncs.values
            .map((a) => a.error)
            .firstWhere((e) => e != null, orElse: () => null);
    if (error != null) {
      return Scaffold(body: Center(child: Text('Failed to load: $error')));
    }
    if (!configAsync.hasValue ||
        !wordsAsync.hasValue ||
        catalogueAsyncs.values.any((a) => !a.hasValue)) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Keeps the field in step if settings finish loading after this screen
    // has already built — but never clobbers a name mid-typing.
    ref.listen(settingsStoreProvider, (previous, next) {
      if (_nameController.text.isEmpty && next.childName.isNotEmpty) {
        _nameController.text = next.childName;
      }
    });

    final config = configAsync.requireValue;
    final colors = themeColorsOf(config, ref.watch(settingsStoreProvider));
    final l10n = AppLocalizations.of(context);
    final progress = ref.watch(progressStoreProvider);
    final cleanWords = ref.watch(gameStoreProvider).cleanWords.length;

    final score = computeCertificateScore(
      catalogues: {
        for (final entry in catalogueAsyncs.entries)
          entry.key: entry.value.requireValue,
      },
      progress: progress,
      thresholds: config.scoring.starThresholds,
      wordCount: wordsAsync.requireValue.length,
      cleanWordCount: cleanWords,
      config: config.app.certificate,
    );
    final today = DateTime.now();
    final dateText =
        '${today.day.toString().padLeft(2, '0')}/${today.month.toString().padLeft(2, '0')}/${today.year}';

    return Scaffold(
      backgroundColor: colors.background,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 0.9,
            colors: [colors.backgroundGlow, colors.background],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Row(
                  children: [
                    BackCircleButton(
                      color: colors.textSecondary,
                      background: colors.canvasBackground,
                      border: colors.starEmpty,
                    ),
                    Expanded(
                      child: Text(
                        l10n.certificate,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 44),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      RepaintBoundary(
                        key: _captureKey,
                        child: _CertificateCard(
                          score: score,
                          colors: colors,
                          l10n: l10n,
                          nameController: _nameController,
                          onNameChanged: _onNameChanged,
                          dateText: dateText,
                          onShowHowCalculated: () =>
                              _showHowCalculated(score, colors),
                          medalColor: _medalColorFor(score.total),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _exporting
                            ? null
                            : () => _export(l10n.appTitle),
                        style: FilledButton.styleFrom(
                          backgroundColor: colors.secondary,
                        ),
                        icon: _exporting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.ios_share_rounded),
                        label: Text(l10n.certificateExport),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _labelOf(CertificateAchievement achievement, AppLocalizations l10n) =>
    switch (achievement) {
      CertificateAchievement.allStarred => l10n.certAllStarred,
      CertificateAchievement.uyir => l10n.certUyir,
      CertificateAchievement.mei => l10n.certMei,
      CertificateAchievement.uyirmei => l10n.certUyirmei,
      CertificateAchievement.game => l10n.certGame,
    };

/// Bronze under 50, silver into the 50s-70s, gold in the 80s-90s, diamond
/// only at a perfect 100 — real metal colours rather than anything from
/// [ThemeColors], since bronze is bronze whichever theme is picked.
Color _medalColorFor(int total) {
  if (total >= 100) return const Color(0xFFB9E8FB); // diamond
  if (total >= 80) return const Color(0xFFFFD700); // gold
  if (total >= 50) return const Color(0xFFC0C0C8); // silver
  return const Color(0xFFCD7F32); // bronze
}

/// The certificate itself — everything inside the [RepaintBoundary] that
/// gets exported, styled like a printed certificate: a double border, a
/// medal, a name line, a body sentence, the marks breakdown, and a date and
/// signature line along the foot.
class _CertificateCard extends StatelessWidget {
  final CertificateScore score;
  final ThemeColors colors;
  final AppLocalizations l10n;
  final TextEditingController nameController;
  final ValueChanged<String> onNameChanged;
  final String dateText;
  final VoidCallback onShowHowCalculated;
  final Color medalColor;

  const _CertificateCard({
    required this.score,
    required this.colors,
    required this.l10n,
    required this.nameController,
    required this.onNameChanged,
    required this.dateText,
    required this.onShowHowCalculated,
    required this.medalColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 560),
      padding: const EdgeInsets.all(10),
      // An opaque background behind the border, not just the card inside
      // it — the exported PNG would otherwise carry a transparent margin
      // where this widget's own bounds run past the inner card.
      decoration: BoxDecoration(
        color: colors.canvasBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.starFilled, width: 6),
      ),
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 26),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colors.starFilled.withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.workspace_premium_rounded,
                  size: 52,
                  color: colors.starFilled,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.certificate,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.appTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: colors.textSecondary),
                ),
                const SizedBox(height: 20),
                Text(
                  l10n.certificateIntro,
                  style: TextStyle(fontSize: 13, color: colors.textSecondary),
                ),
                const SizedBox(height: 6),
                // The certificate's own "signature line" — typed rather than
                // printed, since nobody has entered a name yet the first time
                // this opens.
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 340),
                  child: TextField(
                    controller: nameController,
                    onChanged: onNameChanged,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      fontStyle: FontStyle.italic,
                      color: colors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: l10n.certificateNamePlaceholder,
                      hintStyle: TextStyle(
                        color: colors.textSecondary.withValues(alpha: 0.6),
                        fontStyle: FontStyle.italic,
                      ),
                      border: UnderlineInputBorder(
                        borderSide: BorderSide(color: colors.primary),
                      ),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: colors.primary),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: colors.primary, width: 2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  l10n.certificateBody(l10n.appTitle),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: colors.textPrimary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      l10n.certificateScoreLine('${score.total}'),
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        color: colors.starFilled,
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Excluded from the exported image's interactive expectations
                    // — still visible in a static PNG, but harmless there since
                    // nothing needs to be tapped on a picture.
                    IconButton(
                      onPressed: onShowHowCalculated,
                      tooltip: l10n.certificateHowCalculated,
                      icon: Icon(
                        Icons.info_outline_rounded,
                        color: colors.textSecondary,
                        size: 20,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                for (final line in score.lines) ...[
                  _CertificateLineRow(
                    line: line,
                    colors: colors,
                    label: _labelOf(line.achievement, l10n),
                  ),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 12),
                Divider(color: colors.starEmpty),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.certificateDateLabel(dateText),
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        l10n.appTitle,
                        textAlign: TextAlign.right,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w600,
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: _CertificateMedal(colors: colors, medalColor: medalColor),
          ),
        ],
      ),
    );
  }
}

/// The app icon as a medal — a ringed circle with two ribbon tails — sitting
/// in the certificate's top-right corner, separate from the trophy seal
/// centred at the top. Its colour is the tier the total score has reached
/// (bronze/silver/gold/diamond, see [_medalColorFor]) rather than a fixed
/// gold, so the medal itself tells the same story the number does.
class _CertificateMedal extends StatelessWidget {
  final ThemeColors colors;
  final Color medalColor;

  const _CertificateMedal({required this.colors, required this.medalColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.canvasBackground,
            border: Border.all(color: medalColor, width: 4),
            boxShadow: [
              BoxShadow(
                color: medalColor.withValues(alpha: 0.4),
                blurRadius: 7,
              ),
            ],
          ),
          child: ClipOval(
            child: Image.asset('assets/images/app_icon.png', fit: BoxFit.cover),
          ),
        ),
        CustomPaint(
          size: const Size(42, 20),
          painter: _RibbonPainter(medalColor),
        ),
      ],
    );
  }
}

/// Two V-notched ribbon tails hanging below the medal — plain triangles,
/// nothing fancier than `Canvas.drawPath` needs.
class _RibbonPainter extends CustomPainter {
  final Color color;

  _RibbonPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final left = Path()
      ..moveTo(size.width * 0.12, 0)
      ..lineTo(size.width * 0.44, 0)
      ..lineTo(size.width * 0.34, size.height)
      ..close();
    final right = Path()
      ..moveTo(size.width * 0.56, 0)
      ..lineTo(size.width * 0.88, 0)
      ..lineTo(size.width * 0.66, size.height)
      ..close();
    canvas.drawPath(left, paint);
    canvas.drawPath(right, paint);
  }

  @override
  bool shouldRepaint(covariant _RibbonPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _CertificateLineRow extends StatelessWidget {
  final CertificateLine line;
  final ThemeColors colors;
  final String label;

  const _CertificateLineRow({
    required this.line,
    required this.colors,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // The ring says "fully done or not" — the fraction beside it says
    // exactly how far, so early progress still reads as something rather
    // than nothing.
    return Row(
      children: [
        Icon(
          line.complete
              ? Icons.check_circle_rounded
              : Icons.radio_button_unchecked_rounded,
          color: line.complete ? colors.success : colors.starEmpty,
          size: 20,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: line.complete ? colors.textPrimary : colors.textSecondary,
              fontWeight: line.complete ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        Text(
          l10n.certMarksFraction('${line.marks}', '${line.maxMarks}'),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: line.complete ? colors.starFilled : colors.textSecondary,
          ),
        ),
      ],
    );
  }
}
