import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kids_tamil_ezhuthu_school/services/settings_store.dart';

/// SharedPreferences namespaces every key it stores.
const _key = 'flutter.${SettingsRepository.storageKey}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('defaults', () {
    test('Tamil, music and sound all on, light theme, no name yet', () {
      expect(AppSettings.defaults.locale.languageCode, 'ta');
      expect(AppSettings.defaults.musicEnabled, isTrue);
      expect(AppSettings.defaults.soundEnabled, isTrue);
      expect(AppSettings.defaults.homeTheme, HomeTheme.light);
      expect(AppSettings.defaults.childName, isEmpty);
    });
  });

  group('reading and writing', () {
    test('nothing saved yet reads back as the defaults', () async {
      SharedPreferences.setMockInitialValues({});

      final settings = await SettingsRepository().load();

      expect(settings.locale.languageCode, AppSettings.defaults.locale.languageCode);
      expect(settings.musicEnabled, isTrue);
      expect(settings.soundEnabled, isTrue);
    });

    test('a corrupt file opens the app with the defaults rather than not at all', () async {
      SharedPreferences.setMockInitialValues({_key: 'not json'});

      final settings = await SettingsRepository().load();

      expect(settings.locale.languageCode, AppSettings.defaults.locale.languageCode);
    });

    test('what was saved comes back on the next run', () async {
      SharedPreferences.setMockInitialValues({});
      final repository = SettingsRepository();
      await repository.save(const AppSettings(
        locale: Locale('en'),
        musicEnabled: false,
        soundEnabled: true,
        homeTheme: HomeTheme.dark,
        childName: 'Meera',
      ));

      final back = await repository.load();

      expect(back.locale.languageCode, 'en');
      expect(back.musicEnabled, isFalse);
      expect(back.soundEnabled, isTrue);
      expect(back.homeTheme, HomeTheme.dark);
      expect(back.childName, 'Meera');
    });

    test('the store hydrates from what was already on disk', () async {
      SharedPreferences.setMockInitialValues({
        _key: '{"locale":"en","musicEnabled":false,"soundEnabled":false}',
      });

      final store = SettingsStore(SettingsRepository());
      addTearDown(store.dispose);
      await Future<void>.delayed(Duration.zero);

      expect(store.state.locale.languageCode, 'en');
      expect(store.state.musicEnabled, isFalse);
      expect(store.state.soundEnabled, isFalse);
    });

    test('each setter persists without disturbing the others', () async {
      SharedPreferences.setMockInitialValues({});
      final repository = SettingsRepository();
      final store = SettingsStore(repository);
      addTearDown(store.dispose);
      await Future<void>.delayed(Duration.zero);

      store.setMusicEnabled(false);
      await Future<void>.delayed(Duration.zero);
      store.setLocale(const Locale('en'));
      await Future<void>.delayed(Duration.zero);
      store.setHomeTheme(HomeTheme.dark);
      await Future<void>.delayed(Duration.zero);
      store.setChildName('Arjun');
      await Future<void>.delayed(Duration.zero);

      final back = await repository.load();
      expect(back.musicEnabled, isFalse);
      expect(back.locale.languageCode, 'en');
      expect(back.soundEnabled, isTrue, reason: 'untouched setting must survive the others');
      expect(back.homeTheme, HomeTheme.dark);
      expect(back.childName, 'Arjun');
    });
  });
}
