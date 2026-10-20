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

  /// Set after the first launch of this installation (see
  /// `clearSecureStorageOnFreshInstall`). Not sensitive.
  static const installed = 'pref.installed';

  /// Set while a `PATCH /me {"locale"}` still has to reach the server
  /// (PHASE1_1_SCREENS §3.4). Not sensitive.
  static const localeSyncPending = 'pref.localeSyncPending';

  /// Set once this installation has shown the welcome screen (D65): later
  /// signed-out launches go straight to login. Not sensitive.
  static const welcomeSeen = 'pref.welcomeSeen';
}
