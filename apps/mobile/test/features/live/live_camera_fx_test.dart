import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_camera_fx/kabso_camera_fx.dart';
import 'package:kabso_live/features/live/data/beauty/live_ar_effect.dart';
import 'package:kabso_live/features/live/data/beauty/live_beauty.dart';
import 'package:kabso_live/features/live/data/beauty/live_camera_fx.dart';
import 'package:kabso_live/features/live/data/beauty/live_color_filter.dart';

/// Records what reaches the native processor.
class _FakeBridge implements KabsoCameraFx {
  new({this.isSupported = true, this.attachOk = true});

  @override
  final bool isSupported;
  final bool attachOk;

  final List<String> calls = [];
  String? licenseKey;

  @override
  Future<bool> attach(String trackId) async {
    calls.add('attach:$trackId');
    return attachOk;
  }

  @override
  Future<void> setColorMatrix(List<double>? matrix) async =>
      calls.add(matrix == null ? 'color:none' : 'color:${matrix.length}');

  @override
  Future<bool> setLicenseKey(String key) async {
    calls.add('licence');
    licenseKey = key;
    return true;
  }

  @override
  Future<void> setEffect(String? effect) async =>
      calls.add('effect:${effect ?? 'none'}');

  /// D144b: the track the last release named.
  String? releasedTrack;

  @override
  Future<void> release({String? trackId}) async {
    calls.add('release');
    releasedTrack = trackId;
  }

  /// D144a: what the native side reports.
  final StreamController<KabsoCameraFxStatus> native =
      StreamController.broadcast(sync: true);

  @override
  Stream<KabsoCameraFxStatus> get statusChanges => native.stream;

  KabsoCameraFxDiagnostics? diagnosticsAnswer;

  @override
  Future<KabsoCameraFxDiagnostics?> diagnostics() async => diagnosticsAnswer;
}

void main() {
  const blur = LiveBeauty(effect: LiveArEffect.backgroundBlur);

  test('unsupported platform: nothing is called, nothing is offered', () async {
    final bridge = _FakeBridge(isSupported: false);
    final fx = LiveCameraFx(bridge: bridge, licenseKey: 'key');
    expect(fx.filtersSupported, isFalse);
    expect(fx.effects, LiveArSupport.unsupported);
    await fx.attach('t1');
    await fx.update(blur);
    await fx.release();
    expect(bridge.calls, isEmpty);
  });

  test('no licence key: colour filters work, effects never start', () async {
    final bridge = _FakeBridge();
    final fx = LiveCameraFx(bridge: bridge, licenseKey: '');
    expect(fx.filtersSupported, isTrue);
    expect(fx.effects, LiveArSupport.unlicensed);
    await fx.attach('t1');
    await fx.update(blur.copyWith(filter: LiveColorFilter.warm));
    expect(bridge.calls, contains('color:12'));
    expect(bridge.calls, isNot(contains('licence')));
    expect(bridge.calls.where((c) => c.startsWith('effect:builtin')), isEmpty);
  });

  test('the licence goes over once, before the first effect; Natural sends '
      'no matrix', () async {
    final bridge = _FakeBridge();
    final fx = LiveCameraFx(bridge: bridge, licenseKey: 'secret');
    await fx.attach('t1');
    expect(bridge.calls, ['attach:t1', 'color:none', 'effect:none']);
    bridge.calls.clear();

    await fx.update(blur);
    expect(bridge.calls, [
      'licence',
      'effect:${KabsoCameraFxEffects.backgroundBlur}',
    ]);
    expect(bridge.licenseKey, 'secret');
    bridge.calls.clear();

    await fx.update(const LiveBeauty());
    await fx.update(blur);
    expect(bridge.calls, [
      'effect:none',
      'effect:${KabsoCameraFxEffects.backgroundBlur}',
    ]);
  });

  test('a restarted track (new id) moves the processor; the same id does '
      'nothing', () async {
    final bridge = _FakeBridge();
    final fx = LiveCameraFx(bridge: bridge, licenseKey: 'k');
    await fx.attach('t1');
    await fx.attach('t1');
    await fx.attach('t2');
    expect(bridge.calls.where((c) => c.startsWith('attach')), [
      'attach:t1',
      'attach:t2',
    ]);
    expect(fx.trackId, 't2');
  });

  test('release frees the processor; the next attach brings back what was '
      'picked', () async {
    final bridge = _FakeBridge();
    final fx = LiveCameraFx(bridge: bridge, licenseKey: 'k');
    await fx.update(blur.copyWith(filter: LiveColorFilter.mono));
    await fx.attach('t1');
    await fx.release();
    expect(bridge.calls.last, 'release');
    expect(fx.trackId, isNull);
    bridge.calls.clear();

    await fx.attach('t3');
    expect(bridge.calls, [
      'attach:t3',
      'color:12',
      'licence',
      'effect:${KabsoCameraFxEffects.backgroundBlur}',
    ]);
  });

  test('an unknown track: not attached, nothing resent', () async {
    final bridge = _FakeBridge(attachOk: false);
    final fx = LiveCameraFx(bridge: bridge, licenseKey: 'k');
    await fx.attach('gone');
    expect(fx.trackId, isNull);
    expect(bridge.calls, ['attach:gone']);
  });

  test("D144a: DeepAR's reports become the effect status; a release "
      'resets it', () async {
    final bridge = _FakeBridge();
    final fx = LiveCameraFx(bridge: bridge, licenseKey: 'secret');
    expect(fx.status.value, LiveArStatus.off);
    await fx.attach('t1');
    await fx.update(blur);
    bridge.native.add(
      const KabsoCameraFxStatus(KabsoCameraFxState.initializing),
    );
    expect(fx.status.value.state, LiveArState.starting);
    bridge.native.add(const KabsoCameraFxStatus(KabsoCameraFxState.ready));
    expect(fx.status.value.state, LiveArState.running);
    bridge.native.add(
      const KabsoCameraFxStatus(KabsoCameraFxState.disabled, 'no_output'),
    );
    expect(
      fx.status.value,
      const LiveArStatus(
        LiveArState.unavailable,
        problem: LiveArProblem.stopped,
        code: 'no_output',
      ),
    );
    await fx.release();
    expect(fx.status.value, LiveArStatus.off);
    // Listening again after the next attach.
    await fx.attach('t2');
    bridge.native.add(
      const KabsoCameraFxStatus(KabsoCameraFxState.licenceFailed, 'licence'),
    );
    expect(fx.status.value.problem, LiveArProblem.licence);
  });

  test(
    'D144a: diagnostics come from the processor (null without one)',
    () async {
      final bridge = _FakeBridge()
        ..diagnosticsAnswer = const KabsoCameraFxDiagnostics(
          status: KabsoCameraFxStatus(KabsoCameraFxState.ready),
          licencePresent: true,
          framesOut: 12,
        );
      final fx = LiveCameraFx(bridge: bridge, licenseKey: 'k');
      expect((await fx.diagnostics())!.framesOut, 12);
      bridge.diagnosticsAnswer = null;
      expect(await fx.diagnostics(), isNull);
    },
  );

  test('D157: the fill light goes to the colour stage (the published '
      'picture), alone or with a filter; off sends no matrix', () async {
    final bridge = _FakeBridge();
    final fx = LiveCameraFx(bridge: bridge, licenseKey: '');
    await fx.attach('t1');
    bridge.calls.clear();
    await fx.update(const LiveBeauty(light: LiveFillLight.medium));
    expect(bridge.calls, ['color:12']);
    bridge.calls.clear();
    await fx.update(
      const LiveBeauty(
        light: LiveFillLight.medium,
        filter: LiveColorFilter.warm,
      ),
    );
    expect(bridge.calls, ['color:12']);
    bridge.calls.clear();
    await fx.update(const LiveBeauty());
    expect(bridge.calls, ['color:none']);
  });
}
