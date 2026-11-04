// D262 (owner 2026-11-04: «لم تسمح بتصوير الشاشة» right away, the system
// dialog never showed): the screen-capture consent is asked by our own
// plugin (`com.kabso/streamer` `requestCapture`) and answers granted,
// refused or failed (with a short code). The real Android dialog is not
// exercised here (no device); the Kotlin rules have their own JVM tests.
import 'dart:ui' show Locale;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/features/live/data/streamer/live_streamer_platform.dart';
import 'package:kabso_live/features/live/presentation/streamer/streamer_widgets.dart';
import 'package:kabso_live/l10n/l10n.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.kabso/streamer');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  group('StreamerConsent.parse', () {
    test('the three outcomes', () {
      expect(
        StreamerConsent.parse(const {'outcome': 'granted', 'reason': null}),
        StreamerConsent.granted,
      );
      expect(
        StreamerConsent.parse(const {'outcome': 'refused'}),
        StreamerConsent.refused,
      );
      expect(
        StreamerConsent.parse(const {
          'outcome': 'failed',
          'reason': 'instant_cancel',
        }),
        const StreamerConsent.failed('instant_cancel'),
      );
    });

    test('anything else is a failure, never a «no»', () {
      expect(StreamerConsent.parse(null).reason, 'bad_answer');
      expect(StreamerConsent.parse(true).reason, 'bad_answer');
      expect(
        StreamerConsent.parse(const {'outcome': 'maybe'}).outcome,
        StreamerConsentOutcome.failed,
      );
      expect(
        StreamerConsent.parse(const {'outcome': 'failed'}).reason,
        'unknown',
      );
    });

    test('the code is short and plain', () {
      expect(StreamerConsent.code('No Activity!'), 'no_activity');
      expect(StreamerConsent.code(StateError), 'stateerror');
      expect(StreamerConsent.code(''), 'unknown');
      expect(StreamerConsent.code('x' * 50), hasLength(32));
    });
  });

  group('ChannelStreamerPlatform.requestCapture', () {
    Future<StreamerConsent> ask(Future<Object?>? Function(MethodCall) handler) {
      messenger.setMockMethodCallHandler(channel, handler);
      return ChannelStreamerPlatform().requestCapture();
    }

    test('asks our plugin (not flutter_webrtc) and reads its answer', () async {
      final calls = <MethodCall>[];
      final answer = await ask((call) async {
        calls.add(call);
        return {'outcome': 'granted', 'reason': null};
      });
      expect(answer, StreamerConsent.granted);
      expect(calls.single.method, 'requestCapture');
      expect(calls.single.arguments, {'fullScreenOnly': false});
      expect(
        await ask((_) async => {'outcome': 'refused'}),
        StreamerConsent.refused,
      );
    });

    test('platform errors are failures with their code', () async {
      expect(
        await ask((_) async => throw PlatformException(code: 'Busy Now')),
        const StreamerConsent.failed('busy_now'),
      );
      expect(
        await ask((_) async => throw StateError('x')),
        isA<StreamerConsent>().having(
          (c) => c.outcome,
          'outcome',
          StreamerConsentOutcome.failed,
        ),
      );
    });

    test('an old build without the method is a failure', () async {
      expect(await ask((_) async => null), StreamerConsent.parse(null));
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw MissingPluginException();
      });
      expect(
        await ChannelStreamerPlatform().requestCapture(),
        const StreamerConsent.failed('no_plugin'),
      );
    });
  });

  group('streamerConsentMessage', () {
    test('Arabic: «no», failed with the code, could not start', () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('ar'));
      expect(streamerConsentMessage(l10n, StreamerConsent.granted), isNull);
      expect(
        streamerConsentMessage(l10n, StreamerConsent.refused),
        'لم تسمح بتصوير الشاشة، لذلك لم يبدأ البث',
      );
      expect(
        streamerConsentMessage(
          l10n,
          const StreamerConsent.failed('instant_cancel'),
        ),
        'تعذّر طلب إذن تصوير الشاشة (instant_cancel)',
      );
      expect(
        streamerConsentMessage(
          l10n,
          const StreamerConsent.failed(StreamerConsent.startFailed),
        ),
        'تعذّر تشغيل مشاركة الشاشة، حاول مرة أخرى',
      );
    });

    test('English', () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(
        streamerConsentMessage(l10n, const StreamerConsent.failed('timeout')),
        "Couldn't ask for screen capture permission (timeout)",
      );
    });
  });
}
