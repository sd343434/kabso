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
}
