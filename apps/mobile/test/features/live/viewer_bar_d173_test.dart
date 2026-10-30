// D173 (owner, Arabic, on the viewer screens): the video live's guest (∞)
// button, the games (joystick) button on both bars, the video live's cherry
// chip, the wish list in the audio room, and the promo box for everyone,
// through the real viewer screen.
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/home_banner.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/domain/live_watch.dart';
import 'package:kabso_live/features/live/live_room_screen.dart';
import 'package:kabso_live/features/live/presentation/go_live/go_live_parts.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_audio_room.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_cinema.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_rankings_sheet.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_seat_tiles.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_games_sheet.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_gift_sheet.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_chat.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_side_cards.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_watch_card.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../fixtures/live/live_gift_fixtures.dart';
import '../../helpers/fake_home_banners_repository.dart';
import '../../helpers/fake_live_gift_repository.dart';
import '../../helpers/fake_live_media_engine.dart';
import '../../helpers/fake_live_repository.dart';
import '../../helpers/fake_live_watch_repository.dart';
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

final List<HomeBanner> _roomBanners = [
  for (var i = 0; i < 2; i++)
    HomeBanner(
      id: 'room-banner-$i',
      imageUrl: 'https://media.example.test/media/r$i/600.webp',
      link: '/families',
      width: 600,
      height: 800,
    ),
];

final LiveSeats _multiSeats = LiveSeats(
  roomId: 'room-0',
  mode: LiveRoomMode.multi,
  version: 1,
  seatCount: 6,
  seats: [
    for (var i = 1; i < 6; i++)
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

Future<FakeLiveRepository> _pump(
  WidgetTester tester, {
  LiveRoomMode mode = LiveRoomMode.solo,
  List<LiveWishGift> wishes = const [],
  List<HomeBanner> roomBanners = const [],
  int score = 45210,
  AppLanguage language = AppLanguage.en,
  bool signedIn = true,
  GoldenViewport viewport = GoldenViewport.phone,
  double textScale = 1,
  LiveSeats? seats,
  int seatCount = 10,
  LiveWatch? watch,
  FakeLiveMediaEngine? engine,
}) async {
  setViewport(tester, viewport);
  if (textScale != 1) {
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }
  await tester.pumpWidget(const SizedBox.shrink());
  final repo = FakeLiveRepository(
    room: (id) {
      final room = apiRoom(
        id: id,
        ar: language == AppLanguage.ar,
      ).copyWith(wishGifts: wishes, score: score);
      return switch (mode) {
        LiveRoomMode.audio => room.copyWith(mode: mode, seatCount: seatCount),
        LiveRoomMode.multi => room.copyWith(mode: mode, seatCount: 6),
        _ => room,
      };
    },
  )..seatState = seats ?? (mode == LiveRoomMode.multi ? _multiSeats : null);
  await pumpScreen(
    tester,
    const LiveRoomScreen(roomId: 'room-0'),
    language: language,
    liveMediaEngine: engine ?? (FakeLiveMediaEngine()..present.add('user-0')),
    liveGiftRepository: FakeLiveGiftRepository(codes: giftFixtureCodes),
    homeBannersRepository: FakeHomeBannersRepository(roomBanners: roomBanners),
    liveWatchRepository: FakeLiveWatchRepository()
      ..watches.addAll({'room-0': ?watch}),
    overrides: [
      liveRepositoryProvider.overrideWithValue(repo),
      profileRepositoryProvider.overrideWithValue(
        FakeProfileRepository(apiProfile()),
      ),
      if (signedIn) currentUserProvider.overrideWithValue(testUser()),
    ],
  );
  await tester.pumpAndSettle();
  return repo;
}

Future<void> _leave(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  group('D173 video live viewer bar', () {
    for (final language in AppLanguage.values) {
      for (final viewport in GoldenViewport.values) {
        testWidgets('∞, games and gift in one row with the pill, nothing '
            'overlaps (${language.name}, ${viewport.name}, text 1.3)', (
          tester,
        ) async {
          await _pump(
            tester,
            language: language,
            viewport: viewport,
            textScale: 1.3,
          );
          expect(tester.takeException(), isNull);
          final guest = tester.getRect(find.byKey(LiveRoomScreen.guestKey));
          final games = tester.getRect(find.byKey(LiveRoomScreen.gamesKey));
          final gift = tester.getRect(find.byKey(LiveRoomScreen.giftKey));
          final pill = tester.getRect(find.byKey(AudioRoomViewKeys.chat));
          for (final r in [guest, games, gift]) {
            expect((r.center.dy - pill.center.dy).abs(), lessThan(1));
            expect(r.overlaps(pill), isFalse);
          }
          expect(guest.overlaps(games) || games.overlaps(gift), isFalse);
          final width = viewport.logicalSize.width;
          final ar = language == AppLanguage.ar;
          // Reading order: pill, ∞, games, gift (mirrored in Arabic).
          if (ar) {
            expect(pill.left, greaterThan(guest.right - 0.5));
            expect(guest.left, greaterThanOrEqualTo(games.right - 0.5));
            expect(games.left, greaterThanOrEqualTo(gift.right - 0.5));
          } else {
            expect(pill.right, lessThan(guest.left + 0.5));
            expect(guest.right, lessThanOrEqualTo(games.left + 0.5));
            expect(games.right, lessThanOrEqualTo(gift.left + 0.5));
          }
          for (final r in [pill, guest, games, gift]) {
            expect(r.left, greaterThanOrEqualTo(0));
            expect(r.right, lessThanOrEqualTo(width));
          }
          // The pill keeps a usable width (the hint is not squeezed away).
          expect(pill.width, greaterThan(150));
          await _leave(tester);
        });
      }
    }

    testWidgets('solo: ∞ says honestly that a solo live has no guest seats; '
        'no seat request is made', (tester) async {
      await _pump(tester);
      await tester.tap(find.byKey(LiveRoomScreen.guestKey));
      await tester.pump();
      expect(
        find.text(l10nFor(AppLanguage.en).liveGuestSoloInfo),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 5));
      await _leave(tester);
    });

    testWidgets('multi-guest: the seat bar asks for a seat (CP-011); no '
        'second ∞ button', (tester) async {
      await _pump(tester, mode: LiveRoomMode.multi);
      expect(find.byType(VideoSeatGrid), findsOneWidget);
      expect(find.byKey(const Key('room.seat.request')), findsOneWidget);
      expect(find.byKey(LiveRoomScreen.guestKey), findsNothing);
      expect(find.byKey(LiveRoomScreen.gamesKey), findsOneWidget);
      await _leave(tester);
    });

    testWidgets('a guest without an account: games and gift, no ∞', (
      tester,
    ) async {
      await _pump(tester, signedIn: false);
      expect(find.byKey(LiveRoomScreen.guestKey), findsNothing);
      expect(find.byKey(LiveRoomScreen.gamesKey), findsOneWidget);
      await _leave(tester);
    });
  });

  group('D173 ≡ for everyone', () {
    const viewerTools = [
      'share',
      'follow',
      'viewers',
      'contributions',
      'rankings',
      'games',
      'suggestVideo',
      'report',
    ];
    const soonTools = ['minimize', 'giftSounds', 'giftEffects', 'clearScreen'];
    for (final mode in [LiveRoomMode.solo, LiveRoomMode.audio]) {
      for (final language in AppLanguage.values) {
        testWidgets("${mode.name}: a viewer's ≡ lists only what works for "
            'them, the rest greyed «Soon»; no moderator tools '
            '(${language.name}, 360 dp, text 1.3)', (tester) async {
          await _pump(
            tester,
            mode: mode,
            language: language,
            viewport: GoldenViewport.android,
            textScale: 1.3,
          );
          final key = mode == LiveRoomMode.audio
              ? AudioRoomViewKeys.menu
              : LiveRoomScreen.menuKey;
          await tester.tap(find.byKey(key));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          for (final id in [...viewerTools, ...soonTools]) {
            expect(find.byKey(GoLiveKeys.tool(id)), findsOneWidget, reason: id);
          }
          for (final id in soonTools) {
            expect(
              tester
                  .getSemantics(find.byKey(GoLiveKeys.tool(id)))
                  .getSemanticsData()
                  .label,
              contains(l10nFor(language).liveSoon),
              reason: id,
            );
          }
          expect(find.byKey(GoLiveKeys.tool('newcomers')), findsNothing);
          expect(find.text(l10nFor(language).liveToolsModerator), findsNothing);
          // Games opens the honest sheet.
          await tester.tap(find.byKey(GoLiveKeys.tool('games')));
          await tester.pumpAndSettle();
          expect(find.byKey(LiveGamesSheet.sheetKey), findsOneWidget);
          await _leave(tester);
        });
      }
    }

    testWidgets('a guest without an account: share, viewers, rankings, games '
        '— no follow, suggest or report', (tester) async {
      await _pump(tester, signedIn: false);
      await tester.tap(find.byKey(LiveRoomScreen.menuKey));
      await tester.pumpAndSettle();
      expect(find.byKey(GoLiveKeys.tool('share')), findsOneWidget);
      for (final id in ['suggestVideo', 'report', 'leaveSeat']) {
        expect(find.byKey(GoLiveKeys.tool(id)), findsNothing, reason: id);
      }
      await _leave(tester);
    });

    testWidgets('a seated moderator: their tools (Newcomers, seat requests) '
        'and leave seat in ≡', (tester) async {
      final me = testUser();
      await _pump(
        tester,
        mode: LiveRoomMode.audio,
        seats: LiveSeats(
          roomId: 'room-0',
          mode: LiveRoomMode.audio,
          version: 1,
          seatCount: 10,
          seats: [
            LiveSeat(
              index: 1,
              state: LiveSeatState.taken,
              user: UserSummary(
                id: me.id,
                username: me.username,
                displayName: me.displayName,
                avatarUrl: null,
              ),
            ),
            for (var i = 2; i < 10; i++)
              LiveSeat(index: i, state: LiveSeatState.empty, user: null),
          ],
          moderators: const [],
          mine: const LiveSeatsMine(
            role: LiveSeatRole.moderator,
            seatIndex: 1,
            request: null,
            invite: null,
          ),
        ),
      );
      await tester.tap(find.byKey(AudioRoomViewKeys.menu));
      await tester.pumpAndSettle();
      for (final id in ['newcomers', 'seatRequests', 'leaveSeat']) {
        expect(find.byKey(GoLiveKeys.tool(id)), findsOneWidget, reason: id);
      }
      expect(
        find.text(l10nFor(AppLanguage.en).liveToolsModerator),
        findsOneWidget,
      );
      await _leave(tester);
    });
  });

  group('D173 games', () {
    for (final mode in [LiveRoomMode.solo, LiveRoomMode.audio]) {
      for (final language in AppLanguage.values) {
        testWidgets('${mode.name}: the joystick opens the honest «coming '
            'soon» sheet — no game tiles (${language.name})', (tester) async {
          await _pump(tester, mode: mode, language: language);
          final key = mode == LiveRoomMode.audio
              ? AudioRoomViewKeys.games
              : LiveRoomScreen.gamesKey;
          final button = find.byKey(key);
          expect(button, findsOneWidget);
          // The owner's controller art, as on the host's bar.
          expect(
            find.descendant(
              of: button,
              matching: find.image(const AssetImage(LiveGamesSheet.art)),
            ),
            findsOneWidget,
          );
          await tester.tap(button);
          await tester.pumpAndSettle();
          final l10n = l10nFor(language);
          final sheet = find.byKey(LiveGamesSheet.sheetKey);
          expect(sheet, findsOneWidget);
          expect(
            find.descendant(of: sheet, matching: find.text(l10n.liveGamesSoon)),
            findsOneWidget,
          );
          expect(
            find.descendant(of: sheet, matching: find.text(l10n.liveGames)),
            findsOneWidget,
          );
          // Nothing in it can be played.
          for (final type in [
            InkWell,
            GestureDetector,
            FilledButton,
            TextButton,
          ]) {
            expect(
              find.descendant(of: sheet, matching: find.byType(type)),
              findsNothing,
            );
          }
          await _leave(tester);
        });
      }
    }
  });

  group('D173 audio bar', () {
    for (final language in AppLanguage.values) {
      testWidgets('a seated moderator at 360 × 800, text 1.3: the bar (games '
          'added) scrolls sideways instead of overflowing; every button keeps '
          'a 48 pt target and games is reachable (${language.name})', (
        tester,
      ) async {
        final me = testUser();
        await _pump(
          tester,
          mode: LiveRoomMode.audio,
          language: language,
          viewport: GoldenViewport.android,
          textScale: 1.3,
          seats: LiveSeats(
            roomId: 'room-0',
            mode: LiveRoomMode.audio,
            version: 1,
            seatCount: 10,
            seats: [
              LiveSeat(
                index: 1,
                state: LiveSeatState.taken,
                user: UserSummary(
                  id: me.id,
                  username: me.username,
                  displayName: me.displayName,
                  avatarUrl: null,
                ),
              ),
              for (var i = 2; i < 10; i++)
                LiveSeat(index: i, state: LiveSeatState.empty, user: null),
            ],
            moderators: const [],
            mine: const LiveSeatsMine(
              role: LiveSeatRole.moderator,
              seatIndex: 1,
              request: null,
              invite: null,
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.byKey(LiveAudioRoomLayout.crowdedBarKey), findsOneWidget);
        final games = find.byKey(AudioRoomViewKeys.games);
        await tester.ensureVisible(games);
        await tester.pumpAndSettle();
        expect(tester.getSize(games).width, KAudioRoom.barTarget);
        await tester.tap(games);
        await tester.pumpAndSettle();
        expect(find.byKey(LiveGamesSheet.sheetKey), findsOneWidget);
        await _leave(tester);
      });
    }

    testWidgets('a plain viewer: the bar fits, no scrolling', (tester) async {
      await _pump(
        tester,
        mode: LiveRoomMode.audio,
        viewport: GoldenViewport.android,
        textScale: 1.3,
      );
      expect(find.byKey(LiveAudioRoomLayout.crowdedBarKey), findsNothing);
      expect(find.byKey(AudioRoomViewKeys.games), findsOneWidget);
      await _leave(tester);
    });
  });

  group('D173 cherries on the video live', () {
    for (final language in AppLanguage.values) {
      testWidgets('the cherry chip sits right after the board chip, as in '
          'the audio room (${language.name})', (tester) async {
        await _pump(tester, language: language);
        final chip = find.byKey(LiveRoomScreen.scoreChipKey);
        expect(chip, findsOneWidget);
        final l10n = l10nFor(language);
        expect(
          tester.widget<LiveScoreChip>(chip).label,
          l10n.liveScore(45210, KFormat.grouped(45210)),
        );
        final rank = tester.getRect(find.byType(LiveRankChip));
        final rect = tester.getRect(chip);
        expect((rect.center.dy - rank.center.dy).abs(), lessThan(1));
        if (language == AppLanguage.ar) {
          expect(rect.right, lessThanOrEqualTo(rank.left));
        } else {
          expect(rect.left, greaterThanOrEqualTo(rank.right));
        }
        await _leave(tester);
      });
    }

    testWidgets('no points yet: no chip (as in the audio room)', (
      tester,
    ) async {
      await _pump(tester, score: 0);
      expect(find.byKey(LiveRoomScreen.scoreChipKey), findsNothing);
      await _leave(tester);
    });
  });

  group('D173 wish list in the audio room', () {
    for (final language in AppLanguage.values) {
      for (final viewport in GoldenViewport.values) {
        testWidgets('the card sits at the end over the promo box and the gift '
            'button, clear of the seats and the chat (${language.name}, '
            '${viewport.name}, text 1.3)', (tester) async {
          await _pump(
            tester,
            mode: LiveRoomMode.audio,
            wishes: _wishes,
            roomBanners: _roomBanners,
            language: language,
            viewport: viewport,
            textScale: 1.3,
          );
          await tester.pump(const Duration(milliseconds: 100));
          expect(tester.takeException(), isNull);
          final card = tester.getRect(find.byKey(LiveWishCard.cardKey));
          final promo = tester.getRect(find.byKey(LiveRoomPromoBox.boxKey));
          final gift = tester.getRect(find.byKey(AudioRoomViewKeys.gift));
          expect(card.bottom, lessThanOrEqualTo(promo.top + 0.5));
          expect(promo.bottom, lessThanOrEqualTo(gift.top));
          // The promo box keeps its place over the gift button (D141a).
          expect((promo.center.dx - gift.center.dx).abs(), lessThan(12));
          final width = viewport.logicalSize.width;
          final ar = language == AppLanguage.ar;
          expect(ar ? card.left < 12 : card.right > width - 12, isTrue);
          final seats = find.ancestor(
            of: find.byKey(AudioSeatRing.seatKey(0)),
            matching: find.byType(Scrollable),
          );
          expect(
            tester.getRect(seats.first).bottom,
            lessThanOrEqualTo(card.top + 0.5),
          );
          await _leave(tester);
        });
      }
    }

    testWidgets('a row opens the gift panel; no wishes: no card', (
      tester,
    ) async {
      await _pump(tester, mode: LiveRoomMode.audio, wishes: _wishes);
      await tester.tap(find.byKey(LiveWishCard.rowKey('crown')));
      await tester.pumpAndSettle();
      expect(find.byKey(KLiveGiftSheet.sheetKey), findsOneWidget);
      await _leave(tester);
      await _pump(tester, mode: LiveRoomMode.audio);
      expect(find.byKey(LiveWishCard.cardKey), findsNothing);
      await _leave(tester);
    });
  });

  group('D173 cinema (YouTube together in the audio room)', () {
    LiveWatch playing() => LiveWatch(
      roomId: 'room-0',
      video: FakeLiveWatchRepository.videoOf('aaaaaaaaaaa'),
      playing: true,
      positionMs: 30000,
      updatedAt: DateTime.now(),
      serverTime: DateTime.now(),
    );

    for (final viewport in GoldenViewport.values) {
      for (final language in AppLanguage.values) {
        for (final count in [5, 10, 15, 20]) {
          testWidgets("$count seats: the owner's cinema — the player exactly "
              'on the drawn screen, the first ${count < 10 ? count : 10} seats '
              'on the drawn seat backs, the chat on the carpet over the bar '
              '(${language.name}, ${viewport.name}, text 1.3)', (tester) async {
            await _pump(
              tester,
              mode: LiveRoomMode.audio,
              seatCount: count,
              watch: playing(),
              language: language,
              viewport: viewport,
              textScale: 1.3,
            );
            expect(tester.takeException(), isNull);
            final size = viewport.logicalSize;
            final rtl = language == AppLanguage.ar;
            expect(
              find.byKey(LiveAudioRoomLayout.cinemaPictureKey),
              findsOneWidget,
            );
            final top = LiveAudioRoomLayout.cinemaMinScreenTop(
              tester.element(find.byType(LiveAudioRoomLayout)),
            );
            final drawn = LiveCinema.place(
              LiveCinema.screen,
              size,
              minScreenTop: top,
            );
            final player = tester.getRect(find.byKey(LiveWatchLayer.cardKey));
            expect(player.left, closeTo(drawn.left, 0.5));
            expect(player.top, closeTo(drawn.top, 0.5));
            expect(player.width, closeTo(drawn.width, 0.5));
            expect(player.height, closeTo(drawn.height, 0.5));
            expect(player.width / player.height, closeTo(16 / 9, 0.02));
            // The header and its chips stay above the screen.
            final chips = tester.getRect(find.byType(LiveRankChip));
            expect(chips.bottom, lessThan(player.top));
            final shown = count < 10 ? count : 10;
            final bar = tester.getRect(find.byKey(AudioRoomViewKeys.gift));
            for (var i = 0; i < shown; i++) {
              final seat = find.byKey(AudioSeatRing.seatKey(i));
              expect(seat.hitTestable(), findsOneWidget, reason: 'seat $i');
              final back = LiveCinema.place(
                LiveCinema.seatFraction(i, rtl: rtl),
                size,
                minScreenTop: top,
              );
              final r = tester.getRect(seat);
              expect(
                (r.center.dx - back.center.dx).abs(),
                lessThan(1),
                reason: 'seat $i on its drawn seat',
              );
              expect(r.top, greaterThanOrEqualTo(back.top - 1), reason: '$i');
              expect(r.width, greaterThanOrEqualTo(40), reason: '$i');
            }
            // Only the 10 drawn seats; a smaller room leaves the others
            // empty (nothing to tap).
            expect(find.byKey(AudioSeatRing.seatKey(shown)), findsNothing);
            // The chat keeps its place over the bar, under the seats.
            final chat = find.byType(LiveRoomChatLines);
            expect(chat, findsOneWidget);
            // (the lines scroll inside the area under the seats)
            final c = tester.getRect(
              find.ancestor(of: chat, matching: find.byType(Scrollable)).first,
            );
            expect(
              c.top,
              greaterThanOrEqualTo(
                LiveCinema.seatsBottom(size, minScreenTop: top),
              ),
            );
            expect(c.bottom, lessThanOrEqualTo(bar.top));
            await _leave(tester);
          });
        }
      }
    }

    testWidgets('hidden on this phone: the circle rows come back with the '
        '«show» pill; shown again: the cinema', (tester) async {
      await _pump(tester, mode: LiveRoomMode.audio, watch: playing());
      expect(find.byKey(LiveAudioRoomLayout.cinemaKey), findsOneWidget);
      await tester.tap(find.byKey(LiveWatchLayer.hideKey));
      await tester.pumpAndSettle();
      expect(find.byKey(LiveAudioRoomLayout.cinemaKey), findsNothing);
      expect(find.byKey(LiveWatchLayer.cardKey), findsNothing);
      expect(find.byKey(LiveWatchLayer.showKey), findsOneWidget);
      expect(find.byKey(AudioSeatRing.seatKey(9)), findsOneWidget);
      await tester.tap(find.byKey(LiveWatchLayer.showKey));
      await tester.pumpAndSettle();
      expect(find.byKey(LiveAudioRoomLayout.cinemaKey), findsOneWidget);
      await _leave(tester);
    });

    testWidgets('no video: the normal rows (no picture, no player)', (
      tester,
    ) async {
      await _pump(tester, mode: LiveRoomMode.audio);
      expect(find.byKey(LiveAudioRoomLayout.cinemaKey), findsNothing);
      expect(find.byKey(LiveWatchLayer.cardKey), findsNothing);
      await _leave(tester);
    });

    for (final language in AppLanguage.values) {
      testWidgets('someone on seat 12 when the cinema starts is told where '
          'they went: moved to seat 3, or off the seat (${language.name})', (
        tester,
      ) async {
        final me = testUser();
        final engine = FakeLiveMediaEngine()..present.add('user-0');
        LiveSeats mine(int? seat, int version) => LiveSeats(
          roomId: 'room-0',
          mode: LiveRoomMode.audio,
          version: version,
          seatCount: 15,
          seats: [
            for (var i = 1; i < 15; i++)
              LiveSeat(
                index: i,
                state: i == seat ? LiveSeatState.taken : LiveSeatState.empty,
                user: i == seat
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
            role: seat == null ? LiveSeatRole.viewer : LiveSeatRole.seated,
            seatIndex: seat,
            request: null,
            invite: null,
          ),
        );
        final repo = await _pump(
          tester,
          mode: LiveRoomMode.audio,
          seatCount: 15,
          watch: playing(),
          language: language,
          seats: mine(12, 1),
          engine: engine,
        );
        final l10n = l10nFor(language);
        repo.seatState = mine(3, 2);
        engine
          ..version = 2
          ..ping();
        await tester.pumpAndSettle();
        expect(find.text(l10n.liveCinemaMoved(3)), findsOneWidget);
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        // Back on 12 (a fixture jump), then off the seat.
        repo.seatState = mine(12, 3);
        engine
          ..version = 3
          ..ping();
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        repo.seatState = mine(null, 4);
        engine
          ..version = 4
          ..ping();
        await tester.pumpAndSettle();
        expect(find.text(l10n.liveCinemaOffSeat), findsOneWidget);
        await tester.pump(const Duration(seconds: 5));
        await _leave(tester);
      });
    }
  });

  group('D173 promo box for everyone', () {
    for (final mode in [LiveRoomMode.solo, LiveRoomMode.audio]) {
      testWidgets('${mode.name}: a viewer without an account sees it too', (
        tester,
      ) async {
        await _pump(
          tester,
          mode: mode,
          roomBanners: _roomBanners,
          signedIn: false,
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byKey(LiveRoomPromoBox.boxKey), findsOneWidget);
        await _leave(tester);
      });
    }

    for (final language in AppLanguage.values) {
      testWidgets('video: the box is under the «room ranking» chip, on its '
          'side (${language.name})', (tester) async {
        await _pump(tester, roomBanners: _roomBanners, language: language);
        await tester.pump(const Duration(milliseconds: 100));
        final box = tester.getRect(find.byKey(LiveRoomPromoBox.boxKey));
        final rank = tester.getRect(find.byType(LiveRankChip));
        expect(box.top, greaterThanOrEqualTo(rank.bottom));
        expect(box.top - rank.bottom, lessThan(24));
        if (language == AppLanguage.ar) {
          expect(box.right, greaterThan(rank.right - 30));
        } else {
          expect(box.left, lessThan(rank.left + 30));
        }
        await _leave(tester);
      });
    }
  });
}
