import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:material_ui/material_ui.dart';

/// Languages the app ships. Arabic is the default (RTL).
enum AppLanguage {
  ar,
  en;

  Locale get locale => Locale(name);

  static AppLanguage fromCode(String? code) =>
      values.firstWhere((l) => l.name == code, orElse: () => AppLanguage.ar);
}

/// User-selected language, persisted in shared preferences.
class LanguageController extends Notifier<AppLanguage> {
  @override
  AppLanguage build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return AppLanguage.fromCode(prefs.getString(PreferenceKeys.languageCode));
  }

  Future<void> select(AppLanguage language) async {
    state = language;
    await ref
        .read(sharedPreferencesProvider)
        .setString(PreferenceKeys.languageCode, language.name);
  }
}

final languageControllerProvider =
    NotifierProvider<LanguageController, AppLanguage>(LanguageController.new);

/// User-selected theme mode. Dark is the default; "system" follows the OS.
class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final stored = prefs.getString(PreferenceKeys.themeMode);
    return ThemeMode.values.firstWhere(
      (m) => m.name == stored,
      orElse: () => ThemeMode.dark,
    );
  }

  Future<void> select(ThemeMode mode) async {
    state = mode;
    await ref
        .read(sharedPreferencesProvider)
        .setString(PreferenceKeys.themeMode, mode.name);
  }
}

final themeModeControllerProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);
