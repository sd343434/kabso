import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/features/live/application/live_host_controller.dart';
import 'package:kabso_live/features/live/data/beauty/live_fx_engine.dart';

/// D228: the developer override of the effects engine on this phone —
/// **debug and profile builds only** (`!kReleaseMode`; a release build always
/// reads null and never touches the preference). null: follow the server.
/// Kept in [PreferenceKeys.debugCameraFxEngine] so a test build keeps it
/// across restarts; set from the FX diagnostics overlay.
class LiveFxEngineOverride extends Notifier<LiveFxEngine?> {
  /// Whether this build offers the override.
  static bool get available => !kReleaseMode;

  @override
  LiveFxEngine? build() {
    if (!available) return null;
    try {
      final saved = ref
          .read(sharedPreferencesProvider)
          .getString(PreferenceKeys.debugCameraFxEngine);
      return saved == null ? null : LiveFxEngine.parse(saved);
    } on Object {
      // No preferences here (a test without them): follow the server.
      return null;
    }
  }

  /// [engine] null: back to the server's choice.
  Future<void> set(LiveFxEngine? engine) async {
    if (!available) return;
    state = engine;
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      if (engine == null) {
        await prefs.remove(PreferenceKeys.debugCameraFxEngine);
      } else {
        await prefs.setString(PreferenceKeys.debugCameraFxEngine, engine.wire);
      }
    } on Object {
      // Kept for this run only.
    }
  }
}

final NotifierProvider<LiveFxEngineOverride, LiveFxEngine?>
liveFxEngineOverrideProvider =
    NotifierProvider<LiveFxEngineOverride, LiveFxEngine?>(
      LiveFxEngineOverride.new,
    );

/// D228: the engine the host's camera uses now — the developer override
/// (debug/profile only), else the server's `LiveConfig.cameraFxEngine`
/// (DeepAR until the config arrives, and for an older server).
final Provider<LiveFxEngine> liveFxEngineProvider =
    Provider.autoDispose<LiveFxEngine>((ref) {
      final override = ref.watch(liveFxEngineOverrideProvider);
      if (override != null && LiveFxEngineOverride.available) return override;
      final config = ref.watch(liveConfigProvider).value;
      return LiveFxEngine.parse(config?.cameraFxEngine);
    });
