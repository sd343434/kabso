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
}) async {
  setViewport(tester, GoldenViewport.phone);
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
          room: (id) =>
              apiRoom(id: id)
                  .copyWith(wishGifts: wishes, roomNumber: 120345678),
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
        // Ref 158: 94.5 pt wide, 33 pt rows.
        final rect = tester.getRect(card);
        expect(rect.width, closeTo(LiveWishCard.width, 0.5));
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
      testWidgets('ROOM banners in a 3:4 box at the end, opposite the wish '
          'list; "–" hides it for this live (${language.name})', (
        tester,
      ) async {
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
        final ar = language == AppLanguage.ar;
        expect(ar ? rect.left < wish.left : rect.left > wish.left, isTrue);
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

    testWidgets('no ROOM banner, or a guest: no box', (tester) async {
      await _pump(tester);
      expect(find.byKey(LiveRoomPromoBox.boxKey), findsNothing);
      await _pump(tester, roomBanners: room, signedIn: false);
      expect(find.byKey(LiveRoomPromoBox.boxKey), findsNothing);
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
      // Ref 158: the count pill is at least 31 × 25 pt, at the top end.
      final rect = tester.getRect(group);
      expect(rect.right, greaterThan(393 - 80));
      await tester.tap(group);
      await tester.pumpAndSettle();
      expect(find.byKey(LiveRoomScreen.viewersKey), findsWidgets);
      await _leave(tester);
    });

    testWidgets('the room ID beside the host name copies the number', (
      tester,
    ) async {
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
      final id = find.byKey(KHostPill.roomIdKey);
      expect(
        find.descendant(of: find.byType(KHostPill), matching: id),
        findsOneWidget,
      );
      await tester.tap(id);
      await tester.pump();
      expect(copied, '120345678');
      expect(find.text(l10nFor(AppLanguage.en).liveRoomIdCopied), findsOne);
      await tester.pump(const Duration(seconds: 5));
      await _leave(tester);
    });
  });
}
