// KL-034: the live room — route from the hub, every production state,
// follow with optimistic update and rollback, close and back, the
// non-dimming gift sheet with Send disabled, no fake counts or decorative
// controls, RTL, text scale and contrast on the media scrims.

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show Tristate;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/data/auth_repository_impl.dart';
import 'package:kabso_live/features/auth/domain/entities.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/emoji/kabi_emoji.dart';
import 'package:kabso_live/features/live/data/live_media_engine.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/live_room_screen.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_audio_room.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_seat_tiles.dart';
import 'package:kabso_live/features/live/presentation/widgets/gift_panel.dart';
import 'package:kabso_live/features/live/presentation/widgets/guest_seats.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_full_page.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_chat.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_scaffold.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_states.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_tap_layer.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_view_data.dart';
import 'package:kabso_live/features/live/presentation/widgets/pk_layout.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:kabso_live/features/profile/domain/profile_models.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../fixtures/live/live_fixtures.dart';
import '../../helpers/component_harness.dart';
import '../../helpers/fake_live_media_engine.dart';
import '../../helpers/fake_live_repository.dart';
import '../../helpers/fake_profile_repository.dart';
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
    overrides: [
      liveRepositoryProvider.overrideWithValue(live),
      profileRepositoryProvider.overrideWithValue(profiles),
      if (user != null) currentUserProvider.overrideWithValue(user),
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

/// A chat line (rich text with an icon).
Finder _chat(String text) => find.textContaining(text, findRichText: true);

/// Every visible text (Text and rich text) in the tree.
List<String> _texts(WidgetTester tester) => [
  for (final element in find.byType(RichText).evaluate())
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
      // D50: the hub shows one stream per screen; "Join live" opens it.
      await tester.tap(find.byKey(KLiveFullPage.joinKey).first);
      await tester.pumpAndSettle();

      expect(find.byType(LiveRoomScreen), findsOneWidget);
      expect(live.roomRequests, ['room-0']);
      expect(find.byKey(const Key('nav.home')), findsNothing);
      expect(find.byKey(_hostAway), findsOneWidget);

      await tester.tap(_label(l10n.liveClose));
      await tester.pumpAndSettle();
      expect(find.byType(LiveRoomScreen), findsNothing);
      expect(find.byKey(const Key('nav.home')), findsOneWidget);
      expect(find.byType(KLiveFullPage), findsWidgets);
    });

    testWidgets('system back leaves the room for the hub', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byType(KLiveFullPage).first);
      await tester.pumpAndSettle();
      expect(find.byType(LiveRoomScreen), findsOneWidget);

      // The Android back button.
      await tester.binding.handlePopRoute();
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
      await tester.tap(find.byType(KLiveFullPage).first);
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
      // Room detail: title and category; host from the room, follower
      // count from the public profile.
      expect(find.text('Arabic music night'), findsOneWidget);
      expect(find.text('Music'), findsOneWidget);
      expect(find.text('Sara'), findsOneWidget);
      expect(find.text('1,234 followers'), findsOneWidget);
      // Chat (CP-013): the room's chat, empty so far; the old comment
      // field is gone.
      expect(_chat(l10n.liveChatEmpty), findsOneWidget);
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
        expect(_chat(l10n.liveChatEmpty), findsNothing);
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
      expect(find.text('1,235 followers'), findsOneWidget);
      expect(profiles.calls.last, 'PUT host0');

      profiles.gate!.complete();
      await tester.pumpAndSettle();
      expect(_label(l10n.liveFollowing), findsOneWidget);
      // After the confirmation the chip is gone.
      await tester.pump(KMetrics.followConfirmDuration);
      await tester.pumpAndSettle();
      expect(_label(l10n.liveFollowing), findsNothing);
      expect(_label(l10n.liveFollow), findsNothing);
      expect(find.text('1,235 followers'), findsOneWidget);
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
      expect(find.text('1,235 followers'), findsOneWidget);

      profiles.gate!.complete();
      await tester.pumpAndSettle();
      expect(_label(l10n.liveFollow), findsOneWidget);
      expect(_label(l10n.liveFollowing), findsNothing);
      expect(find.text('1,234 followers'), findsOneWidget);
      expect(find.text(l10n.errorRateLimited), findsOneWidget);
    });

    testWidgets('no Follow for yourself or a private account', (tester) async {
      await _pumpRoom(tester, profile: apiProfile(isSelf: true));
      expect(_label(l10n.liveFollow), findsNothing);
      await _pumpRoom(tester, profile: apiProfile(isPrivate: true));
      expect(_label(l10n.liveFollow), findsNothing);
    });

    testWidgets('the host pill opens the profile sheet: unfollow from there', (
      tester,
    ) async {
      final (_, profiles) = await _pumpRoom(
        tester,
        profile: apiProfile(isFollowing: true),
      );
      // Already following: no chip in the pill.
      expect(_label(l10n.liveFollow), findsNothing);
      await tester.tap(_hostPill(l10n, 'Sara'));
      await tester.pumpAndSettle();
      final sheet = find.byKey(const Key('room.hostSheet'));
      expect(sheet, findsOneWidget);
      expect(find.text('@host0'), findsOneWidget);
      expect(find.text('Arabic music every evening'), findsOneWidget);
      _expectNoDimming(tester);

      // The card shows following and followers counts too, so the button
      // is found by its key.
      final follow = find.byKey(const Key('room.follow'));
      expect(
        find.descendant(of: follow, matching: find.text(l10n.liveFollowing)),
        findsOneWidget,
      );
      await tester.tap(follow);
      await tester.pumpAndSettle();
      expect(profiles.calls.last, 'DELETE host0');
      expect(
        find.descendant(of: follow, matching: find.text(l10n.liveFollow)),
        findsOneWidget,
      );
      // The pill offers Follow again.
      await tester.tapAt(const Offset(200, 200));
      await tester.pumpAndSettle();
      expect(sheet, findsNothing);
      expect(_label(l10n.liveFollow), findsOneWidget);
    });
  });

  group('gifts (HL-L6, B5)', () {
    testWidgets('the sheet does not dim the stream; items show, no prices, '
        'Send disabled with the reason', (tester) async {
      await _pumpRoom(tester);
      await tester.tap(_label(l10n.liveGifts));
      await tester.pumpAndSettle();
      expect(find.byType(KGiftPanel), findsOneWidget);
      _expectNoDimming(tester);
      for (final name in [
        l10n.giftNameHeart,
        l10n.giftNameStar,
        l10n.giftNameDiamond,
        l10n.giftNameCrown,
      ]) {
        expect(find.text(name), findsOneWidget);
      }
      // No invented prices or balance.
      expect(find.byIcon(Icons.monetization_on), findsNothing);
      expect(find.textContaining(RegExp(r'\d')), findsWidgets); // followers
      expect(
        find.descendant(
          of: find.byType(KGiftPanel),
          matching: find.textContaining(RegExp(r'\d')),
        ),
        findsNothing,
      );
      final send = tester.widget<KButton>(
        find.ancestor(
          of: find.text(l10n.giftSend),
          matching: find.byType(KButton),
        ),
      );
      expect(send.onPressed, isNull);
      expect(find.text(l10n.giftSendComingSoon), findsOneWidget);

      // Selecting works; there is no combo without sending.
      await tester.tap(find.text(l10n.giftNameStar));
      await tester.pump();
      await tester.tap(find.text(l10n.giftNameStar));
      await tester.pumpAndSettle();
      expect(find.text(l10n.giftCombo(2)), findsNothing);
      expect(
        tester
            .getSemantics(_label(l10n.giftNameStar))
            .getSemanticsData()
            .flagsCollection
            .isSelected,
        Tristate.isTrue,
      );

      // A tap on the visible stream closes it.
      await tester.tapAt(const Offset(200, 150));
      await tester.pumpAndSettle();
      expect(find.byType(KGiftPanel), findsNothing);
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
      await _pumpRoom(tester, room: (id) => apiRoom(id: id, viewerCount: 3));
      expect(find.byType(KViewerCountChip), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(KViewerStrip),
          matching: find.byType(KAvatar),
        ),
        findsNothing,
      );
    });

    testWidgets('no decorative controls: every room button acts', (
      tester,
    ) async {
      await _pumpRoom(tester);
      final buttons = tester.widgetList<KRoomIconButton>(
        find.byType(KRoomIconButton),
      );
      expect(buttons, hasLength(2)); // close + gifts
      for (final button in buttons) {
        expect(button.onPressed, isNotNull, reason: button.label);
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
        final chat = tester.getCenter(_chat(l.liveChatEmpty)).dx;
        final info = tester.getCenter(find.byType(KRoomInfoRow)).dx;
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
        expect(find.byType(KGiftPanel), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byTooltip(l.liveClose));
        await tester.pumpAndSettle();
        expect(find.byType(KGiftPanel), findsNothing);
        await tester.tap(_hostPill(l, 'سارة'));
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
      expect(find.byKey(LiveRoomScreen.scoreKey), findsNothing);
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
          matching: find.text('3'),
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
          matching: find.text('12.4K'),
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

    testWidgets('guests without an account and the host do not tap', (
      tester,
    ) async {
      await _pumpRoom(tester, engine: FakeLiveMediaEngine());
      expect(find.byKey(LiveTapLayer.tapKey), findsNothing);
      final host = testUser().copyWith(id: 'user-0');
      final (repo, _) = await _pumpRoom(
        tester,
        engine: FakeLiveMediaEngine(),
        user: host,
      );
      expect(find.byKey(LiveTapLayer.tapKey), findsNothing);
      expect(repo.tapBatches, isEmpty);
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
      // Not the host: no Manage, no Invite; their full profile instead.
      expect(find.byKey(const Key('room.userCard.manage')), findsNothing);
      expect(find.byKey(const Key('room.userCard.invite')), findsNothing);
      expect(find.byKey(const Key('room.userCard.profile')), findsOneWidget);
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
            .goLiveShareText(shown.title, shown.host.username),
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
      // Owner (2026-10-26): no mic button; a tap on my own seat mutes me
      // (the mic-off badge shows) and another unmutes me.
      expect(find.byKey(AudioRoomViewKeys.mic), findsNothing);
      await tester.tap(find.byKey(AudioSeatRing.seatKey(1)));
      await tester.pumpAndSettle();
      expect(engine.micEnabled, isFalse);
      await tester.tap(find.byKey(AudioSeatRing.seatKey(1)));
      await tester.pumpAndSettle();
      expect(engine.micEnabled, isTrue);
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
        // Names are direction-isolated inside the line.
        expect(line('joined'), findsOneWidget);
        // Write.
        await tester.tap(find.byKey(AudioRoomViewKeys.chat));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(LiveChatComposer.fieldKey), 'Hi all');
        await tester.tap(find.byKey(LiveChatComposer.sendKey));
        await tester.pumpAndSettle();
        expect(repo.chatCalls, contains('send:Hi all'));
        expect(line('Hi all'), findsOneWidget);
        // Someone else's line: profile and report only.
        await tester.tapAt(const Offset(1, 1));
        await tester.pumpAndSettle();
        await tester.tap(line('Hello room'));
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
        expect(repo.chatCalls, contains('report:m1:SPAM'));
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
        // Ref 83: a round chat button; its label says why (tooltip and
        // screen readers).
        expect(find.byTooltip(l10n.liveChatSignIn), findsOneWidget);
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
          expect(find.byTooltip(hint), findsOneWidget);
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
        expect(find.byTooltip(l10n.liveChatMutedPill), findsOneWidget);
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
        expect(find.byTooltip(l10n.goLiveChatPill), findsOneWidget);
        // Writing when it happens: the box closes so the pill can say why
        // (real two-browser run).
        await tester.tap(find.byKey(AudioRoomViewKeys.chat));
        await tester.pumpAndSettle();
        expect(find.byKey(LiveChatComposer.fieldKey), findsOneWidget);
        engine.chat.add(const LiveChatStateChanged(enabled: false));
        await tester.pumpAndSettle();
        expect(find.byKey(LiveChatComposer.fieldKey), findsNothing);
        expect(find.byTooltip(l10n.liveChatOff), findsOneWidget);
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
