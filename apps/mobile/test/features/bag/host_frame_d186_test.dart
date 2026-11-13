// D186 (owner): the active-host frame. The bag shows it under «إطارات
// الصورة» with its source line and why it cannot be sent, and wears or
// removes it like any frame; an active host without a stated gender picks
// the colour from a banner and a small sheet (and changes it from the
// selected frame); the worn frame is drawn around the photo on the profile
// header and on the audio-room seats (the host's and a guest's), with no
// name under it. Arabic RTL and English LTR, 360×800 at text scale 1.3.

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/bag/data/bag_repository.dart';
import 'package:kabso_live/features/bag/domain/bag_models.dart';
import 'package:kabso_live/features/bag/presentation/avatar_frame_art.dart';
import 'package:kabso_live/features/bag/presentation/bag_screen.dart';
import 'package:kabso_live/features/bag/presentation/host_frame_sheet.dart';
import 'package:kabso_live/features/live/data/live_gift_repository.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_seat_tiles.dart';
import 'package:kabso_live/features/posts/data/posts_repository.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:kabso_live/features/profile/domain/profile_models.dart';
import 'package:kabso_live/features/profile/profile_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/bag/bag_api_fixtures.dart';
import '../../fixtures/live/live_api_fixtures.dart';
import '../../helpers/fake_bag_repository.dart';
import '../../helpers/fake_live_gift_repository.dart';
import '../../helpers/fake_posts_repository.dart';
import '../../helpers/fake_profile_repository.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';
import '../bonds/bonds_harness.dart';

final DateTime _now = DateTime(2026, 10, 30, 9);

Map<String, Object?> _hostFrameItem(String style, {bool ar = false}) =>
    bagItemJson(
      'host_frame_$style',
      ar: ar,
      category: 'AVATAR_FRAME',
      assetKey: 'host_frame_$style',
      source: 'HOST_ACTIVE',
      transferable: false,
    );

Map<String, Object?> _status({
  bool active = true,
  bool canChoose = false,
  String? style,
  String? frame,
}) => {
  'agencyHost': true,
  'active': active,
  'liveDays': 8,
  'liveSeconds': 40000,
  'style': style,
  'styleFrom': style == null ? null : (canChoose ? 'CHOICE' : 'GENDER'),
  'canChoose': canChoose,
  'frame': frame == null
      ? null
      : {'code': frame, 'assetKey': frame, 'equipped': false},
  'rule': {'minDays': 7, 'minHours': 10, 'windowDays': 30},
};

Future<FakeBagRepository> _pumpBag(
  WidgetTester tester, {
  required List<Map<String, Object?>> items,
  required Map<String, Object?> status,
  String? worn,
  AppLanguage language = AppLanguage.en,
}) async {
  setViewport(tester, GoldenViewport.android);
  final ar = language == AppLanguage.ar;
  final bag = FakeBagRepository(items: items, worn: worn, ar: ar)
    ..hostFrameJson = status;
  await pumpBonds(
    tester,
    const BagScreen(),
    language: language,
    overrides: [
      bagRepositoryProvider.overrideWithValue(bag),
      profileRepositoryProvider.overrideWithValue(
        FakeProfileRepository(apiProfile(isSelf: true)),
      ),
      postsRepositoryProvider.overrideWithValue(FakePostsRepository()),
      liveGiftRepositoryProvider.overrideWithValue(FakeLiveGiftRepository()),
    ],
  );
  return bag;
}

Finder get _list => find
    .descendant(
      of: find.byType(RefreshIndicator),
      matching: find.byType(Scrollable),
    )
    .first;

/// The frame art drawn under [f].
List<String> _framesUnder(WidgetTester tester, Finder f) => [
  for (final i in tester.widgetList<Image>(
    find.descendant(of: f, matching: find.byKey(FramedAvatar.frameKey)),
  ))
    (i.image as AssetImage).assetName,
];

void main() {
  final en = l10nFor(AppLanguage.en);
  final ar = l10nFor(AppLanguage.ar);

  Future<void> select(WidgetTester tester, String code) async {
    if (find.byKey(BagScreen.itemKey(code)).evaluate().isEmpty) {
      await tester.tap(find.byKey(BagScreen.itemsTabKey));
      await tester.pumpAndSettle();
    }
    await tester.scrollUntilVisible(
      find.byKey(BagScreen.itemKey(code)),
      200,
      scrollable: _list,
    );
    await tester.tap(find.byKey(BagScreen.itemKey(code)));
    await tester.pumpAndSettle();
  }

  group('the bag', () {
    testWidgets('shows the host frame; not sendable, says why; wear works', (
      tester,
    ) async {
      await withClock(Clock.fixed(_now), () async {
        final bag = await _pumpBag(
          tester,
          items: [
            bagItemJson('bunny_royal', source: 'FREE_SIGNUP'),
            _hostFrameItem('blue', ar: true),
          ],
          status: _status(style: 'BLUE', frame: 'host_frame_blue'),
          worn: 'bunny_royal',
          language: AppLanguage.ar,
        );
        // A male host: no banner, the colour is not theirs to pick.
        expect(find.byKey(BagScreen.hostFrameBannerKey), findsNothing);
        // «قيد الاستخدام»: the frames column is empty until worn.
        expect(
          find.byKey(BagScreen.emptySlotKey('AVATAR_FRAME')),
          findsOneWidget,
        );
        await select(tester, 'host_frame_blue');
        expect(
          find.byKey(BagScreen.sectionKey('AVATAR_FRAME')),
          findsOneWidget,
        );
        expect(find.text(ar.bagCategoryAvatarFrame), findsWidgets);
        // The tile draws the owner's blue frame.
        expect(
          _framesUnder(
            tester,
            find.byKey(BagScreen.itemKey('host_frame_blue')),
          ),
          ['assets/host_frames/host_frame_blue.webp'],
        );
        expect(
          tester.widget<Text>(find.byKey(BagScreen.selectedSourceKey)).data,
          'مكافأة المضيف النشط',
        );
        expect(
          tester.widget<Text>(find.byKey(BagScreen.noSendKey)).data,
          ar.bagNoSendHostActive,
        );
        expect(
          tester
              .widget<ButtonStyleButton>(find.byKey(BagScreen.sendKey))
              .onPressed,
          isNull,
        );
        expect(find.byKey(BagScreen.hostFrameChangeKey), findsNothing);
        // Wear it: PUT, the worn mark, the in-use column shows it.
        await tester.tap(find.byKey(BagScreen.useKey));
        await tester.pumpAndSettle();
        expect(bag.calls, contains('setEquipped:host_frame_blue'));
        expect(
          find.byKey(BagScreen.wornKey('host_frame_blue')),
          findsOneWidget,
        );
        expect(find.byKey(BagScreen.takeOffKey), findsOneWidget);
        await tester.tap(find.byKey(BagScreen.toolsTabKey));
        await tester.pumpAndSettle();
        expect(
          _framesUnder(tester, find.byKey(BagScreen.slotKey('AVATAR_FRAME'))),
          ['assets/host_frames/host_frame_blue.webp'],
        );
        // Remove it again (still selected).
        await tester.tap(find.byKey(BagScreen.takeOffKey));
        await tester.pumpAndSettle();
        expect(bag.calls, contains('setEquipped:null'));
      });
    });

    testWidgets('no stated gender: the banner, the sheet, then the change', (
      tester,
    ) async {
      await withClock(Clock.fixed(_now), () async {
        final bag = await _pumpBag(
          tester,
          items: [bagItemJson('bunny_royal', source: 'FREE_SIGNUP', ar: false)],
          status: _status(canChoose: true),
          worn: 'bunny_royal',
        );
        expect(find.byKey(BagScreen.hostFrameBannerKey), findsOneWidget);
        expect(find.text(en.hostFrameChooseTitle), findsOneWidget);
        await tester.tap(find.byKey(BagScreen.hostFrameBannerKey));
        await tester.pumpAndSettle();
        expect(find.byType(HostFrameStyleSheet), findsOneWidget);
        // Nothing picked yet: «اختيار» is off.
        expect(
          tester
              .widget<ButtonStyleButton>(
                find.byKey(HostFrameStyleSheet.saveKey),
              )
              .onPressed,
          isNull,
        );
        await tester.tap(
          find.byKey(HostFrameStyleSheet.optionKey(HostFrameStyle.pink)),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(HostFrameStyleSheet.saveKey));
        await tester.pumpAndSettle();
        expect(bag.calls, contains('setHostFrameStyle:PINK'));
        expect(find.byType(HostFrameStyleSheet), findsNothing);
        expect(find.text(en.hostFrameSaved), findsOneWidget);
        // The bag reloaded: the pink frame (selected), no banner.
        expect(find.byKey(BagScreen.hostFrameBannerKey), findsNothing);
        await tester.tap(find.byKey(BagScreen.itemsTabKey));
        await tester.pumpAndSettle();
        expect(
          find.byKey(BagScreen.itemKey('host_frame_pink')),
          findsOneWidget,
        );
        expect(
          tester.widget<Text>(find.byKey(BagScreen.selectedNameKey)).data,
          'Pink host frame',
        );
        expect(find.byKey(BagScreen.hostFrameChangeKey), findsOneWidget);
        // Changed later from the selected frame (once the snack is gone):
        // blue.
        await tester.pump(const Duration(seconds: 6));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(BagScreen.hostFrameChangeKey));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(HostFrameStyleSheet.optionKey(HostFrameStyle.blue)),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(HostFrameStyleSheet.saveKey));
        await tester.pumpAndSettle();
        expect(bag.calls, contains('setHostFrameStyle:BLUE'));
        expect(
          find.byKey(BagScreen.itemKey('host_frame_blue')),
          findsOneWidget,
        );
        expect(find.byKey(BagScreen.itemKey('host_frame_pink')), findsNothing);
      });
    });

    testWidgets('a refused choice stays in the sheet with its message', (
      tester,
    ) async {
      final bag = await _pumpBag(
        tester,
        items: const [],
        status: _status(canChoose: true),
      );
      bag.failNext['setHostFrameStyle'] = const ServerFailure(
        code: ErrorCode.hostFrameStyleFromGender,
        rawCode: 'HOST_FRAME_STYLE_FROM_GENDER',
        debugMessage: 'gender',
        statusCode: 409,
      );
      await tester.tap(find.byKey(BagScreen.hostFrameBannerKey));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(HostFrameStyleSheet.optionKey(HostFrameStyle.blue)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(HostFrameStyleSheet.saveKey));
      await tester.pumpAndSettle();
      expect(find.byType(HostFrameStyleSheet), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(HostFrameStyleSheet.errorKey)).data,
        en.errorHostFrameStyleFromGender,
      );
    });

    for (final language in AppLanguage.values) {
      testWidgets(
        'banner and sheet at 360×800, text scale 1.3 (${language.name})',
        (tester) async {
          tester.platformDispatcher.textScaleFactorTestValue = 1.3;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await _pumpBag(
            tester,
            items: [_hostFrameItem('pink', ar: language == AppLanguage.ar)],
            status: _status(canChoose: true),
            language: language,
          );
          expect(tester.takeException(), isNull);
          expect(find.byKey(BagScreen.hostFrameBannerKey), findsOneWidget);
          await tester.tap(find.byKey(BagScreen.hostFrameBannerKey));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          // The first colour (blue) at the reading start: right in Arabic.
          final blue = tester.getCenter(
            find.byKey(HostFrameStyleSheet.optionKey(HostFrameStyle.blue)),
          );
          final pink = tester.getCenter(
            find.byKey(HostFrameStyleSheet.optionKey(HostFrameStyle.pink)),
          );
          expect(blue.dx > pink.dx, language == AppLanguage.ar);
        },
      );
    }
  });

  group('drawn around the photo', () {
    const pinkFrame = AvatarFrame(
      code: 'host_frame_pink',
      assetKey: 'host_frame_pink',
    );

    test('wire: PublicProfile and UserSummary avatarFrame', () {
      final profile = PublicProfile.fromJson({
        ...publicProfileJson(),
        'avatarFrame': {
          'code': 'host_frame_pink',
          'assetKey': 'host_frame_pink',
        },
      });
      expect(profile.avatarFrame, pinkFrame);
      expect(PublicProfile.fromJson(publicProfileJson()).avatarFrame, isNull);
      final user = UserSummary.fromJson({
        'id': 'u1',
        'username': 'u1',
        'displayName': 'U',
        'avatarUrl': null,
        'avatarFrame': {'code': 'x'},
      });
      expect(user.avatarFrame, isNull);
      expect(AvatarFrameArt.of(pinkFrame), AvatarFrameArt.hostPink);
      expect(
        AvatarFrameArt.byAssetKey('host_frame_blue'),
        AvatarFrameArt.hostBlue,
      );
      // A frame without art here (e.g. a support frame) is not drawn.
      expect(AvatarFrameArt.byAssetKey('support_frame_01'), isNull);
    });

    for (final language in AppLanguage.values) {
      testWidgets('the profile header (${language.name})', (tester) async {
        setViewport(tester, GoldenViewport.android);
        Future<void> header({AvatarFrame? frame, String? agent}) async {
          await pumpScreen(
            tester,
            Scaffold(
              body: ProfileHeaderView(
                displayName: 'Layla',
                followers: 1,
                following: 2,
                actions: const SizedBox.shrink(),
                avatarFrame: frame,
                agentCode: agent,
              ),
            ),
            language: language,
          );
          await tester.pumpAndSettle();
        }

        await header(frame: pinkFrame);
        expect(tester.takeException(), isNull);
        expect(
          _framesUnder(tester, find.byKey(ProfileHeaderView.avatarFrameKey)),
          ['assets/host_frames/host_frame_pink.webp'],
        );
        // No name under the frame: the name appears once (in the header).
        expect(find.text('Layla'), findsOneWidget);
        // The photo sits in the measured circle.
        final frameBox = tester.getRect(
          find.byKey(ProfileHeaderView.avatarFrameKey),
        );
        final photo = tester.getRect(
          find.descendant(
            of: find.byKey(ProfileHeaderView.avatarFrameKey),
            matching: find.byType(KAvatar),
          ),
        );
        const art = AvatarFrameArt.hostPink;
        expect(
          photo.center.dx,
          moreOrLessEquals(frameBox.left + frameBox.width * art.cx, epsilon: 1),
        );
        expect(
          photo.center.dy,
          moreOrLessEquals(frameBox.top + frameBox.width * art.cy, epsilon: 1),
        );
        expect(
          photo.width,
          moreOrLessEquals(
            frameBox.width * 2 * art.r * AvatarFrameArt.tuck,
            epsilon: 1,
          ),
        );
        // The recharge-agent frame (with its code) wins on the profile.
        await header(frame: pinkFrame, agent: 'coin0001');
        expect(find.byKey(ProfileHeaderView.avatarFrameKey), findsNothing);
        expect(find.byKey(ProfileHeaderView.agentFrameKey), findsOneWidget);
        // A frame without art: the plain photo.
        await header(
          frame: const AvatarFrame(code: 'x', assetKey: 'support_frame_03'),
        );
        expect(find.byKey(ProfileHeaderView.avatarFrameKey), findsNothing);
      });
    }

    testWidgets('the audio seats: the host and a guest wear theirs', (
      tester,
    ) async {
      setViewport(tester, GoldenViewport.phone);
      await pumpScreen(
        tester,
        const Scaffold(
          body: AudioSeatRing(
            count: 5,
            host: KAvatar(name: 'Layla', size: AudioSeatRing.picture),
            hostName: 'Layla',
            hostFrame: pinkFrame,
            seats: [
              LiveSeat(
                index: 1,
                state: LiveSeatState.taken,
                user: UserSummary(
                  id: 'u1',
                  username: 'omar',
                  displayName: 'Omar',
                  avatarUrl: null,
                  avatarFrame: AvatarFrame(
                    code: 'host_frame_blue',
                    assetKey: 'host_frame_blue',
                  ),
                ),
              ),
              LiveSeat(
                index: 2,
                state: LiveSeatState.taken,
                user: UserSummary(
                  id: 'u2',
                  username: 'sami',
                  displayName: 'Sami',
                  avatarUrl: null,
                ),
              ),
            ],
          ),
        ),
        language: AppLanguage.ar,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(_framesUnder(tester, find.byKey(AudioSeatRing.seatKey(0))), [
        'assets/host_frames/host_frame_pink.webp',
      ]);
      expect(_framesUnder(tester, find.byKey(AudioSeatRing.seatKey(1))), [
        'assets/host_frames/host_frame_blue.webp',
      ]);
      expect(
        _framesUnder(tester, find.byKey(AudioSeatRing.seatKey(2))),
        isEmpty,
      );
      // A framed picture is a little smaller so the frame is about a seat
      // wide; the measured circle's centre is the picture's.
      final picture = tester.getRect(
        find
            .descendant(
              of: find.byKey(AudioSeatRing.seatKey(1)),
              matching: find.byType(KAvatar),
            )
            .first,
      );
      expect(
        picture.width,
        moreOrLessEquals(
          AudioSeatRing.framedPictureFor(AvatarFrameArt.hostBlue),
          epsilon: 0.01,
        ),
      );
      final plain = tester.getRect(
        find
            .descendant(
              of: find.byKey(AudioSeatRing.seatKey(2)),
              matching: find.byType(KAvatar),
            )
            .first,
      );
      expect(plain.width, AudioSeatRing.picture);
      // The seats keep their places: the framed one is centred like the
      // plain one on the same row.
      expect(picture.center.dy, moreOrLessEquals(plain.center.dy));
      final frame = tester.getRect(
        find.descendant(
          of: find.byKey(AudioSeatRing.seatKey(1)),
          matching: find.byKey(FramedAvatar.frameKey),
        ),
      );
      const art = AvatarFrameArt.hostBlue;
      // Owner (after D189): the seat's standard frame box — a square art is
      // as wide as the seat.
      expect(frame.width, moreOrLessEquals(AudioSeatRing.tileWidth));
      expect(
        frame.left + frame.width * art.cx,
        moreOrLessEquals(picture.center.dx, epsilon: 0.5),
      );
      expect(
        frame.top + frame.width * art.cy,
        moreOrLessEquals(picture.center.dy, epsilon: 0.5),
      );
      // No name under the frame: each name once.
      expect(find.text('Omar'), findsOneWidget);
    });
  });
}
