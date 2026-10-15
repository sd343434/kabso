import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:material_ui/material_ui.dart';

/// Languages the app ships. Arabic is the fallback (RTL).
enum AppLanguage {
  ar,
  en;

  Locale get locale => Locale(name);

  AppLanguage get other => this == ar ? en : ar;

  static AppLanguage fromCode(String? code) =>
      values.firstWhere((l) => l.name == code, orElse: () => AppLanguage.ar);

  /// `ar`/`en`, or `null` for anything else.
  static AppLanguage? tryParse(String? code) {
    for (final l in values) {
      if (l.name == code) return l;
    }
    return null;
  }
}

/// The device's preferred locales, first = most preferred. Overridden in
/// tests.
final deviceLocalesProvider = Provider<List<Locale>>(
  (ref) => ui.PlatformDispatcher.instance.locales,
);

/// PHASE1_1_SCREENS §3.1 (D26): an explicit saved choice wins; otherwise
/// the device's first preferred language — `en*` → en, `ar*` → ar,
/// anything else → ar.
AppLanguage resolveAppLanguage({
  required String? savedChoice,
  required List<Locale> deviceLocales,
}) {
  final saved = AppLanguage.tryParse(savedChoice);
  if (saved != null) return saved;
  final first = deviceLocales.isEmpty ? null : deviceLocales.first;
  return switch (first?.languageCode.toLowerCase()) {
    'en' => AppLanguage.en,
    _ => AppLanguage.ar,
  };
}

/// App language. Nothing is persisted until the user explicitly chooses
/// (auth language switch or Settings), so a device-language change still
/// applies before that. Logout keeps the choice (device preference).
class LanguageController extends Notifier<AppLanguage> {
  @override
  AppLanguage build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return resolveAppLanguage(
      savedChoice: prefs.getString(PreferenceKeys.languageCode),
      deviceLocales: ref.watch(deviceLocalesProvider),
    );
  }

  /// Whether the user has explicitly chosen a language on this device.
  bool get hasExplicitChoice =>
      AppLanguage.tryParse(
        ref
            .read(sharedPreferencesProvider)
            .getString(PreferenceKeys.languageCode),
      ) !=
      null;

  /// Explicit choice: applied immediately and persisted.
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
