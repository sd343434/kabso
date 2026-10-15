import 'package:kabso_live/core/logging/app_logger.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Clears secure-storage tokens left over from a previous installation
/// (SEC-019).
///
/// iOS Keychain items survive app deletion, so a reinstall would otherwise
/// silently restore the old session. SharedPreferences (NSUserDefaults /
/// app-private prefs) is wiped on uninstall, so a missing
/// [PreferenceKeys.installed] flag means "first launch of this install".
///
/// The flag is written only after the clear succeeded, so a failed clear is
/// retried on the next launch. Returns `true` when stale data was cleared.
Future<bool> clearSecureStorageOnFreshInstall({
  required SharedPreferences prefs,
  required SecureTokenStore store,
}) async {
  if (prefs.getBool(PreferenceKeys.installed) ?? false) return false;
  try {
    await store.clear();
  } on Object catch (e, st) {
    AppLogger.error('Could not clear secure storage on first launch', e, st);
    return false;
  }
  await prefs.setBool(PreferenceKeys.installed, true);
  return true;
}
