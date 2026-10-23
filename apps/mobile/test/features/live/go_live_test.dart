// CP-010 L1: go live — the gates (hosting off, no hosting permission), the
// camera preview and its problems, the title rule, starting (room, token,
// publish, heartbeats), the guests switch while live, ending (confirmed),
// failures that roll back, the server ending the room, leaving while live,
// the Create mode bar, and Arabic RTL placement.

import 'dart:ui' show Tristate;

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/create/create_mode_bar.dart';
import 'package:kabso_live/features/live/data/live_media_engine.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/go_live_screen.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_live_media_engine.dart';
import '../../helpers/fake_live_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

const _notAllowed = ServerFailure(
  code: ErrorCode.liveHostingNotAllowed,
  rawCode: 'LIVE_HOSTING_NOT_ALLOWED',
  debugMessage: 'x',
  statusCode: 403,
);

const _ended = ServerFailure(
  code: ErrorCode.liveRoomEnded,
  rawCode: 'LIVE_ROOM_ENDED',
  debugMessage: 'x',
  statusCode: 409,
);

const _internal = ServerFailure(
  code: ErrorCode.internalError,
  rawCode: 'INTERNAL_ERROR',
  debugMessage: 'x',
  statusCode: 500,
);

final _categories = [
  const LiveCategory(slug: 'music', name: 'Music'),
  const LiveCategory(slug: 'chat', name: 'Chat'),
];

Future<(FakeLiveRepository, FakeLiveMediaEngine)> _pump(
  WidgetTester tester, {
  bool hostingEnabled = true,
  bool canHost = true,
  AppLanguage language = AppLanguage.en,
  FakeLiveMediaEngine? engine,
  FakeLiveRepository? repo,
}) async {
  final live =
      repo ??
      FakeLiveRepository(
        hostingEnabled: hostingEnabled,
        categories: _categories,
      );
  final camera = engine ?? FakeLiveMediaEngine();
  setViewport(tester, GoldenViewport.phone);
  await tester.pumpWidget(const SizedBox.shrink());
  await pumpScreen(
    tester,
    const GoLiveScreen(),
    language: language,
    overrides: [
      liveRepositoryProvider.overrideWithValue(live),
      liveMediaEngineProvider.overrideWithValue(() => camera),
      currentUserProvider.overrideWithValue(
        testUser().copyWith(canHost: canHost),
      ),
    ],
  );
  await tester.pumpAndSettle();
  return (live, camera);
}

/// Disposes the screen (and its provider scope) so no timer outlives the
/// test.
Future<void> _leave(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

Future<void> _goLive(
  WidgetTester tester, {
  String title = 'Evening chat',
}) async {
  await tester.enterText(find.byKey(GoLiveScreen.titleKey), title);
  await tester.tap(find.byKey(GoLiveScreen.startKey));
  await tester.pumpAndSettle();
}

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(GoLiveScreen)));

void main() {
  group('gates', () {
    testWidgets('hosting switched off: explained, the camera never starts', (
      tester,
    ) async {
      final (repo, camera) = await _pump(tester, hostingEnabled: false);
      final l10n = _l10n(tester);
      expect(find.byKey(GoLiveScreen.unavailableKey), findsOneWidget);
      expect(find.text(l10n.goLiveUnavailableTitle), findsOneWidget);
      expect(find.byKey(GoLiveScreen.startKey), findsNothing);
      expect(camera.previewStarts, 0);
      expect(repo.startRequests, isEmpty);
      await _leave(tester);
    });

    testWidgets('no hosting permission: explained, the camera never starts', (
      tester,
    ) async {
      final (repo, camera) = await _pump(tester, canHost: false);
      final l10n = _l10n(tester);
      expect(find.byKey(GoLiveScreen.notAllowedKey), findsOneWidget);
      expect(find.text(l10n.goLiveNotAllowedBody), findsOneWidget);
      expect(find.byKey(GoLiveScreen.startKey), findsNothing);
      expect(camera.previewStarts, 0);
      // The mode bar still leads elsewhere.
      expect(find.byType(CreateModeBar), findsOneWidget);
      await _leave(tester);
    });
  });

  group('preview', () {
    testWidgets('the camera starts with the tools and the categories', (
      tester,
    ) async {
      final (_, camera) = await _pump(tester);
      final l10n = _l10n(tester);
      expect(camera.previewStarts, 1);
      expect(find.byKey(FakeLiveMediaEngine.previewKey), findsOneWidget);
      for (final key in [
        GoLiveScreen.closeKey,
        GoLiveScreen.titleKey,
        GoLiveScreen.flipKey,
        GoLiveScreen.micKey,
        GoLiveScreen.guestsKey,
        GoLiveScreen.startKey,
      ]) {
        expect(find.byKey(key), findsOneWidget, reason: '$key');
      }
      expect(find.text(l10n.goLiveNoCategory), findsOneWidget);
      expect(find.text('Music'), findsOneWidget);
      expect(find.text(l10n.goLiveTitleHint), findsOneWidget);
      // Nothing that does not work: no flash, timer, beauty, filters.
      expect(find.byIcon(Icons.flash_on), findsNothing);
      expect(find.byIcon(Icons.timer_outlined), findsNothing);
      await _leave(tester);
    });

    testWidgets('flip and microphone act on the camera', (tester) async {
      final (_, camera) = await _pump(tester);
      final l10n = _l10n(tester);
      await tester.tap(find.byKey(GoLiveScreen.flipKey));
      await tester.pumpAndSettle();
      expect(camera.flips, 1);
      expect(camera.frontCamera, isFalse);

      await tester.tap(find.byKey(GoLiveScreen.micKey));
      await tester.pumpAndSettle();
      expect(camera.micEnabled, isFalse);
      expect(find.text(l10n.goLiveMicOff), findsOneWidget);
      await _leave(tester);
    });

    testWidgets('camera denied: explained with Try again', (tester) async {
      final camera = FakeLiveMediaEngine()
        ..previewProblem = LiveCaptureProblem.denied;
      await _pump(tester, engine: camera);
      final l10n = _l10n(tester);
      expect(find.byKey(GoLiveScreen.captureFailedKey), findsOneWidget);
      expect(find.text(l10n.goLiveCameraDeniedTitle), findsOneWidget);
      expect(find.byKey(GoLiveScreen.startKey), findsNothing);

      camera.previewProblem = null;
      await tester.tap(find.byKey(GoLiveScreen.retryKey));
      await tester.pumpAndSettle();
      expect(camera.previewStarts, 2);
      expect(find.byKey(GoLiveScreen.startKey), findsOneWidget);
      await _leave(tester);
    });

    testWidgets('no camera: the unavailable message', (tester) async {
      await _pump(
        tester,
        engine: FakeLiveMediaEngine()
          ..previewProblem = LiveCaptureProblem.unavailable,
      );
      expect(
        find.text(_l10n(tester).goLiveCameraUnavailableTitle),
        findsOneWidget,
      );
      await _leave(tester);
    });

    testWidgets('a title is required', (tester) async {
      final (repo, _) = await _pump(tester);
      await tester.tap(find.byKey(GoLiveScreen.startKey));
      await tester.pump();
      expect(find.text(_l10n(tester).goLiveTitleRequired), findsOneWidget);
      expect(repo.startRequests, isEmpty);
      await _leave(tester);
    });

    testWidgets('the title is capped at 80 characters', (tester) async {
      await _pump(tester);
      await tester.enterText(find.byKey(GoLiveScreen.titleKey), 'x' * 100);
      final field = tester.widget<TextField>(find.byKey(GoLiveScreen.titleKey));
      expect(field.controller!.text.length, GoLiveScreen.titleMaxLength);
      await _leave(tester);
    });
  });

  group('on air', () {
    testWidgets('start: room, token, publish, then heartbeats', (tester) async {
      final (repo, camera) = await _pump(tester);
      final l10n = _l10n(tester);
      await tester.tap(find.byKey(GoLiveScreen.categoryKey('music')));
      await tester.tap(find.byKey(GoLiveScreen.guestsKey));
      await tester.pumpAndSettle();
      await _goLive(tester, title: '  Evening chat  ');

      expect(repo.startRequests, [
        (title: 'Evening chat', categorySlug: 'music', allowGuests: false),
      ]);
      expect(repo.tokenRequests, [(roomId: 'room-host', guestId: null)]);
      expect(camera.published?.token, 'token-room-host');
      expect(find.byKey(GoLiveScreen.elapsedKey), findsOneWidget);
      expect(find.byKey(GoLiveScreen.endKey), findsOneWidget);
      expect(find.byKey(GoLiveScreen.startKey), findsNothing);
      expect(find.byType(CreateModeBar), findsNothing);
      expect(find.text('Evening chat'), findsOneWidget);

      await tester.pump(const Duration(seconds: 15));
      expect(repo.heartbeats, ['room-host']);
      await tester.pump(const Duration(seconds: 15));
      expect(repo.heartbeats, hasLength(2));
      expect(find.bySemanticsLabel(l10n.goLiveElapsed('0:30')), findsOneWidget);
      await _leave(tester);
    });

    testWidgets('guests switch while live goes to the server', (tester) async {
      final (repo, _) = await _pump(tester);
      final l10n = _l10n(tester);
      await _goLive(tester);
      await tester.tap(find.byKey(GoLiveScreen.guestsKey));
      await tester.pump();
      expect(repo.guestUpdates, [(roomId: 'room-host', allow: false)]);
      expect(find.text(l10n.goLiveGuestsOff), findsOneWidget);
      await _leave(tester);
    });

    testWidgets('a failed guests change keeps the switch', (tester) async {
      final (repo, _) = await _pump(tester);
      await _goLive(tester);
      repo.guestsFailure = _internal;
      await tester.tap(find.byKey(GoLiveScreen.guestsKey));
      await tester.pump();
      final semantics = tester.getSemantics(find.byKey(GoLiveScreen.guestsKey));
      expect(semantics.flagsCollection.isToggled, Tristate.isTrue);
      await _leave(tester);
    });

    testWidgets('end asks first, then ends and stops the camera', (
      tester,
    ) async {
      final (repo, camera) = await _pump(tester);
      final l10n = _l10n(tester);
      await _goLive(tester);

      await tester.tap(find.byKey(GoLiveScreen.endKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.goLiveKeepGoing));
      await tester.pumpAndSettle();
      expect(repo.endRequests, isEmpty);

      await tester.tap(find.byKey(GoLiveScreen.endKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(GoLiveScreen.endConfirmKey));
      await tester.pumpAndSettle();
      expect(repo.endRequests, ['room-host']);
      expect(camera.stops, greaterThanOrEqualTo(1));
      expect(camera.running, isFalse);
      expect(find.byKey(GoLiveScreen.endedKey), findsOneWidget);
      expect(find.text(l10n.goLiveEndedTitle), findsOneWidget);

      // No heartbeat after the end.
      await tester.pump(const Duration(seconds: 30));
      expect(repo.heartbeats, isEmpty);
      await _leave(tester);
    });

    testWidgets('close while live asks to end too', (tester) async {
      final (repo, _) = await _pump(tester);
      await _goLive(tester);
      await tester.tap(find.byKey(GoLiveScreen.closeKey));
      await tester.pumpAndSettle();
      expect(find.byKey(GoLiveScreen.endConfirmKey), findsOneWidget);
      await tester.tap(find.byKey(GoLiveScreen.endConfirmKey));
      await tester.pumpAndSettle();
      expect(repo.endRequests, ['room-host']);
      await _leave(tester);
    });

    testWidgets('the server ended the room: the heartbeat stops the live', (
      tester,
    ) async {
      final (repo, camera) = await _pump(tester);
      await _goLive(tester);
      repo.heartbeatFailure = _ended;
      await tester.pump(const Duration(seconds: 15));
      await tester.pumpAndSettle();
      expect(find.byKey(GoLiveScreen.endedKey), findsOneWidget);
      expect(camera.running, isFalse);
      await tester.pump(const Duration(seconds: 30));
      expect(repo.heartbeats, hasLength(1));
      await _leave(tester);
    });

    testWidgets('a transient heartbeat failure keeps the live', (tester) async {
      final (repo, _) = await _pump(tester);
      await _goLive(tester);
      repo.heartbeatFailure = _internal;
      await tester.pump(const Duration(seconds: 15));
      repo.heartbeatFailure = null;
      await tester.pump(const Duration(seconds: 15));
      expect(repo.heartbeats, hasLength(2));
      expect(find.byKey(GoLiveScreen.endKey), findsOneWidget);
      await _leave(tester);
    });

    testWidgets('leaving while live ends the room and stops the camera', (
      tester,
    ) async {
      final (repo, camera) = await _pump(tester);
      await _goLive(tester);
      await _leave(tester);
      expect(repo.endRequests, ['room-host']);
      expect(camera.running, isFalse);
    });
  });

  group('failures', () {
    testWidgets('no permission on the server: message, back to preview', (
      tester,
    ) async {
      final repo = FakeLiveRepository(categories: _categories)
        ..startFailure = _notAllowed;
      final (_, camera) = await _pump(tester, repo: repo);
      await _goLive(tester);
      expect(
        find.text(_l10n(tester).errorLiveHostingNotAllowed),
        findsOneWidget,
      );
      expect(repo.tokenRequests, isEmpty);
      expect(camera.published, isNull);
      expect(find.byKey(GoLiveScreen.startKey), findsOneWidget);
      await _leave(tester);
    });

    testWidgets('publish fails: the new room is ended, not left behind', (
      tester,
    ) async {
      final camera = FakeLiveMediaEngine()..publishFailure = _internal;
      final (repo, _) = await _pump(tester, engine: camera);
      await _goLive(tester);
      expect(repo.endRequests, ['room-host']);
      expect(find.byKey(GoLiveScreen.startKey), findsOneWidget);
      expect(find.byKey(GoLiveScreen.endKey), findsNothing);
      await tester.pump(const Duration(seconds: 30));
      expect(repo.heartbeats, isEmpty);
      await _leave(tester);
    });
  });

  testWidgets('Arabic RTL: close at the right, the rail at the left', (
    tester,
  ) async {
    await _pump(tester, language: AppLanguage.ar);
    final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
    final close = tester.getCenter(find.byKey(GoLiveScreen.closeKey));
    final flip = tester.getCenter(find.byKey(GoLiveScreen.flipKey));
    expect(close.dx, greaterThan(width / 2));
    expect(flip.dx, lessThan(width / 2));
    expect(find.text('ابدأ البث'), findsOneWidget);
    expect(find.text('بث مباشر'), findsOneWidget);
    await _leave(tester);
  });

  group('Create mode bar', () {
    Future<GoRouter> pumpRouter(WidgetTester tester) async {
      final router = GoRouter(
        initialLocation: '/start',
        routes: [
          GoRoute(
            path: '/start',
            builder: (context, _) => Scaffold(
              body: Center(
                child: CreateModeBar(
                  selected: CreateMode.post,
                  onSelect: (mode) => switch (mode) {
                    CreateMode.post => null,
                    CreateMode.story => context.push(AppRoutes.newStory),
                    CreateMode.live => context.push(AppRoutes.goLive),
                  },
                ),
              ),
            ),
          ),
          GoRoute(
            path: AppRoutes.goLive,
            builder: (_, _) => const Text('go-live'),
          ),
          GoRoute(
            path: AppRoutes.newStory,
            builder: (_, _) => const Text('new-story'),
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp.router(
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
      );
      await tester.pumpAndSettle();
      return router;
    }

    testWidgets('LIVE opens go live, Story opens a new story', (tester) async {
      await pumpRouter(tester);
      await tester.tap(find.byKey(CreateModeBar.modeKey(CreateMode.live)));
      await tester.pumpAndSettle();
      expect(find.text('go-live'), findsOneWidget);
    });

    testWidgets('Story opens a new story', (tester) async {
      await pumpRouter(tester);
      await tester.tap(find.byKey(CreateModeBar.modeKey(CreateMode.story)));
      await tester.pumpAndSettle();
      expect(find.text('new-story'), findsOneWidget);
    });

    testWidgets('the selected mode is marked for screen readers', (
      tester,
    ) async {
      await pumpRouter(tester);
      final post = tester.getSemantics(
        find.byKey(CreateModeBar.modeKey(CreateMode.post)),
      );
      expect(post.flagsCollection.isSelected, Tristate.isTrue);
    });
  });
}
