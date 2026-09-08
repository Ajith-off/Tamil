import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/config_service.dart';
import '../../core/config/models/theme_config.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../services/ad_service.dart';
import '../../services/settings_store.dart';
import '../../services/theme_selector.dart';
import '../common/guide_highlight.dart';
import '../letter/letter_providers.dart';
import '../letters/score_badge.dart';
import 'certificate_screen.dart';

final _packageInfoProvider = FutureProvider<PackageInfo>(
  (ref) => PackageInfo.fromPlatform(),
);

/// Reached only through [ParentalGateScreen] (CLAUDE.md section 1): watching
/// an ad, opening an outbound link and exporting progress all live here, and
/// none of them is reachable without the gate first. Quitting the app lives
/// here too now — it used to be a bare button on the home screen a child
/// could tap on their own, and CLAUDE.md section 1 gates purchases, ads and
/// links but has no reason to leave quitting the one loose end.
class ParentZoneScreen extends ConsumerWidget {
  const ParentZoneScreen({super.key});

  static const _adService = AdService();

  Future<void> _watchAd(
    BuildContext context,
    WidgetRef ref,
    ThemeColors colors,
  ) async {
    final config = ref.read(configServiceProvider).requireValue.app.parentZone;
    final outcome = await _adService.showRewardedAd(context, config);
    if (!context.mounted) return;
    final l10n = AppLocalizations.of(context);
    switch (outcome) {
      case AdWatchOutcome.earned:
        ref.read(adCoinBankProvider.notifier).earn(config.adCoinsPerWatch);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.adRewardEarned),
            backgroundColor: colors.success,
          ),
        );
      case AdWatchOutcome.notEarned:
        // A deliberate skip — the row already made clear watching pays out,
        // so no extra message is needed for a choice the parent just made.
        break;
      case AdWatchOutcome.unavailable:
        // No ad to show at all (failed load/show — e.g. a new ad unit with
        // no fill yet). Worth a message: silently doing nothing here reads
        // as the feature being broken.
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.adUnavailable)));
    }
  }

  Future<void> _openLink(BuildContext context, String url) async {
    final l10n = AppLocalizations.of(context);
    final uri = Uri.tryParse(url);
    final opened =
        uri != null &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (opened || !context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.linkOpenFailed)));
  }

  Future<void> _shareApp(BuildContext context, String appShareUrl) async {
    final l10n = AppLocalizations.of(context);
    await Share.share(l10n.shareAppText(l10n.appTitle, appShareUrl));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(configServiceProvider);
    final packageInfoAsync = ref.watch(_packageInfoProvider);
    if (!configAsync.hasValue) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final config = configAsync.requireValue;
    final parentZoneConfig = config.app.parentZone;
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(settingsStoreProvider);
    final colors = themeColorsOf(config, settings);
    final settingsNotifier = ref.read(settingsStoreProvider.notifier);
    final year = '${DateTime.now().year}';
    final version = packageInfoAsync.whenOrNull(
      data: (info) => '${info.version} (${info.buildNumber})',
    );

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
                        l10n.parentZone,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    // The same running total every other screen carries, so
                    // watching an ad in the row below and seeing this number
                    // move is the confirmation it actually paid out.
                    ScoreBadge(
                      coins: ref.watch(coinBalanceProvider),
                      colors: colors,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Column(
                        children: [
                          _ParentZoneRow(
                            icon: Icons.translate_rounded,
                            iconColor: colors.primary,
                            title: l10n.settingsLanguage,
                            colors: colors,
                            trailing: _LanguageSwitch(
                              locale: settings.locale,
                              colors: colors,
                              onChanged: settingsNotifier.setLocale,
                            ),
                          ),
                          _ParentZoneRow(
                            icon: Icons.music_note_rounded,
                            iconColor: colors.secondary,
                            title: l10n.settingsMusic,
                            colors: colors,
                            trailing: Switch(
                              value: settings.musicEnabled,
                              activeThumbColor: colors.secondary,
                              onChanged: settingsNotifier.setMusicEnabled,
                            ),
                          ),
                          _ParentZoneRow(
                            icon: Icons.volume_up_rounded,
                            iconColor: colors.secondary,
                            title: l10n.settingsSound,
                            colors: colors,
                            trailing: Switch(
                              value: settings.soundEnabled,
                              activeThumbColor: colors.secondary,
                              onChanged: settingsNotifier.setSoundEnabled,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _ParentZoneRow(
                            icon: Icons.ondemand_video_rounded,
                            iconColor: colors.secondary,
                            title: l10n.watchAdEarnCoin,
                            subtitle: l10n.watchAdEarnCoinHint(
                              '${parentZoneConfig.adCoinsPerWatch}',
                            ),
                            colors: colors,
                            onTap: () => _watchAd(context, ref, colors),
                          ),
                          _ParentZoneRow(
                            icon: Icons.workspace_premium_rounded,
                            iconColor: colors.starFilled,
                            title: l10n.certificate,
                            colors: colors,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const CertificateScreen(),
                              ),
                            ),
                          ),
                          _ParentZoneRow(
                            icon: Icons.info_outline_rounded,
                            iconColor: colors.primary,
                            title: l10n.projectDetails,
                            colors: colors,
                            onTap: () => _openLink(
                              context,
                              parentZoneConfig.projectDetailsUrl,
                            ),
                          ),
                          _ParentZoneRow(
                            icon: Icons.privacy_tip_outlined,
                            iconColor: colors.primary,
                            title: l10n.privacyPolicy,
                            colors: colors,
                            onTap: () => _openLink(
                              context,
                              parentZoneConfig.privacyPolicyUrl,
                            ),
                          ),
                          _ParentZoneRow(
                            icon: Icons.share_rounded,
                            iconColor: colors.secondary,
                            title: l10n.shareApp,
                            colors: colors,
                            onTap: () => _shareApp(
                              context,
                              parentZoneConfig.appShareUrl,
                            ),
                          ),
                          _ParentZoneRow(
                            icon: Icons.info_rounded,
                            iconColor: colors.textSecondary,
                            title: l10n.versionLabel(version ?? '…'),
                            colors: colors,
                          ),
                          _ParentZoneRow(
                            icon: Icons.copyright_rounded,
                            iconColor: colors.textSecondary,
                            title: l10n.copyrightLine(year),
                            colors: colors,
                          ),
                          const SizedBox(height: 12),
                          _ParentZoneRow(
                            icon: Icons.power_settings_new_rounded,
                            iconColor: colors.retry,
                            title: l10n.quit,
                            colors: colors,
                            onTap: SystemNavigator.pop,
                          ),
                        ],
                      ),
                    ),
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

/// One entry in the Parent Zone list. Rows without [onTap] are informational
/// only — Version and Copyright are read, not tapped. A [trailing] widget
/// replaces the default chevron — the switch on the music/sound rows, the
/// segmented control on the language row.
class _ParentZoneRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final ThemeColors colors;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _ParentZoneRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    required this.colors,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Material(
        color: colors.canvasBackground,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colors.starEmpty, width: 1.5),
            ),
            child: Row(
              children: [
                Icon(icon, color: iconColor, size: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                if (trailing != null)
                  trailing!
                else if (onTap != null)
                  Icon(
                    Icons.chevron_right_rounded,
                    color: colors.textSecondary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Two buttons — தமிழ் / English — the current one filled in.
class _LanguageSwitch extends StatelessWidget {
  final Locale locale;
  final ThemeColors colors;
  final ValueChanged<Locale> onChanged;

  const _LanguageSwitch({
    required this.locale,
    required this.colors,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    Widget option(String label, Locale value) {
      final selected = locale.languageCode == value.languageCode;
      return Material(
        color: selected ? colors.secondary : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => onChanged(value),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: selected ? Colors.white : colors.textSecondary,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.starEmpty, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          option('தமிழ்', const Locale('ta')),
          option('English', const Locale('en')),
        ],
      ),
    );
  }
}
