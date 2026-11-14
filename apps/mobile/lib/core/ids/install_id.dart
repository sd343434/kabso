import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/ids/client_id.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// v1.74-social (D217, CONVENTIONS §10.71): a random id for this install of
/// the app (`DeviceInfo.installId`), kept in the app's preferences until it is
/// uninstalled. Sent at sign-in, sign-up and with a later invite code; the
/// server uses it only for the referral fraud checks (one reward per device,
/// no self-referral). Not a hardware id.
///
/// Null only without preferences (the app always provides them at start;
/// widget tests that do not): then no id is sent, as from an older app.
final installIdProvider = Provider<String?>((ref) {
  final SharedPreferences prefs;
  try {
    prefs = ref.watch(sharedPreferencesProvider);
  } on Object {
    return null;
  }
  final saved = prefs.getString(PreferenceKeys.installId);
  if (saved != null && RegExp(r'^[A-Za-z0-9-]{8,64}$').hasMatch(saved)) {
    return saved;
  }
  final id = newClientId();
  // Best effort: a failed write gives another id next launch.
  prefs.setString(PreferenceKeys.installId, id).ignore();
  return id;
});
