// KL-034: the live room — route from the hub, every production state,
// follow with optimistic update and rollback, close and back, the
// non-dimming gift sheet with Send disabled, no fake counts or decorative
// controls, RTL, text scale and contrast on the media scrims.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/data/auth_repository_impl.dart';
import 'package:kabso_live/features/auth/domain/entities.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/emoji/kabi_emoji.dart';
import 'package:kabso_live/features/live/data/live_media_engine.dart';
import 'package:kabso_live/features/live/data/live_permissions.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/live/domain/live_gift_models.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/live_room_screen.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_audio_room.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_rankings_sheet.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_seat_tiles.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_theme_art.dart';
import 'package:kabso_live/features/live/presentation/go_live/seat_controls.dart';
import 'package:kabso_live/features/live/presentation/hub/live_grid_card.dart';
import 'package:kabso_live/features/live/presentation/hub/live_hub_grid.dart';
import 'package:kabso_live/features/live/presentation/live_permission_sheet.dart';
import 'package:kabso_live/features/live/presentation/widgets/guest_seats.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_gift_art.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_gift_effects_layer.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_gift_sheet.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_person_boxes.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_person_tools.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_chat.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_scaffold.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_states.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_tap_layer.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_view_data.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_viewer_parts.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_win_banner.dart';
import 'package:kabso_live/features/live/presentation/widgets/pk_layout.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:kabso_live/features/profile/domain/profile_models.dart';
import 'package:kabso_live/features/safety/safety_repository.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../fixtures/live/live_fixtures.dart';
import '../../fixtures/live/live_gift_fixtures.dart';
import '../../helpers/component_harness.dart';
import '../../helpers/fake_live_gift_repository.dart';
import '../../helpers/fake_live_media_engine.dart';
import '../../helpers/fake_live_permissions.dart';
import '../../helpers/fake_live_repository.dart';
import '../../helpers/fake_profile_repository.dart';
import '../../helpers/fake_safety_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

const _internal = ServerFailure(
  code: ErrorCode.internalError,
  rawCode: 'INTERNAL_ERROR',
  debugMessage: 'x',
  statusCode: 500,
  requestId: 'req-1',
);

const _rateLimited = ServerFailure(
  code: ErrorCode.rateLimited,
  rawCode: 'RATE_LIMITED',
  debugMessage: 'x',
  statusCode: 429,
);

/// The room screen alone (no router; close pops the test navigator).
Future<(FakeLiveRepository, FakeProfileRepository)> _pumpRoom(
  WidgetTester tester, {
  RoomHandler? room,
  PublicProfile? profile,
  AppLanguage language = AppLanguage.en,
  GoldenViewport viewport = GoldenViewport.phone,
  bool settle = true,
  FakeLiveMediaEngine? engine,
  FakeLiveRepository? repo,
  User? user,
  FakeLiveGiftRepository? gifts,
  FakeLivePermissions? permissions,
}) async {
  final ar = language == AppLanguage.ar;
  final live =
      repo ?? FakeLiveRepository(room: room ?? (id) => apiRoom(id: id));
  final profiles = FakeProfileRepository(profile ?? apiProfile(ar: ar));
  setViewport(tester, viewport);
  // A fresh tree (and provider container) for every call in a test.
  await tester.pumpWidget(const SizedBox.shrink());
  await pumpScreen(
    tester,
    const LiveRoomScreen(roomId: 'room-0'),
    language: language,
    liveMediaEngine: engine,
    liveGiftRepository: gifts,
    overrides: [
      liveRepositoryProvider.overrideWithValue(live),
      profileRepositoryProvider.overrideWithValue(profiles),
      if (user != null) currentUserProvider.overrideWithValue(user),
      if (permissions != null)
        livePermissionsProvider.overrideWithValue(permissions),
    ],
  );
  settle
      ? await tester.pumpAndSettle()
      : await tester.pump(const Duration(milliseconds: 50));
  return (live, profiles);
}

Finder _label(String label) => find.bySemanticsLabel(label);

/// CP-010: the stage while the host is not in the media session.
const _hostAway = Key('room.hostAway');

/// The host pill (its label starts with "host, host profile").
Finder _hostPill(AppLocalizations l, String host) => find.bySemanticsLabel(
  RegExp('^${RegExp.escape(l.liveRoomHostSemantics(host))}'),
);

/// D141: the host pill's picture (a tap on the pill opens the host; its
/// middle holds the @username, which copies it instead).
Finder _hostPillPicture(AppLocalizations l, String host) => find
    .descendant(of: _hostPill(l, host), matching: find.byType(KAvatar))
    .first;

/// A chat line (rich text with an icon).
/// Every visible text (Text and rich text) in the tree.
List<String> _texts(WidgetTester tester) => [
  for (final element in find.byWidgetPredicate((w) => w is RichText).evaluate())
    (element.widget as RichText).text.toPlainText(),
];

void main() {
  final l10n = l10nFor(AppLanguage.en);

  group('route (/live/room/:roomId)', () {
    Future<FakeLiveRepository> pumpApp(WidgetTester tester) async {
      final live = FakeLiveRepository(
        rooms: (_) => apiPage(apiRooms(2)),
        room: (id) => apiRoom(id: id),
      );
      setViewport(tester, GoldenViewport.phone);
      await pumpKabsoApp(
        tester,
        liveRepository: live,
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
      return live;
    }

    testWidgets('a hub card opens its room full screen (no bottom nav); '
        'Close returns to the hub', (tester) async {
      final live = await pumpApp(tester);
      // D124: the hub's grid; a card opens its room.
      await tester.tap(find.byKey(LiveHubGrid.cardKey(0)));
      await tester.pumpAndSettle();

      expect(find.byType(LiveRoomScreen), findsOneWidget);
      expect(live.roomRequests, ['room-0']);
      expect(find.byKey(const Key('nav.home')), findsNothing);
      expect(find.byKey(_hostAway), findsOneWidget);

      await tester.tap(_label(l10n.liveClose));
      await tester.pumpAndSettle();
      // D131 (ref 160): not following the host yet: the leave prompt.
      expect(find.byType(KLeavePrompt), findsOneWidget);
      await tester.tap(find.byKey(KLeavePrompt.exitKey));
      await tester.pumpAndSettle();
      expect(find.byType(LiveRoomScreen), findsNothing);
      expect(find.byKey(const Key('nav.home')), findsOneWidget);
      expect(find.byType(KLiveGridCard), findsWidgets);
    });

    testWidgets('system back leaves the room for the hub', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(LiveHubGrid.cardKey(0)));
      await tester.pumpAndSettle();
      expect(find.byType(LiveRoomScreen), findsOneWidget);

      // The Android back button: D131, the leave prompt first (the
      // viewer does not follow the host); Back again keeps watching.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(KLeavePrompt), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(KLeavePrompt), findsNothing);
      expect(find.byType(LiveRoomScreen), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(KLeavePrompt.exitKey));
      await tester.pumpAndSettle();
      expect(find.byType(LiveRoomScreen), findsNothing);
      expect(find.byKey(const Key('nav.home')), findsOneWidget);
    });

    testWidgets('an ended room: "Back to live rooms" returns to the hub', (
      tester,
    ) async {
      final live = await pumpApp(tester);
      // The card was LIVE in the list, but the room is stale (v1.3.1 §10.2).
      live.room = (id) => apiRoom(
        id: id,
        status: LiveRoomStatus.ended,
        endReason: LiveRoomEndReason.heartbeatTimeout,
      );
      await tester.tap(find.byKey(LiveHubGrid.cardKey(0)));
      await tester.pumpAndSettle();
      expect(find.text(l10n.liveRoomEndedTitle), findsOneWidget);
      await tester.tap(find.text(l10n.liveRoomBackToLive));
      await tester.pumpAndSettle();
      expect(find.byType(LiveRoomScreen), findsNothing);
      expect(find.byKey(const Key('nav.home')), findsOneWidget);
    });

    testWidgets('a deep link builds the hub under the room; Close shows it', (
      tester,
    ) async {
      final router = GoRouter(
        initialLocation: AppRoutes.liveRoom('room-0'),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            builder: (_, _) => const Text('hub', key: Key('hub')),
            routes: [
              GoRoute(
                path: AppRoutes.liveRoomSegment,
                builder: (_, state) =>
                    LiveRoomScreen(roomId: state.pathParameters['roomId']!),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      final live = FakeLiveRepository(room: (id) => apiRoom(id: id));
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [
            liveRepositoryProvider.overrideWithValue(live),
            profileRepositoryProvider.overrideWithValue(
              FakeProfileRepository(apiProfile()),
            ),
            liveMediaEngineProvider.overrideWithValue(FakeLiveMediaEngine.new),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            locale: AppLanguage.en.locale,
            supportedLocales: KabsoApp.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(live.roomRequests, ['room-0']);
      await tester.tap(_label(l10n.liveClose));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('hub')), findsOneWidget);
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        AppRoutes.home,
      );
    });

    test('room locations encode the id', () {
      expect(AppRoutes.liveRoom('room-0'), '/home/room/room-0');
      expect(AppRoutes.liveRoom('a/b'), '/home/room/a%2Fb');
    });
  });

  group('production states (HL-L10)', () {
    testWidgets('loading: skeleton header, Close works', (tester) async {
      final never = Completer<LiveRoom>();
      await _pumpRoom(tester, room: (_) => never.future, settle: false);
      expect(find.byKey(const Key('room.loading')), findsOneWidget);
      expect(find.byType(KHostPillSkeleton), findsOneWidget);
      expect(find.byKey(_hostAway), findsNothing);
      expect(_label(l10n.liveClose), findsOneWidget);
    });

    testWidgets('live: "the host will be right back" while the host is not '
        'in the media session, with real room and host data', (tester) async {
      await _pumpRoom(
        tester,
        room: (id) => apiRoom(
          id: id,
          category: const LiveCategory(slug: 'music', name: 'Music'),
        ),
      );
      expect(find.byKey(_hostAway), findsOneWidget);
      expect(find.text(l10n.liveHostAway), findsOneWidget);
      // D131 (ref 158): the host from the room, this live's points in the
      // pill, the board chip; the title and category are announced on the
      // cards and the host's sheet, not drawn here.
      expect(find.text('Sara'), findsOneWidget);
      expect(find.byKey(LiveRoomScreen.scoreKey), findsOneWidget);
      expect(find.byType(KRoomChipsRow), findsOneWidget);
      // Chat (CP-013): the room's chat, empty so far — D135: only the
      // pinned rules line, no "no messages yet" line; the old comment
      // field is gone.
      expect(find.byKey(LiveRoomChatLines.noticeKey), findsOneWidget);
      expect(find.textContaining('No messages yet'), findsNothing);
      expect(find.textContaining('لا رسائل بعد'), findsNothing);
      expect(find.text(l10n.liveCommentHint), findsNothing);
      expect(_label(l10n.liveCommentHint), findsNothing);
      // Gifts only; no share (no room link domain yet).
      expect(_label(l10n.liveGifts), findsOneWidget);
      expect(_label(l10n.liveShare), findsNothing);
    });

    for (final (reason, text) in [
      (LiveRoomEndReason.hostEnded, l10n.liveRoomEndedByHost),
      (LiveRoomEndReason.heartbeatTimeout, l10n.liveRoomEndedTimeout),
      (LiveRoomEndReason.hostSuspended, l10n.liveRoomEndedOther),
      (LiveRoomEndReason.admin, l10n.liveRoomEndedOther),
      (LiveRoomEndReason.unknown, l10n.liveRoomEndedOther),
    ]) {
      testWidgets('ended (${reason.name}): overlay with the reason, no chat '
          'or actions', (tester) async {
        await _pumpRoom(
          tester,
          room: (id) =>
              apiRoom(id: id, status: LiveRoomStatus.ended, endReason: reason),
        );
        expect(find.byKey(const Key('room.ended')), findsOneWidget);
        expect(find.text(l10n.liveRoomEndedTitle), findsOneWidget);
        expect(find.text(text), findsOneWidget);
        expect(find.byKey(LiveRoomChatLines.noticeKey), findsNothing);
        expect(find.byType(KRoomActionBar), findsNothing);
        expect(find.byKey(_hostAway), findsNothing);
        expect(find.byKey(const Key('room.back')), findsOneWidget);
        // Not following yet: Follow is offered.
        expect(find.byKey(const Key('room.follow')), findsOneWidget);
      });
    }

    testWidgets('ended: no Follow when already following', (tester) async {
      await _pumpRoom(
        tester,
        room: (id) => apiRoom(id: id, status: LiveRoomStatus.ended),
        profile: apiProfile(isFollowing: true),
      );
      expect(find.byKey(const Key('room.follow')), findsNothing);
      expect(find.byKey(const Key('room.back')), findsOneWidget);
    });

    testWidgets('ended: Follow from the overlay stays as "Following"', (
      tester,
    ) async {
      final (_, profiles) = await _pumpRoom(
        tester,
        room: (id) => apiRoom(id: id, status: LiveRoomStatus.ended),
      );
      await tester.tap(find.byKey(const Key('room.follow')));
      await tester.pumpAndSettle();
      expect(profiles.calls.last, 'PUT host0');
      expect(
        find.descendant(
          of: find.byKey(const Key('room.follow')),
          matching: find.text(l10n.liveFollowing),
        ),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('not found: message and the way back, no retry', (
      tester,
    ) async {
      final (live, _) = await _pumpRoom(
        tester,
        room: (_) => throw roomNotFound,
      );
      expect(find.byKey(const Key('room.notFound')), findsOneWidget);
      expect(find.text(l10n.liveRoomNotFoundTitle), findsOneWidget);
      expect(find.text(l10n.liveRoomBackToLive), findsOneWidget);
      expect(find.text(l10n.actionRetry), findsNothing);
      expect(live.roomRequests, hasLength(1));
    });

    testWidgets('error: Error ID; Try again re-requests the room', (
      tester,
    ) async {
      var fail = true;
      final (live, _) = await _pumpRoom(
        tester,
        room: (id) => fail ? throw _internal : apiRoom(id: id),
      );
      expect(find.byKey(const Key('room.error')), findsOneWidget);
      expect(find.text(l10n.liveRoomErrorTitle), findsOneWidget);
      expect(find.text(l10n.errorIdLabel('req-1')), findsOneWidget);
      expect(live.roomRequests, hasLength(1));

      // Still failing: one more request, still the error.
      await tester.tap(find.text(l10n.actionRetry));
      await tester.pumpAndSettle();
      expect(live.roomRequests, hasLength(2));
      expect(find.byKey(const Key('room.error')), findsOneWidget);

      fail = false;
      await tester.tap(find.text(l10n.actionRetry));
      await tester.pumpAndSettle();
      expect(live.roomRequests, ['room-0', 'room-0', 'room-0']);
      expect(find.byKey(_hostAway), findsOneWidget);
    });

    testWidgets('offline: its own state; Try again re-requests', (
      tester,
    ) async {
      var offline = true;
      final (live, _) = await _pumpRoom(
        tester,
        room: (id) =>
            offline ? throw const NetworkFailure.offline() : apiRoom(id: id),
      );
      expect(find.byKey(const Key('room.offline')), findsOneWidget);
      expect(find.text(l10n.feedOfflineTitle), findsOneWidget);
      offline = false;
      await tester.tap(find.text(l10n.actionRetry));
      await tester.pumpAndSettle();
      expect(live.roomRequests, hasLength(2));
      expect(find.byKey(_hostAway), findsOneWidget);
    });

    testWidgets('the host profile failing leaves the room usable, without '
        'Follow', (tester) async {
      setViewport(tester, GoldenViewport.phone);
      await pumpScreen(
        tester,
        const LiveRoomScreen(roomId: 'room-0'),
        overrides: [
          liveRepositoryProvider.overrideWithValue(
            FakeLiveRepository(room: (id) => apiRoom(id: id)),
          ),
          profileRepositoryProvider.overrideWithValue(
            FakeProfileRepository(apiProfile(), profileFailure: _internal),
          ),
        ],
      );
      await tester.pumpAndSettle();
      expect(find.byKey(_hostAway), findsOneWidget);
      expect(find.text('Sara'), findsOneWidget);
      expect(_label(l10n.liveFollow), findsNothing);
      expect(find.textContaining('followers'), findsNothing);
    });
  });

  group('follow (HL-L2, optimistic)', () {
    testWidgets('follow: instant check and count, then the chip fades out', (
      tester,
    ) async {
      final (_, profiles) = await _pumpRoom(tester);
      profiles.gate = Completer<void>();
      await tester.tap(_label(l10n.liveFollow));
      // The chip cross-fade (the 1 s confirmation timer is not reached).
      await tester.pumpAndSettle();
      // Optimistic: following and +1 before the server answers.
      expect(_label(l10n.liveFollow), findsNothing);
      expect(_label(l10n.liveFollowing), findsOneWidget);
      expect(profiles.calls.last, 'PUT host0');

      profiles.gate!.complete();
      await tester.pumpAndSettle();
      expect(_label(l10n.liveFollowing), findsOneWidget);
      // After the confirmation the chip is gone.
      await tester.pump(KMetrics.followConfirmDuration);
      await tester.pumpAndSettle();
      expect(_label(l10n.liveFollowing), findsNothing);
      expect(_label(l10n.liveFollow), findsNothing);
    });

    testWidgets('a failed follow rolls back and explains', (tester) async {
      final (_, profiles) = await _pumpRoom(tester);
      profiles
        ..gate = Completer<void>()
        ..followFailure = _rateLimited;
      await tester.tap(_label(l10n.liveFollow));
      // The chip cross-fade (the 1 s confirmation timer is not reached).
      await tester.pumpAndSettle();
      expect(_label(l10n.liveFollowing), findsOneWidget);

      profiles.gate!.complete();
      await tester.pumpAndSettle();
      expect(_label(l10n.liveFollow), findsOneWidget);
      expect(_label(l10n.liveFollowing), findsNothing);
      expect(find.text(l10n.errorRateLimited), findsOneWidget);
    });

    testWidgets('no Follow for yourself or a private account', (tester) async {
      await _pumpRoom(
        tester,
        profile: apiProfile(isSelf: true),
        user: testUser(),
      );
      expect(_label(l10n.liveFollow), findsNothing);
      await _pumpRoom(tester, profile: apiProfile(isPrivate: true));
      expect(_label(l10n.liveFollow), findsNothing);
    });

    testWidgets("D135: the card's bottom row — Gift, Mention, Message for "
        'someone I follow', (tester) async {
      await _pumpRoom(
        tester,
        profile: apiProfile(isFollowing: true),
        user: testUser(),
      );
      // Already following: no chip in the pill.
      expect(_label(l10n.liveFollow), findsNothing);
      await tester.tap(_hostPillPicture(l10n, 'Sara'));
      await tester.pumpAndSettle();
      final sheet = find.byKey(const Key('room.hostSheet'));
      expect(sheet, findsOneWidget);
      expect(find.text('@host0'), findsOneWidget);
      expect(find.text('Arabic music every evening'), findsOneWidget);
      _expectNoDimming(tester);
      final gift = find.byKey(const Key('room.userCard.gift'));
      final mention = find.byKey(const Key('room.userCard.mention'));
      final message = find.byKey(const Key('room.userCard.message'));
      expect(gift, findsOneWidget);
      expect(mention, findsOneWidget);
      expect(message, findsOneWidget);
      expect(find.byKey(const Key('room.userCard.follow')), findsNothing);
      // In reading order: Gift, Mention, Message.
      final ar = Directionality.of(tester.element(sheet)) == TextDirection.rtl;
      final xs = [
        for (final f in [gift, mention, message]) tester.getCenter(f).dx,
      ];
      expect(
        ar ? xs[0] > xs[1] && xs[1] > xs[2] : xs[0] < xs[1] && xs[1] < xs[2],
        isTrue,
      );
      for (final f in [gift, mention, message]) {
        final size = tester.getSize(f);
        expect(size.height, greaterThanOrEqualTo(48));
        expect(size.width, greaterThanOrEqualTo(48));
      }
    });

    testWidgets("D135: not followed — Follow in Message's place; it follows "
        'and turns into Message; Mention puts @username in the chat box', (
      tester,
    ) async {
      final (_, profiles) = await _pumpRoom(
        tester,
        profile: apiProfile(),
        user: testUser(),
      );
      await tester.tap(_hostPillPicture(l10n, 'Sara'));
      await tester.pumpAndSettle();
      final follow = find.byKey(const Key('room.userCard.follow'));
      expect(follow, findsOneWidget);
      expect(find.byKey(const Key('room.userCard.message')), findsNothing);
      await tester.ensureVisible(follow);
      await tester.pumpAndSettle();
      await tester.tap(follow);
      await tester.pumpAndSettle();
      expect(profiles.calls.last, 'PUT host0');
      expect(follow, findsNothing);
      expect(find.byKey(const Key('room.userCard.message')), findsOneWidget);
      // Mention closes the card and opens the chat box with "@host0 ".
      final mention = find.byKey(const Key('room.userCard.mention'));
      await tester.ensureVisible(mention);
      await tester.pumpAndSettle();
      await tester.tap(mention);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('room.hostSheet')), findsNothing);
      final field = tester.widget<TextField>(
        find.byKey(LiveChatComposer.fieldKey),
      );
      expect(field.controller!.text, '@host0 ');
    });

    testWidgets('D135: my own card has no Gift, Mention, Message or Follow', (
      tester,
    ) async {
      await _pumpRoom(tester, profile: apiProfile(isSelf: true));
      await tester.tap(_hostPillPicture(l10n, 'Sara'));
      await tester.pumpAndSettle();
      for (final k in ['gift', 'mention', 'message', 'follow']) {
        expect(find.byKey(Key('room.userCard.$k')), findsNothing, reason: k);
      }
    });
  });

  group('gifts (CP-020)', () {
    testWidgets('the sheet does not dim the stream; an empty catalogue says '
        '"No gifts yet" and invents nothing', (tester) async {
      await _pumpRoom(tester, user: testUser());
      await tester.tap(_label(l10n.liveGifts));
      await tester.pumpAndSettle();
      expect(find.byType(KLiveGiftSheet), findsOneWidget);
      _expectNoDimming(tester);
      expect(find.text(l10n.liveGiftEmptyTitle), findsOneWidget);
      expect(find.byType(KGiftImage), findsNothing);
      // D131 (ref 161): the host is the only recipient, so no row.
      expect(find.byKey(KLiveGiftSheet.recipientKey('host0')), findsNothing);
      // Send is dimmed; D128: a tap on it says why and sends nothing.
      final send = tester.widget<Semantics>(
        find
            .ancestor(
              of: find.byKey(KLiveGiftSheet.sendKey),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(send.properties.enabled, isFalse);
      await tester.tap(find.byKey(KLiveGiftSheet.sendKey));
      await tester.pump();
      expect(
        find.descendant(
          of: find.byKey(KLiveGiftSheet.toastKey),
          matching: find.text(l10n.liveGiftEmptyTitle),
        ),
        findsOneWidget,
      );
      await tester.pump(KLiveGiftSheet.toastTime);

      // A tap on the visible stream closes it.
      await tester.tapAt(const Offset(200, 150));
      await tester.pumpAndSettle();
      expect(find.byType(KLiveGiftSheet), findsNothing);
    });

    testWidgets("sending to the host plays the banner at once; the room's "
        'message for the same send plays nothing more', (tester) async {
      final engine = FakeLiveMediaEngine();
      final gifts = FakeLiveGiftRepository(codes: giftFixtureCodes);
      await _pumpRoom(tester, user: testUser(), engine: engine, gifts: gifts);
      await tester.tap(_label(l10n.liveGifts));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(KLiveGiftSheet.cellKey('rose')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(KLiveGiftSheet.sendKey));
      await tester.pumpAndSettle();
      final sent = gifts.sends.single;
      expect(sent.roomId, 'room-0');
      expect(sent.recipients, ['host0']);
      expect(find.byType(LiveGiftBanner), findsOneWidget);
      // The same send comes back as a data message.
      engine.chat.add(
        LiveGiftReceived(
          LiveGift.fromJson(
            liveGiftJson(
              id: 'gift-0',
              quantity: 1,
              recipients: [giftUserJson('host0', 'Sara')],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(LiveGiftBanner), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(find.byType(LiveGiftBanner), findsNothing);
    });

    testWidgets("a person's card opens the panel with that person chosen", (
      tester,
    ) async {
      await _pumpRoom(tester, user: testUser());
      await tester.tap(_hostPillPicture(l10n, 'Sara'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('room.userCard.gift')));
      await tester.tap(find.byKey(const Key('room.userCard.gift')));
      await tester.pumpAndSettle();
      expect(find.byType(KLiveGiftSheet), findsOneWidget);
      // D131 (ref 161): the host is the only one who can receive here, so
      // the panel shows no recipients row and no "not on the mic" line.
      expect(find.byKey(KLiveGiftSheet.recipientKey('host0')), findsNothing);
      expect(find.textContaining(l10n.liveGiftNotOnMic('')), findsNothing);
    });

    testWidgets('a gift data message in the room: the banner with the '
        'sender, the gift name from the catalogue and the quantity', (
      tester,
    ) async {
      final engine = FakeLiveMediaEngine();
      await _pumpRoom(
        tester,
        user: testUser(),
        engine: engine,
        gifts: FakeLiveGiftRepository(codes: giftFixtureCodes),
      );
      engine.chat.add(
        LiveGiftReceived(
          LiveGift.fromJson(
            liveGiftJson(
              sender: giftUserJson('lina', 'Lina'),
              recipients: [giftUserJson('host0', 'Sara')],
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(LiveGiftBanner), findsOneWidget);
      expect(find.textContaining('Lina'), findsOneWidget);
      expect(find.textContaining('Rose'), findsOneWidget);
      expect(find.text(l10n.giftCombo(10)), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.byType(LiveGiftBanner), findsNothing);
    });

    testWidgets('D132: a lucky-win message of ×100 or more shows the room '
        'banner; a smaller one does not', (tester) async {
      final engine = FakeLiveMediaEngine();
      await _pumpRoom(
        tester,
        user: testUser(),
        engine: engine,
        gifts: FakeLiveGiftRepository(codes: giftFixtureCodes),
      );
      LiveChatEvent? win(int multiplier, String id) => LiveChatEvent.parse({
        'type': 'lucky-win',
        'win': {
          'giftId': id,
          'roomId': 'room-0',
          'giftCode': 'lucky_clover',
          'sender': giftUserJson('lina', 'Lina'),
          'multiplier': multiplier,
          'coinsWon': multiplier * 10,
          'createdAt': '2026-10-27T18:30:00.000Z',
        },
      });
      engine.chat.add(win(50, 'g-1')!);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(LiveWinBanner), findsNothing);
      engine.chat.add(win(500, 'g-2')!);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(LiveWinBanner), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(LiveWinBanner.numberKey)).data,
        '×500',
      );
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.byType(LiveWinBanner), findsNothing);
    });
  });

  group('D109: viewers see who else is watching', () {
    const huda = UserSummary(
      id: 'u-huda',
      username: 'huda',
      displayName: 'Huda',
      avatarUrl: null,
    );
    const omar = UserSummary(
      id: 'u-omar',
      username: 'omar',
      displayName: 'Omar',
      avatarUrl: null,
    );
    List<LiveViewer> watching() => [
      LiveViewer(
        kind: LiveViewerKind.user,
        user: huda,
        guestNumber: null,
        joinedAt: DateTime.utc(2026, 10, 26, 12, 2),
      ),
      LiveViewer(
        kind: LiveViewerKind.guest,
        user: null,
        guestNumber: 4821,
        joinedAt: DateTime.utc(2026, 10, 26, 12, 1),
      ),
      LiveViewer(
        kind: LiveViewerKind.user,
        user: omar,
        guestNumber: null,
        joinedAt: DateTime.utc(2026, 10, 26, 12),
      ),
    ];

    for (final mode in [LiveRoomMode.solo, LiveRoomMode.audio]) {
      for (final language in AppLanguage.values) {
        testWidgets('${mode.name} room (${language.name}): the faces and the '
            'count from the viewer list; a tap opens it read-only and a '
            'person opens their card', (tester) async {
          final l = l10nFor(language);
          final repo = FakeLiveRepository(
            room: (id) => apiRoom(
              id: id,
              ar: language == AppLanguage.ar,
              viewerCount: 1,
            ).copyWith(mode: mode, seatCount: mode.hasSeats ? 10 : null),
          )..viewerList = watching();
          if (mode.hasSeats) {
            repo.seatState = LiveSeats(
              roomId: 'room-0',
              mode: mode,
              seatCount: 10,
              version: 1,
              moderators: const [],
              seats: [
                for (var i = 1; i < 10; i++)
                  LiveSeat(index: i, state: LiveSeatState.empty, user: null),
              ],
            );
          }
          await _pumpRoom(
            tester,
            repo: repo,
            language: language,
            engine: FakeLiveMediaEngine()..present.add('user-0'),
            user: testUser(),
          );
          final stack = find.byKey(LiveRoomScreen.viewersKey);
          expect(stack, findsOneWidget);
          // Two people (the guest has no face) and the list's count, not
          // the room's stale 1.
          expect(
            find.descendant(of: stack, matching: find.byType(KAvatar)),
            findsNWidgets(2),
          );
          expect(
            find.descendant(of: stack, matching: find.text('3')),
            findsOneWidget,
          );
          expect(find.bySemanticsLabel(l.liveViewers(3, '3')), findsOneWidget);

          await tester.tap(stack);
          await tester.pumpAndSettle();
          expect(find.text(l.liveViewersTab('3')), findsOneWidget);
          expect(find.textContaining('Huda'), findsOneWidget);
          expect(find.textContaining('Omar'), findsOneWidget);
          expect(find.textContaining('4821'), findsOneWidget);
          // Read-only: no invite to a seat, no moderator choice.
          expect(find.byKey(SeatControlKeys.inviteUser('huda')), findsNothing);
          expect(find.byKey(SeatControlKeys.inviteUser('omar')), findsNothing);
          // A person: their card (not the moderator menu).
          await tester.tap(find.byKey(SeatControlKeys.moderatorUser('huda')));
          await tester.pumpAndSettle();
          final card = find.byKey(const Key('room.hostSheet'));
          expect(card, findsOneWidget);
          expect(find.byKey(SeatControlKeys.moderatorAction), findsNothing);
          expect(find.byKey(LivePersonToolKeys.kick), findsNothing);
          Navigator.of(tester.element(card)).pop();
          await tester.pumpAndSettle();

          // Nobody seated: no "Invite friends" for a viewer either.
          await tester.tap(find.byKey(SeatControlKeys.guestsTab));
          await tester.pumpAndSettle();
          expect(find.byKey(SeatControlKeys.inviteFriends), findsNothing);
        });
      }
    }

    testWidgets('the list refreshes every 10 s, as the host does', (
      tester,
    ) async {
      final repo = FakeLiveRepository(room: (id) => apiRoom(id: id))
        ..viewerList = watching().take(1).toList();
      await _pumpRoom(
        tester,
        repo: repo,
        engine: FakeLiveMediaEngine()..present.add('user-0'),
        user: testUser(),
      );
      final stack = find.byKey(LiveRoomScreen.viewersKey);
      expect(find.descendant(of: stack, matching: find.text('1')), findsOne);
      repo.viewerList = watching();
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(find.descendant(of: stack, matching: find.text('3')), findsOne);
    });

    testWidgets('an ended room shows no viewers', (tester) async {
      final repo = FakeLiveRepository(
        room: (id) => apiRoom(id: id, status: LiveRoomStatus.ended),
      )..viewerList = watching();
      await _pumpRoom(tester, repo: repo);
      expect(find.byKey(LiveRoomScreen.viewersKey), findsNothing);
    });
  });

  group('honesty', () {
    testWidgets('no viewer count or avatars while presence does not exist', (
      tester,
    ) async {
      await _pumpRoom(tester);
      expect(find.byType(KViewerStrip), findsNothing);
      expect(find.byType(KViewerCountChip), findsNothing);
      expect(find.text(l10n.liveCardNew), findsNothing);
    });

    testWidgets('a real viewer count from the API is shown as is', (
      tester,
    ) async {
      // No one in the viewer list (yet): the room's count, no faces; D135:
      // the list opens all the same.
      await _pumpRoom(tester, room: (id) => apiRoom(id: id, viewerCount: 3));
      final stack = find.byKey(LiveRoomScreen.viewersKey);
      expect(stack, findsOneWidget);
      expect(
        find.descendant(of: stack, matching: find.text('3')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: stack, matching: find.byType(KAvatar)),
        findsNothing,
      );
      expect(tester.widget<LiveViewersStack>(stack).onTap, isNotNull);
    });

    testWidgets('no decorative controls: every room button acts', (
      tester,
    ) async {
      await _pumpRoom(tester);
      final buttons = tester.widgetList<KRoomIconButton>(
        find.byType(KRoomIconButton),
      );
      expect(buttons, hasLength(1)); // close
      for (final button in buttons) {
        expect(button.onPressed, isNotNull, reason: button.label);
      }
      // D131: the bar's round buttons (the gift box); D173: ≡ and games
      // too.
      final bar = tester.widgetList<KViewerBarButton>(
        find.byType(KViewerBarButton),
      );
      expect(bar, hasLength(3));
      for (final button in bar) {
        expect(button.onTap, isNotNull, reason: button.label);
      }
      // Fixture-only states never appear in production paths.
      for (final type in [
        KRoomReconnecting,
        KRoomCameraOff,
        KRoomStatusChip,
        KPkLayout,
        KGuestSeatGrid,
      ]) {
        expect(find.byType(type), findsNothing, reason: '$type');
      }
    });

    testWidgets('48 dp targets: close, gifts, follow and the host pill (also '
        'once the follow chip is gone)', (tester) async {
      for (final following in [false, true]) {
        await _pumpRoom(tester, profile: apiProfile(isFollowing: following));
        final targets = [
          _label(l10n.liveClose),
          _label(l10n.liveGifts),
          _hostPill(l10n, 'Sara'),
          if (!following) _label(l10n.liveFollow),
        ];
        for (final target in targets) {
          final size = tester.getSize(target);
          expect(size.height, greaterThanOrEqualTo(KSizes.minTouchTarget));
          expect(size.width, greaterThanOrEqualTo(KSizes.minTouchTarget));
        }
      }
    });

    testWidgets('rendered room copy names no development phases', (
      tester,
    ) async {
      final phase = RegExp(
        r'phase|المرحلة|مرحلة|\bB[0-9]\b',
        caseSensitive: false,
      );
      for (final language in AppLanguage.values) {
        for (final room in <RoomHandler>[
          (id) => apiRoom(id: id),
          (id) => apiRoom(id: id, status: LiveRoomStatus.ended),
          (_) => throw roomNotFound,
          (_) => throw _internal,
          (_) => throw const NetworkFailure.offline(),
        ]) {
          await _pumpRoom(tester, room: room, language: language);
          for (final text in _texts(tester)) {
            expect(text, isNot(contains(phase)), reason: text);
          }
        }
        await _pumpRoom(tester, language: language);
        await tester.tap(_label(l10nFor(language).liveGifts));
        await tester.pumpAndSettle();
        for (final text in _texts(tester)) {
          expect(text, isNot(contains(phase)), reason: text);
        }
      }
    });
  });

  group('RTL', () {
    testWidgets('Arabic mirrors the room: host at the right, close and gift '
        'at the left', (tester) async {
      for (final language in AppLanguage.values) {
        final l = l10nFor(language);
        final ar = language == AppLanguage.ar;
        await _pumpRoom(tester, language: language);
        final pill = tester.getCenter(find.byType(KHostPill)).dx;
        final close = tester.getCenter(_label(l.liveClose)).dx;
        final gift = tester.getCenter(_label(l.liveGifts)).dx;
        final chat = tester
            .getCenter(find.byKey(LiveRoomChatLines.noticeKey))
            .dx;
        // D131: the board chip starts the second row.
        final info = tester.getCenter(find.byType(LiveRankChip)).dx;
        const mid = 393 / 2;
        expect(ar ? pill > close : pill < close, isTrue, reason: language.name);
        expect(ar ? gift < mid : gift > mid, isTrue, reason: language.name);
        expect(ar ? chat > mid : chat < mid, isTrue, reason: language.name);
        expect(ar ? info > mid : info < mid, isTrue, reason: language.name);
      }
    });

    testWidgets('PK: the host pane is at the reading start in both '
        'directions', (tester) async {
      for (final language in AppLanguage.values) {
        final ar = language == AppLanguage.ar;
        final (host, opponent) = pkSides(language, opponentCameraOff: true);
        await pumpComponent(
          tester,
          KPkLayout(host: host, opponent: opponent, result: PkResult.win),
          language: language,
        );
        final hostX = tester.getCenter(find.text(host.name).first).dx;
        final opponentX = tester.getCenter(find.text(opponent.name).first).dx;
        expect(ar ? hostX > opponentX : hostX < opponentX, isTrue);
        // Per-pane results: the host won, so the opponent lost.
        final l = l10nFor(language);
        expect(find.text(l.pkWin), findsOneWidget);
        expect(find.text(l.pkLose), findsOneWidget);
        final winX = tester.getCenter(find.text(l.pkWin)).dx;
        expect(ar ? winX > opponentX : winX < opponentX, isTrue);
      }
    });

    testWidgets('multi-guest seats run in reading order; an open seat is not '
        'a button', (tester) async {
      for (final language in AppLanguage.values) {
        final ar = language == AppLanguage.ar;
        final seats = guestSeats(language);
        await pumpComponent(
          tester,
          KGuestSeatGrid(seats: seats),
          language: language,
        );
        final first = tester.getCenter(find.text(seats[0]!.name)).dx;
        final second = tester.getCenter(find.text(seats[1]!.name)).dx;
        expect(ar ? first > second : first < second, isTrue);
        final open = _label(l10nFor(language).multiGuestOpenSeat);
        expect(open, findsOneWidget);
        expect(
          tester.getSemantics(open).getSemanticsData().flagsCollection.isButton,
          isFalse,
        );
      }
    });
  });

  group('text scale (Arabic, 360×800)', () {
    for (final scale in [1.3, 2.0]) {
      testWidgets('×$scale: every production state and both sheets lay out '
          'without overflow', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        const ar = AppLanguage.ar;
        final l = l10nFor(ar);
        for (final room in <RoomHandler>[
          (id) => apiRoom(
            id: id,
            ar: true,
            category: const LiveCategory(slug: 'music', name: 'موسيقى'),
          ),
          (id) => apiRoom(id: id, ar: true, status: LiveRoomStatus.ended),
          (_) => throw roomNotFound,
          (_) => throw _internal,
        ]) {
          await _pumpRoom(
            tester,
            room: room,
            language: ar,
            viewport: GoldenViewport.android,
          );
          expect(tester.takeException(), isNull);
        }
        await _pumpRoom(
          tester,
          room: (id) => apiRoom(id: id, ar: true),
          language: ar,
          viewport: GoldenViewport.android,
        );
        await tester.tap(_label(l.liveGifts));
        await tester.pumpAndSettle();
        expect(find.byType(KLiveGiftSheet), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tapAt(const Offset(180, 100));
        await tester.pumpAndSettle();
        expect(find.byType(KLiveGiftSheet), findsNothing);
        await tester.tap(_hostPillPicture(l, 'سارة'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('room.hostSheet')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('contrast on media scrims (worst case: a white frame)', () {
    double luminance(Color c) {
      double ch(double v) => v <= 0.04045
          ? v / 12.92
          : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
      return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
    }

    double contrast(Color a, Color b) {
      final la = luminance(a);
      final lb = luminance(b);
      return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
    }

    const white = Color(0xFFFFFFFF);
    const p = KPalette.dark;
    Color over(Color fg, Color bg) => Color.alphaBlend(fg, bg);

    test('white text on the room scrim and the chat scrim ≥ 4.5:1', () {
      expect(contrast(p.textPrimary, over(p.scrim, white)), greaterThan(4.5));
      expect(
        contrast(p.textPrimary, over(KLiveColors.chatScrim, white)),
        greaterThan(4.5),
      );
      // Why the pill's second line is white: secondary grey would fail.
      expect(contrast(p.textSecondary, over(p.scrim, white)), lessThan(4.5));
    });

    test('ended overlay and stage copy ≥ 4.5:1', () {
      final ended = over(
        p.background.withValues(alpha: KMetrics.endedOverlayOpacity),
        white,
      );
      expect(contrast(p.textSecondary, ended), greaterThan(4.5));
      expect(contrast(p.textSecondary, p.surfaceOverlay), greaterThan(4.5));
    });

    test('urgent PK timer: onStatus on error ≥ 4.5:1', () {
      expect(contrast(KStatusColors.onStatus, p.error), greaterThan(4.5));
    });
  });
  group('taps and the score (CP-012, D95)', () {
    testWidgets('a signed-in viewer taps: characters rise, one batch a second, '
        'the score shows', (tester) async {
      final engine = FakeLiveMediaEngine()..present.add('user-0');
      final (repo, _) = await _pumpRoom(
        tester,
        engine: engine,
        user: testUser(),
      );
      // D131: this live's points sit in the host pill from the start.
      expect(
        find.descendant(
          of: find.byKey(LiveRoomScreen.scoreKey),
          matching: find.textContaining('0'),
        ),
        findsOneWidget,
      );
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byKey(LiveTapLayer.tapKey));
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(LiveTapCharacter), findsNWidgets(3));
      expect(repo.tapBatches, isEmpty);
      await tester.pump(const Duration(seconds: 1));
      expect(repo.tapBatches.single, (roomId: 'room-0', count: 3));
      await tester.pumpAndSettle();
      expect(find.byType(LiveTapCharacter), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(LiveRoomScreen.scoreKey),
          matching: find.textContaining('3'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the media room metadata moves the score for everyone', (
      tester,
    ) async {
      final engine = FakeLiveMediaEngine()..scoreNow = 12400;
      await _pumpRoom(tester, engine: engine);
      expect(
        find.descendant(
          of: find.byKey(LiveRoomScreen.scoreKey),
          matching: find.textContaining('12,400'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the host ends the live: the media session drops and the '
        'viewer sees the ended state (real web run)', (tester) async {
      var ended = false;
      final engine = FakeLiveMediaEngine()..present.add('user-0');
      final (repo, _) = await _pumpRoom(
        tester,
        engine: engine,
        user: testUser(),
        repo: FakeLiveRepository(
          room: (id) => ended
              ? apiRoom(
                  id: id,
                  status: LiveRoomStatus.ended,
                  endReason: LiveRoomEndReason.hostEnded,
                )
              : apiRoom(id: id),
        ),
      );
      expect(find.byType(KRoomEndedOverlay), findsNothing);
      final before = repo.roomRequests.length;
      ended = true;
      engine
        ..dropped = true
        ..ping();
      await tester.pumpAndSettle();
      expect(repo.roomRequests.length, before + 1);
      expect(find.byType(KRoomEndedOverlay), findsOneWidget);
    });

    testWidgets('guests without an account do not tap; D120: the host '
        'does, and it counts', (tester) async {
      await _pumpRoom(tester, engine: FakeLiveMediaEngine());
      expect(find.byKey(LiveTapLayer.tapKey), findsNothing);
      final host = testUser().copyWith(id: 'user-0');
      final (repo, _) = await _pumpRoom(
        tester,
        engine: FakeLiveMediaEngine(),
        user: host,
      );
      await tester.tap(find.byKey(LiveTapLayer.tapKey));
      await tester.pump(const Duration(seconds: 1));
      expect(repo.tapBatches.single, (roomId: 'room-0', count: 1));
      await tester.pumpAndSettle();
    });
  });

  group('media and seats (CP-010, CP-011)', () {
    final l10n = l10nFor(AppLanguage.en);
    const omar = UserSummary(
      id: 'u-omar',
      username: 'omar',
      displayName: 'Omar',
      avatarUrl: null,
    );

    LiveSeats seats({
      LiveRoomMode mode = LiveRoomMode.multi,
      int count = 6,
      LiveSeatsMine? mine,
      List<LiveSeat>? list,
    }) => LiveSeats(
      roomId: 'room-0',
      mode: mode,
      version: 1,
      seatCount: count,
      seats:
          list ??
          [
            for (var i = 1; i < count; i++)
              LiveSeat(index: i, state: LiveSeatState.empty, user: null),
          ],
      moderators: const [],
      mine:
          mine ??
          const LiveSeatsMine(
            role: LiveSeatRole.viewer,
            seatIndex: null,
            request: null,
            invite: null,
          ),
    );

    FakeLiveRepository seatRoom(LiveRoomMode mode, int count) =>
        FakeLiveRepository(
          room: (id) =>
              apiRoom(id: id)
                  .copyWith(mode: mode, seatCount: count, theme: 'ice-palace'),
        )..seatState = seats(mode: mode, count: count);

    testWidgets('audio room: tapping the empty stage cheers (the seats area '
        'scrolls, it must not swallow the tap); a seat tap does not', (
      tester,
    ) async {
      final engine = FakeLiveMediaEngine()..present.add('user-0');
      final repo = FakeLiveRepository(
        room: (id) =>
            apiRoom(id: id).copyWith(mode: LiveRoomMode.audio, seatCount: 25),
      )..seatState = seats(mode: LiveRoomMode.audio, count: 25);
      await _pumpRoom(tester, repo: repo, engine: engine, user: testUser());
      // Under the rows of seats, above the chat: empty stage.
      final last = tester.getBottomLeft(find.byKey(AudioSeatRing.seatKey(24)));
      for (var i = 0; i < 3; i++) {
        await tester.tapAt(Offset(200, last.dy + 40));
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(LiveTapCharacter), findsNWidgets(3));
      await tester.pump(const Duration(seconds: 1));
      expect(repo.tapBatches.single, (roomId: 'room-0', count: 3));
      // A seat opens its own action, not a cheer.
      await tester.tap(find.byKey(AudioSeatRing.seatKey(3)));
      await tester.pump(const Duration(seconds: 1));
      expect(repo.tapBatches, hasLength(1));
      await tester.pumpAndSettle();
    });

    testWidgets("D135: the host changes the theme — every viewer's room "
        'follows when roomInfoVersion moves', (tester) async {
      var theme = 'classic';
      final engine = FakeLiveMediaEngine()..present.add('user-0');
      final repo = FakeLiveRepository(
        room: (id) => apiRoom(id: id)
            .copyWith(mode: LiveRoomMode.audio, seatCount: 10, theme: theme),
      )..seatState = seats(mode: LiveRoomMode.audio, count: 10);
      await _pumpRoom(tester, repo: repo, engine: engine, user: testUser());
      Finder background(String slug) => find.byWidgetPredicate(
        (w) => w is LiveThemeBackground && w.theme == slug,
      );
      expect(find.byType(LiveAudioRoomBackground), findsOneWidget);
      expect(background('galaxy'), findsNothing);
      // The host picks Galaxy: the server moves roomInfoVersion.
      theme = 'galaxy';
      engine
        ..infoVersion = 1
        ..ping();
      await tester.pumpAndSettle();
      expect(background('galaxy'), findsOneWidget);
      expect(find.byType(LiveAudioRoomBackground), findsNothing);
      // And back.
      theme = 'classic';
      engine
        ..infoVersion = 2
        ..ping();
      await tester.pumpAndSettle();
      expect(find.byType(LiveAudioRoomBackground), findsOneWidget);
    });

    testWidgets('D135: the points each seated person received show under '
        'their seat (the cherry) and follow the seats', (tester) async {
      LiveSeat taken(int i, String name, int points) => LiveSeat(
        index: i,
        state: LiveSeatState.taken,
        user: UserSummary(
          id: 'u-$name',
          username: name,
          displayName: name,
          avatarUrl: null,
        ),
        points: points,
      );
      final engine = FakeLiveMediaEngine()..present.add('user-0');
      final repo =
          FakeLiveRepository(
              room: (id) =>
                  apiRoom(id: id)
                      .copyWith(mode: LiveRoomMode.audio, seatCount: 10),
            )
            ..seatState = seats(
              mode: LiveRoomMode.audio,
              count: 10,
              list: [
                taken(1, 'huda', 1500),
                taken(2, 'omar', 0),
                for (var i = 3; i < 10; i++)
                  LiveSeat(index: i, state: LiveSeatState.empty, user: null),
              ],
            );
      await _pumpRoom(tester, repo: repo, engine: engine, user: testUser());
      final l = lookupAppLocalizations(const Locale('en'));
      Finder pill(int i) => find.byKey(AudioSeatRing.seatPointsKey(i));
      String text(int i) => tester
          .widgetList<Text>(
            find.descendant(of: pill(i), matching: find.byType(Text)),
          )
          .single
          .data!;
      expect(text(1), KFormat.compact(1500, l));
      expect(text(2), KFormat.compact(0, l));
      // Empty seats keep the space, no points.
      expect(pill(3), findsNothing);
      // A gift to Omar: the seats move and everyone reads them again.
      repo.seatState = repo.seatState!.copyWith(
        version: 2,
        seats: [
          taken(1, 'huda', 1500),
          taken(2, 'omar', 12000),
          for (var i = 3; i < 10; i++)
            LiveSeat(index: i, state: LiveSeatState.empty, user: null),
        ],
      );
      engine
        ..version = 2
        ..ping();
      await tester.pumpAndSettle();
      expect(text(2), KFormat.compact(12000, l));
      // The pill sits under the name, like the host's.
      expect(
        tester.getTopLeft(pill(1)).dy,
        greaterThan(tester.getBottomLeft(find.text('huda')).dy - 1),
      );
    });

    testWidgets('audio room: a viewer taps someone on a seat and sees their '
        'card (owner, 2026-10-26)', (tester) async {
      final repo =
          FakeLiveRepository(
              room: (id) =>
                  apiRoom(id: id)
                      .copyWith(mode: LiveRoomMode.audio, seatCount: 10),
            )
            ..seatState = seats(
              mode: LiveRoomMode.audio,
              count: 10,
              list: [
                const LiveSeat(
                  index: 1,
                  state: LiveSeatState.taken,
                  user: UserSummary(
                    id: 'u-huda',
                    username: 'huda',
                    displayName: 'Huda',
                    avatarUrl: null,
                  ),
                ),
                for (var i = 2; i < 10; i++)
                  LiveSeat(index: i, state: LiveSeatState.empty, user: null),
              ],
            );
      await _pumpRoom(
        tester,
        repo: repo,
        engine: FakeLiveMediaEngine()..present.add('user-0'),
        user: testUser(),
      );
      await tester.tap(find.byKey(AudioSeatRing.seatKey(1)));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('room.hostSheet')), findsOneWidget);
      // Not the host: no moderator tools, no Invite; their points, ⋯ and
      // their full profile instead.
      expect(find.byKey(LivePersonToolKeys.points), findsOneWidget);
      expect(find.byKey(LivePersonToolKeys.more), findsOneWidget);
      expect(find.byKey(LivePersonToolKeys.kick), findsNothing);
      expect(find.byKey(LivePersonToolKeys.mute), findsNothing);
      expect(find.byKey(LivePersonToolKeys.admin), findsNothing);
      expect(find.byKey(const Key('room.userCard.invite')), findsNothing);
      // D135: not followed — Gift, Mention and Follow (Message once
      // followed); the picture opens the profile.
      expect(find.byKey(const Key('room.userCard.follow')), findsOneWidget);
      expect(find.byKey(const Key('room.userCard.mention')), findsOneWidget);
      expect(find.byKey(const Key('room.userCard.message')), findsNothing);
      expect(find.byKey(const Key('room.userCard.profile')), findsOneWidget);
      // Family, relationship, gift wall and medals do not exist yet: each
      // says so.
      final l10n = lookupAppLocalizations(const Locale('en'));
      await tester.ensureVisible(find.byKey(LivePersonBoxes.boxKey(2)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(LivePersonBoxes.boxKey(2)));
      await tester.pump();
      expect(
        find.text(l10n.liveUserBoxSoon(l10n.liveUserGiftWall)),
        findsOneWidget,
      );
      // Nobody asked for a seat.
      expect(repo.seatCalls, isNot(contains(startsWith('requestSeat'))));
    });

    testWidgets("the host's video while they are in the session", (
      tester,
    ) async {
      final engine = FakeLiveMediaEngine()..present.add('user-0');
      final (repo, _) = await _pumpRoom(tester, engine: engine);
      expect(find.byKey(const Key('remote.user-0')), findsOneWidget);
      expect(find.byKey(_hostAway), findsNothing);
      // Signed out: a guest, with the app run's guest id.
      expect(repo.tokenRequests.single.guestId, isNotNull);
      expect(engine.joined, isNotNull);
    });

    testWidgets('signed in: the token without a guest id', (tester) async {
      final (repo, _) = await _pumpRoom(
        tester,
        engine: FakeLiveMediaEngine(),
        user: testUser(),
      );
      expect(repo.tokenRequests.single.guestId, isNull);
    });

    testWidgets('an ended room does not join the media session', (
      tester,
    ) async {
      final engine = FakeLiveMediaEngine();
      final (repo, _) = await _pumpRoom(
        tester,
        engine: engine,
        room: (id) => apiRoom(
          id: id,
          status: LiveRoomStatus.ended,
          endReason: LiveRoomEndReason.hostEnded,
        ),
      );
      expect(repo.tokenRequests, isEmpty);
      expect(engine.joined, isNull);
    });

    testWidgets('D144a audio room: asking for a seat explains and asks for '
        'the microphone only, once; Not now asks nothing', (tester) async {
      final repo = seatRoom(LiveRoomMode.audio, 9);
      final permissions = FakeLivePermissions(
        state: LivePermission.notAsked,
        afterRequest: LivePermission.granted,
      );
      await _pumpRoom(
        tester,
        repo: repo,
        engine: FakeLiveMediaEngine(),
        user: testUser(),
        permissions: permissions,
      );
      await tester.tap(find.byKey(AudioRoomViewKeys.request));
      await tester.pumpAndSettle();
      final l10n = l10nFor(AppLanguage.en);
      expect(find.text(l10n.livePermissionTitleAudio), findsOneWidget);
      expect(find.text(l10n.livePermissionBodyAudio), findsOneWidget);
      await tester.tap(find.byKey(LivePermissionKeys.notNow));
      await tester.pumpAndSettle();
      expect(permissions.requests, isEmpty);
      expect(repo.seatCalls, isNot(contains(startsWith('requestSeat'))));
      expect(find.text(l10n.livePermissionSeatRefused), findsOneWidget);
      ScaffoldMessenger.of(tester.element(find.byType(LiveAudioRoomLayout)))
          .removeCurrentSnackBar();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(AudioRoomViewKeys.request));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(LivePermissionKeys.go));
      await tester.pumpAndSettle();
      expect(permissions.checks, everyElement(isFalse));
      expect(permissions.requests, [false]);
      expect(repo.seatCalls, contains('requestSeat:'));
    });

    testWidgets('D144a refused for good: Open settings, no seat request', (
      tester,
    ) async {
      final repo = seatRoom(LiveRoomMode.multi, 6);
      final permissions = FakeLivePermissions(state: LivePermission.blocked);
      await _pumpRoom(
        tester,
        repo: repo,
        engine: FakeLiveMediaEngine(),
        user: testUser(),
        permissions: permissions,
      );
      await tester.tap(find.byKey(const Key('room.seat.request')));
      await tester.pumpAndSettle();
      final l10n = l10nFor(AppLanguage.en);
      expect(find.text(l10n.livePermissionBlockedVideo), findsOneWidget);
      await tester.tap(find.byKey(LivePermissionKeys.settings));
      await tester.pumpAndSettle();
      expect(permissions.settingsOpened, 1);
      expect(permissions.checks, [true]);
      expect(permissions.requests, isEmpty);
      expect(repo.seatCalls, isNot(contains(startsWith('requestSeat'))));
    });

    testWidgets('multi-guest: the seats, and asking for one', (tester) async {
      final repo = seatRoom(LiveRoomMode.multi, 6);
      await _pumpRoom(
        tester,
        repo: repo,
        engine: FakeLiveMediaEngine(),
        user: testUser(),
      );
      expect(find.byType(VideoSeatGrid), findsOneWidget);
      expect(find.byKey(VideoSeatGrid.seatKey(5)), findsOneWidget);
      await tester.tap(find.byKey(const Key('room.seat.request')));
      await tester.pumpAndSettle();
      expect(repo.seatCalls, contains('requestSeat:'));
      // An empty seat asks for that seat.
      await tester.tap(find.byKey(VideoSeatGrid.seatKey(3)));
      await tester.pumpAndSettle();
      expect(repo.seatCalls, contains('requestSeat:3'));
    });

    testWidgets("audio room (D94): the viewer sees the host's design — "
        'room bar, chat pill, seat button, gifts; seated: leave and mic', (
      tester,
    ) async {
      final engine = FakeLiveMediaEngine()..present.add('user-0');
      final repo = seatRoom(LiveRoomMode.audio, 9);
      await _pumpRoom(tester, repo: repo, engine: engine, user: testUser());
      expect(find.byType(LiveAudioRoomLayout), findsOneWidget);
      expect(find.byType(KLiveRoomScaffold), findsNothing);
      for (final key in [
        AudioRoomViewKeys.share,
        AudioRoomViewKeys.close,
        AudioRoomViewKeys.chat,
        AudioRoomViewKeys.request,
        AudioRoomViewKeys.gift,
      ]) {
        expect(find.byKey(key), findsOneWidget, reason: '$key');
      }
      expect(find.byKey(AudioRoomViewKeys.mic), findsNothing);
      // Share copies the live's invite, as on the host's screen.
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final shown = apiRoom();
      await tester.tap(find.byKey(AudioRoomViewKeys.share));
      await tester.pump();
      expect(
        copied,
        l10nFor(AppLanguage.en)
            .goLiveShareText(shown.title, '@${shown.host.username}'),
      );
      ScaffoldMessenger.of(tester.element(find.byType(LiveAudioRoomLayout)))
          .removeCurrentSnackBar();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AudioRoomViewKeys.request));
      await tester.pumpAndSettle();
      expect(repo.seatCalls, contains('requestSeat:'));
      // Seated: leave instead of ask, and the microphone.
      repo.seatState = seats(
        mode: LiveRoomMode.audio,
        count: 9,
        mine: const LiveSeatsMine(
          role: LiveSeatRole.seated,
          seatIndex: 1,
          request: null,
          invite: null,
        ),
        list: [
          LiveSeat(
            index: 1,
            state: LiveSeatState.taken,
            user: UserSummary(
              id: testUser().id,
              username: 'layla.k',
              displayName: 'Layla',
              avatarUrl: null,
            ),
          ),
          for (var i = 2; i < 9; i++)
            LiveSeat(index: i, state: LiveSeatState.empty, user: null),
        ],
      ).copyWith(version: 2);
      engine
        ..version = 2
        ..ping();
      await tester.pumpAndSettle();
      expect(find.byKey(AudioRoomViewKeys.leave), findsOneWidget);
      // Owner (2026-10-26): no mic button; a tap on my own seat opens my
      // card (no mute) and its mic button mutes and unmutes me.
      expect(find.byKey(AudioRoomViewKeys.mic), findsNothing);
      await tester.tap(find.byKey(AudioSeatRing.seatKey(1)));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('room.hostSheet')), findsOneWidget);
      expect(engine.micEnabled, isTrue);
      final selfMic = find.byKey(LivePersonToolKeys.selfMic);
      await tester.tap(selfMic);
      await tester.pumpAndSettle();
      expect(engine.micEnabled, isFalse);
      await tester.tap(selfMic);
      await tester.pumpAndSettle();
      expect(engine.micEnabled, isTrue);
      await tester.tapAt(const Offset(200, 60));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AudioRoomViewKeys.close));
      await tester.pumpAndSettle();
    });

    group('room chat (CP-013)', () {
      const huda = UserSummary(
        id: 'u-huda',
        username: 'huda',
        displayName: 'Huda',
        avatarUrl: null,
      );
      LiveChatEntry entry(
        String id,
        String text, {
        UserSummary author = huda,
        LiveChatRole role = LiveChatRole.viewer,
      }) => LiveChatEntry(
        id: id,
        roomId: 'room-0',
        author: author,
        authorRole: role,
        text: text,
        createdAt: DateTime.utc(2026, 10, 24, 20),
      );
      Finder line(String text) => find.descendant(
        of: find.byKey(LiveRoomChatLines.listKey),
        matching: find.textContaining(text, findRichText: true),
      );

      testWidgets('a viewer reads the last messages and the live ones, '
          'writes, and can only report others', (tester) async {
        final engine = FakeLiveMediaEngine()..present.add('user-0');
        final me = testUser();
        final repo = seatRoom(LiveRoomMode.audio, 9)
          ..chat = [entry('m1', 'Hello room')]
          ..chatAuthor = UserSummary(
            id: me.id,
            username: me.username,
            displayName: me.displayName,
            avatarUrl: null,
          );
        await _pumpRoom(tester, repo: repo, engine: engine, user: me);
        expect(line('Hello room'), findsOneWidget);
        engine.chat
          ..add(
            LiveChatReceived(entry('m2', 'Welcome!', role: LiveChatRole.host)),
          )
          ..add(const LiveChatJoined(huda));
        await tester.pumpAndSettle();
        expect(line('Welcome!'), findsOneWidget);
        expect(line(l10n.liveChatHostBadge), findsOneWidget);
        // D119: the join is the strip pinned under the chat, not a line;
        // the name is direction-isolated.
        expect(line('joined'), findsNothing);
        expect(
          find.descendant(
            of: find.byKey(LiveChatJoinStrip.stripKey),
            matching: find.textContaining('joined'),
          ),
          findsOneWidget,
        );
        // Write.
        await tester.tap(find.byKey(AudioRoomViewKeys.chat));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(LiveChatComposer.fieldKey), 'Hi all');
        await tester.tap(find.byKey(LiveChatComposer.sendKey));
        await tester.pumpAndSettle();
        expect(repo.chatCalls, contains('send:Hi all'));
        expect(line('Hi all'), findsOneWidget);
        // Someone else's line: profile and report only. (The oldest line
        // has scrolled under the top of the box: the rules line, D118, came
        // after it.)
        expect(find.byKey(LiveRoomChatLines.noticeKey), findsOneWidget);
        await tester.tapAt(const Offset(1, 1));
        await tester.pumpAndSettle();
        await tester.tap(line('Welcome!'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('liveChat.action.profile')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('liveChat.action.report')), findsOneWidget);
        expect(find.byKey(const Key('liveChat.action.delete')), findsNothing);
        expect(find.byKey(const Key('liveChat.action.mute')), findsNothing);
        await tester.tap(find.byKey(const Key('liveChat.action.report')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('feed.post.report.spam')));
        await tester.pumpAndSettle();
        expect(repo.chatCalls, contains('report:m2:SPAM'));
        ScaffoldMessenger.of(tester.element(find.byType(LiveRoomScreen)))
            .removeCurrentSnackBar();
        await tester.pumpAndSettle();
        // Their own line: delete.
        await tester.tap(line('Hi all'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('liveChat.action.delete')), findsOneWidget);
        expect(find.byKey(const Key('liveChat.action.report')), findsNothing);
        await tester.tap(find.byKey(const Key('liveChat.action.delete')));
        await tester.pumpAndSettle();
        expect(repo.chatCalls, contains('delete:sent-0'));
        expect(line('Hi all'), findsNothing);
        // A Kabi emoji from the row goes at once as its own message (its
        // token, D66) and shows in the line, animated (so last: it never
        // settles).
        ScaffoldMessenger.of(tester.element(find.byType(LiveRoomScreen)))
            .removeCurrentSnackBar();
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(AudioRoomViewKeys.chat));
        await tester.pumpAndSettle();
        final kabis = find.byType(KabiEmoji).evaluate().length;
        await tester.tap(
          find.byKey(LiveChatComposer.emojiKey(KabsoEmoji.kabi('love'))),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(repo.chatCalls, contains('send::kabi_love:'));
        expect(find.byType(KabiEmoji), findsNWidgets(kabis + 1));
      });

      testWidgets('a moderator deletes and mutes viewers, not the host', (
        tester,
      ) async {
        final engine = FakeLiveMediaEngine()..present.add('user-0');
        final repo = seatRoom(LiveRoomMode.audio, 9)
          ..seatState = seats(
            mode: LiveRoomMode.audio,
            count: 9,
            mine: const LiveSeatsMine(
              role: LiveSeatRole.moderator,
              seatIndex: null,
              request: null,
              invite: null,
            ),
          )
          ..chat = [
            entry('m1', 'buy followers'),
            entry('m2', 'Thanks all', role: LiveChatRole.host),
          ];
        await _pumpRoom(tester, repo: repo, engine: engine, user: testUser());
        await tester.tap(line('buy followers'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('liveChat.action.delete')), findsOneWidget);
        await tester.tap(find.byKey(const Key('liveChat.action.mute')));
        await tester.pumpAndSettle();
        expect(repo.chatCalls, contains('mute:huda'));
        expect(find.textContaining('is muted in this'), findsOneWidget);
        ScaffoldMessenger.of(tester.element(find.byType(LiveRoomScreen)))
            .removeCurrentSnackBar();
        await tester.pumpAndSettle();
        // The host's message: no delete, no mute.
        await tester.tap(line('Thanks all'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('liveChat.action.delete')), findsNothing);
        expect(find.byKey(const Key('liveChat.action.mute')), findsNothing);
      });

      testWidgets('guests read but are asked to sign in to write', (
        tester,
      ) async {
        final repo = seatRoom(LiveRoomMode.audio, 9)
          ..chat = [entry('m1', 'Hello room')];
        await _pumpRoom(tester, repo: repo, engine: FakeLiveMediaEngine());
        expect(line('Hello room'), findsOneWidget);
        // D173: the chat pill (was ref 83's round button) says why.
        expect(_pillSays(l10n.liveChatSignIn), findsOneWidget);
        await tester.tap(find.byKey(AudioRoomViewKeys.chat));
        await tester.pump();
        expect(find.byKey(LiveChatComposer.fieldKey), findsNothing);
      });

      testWidgets('muted, or the chat turned off: the pill says so and the '
          'box does not open', (tester) async {
        for (final (room, hint) in [
          (apiRoom().copyWith(chatMuted: true), l10n.liveChatMutedPill),
          (apiRoom().copyWith(chatEnabled: false), l10n.liveChatOff),
        ]) {
          final engine = FakeLiveMediaEngine();
          final repo = FakeLiveRepository(
            room: (_) => room.copyWith(mode: LiveRoomMode.audio, seatCount: 10),
          )..seatState = seats(mode: LiveRoomMode.audio, count: 10);
          await _pumpRoom(tester, repo: repo, engine: engine, user: testUser());
          expect(_pillSays(hint), findsOneWidget);
          await tester.tap(find.byKey(AudioRoomViewKeys.chat));
          await tester.pump();
          expect(find.byKey(LiveChatComposer.fieldKey), findsNothing);
          ScaffoldMessenger.of(tester.element(find.byType(LiveRoomScreen)))
              .removeCurrentSnackBar();
          await tester.pumpAndSettle();
        }
      });

      testWidgets('a muted viewer who was unmuted can write again: tapping '
          'the pill asks the server', (tester) async {
        var muted = true;
        final repo = FakeLiveRepository(
          room: (id) => apiRoom(
            id: id,
          ).copyWith(mode: LiveRoomMode.audio, seatCount: 10, chatMuted: muted),
        )..seatState = seats(mode: LiveRoomMode.audio, count: 10);
        await _pumpRoom(
          tester,
          repo: repo,
          engine: FakeLiveMediaEngine(),
          user: testUser(),
        );
        expect(_pillSays(l10n.liveChatMutedPill), findsOneWidget);
        muted = false; // The host unmuted (no live notice).
        await tester.tap(find.byKey(AudioRoomViewKeys.chat));
        await tester.pumpAndSettle();
        expect(find.byKey(LiveChatComposer.fieldKey), findsOneWidget);
      });

      testWidgets('the host turning the chat off reaches the room at once', (
        tester,
      ) async {
        final engine = FakeLiveMediaEngine();
        final repo = seatRoom(LiveRoomMode.audio, 9);
        await _pumpRoom(tester, repo: repo, engine: engine, user: testUser());
        expect(_pillSays(l10n.liveChatSayHi), findsOneWidget);
        // Writing when it happens: the box closes so the pill can say why
        // (real two-browser run).
        await tester.tap(find.byKey(AudioRoomViewKeys.chat));
        await tester.pumpAndSettle();
        expect(find.byKey(LiveChatComposer.fieldKey), findsOneWidget);
        engine.chat.add(const LiveChatStateChanged(enabled: false));
        await tester.pumpAndSettle();
        expect(find.byKey(LiveChatComposer.fieldKey), findsNothing);
        expect(_pillSays(l10n.liveChatOff), findsOneWidget);
      });

      testWidgets('video rooms: the chat over the video and the pill above '
          'the buttons', (tester) async {
        final engine = FakeLiveMediaEngine()..present.add('user-0');
        final repo = FakeLiveRepository(room: (id) => apiRoom(id: id))
          ..chat = [entry('m1', 'Nice video')];
        await _pumpRoom(tester, repo: repo, engine: engine, user: testUser());
        expect(line('Nice video'), findsOneWidget);
        await tester.tap(find.byKey(AudioRoomViewKeys.chat));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(LiveChatComposer.fieldKey), 'Wow');
        await tester.tap(find.byKey(LiveChatComposer.sendKey));
        await tester.pumpAndSettle();
        expect(repo.chatCalls, contains('send:Wow'));
        expect(line('Wow'), findsOneWidget);
      });
    });

    testWidgets('a pending request can be cancelled', (tester) async {
      final repo = seatRoom(LiveRoomMode.audio, 9)
        ..seatState = seats(
          mode: LiveRoomMode.audio,
          count: 9,
          mine: LiveSeatsMine(
            role: LiveSeatRole.viewer,
            seatIndex: null,
            request: LiveSeatRequest(
              id: 'r1',
              user: omar,
              seatIndex: null,
              createdAt: DateTime.utc(2026, 10, 23),
            ),
            invite: null,
          ),
        );
      await _pumpRoom(
        tester,
        repo: repo,
        engine: FakeLiveMediaEngine(),
        user: testUser(),
      );
      expect(find.byType(AudioSeatRing), findsOneWidget);
      // D94: the audio room's bar holds the seat button (as the host's).
      await tester.tap(find.byKey(AudioRoomViewKeys.cancel));
      await tester.pumpAndSettle();
      expect(repo.seatCalls, contains('cancelSeatRequest'));
    });

    testWidgets('an invitation asks first; joining seats and publishes', (
      tester,
    ) async {
      final repo = seatRoom(LiveRoomMode.multi, 4)
        ..seatState = seats(
          count: 4,
          mine: LiveSeatsMine(
            role: LiveSeatRole.viewer,
            seatIndex: null,
            request: null,
            invite: LiveSeatInvite(
              id: 'inv-1',
              user: omar,
              seatIndex: 2,
              invitedBy: const UserSummary(
                id: 'user-0',
                username: 'host0',
                displayName: 'Sara',
                avatarUrl: null,
              ),
              expiresAt: DateTime.utc(2030),
            ),
          ),
        );
      final engine = FakeLiveMediaEngine()..publishAllowed = true;
      await _pumpRoom(tester, repo: repo, engine: engine, user: testUser());
      expect(find.byKey(const Key('room.seatInvite')), findsOneWidget);
      expect(find.text(l10n.liveSeatInviteBody('Sara')), findsOneWidget);

      // The server seats us when we accept.
      repo.seatState = seats(
        count: 4,
        mine: const LiveSeatsMine(
          role: LiveSeatRole.seated,
          seatIndex: 2,
          request: null,
          invite: null,
        ),
        list: [
          const LiveSeat(index: 1, state: LiveSeatState.empty, user: null),
          const LiveSeat(index: 2, state: LiveSeatState.taken, user: omar),
          const LiveSeat(index: 3, state: LiveSeatState.empty, user: null),
        ],
      );
      await tester.tap(find.byKey(const Key('room.seatInvite.accept')));
      await tester.pumpAndSettle();
      expect(repo.seatCalls, contains('acceptSeatInvite'));
      expect(engine.publishLocalCalls, [true]);
      expect(find.byKey(const Key('room.seat.leave')), findsOneWidget);

      // Leaving the seat stops publishing.
      repo.seatState = seats(count: 4);
      await tester.tap(find.byKey(const Key('room.seat.leave')));
      await tester.pumpAndSettle();
      expect(repo.seatCalls, contains('leaveSeat'));
      expect(engine.unpublishLocalCalls, 1);
    });

    testWidgets('guests without an account only watch: no seat button', (
      tester,
    ) async {
      await _pumpRoom(
        tester,
        repo: seatRoom(LiveRoomMode.audio, 5),
        engine: FakeLiveMediaEngine(),
      );
      expect(find.byKey(AudioRoomViewKeys.request), findsNothing);
      expect(find.byKey(const Key('room.seat.request')), findsNothing);
    });

    testWidgets('a moderator gets the requests and seat actions', (
      tester,
    ) async {
      final repo = seatRoom(LiveRoomMode.multi, 4)
        ..seatState = seats(
          count: 4,
          mine: const LiveSeatsMine(
            role: LiveSeatRole.moderator,
            seatIndex: null,
            request: null,
            invite: null,
          ),
          list: [
            const LiveSeat(index: 1, state: LiveSeatState.taken, user: omar),
            const LiveSeat(index: 2, state: LiveSeatState.empty, user: null),
            const LiveSeat(index: 3, state: LiveSeatState.empty, user: null),
          ],
        )
        ..pendingSeatRequests = [
          LiveSeatRequest(
            id: 'r9',
            user: omar,
            seatIndex: null,
            createdAt: DateTime.utc(2026, 10, 23),
          ),
        ];
      await _pumpRoom(
        tester,
        repo: repo,
        engine: FakeLiveMediaEngine(),
        user: testUser(),
      );
      await tester.tap(find.byKey(VideoSeatGrid.seatKey(1)));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.liveSeatMute));
      await tester.pumpAndSettle();
      expect(repo.seatCalls, contains('muteSeat:1:true'));

      await tester.tap(find.byKey(const Key('room.seat.requests')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.liveSeatAccept));
      await tester.pumpAndSettle();
      expect(repo.seatCalls, contains('acceptSeatRequest:r9:'));
    });
  });

  group("a person's card in a live (owner, 2026-10-26; D105)", () {
    /// Opens host0's card ("Sara") as [viewer]; returns the fakes.
    Future<({FakeLiveRepository repo, FakeSafetyRepository safety})> card(
      WidgetTester tester, {
      required LivePersonRole viewer,
      LivePersonRole target = LivePersonRole.viewer,
      bool self = false,
      List<String> moderated = const [],
      List<String> kicked = const [],
      AppLanguage language = AppLanguage.en,
      LiveSeat? seat,
      List<String>? seatMutes,
    }) async {
      final repo = FakeLiveRepository()
        ..standings = {'host0': (points: 1240, rank: 3)};
      final safety = FakeSafetyRepository();
      setViewport(tester, GoldenViewport.android);
      await pumpScreen(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => showHostSheet(
                  context,
                  'host0',
                  scope: LivePersonScope(
                    roomId: 'room-0',
                    viewer: viewer,
                    target: target,
                    onModerator: viewer == LivePersonRole.host
                        ? (u, {required moderator}) async =>
                              moderated.add('$u:$moderator')
                        : null,
                    onKicked: () => kicked.add('kicked'),
                    seat: seat,
                    onSeatMute: (index, {required muted}) async =>
                        seatMutes?.add('$index:$muted'),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
        language: language,
        overrides: [
          liveRepositoryProvider.overrideWithValue(repo),
          profileRepositoryProvider.overrideWithValue(
            FakeProfileRepository(apiProfile(isSelf: self)),
          ),
          safetyRepositoryProvider.overrideWithValue(safety),
          currentUserProvider.overrideWithValue(testUser()),
        ],
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return (repo: repo, safety: safety);
    }

    Finder tool(Key key) => find.byKey(key);
    final sara = KFormat.bidiIsolate('Sara');

    testWidgets('the host sees points, kick, chat mute, make moderator and ⋯', (
      tester,
    ) async {
      await card(tester, viewer: LivePersonRole.host);
      expect(find.byKey(const Key('room.hostSheet')), findsOneWidget);
      for (final key in [
        LivePersonToolKeys.points,
        LivePersonToolKeys.kick,
        LivePersonToolKeys.mute,
        LivePersonToolKeys.admin,
        LivePersonToolKeys.more,
      ]) {
        expect(tool(key), findsOneWidget, reason: '$key');
      }
      // The old "⋯ = Manage" is gone.
      expect(find.byKey(const Key('room.userCard.manage')), findsNothing);
      // The host may also act on a moderator.
      await tester.pumpWidget(const SizedBox.shrink());
      await card(
        tester,
        viewer: LivePersonRole.host,
        target: LivePersonRole.moderator,
      );
      expect(tool(LivePersonToolKeys.kick), findsOneWidget);
      expect(tool(LivePersonToolKeys.mute), findsOneWidget);
      expect(find.byTooltip(l10n.liveSeatRemoveModerator), findsOneWidget);
    });

    testWidgets('a moderator sees kick and mute but never the moderator '
        'choice; nothing on another moderator or the host', (tester) async {
      await card(tester, viewer: LivePersonRole.moderator);
      expect(tool(LivePersonToolKeys.points), findsOneWidget);
      expect(tool(LivePersonToolKeys.kick), findsOneWidget);
      expect(tool(LivePersonToolKeys.mute), findsOneWidget);
      expect(tool(LivePersonToolKeys.admin), findsNothing);
      expect(tool(LivePersonToolKeys.more), findsOneWidget);
      for (final target in [LivePersonRole.moderator, LivePersonRole.host]) {
        await tester.pumpWidget(const SizedBox.shrink());
        await card(tester, viewer: LivePersonRole.moderator, target: target);
        expect(tool(LivePersonToolKeys.kick), findsNothing, reason: '$target');
        expect(tool(LivePersonToolKeys.mute), findsNothing, reason: '$target');
        expect(tool(LivePersonToolKeys.admin), findsNothing);
        expect(tool(LivePersonToolKeys.points), findsOneWidget);
        // Owner: everyone sees that they are the host or a moderator.
        expect(
          find.descendant(
            of: find.byKey(const Key('room.userCard.roleBadge')),
            matching: find.text(
              target == LivePersonRole.host
                  ? l10n.goLiveHostTag
                  : l10n.liveSeatModeratorTag,
            ),
          ),
          findsOneWidget,
          reason: '$target',
        );
      }
    });

    testWidgets('a viewer sees only points and ⋯; on your own card only '
        'points', (tester) async {
      await card(tester, viewer: LivePersonRole.viewer);
      expect(tool(LivePersonToolKeys.points), findsOneWidget);
      expect(tool(LivePersonToolKeys.more), findsOneWidget);
      // A plain viewer has no role badge.
      expect(find.byKey(const Key('room.userCard.roleBadge')), findsNothing);
      expect(tool(LivePersonToolKeys.kick), findsNothing);
      expect(tool(LivePersonToolKeys.mute), findsNothing);
      expect(tool(LivePersonToolKeys.admin), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await card(tester, viewer: LivePersonRole.host, self: true);
      expect(tool(LivePersonToolKeys.points), findsOneWidget);
      expect(tool(LivePersonToolKeys.more), findsNothing);
      expect(tool(LivePersonToolKeys.kick), findsNothing);
      expect(tool(LivePersonToolKeys.mute), findsNothing);
      expect(tool(LivePersonToolKeys.admin), findsNothing);
    });

    testWidgets("points: the person's points and rank in this live, or "
        '"no points yet"', (tester) async {
      final fakes = await card(tester, viewer: LivePersonRole.viewer);
      await tester.tap(tool(LivePersonToolKeys.points));
      await tester.pumpAndSettle();
      final popover = find.byKey(LivePersonToolKeys.pointsPopover);
      expect(popover, findsOneWidget);
      expect(fakes.repo.standingCalls, ['host0']);
      expect(
        find.descendant(
          of: popover,
          matching: find.text(l10n.liveScore(1240, '1,240')),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: popover,
          matching: find.text(l10n.liveUserRank('3')),
        ),
        findsOneWidget,
      );
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      fakes.repo.standings = {};
      await tester.tap(tool(LivePersonToolKeys.points));
      await tester.pumpAndSettle();
      expect(find.text(l10n.liveUserNoPoints), findsOneWidget);
      expect(find.text(l10n.liveUserRank('3')), findsNothing);
    });

    testWidgets('kick: asks first, then POST …/kicks, says so and closes', (
      tester,
    ) async {
      final kicked = <String>[];
      final fakes = await card(
        tester,
        viewer: LivePersonRole.moderator,
        kicked: kicked,
      );
      await tester.tap(tool(LivePersonToolKeys.kick));
      await tester.pumpAndSettle();
      expect(find.text(l10n.liveUserKickTitle(sara)), findsOneWidget);
      // Cancel: nothing happens.
      await tester.tap(find.text(l10n.actionCancel));
      await tester.pumpAndSettle();
      expect(fakes.repo.kickCalls, isEmpty);
      await tester.tap(tool(LivePersonToolKeys.kick));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(LivePersonToolKeys.kickConfirm));
      await tester.pumpAndSettle();
      expect(fakes.repo.kickCalls, ['kick:host0']);
      expect(kicked, ['kicked']);
      expect(find.byKey(const Key('room.hostSheet')), findsNothing);
      expect(find.text(l10n.liveUserKicked(sara)), findsOneWidget);
    });

    const seated = LiveSeat(
      index: 3,
      state: LiveSeatState.taken,
      user: UserSummary(
        id: 'user-0',
        username: 'host0',
        displayName: 'Sara',
        avatarUrl: null,
      ),
    );

    testWidgets('the two mutes sit next to ⋯ at the end, away from points', (
      tester,
    ) async {
      for (final language in AppLanguage.values) {
        await tester.pumpWidget(const SizedBox.shrink());
        await card(
          tester,
          viewer: LivePersonRole.host,
          seat: seated,
          language: language,
        );
        final rtl = language == AppLanguage.ar;
        double x(Key k) => tester.getCenter(tool(k)).dx;
        // Reading order: … mic, chat, ⋯ at the end; points at the start.
        final order = [
          LivePersonToolKeys.points,
          LivePersonToolKeys.micMute,
          LivePersonToolKeys.mute,
          LivePersonToolKeys.more,
        ].map(x).toList();
        for (var i = 1; i < order.length; i++) {
          expect(
            rtl ? order[i] < order[i - 1] : order[i] > order[i - 1],
            isTrue,
            reason: '$language $order',
          );
        }
        // Chat mute is the ⋯ button's neighbour (36 dp buttons).
        expect(
          (x(LivePersonToolKeys.more) - x(LivePersonToolKeys.mute)).abs(),
          closeTo(36, 0.5),
        );
        final width =
            tester.view.physicalSize.width / tester.view.devicePixelRatio;
        expect(
          rtl
              ? x(LivePersonToolKeys.mute) < width / 2
              : x(LivePersonToolKeys.mute) > width / 2,
          isTrue,
        );
      }
    });

    testWidgets('mic mute: only for a seated person or guest, toggles the '
        "seat's mic, and follows the same rules", (tester) async {
      // Not on a seat: no mic button.
      await card(tester, viewer: LivePersonRole.host);
      expect(tool(LivePersonToolKeys.micMute), findsNothing);
      // On a seat, seen by the host.
      final mutes = <String>[];
      await tester.pumpWidget(const SizedBox.shrink());
      await card(
        tester,
        viewer: LivePersonRole.host,
        seat: seated,
        seatMutes: mutes,
      );
      expect(find.byTooltip(l10n.liveSeatMuteUser(sara)), findsOneWidget);
      await tester.tap(tool(LivePersonToolKeys.micMute));
      await tester.pumpAndSettle();
      expect(mutes, ['3:true']);
      expect(find.text(l10n.liveSeatUserMuted(sara)), findsOneWidget);
      expect(find.byTooltip(l10n.liveSeatUnmuteUser(sara)), findsOneWidget);
      await tester.tap(tool(LivePersonToolKeys.micMute));
      await tester.pumpAndSettle();
      expect(mutes, ['3:true', '3:false']);
      // Already muted by the host: it opens as "unmute".
      await tester.pumpWidget(const SizedBox.shrink());
      await card(
        tester,
        viewer: LivePersonRole.moderator,
        seat: seated.copyWith(mutedByHost: true),
      );
      expect(find.byTooltip(l10n.liveSeatUnmuteUser(sara)), findsOneWidget);
      // A moderator never on another moderator or the host; a viewer never.
      for (final (viewer, target) in [
        (LivePersonRole.moderator, LivePersonRole.moderator),
        (LivePersonRole.moderator, LivePersonRole.host),
        (LivePersonRole.viewer, LivePersonRole.viewer),
      ]) {
        await tester.pumpWidget(const SizedBox.shrink());
        await card(tester, viewer: viewer, target: target, seat: seated);
        expect(
          tool(LivePersonToolKeys.micMute),
          findsNothing,
          reason: '$viewer → $target',
        );
      }
      // Your own card: never.
      await tester.pumpWidget(const SizedBox.shrink());
      await card(tester, viewer: LivePersonRole.host, self: true, seat: seated);
      expect(tool(LivePersonToolKeys.micMute), findsNothing);
    });

    testWidgets('chat mute shows the state and toggles', (tester) async {
      final fakes = await card(tester, viewer: LivePersonRole.host);
      expect(find.byTooltip(l10n.liveChatMuteUser(sara)), findsOneWidget);
      await tester.tap(tool(LivePersonToolKeys.mute));
      await tester.pumpAndSettle();
      expect(fakes.repo.chatCalls, contains('mute:host0'));
      expect(find.byTooltip(l10n.liveChatUnmuteUser(sara)), findsOneWidget);
      await tester.tap(tool(LivePersonToolKeys.mute));
      await tester.pumpAndSettle();
      expect(fakes.repo.chatCalls, contains('unmute:host0'));
      // Already muted when the card opens: it says so.
      await tester.pumpWidget(const SizedBox.shrink());
      final again = await card(tester, viewer: LivePersonRole.host);
      again.repo.chatMuteList = [
        LiveChatMute(
          user: const UserSummary(
            id: 'user-0',
            username: 'host0',
            displayName: 'Sara',
            avatarUrl: null,
          ),
          mutedAt: DateTime.utc(2026, 10, 26),
        ),
      ];
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byTooltip(l10n.liveChatUnmuteUser(sara)), findsOneWidget);
    });

    testWidgets('the host makes and removes a moderator from the card', (
      tester,
    ) async {
      final moderated = <String>[];
      await card(tester, viewer: LivePersonRole.host, moderated: moderated);
      await tester.tap(tool(LivePersonToolKeys.admin));
      await tester.pumpAndSettle();
      expect(moderated, ['host0:true']);
      expect(find.byTooltip(l10n.liveSeatRemoveModerator), findsOneWidget);
      await tester.tap(tool(LivePersonToolKeys.admin));
      await tester.pumpAndSettle();
      expect(moderated, ['host0:true', 'host0:false']);
      expect(find.byTooltip(l10n.liveSeatMakeModerator), findsOneWidget);
    });

    testWidgets('⋯: report and block go through the safety actions', (
      tester,
    ) async {
      final fakes = await card(tester, viewer: LivePersonRole.viewer);
      await tester.tap(tool(LivePersonToolKeys.more));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(LivePersonToolKeys.report));
      await tester.pumpAndSettle();
      // The reason picker: pick spam.
      await tester.tap(find.byKey(const ValueKey('feed.post.report.spam')));
      await tester.pumpAndSettle();
      expect(fakes.safety.calls, ['reportUser:user-0:SPAM']);
      await tester.tap(tool(LivePersonToolKeys.more));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(LivePersonToolKeys.block));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('safety.block.confirm')));
      await tester.pumpAndSettle();
      expect(fakes.safety.calls, contains('block:host0:true'));
      // Blocked: the card closes.
      expect(find.byKey(const Key('room.hostSheet')), findsNothing);
    });

    testWidgets(
      'the three boxes: no family, a CP request offer, the gift wall soon',
      (tester) async {
        // CP-018: Sara has no family and no partner; the signed-in viewer
        // (not Sara) may send her a CP request; the gift wall is coming.
        await card(tester, viewer: LivePersonRole.viewer);
        expect(find.text(l10n.liveUserNone), findsOneWidget);
        expect(find.text(l10n.cpSendShort), findsOneWidget);
        expect(find.text(l10n.liveUserGiftWall), findsOneWidget);
        // Medals are not a box (owner): they sit in a row under the levels,
        // and only when chosen (none here).
        expect(find.text(l10n.liveUserMedals), findsNothing);
        expect(find.byKey(LivePersonBoxes.boxKey(3)), findsNothing);
        expect(find.byKey(const Key('room.userCard.medals')), findsNothing);
        // The three boxes sit side by side.
        final family = tester.getRect(find.byKey(LivePersonBoxes.boxKey(0)));
        final gifts = tester.getRect(find.byKey(LivePersonBoxes.boxKey(2)));
        expect(family.center.dy, closeTo(gifts.center.dy, 0.5));
        // No counts anywhere.
        expect(find.textContaining('/'), findsNothing);
        // Someone else's empty family is not a button.
        final familyBox = find.byKey(LivePersonBoxes.boxKey(0));
        await Scrollable.ensureVisible(
          tester.element(familyBox),
          alignment: 0.5,
        );
        await tester.pumpAndSettle();
        await tester.tap(familyBox);
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byType(SnackBar), findsNothing);
        expect(find.byKey(const Key('room.hostSheet')), findsOneWidget);
        // The gift wall says it is coming.
        final box = find.byKey(LivePersonBoxes.boxKey(2));
        await Scrollable.ensureVisible(tester.element(box), alignment: 0.5);
        await tester.pumpAndSettle();
        await tester.tap(box);
        await tester.pump();
        expect(
          find.text(l10n.liveUserBoxSoon(l10n.liveUserGiftWall)),
          findsOneWidget,
        );
      },
    );

    testWidgets('fits at 360 dp with text scale 2 (the card scrolls)', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      for (final language in AppLanguage.values) {
        await tester.pumpWidget(const SizedBox.shrink());
        await card(tester, viewer: LivePersonRole.host, language: language);
        expect(tester.takeException(), isNull);
        final gifts = find.byKey(LivePersonBoxes.boxKey(2));
        await tester.ensureVisible(gifts);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  });

  group('kicked out of a live (v1.20-live, D105)', () {
    final me = testUser();
    UserSummary summary(User u) => UserSummary(
      id: u.id,
      username: u.username,
      displayName: u.displayName,
      avatarUrl: null,
    );

    testWidgets('LiveRoom.kicked: opening it says so instead of the room', (
      tester,
    ) async {
      final engine = FakeLiveMediaEngine();
      final (repo, _) = await _pumpRoom(
        tester,
        room: (id) => apiRoom(id: id).copyWith(kicked: true),
        engine: engine,
        user: me,
      );
      expect(find.byKey(LiveRoomScreen.kickedKey), findsOneWidget);
      expect(find.text(l10n.liveKickedTitle), findsOneWidget);
      expect(find.text(l10n.liveKickedBody), findsOneWidget);
      // Never joined.
      expect(repo.tokenRequests, isEmpty);
      expect(engine.joined, isNull);
    });

    testWidgets('the kick data message naming me: leave and say so; someone '
        "else's kick only refreshes", (tester) async {
      final engine = FakeLiveMediaEngine()..present.add('user-0');
      await _pumpRoom(tester, engine: engine, user: me);
      expect(engine.joined, isNotNull);
      engine.chat.add(
        const LiveKickReceived(
          UserSummary(
            id: 'u-other',
            username: 'other',
            displayName: 'Other',
            avatarUrl: null,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(LiveRoomScreen.kickedKey), findsNothing);
      final stops = engine.stops;
      engine.chat.add(LiveKickReceived(summary(me)));
      await tester.pumpAndSettle();
      expect(find.byKey(LiveRoomScreen.kickedKey), findsOneWidget);
      expect(find.text(l10n.liveKickedTitle), findsOneWidget);
      // Left the media session.
      expect(engine.stops, greaterThan(stops));
    });

    testWidgets('the media server removes me ("participant removed")', (
      tester,
    ) async {
      final engine = FakeLiveMediaEngine()..present.add('user-0');
      await _pumpRoom(tester, engine: engine, user: me);
      engine
        ..kickedOut = true
        ..dropped = true
        ..ping();
      await tester.pumpAndSettle();
      expect(find.byKey(LiveRoomScreen.kickedKey), findsOneWidget);
    });

    testWidgets('LIVE_KICKED from the media token or the chat', (tester) async {
      const kickedFailure = ServerFailure(
        code: ErrorCode.liveKicked,
        rawCode: 'LIVE_KICKED',
        debugMessage: 'x',
        statusCode: 403,
      );
      final repo = FakeLiveRepository(room: (id) => apiRoom(id: id))
        ..tokenFailure = kickedFailure;
      await _pumpRoom(
        tester,
        repo: repo,
        engine: FakeLiveMediaEngine(),
        user: me,
      );
      expect(find.byKey(LiveRoomScreen.kickedKey), findsOneWidget);

      final chatRepo = FakeLiveRepository(room: (id) => apiRoom(id: id))
        ..chatFailure = kickedFailure;
      await _pumpRoom(
        tester,
        repo: chatRepo,
        engine: FakeLiveMediaEngine()..present.add('user-0'),
        user: me,
      );
      expect(find.byKey(LiveRoomScreen.kickedKey), findsNothing);
      await tester.tap(find.byKey(AudioRoomViewKeys.chat));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(LiveChatComposer.fieldKey), 'Hi');
      await tester.tap(find.byKey(LiveChatComposer.sendKey));
      await tester.pumpAndSettle();
      expect(find.byKey(LiveRoomScreen.kickedKey), findsOneWidget);
      expect(LiveRoomScreen.kickedKey, isNotNull);
      expect(l10n.errorLiveKicked, isNot(l10n.errorUnknown));
    });
  });
}

/// Room sheets never dim the stream: every modal barrier is transparent.
void _expectNoDimming(WidgetTester tester) {
  final barriers = tester.widgetList<ModalBarrier>(find.byType(ModalBarrier));
  expect(barriers, isNotEmpty);
  for (final barrier in barriers) {
    final color = barrier.color;
    expect(color == null || color.a == 0, isTrue, reason: '$color');
  }
}

/// D173: the audio room's chat pill shows (and reads) [text].
Finder _pillSays(String text) => find.descendant(
  of: find.byKey(AudioRoomViewKeys.chat),
  matching: find.text(text),
);
