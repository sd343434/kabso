import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// D86: demo data exists only in test builds. In release builds this is a
/// compile-time `false`, so every demo branch and fixture is tree-shaken.
const bool kDemoAvailable = !kReleaseMode;

/// D86 (owner): "Demo data" — test builds can show the designed screens
/// with labelled test data (names carry "(test)") where no API exists yet,
/// and without a server or an account. Off by default; a test build can
/// start with it on through `--dart-define=KABSO_DEMO=true`. Release
/// builds always read `false`.
class DemoModeController extends Notifier<bool> {
  static const _key = 'pref.demoData';
  static const _startOn = bool.fromEnvironment('KABSO_DEMO');

  @override
  bool build() {
    if (!kDemoAvailable) return false;
    final SharedPreferences prefs;
    try {
      prefs = ref.watch(sharedPreferencesProvider);
    } on Object {
      // No preferences (widget tests that do not provide them): off.
      return false;
    }
    return prefs.getBool(_key) ?? _startOn;
  }

  Future<void> set({required bool enabled}) async {
    if (!kDemoAvailable) return;
    state = enabled;
    await ref.read(sharedPreferencesProvider).setBool(_key, enabled);
  }
}

final demoModeProvider = NotifierProvider<DemoModeController, bool>(
  DemoModeController.new,
);

/// Whether demo data is on (watching it, so a source rebuilds when the
/// switch changes).
bool watchDemo(Ref ref) => kDemoAvailable && ref.watch(demoModeProvider);
