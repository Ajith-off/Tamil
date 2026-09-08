import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'features/home/home_screen.dart';
import 'l10n/gen/app_localizations.dart';
import 'services/audio_service.dart';
import 'services/settings_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The tracing canvas wants as much width as it can get, and a child
  // holding a tablet or phone sideways has a steadier hand for writing.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await MobileAds.instance.initialize();
  // Every ad request across the app is tagged child-directed and capped at
  // General audiences — the audience here is 4-8 year olds, and this is not
  // a per-request choice (CLAUDE.md section 6's compliance checklist).
  await MobileAds.instance.updateRequestConfiguration(
    RequestConfiguration(
      tagForChildDirectedTreatment: TagForChildDirectedTreatment.yes,
      tagForUnderAgeOfConsent: TagForUnderAgeOfConsent.yes,
      maxAdContentRating: MaxAdContentRating.g,
    ),
  );
  runApp(const ProviderScope(child: TamilEzhuthuApp()));
}

class TamilEzhuthuApp extends ConsumerStatefulWidget {
  const TamilEzhuthuApp({super.key});

  @override
  ConsumerState<TamilEzhuthuApp> createState() => _TamilEzhuthuAppState();
}

/// Backgrounding the app — the system back button from the home screen, the
/// home button, switching apps — leaves the process alive for a while with
/// nothing telling the native audio player to stop, so background music kept
/// looping after a child had already left the app. [WidgetsBindingObserver]
/// is the only thing that fires regardless of which screen happens to be on
/// screen at the time, so the fix lives once here rather than in every
/// screen that starts music.
class _TamilEzhuthuAppState extends ConsumerState<TamilEzhuthuApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final audio = ref.read(audioServiceProvider);
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        audio.pauseBackgroundMusic();
        audio.stopSpeech();
      case AppLifecycleState.resumed:
        audio.resumeBackgroundMusic();
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Read from the Parent Zone's language switch rather than hardcoding
    // Tamil, so a grown-up's choice there takes effect everywhere at once.
    final locale = ref.watch(settingsStoreProvider).locale;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF8C42)),
        // Bundled so every device renders the same shapes the tracing data
        // was extracted from — see tools/trace_letter.py.
        fontFamily: 'NotoSansTamil',
      ),
      // Boots into the category picker. Games, profile and the parent zone
      // join it as they are built (CLAUDE.md section 3).
      home: const HomeScreen(),
    );
  }
}
