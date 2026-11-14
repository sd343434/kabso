// D144c: on the owner's phone (staging 739fa7c) one attempt never started
// (`init no … fed 0`, `error (init_timeout)`) and another was switched off
// as black after 2.0 s with DeepAR's «Switch effect called but DeepAR
// rendering is paused!». The native fixes are in the plugin's Kotlin tests
// (EngineSlotTest); here: what the app shows of them.

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_camera_fx/kabso_camera_fx.dart';
import 'package:kabso_live/features/live/data/beauty/live_ar_effect.dart';
import 'package:kabso_live/features/live/presentation/go_live/go_live_parts.dart';
import 'package:kabso_live/features/live/presentation/live_fx_diagnostics.dart';
import 'package:kabso_live/l10n/gen/app_localizations_ar.dart';
import 'package:kabso_live/l10n/gen/app_localizations_en.dart';

void main() {
  test('the overlay: DeepAR engine state, first lit picture, held-back '
      'black renders; a warning never hides the error', () {
    final lines = liveFxDiagnosticsLines(
      const KabsoCameraFxDiagnostics(
        status: KabsoCameraFxStatus(KabsoCameraFxState.ready),
        licencePresent: true,
        attached: true,
        cameraFrames: 442,
        framePath: 'source',
        engine: 2,
        litMs: 2400,
        heldBlack: 61,
        lastError: 'black output (in 138, out 17)',
        lastWarning:
            'WARNING: Switch effect called but DeepAR rendering is paused!',
      ),
      LiveArStatus.off,
    );
    expect(lines, contains('camera 442  path source  engine 2'));
    expect(lines, contains('lit 2400 ms  held 61'));
    expect(lines, contains('err black output (in 138, out 17)'));
    expect(
      lines.last,
      'warn WARNING: Switch effect called but DeepAR rendering is paused!',
    );
  });

  test('nothing lit yet and no DeepAR: dashes, not zeros', () {
    final lines = liveFxDiagnosticsLines(
      const KabsoCameraFxDiagnostics(
        status: KabsoCameraFxStatus(KabsoCameraFxState.initializing),
        licencePresent: true,
      ),
      LiveArStatus.off,
    );
    expect(lines, contains('camera 0  path -  engine -'));
    expect(lines, contains('lit -  held 0'));
    expect(lines.where((l) => l.startsWith('warn')), isEmpty);
  });

  test('engine_busy: Magic says the effect did not start (ar, en)', () {
    final status = LiveArStatus.from(
      const KabsoCameraFxStatus(KabsoCameraFxState.error, 'engine_busy'),
    );
    expect(status.state, LiveArState.unavailable);
    expect(status.problem, LiveArProblem.failed);
    expect(status.code, 'engine_busy');
    final ar = AppLocalizationsAr();
    final en = AppLocalizationsEn();
    expect(liveEffectStatusText(ar, status), ar.liveEffectUnavailableFailed);
    expect(liveEffectStatusText(en, status), en.liveEffectUnavailableFailed);
  });
}
