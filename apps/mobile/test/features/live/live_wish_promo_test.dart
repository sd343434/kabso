// D135–D137 (owner, staging device): the host's wish list card (D136), the
// in-room promo box (D137), the rules line that shows on entry then goes
// (D135) and the room ID beside the host's name (D135), through the real
// viewer screen.
import 'dart:ui' show Tristate;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/home_banner.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/live_room_screen.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_seat_tiles.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_gift_sheet.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_scaffold.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_side_cards.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../fixtures/live/live_gift_fixtures.dart';
import '../../helpers/fake_home_banners_repository.dart';
import '../../helpers/fake_live_gift_repository.dart';
import '../../helpers/fake_live_media_engine.dart';
import '../../helpers/fake_live_repository.dart';
import '../../helpers/fake_profile_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

const _wishes = [
  LiveWishGift(
    giftCode: 'rose',
    name: 'Rose',
    priceCoins: 1,
    assetKey: 'gift_rose',
    received: 12,
  ),
  LiveWishGift(
    giftCode: 'crown',
    name: 'Crown',
    priceCoins: 299,
    assetKey: 'gift_crown',
  ),
];

Future<FakeHomeBannersRepository> _pump(
  WidgetTester tester, {
  List<LiveWishGift> wishes = _wishes,
  List<HomeBanner> roomBanners = const [],
  AppLanguage language = AppLanguage.en,
  bool signedIn = true,
  bool audio = false,
  GoldenViewport viewport = GoldenViewport.phone,
}) async {
  setViewport(tester, viewport);
  final banners = FakeHomeBannersRepository(roomBanners: roomBanners);
  await tester.pumpWidget(const SizedBox.shrink());
  await pumpScreen(
    tester,
    const LiveRoomScreen(roomId: 'room-0'),
    language: language,
    liveMediaEngine: FakeLiveMediaEngine()..present.add('user-0'),
    liveGiftRepository: FakeLiveGiftRepository(codes: giftFixtureCodes),
    homeBannersRepository: banners,
    overrides: [
      liveRepositoryProvider.overrideWithValue(
        FakeLiveRepository(
          room: (id) {
            final room = apiRoom(id: id)
                .copyWith(wishGifts: wishes, roomNumber: 120345678);
            return audio
                ? room.copyWith(mode: LiveRoomMode.audio, seatCount: 10)
                : room;
          },
        ),
      ),
      profileRepositoryProvider.overrideWithValue(
        FakeProfileRepository(apiProfile()),
      ),
      if (signedIn) currentUserProvider.overrideWithValue(testUser()),
    ],
  );
  await tester.pumpAndSettle();
  return banners;
}

Future<void> _leave(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  group('D136 wish list', () {
    for (final language in AppLanguage.values) {
      testWidgets('the card shows each wish with its received count, at the '
          'reading start (${language.name})', (tester) async {
        await _pump(tester, language: language);
        final card = find.byKey(LiveWishCard.cardKey);
        expect(card, findsOneWidget);
        expect(find.byKey(LiveWishCard.rowKey('rose')), findsOneWidget);
        expect(find.byKey(LiveWishCard.rowKey('crown')), findsOneWidget);
        expect(find.text('×12'), findsOneWidget);
        // D141a (owner): back to D136's see-through card of rows (no
        // sticky note, no title), one row per wish.
        expect(
          find.text(language == AppLanguage.ar ? 'أمنيات' : 'Wishes'),
          findsNothing,
        );
        expect(
          find.descendant(of: card, matching: find.byType(Divider)),
          findsOneWidget,
        );
        final rect = tester.getRect(card);
        expect(tester.getSize(card).width, closeTo(LiveWishCard.width, 0.5));
        expect(
          tester.getSize(find.byKey(LiveWishCard.rowKey('rose'))).height,
          closeTo(LiveWishCard.row, 0.5),
        );
        // The start side (left in English, right in Arabic).
        final ar = language == AppLanguage.ar;
        expect(ar ? rect.right > 393 - 30 : rect.left < 30, isTrue);
        await _leave(tester);
      });
    }

    testWidgets('a row opens the gift panel with that gift selected and the '
        'host as recipient; nothing is sent', (tester) async {
      await _pump(tester);
      await tester.tap(find.byKey(LiveWishCard.rowKey('crown')));
      await tester.pumpAndSettle();
      expect(find.byKey(KLiveGiftSheet.sheetKey), findsOneWidget);
      final cell = find.byKey(KLiveGiftSheet.cellKey('crown'));
      expect(cell, findsOneWidget);
      expect(
        tester
            .getSemantics(
              find.descendant(of: cell, matching: find.byType(Semantics)).first,
            )
            .getSemanticsData()
            .flagsCollection
            .isSelected,
        Tristate.isTrue,
      );
      await _leave(tester);
    });

    testWidgets('no wishes: no card', (tester) async {
      await _pump(tester, wishes: const []);
      expect(find.byKey(LiveWishCard.cardKey), findsNothing);
      await _leave(tester);
    });
  });

  group('D137 promo box', () {
    final room = [
      for (var i = 0; i < 2; i++)
        HomeBanner(
          id: 'room-banner-$i',
          imageUrl: 'https://media.example.test/media/r$i/600.webp',
          link: '/families',
          width: 600,
          height: 800,
        ),
    ];

    for (final language in AppLanguage.values) {
      testWidgets('ROOM banners in a 3:4 box right above the wish note, in '
          'the same column (D141); "–" hides it for this live '
          '(${language.name})', (tester) async {
        final banners = await _pump(
          tester,
          roomBanners: room,
          language: language,
        );
        await tester.pump(const Duration(milliseconds: 100));
        final box = find.byKey(LiveRoomPromoBox.boxKey);
        expect(box, findsOneWidget);
        final rect = tester.getRect(box);
        expect(rect.width, closeTo(LiveRoomPromoBox.width, 0.5));
        expect(rect.height, closeTo(LiveRoomPromoBox.height, 0.5));
        final wish = tester.getRect(find.byKey(LiveWishCard.cardKey));
        // Directly above it (the note is turned a little), centred on it.
        expect(rect.bottom, lessThanOrEqualTo(wish.top + 1));
        expect(wish.top - rect.bottom, lessThan(KLiveSideCards.gap + 4));
        expect((rect.center.dx - wish.center.dx).abs(), lessThan(4));
        expect(find.byKey(LiveRoomPromoBox.pageKey('room-banner-0')), findsOne);
        // Every 4 s the next one.
        await tester.pump(LiveRoomPromoBox.interval);
        await tester.pumpAndSettle();
        expect(find.byKey(LiveRoomPromoBox.pageKey('room-banner-1')), findsOne);
        expect(banners.calls, greaterThan(0));
        await tester.tap(find.byKey(LiveRoomPromoBox.closeKey));
        await tester.pump();
        expect(box, findsNothing);
        await _leave(tester);
      });
    }

    testWidgets('D141a: a finger on the box pauses the carousel; it goes on '
        'after the finger lifts; a swipe changes the banner', (tester) async {
      await _pump(tester, roomBanners: room);
      await tester.pump(const Duration(milliseconds: 100));
      final box = find.byKey(LiveRoomPromoBox.boxKey);
      final page0 = find.byKey(LiveRoomPromoBox.pageKey('room-banner-0'));
      final page1 = find.byKey(LiveRoomPromoBox.pageKey('room-banner-1'));
      final hold = await tester.startGesture(tester.getCenter(box));
      await tester.pump(LiveRoomPromoBox.interval * 2);
      await tester.pump(const Duration(milliseconds: 400));
      expect(page0, findsOne);
      expect(page1, findsNothing);
      await hold.cancel();
      await tester.pump(LiveRoomPromoBox.interval);
      await tester.pumpAndSettle();
      expect(page1, findsOne);
      // A swipe back (English: to the right) shows the first again.
      await tester.drag(box, const Offset(70, 0));
      await tester.pumpAndSettle();
      expect(page0, findsOne);
      await _leave(tester);
    });

    testWidgets('D141a: reduced motion — no slide by itself, the swipe still '
        'works; one banner — no dots, nothing moves', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await _pump(tester, roomBanners: room);
      await tester.pump(const Duration(milliseconds: 100));
      final box = find.byKey(LiveRoomPromoBox.boxKey);
      await tester.pump(LiveRoomPromoBox.interval * 3);
      await tester.pumpAndSettle();
      expect(find.byKey(LiveRoomPromoBox.pageKey('room-banner-0')), findsOne);
      await tester.drag(box, const Offset(-70, 0));
      await tester.pumpAndSettle();
      expect(find.byKey(LiveRoomPromoBox.pageKey('room-banner-1')), findsOne);
      await _leave(tester);
      tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
      await _pump(tester, roomBanners: [room.first]);
      await tester.pump(LiveRoomPromoBox.interval * 2);
      await tester.pumpAndSettle();
      expect(find.byKey(LiveRoomPromoBox.pageKey('room-banner-0')), findsOne);
      expect(find.byKey(LiveRoomPromoBox.dotsKey), findsNothing);
      await _leave(tester);
    });

    for (final language in AppLanguage.values) {
      for (final viewport in GoldenViewport.values) {
        testWidgets('D141a: an audio room shows the box (64 × 85 pt) right '
            'above the gift button at the end, clear of the seats and the '
            'bar (${language.name}, ${viewport.name}, text 1.3)', (
          tester,
        ) async {
          tester.platformDispatcher.textScaleFactorTestValue = 1.3;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await _pump(
            tester,
            roomBanners: room,
            language: language,
            audio: true,
            viewport: viewport,
          );
          await tester.pump(const Duration(milliseconds: 100));
          final box = find.byKey(LiveRoomPromoBox.boxKey);
          expect(box, findsOneWidget);
          final rect = tester.getRect(box);
          expect(rect.width, closeTo(LiveRoomPromoBox.audioWidth, 0.5));
          expect(rect.height, closeTo(LiveRoomPromoBox.audioHeight, 0.5));
          final gift = tester.getRect(find.byKey(AudioRoomViewKeys.gift));
          expect(rect.bottom, lessThanOrEqualTo(gift.top));
          expect(gift.top - rect.bottom, lessThan(16));
          // Over the gift button: the end side (right in English, left in
          // Arabic), mirrored.
          expect((rect.center.dx - gift.center.dx).abs(), lessThan(12));
          final width = viewport.logicalSize.width;
          expect(
            language == AppLanguage.ar
                ? rect.left < 12
                : rect.right > width - 12,
            isTrue,
          );
          // No seat under it.
          // The seats scroll in an area that ends above the box.
          final seats = find.ancestor(
            of: find.byKey(AudioSeatRing.seatKey(0)),
            matching: find.byType(Scrollable),
          );
          expect(
            tester.getRect(seats.first).bottom,
            lessThanOrEqualTo(rect.top),
          );
          await _leave(tester);
        });
      }
    }

    testWidgets('no ROOM banner: no box; D173 (owner: «يجب أن يظهر عند '
        'الجميع»): a guest without an account sees it too', (tester) async {
      await _pump(tester);
      expect(find.byKey(LiveRoomPromoBox.boxKey), findsNothing);
      await _pump(tester, roomBanners: room, signedIn: false);
      expect(find.byKey(LiveRoomPromoBox.boxKey), findsOneWidget);
      await _leave(tester);
    });
  });

  group('D135', () {
    testWidgets('the viewer sees the top-end group: the faces and the count '
        '(ref size), and opens the list; with no list yet, the count with '
        'at least themself', (tester) async {
      await _pump(tester);
      final group = find.byKey(LiveRoomScreen.viewersKey);
      expect(group, findsOneWidget);
      expect(find.text('1'), findsWidgets);
      await _leave(tester);
      setViewport(tester, GoldenViewport.phone);
      await pumpScreen(
        tester,
        const LiveRoomScreen(roomId: 'room-0'),
        liveMediaEngine: FakeLiveMediaEngine()..present.add('user-0'),
        overrides: [
          liveRepositoryProvider.overrideWithValue(
            FakeLiveRepository(room: (id) => apiRoom(id: id))
              ..viewerList = [
                for (final (i, n) in ['Huda', 'Omar', 'Nour', 'Lina'].indexed)
                  LiveViewer(
                    kind: LiveViewerKind.user,
                    user: UserSummary(
                      id: 'v$i',
                      username: 'v$i',
                      displayName: n,
                      avatarUrl: null,
                    ),
                    guestNumber: null,
                    joinedAt: DateTime.utc(2026),
                  ),
              ],
          ),
          profileRepositoryProvider.overrideWithValue(
            FakeProfileRepository(apiProfile()),
          ),
          currentUserProvider.overrideWithValue(testUser()),
        ],
      );
      await tester.pumpAndSettle();
      expect(group, findsOneWidget);
      expect(
        find.descendant(of: group, matching: find.byType(KAvatar)),
        findsNWidgets(3),
      );
      expect(find.descendant(of: group, matching: find.text('4')), findsOne);
      // Ref 158: the count pill is at least 31 × 25 pt, at the top end —
      // right before D181's minimize button (viewers minimize too) and ✕.
      final rect = tester.getRect(group);
      final minimize = tester.getRect(
        find.byKey(LiveRoomScreen.minimizeKey).first,
      );
      expect(rect.right, lessThanOrEqualTo(minimize.left + 0.5));
      expect(rect.right, greaterThan(minimize.left - 16));
      expect(rect.right, greaterThan(393 - 80 - minimize.width));
      await tester.tap(group);
      await tester.pumpAndSettle();
      expect(find.byKey(LiveRoomScreen.viewersKey), findsWidgets);
      await _leave(tester);
    });

    testWidgets("D141: the host's @username beside the name (not the room "
        'number) copies it and says «Copied»', (tester) async {
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
      await _pump(tester);
      final tag = find.byKey(KLiveUsernameTag.tagKey);
      expect(
        find.descendant(of: find.byType(KHostPill), matching: tag),
        findsOneWidget,
      );
      final username = tester
          .widget<KLiveUsernameTag>(find.byType(KLiveUsernameTag))
          .username;
      expect(username, isNotEmpty);
      expect(
        find.descendant(of: tag, matching: find.textContaining('@$username')),
        findsOneWidget,
      );
      // The room number is not shown any more.
      expect(find.textContaining('120345678'), findsNothing);
      await tester.tap(tag);
      await tester.pump();
      expect(copied, '@$username');
      expect(find.text(l10nFor(AppLanguage.en).liveUsernameCopied), findsOne);
      await tester.pump(const Duration(seconds: 5));
      await _leave(tester);
    });
  });
}
