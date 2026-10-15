import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Non-sensitive user preferences (theme, language). Never store tokens here.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in bootstrap or tests',
  ),
);

abstract final class PreferenceKeys {
  static const themeMode = 'pref.themeMode';
  static const languageCode = 'pref.languageCode';
}
