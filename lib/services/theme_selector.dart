import '../core/config/config_service.dart';
import '../core/config/models/theme_config.dart';
import 'settings_store.dart';

/// The palette every screen draws with, following the home screen's
/// light/dark toggle app-wide. The control (the sun/moon button) lives only
/// on the home screen (`HomeScreen`'s theme button); every other screen just
/// reads the choice, the same way they all already read [ConfigService].
ThemeColors themeColorsOf(ConfigService config, AppSettings settings) =>
    settings.homeTheme == HomeTheme.dark ? config.theme.darkColors : config.theme.colors;
