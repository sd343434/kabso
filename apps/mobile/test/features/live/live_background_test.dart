// D123 (owner, staging device): a live keeps running in the background
// (foreground service with an ongoing notification), nothing ends on a
// lifecycle change, the camera pauses away and resumes on return, the
// notification's End ends the live through the normal path; minimizing a
// live started from Create returns to the tab the person came from. Also
// D123: the audio seat counts are 5, 10, 15 and 20.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/app/shell/app_shell.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/application/live_background.dart';
import 'package:kabso_live/features/live/application/live_host_controller.dart';
import 'package:kabso_live/features/live/application/live_room_session.dart';
import 'package:kabso_live/features/live/data/live_media_engine.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/go_live_screen.dart';
import 'package:kabso_live/features/live/presentation/go_live/go_live_parts.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_host_parts.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_mini_window.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../helpers/fake_live_media_engine.dart';
import '../../helpers/fake_live_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

/// Records what the keeper asks of the platform service; [tap] plays a tap
/// on the notification.
class FakeLiveBackgroundService implements LiveBackgroundService {
  final List<String> calls = [];
  LiveBackgroundSpec? running;
  final _actions = StreamController<LiveBackgroundAction>.broadcast();

  @override
  Future<void> start(LiveBackgroundSpec spec) async {
    calls.add('start:${spec.role.name}');
    running = spec;
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
    running = null;
  }

  @override
  Stream<LiveBackgroundAction> get actions => _actions.stream;

  void tap(LiveBackgroundAction action) => _actions.add(action);
}

const _texts = LiveBackgroundTexts(
  channelName: 'Live',
  hostTitle: 'Your live is on',
  guestTitle: 'On a seat',
  listenerTitle: 'Listening',
  body: 'Tap to return to the room',
  endLive: 'End live',
  leave: 'Leave',
);

final _categories = [const LiveCategory(slug: 'music', name: 'Music')];

/// Goes through the lifecycle the way Android reports leaving the app.
Future<void> _toBackground(WidgetTester tester) async {
  for (final s in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(s);
    await tester.pump();
  }
}

Future<void> _toForeground(WidgetTester tester) async {
  for (final s in [
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(s);
    await tester.pump();
  }
}

/// The real shell (AppShell, five branches) with Create opening Go live
/// the way Create's LIVE mode does (a push over the shell).
GoRouter _shellRouter() {
  Widget page(String name) => Scaffold(body: Center(child: Text(name)));
  return GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      GoRoute(path: AppRoutes.goLive, builder: (_, _) => const GoLiveScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(navigationShell: shell),
        branches: [
          for (final location in AppRoutes.shellBranches)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: location,
                  builder: (context, _) => location == AppRoutes.create
                      ? Scaffold(
                          body: Center(
                            child: TextButton(
                              key: const Key('create.live'),
                              onPressed: () => context.push(AppRoutes.goLive),
                              child: const Text('create'),
                            ),
                          ),
                        )
                      : page('tab:$location'),
                ),
              ],
            ),
        ],
      ),
    ],
  );
}

Future<(FakeLiveRepository, FakeLiveMediaEngine, FakeLiveBackgroundService)>
_pumpApp(WidgetTester tester, GoRouter router) async {
  final repo = FakeLiveRepository(categories: _categories);
  final camera = FakeLiveMediaEngine();
  final service = FakeLiveBackgroundService();
  final prefs = await testPrefs();
  addTearDown(router.dispose);
  setViewport(tester, GoldenViewport.phone);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        liveRepositoryProvider.overrideWithValue(repo),
        liveMediaEngineProvider.overrideWithValue(() => camera),
        liveBackgroundServiceProvider.overrideWithValue(service),
        currentUserProvider.overrideWithValue(
          testUser().copyWith(canHost: true),
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
        builder: (context, child) => Stack(
          children: [
            child!,
            LiveMiniWindow(router: router),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (repo, camera, service);
}

Future<void> _openGoLiveFromCreate(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('nav.create')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('create.live')));
  await tester.pumpAndSettle();
  expect(find.byType(GoLiveScreen), findsOneWidget);
}

Future<void> _goLive(WidgetTester tester) async {
  await tester.enterText(find.byKey(GoLiveScreen.titleKey), 'Evening chat');
  await tester.tap(find.byKey(GoLiveScreen.startKey));
  await tester.pumpAndSettle();
  expect(find.byKey(KHostBar.toolsKey), findsOneWidget);
}

Future<void> _leave(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  test('D123: a saved 25-seat choice becomes 20 (25 is no longer offered)', () {
    const audio = [5, 10, 15, 20];
    expect(fitSeatCount(25, audio), 20);
    expect(fitSeatCount(20, audio), 20);
    expect(fitSeatCount(9, audio), 10);
    expect(const LiveSeatCounts().audio, audio);
  });

  group('LiveBackgroundKeeper', () {
    test('starts with the first holder, stops after the last', () async {
      final service = FakeLiveBackgroundService();
      final keeper = LiveBackgroundKeeper(service);
      final a = Object();
      final b = Object();
      keeper
        ..hold(
          a,
          LiveBackgroundSpec.of(LiveBackgroundRole.listener, _texts),
          onEnd: () {},
        )
        ..hold(
          a,
          LiveBackgroundSpec.of(LiveBackgroundRole.listener, _texts),
          onEnd: () {},
        );
      await keeper.settled;
      // The same spec again changes nothing.
      expect(service.calls, ['start:listener']);
      expect(service.running?.title, 'Listening');
      expect(service.running?.microphone, isFalse);

      // A host outranks a listener; the notification shows the host.
      keeper.hold(
        b,
        LiveBackgroundSpec.of(LiveBackgroundRole.host, _texts),
        onEnd: () {},
      );
      await keeper.settled;
      expect(service.running?.title, 'Your live is on');
      expect(service.running?.actionLabel, 'End live');
      expect(service.running?.microphone, isTrue);

      keeper.release(b);
      await keeper.settled;
      expect(service.running?.role, LiveBackgroundRole.listener);
      keeper.release(a);
      await keeper.settled;
      expect(service.calls, [
        'start:listener',
        'start:host',
        'start:listener',
        'stop',
      ]);
      expect(keeper.shown, isNull);
      keeper.dispose();
    });

    test('the notification acts on the holder it shows', () async {
      final service = FakeLiveBackgroundService();
      final keeper = LiveBackgroundKeeper(service);
      final ended = <String>[];
      final opened = <String>[];
      keeper
        ..hold(
          'guest',
          LiveBackgroundSpec.of(LiveBackgroundRole.guest, _texts),
          onEnd: () => ended.add('guest'),
        )
        ..hold(
          'host',
          LiveBackgroundSpec.of(LiveBackgroundRole.host, _texts),
          onEnd: () => ended.add('host'),
          onOpen: () => opened.add('host'),
        );
      service
        ..tap(LiveBackgroundAction.open)
        ..tap(LiveBackgroundAction.end);
      await Future<void>.delayed(Duration.zero);
      expect(opened, ['host']);
      expect(ended, ['host']);
      keeper.dispose();
    });

    test('away and back: told once each; inactive changes nothing', () {
      final keeper = LiveBackgroundKeeper(FakeLiveBackgroundService());
      final events = <String>[];
      keeper
        ..hold(
          'host',
          LiveBackgroundSpec.of(LiveBackgroundRole.host, _texts),
          onEnd: () => events.add('end'),
          onBackground: () => events.add('away'),
          onForeground: () => events.add('back'),
        )
        ..handleLifecycle(AppLifecycleState.inactive)
        ..handleLifecycle(AppLifecycleState.resumed);
      expect(events, isEmpty);
      keeper
        ..handleLifecycle(AppLifecycleState.inactive)
        ..handleLifecycle(AppLifecycleState.hidden)
        ..handleLifecycle(AppLifecycleState.paused);
      expect(events, ['away']);
      expect(keeper.away, isTrue);
      keeper
        ..handleLifecycle(AppLifecycleState.hidden)
        ..handleLifecycle(AppLifecycleState.inactive)
        ..handleLifecycle(AppLifecycleState.resumed);
      expect(events, ['away', 'back']);
      keeper.dispose();
    });
  });

  group('host in the background', () {
    testWidgets('solo: the service runs while live; the app going away '
        'ends nothing, heartbeats go on, the camera pauses and resumes', (
      tester,
    ) async {
      final router = _shellRouter();
      final (repo, camera, service) = await _pumpApp(tester, router);
      await _openGoLiveFromCreate(tester);
      await _goLive(tester);
      expect(service.calls, ['start:host']);
      expect(service.running?.title, 'Your live is on');
      expect(service.running?.actionLabel, 'End live');
      expect(service.running?.microphone, isTrue);

      await _toBackground(tester);
      expect(camera.videoPauses, [true]);
      // Away for a minute: still on air, beating every 15 s.
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(seconds: 15));
      }
      expect(repo.endRequests, isEmpty);
      expect(repo.heartbeats, hasLength(4));
      expect(camera.stops, 0);
      expect(find.byKey(KHostBar.toolsKey), findsOneWidget);

      await _toForeground(tester);
      await tester.pump();
      expect(camera.videoPauses, [true, false]);
      // Back: one heartbeat at once.
      expect(repo.heartbeats, hasLength(5));
      expect(repo.endRequests, isEmpty);
      expect(service.calls, ['start:host']);

      // End from ✕: the service stops.
      await tester.tap(find.byKey(GoLiveScreen.closeKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(GoLiveScreen.endConfirmKey));
      await tester.pumpAndSettle();
      expect(repo.endRequests, ['room-host']);
      expect(service.calls, ['start:host', 'stop']);
      await _leave(tester);
    });

    testWidgets('audio: the camera is never touched in the background', (
      tester,
    ) async {
      final router = _shellRouter();
      final (repo, camera, service) = await _pumpApp(tester, router);
      await _openGoLiveFromCreate(tester);
      await tester.tap(find.byKey(GoLiveKeys.mode(LiveRoomMode.audio)));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(GoLiveScreen.titleKey), 'Night talk');
      await tester.tap(find.byKey(GoLiveScreen.startKey));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.pumpAndSettle();
      expect(service.calls, ['start:host']);
      await _toBackground(tester);
      await tester.pump(const Duration(seconds: 15));
      await _toForeground(tester);
      expect(camera.videoPauses, isEmpty);
      expect(repo.endRequests, isEmpty);
      await _leave(tester);
    });

    testWidgets("the notification's End ends the live like ✕", (tester) async {
      final router = _shellRouter();
      final (repo, _, service) = await _pumpApp(tester, router);
      await _openGoLiveFromCreate(tester);
      await _goLive(tester);
      await _toBackground(tester);
      service.tap(LiveBackgroundAction.end);
      await tester.pump();
      await tester.pump();
      expect(repo.endRequests, ['room-host']);
      await _toForeground(tester);
      await tester.pumpAndSettle();
      expect(find.byKey(GoLiveScreen.endedKey), findsOneWidget);
      expect(service.calls, ['start:host', 'stop']);
      await _leave(tester);
    });
  });

  group('minimize returns where the person came from (D123)', () {
    testWidgets('from the Live hub via Create: back on Home with the '
        'floating window, not on Create', (tester) async {
      final router = _shellRouter();
      final (repo, _, service) = await _pumpApp(tester, router);
      await _openGoLiveFromCreate(tester);
      await _goLive(tester);
      // D135: minimize is in ≡ (Room Tools).
      await tester.tap(find.byKey(KHostBar.toolsKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(GoLiveKeys.tool('minimize')));
      await tester.pumpAndSettle();
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        AppRoutes.home,
      );
      expect(find.text('tab:${AppRoutes.home}'), findsOneWidget);
      expect(find.text('create'), findsNothing);
      expect(find.byKey(LiveMiniWindow.windowKey), findsOneWidget);
      expect(repo.endRequests, isEmpty);

      // The notification's tap opens the minimized live full screen.
      service.tap(LiveBackgroundAction.open);
      await tester.pumpAndSettle();
      expect(find.byType(GoLiveScreen), findsOneWidget);
      expect(find.byKey(LiveMiniWindow.windowKey), findsNothing);
      await _leave(tester);
    });

    testWidgets('from Messages via Create: back on Messages', (tester) async {
      final router = _shellRouter();
      await _pumpApp(tester, router);
      await tester.tap(find.byKey(const Key('nav.messages')));
      await tester.pumpAndSettle();
      await _openGoLiveFromCreate(tester);
      await _goLive(tester);
      // D135: minimize is in ≡ (Room Tools).
      await tester.tap(find.byKey(KHostBar.toolsKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(GoLiveKeys.tool('minimize')));
      await tester.pumpAndSettle();
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        AppRoutes.messages,
      );
      expect(find.byKey(LiveMiniWindow.windowKey), findsOneWidget);
      await _leave(tester);
    });

    testWidgets('system back while live does the same', (tester) async {
      final router = _shellRouter();
      final (repo, _, _) = await _pumpApp(tester, router);
      await _openGoLiveFromCreate(tester);
      await _goLive(tester);
      final navigator = tester.state<NavigatorState>(
        find.byType(Navigator).first,
      );
      await navigator.maybePop();
      await tester.pumpAndSettle();
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        AppRoutes.home,
      );
      expect(find.byKey(LiveMiniWindow.windowKey), findsOneWidget);
      expect(repo.endRequests, isEmpty);
      await _leave(tester);
    });
  });

  group('viewer session', () {
    LiveSeats seats({int? mySeat}) => LiveSeats(
      roomId: 'room-0',
      mode: LiveRoomMode.audio,
      version: 1,
      seatCount: 10,
      seats: [
        for (var i = 1; i < 10; i++)
          LiveSeat(index: i, state: LiveSeatState.empty, user: null),
      ],
      moderators: const [],
      mine: LiveSeatsMine(
        role: mySeat == null ? LiveSeatRole.viewer : LiveSeatRole.seated,
        seatIndex: mySeat,
        request: null,
        invite: null,
      ),
    );

    test('audio listener, then seated guest, then off the seat; released '
        'when the session goes', () async {
      final repo = FakeLiveRepository()..seatState = seats();
      final engine = FakeLiveMediaEngine()..publishAllowed = true;
      final service = FakeLiveBackgroundService();
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          liveRepositoryProvider.overrideWithValue(repo),
          liveMediaEngineProvider.overrideWithValue(() => engine),
          liveBackgroundServiceProvider.overrideWithValue(service),
          currentUserProvider.overrideWithValue(testUser()),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(
        liveRoomSessionProvider('room-0'),
        (_, _) {},
      );
      final session = container.read(
        liveRoomSessionProvider('room-0').notifier,
      );
      var left = 0;
      await session.start(
        apiRoom().copyWith(mode: LiveRoomMode.audio, seatCount: 10),
        background: _texts,
        onLeave: () => left++,
      );
      final keeper = container.read(liveBackgroundKeeperProvider);
      await keeper.settled;
      expect(service.calls, ['start:listener']);
      service.tap(LiveBackgroundAction.end);
      await Future<void>.delayed(Duration.zero);
      expect(left, 1);

      repo.seatState = seats(mySeat: 3);
      await session.refreshSeats();
      await Future<void>.delayed(Duration.zero);
      await keeper.settled;
      expect(service.running?.role, LiveBackgroundRole.guest);

      // The guest's Leave leaves the seat (the normal path).
      service.tap(LiveBackgroundAction.end);
      await Future<void>.delayed(Duration.zero);
      expect(repo.seatCalls, contains('leaveSeat'));

      sub.close();
      container.invalidate(liveRoomSessionProvider('room-0'));
      await Future<void>.delayed(Duration.zero);
      await keeper.settled;
      expect(service.running, isNull);
      expect(service.calls.last, 'stop');
    });
  });
}
