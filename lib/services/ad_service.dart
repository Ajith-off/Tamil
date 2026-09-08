import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../core/config/models/app_config.dart';
import '../l10n/gen/app_localizations.dart';

/// The real "Coin Earn Ad" rewarded ad for the Parent Zone (CLAUDE.md
/// section 6: "Rewarded ads in the Parent Zone only"). Non-personalised —
/// the requirement `google_mobile_ads`'s own child-directed handling exists
/// for — and gated the same way every other sound/screen in this app is:
/// the reward is paid only when AdMob itself reports the user earned it,
/// never on a guess from this side.
///
/// The AdMob app id lives in `AndroidManifest.xml`'s `APPLICATION_ID`
/// meta-data, read automatically by the SDK; only the ad unit id
/// (`ParentZoneConfig.rewardedAdUnitId`) is needed here, and it comes from
/// config rather than being typed into this file.
/// Outcome of a rewarded-ad attempt. Kept distinct from a plain `bool` so
/// [ParentZoneScreen] can tell "chose to skip" (expected, no message needed)
/// apart from "no ad to show" (a new/unfilled ad unit, or a network miss —
/// worth telling the grown-up so the row does not look silently broken).
enum AdWatchOutcome { earned, notEarned, unavailable }

class AdService {
  const AdService();

  /// Loads and shows the rewarded ad. The reward is only [AdWatchOutcome.earned]
  /// when AdMob's own `onUserEarnedReward` fires; [AdWatchOutcome.unavailable]
  /// covers a failed load or a failed show, distinct from a plain skip.
  Future<AdWatchOutcome> showRewardedAd(
    BuildContext context,
    ParentZoneConfig config,
  ) async {
    final l10n = AppLocalizations.of(context);
    var dialogOpen = true;
    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(width: 16),
            Text(l10n.adPlaying),
          ],
        ),
      ),
    ));

    void closeLoadingDialog() {
      if (!dialogOpen) return;
      dialogOpen = false;
      Navigator.of(context, rootNavigator: true).pop();
    }

    final completer = Completer<AdWatchOutcome>();
    var earned = false;
    await RewardedAd.load(
      adUnitId: config.rewardedAdUnitId,
      // Non-personalised — this app carries no accounts and no profiling,
      // and the audience is children (CLAUDE.md section 1).
      request: const AdRequest(nonPersonalizedAds: true),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          closeLoadingDialog();
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              if (!completer.isCompleted) {
                completer.complete(
                  earned ? AdWatchOutcome.earned : AdWatchOutcome.notEarned,
                );
              }
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              if (!completer.isCompleted) {
                completer.complete(AdWatchOutcome.unavailable);
              }
            },
          );
          ad.show(
            onUserEarnedReward: (ad, reward) {
              earned = true;
            },
          );
        },
        onAdFailedToLoad: (error) {
          closeLoadingDialog();
          if (!completer.isCompleted) {
            completer.complete(AdWatchOutcome.unavailable);
          }
        },
      ),
    );

    return completer.future;
  }
}
