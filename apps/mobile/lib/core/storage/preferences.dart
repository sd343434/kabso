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

  /// D129: the live hub's last kind filter on this device (`audio` /
  /// `video`). D131: no longer read or written (the hub lists video lives;
  /// the party button opens the voice rooms). A value saved by an older
  /// build is left alone and ignored. Not sensitive.
  static const liveHubKind = 'pref.liveHubKind';

  /// D145d: the app's sound effects on (default) or off. Not sensitive.
  static const soundEffects = 'pref.soundEffects';

  /// D152: the notification permission's rationale was shown once (it is
  /// never shown by itself again; Settings offers it). Not sensitive.
  static const pushPermissionAsked = 'pref.pushPermissionAsked';
}
