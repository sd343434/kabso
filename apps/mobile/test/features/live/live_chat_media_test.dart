// CP-017 (D104): the live chat's tools — bullet messages (15 coins, the
// balance from GET /wallet/me), voice clips (fake recorder, 30 s at most),
// pictures, private messages — voice and picture lines that vanish at
// expiresAt, and bullets shown as a box in the viewer's and the host's chat
// (owner, 2026-10-26: they no longer fly over the screen).

import 'dart:typed_data';
import 'dart:ui' show Tristate;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/data/live_blocked_words_repository.dart';
import 'package:kabso_live/features/live/data/live_media_engine.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/data/live_schedule_repository.dart';
import 'package:kabso_live/features/live/data/live_voice_recorder.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/go_live_screen.dart';
import 'package:kabso_live/features/live/live_room_screen.dart';
import 'package:kabso_live/features/live/presentation/go_live/go_live_parts.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_audio_room.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_chat_media.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_chat_tools.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_chat.dart';
import 'package:kabso_live/features/posts/application/compose_controller.dart';
import 'package:kabso_live/features/posts/data/media_library.dart';
import 'package:kabso_live/features/posts/data/media_repository.dart';
import 'package:kabso_live/features/posts/data/posts_repository.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:kabso_live/features/safety/safety_repository.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../helpers/fake_live_blocked_words_repository.dart';
import '../../helpers/fake_live_media_engine.dart';
import '../../helpers/fake_live_repository.dart';
import '../../helpers/fake_live_schedule_repository.dart';
import '../../helpers/fake_live_voice_recorder.dart';
import '../../helpers/fake_media_repository.dart';
import '../../helpers/fake_posts_repository.dart';
import '../../helpers/fake_profile_repository.dart';
import '../../helpers/fake_safety_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

const _huda = UserSummary(
  id: 'u-huda',
  username: 'huda',
  displayName: 'Huda',
  avatarUrl: null,
);

const _omar = UserSummary(
  id: 'u-omar',
  username: 'omar',
  displayName: 'Omar',
  avatarUrl: null,
);

final _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

LiveSeats _seats() => LiveSeats(
  roomId: 'room-0',
  mode: LiveRoomMode.audio,
  version: 1,
  seatCount: 9,
  seats: [
    for (var i = 1; i < 9; i++)
      LiveSeat(index: i, state: LiveSeatState.empty, user: null),
  ],
  moderators: const [],
  mine: const LiveSeatsMine(
    role: LiveSeatRole.viewer,
    seatIndex: null,
    request: null,
    invite: null,
  ),
);

/// An audio room whose sent messages come from the signed-in test user.
FakeLiveRepository _audioRoom() {
  final me = testUser();
  return FakeLiveRepository(
      room: (id) => apiRoom(
        id: id,
      ).copyWith(mode: LiveRoomMode.audio, seatCount: 9, theme: 'ice-palace'),
    )
    ..seatState = _seats()
    ..chatAuthor = UserSummary(
      id: me.id,
      username: me.username,
      displayName: me.displayName,
      avatarUrl: null,
    );
}

LiveBullet _bullet(String id, String text, {UserSummary sender = _huda}) =>
    LiveBullet(
      id: id,
      text: text,
      sender: sender,
      roomId: 'room-9',
      createdAt: DateTime.utc(2026, 10, 26, 18),
    );

/// A player whose source fails to load (like a clip served wrongly).
class _FailingPlayer implements AudioPlayer {
  final List<String> played = [];
  bool disposed = false;

  @override
  Stream<void> get onPlayerComplete => const Stream.empty();

  @override
  Future<void> play(
    Source source, {
    double? volume,
    double? balance,
    AudioContext? ctx,
    Duration? position,
    PlayerMode? mode,
  }) async {
    if (source is UrlSource) played.add(source.url);
    throw Exception('source error');
  }

  @override
  Future<void> dispose() async => disposed = true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Room {
  const new({
    required this.repo,
    required this.engine,
    required this.recorder,
    required this.media,
    required this.picker,
  });

  final FakeLiveRepository repo;
  final FakeLiveMediaEngine engine;
  final FakeLiveVoiceRecorder recorder;
  final FakeMediaRepository media;
  final FakePhotoPicker picker;
}

List<Override> _overrides(
  FakeLiveRepository repo,
  FakeLiveVoiceRecorder recorder,
  FakeMediaRepository media,
  FakePhotoPicker picker, {
  bool signedIn = true,
  List<UserSummary> blocked = const [],
}) => [
  liveRepositoryProvider.overrideWithValue(repo),
  profileRepositoryProvider.overrideWithValue(
    FakeProfileRepository(apiProfile()),
  ),
  if (signedIn) currentUserProvider.overrideWithValue(testUser()),
  liveVoiceRecorderProvider.overrideWithValue(() => recorder),
  mediaRepositoryProvider.overrideWithValue(media),
  photoPickerProvider.overrideWithValue(picker),
  safetyRepositoryProvider.overrideWithValue(
    FakeSafetyRepository(blockedUsers: [...blocked]),
  ),
];

/// The viewer's audio room, signed in.
Future<_Room> _pumpRoom(
  WidgetTester tester, {
  AppLanguage language = AppLanguage.en,
  List<UserSummary> blocked = const [],
  bool signedIn = true,
}) async {
  final repo = _audioRoom();
  final engine = FakeLiveMediaEngine()..present.add('user-0');
  final recorder = FakeLiveVoiceRecorder();
  final media = FakeMediaRepository();
  final picker = FakePhotoPicker();
  setViewport(tester, GoldenViewport.phone);
  await tester.pumpWidget(const SizedBox.shrink());
  await pumpScreen(
    tester,
    const LiveRoomScreen(roomId: 'room-0'),
    language: language,
    liveMediaEngine: engine,
    overrides: _overrides(
      repo,
      recorder,
      media,
      picker,
      signedIn: signedIn,
      blocked: blocked,
    ),
  );
  await tester.pumpAndSettle();
  return _Room(
    repo: repo,
    engine: engine,
    recorder: recorder,
    media: media,
    picker: picker,
  );
}

Future<void> _openComposer(WidgetTester tester) async {
  await tester.tap(find.byKey(AudioRoomViewKeys.chat));
  await tester.pumpAndSettle();
}

void _clearSnack(WidgetTester tester) =>
    ScaffoldMessenger.of(tester.element(find.byType(LiveRoomScreen)))
        .removeCurrentSnackBar();

Finder _inChat(Finder finder) => find.descendant(
  of: find.byKey(LiveRoomChatLines.listKey),
  matching: finder,
);

/// Disposes the screen so no timer outlives the test.
Future<void> _leave(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  final l10n = l10nFor(AppLanguage.en);

  group('models', () {
    test('a VOICE message and a bullet data message parse', () {
      final voice = LiveChatEvent.parse({
        'type': 'chat',
        'message': {
          'id': 'm1',
          'roomId': 'room-0',
          'author': {
            'id': 'u-huda',
            'username': 'huda',
            'displayName': 'Huda',
            'avatarUrl': null,
          },
          'authorRole': 'VIEWER',
          'kind': 'VOICE',
          'text': '',
          'media': {
            'id': 'a1',
            'type': 'AUDIO',
            'status': 'READY',
            'width': 0,
            'height': 0,
            'blurhash': null,
            'url': 'https://m.test/a1/voice.m4a',
            'thumbUrl': 'https://m.test/a1/voice.m4a',
            'durationMs': 12500,
          },
          'expiresAt': '2026-10-26T18:31:00.000Z',
          'createdAt': '2026-10-26T18:30:00.000Z',
        },
      });
      expect(voice, isA<LiveChatReceived>());
      final entry = (voice! as LiveChatReceived).message;
      expect(entry.kind, LiveChatKind.voice);
      expect(entry.media?.durationMs, 12500);
      expect(entry.expiresAt, DateTime.utc(2026, 10, 26, 18, 31));
      // An older message without kind is text.
      final old = LiveChatEntry.fromJson({
        'id': 'm2',
        'roomId': 'room-0',
        'author': {
          'id': 'u',
          'username': 'u',
          'displayName': 'U',
          'avatarUrl': null,
        },
        'authorRole': 'HOST',
        'text': 'hi',
        'createdAt': '2026-10-26T18:30:00.000Z',
      });
      expect(old.kind, LiveChatKind.text);
      expect(old.media, isNull);
      final bullet = LiveChatEvent.parse({
        'type': 'bullet',
        'bullet': {
          'id': 'b1',
          'text': 'Good evening',
          'sender': {
            'id': 'u-huda',
            'username': 'huda',
            'displayName': 'Huda',
            'avatarUrl': null,
          },
          'roomId': 'room-9',
          'createdAt': '2026-10-26T18:30:00.000Z',
        },
      });
      expect((bullet! as LiveBulletReceived).bullet.text, 'Good evening');
    });
  });

  group('the tools row', () {
    testWidgets('bullet, voice, messages, picture from the start; RTL '
        'mirrors them', (tester) async {
      await _pumpRoom(tester);
      await _openComposer(tester);
      final keys = [
        LiveRoomComposer.bulletKey,
        LiveRoomComposer.voiceKey,
        LiveRoomComposer.messagesKey,
        LiveRoomComposer.pictureKey,
      ];
      final xs = [for (final k in keys) tester.getCenter(find.byKey(k)).dx];
      final ascending = [...xs]..sort();
      expect(xs, ascending);
      // Above the field.
      expect(
        tester.getCenter(find.byKey(LiveRoomComposer.toolsKey)).dy,
        lessThan(tester.getCenter(find.byKey(LiveChatComposer.fieldKey)).dy),
      );
      await _leave(tester);

      await _pumpRoom(tester, language: AppLanguage.ar);
      await _openComposer(tester);
      final rtl = [for (final k in keys) tester.getCenter(find.byKey(k)).dx];
      final descending = [...rtl]..sort((a, b) => b.compareTo(a));
      expect(rtl, descending);
      await _leave(tester);
    });

    testWidgets('guests get no tools; no voice where clips cannot be '
        'recorded (the web)', (tester) async {
      final repo = _audioRoom();
      final recorder = FakeLiveVoiceRecorder()..canRecord = false;
      final field = TextEditingController();
      final focus = FocusNode();
      addTearDown(field.dispose);
      addTearDown(focus.dispose);
      Widget composer() => Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: LiveRoomComposer(
            roomId: 'room-0',
            controller: field,
            focusNode: focus,
            onSend: () {},
            onEmoji: (_) {},
            onMessages: () {},
          ),
        ),
      );
      await pumpScreen(
        tester,
        composer(),
        overrides: [
          liveRepositoryProvider.overrideWithValue(repo),
          liveVoiceRecorderProvider.overrideWithValue(() => recorder),
        ],
      );
      await tester.pump();
      expect(find.byKey(LiveChatComposer.fieldKey), findsOneWidget);
      expect(find.byKey(LiveRoomComposer.toolsKey), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await pumpScreen(
        tester,
        composer(),
        overrides: [
          liveRepositoryProvider.overrideWithValue(repo),
          liveVoiceRecorderProvider.overrideWithValue(() => recorder),
          currentUserProvider.overrideWithValue(testUser()),
        ],
      );
      await tester.pump();
      expect(find.byKey(LiveRoomComposer.toolsKey), findsOneWidget);
      expect(find.byKey(LiveRoomComposer.bulletKey), findsOneWidget);
      expect(find.byKey(LiveRoomComposer.voiceKey), findsNothing);
      expect(find.byKey(LiveRoomComposer.pictureKey), findsOneWidget);
    });

    testWidgets('a guest cannot open the chat box at all', (tester) async {
      await _pumpRoom(tester, signedIn: false);
      await _openComposer(tester);
      expect(find.byKey(LiveRoomComposer.toolsKey), findsNothing);
      expect(find.text(l10n.liveChatSignIn), findsWidgets);
      await _leave(tester);
    });
  });

  group('bullet messages', () {
    testWidgets('bullet mode shows the price and the balance; send posts '
        'the bullet and the balance follows the answer', (tester) async {
      final room = await _pumpRoom(tester);
      await _openComposer(tester);
      final bullet = find.byKey(LiveRoomComposer.bulletKey);
      final handle = tester.ensureSemantics();
      expect(
        tester.getSemantics(bullet).flagsCollection.isToggled,
        isNot(Tristate.isTrue),
      );
      await tester.tap(bullet);
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(bullet).flagsCollection.isToggled,
        Tristate.isTrue,
      );
      handle.dispose();
      expect(room.repo.walletReads, 1);
      expect(find.text(l10n.liveBulletHint('100')), findsOneWidget);
      // 60 code points at most.
      expect(
        tester
            .widget<TextField>(find.byKey(LiveChatComposer.fieldKey))
            .maxLength,
        60,
      );
      await tester.enterText(
        find.byKey(LiveChatComposer.fieldKey),
        '  Good evening everyone  ',
      );
      await tester.tap(find.byKey(LiveChatComposer.sendKey));
      await tester.pumpAndSettle();
      expect(room.repo.bulletCalls, hasLength(1));
      expect(room.repo.bulletCalls.single.text, 'Good evening everyone');
      expect(room.repo.bulletCalls.single.clientId, matches(_uuid));
      // Not a chat line.
      expect(room.repo.chatCalls.where((c) => c.startsWith('send:')), isEmpty);
      expect(find.text(l10n.liveBulletSent), findsOneWidget);
      expect(find.text(l10n.liveBulletHint('85')), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(LiveChatComposer.fieldKey))
            .controller!
            .text,
        isEmpty,
      );
      // Off again: the field is the chat's.
      _clearSnack(tester);
      await tester.tap(bullet);
      await tester.pumpAndSettle();
      expect(find.text(l10n.goLiveChatHint), findsOneWidget);
      await _leave(tester);
    });

    testWidgets('not enough coins: a clear message, the text stays', (
      tester,
    ) async {
      final room = await _pumpRoom(tester);
      room.repo
        ..coins = 5
        ..bulletFailure = const ServerFailure(
          code: ErrorCode.insufficientCoins,
          rawCode: 'INSUFFICIENT_COINS',
          debugMessage: 'x',
          statusCode: 409,
        );
      await _openComposer(tester);
      await tester.tap(find.byKey(LiveRoomComposer.bulletKey));
      await tester.pumpAndSettle();
      expect(find.text(l10n.liveBulletHint('5')), findsOneWidget);
      await tester.enterText(find.byKey(LiveChatComposer.fieldKey), 'Hi');
      await tester.tap(find.byKey(LiveChatComposer.sendKey));
      await tester.pumpAndSettle();
      expect(find.text(l10n.errorInsufficientCoins), findsOneWidget);
      expect(l10n.errorInsufficientCoins, contains('15'));
      expect(
        tester
            .widget<TextField>(find.byKey(LiveChatComposer.fieldKey))
            .controller!
            .text,
        'Hi',
      );
      expect(find.byType(LiveChatBulletBox), findsNothing);
      await _leave(tester);
    });
  });

  group('voice clips', () {
    testWidgets('record, see the timer, send: uploaded as LIVE_CHAT_VOICE '
        'and sent as VOICE; the clip line plays and vanishes at expiresAt', (
      tester,
    ) async {
      final room = await _pumpRoom(tester);
      await _openComposer(tester);
      await tester.tap(find.byKey(LiveRoomComposer.voiceKey));
      await tester.pump();
      expect(room.recorder.starts, 1);
      expect(find.text(l10n.liveVoiceRecording('0:00')), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      expect(find.text(l10n.liveVoiceRecording('0:03')), findsOneWidget);
      // The send arrow stops and sends.
      await tester.tap(find.byKey(LiveChatComposer.sendKey));
      await tester.pump();
      await tester.pump();
      expect(room.recorder.stops, 1);
      expect(room.media.liveChatUploads, ['voice:audio/mp4:2048']);
      expect(room.repo.chatCalls, contains('voice:c1'));
      expect(find.byKey(LiveRoomComposer.recordingKey), findsNothing);
      expect(
        _inChat(find.byKey(LiveVoiceClipPill.keyFor('c1'))),
        findsOneWidget,
      );
      expect(_inChat(find.text('0:04')), findsOneWidget);
      // Gone 60 s after sending, without any refresh.
      await tester.pump(const Duration(seconds: 59));
      expect(find.byKey(LiveVoiceClipPill.keyFor('c1')), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(find.byKey(LiveVoiceClipPill.keyFor('c1')), findsNothing);
      await _leave(tester);
    });

    testWidgets('stops and sends by itself at 30 s', (tester) async {
      final room = await _pumpRoom(tester);
      await _openComposer(tester);
      await tester.tap(find.byKey(LiveRoomComposer.voiceKey));
      await tester.pump();
      await tester.pump(const Duration(seconds: 29));
      expect(room.recorder.stops, 0);
      expect(find.text(l10n.liveVoiceRecording('0:29')), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(room.recorder.stops, 1);
      expect(room.media.liveChatUploads, hasLength(1));
      expect(room.repo.chatCalls, contains('voice:c1'));
      expect(find.byKey(LiveRoomComposer.recordingKey), findsNothing);
      await _leave(tester);
    });

    testWidgets('cancel throws the clip away; a refused microphone says so', (
      tester,
    ) async {
      final room = await _pumpRoom(tester);
      await _openComposer(tester);
      await tester.tap(find.byKey(LiveRoomComposer.voiceKey));
      await tester.pump();
      await tester.tap(find.byKey(LiveRoomComposer.voiceCancelKey));
      await tester.pump();
      expect(room.recorder.cancels, 1);
      expect(room.media.liveChatUploads, isEmpty);
      expect(find.byKey(LiveChatComposer.fieldKey), findsOneWidget);
      room.recorder.problem = LiveVoiceProblem.denied;
      await tester.tap(find.byKey(LiveRoomComposer.voiceKey));
      await tester.pump();
      expect(find.text(l10n.liveVoiceDenied), findsOneWidget);
      expect(find.byKey(LiveRoomComposer.recordingKey), findsNothing);
      await _leave(tester);
    });
  });

  // Owner report (staging, Android): a voice clip recorded in a live had no
  // sound. LiveKit/WebRTC holds the microphone for the live, so the live mic
  // is paused while the clip records and always restored after.
  group('voice clips and the live microphone', () {
    Future<_Room> seated(WidgetTester tester) async {
      final room = await _pumpRoom(tester);
      // A seated guest publishing the microphone.
      room.engine.publishingLocal = true;
      await _openComposer(tester);
      return room;
    }

    testWidgets('a seated guest: the live mic pauses before recording, the '
        'hint shows, and it comes back after the clip stops, before upload', (
      tester,
    ) async {
      final room = await seated(tester);
      await tester.tap(find.byKey(LiveRoomComposer.voiceKey));
      await tester.pump();
      expect(room.engine.clipMicLog, ['pause']);
      expect(room.recorder.log, ['start']);
      expect(room.engine.micPausedForClip, isTrue);
      expect(find.byKey(LiveRoomComposer.micPausedKey), findsOneWidget);
      expect(find.text(l10n.liveVoiceLiveMicPaused), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await tester.tap(find.byKey(LiveChatComposer.sendKey));
      await tester.pump();
      await tester.pump();
      expect(room.recorder.log, ['start', 'stop']);
      expect(room.engine.clipMicLog, ['pause', 'resume']);
      expect(room.engine.micPausedForClip, isFalse);
      expect(find.byKey(LiveRoomComposer.micPausedKey), findsNothing);
      expect(room.media.liveChatUploads, ['voice:audio/mp4:2048']);
      await _leave(tester);
    });

    testWidgets('restored after cancel, a recorder that cannot start, a '
        'failed stop, and when the chat box goes away mid-recording', (
      tester,
    ) async {
      final room = await seated(tester);
      // Cancel.
      await tester.tap(find.byKey(LiveRoomComposer.voiceKey));
      await tester.pump();
      await tester.tap(find.byKey(LiveRoomComposer.voiceCancelKey));
      await tester.pump();
      expect(room.engine.clipMicLog, ['pause', 'resume']);
      // The recorder cannot start.
      room.recorder.problem = LiveVoiceProblem.unavailable;
      await tester.tap(find.byKey(LiveRoomComposer.voiceKey));
      await tester.pump();
      expect(find.text(l10n.liveVoiceUnavailable), findsOneWidget);
      expect(room.engine.clipMicLog, ['pause', 'resume', 'pause', 'resume']);
      expect(find.byKey(LiveRoomComposer.recordingKey), findsNothing);
      _clearSnack(tester);
      // Stopping fails.
      room.recorder
        ..problem = null
        ..stopFailure = Exception('encoder');
      await tester.tap(find.byKey(LiveRoomComposer.voiceKey));
      await tester.pump();
      await tester.tap(find.byKey(LiveChatComposer.sendKey));
      await tester.pump();
      await tester.pump();
      expect(room.engine.micPausedForClip, isFalse);
      expect(room.engine.clipMicLog, hasLength(6));
      expect(room.media.liveChatUploads, isEmpty);
      // The screen goes away while recording.
      room.recorder.stopFailure = null;
      await tester.tap(find.byKey(LiveRoomComposer.voiceKey));
      await tester.pump();
      expect(room.engine.micPausedForClip, isTrue);
      await _leave(tester);
      expect(room.engine.micPausedForClip, isFalse);
      expect(room.engine.clipMicLog.last, 'resume');
      expect(room.media.liveChatUploads, isEmpty);
    });

    testWidgets('a viewer who publishes no mic: nothing paused, no hint', (
      tester,
    ) async {
      final room = await _pumpRoom(tester);
      await _openComposer(tester);
      await tester.tap(find.byKey(LiveRoomComposer.voiceKey));
      await tester.pump();
      expect(room.recorder.starts, 1);
      expect(find.byKey(LiveRoomComposer.micPausedKey), findsNothing);
      await tester.tap(find.byKey(LiveChatComposer.sendKey));
      await tester.pump();
      await tester.pump();
      expect(room.engine.clipMicLog, isEmpty);
      expect(room.media.liveChatUploads, hasLength(1));
      await _leave(tester);
    });

    testWidgets('a live mic that cannot be paused: no recording, says why', (
      tester,
    ) async {
      final room = await seated(tester);
      room.engine.micPauseFails = true;
      await tester.tap(find.byKey(LiveRoomComposer.voiceKey));
      await tester.pump();
      expect(find.text(l10n.liveVoiceLiveMicBusy), findsOneWidget);
      expect(room.recorder.starts, 0);
      expect(find.byKey(LiveRoomComposer.recordingKey), findsNothing);
      expect(room.engine.micPausedForClip, isFalse);
      await _leave(tester);
    });

    testWidgets('a silent clip is not sent and says so; the mic comes back', (
      tester,
    ) async {
      final room = await seated(tester);
      // What a microphone held elsewhere delivers: digital silence.
      room.recorder.peakDb = -160;
      await tester.tap(find.byKey(LiveRoomComposer.voiceKey));
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      await tester.tap(find.byKey(LiveChatComposer.sendKey));
      await tester.pump();
      await tester.pump();
      expect(find.text(l10n.liveVoiceSilent), findsOneWidget);
      expect(room.media.liveChatUploads, isEmpty);
      expect(room.repo.chatCalls.where((c) => c.startsWith('voice')), isEmpty);
      expect(room.engine.clipMicLog, ['pause', 'resume']);
      await _leave(tester);
    });
  });

  testWidgets('the host of an audio live: the published mic pauses for '
      'the clip and comes back after', (tester) async {
    final repo = FakeLiveRepository(
      categories: const [LiveCategory(slug: 'music', name: 'Music')],
    );
    final engine = FakeLiveMediaEngine();
    final recorder = FakeLiveVoiceRecorder();
    final media = FakeMediaRepository();
    setViewport(tester, GoldenViewport.phone);
    await pumpScreen(
      tester,
      const GoLiveScreen(),
      liveMediaEngine: engine,
      overrides: [
        ..._overrides(
          repo,
          recorder,
          media,
          FakePhotoPicker(),
          signedIn: false,
        ),
        currentUserProvider.overrideWithValue(
          testUser().copyWith(canHost: true),
        ),
        liveBlockedWordsRepositoryProvider.overrideWithValue(
          FakeLiveBlockedWordsRepository(),
        ),
        liveScheduleRepositoryProvider.overrideWithValue(
          FakeLiveScheduleRepository(),
        ),
      ],
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(GoLiveKeys.mode(LiveRoomMode.audio)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(GoLiveScreen.titleKey), 'Voices');
    await tester.tap(find.byKey(GoLiveScreen.startKey));
    await tester.pump();
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.pumpAndSettle();
    expect(engine.micPublished, isTrue);
    await tester.tap(find.byKey(GoLiveScreen.audioChatKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(LiveRoomComposer.voiceKey));
    await tester.pump();
    expect(engine.clipMicLog, ['pause']);
    expect(find.byKey(LiveRoomComposer.micPausedKey), findsOneWidget);
    await tester.tap(find.byKey(LiveChatComposer.sendKey));
    await tester.pump();
    await tester.pump();
    expect(engine.clipMicLog, ['pause', 'resume']);
    expect(media.liveChatUploads, ['voice:audio/mp4:2048']);
    // The host's own mic choice is untouched.
    expect(engine.micEnabled, isTrue);
    await _leave(tester);
  });

  testWidgets('a clip that cannot play says so instead of staying silent', (
    tester,
  ) async {
    final player = _FailingPlayer();
    LiveVoiceClipPill.newPlayer = () => player;
    addTearDown(() => LiveVoiceClipPill.newPlayer = AudioPlayer.new);
    await _pumpRoom(tester);
    await _openComposer(tester);
    await tester.tap(find.byKey(LiveRoomComposer.voiceKey));
    await tester.pump();
    await tester.tap(find.byKey(LiveChatComposer.sendKey));
    await tester.pump();
    await tester.pump();
    await tester.tap(_inChat(find.byKey(LiveVoiceClipPill.keyFor('c1'))));
    await tester.pump();
    await tester.pump();
    expect(player.played, ['https://media.example.test/media/c1/voice.m4a']);
    expect(find.text(l10n.liveVoicePlayFailed), findsOneWidget);
    expect(player.disposed, isTrue);
    await _leave(tester);
  });

  group('LiveVoiceClip', () {
    test('silence is under -60 dBFS; an unknown level is not refused', () {
      final bytes = Uint8List(4);
      expect(LiveVoiceClip(bytes, peakDb: -160).silent, isTrue);
      expect(LiveVoiceClip(bytes, peakDb: -61).silent, isTrue);
      expect(LiveVoiceClip(bytes, peakDb: -45).silent, isFalse);
      expect(LiveVoiceClip(bytes).silent, isFalse);
    });
  });

  group('pictures', () {
    testWidgets('one photo from the library: uploaded as LIVE_CHAT_IMAGE, '
        'sent as IMAGE, a thumbnail that opens larger', (tester) async {
      final room = await _pumpRoom(tester);
      room.picker.next = [jpegBytes];
      await _openComposer(tester);
      await tester.tap(find.byKey(LiveRoomComposer.pictureKey));
      await tester.pumpAndSettle();
      expect(room.picker.calls, 1);
      expect(room.media.liveChatUploads, ['image:image/jpeg:12']);
      expect(room.repo.chatCalls, contains('image:c1'));
      final thumb = _inChat(find.byKey(LiveChatPictureThumb.keyFor('c1')));
      expect(thumb, findsOneWidget);
      await tester.tapAt(const Offset(1, 1));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(LiveChatPictureThumb.keyFor('c1')));
      await tester.pumpAndSettle();
      expect(find.byKey(LiveChatPictureThumb.viewerKey), findsOneWidget);
      Navigator.of(tester.element(find.byKey(LiveChatPictureThumb.viewerKey)))
          .pop();
      await tester.pumpAndSettle();
      // HEIC is refused on the device.
      room.picker.next = [heicBytes];
      await _openComposer(tester);
      await tester.tap(find.byKey(LiveRoomComposer.pictureKey));
      await tester.pumpAndSettle();
      expect(find.text(l10n.createPhotoUnsupported), findsOneWidget);
      expect(room.media.liveChatUploads, hasLength(1));
      await _leave(tester);
    });
  });

  group('vanishing lines', () {
    testWidgets('a VOICE / IMAGE data message hides at expiresAt; one '
        'without media never shows', (tester) async {
      final room = await _pumpRoom(tester);
      final at = DateTime.utc(2026, 10, 26, 18, 30);
      LiveChatEntry media(String id, LiveChatKind kind, {bool gone = false}) =>
          LiveChatEntry(
            id: id,
            roomId: 'room-0',
            author: _huda,
            authorRole: LiveChatRole.viewer,
            text: '',
            createdAt: at,
            kind: kind,
            media: gone
                ? null
                : LiveChatMedia(
                    id: 'media-$id',
                    url: 'https://m.test/$id',
                    thumbUrl: 'https://m.test/$id/320',
                    width: 800,
                    height: 600,
                    durationMs: kind == LiveChatKind.voice ? 7000 : null,
                  ),
            expiresAt: at.add(const Duration(seconds: 60)),
          );
      room.engine.chat
        ..add(LiveChatReceived(media('v1', LiveChatKind.voice)))
        ..add(LiveChatReceived(media('i1', LiveChatKind.image)))
        ..add(LiveChatReceived(media('i2', LiveChatKind.image, gone: true)));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(LiveVoiceClipPill.keyFor('media-v1')), findsOneWidget);
      expect(
        find.byKey(LiveChatPictureThumb.keyFor('media-i1')),
        findsOneWidget,
      );
      expect(find.byKey(LiveChatPictureThumb.keyFor('media-i2')), findsNothing);
      await tester.pump(const Duration(seconds: 30));
      expect(find.byKey(LiveVoiceClipPill.keyFor('media-v1')), findsOneWidget);
      await tester.pump(const Duration(seconds: 31));
      expect(find.byKey(LiveVoiceClipPill.keyFor('media-v1')), findsNothing);
      expect(find.byKey(LiveChatPictureThumb.keyFor('media-i1')), findsNothing);
      await _leave(tester);
    });
  });

  group('bullets in the chat', () {
    Finder box(String id) => find.byKey(LiveChatBulletBox.keyFor(id));

    testWidgets('viewer: a bullet shows in the chat as the public-message '
        'box with the sender and text, and stays; the same bullet shows '
        'once; blocked senders are skipped; nothing flies', (tester) async {
      final room = await _pumpRoom(tester, blocked: [_omar]);
      room.engine.chat
        ..add(LiveBulletReceived(_bullet('b1', 'Good evening')))
        ..add(LiveBulletReceived(_bullet('b2', 'Spam', sender: _omar)))
        ..add(LiveBulletReceived(_bullet('b3', 'Second one')))
        // The same bullet twice shows once.
        ..add(LiveBulletReceived(_bullet('b1', 'Good evening')));
      await tester.pumpAndSettle();
      expect(box('b1'), findsOneWidget);
      expect(box('b3'), findsOneWidget);
      expect(box('b2'), findsNothing);
      expect(find.textContaining('Spam', findRichText: true), findsNothing);
      // Inside the chat list, with the tag, the name and the text.
      final lines = find.byKey(LiveRoomChatLines.listKey);
      expect(find.descendant(of: lines, matching: box('b1')), findsOneWidget);
      expect(
        find.descendant(of: box('b1'), matching: find.text(l10n.liveBulletTag)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: box('b1'),
          matching: find.textContaining('Good evening'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: box('b1'), matching: find.textContaining('Huda')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(l10n.liveBulletLabel('Huda', 'Good evening')),
        findsOneWidget,
      );
      // b1 then b3, oldest first.
      expect(
        tester.getTopLeft(box('b1')).dy,
        lessThan(tester.getTopLeft(box('b3')).dy),
      );
      // It does not move or expire: still there, in place, a minute later.
      final at = tester.getRect(box('b1'));
      await tester.pump(const Duration(seconds: 61));
      await tester.pumpAndSettle();
      expect(tester.getRect(box('b1')), at);
      await _leave(tester);
    });

    testWidgets('my own bullet shows once in the chat (the answer and the '
        "room's copy)", (tester) async {
      final room = await _pumpRoom(tester);
      await _openComposer(tester);
      await tester.tap(find.byKey(LiveRoomComposer.bulletKey));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(LiveChatComposer.fieldKey), 'Hi all');
      await tester.tap(find.byKey(LiveChatComposer.sendKey));
      await tester.pumpAndSettle();
      expect(find.byType(LiveChatBulletBox), findsOneWidget);
      final id = tester
          .widget<LiveChatBulletBox>(find.byType(LiveChatBulletBox))
          .bullet
          .id;
      final sent = tester
          .widget<LiveChatBulletBox>(find.byType(LiveChatBulletBox))
          .bullet;
      room.engine.chat.add(LiveBulletReceived(sent));
      await tester.pumpAndSettle();
      expect(box(id), findsOneWidget);
      expect(find.byType(LiveChatBulletBox), findsOneWidget);
      await _leave(tester);
    });

    testWidgets('Arabic: the tag is localized; reduced motion shows the box '
        'at once, still', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final ar = l10nFor(AppLanguage.ar);
      final room = await _pumpRoom(tester, language: AppLanguage.ar);
      room.engine.chat.add(LiveBulletReceived(_bullet('b1', 'مساء الخير')));
      await tester.pump();
      await tester.pump();
      expect(box('b1'), findsOneWidget);
      expect(
        find.descendant(of: box('b1'), matching: find.text(ar.liveBulletTag)),
        findsOneWidget,
      );
      final at = tester.getRect(box('b1'));
      await tester.pump(const Duration(seconds: 2));
      expect(tester.getRect(box('b1')), at);
      await _leave(tester);
    });

    testWidgets('host: a bullet shows as the box in the host live chat', (
      tester,
    ) async {
      final repo = FakeLiveRepository(
        categories: const [LiveCategory(slug: 'music', name: 'Music')],
      );
      final engine = FakeLiveMediaEngine();
      setViewport(tester, GoldenViewport.phone);
      await pumpScreen(
        tester,
        const GoLiveScreen(),
        liveMediaEngine: engine,
        overrides: [
          ..._overrides(
            repo,
            FakeLiveVoiceRecorder(),
            FakeMediaRepository(),
            FakePhotoPicker(),
            signedIn: false,
          ),
          currentUserProvider.overrideWithValue(
            testUser().copyWith(canHost: true),
          ),
          liveBlockedWordsRepositoryProvider.overrideWithValue(
            FakeLiveBlockedWordsRepository(),
          ),
          liveScheduleRepositoryProvider.overrideWithValue(
            FakeLiveScheduleRepository(),
          ),
        ],
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(GoLiveScreen.titleKey), 'Evening');
      await tester.tap(find.byKey(GoLiveScreen.startKey));
      await tester.pumpAndSettle();
      engine.chat
        ..add(LiveBulletReceived(_bullet('b1', 'Hello host')))
        ..add(LiveBulletReceived(_bullet('b1', 'Hello host')));
      await tester.pumpAndSettle();
      expect(box('b1'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(LiveRoomChatLines.listKey),
          matching: find.textContaining('Hello host'),
        ),
        findsOneWidget,
      );
      // Still there later: it stays like a message.
      await tester.pump(const Duration(seconds: 10));
      expect(box('b1'), findsOneWidget);
      await _leave(tester);
    });
  });

  group('private messages', () {
    testWidgets('the messages tool opens the Messages tab', (tester) async {
      final repo = _audioRoom();
      final engine = FakeLiveMediaEngine()..present.add('user-0');
      final prefs = await testPrefs();
      final router = GoRouter(
        initialLocation: '/room',
        routes: [
          GoRoute(
            path: '/room',
            builder: (_, _) => const LiveRoomScreen(roomId: 'room-0'),
          ),
          GoRoute(
            path: AppRoutes.messages,
            builder: (_, _) => const Text('messages-tab'),
          ),
        ],
      );
      addTearDown(router.dispose);
      setViewport(tester, GoldenViewport.phone);
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            postsRepositoryProvider.overrideWithValue(FakePostsRepository()),
            mediaLibraryProvider.overrideWithValue(
              const UnsupportedMediaLibrary(),
            ),
            liveMediaEngineProvider.overrideWithValue(() => engine),
            ..._overrides(
              repo,
              FakeLiveVoiceRecorder(),
              FakeMediaRepository(),
              FakePhotoPicker(),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            locale: AppLanguage.en.locale,
            supportedLocales: KabsoApp.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            theme: buildAppTheme(
              brightness: Brightness.dark,
              locale: AppLanguage.en.locale,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _openComposer(tester);
      await tester.tap(find.byKey(LiveRoomComposer.messagesKey));
      await tester.pumpAndSettle();
      expect(find.text('messages-tab'), findsOneWidget);
      await _leave(tester);
    });
  });
}
