// D215 (owner, two Android phones on staging): «عندما محاولة فتح لايف وانا
// اعمل ميوت للمايك يظهر تعذر ولا اتسطيع الفتح» — muting the microphone on
// the setup screen made going live fail («تعذر…», GL-publish:audio).
//
// Root cause: the setup's mute called LiveKit's `LocalTrack.mute()` on the
// preview track, which is not published yet; LiveKit's mute stops the
// native capture and disposes its stream (livekit_client 2.13.1
// `LocalTrack.mute` → `stop()`), and `publishAudioTrack` then added that
// dead track to the peer connection and failed. Turning the mic back on in
// the setup failed too (`unmute` → `restartTrack` throws without a sender).
//
// These tests drive the real `LiveKitMediaEngine` with stand-ins for the
// LiveKit objects that behave as livekit_client does on those points.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:kabso_live/features/live/data/live_media_engine.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:livekit_client/livekit_client.dart' as lk;

class _Sender implements rtc.RTCRtpSender {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A microphone track as livekit_client's `LocalAudioTrack` behaves.
class _Mic implements lk.LocalAudioTrack {
  bool active = false;
  bool enabled = true;
  bool captureStopped = false;
  bool disposed = false;
  bool _muted = false;
  rtc.RTCRtpSender? _sender;
  final List<String> calls = [];

  @override
  bool get muted => _muted;

  @override
  rtc.RTCRtpSender? get sender => _sender;

  @override
  Future<bool> start() async {
    calls.add('start');
    if (active) return false;
    active = true;
    return true;
  }

  @override
  Future<void> disable() async {
    calls.add('disable');
    if (active) enabled = false;
  }

  @override
  Future<void> enable() async {
    calls.add('enable');
    if (active) enabled = true;
  }

  @override
  Future<bool> stop() async {
    calls.add('stop');
    captureStopped = true;
    active = false;
    return true;
  }

  // `LocalTrack.mute`: disable, stop the capture, muted.
  @override
  Future<bool> mute({bool stopOnMute = true}) async {
    calls.add('mute');
    if (_muted) return false;
    await disable();
    if (stopOnMute) await stop();
    _muted = true;
    return true;
  }

  // `LocalTrack.unmute`: `restartTrack` (needs a sender), enable.
  @override
  Future<bool> unmute({bool stopOnMute = true}) async {
    calls.add('unmute');
    if (!_muted) return false;
    if (_sender == null) {
      throw lk.TrackCreateException('could not restart track');
    }
    captureStopped = false;
    active = true;
    enabled = true;
    _muted = false;
    return true;
  }

  @override
  Future<bool> dispose() async {
    calls.add('dispose');
    disposed = true;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The room's participant: publishing a track whose capture was stopped
/// fails as `addTransceiver` does with a disposed native track.
class _Local implements lk.LocalParticipant {
  final List<String> published = [];

  /// The microphone's state when it was published.
  ({bool enabled, bool muted})? micAtPublish;

  @override
  List<lk.LocalTrackPublication<lk.LocalAudioTrack>>
  get audioTrackPublications => const [];

  @override
  List<lk.LocalTrackPublication<lk.LocalVideoTrack>>
  get videoTrackPublications => const [];

  @override
  Future<lk.LocalTrackPublication<lk.LocalAudioTrack>> publishAudioTrack(
    lk.LocalAudioTrack track, {
    lk.AudioPublishOptions? publishOptions,
  }) async {
    final mic = track as _Mic;
    await mic.start();
    if (mic.captureStopped || mic.disposed) {
      throw StateError('MediaStreamTrack has been disposed');
    }
    micAtPublish = (enabled: mic.enabled, muted: mic.muted);
    mic._sender = _Sender();
    published.add('audio');
    return _Publication();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Publication implements lk.LocalTrackPublication<lk.LocalAudioTrack> {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Room implements lk.Room {
  final _Local local = _Local();
  final lk.EventsEmitter<lk.RoomEvent> _events = lk.EventsEmitter();

  @override
  lk.LocalParticipant get localParticipant => local;

  @override
  String? get metadata => null;

  @override
  lk.EventsListener<lk.RoomEvent> createListener({bool synchronized = false}) =>
      lk.EventsListener<lk.RoomEvent>(_events, synchronized: synchronized);

  @override
  Future<void> connect(
    String url,
    String token, {
    lk.ConnectOptions? connectOptions,
    @Deprecated('deprecated') lk.RoomOptions? roomOptions,
    lk.FastConnectOptions? fastConnectOptions,
  }) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

LiveMediaAccess _access() => LiveMediaAccess(
  url: 'wss://media.test',
  token: 't',
  expiresAt: DateTime(2030),
  role: LiveMediaRole.host,
  identity: 'host-1',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<_Mic> mics;
  late _Room room;

  setUp(() {
    mics = [];
    room = _Room();
    LiveKitMediaEngine.createMicrophone = (_) async {
      final mic = _Mic();
      mics.add(mic);
      return mic;
    };
    LiveKitMediaEngine.createRoom = () => room;
  });
  tearDown(() {
    LiveKitMediaEngine.createMicrophone = lk.LocalAudioTrack.create;
    LiveKitMediaEngine.createRoom = lk.Room.new;
  });

  Future<void> publish(LiveKitMediaEngine engine) => engine.publish(_access());

  test('muted in the setup: the preview track is not muted (its capture '
      'keeps), going live publishes it silent', () async {
    final engine = LiveKitMediaEngine();
    await engine.startPreview(video: false);
    await engine.setMicEnabled(enabled: false);
    expect(engine.micEnabled, isFalse);
    expect(mics.single.calls, isNot(contains('mute')));
    expect(mics.single.captureStopped, isFalse);
    await publish(engine);
    expect(room.local.published, ['audio']);
    // Silent from its first frame: started and disabled before publishing,
    // then muted the LiveKit way once published.
    expect(room.local.micAtPublish, (enabled: false, muted: false));
    expect(mics.single.muted, isTrue);
    expect(
      mics.single.calls,
      containsAllInOrder(<String>['start', 'disable', 'start', 'mute']),
    );
  });

  test('live muted, then the host unmutes on air (and mutes again)', () async {
    final engine = LiveKitMediaEngine();
    await engine.startPreview(video: false);
    await engine.setMicEnabled(enabled: false);
    final mic = mics.single;
    await publish(engine);
    expect(mic.sender, isNotNull);
    expect(mic.muted, isTrue);
    await engine.setMicEnabled(enabled: true);
    expect(engine.micEnabled, isTrue);
    expect(mic.muted, isFalse);
    expect(mic.enabled, isTrue);
    await engine.setMicEnabled(enabled: false);
    expect(mic.muted, isTrue);
  });

  test('a track muted the old way before publishing is replaced, not '
      'published dead', () async {
    final engine = LiveKitMediaEngine();
    await engine.startPreview(video: false);
    await mics.single.mute();
    await engine.setMicEnabled(enabled: false);
    await publish(engine);
    expect(mics, hasLength(2));
    expect(mics.first.disposed, isTrue);
    expect(room.local.micAtPublish, (enabled: false, muted: false));
    expect(mics.last.muted, isTrue);
  });

  test('off then on in the setup: no error (unmute without a sender threw '
      'before), and it goes live with the microphone on', () async {
    final engine = LiveKitMediaEngine();
    await engine.startPreview(video: false);
    await engine.setMicEnabled(enabled: false);
    await engine.setMicEnabled(enabled: true);
    expect(engine.micEnabled, isTrue);
    await publish(engine);
    expect(room.local.micAtPublish, (enabled: true, muted: false));
    expect(mics.single.calls, isNot(contains('disable')));
  });

  test('voice settings changed while muted in the setup: the new track is '
      'not muted either', () async {
    final engine = LiveKitMediaEngine();
    await engine.startPreview(video: false);
    await engine.setMicEnabled(enabled: false);
    await engine.setVoice(noiseReduction: false, enhance: false);
    expect(mics, hasLength(2));
    expect(mics.last.calls, isEmpty);
    await publish(engine);
    expect(room.local.micAtPublish, (enabled: false, muted: false));
  });

  test('a real microphone failure is still reported as the audio step '
      '(D210)', () async {
    final engine = LiveKitMediaEngine();
    await engine.startPreview(video: false);
    // The capture died on its own (not by the setup's mute).
    mics.single.captureStopped = true;
    await expectLater(
      engine.publish(_access()),
      throwsA(
        isA<LivePublishException>()
            .having((e) => e.stage, 'stage', LivePublishStage.audio)
            .having((e) => e.cause, 'cause', isA<StateError>()),
      ),
    );
  });
}
