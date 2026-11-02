// D210 (staging go-live «حدث خطأ غير متوقع» after the D195/D199/D201
// batch): the failed step and error type reach the screen («تفاصيل»), the
// core (media room + camera + microphone) is the only thing that may fail
// going live, and an optional tool that throws never ends it.

import 'dart:async';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/application/live_background.dart';
import 'package:kabso_live/features/live/application/live_host_controller.dart';
import 'package:kabso_live/features/live/application/live_quips.dart';
import 'package:kabso_live/features/live/data/live_blocked_words_repository.dart';
import 'package:kabso_live/features/live/data/live_media_engine.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/data/live_schedule_repository.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/go_live_screen.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_host_parts.dart';
import 'package:kabso_live/features/live/tools/live_tools_stage.dart';
import 'package:kabso_live/features/live/tools/music/live_music_controller.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../helpers/fake_live_blocked_words_repository.dart';
import '../../helpers/fake_live_media_engine.dart';
import '../../helpers/fake_live_repository.dart';
import '../../helpers/fake_live_schedule_repository.dart';
import '../../helpers/fake_profile_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

final _categories = [const LiveCategory(slug: 'chat', name: 'Chat')];

Future<(FakeLiveRepository, FakeLiveMediaEngine)> _pump(
  WidgetTester tester, {
  FakeLiveMediaEngine? engine,
  FakeLiveRepository? repo,
  List<Override> overrides = const [],
}) async {
  final live = repo ?? FakeLiveRepository(categories: _categories);
  final camera = engine ?? FakeLiveMediaEngine();
  setViewport(tester, GoldenViewport.phone);
  await tester.pumpWidget(const SizedBox.shrink());
  await pumpScreen(
    tester,
    const GoLiveScreen(),
    liveMediaEngine: camera,
    overrides: [
      liveRepositoryProvider.overrideWithValue(live),
      currentUserProvider.overrideWithValue(testUser().copyWith(canHost: true)),
      liveBlockedWordsRepositoryProvider.overrideWithValue(
        FakeLiveBlockedWordsRepository(),
      ),
      liveScheduleRepositoryProvider.overrideWithValue(
        FakeLiveScheduleRepository(),
      ),
      profileRepositoryProvider.overrideWithValue(
        FakeProfileRepository(apiProfile()),
      ),
      ...overrides,
    ],
  );
  await tester.pumpAndSettle();
  return (live, camera);
}

Future<void> _goLive(WidgetTester tester) async {
  await tester.enterText(find.byKey(GoLiveScreen.titleKey), 'Evening chat');
  await tester.tap(find.byKey(GoLiveScreen.startKey));
  await tester.pumpAndSettle();
}

Future<void> _leave(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

/// A background keeper whose hold throws (the platform service broken).
class _BrokenKeeper extends LiveBackgroundKeeper {
  new() : super(_NoService());

  @override
  void hold(
    Object owner,
    LiveBackgroundSpec spec, {
    required VoidCallback onEnd,
    VoidCallback? onOpen,
    VoidCallback? onBackground,
    VoidCallback? onForeground,
    VoidCallback? onToggleMic,
    VoidCallback? onToggleCamera,
    VoidCallback? onUnavailable,
  }) => throw StateError('background service broken');
}

class _NoService implements LiveBackgroundService {
  @override
  Stream<LiveBackgroundAction> get actions => const Stream.empty();

  @override
  Future<void> start(LiveBackgroundSpec spec) async {}

  @override
  Future<void> stop() async {}
}

/// An optional tool (the quips) whose start throws.
class _BrokenQuips extends LiveQuips {
  new(super.roomId);

  @override
  void attach(LiveMediaEngine engine) =>
      throw const MissingPluginExceptionLike('quips');
}

/// The music player whose start throws (its native plugin missing).
class _BrokenMusic extends LiveMusicController {
  @override
  LiveMusicState build() => throw const MissingPluginExceptionLike('music');
}

class MissingPluginExceptionLike implements Exception {
  const new(this.what);
  final String what;
}

void main() {
  group('livePublishStage (the publish steps)', () {
    test('a failing step is rethrown with its stage and cause', () async {
      final error = StateError('track ended');
      await expectLater(
        livePublishStage(LivePublishStage.video, () async => throw error),
        throwsA(
          isA<LivePublishException>()
              .having((e) => e.stage, 'stage', LivePublishStage.video)
              .having((e) => e.cause, 'cause', same(error)),
        ),
      );
    });

    test('a nested stage keeps the inner step', () async {
      await expectLater(
        livePublishStage(
          LivePublishStage.connect,
          () => livePublishStage<void>(
            LivePublishStage.audio,
            () async => throw StateError('x'),
          ),
        ),
        throwsA(
          isA<LivePublishException>().having(
            (e) => e.stage,
            'stage',
            LivePublishStage.audio,
          ),
        ),
      );
    });

    test('a step that works returns its value', () async {
      expect(
        await livePublishStage(LivePublishStage.connect, () async => 7),
        7,
      );
    });
  });

  group('LiveStartFailure (the «تفاصيل» code)', () {
    test('a publish step names the step and the error type', () {
      final why = LiveStartFailure.of(
        'publish',
        LivePublishException(LivePublishStage.video, StateError('x')),
      );
      expect(why.code, 'GL-video:StateError');
    });

    test('a server failure names the server code, never the message', () {
      const failure = ServerFailure(
        code: ErrorCode.liveRoomEnded,
        rawCode: 'LIVE_ROOM_ENDED',
        debugMessage: 'secret token=abc',
        statusCode: 409,
      );
      final why = LiveStartFailure.of('token', failure);
      expect(why.code, 'GL-token:LIVE_ROOM_ENDED');
      expect(why.code, isNot(contains('abc')));
    });

    test('anything else is the exception type', () {
      expect(
        LiveStartFailure.of('publish', const FormatException('x')).code,
        'GL-publish:FormatException',
      );
    });
  });

  group('go-live failure details (D210)', () {
    testWidgets('the camera publish fails: generic error + «تفاصيل» with the '
        'step and type; the room is ended; tapping hides it', (tester) async {
      final camera = FakeLiveMediaEngine()
        ..publishFailure = LivePublishException(
          LivePublishStage.video,
          StateError('track ended'),
        );
      final (repo, _) = await _pump(tester, engine: camera);
      await _goLive(tester);
      expect(repo.endRequests, ['room-host']);
      expect(find.byKey(GoLiveScreen.startKey), findsOneWidget);
      // The snack: the generic message and the details line.
      expect(
        find.textContaining('Something unexpected happened'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Details: GL-video:StateError'),
        findsNWidgets(2),
      );
      // The persistent line (for a screenshot) until tapped.
      expect(find.byKey(GoLiveScreen.failureDetailsKey), findsOneWidget);
      await tester.tap(find.byKey(GoLiveScreen.failureDetailsKey));
      await tester.pump();
      expect(find.byKey(GoLiveScreen.failureDetailsKey), findsNothing);
      await _leave(tester);
    });

    testWidgets(
      'the media token is refused: the details name the server code',
      (tester) async {
        final repo = FakeLiveRepository(categories: _categories)
          ..tokenFailure = const ServerFailure(
            code: ErrorCode.internalError,
            rawCode: 'INTERNAL_ERROR',
            debugMessage: 'x',
            statusCode: 500,
          );
        await _pump(tester, repo: repo);
        await _goLive(tester);
        expect(repo.endRequests, ['room-host']);
        expect(
          find.descendant(
            of: find.byKey(GoLiveScreen.failureDetailsKey),
            matching: find.text('Details: GL-token:INTERNAL_ERROR'),
          ),
          findsOneWidget,
        );
        await _leave(tester);
      },
    );

    testWidgets('a successful try clears the last failure', (tester) async {
      final camera = FakeLiveMediaEngine()
        ..publishFailure = LivePublishException(
          LivePublishStage.connect,
          StateError('x'),
        );
      await _pump(tester, engine: camera);
      await _goLive(tester);
      expect(find.byKey(GoLiveScreen.failureDetailsKey), findsOneWidget);
      camera.publishFailure = null;
      // The error snack goes away first (it covers the button).
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(GoLiveScreen.startKey));
      await tester.pumpAndSettle();
      expect(find.byKey(GoLiveScreen.failureDetailsKey), findsNothing);
      expect(find.byKey(KHostBar.toolsKey), findsOneWidget);
      await _leave(tester);
    });
  });

  group('optional features never abort going live (D210)', () {
    testWidgets('the music player fails: the host stage is the plain camera', (
      tester,
    ) async {
      setViewport(tester, GoldenViewport.phone);
      await pumpScreen(
        tester,
        LiveHostToolsStage(
          roomId: 'room-host',
          engine: FakeLiveMediaEngine(),
          camera: const Text('camera picture'),
        ),
        overrides: [liveMusicProvider.overrideWith(_BrokenMusic.new)],
      );
      await tester.pump();
      expect(find.text('camera picture'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _leave(tester);
    });

    testWidgets('the background keeper throws: the live goes on, heartbeats '
        'run, the room is not ended', (tester) async {
      final (repo, _) = await _pump(
        tester,
        overrides: [
          liveBackgroundKeeperProvider.overrideWithValue(_BrokenKeeper()),
        ],
      );
      await _goLive(tester);
      expect(find.byKey(KHostBar.toolsKey), findsOneWidget);
      expect(repo.endRequests, isEmpty);
      expect(find.byKey(GoLiveScreen.failureDetailsKey), findsNothing);
      await tester.pump(const Duration(seconds: 31));
      expect(repo.heartbeats, isNotEmpty);
      await _leave(tester);
    });

    testWidgets('a room tool throws on start: the live goes on, the others '
        'start, the host is told once', (tester) async {
      final (repo, camera) = await _pump(
        tester,
        overrides: [liveQuipsProvider.overrideWith2(_BrokenQuips.new)],
      );
      await _goLive(tester);
      await tester.pump();
      expect(find.byKey(KHostBar.toolsKey), findsOneWidget);
      expect(repo.endRequests, isEmpty);
      expect(
        find.text(
          'Some live tools didn’t start and were switched off. '
          'Your live goes on.',
        ),
        findsOneWidget,
      );
      // The chat (started after the broken tool) still runs on the session.
      expect(camera.published, isNotNull);
      await _leave(tester);
    });
  });
}
