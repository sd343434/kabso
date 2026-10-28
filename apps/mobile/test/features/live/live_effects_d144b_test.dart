// D144b: on the owner's phone (staging APK incl. D157) background blur said
// «جارٍ تشغيل المؤثر…» for ever; the overlay read `DeepAR initializing …
// in 0 fed 0 out 0 … init no #1 on track`: the processor was on a track and
// DeepAR was created, but not one camera frame reached it, and no safety net
// fired. These tests pin the app's half of the fix: one camera at a time (a
// camera opened while another is still open is a shared track the processor
// never sees), a late stop never frees the next camera's processor, effect +
// filter + fill light all reach the processor on the live camera's track,
// and an effect that never starts is reported within seconds.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_camera_fx/kabso_camera_fx.dart';
import 'package:kabso_live/features/live/data/beauty/live_ar_effect.dart';
import 'package:kabso_live/features/live/data/beauty/live_beauty.dart';
import 'package:kabso_live/features/live/data/beauty/live_camera_fx.dart';
import 'package:kabso_live/features/live/data/beauty/live_color_filter.dart';
import 'package:kabso_live/features/live/data/live_camera_gate.dart';
import 'package:kabso_live/features/live/data/live_media_engine.dart';
import 'package:kabso_live/features/live/presentation/go_live/go_live_parts.dart';
import 'package:kabso_live/features/live/presentation/live_fx_diagnostics.dart';
import 'package:kabso_live/l10n/gen/app_localizations_ar.dart';
import 'package:kabso_live/l10n/gen/app_localizations_en.dart';
import 'package:livekit_client/livekit_client.dart' as lk;

/// The native plugin as `KabsoCameraFxPlugin.kt` behaves: one processor for
/// the whole app, on at most one track; frames reach it only from that
/// track; `release` with a track id only frees it if it is still there.
class _Native {
  String? attachedTrack;
  List<double>? matrix;
  String? effect;
  bool licence = false;

  /// The live camera's track (the one the capturer's frames go through).
  String? cameraTrack;

  /// What the effect stage would see: frames, a matrix and an effect.
  bool get framesReachStage =>
      attachedTrack != null && attachedTrack == cameraTrack;

  void release(String? trackId) {
    if (trackId != null && attachedTrack != null && attachedTrack != trackId) {
      return;
    }
    attachedTrack = null;
    matrix = null;
    effect = null;
  }
}

class _Bridge implements KabsoCameraFx {
  new(this.native);

  final _Native native;
  final StreamController<KabsoCameraFxStatus> statuses =
      StreamController.broadcast(sync: true);

  @override
  bool get isSupported => true;

  @override
  Future<bool> attach(String trackId) async {
    native.attachedTrack = trackId;
    return true;
  }

  @override
  Future<void> setColorMatrix(List<double>? matrix) async =>
      native.matrix = matrix;

  @override
  Future<bool> setLicenseKey(String licenseKey) async => native.licence = true;

  @override
  Future<void> setEffect(String? effect) async => native.effect = effect;

  @override
  Future<void> release({String? trackId}) async => native.release(trackId);

  @override
  Stream<KabsoCameraFxStatus> get statusChanges => statuses.stream;

  @override
  Future<KabsoCameraFxDiagnostics?> diagnostics() async => null;
}

const _all = LiveBeauty(
  effect: LiveArEffect.backgroundBlur,
  filter: LiveColorFilter.warm,
  light: LiveFillLight.high,
);

void main() {
  tearDown(LiveCameraGate.reset);

  group('effect + colour filter + fill light on the live camera', () {
    test('all three reach the processor on the camera track the frames go '
        'through', () async {
      final native = _Native()..cameraTrack = 'cam-1';
      final fx = LiveCameraFx(bridge: _Bridge(native), licenseKey: 'k');
      await fx.update(_all);
      await fx.attach('cam-1');
      expect(native.framesReachStage, isTrue);
      expect(native.effect, KabsoCameraFxEffects.backgroundBlur);
      expect(native.licence, isTrue);
      // D157: the light and the filter are one matrix (light first).
      expect(
        native.matrix,
        liveColorMatrix(LiveColorFilter.warm, LiveFillLight.high),
      );
      expect(
        native.matrix,
        isNot(liveColorMatrix(LiveColorFilter.warm, LiveFillLight.off)),
      );
    });

    test('the last go-live stopping late never takes the processor off the '
        "next go-live's camera", () async {
      final native = _Native();
      final old = LiveCameraFx(bridge: _Bridge(native), licenseKey: 'k');
      await old.attach('cam-1');
      await old.update(_all);

      // The screen was closed and opened again: a new engine, a new camera.
      native.cameraTrack = 'cam-2';
      final next = LiveCameraFx(bridge: _Bridge(native), licenseKey: 'k');
      await next.update(_all);
      await next.attach('cam-2');
      // …and only now does the old engine's stop reach the processor.
      await old.release();

      expect(native.framesReachStage, isTrue);
      expect(native.effect, KabsoCameraFxEffects.backgroundBlur);
      expect(native.matrix, isNotNull);

      // Its own camera's stop frees it.
      await next.release();
      expect(native.attachedTrack, isNull);
    });
  });

  group('one camera at a time', () {
    testWidgets('a start waits for a camera still being stopped', (
      tester,
    ) async {
      final stopped = Completer<void>();
      unawaited(LiveCameraGate.stopping(() => stopped.future));
      var idle = false;
      unawaited(LiveCameraGate.idle().then((_) => idle = true));
      await tester.pump(const Duration(seconds: 1));
      expect(LiveCameraGate.busy, isTrue);
      expect(idle, isFalse);
      stopped.complete();
      await tester.pump();
      expect(idle, isTrue);
      expect(LiveCameraGate.busy, isFalse);
    });

    testWidgets('a stop that hangs does not keep the camera off for ever', (
      tester,
    ) async {
      unawaited(LiveCameraGate.stopping(() => Completer<void>().future));
      var idle = false;
      unawaited(LiveCameraGate.idle().then((_) => idle = true));
      await tester.pump(const Duration(seconds: 3));
      expect(idle, isFalse);
      await tester.pump(const Duration(seconds: 2));
      expect(idle, isTrue);
    });

    testWidgets('a failing stop still frees the camera', (tester) async {
      final stop = LiveCameraGate.stopping(
        () => Future<void>.error(StateError('trackDispose failed')),
      );
      await expectLater(stop, throwsStateError);
      await tester.pump();
      expect(LiveCameraGate.busy, isFalse);
    });

    group('the engine', () {
      final opened = <Completer<lk.LocalVideoTrack>>[];

      setUp(() {
        opened.clear();
        // D160 probes the camera for 1080p before opening it; not under test.
        LiveKitMediaEngine.hdProbe = ({required front}) async => null;
        LiveKitMediaEngine.createCamera = (_) {
          final camera = Completer<lk.LocalVideoTrack>();
          opened.add(camera);
          return camera.future;
        };
      });
      final probe = LiveKitMediaEngine.hdProbe;
      tearDown(() {
        LiveKitMediaEngine.createCamera = lk.LocalVideoTrack.createCameraTrack;
        LiveKitMediaEngine.hdProbe = probe;
      });

      testWidgets('does not open the camera while the last go-live is still '
          'stopping its own', (tester) async {
        final lastStop = Completer<void>();
        unawaited(LiveCameraGate.stopping(() => lastStop.future));
        final engine = LiveKitMediaEngine();
        final start = engine.startPreview();
        await tester.pump(const Duration(milliseconds: 500));
        expect(opened, isEmpty);
        lastStop.complete();
        await tester.pump();
        expect(opened, hasLength(1));
        opened.single.completeError(StateError('no camera in tests'));
        await expectLater(start, throwsA(isA<LiveCaptureException>()));
      });

      testWidgets('two overlapping starts open the camera one after the '
          'other, never twice at once', (tester) async {
        final engine = LiveKitMediaEngine();
        final first = engine.startPreview();
        final second = engine.startPreview();
        await tester.pump();
        expect(opened, hasLength(1));
        opened.single.completeError(StateError('no camera in tests'));
        await expectLater(first, throwsA(isA<LiveCaptureException>()));
        await tester.pump();
        expect(opened, hasLength(2));
        opened.last.completeError(StateError('no camera in tests'));
        await expectLater(second, throwsA(isA<LiveCaptureException>()));
      });
    });
  });

  group('an effect that never starts is reported', () {
    testWidgets('no word from the native side (no frames, no status): '
        'unavailable after ${LiveCameraFx.startTimeout.inSeconds} s, and the '
        'effect going back to None keeps the reason', (tester) async {
      final native = _Native()..cameraTrack = 'cam-1';
      final bridge = _Bridge(native);
      final fx = LiveCameraFx(bridge: bridge, licenseKey: 'k');
      await fx.attach('cam-1');
      await fx.update(_all);
      bridge.statuses.add(
        const KabsoCameraFxStatus(KabsoCameraFxState.initializing),
      );
      expect(fx.status.value.state, LiveArState.starting);

      await tester.pump(
        LiveCameraFx.startTimeout - const Duration(milliseconds: 100),
      );
      expect(fx.status.value.state, LiveArState.starting);
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        fx.status.value,
        const LiveArStatus(
          LiveArState.unavailable,
          problem: LiveArProblem.failed,
          code: LiveCameraFx.startTimeoutCode,
        ),
      );

      // The host controller sets None; the native side says off.
      await fx.update(_all.copyWith(effect: LiveArEffect.none));
      expect(native.effect, isNull);
      bridge.statuses.add(KabsoCameraFxStatus.off);
      expect(fx.status.value.problem, LiveArProblem.failed);

      // Picking it again starts over.
      await fx.update(_all);
      bridge.statuses.add(
        const KabsoCameraFxStatus(KabsoCameraFxState.initializing),
      );
      expect(fx.status.value.state, LiveArState.starting);
      // (StreamSubscription.cancel's future completes outside fake time.)
      await tester.runAsync(fx.release);
    });

    testWidgets('the native start watch (no frames in 10 s) is shown as it '
        'says; the backstop stays quiet', (tester) async {
      final native = _Native()..cameraTrack = 'cam-1';
      final bridge = _Bridge(native);
      final fx = LiveCameraFx(bridge: bridge, licenseKey: 'k');
      await fx.attach('cam-1');
      await fx.update(_all);
      await tester.pump(const Duration(seconds: 10));
      bridge.statuses.add(
        const KabsoCameraFxStatus(KabsoCameraFxState.error, 'no_frames'),
      );
      await tester.pump(const Duration(seconds: 5));
      expect(
        fx.status.value,
        const LiveArStatus(
          LiveArState.unavailable,
          problem: LiveArProblem.failed,
          code: 'no_frames',
        ),
      );
      await tester.runAsync(fx.release);
    });

    testWidgets('an effect that starts in time is never reported', (
      tester,
    ) async {
      final native = _Native()..cameraTrack = 'cam-1';
      final bridge = _Bridge(native);
      final fx = LiveCameraFx(bridge: bridge, licenseKey: 'k');
      await fx.attach('cam-1');
      await fx.update(_all);
      await tester.pump(const Duration(seconds: 2));
      bridge.statuses.add(const KabsoCameraFxStatus(KabsoCameraFxState.ready));
      await tester.pump(const Duration(seconds: 30));
      expect(fx.status.value.state, LiveArState.running);
      await tester.runAsync(fx.release);
    });

    test("Magic's line for no_frames and the backstop: it did not start "
        '(ar, en)', () {
      for (final code in ['no_frames', LiveCameraFx.startTimeoutCode]) {
        final status = LiveArStatus(
          LiveArState.unavailable,
          problem: LiveArProblem.failed,
          code: code,
        );
        final ar = AppLocalizationsAr();
        final en = AppLocalizationsEn();
        expect(
          liveEffectStatusText(ar, status),
          ar.liveEffectUnavailableFailed,
        );
        expect(
          liveEffectStatusText(en, status),
          en.liveEffectUnavailableFailed,
        );
      }
      expect(
        LiveArStatus.from(
          const KabsoCameraFxStatus(KabsoCameraFxState.error, 'no_frames'),
        ).problem,
        LiveArProblem.failed,
      );
    });

    test('the overlay names camera frames into the processor and the frame '
        'path', () {
      final lines = liveFxDiagnosticsLines(
        const KabsoCameraFxDiagnostics(
          status: KabsoCameraFxStatus(KabsoCameraFxState.error, 'no_frames'),
          licencePresent: true,
          attached: true,
          instances: 1,
          framePath: 'rebound',
        ),
        LiveArStatus.off,
      );
      expect(lines.first, 'DeepAR  error (no_frames)  licence yes');
      expect(lines, contains('camera 0  path rebound'));
    });
  });
}
