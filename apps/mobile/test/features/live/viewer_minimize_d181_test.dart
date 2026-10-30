// D181 (owner «زر التصغير لا يظهر للمشاهد»): viewers and seated guests
// minimize a live into the floating window (the host's D94 mechanism) —
// from the top bar (video and audio rooms) and from ≡ — keep the live
// while they browse, open it again with a tap and leave it with its ✕.
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/data/auth_repository_impl.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/live_room_screen.dart';
import 'package:kabso_live/features/live/presentation/go_live/go_live_parts.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_mini_window.dart';
import 'package:kabso_live/features/live/presentation/hub/live_hub_grid.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../helpers/fake_live_media_engine.dart';
import '../../helpers/fake_live_repository.dart';
import '../../helpers/fake_profile_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

LiveSeats _seats(LiveRoomMode mode, {int? mine}) {
  final me = testUser();
  final count = mode == LiveRoomMode.audio ? 10 : 4;
  return LiveSeats(
    roomId: 'room-0',
    mode: mode,
    version: 1,
    seatCount: count,
    seats: [
      for (var i = 1; i < count; i++)
        LiveSeat(
          index: i,
          state: i == mine ? LiveSeatState.taken : LiveSeatState.empty,
          user: i == mine
              ? UserSummary(
                  id: me.id,
                  username: me.username,
                  displayName: me.displayName,
                  avatarUrl: null,
                )
              : null,
        ),
    ],
    moderators: const [],
    mine: LiveSeatsMine(
      role: mine == null ? LiveSeatRole.viewer : LiveSeatRole.seated,
      seatIndex: mine,
      request: null,
      invite: null,
    ),
  );
}

Future<(FakeLiveRepository, FakeLiveMediaEngine)> _open(
  WidgetTester tester, {
  required LiveRoomMode mode,
  AppLanguage language = AppLanguage.en,
  int? mine,
}) async {
  final live = FakeLiveRepository(
    rooms: (_) => apiPage(apiRooms(2)),
    room: (id) => mode == LiveRoomMode.audio
        ? apiRoom(id: id).copyWith(mode: mode, seatCount: 10)
        : apiRoom(id: id),
  )..seatState = _seats(mode, mine: mine);
  final engine = FakeLiveMediaEngine()
    ..present.add('user-0')
    ..publishAllowed = mine != null;
  setViewport(tester, GoldenViewport.phone);
  await pumpKabsoApp(
    tester,
    language: language.name,
    liveRepository: live,
    liveMediaEngine: engine,
    overrides: [
      authRepositoryProvider.overrideWithValue(
        FakeAuthRepository(storedUser: testUser(), me: testUser()),
      ),
      secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
      profileRepositoryProvider.overrideWithValue(
        FakeProfileRepository(apiProfile()),
      ),
    ],
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('nav.home')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(LiveHubGrid.cardKey(0)));
  await tester.pumpAndSettle();
  expect(find.byType(LiveRoomScreen), findsOneWidget);
  return (live, engine);
}

Finder get _window => find.byKey(LiveMiniWindow.windowKey);

Future<void> _done(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 6));
}

void main() {
  for (final language in AppLanguage.values) {
    for (final mode in [LiveRoomMode.solo, LiveRoomMode.audio]) {
      testWidgets('${mode.name} viewer: the top bar minimizes; the live goes '
          'on over the hub; a tap opens it again; ✕ on the window leaves '
          '(${language.name})', (tester) async {
        final (live, engine) = await _open(
          tester,
          mode: mode,
          language: language,
        );
        await tester.tap(find.byKey(LiveRoomScreen.minimizeKey));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(LiveRoomScreen), findsNothing);
        expect(find.byKey(const Key('nav.home')), findsOneWidget);
        expect(_window, findsOneWidget);
        final video = find.descendant(
          of: _window,
          matching: find.byKey(const Key('remote.user-0')),
        );
        // Video: the host's video; audio: the host's picture.
        expect(video, mode == LiveRoomMode.audio ? findsNothing : findsOne);
        if (mode == LiveRoomMode.audio) {
          expect(
            find.descendant(of: _window, matching: find.byType(KAvatar)),
            findsOneWidget,
          );
        }
        // Still in the room: the media goes on.
        await tester.pump(const Duration(seconds: 12));
        expect(engine.stops, 0);
        expect(engine.joined, isNotNull);
        // The window sits at the reading end of the screen.
        final rect = tester.getRect(_window);
        final ar = language == AppLanguage.ar;
        expect(ar ? rect.left < 200 : rect.right > 230, isTrue);

        await tester.tap(_window);
        await tester.pumpAndSettle();
        expect(find.byType(LiveRoomScreen), findsOneWidget);
        expect(_window, findsNothing);
        expect(engine.stops, 0);

        // Minimized again, ✕ on the window leaves the live.
        await tester.tap(find.byKey(LiveRoomScreen.minimizeKey));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(LiveMiniWindow.closeKey));
        await tester.pumpAndSettle();
        expect(_window, findsNothing);
        expect(engine.stops, 1);
        expect(live.roomRequests.toSet(), {'room-0'});
        await _done(tester);
      });
    }
  }

  for (final mode in [LiveRoomMode.solo, LiveRoomMode.audio]) {
    testWidgets('${mode.name} seated guest: ≡ minimizes (no longer «Soon»); '
        'still seated and publishing in the window; back to the seat', (
      tester,
    ) async {
      final (_, engine) = await _open(tester, mode: mode, mine: 1);
      expect(engine.publishLocalCalls, isNotEmpty);
      await tester.tap(
        find.byKey(
          mode == LiveRoomMode.audio
              ? AudioRoomViewKeys.menu
              : LiveRoomScreen.menuKey,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(GoLiveKeys.tool('minimize')));
      await tester.pumpAndSettle();
      expect(find.byType(LiveRoomScreen), findsNothing);
      expect(_window, findsOneWidget);
      expect(engine.unpublishLocalCalls, 0);
      expect(engine.stops, 0);
      await tester.tap(_window);
      await tester.pumpAndSettle();
      expect(find.byType(LiveRoomScreen), findsOneWidget);
      if (mode == LiveRoomMode.solo) {
        expect(find.byKey(LiveRoomScreen.guestCameraKey), findsOneWidget);
      }
      expect(engine.publishLocalCalls, hasLength(1));
      expect(engine.unpublishLocalCalls, 0);
      await _done(tester);
    });
  }

  testWidgets('opening another live leaves the minimized one', (tester) async {
    final (_, engine) = await _open(tester, mode: LiveRoomMode.solo);
    await tester.tap(find.byKey(LiveRoomScreen.minimizeKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(LiveHubGrid.cardKey(1)));
    await tester.pumpAndSettle();
    expect(find.byType(LiveRoomScreen), findsOneWidget);
    expect(_window, findsNothing);
    expect(engine.stops, 1);
    await _done(tester);
  });
}
