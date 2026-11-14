// D346 (CONVENTIONS §10.145): the streamer start's failures — each its own
// problem and message, the native capture check, the problem report (no
// personal data) and the keeper's start failure. No device.
import 'dart:async';
import 'dart:ui' show Locale;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/features/live/application/live_background.dart';
import 'package:kabso_live/features/live/application/streamer_diagnostics.dart';
import 'package:kabso_live/features/live/data/streamer/live_streamer_platform.dart';
import 'package:kabso_live/features/live/presentation/streamer/streamer_widgets.dart';
import 'package:kabso_live/l10n/l10n.dart';

import '../../helpers/fake_streamer_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('classification', () {
    test('Android 10+ without the mediaProjection service → serviceDenied', () {
      final f = StreamerFailure.of(
        StreamerStep.capture,
        PlatformException(
          code: 'error',
          message:
              'Media projections require a foreground service of type '
              'ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION',
          details: 'java.lang.SecurityException: Media projections require…',
        ),
      );
      expect(f.problem, StreamerProblem.serviceDenied);
      expect(
        f.errorClass,
        'PlatformException(error) java.lang.SecurityException',
      );
      expect(f.code, 'securityexception');
    });

    test('a reused consent (Android 14) → security', () {
      final f = StreamerFailure.of(
        StreamerStep.capture,
        PlatformException(
          code: 'error',
          message:
              "Don't re-use the resultData to retrieve the same projection",
          details: 'java.lang.SecurityException',
        ),
      );
      expect(f.problem, StreamerProblem.security);
    });

    test("flutter_webrtc's own refused consent → refused", () {
      final f = StreamerFailure.of(
        StreamerStep.capture,
        PlatformException(
          code: 'screenRequestPermissions',
          message: "User didn't give permission to capture the screen.",
        ),
      );
      expect(f.problem, StreamerProblem.refused);
    });

    test('other capture errors, publish errors, the service, the room', () {
      expect(
        StreamerFailure.of(StreamerStep.capture, StateError('x')).problem,
        StreamerProblem.captureFailed,
      );
      final publish = StreamerFailure.of(
        StreamerStep.publish,
        TimeoutException('publish'),
      );
      expect(publish.problem, StreamerProblem.publishFailed);
      expect(publish.code, 'timeoutexception');
      final service = StreamerFailure.of(
        StreamerStep.service,
        LiveBackgroundStartException(TimeoutException('5 s')),
      );
      expect(service.problem, StreamerProblem.serviceDenied);
      expect(
        service.errorClass,
        'LiveBackgroundStartException(TimeoutException)',
      );
      expect(
        StreamerFailure.of(StreamerStep.room, StateError('x')).problem,
        StreamerProblem.other,
      );
      // An already precise failure is kept as it is.
      final blocked = StreamerFailure.blocked('consent_used');
      expect(
        StreamerFailure.of(StreamerStep.room, StreamerStartException(blocked)),
        blocked,
      );
    });

    test('the native check reasons', () {
      expect(
        StreamerFailure.blocked('no_service').problem,
        StreamerProblem.serviceDenied,
      );
      expect(
        StreamerFailure.blocked('consent_used').problem,
        StreamerProblem.security,
      );
      expect(
        StreamerFailure.blocked('unsupported_os').problem,
        StreamerProblem.unsupportedOs,
      );
      expect(
        StreamerFailure.blocked('no_consent').problem,
        StreamerProblem.consentFailed,
      );
      expect(
        StreamerFailure.blocked('???').problem,
        StreamerProblem.captureFailed,
      );
    });

    test('every problem but «other» has its own message, ar and en', () async {
      for (final locale in const [Locale('ar'), Locale('en')]) {
        final l10n = await AppLocalizations.delegate.load(locale);
        final seen = <String>{};
        for (final p in StreamerProblem.values) {
          final m = streamerFailureMessage(
            l10n,
            StreamerFailure(
              step: StreamerStep.capture,
              problem: p,
              errorClass: 'X',
              code: 'c',
            ),
          );
          if (p == StreamerProblem.other) {
            expect(m, isNull);
          } else {
            expect(m, isNotNull, reason: p.name);
            expect(seen.add(m!), isTrue, reason: 'unique: ${p.name}');
          }
        }
      }
    });
  });

  test('scrub: no URLs, e-mails, paths, tokens or ids; one short line', () {
    final out = StreamerFailure.scrub(
      'failed https://media.kabsolive.com/rtc?token=abc for a@b.co at '
      '/data/user/0/com.kabso.live/files id 1234567 '
      'tok eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIn0.abcDEF\nsecond line',
    );
    expect(out, isNot(contains('kabsolive')));
    expect(out, isNot(contains('a@b.co')));
    expect(out, isNot(contains('/data/user')));
    expect(out, isNot(contains('1234567')));
    expect(out, isNot(contains('eyJ')));
    expect(out, isNot(contains('second line')));
    expect(StreamerFailure.scrub('x' * 400).length, lessThanOrEqualTo(161));
  });

  test('the report: app, Android, model, step, error, service types', () {
    final report = streamerReport(
      failure: StreamerFailure.blocked('no_service'),
      appVersion: '0.1.0-staging+809063b',
      device: StreamerDeviceInfo.parse(const {
        'sdk': 35,
        'release': '15',
        'manufacturer': 'samsung',
        'model': 'SM-S921B',
        'serviceForeground': false,
        'serviceTypes': <String>[],
        'consentHanded': true,
        'consentUsed': false,
      }),
      trail: const ['consent ok', 'service ok', 'capture FAILED'],
      at: DateTime.utc(2026, 11, 9, 12),
    );
    expect(
      report,
      'Kabso Live — streamer problem report\n'
      'app: 0.1.0-staging+809063b\n'
      'android: 15 (SDK 35)\n'
      'device: samsung SM-S921B\n'
      'step: capture\n'
      'problem: serviceDenied\n'
      'error: CaptureBlocked\n'
      'detail: no_service\n'
      'service: foreground=no types=none\n'
      'consent: handed=yes used=no\n'
      'steps: consent ok > service ok > capture FAILED\n'
      'time: 2026-11-09T12:00:00.000Z',
    );
    // Unknown facts read as «?», never crash.
    final bare = streamerReport(
      failure: StreamerFailure.blocked('x'),
      appVersion: '?',
      device: StreamerDeviceInfo.parse(null),
      trail: const [],
      at: DateTime.utc(2026),
    );
    expect(bare, contains('android: ?'));
    expect(bare, contains('device: ?'));
    expect(bare, contains('steps: -'));
  });

  group('the channel (kabso_streamer)', () {
    const channel = MethodChannel('com.kabso/streamer');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    test('captureCheck: ok → null, refused → its reason', () async {
      final platform = ChannelStreamerPlatform();
      var answer = <String, Object?>{'ok': true, 'reason': null};
      final calls = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        return call.method == 'captureCheck' ? answer : const {'sdk': 34};
      });
      expect(await platform.captureCheck(), isNull);
      answer = {'ok': false, 'reason': 'no_service'};
      expect(await platform.captureCheck(), 'no_service');
      expect((await platform.diagnostics())['sdk'], 34);
      expect(calls, ['captureCheck', 'captureCheck', 'diagnostics']);
    });

    test('projectionStopped tells whether the service was in front', () async {
      final platform = ChannelStreamerPlatform();
      final got = <StreamerProjectionStopped>[];
      final sub = platform.events.listen((e) {
        if (e is StreamerProjectionStopped) got.add(e);
      });
      Future<void> send(Object? args) => messenger.handlePlatformMessage(
        channel.name,
        const StandardMethodCodec().encodeMethodCall(
          MethodCall('projectionStopped', args),
        ),
        (_) {},
      );
      await send({'serviceForeground': false});
      await send(null);
      await Future<void>.delayed(Duration.zero);
      expect(got.map((e) => e.serviceForeground), [false, null]);
      await sub.cancel();
    });
  });

  test(
    'the keeper keeps why the service did not start; a start clears it',
    () async {
      final service = FakeBackground()
        ..failStart = const LiveBackgroundStartException('denied');
      final keeper = LiveBackgroundKeeper(service);
      addTearDown(keeper.dispose);
      const texts = LiveBackgroundTexts(
        channelName: 'c',
        hostTitle: 'h',
        guestTitle: 'g',
        listenerTitle: 'l',
        body: 'b',
        endLive: 'e',
        leave: 'x',
      );
      final owner = Object();
      keeper.hold(
        owner,
        LiveBackgroundSpec.of(LiveBackgroundRole.host, texts),
        onEnd: () {},
      );
      await keeper.settled;
      expect(keeper.lastStartFailure, isA<LiveBackgroundStartException>());
      service.failStart = null;
      keeper.hold(
        owner,
        LiveBackgroundSpec.of(
          LiveBackgroundRole.host,
          texts,
        ).streamer(mic: 'm', camera: 'c'),
        onEnd: () {},
      );
      await keeper.settled;
      expect(keeper.lastStartFailure, isNull);
    },
  );
}
