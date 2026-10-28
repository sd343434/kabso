import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_camera_fx/kabso_camera_fx.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(KabsoCameraFx.channelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return switch (call.method) {
        'attach' || 'setLicenseKey' => true,
        _ => null,
      };
    });
  });

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('Android: every call reaches the plugin with its arguments', () async {
    final fx = KabsoCameraFx(supported: true);
    expect(await fx.attach('track-1'), isTrue);
    await fx.setColorMatrix(List<double>.filled(12, 0.5));
    expect(await fx.setLicenseKey('key'), isTrue);
    await fx.setEffect(KabsoCameraFxEffects.backgroundBlur);
    await fx.setEffect(null);
    await fx.release();
    expect(calls.map((c) => c.method), [
      'attach',
      'setColorMatrix',
      'setLicenseKey',
      'setEffect',
      'setEffect',
      'release',
    ]);
    expect(calls[0].arguments, {'trackId': 'track-1'});
    expect((calls[1].arguments as Map)['matrix'], hasLength(12));
    expect(calls[2].arguments, {'licenseKey': 'key'});
    expect(calls[3].arguments, {'effect': 'builtin:background_blur'});
    expect(calls[4].arguments, {'effect': null});
  });

  test('elsewhere: no-ops that answer false', () async {
    final fx = KabsoCameraFx(supported: false);
    expect(fx.isSupported, isFalse);
    expect(await fx.attach('t'), isFalse);
    expect(await fx.setLicenseKey('key'), isFalse);
    await fx.setColorMatrix(null);
    await fx.setEffect('x');
    await fx.release();
    expect(calls, isEmpty);
  });

  test('an empty key or track id is not sent', () async {
    final fx = KabsoCameraFx(supported: true);
    expect(await fx.attach(''), isFalse);
    expect(await fx.setLicenseKey(''), isFalse);
    expect(calls, isEmpty);
  });

  test('a matrix must have 12 values', () {
    final fx = KabsoCameraFx(supported: true);
    expect(() => fx.setColorMatrix([1, 0, 0]), throwsArgumentError);
  });

  test('no plugin registered: false, not a crash', () async {
    messenger.setMockMethodCallHandler(channel, null);
    final fx = KabsoCameraFx(supported: true);
    expect(await fx.attach('t'), isFalse);
    await fx.setEffect(null);
  });

  group('D144a status and diagnostics', () {
    Future<void> nativeSays(String method, Object? arguments) async {
      final data = const StandardMethodCodec().encodeMethodCall(
        MethodCall(method, arguments),
      );
      await messenger.handlePlatformMessage(
        KabsoCameraFx.channelName,
        data,
        (_) {},
      );
    }

    test('native status calls arrive as statuses', () async {
      final fx = KabsoCameraFx(supported: true);
      final seen = <KabsoCameraFxStatus>[];
      final sub = fx.statusChanges.listen(seen.add);
      await nativeSays('status', {'state': 'initializing', 'reason': null});
      await nativeSays('status', {'state': 'ready', 'reason': null});
      await nativeSays('status', {'state': 'disabled', 'reason': 'no_output'});
      await nativeSays('status', {'state': 'licence_failed', 'reason': 'x'});
      await nativeSays('status', {'state': 'error', 'reason': 'init_timeout'});
      await nativeSays('status', 'garbage');
      await sub.cancel();
      expect(seen, const [
        KabsoCameraFxStatus(KabsoCameraFxState.initializing),
        KabsoCameraFxStatus(KabsoCameraFxState.ready),
        KabsoCameraFxStatus(KabsoCameraFxState.disabled, 'no_output'),
        KabsoCameraFxStatus(KabsoCameraFxState.licenceFailed, 'x'),
        KabsoCameraFxStatus(KabsoCameraFxState.error, 'init_timeout'),
        KabsoCameraFxStatus.off,
      ]);
      expect(KabsoCameraFxState.disabled.isFailure, isTrue);
      expect(KabsoCameraFxState.ready.isFailure, isFalse);
      messenger.setMockMethodCallHandler(channel, null);
    });

    test('diagnostics parse every counter; no key in them', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'diagnostics');
        return {
          'state': 'ready',
          'reason': null,
          'licencePresent': true,
          'attached': true,
          'initialized': true,
          'framesIn': 300,
          'fed': 280,
          'busySkips': 20,
          'rendered': 600,
          'delivered': 590,
          'staleDropped': 300,
          'framesOut': 290,
          'timeouts': 10,
          'consecutiveMisses': 0,
          'avgWaitMs': 12.5,
          'avgPackMs': 4,
          'inFlightMs': 3,
          'instances': 1,
          'input': '1280x720@270',
          'sdkVersion': '5.6.22',
          'lastError': null,
        };
      });
      final d = (await KabsoCameraFx(supported: true).diagnostics())!;
      expect(d.status, const KabsoCameraFxStatus(KabsoCameraFxState.ready));
      expect(d.licencePresent, isTrue);
      expect(d.attached, isTrue);
      expect(d.framesIn, 300);
      expect(d.fed, 280);
      expect(d.busySkips, 20);
      expect(d.rendered, 600);
      expect(d.delivered, 590);
      expect(d.staleDropped, 300);
      expect(d.framesOut, 290);
      expect(d.timeouts, 10);
      expect(d.avgWaitMs, 12.5);
      expect(d.avgPackMs, 4.0);
      expect(d.instances, 1);
      expect(d.input, '1280x720@270');
      expect(d.sdkVersion, '5.6.22');
      expect(await KabsoCameraFx(supported: false).diagnostics(), isNull);
    });
  });

  group('D144a permissions', () {
    const permissionsChannel = MethodChannel(KabsoPermissions.channelName);
    final asked = <MethodCall>[];

    setUp(() {
      asked.clear();
      messenger.setMockMethodCallHandler(permissionsChannel, (call) async {
        asked.add(call);
        return switch (call.method) {
          'status' => {'camera': 'notAsked', 'microphone': 'granted'},
          'request' => {'camera': 'blocked', 'microphone': 'granted'},
          'openSettings' => true,
          _ => null,
        };
      });
    });

    tearDown(
      () => messenger.setMockMethodCallHandler(permissionsChannel, null),
    );

    test('status, request and settings reach the plugin', () async {
      final p = KabsoPermissions(supported: true);
      expect(
        await p.status({KabsoPermission.camera, KabsoPermission.microphone}),
        {
          KabsoPermission.camera: KabsoPermissionStatus.notAsked,
          KabsoPermission.microphone: KabsoPermissionStatus.granted,
        },
      );
      expect(await p.request({KabsoPermission.camera}), {
        KabsoPermission.camera: KabsoPermissionStatus.blocked,
      });
      expect(await p.openSettings(), isTrue);
      expect(asked.map((c) => c.method), ['status', 'request', 'openSettings']);
      expect((asked[0].arguments as Map)['kinds'], ['camera', 'microphone']);
      expect((asked[1].arguments as Map)['kinds'], ['camera']);
    });

    test('elsewhere or without the plugin: unknown, nothing asked', () async {
      final elsewhere = KabsoPermissions(supported: false);
      expect(await elsewhere.status({KabsoPermission.microphone}), {
        KabsoPermission.microphone: KabsoPermissionStatus.unknown,
      });
      expect(await elsewhere.openSettings(), isFalse);
      expect(asked, isEmpty);
      messenger.setMockMethodCallHandler(permissionsChannel, null);
      expect(
        await KabsoPermissions(supported: true)
            .request({KabsoPermission.camera}),
        {KabsoPermission.camera: KabsoPermissionStatus.unknown},
      );
    });
  });
}
