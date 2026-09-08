import 'dart:convert';
import 'dart:ui' show Locale;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The home screen's sky backdrop (`lib/features/home/sky_backdrop.dart`),
/// picked by hand rather than read off the clock — a grown-up's choice
/// beats guessing at sunrise and sunset in a timezone the device may not
/// even have set correctly.
enum HomeTheme { light, dark }

/// Language, background music, sound effects, the home screen's day/night
/// look, and the name the certificate is issued to — device preferences a
/// grown-up sets once, not something a child earns or that resets with
/// progress. Kept in its own document rather than [SavedProgress]'s, since
/// wiping progress must never silently mute the app, flip its language, or
/// forget whose certificate this is.
class AppSettings {
  final Locale locale;
  final bool musicEnabled;
  final bool soundEnabled;
  final HomeTheme homeTheme;

  /// The name printed on the progress certificate. Empty until a grown-up
  /// types one in — the certificate shows a blank line rather than a
  /// placeholder name until then.
  final String childName;

  const AppSettings({
    required this.locale,
    required this.musicEnabled,
    required this.soundEnabled,
    required this.homeTheme,
    required this.childName,
  });

  static const defaults = AppSettings(
    locale: Locale('ta'),
    musicEnabled: true,
    soundEnabled: true,
    homeTheme: HomeTheme.light,
    childName: '',
  );

  AppSettings copyWith({
    Locale? locale,
    bool? musicEnabled,
    bool? soundEnabled,
    HomeTheme? homeTheme,
    String? childName,
  }) =>
      AppSettings(
        locale: locale ?? this.locale,
        musicEnabled: musicEnabled ?? this.musicEnabled,
        soundEnabled: soundEnabled ?? this.soundEnabled,
        homeTheme: homeTheme ?? this.homeTheme,
        childName: childName ?? this.childName,
      );
}

class SettingsRepository {
  SettingsRepository();

  static const storageKey = 'settings.v1';

  Future<AppSettings> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(storageKey);
      if (raw == null || raw.isEmpty) return AppSettings.defaults;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return AppSettings(
        locale: Locale(json['locale'] as String? ?? AppSettings.defaults.locale.languageCode),
        musicEnabled: json['musicEnabled'] as bool? ?? true,
        soundEnabled: json['soundEnabled'] as bool? ?? true,
        homeTheme: (json['homeTheme'] as String?) == 'dark' ? HomeTheme.dark : HomeTheme.light,
        childName: json['childName'] as String? ?? '',
      );
    } catch (_) {
      // A settings file that cannot be read must not stop the app opening —
      // same rule ProgressRepository follows.
      return AppSettings.defaults;
    }
  }

  Future<void> save(AppSettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        storageKey,
        jsonEncode({
          'locale': settings.locale.languageCode,
          'musicEnabled': settings.musicEnabled,
          'soundEnabled': settings.soundEnabled,
          'homeTheme': settings.homeTheme == HomeTheme.dark ? 'dark' : 'light',
          'childName': settings.childName,
        }),
      );
    } catch (_) {
      // A failed write must never interrupt play.
    }
  }
}

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) => SettingsRepository());

class SettingsStore extends StateNotifier<AppSettings> {
  final SettingsRepository _repository;

  SettingsStore(this._repository) : super(AppSettings.defaults) {
    _hydrate();
  }

  Future<void> _hydrate() async {
    final saved = await _repository.load();
    if (!mounted) return;
    state = saved;
  }

  void setLocale(Locale locale) {
    state = state.copyWith(locale: locale);
    _repository.save(state);
  }

  void setMusicEnabled(bool enabled) {
    state = state.copyWith(musicEnabled: enabled);
    _repository.save(state);
  }

  void setSoundEnabled(bool enabled) {
    state = state.copyWith(soundEnabled: enabled);
    _repository.save(state);
  }

  void setHomeTheme(HomeTheme theme) {
    state = state.copyWith(homeTheme: theme);
    _repository.save(state);
  }

  void setChildName(String name) {
    state = state.copyWith(childName: name);
    _repository.save(state);
  }
}

final settingsStoreProvider = StateNotifierProvider<SettingsStore, AppSettings>((ref) {
  return SettingsStore(ref.watch(settingsRepositoryProvider));
});
