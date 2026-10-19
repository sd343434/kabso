// KL-034: the live room — route from the hub, every production state,
// follow with optimistic update and rollback, close and back, the
// non-dimming gift sheet with Send disabled, no fake counts or decorative
// controls, RTL, text scale and contrast on the media scrims.

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show Tristate;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/data/auth_repository_impl.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/live_room_screen.dart';
import 'package:kabso_live/features/live/presentation/widgets/gift_panel.dart';
import 'package:kabso_live/features/live/presentation/widgets/guest_seats.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_full_page.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_scaffold.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_states.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_view_data.dart';
import 'package:kabso_live/features/live/presentation/widgets/pk_layout.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:kabso_live/features/profile/domain/profile_models.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../fixtures/live/live_fixtures.dart';
import '../../helpers/component_harness.dart';
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
}) async {
  final ar = language == AppLanguage.ar;
  final live = FakeLiveRepository(room: room ?? (id) => apiRoom(id: id));
  final profiles = FakeProfileRepository(profile ?? apiProfile(ar: ar));
  setViewport(tester, viewport);
  // A fresh tree (and provider container) for every call in a test.
  await tester.pumpWidget(const SizedBox.shrink());
  await pumpScreen(
    tester,
    const LiveRoomScreen(roomId: 'room-0'),
    language: language,
    overrides: [
      liveRepositoryProvider.overrideWithValue(live),
      profileRepositoryProvider.overrideWithValue(profiles),
    ],
  );
  settle
      ? await tester.pumpAndSettle()
      : await tester.pump(const Duration(milliseconds: 50));
  return (live, profiles);
}

Finder _label(String label) => find.bySemanticsLabel(label);

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
      expect(find.byType(KRoomVideoUnavailable), findsOneWidget);

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
      expect(find.byType(KRoomVideoUnavailable), findsNothing);
      expect(_label(l10n.liveClose), findsOneWidget);
    });

    testWidgets('live: the honest video-unavailable stage with real room and '
        'host data', (tester) async {
      await _pumpRoom(
        tester,
        room: (id) => apiRoom(
          id: id,
          category: const LiveCategory(slug: 'music', name: 'Music'),
        ),
      );
      expect(find.byType(KRoomVideoUnavailable), findsOneWidget);
      expect(find.text(l10n.liveRoomVideoUnavailableTitle), findsOneWidget);
      // Room detail: title and category; host from the room, follower
      // count from the public profile.
      expect(find.text('Arabic music night'), findsOneWidget);
      expect(find.text('Music'), findsOneWidget);
      expect(find.text('Sara'), findsOneWidget);
      expect(find.text('1,234 followers'), findsOneWidget);
      // Chat: an honest notice, no composer.
      expect(_chat(l10n.liveRoomChatUnavailable), findsOneWidget);
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
        expect(_chat(l10n.liveRoomChatUnavailable), findsNothing);
        expect(find.byType(KRoomActionBar), findsNothing);
        expect(find.byType(KRoomVideoUnavailable), findsNothing);
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
      expect(find.byType(KRoomVideoUnavailable), findsOneWidget);
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
      expect(find.byType(KRoomVideoUnavailable), findsOneWidget);
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
      expect(find.byType(KRoomVideoUnavailable), findsOneWidget);
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

      await tester.tap(
        find.descendant(of: sheet, matching: find.text(l10n.liveFollowing)),
      );
      await tester.pumpAndSettle();
      expect(profiles.calls.last, 'DELETE host0');
      expect(
        find.descendant(of: sheet, matching: find.text(l10n.liveFollow)),
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
        final chat = tester.getCenter(_chat(l.liveRoomChatUnavailable)).dx;
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
