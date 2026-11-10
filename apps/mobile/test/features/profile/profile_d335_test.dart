// D335 (owner, with a third-party reference kept out of git (D40): «أريده
// مطابق»): every profile — visitors, the own «أنا» page, staff and the
// founder — has the same header: the cover from the screen's top (the
// person's picture, the founder's video, a staff region cover, else the
// default Kabso cover) with rounded bottom corners; the bar's buttons on
// translucent circles (back + the @username at the reading start, ⋯ at the
// end); the photo in a Kabso-red gradient ring at the reading start over the
// cover's bottom edge, the verification seal on its corner; start-aligned
// under it the name and its seal, the levels / badges, the worn medals, the
// bio, the numbers with dividers and the buttons («متابعة» on the red
// gradient, «مراسلة» with the send icon or «تعديل الملف», and the chevron
// that opens the family / couple / medals tiles); the word tabs with a
// gradient line; rounded grid tiles.
//
// With D335_CAPTURE_DIR set, the capture group writes PNGs there (not
// committed). D335_REF_INSET (dp) sets the status bar of the `ref.*`
// captures (the reference's back button centre, M 75.75 dp, is a 38 dp
// status bar + 10 + 28).

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/models/verification_badge.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/live/presentation/widgets/kabso_team_badge.dart';
import 'package:kabso_live/features/medals/domain/medal_models.dart';
import 'package:kabso_live/features/owner_profile/presentation/owner_actions.dart';
import 'package:kabso_live/features/owner_profile/presentation/owner_cover_video.dart';
import 'package:kabso_live/features/profile/domain/profile_models.dart';
import 'package:kabso_live/features/profile/profile_bonds.dart';
import 'package:kabso_live/features/profile/profile_cover_header.dart';
import 'package:kabso_live/features/profile/profile_default_cover.dart';
import 'package:kabso_live/features/profile/profile_screen.dart';
import 'package:kabso_live/features/profile/public_profile_screen.dart';
import 'package:kabso_live/features/staff/presentation/staff_official_bio.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../fixtures/owner/owner_fixtures.dart';
import '../../helpers/golden.dart';
import '../owner_profile/owner_profile_d301_test.dart'
    show d301Poster, pumpOwnerOwn, pumpOwnerVisitor;
import '../staff/staff_d283_test.dart' show staffProfile;
import 'profile_cover_d278_test.dart'
    show coverBytes, otherProfile, pumpOther, pumpOwn;
import 'profile_on_cover_d299_test.dart' show longBio;

const _worn = ProfileMedals(
  owned: 6,
  total: 9,
  showcase: [
    ProfileMedal(
      code: 'WEALTH_KINGS',
      name: 'Wealth Kings',
      iconKey: 'medal_wealth_kings',
      level: 3,
      iconAsset: 'medal_wealth_l3',
    ),
    ProfileMedal(
      code: 'LUCKY_MASTER',
      name: 'Lucky Master',
      iconKey: 'medal_lucky_master',
      level: 2,
      iconAsset: 'medal_lucky_l2',
    ),
    ProfileMedal(
      code: 'CONTENT_SCHOOL',
      name: 'Content school',
      iconKey: 'medal_content_school',
      level: 4,
      iconAsset: 'medal_content_school_l4',
    ),
    ProfileMedal(
      code: 'DARES_PLAYER',
      name: 'Dares player',
      iconKey: 'medal_dares_player',
      iconAsset: 'medal_dares_player_l1',
    ),
    ProfileMedal(
      code: 'WEALTH_KINGS_2',
      name: 'Wealth Kings',
      iconKey: 'medal_wealth_kings',
      level: 6,
      iconAsset: 'medal_wealth_l6',
    ),
  ],
);

/// Someone else's profile: a cover, the seal, VIP, the host-agent crest,
/// the levels, five worn medals, the four numbers, tags and a link.
PublicProfile d335Rich({required bool ar, bool self = false}) => otherProfile(
  ar: ar,
  self: self,
).copyWith(verification: VerificationBadge.verifiedHost, medals: _worn);

/// No cover (the default Kabso one), not verified, no medals, no tags.
PublicProfile d335Plain({required bool ar}) =>
    apiProfile(ar: ar)
        .copyWith(liveRoomId: null, followerCount: 812, followingCount: 96);

/// The longest name and bio.
PublicProfile d335Long({required bool ar}) => d335Rich(ar: ar).copyWith(
  displayName: ar
      ? 'عبدالرحمن بن سلطان الهاشمي القحطاني'
      : 'Abdulrahman bin Sultan Al-Hashimi Al-Qahtani',
  bio: longBio(ar: ar),
);

/// The reference's content: a cover, verified, the two follow numbers, a
/// two-line bio; no tags, links or medals.
PublicProfile d335AsReference() => apiProfile().copyWith(
  displayName: 'Nabb',
  liveRoomId: null,
  coverUrl: 'https://cdn.k.test/covers/host0.jpg',
  verification: VerificationBadge.verifiedHost,
  followerCount: 19400,
  followingCount: 253,
  bio:
      'Arabic music every evening, live from Riyadh.\n'
      'Request your favourite songs in the comments.',
);

Rect _r(WidgetTester tester, Key key) => tester.getRect(find.byKey(key));

/// The D335 header's geometry on [screen] (LTR or RTL): the cover from the
/// top, the photo at the reading start over its bottom edge, the name block
/// start-aligned under the photo, then the numbers and the buttons; nothing
/// outside the screen.
void expectD335(
  WidgetTester tester, {
  required Size screen,
  required bool rtl,
  bool plainPhoto = true,
  // D357: the founder's page centres the photo and the name.
  bool centred = false,
}) {
  expect(tester.takeException(), isNull);
  final header = _r(tester, ProfileCoverHeader.headerKey);
  expect(header.topLeft, Offset.zero);
  expect(header.width, screen.width);
  final bar = tester.getRect(find.byType(AppBar));
  final cover = _r(tester, ProfileCoverHeader.coverAreaKey);
  expect(cover.top, 0);
  expect(cover.width, screen.width);
  expect(cover.height, KPublicProfile.coverHeightFor(bar.bottom));
  // The photo: its centre [avatarLift] above the cover's edge, at the
  // reading start, never under the bar.
  final photo = _r(tester, ProfileCoverHeader.photoKey);
  expect(
    photo.center.dy,
    moreOrLessEquals(cover.bottom - KPublicProfile.avatarLift, epsilon: 0.5),
  );
  const centre = KPublicProfile.avatarStart + KPublicProfile.avatarOuter / 2;
  expect(
    centred
        ? photo.center.dx
        : rtl
        ? screen.width - photo.center.dx
        : photo.center.dx,
    moreOrLessEquals(centred ? screen.width / 2 : centre, epsilon: 0.5),
  );
  if (plainPhoto) {
    expect(photo.width, KPublicProfile.avatarOuter);
    expect(photo.top, greaterThan(bar.bottom));
  }
  expect(photo.left, greaterThanOrEqualTo(0));
  expect(photo.right, lessThanOrEqualTo(screen.width));
  // The name block on the page under the photo, at the reading start.
  final name = _r(tester, const Key('profile.displayName'));
  final nameLine = _r(tester, ProfileCoverHeader.nameLineKey);
  expect(name.top, greaterThan(cover.bottom));
  expect(nameLine.top, greaterThanOrEqualTo(photo.bottom - 0.5));
  if (centred) {
    expect(name.center.dx, moreOrLessEquals(screen.width / 2, epsilon: 0.5));
  } else {
    final start = rtl ? screen.width - nameLine.right : nameLine.left;
    expect(start, moreOrLessEquals(KPublicProfile.inset, epsilon: 0.5));
  }
  final stats = _r(tester, ProfileScreen.statsKey);
  final actions = _r(tester, ProfileCoverHeader.actionsKey);
  expect(stats.top, greaterThan(nameLine.bottom));
  expect(actions.top, greaterThanOrEqualTo(stats.bottom));
  expect(actions.height, KPublicProfile.buttonHeight);
  for (final key in [
    ProfileCoverHeader.badgesKey,
    ProfileCoverHeader.medalsKey,
    ProfileCoverHeader.bioKey,
  ]) {
    final f = find.byKey(key);
    if (f.evaluate().isEmpty) continue;
    final r = tester.getRect(f);
    expect(r.top, greaterThanOrEqualTo(nameLine.bottom - 0.5), reason: '$key');
    expect(r.bottom, lessThanOrEqualTo(stats.top), reason: '$key');
  }
  for (final r in [name, nameLine, stats, actions]) {
    expect(r.left, greaterThanOrEqualTo(0));
    expect(r.right, lessThanOrEqualTo(screen.width));
    expect(r.bottom, lessThanOrEqualTo(header.bottom));
  }
  // The handle beside back in the bar.
  final handle = _r(tester, ProfileCoverHeader.handleKey);
  expect(handle.bottom, lessThanOrEqualTo(bar.bottom));
  expect(handle.left, greaterThanOrEqualTo(0));
  expect(handle.right, lessThanOrEqualTo(screen.width));
}

/// Disposes the timers (levels, daily badge).
Future<void> _end(WidgetTester tester) => tester.pumpWidget(const SizedBox());

void main() {
  setUpAll(() async {
    await loadAppFonts();
    d301Poster = await paintOwnerPoster();
  });
  setUp(() {
    profileCoverImageFor = (_) => MemoryImage(coverBytes);
    ownerPosterImageFor = (_) => MemoryImage(d301Poster);
  });
  tearDown(() {
    profileCoverImageFor = NetworkImage.new;
    ownerPosterImageFor = NetworkImage.new;
  });

  test('the measured geometry (M at 1.333 px/dp)', () {
    // The cover's edge 288 dp from the top under a ≈ 104 dp bar.
    expect(KPublicProfile.coverHeightFor(104), 288);
    expect(KPublicProfile.coverHeightFor(125), 309);
    // The ringed photo ≈ 115 dp, two thirds on the cover.
    expect(KPublicProfile.avatarOuter, 114);
    expect(KPublicProfile.avatarOverhang, 19);
    expect(KPublicProfile.buttonHeight, 41);
    expect(KProfile.postAspect, 1);
  });

  group("someone else's profile", () {
    for (final language in AppLanguage.values) {
      final ar = language == AppLanguage.ar;
      for (final brightness in Brightness.values) {
        testWidgets('${language.name} ${brightness.name}: the cover, the '
            'photo at the reading start, the seal on it, the name block, '
            'four numbers, Follow / Message / chevron, ⋯ in the bar', (
          tester,
        ) async {
          await pumpOther(
            tester,
            d335Rich(ar: ar),
            language: language,
            brightness: brightness,
          );
          // The fixture wears the VIP frame (framed box, D244).
          expectD335(
            tester,
            screen: const Size(393, 852),
            rtl: ar,
            plainPhoto: false,
          );
          expect(find.byKey(ProfileCoverHeader.coverKey), findsOneWidget);
          // Owner 2: the seal on the photo's corner (bottom end).
          final photo = _r(tester, ProfileCoverHeader.photoKey);
          final seal = _r(tester, ProfileCoverHeader.avatarBadgeKey);
          expect(seal.center.dy, greaterThan(photo.center.dy));
          expect(
            ar
                ? seal.center.dx < photo.center.dx
                : seal.center.dx > photo.center.dx,
            isTrue,
          );
          // Owner 4: the four numbers; the levels under the name; the medals
          // under the levels; the bio under them.
          expect(find.byKey(ProfileCoverHeader.cherriesKey), findsOneWidget);
          expect(find.byKey(ProfileCoverHeader.coinsKey), findsOneWidget);
          final badges = _r(tester, ProfileCoverHeader.badgesKey);
          final medals = _r(tester, ProfileCoverHeader.medalsKey);
          final bio = _r(tester, ProfileCoverHeader.bioKey);
          expect(medals.top, greaterThanOrEqualTo(badges.bottom));
          expect(bio.top, greaterThanOrEqualTo(medals.bottom));
          // The buttons: Follow, Message, the chevron, in reading order; ⋯
          // only in the bar.
          final actions = _r(tester, ProfileCoverHeader.actionsKey);
          final follow = _r(tester, PublicProfileScreen.followKey);
          final message = _r(tester, PublicProfileScreen.messageKey);
          final toggle = _r(tester, ProfileCoverHeader.bondsToggleKey);
          for (final r in [follow, message, toggle]) {
            expect(r.top, greaterThanOrEqualTo(actions.top - 0.5));
            expect(r.bottom, lessThanOrEqualTo(actions.bottom + 0.5));
          }
          if (ar) {
            expect(follow.left, greaterThan(message.right));
            expect(message.left, greaterThan(toggle.right));
          } else {
            expect(follow.right, lessThan(message.left));
            expect(message.right, lessThan(toggle.left));
          }
          expect(follow.width, greaterThan(message.width));
          final bar = tester.getRect(find.byType(AppBar));
          final more = _r(tester, PublicProfileScreen.moreKey);
          expect(find.byKey(PublicProfileScreen.moreKey), findsOneWidget);
          expect(more.bottom, lessThanOrEqualTo(bar.bottom));
          expect(
            ar ? more.left < bar.width / 2 : more.right > bar.width / 2,
            isTrue,
            reason: '⋯ at the reading end',
          );
          await _end(tester);
        });
      }
    }

    testWidgets('no cover: the default Kabso cover; no seal anywhere', (
      tester,
    ) async {
      await pumpOther(tester, d335Plain(ar: true), language: AppLanguage.ar);
      expectD335(tester, screen: const Size(393, 852), rtl: true);
      expect(find.byKey(ProfileCoverHeader.coverKey), findsNothing);
      expect(find.byType(ProfileDefaultCover), findsOneWidget);
      expect(find.byKey(ProfileCoverHeader.avatarBadgeKey), findsNothing);
      expect(find.byKey(ProfileCoverHeader.medalsKey), findsNothing);
      await _end(tester);
    });

    testWidgets('the chevron opens and closes the family / couple / medals '
        'tiles (semantics: expanded); not remembered', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpOther(tester, d335Rich(ar: false), language: AppLanguage.en);
      expect(find.byKey(ProfileCoverHeader.bondsKey), findsNothing);
      expect(find.byType(ProfileBondsRow), findsNothing);
      expect(
        tester.getSemantics(find.byKey(ProfileCoverHeader.bondsToggleKey)),
        isSemantics(
          isButton: true,
          isExpanded: false,
          hasTapAction: true,
          label: 'Show family, couple and medals',
        ),
      );
      final stats = _r(tester, ProfileScreen.statsKey);
      await tester.tap(find.byKey(ProfileCoverHeader.bondsToggleKey));
      await tester.pumpAndSettle();
      expect(find.byKey(ProfileCoverHeader.bondsKey), findsOneWidget);
      expect(find.byType(ProfileBondsRow), findsOneWidget);
      final bonds = _r(tester, ProfileCoverHeader.bondsKey);
      expect(
        bonds.top,
        greaterThanOrEqualTo(_r(tester, ProfileCoverHeader.actionsKey).bottom),
      );
      // Nothing above it moved.
      expect(_r(tester, ProfileScreen.statsKey), stats);
      expect(
        tester.getSemantics(find.byKey(ProfileCoverHeader.bondsToggleKey)),
        isSemantics(
          isButton: true,
          isExpanded: true,
          hasTapAction: true,
          label: 'Hide family, couple and medals',
        ),
      );
      await tester.tap(find.byKey(ProfileCoverHeader.bondsToggleKey));
      await tester.pumpAndSettle();
      expect(find.byKey(ProfileCoverHeader.bondsKey), findsNothing);
      handle.dispose();
      await _end(tester);
    });

    testWidgets('the ⋯ in the bar opens the profile sheet ([_openMore])', (
      tester,
    ) async {
      await pumpOther(tester, d335Rich(ar: true), language: AppLanguage.ar);
      await tester.tap(find.byKey(PublicProfileScreen.moreKey));
      await tester.pumpAndSettle();
      expect(find.byKey(PublicProfileScreen.copyUsernameKey), findsOneWidget);
      expect(find.byKey(PublicProfileScreen.reportKey), findsOneWidget);
      await _end(tester);
    });

    for (final scale in [1.3, 2.0]) {
      for (final language in AppLanguage.values) {
        testWidgets('360 × 800 × $scale ${language.name}: long name and bio, '
            'nothing overflows', (tester) async {
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await pumpOther(
            tester,
            d335Long(ar: language == AppLanguage.ar),
            language: language,
            viewport: GoldenViewport.android,
          );
          expectD335(
            tester,
            screen: const Size(360, 800),
            rtl: language == AppLanguage.ar,
            plainPhoto: false,
          );
          await _end(tester);
        });
      }
    }
  });

  group('the own «أنا» page', () {
    for (final language in AppLanguage.values) {
      testWidgets('${language.name}: the same header; «تعديل الملف» + the '
          'chevron; drafts and settings in the bar', (tester) async {
        final ar = language == AppLanguage.ar;
        await pumpOwn(
          tester,
          language: language,
          stats: d335Rich(ar: ar, self: true),
        );
        expectD335(
          tester,
          screen: const Size(393, 852),
          rtl: ar,
          plainPhoto: false,
        );
        final edit = _r(tester, ProfileScreen.editButtonKey);
        final toggle = _r(tester, ProfileCoverHeader.bondsToggleKey);
        expect(edit.width, greaterThan(200));
        expect(
          ar ? edit.left > toggle.right : edit.right < toggle.left,
          isTrue,
        );
        final bar = tester.getRect(find.byType(AppBar));
        for (final key in [
          ProfileScreen.draftsButtonKey,
          ProfileScreen.settingsButtonKey,
        ]) {
          expect(_r(tester, key).bottom, lessThanOrEqualTo(bar.bottom));
        }
        expect(find.byKey(PublicProfileScreen.moreKey), findsNothing);
        await _end(tester);
      });
    }
  });

  group('staff and founder', () {
    testWidgets('staff: the team frame at the start, no money numbers, no '
        'chevron, no levels; the team badge beside the name and the official '
        'card under it', (tester) async {
      await pumpOther(tester, staffProfile(ar: true), language: AppLanguage.ar);
      expectD335(
        tester,
        screen: const Size(393, 852),
        rtl: true,
        plainPhoto: false,
      );
      expect(find.byKey(ProfileCoverHeader.staffCoverKey), findsOneWidget);
      expect(find.byKey(ProfileCoverHeader.bondsToggleKey), findsNothing);
      expect(find.byKey(ProfileCoverHeader.cherriesKey), findsNothing);
      expect(find.byKey(ProfileCoverHeader.coinsKey), findsNothing);
      expect(find.byKey(ProfileCoverHeader.levelsKey), findsNothing);
      // Follow-up (owner: «اجعل الأيقونة (فريق كابسو) بجانب الاسم، وضع
      // أسفلهم بعد ذلك صندوق البايو»): the team badge on the name line after
      // the name, vertically centred; the official card under the name line,
      // before the numbers and the buttons.
      final line = _r(tester, ProfileCoverHeader.nameLineKey);
      final name = _r(tester, const Key('profile.displayName'));
      final team = find.descendant(
        of: find.byKey(ProfileCoverHeader.nameLineKey),
        matching: find.byKey(KabsoTeamBadge.badgeKey),
      );
      expect(team, findsOneWidget);
      final badge = tester.getRect(team);
      expect(badge.height, KPublicProfile.teamBadgeInline);
      expect(badge.right, lessThanOrEqualTo(name.left));
      expect(badge.center.dy, moreOrLessEquals(name.center.dy, epsilon: 2));
      expect(find.byKey(ProfileCoverHeader.badgesKey), findsNothing);
      final card = _r(tester, StaffOfficialBio.cardKey);
      expect(card.top, greaterThanOrEqualTo(line.bottom));
      expect(
        card.bottom,
        lessThanOrEqualTo(_r(tester, ProfileScreen.statsKey).top),
      );
      expect(
        _r(tester, ProfileScreen.statsKey).bottom,
        lessThanOrEqualTo(_r(tester, PublicProfileScreen.followKey).top),
      );
      await _end(tester);
    });

    for (final language in AppLanguage.values) {
      testWidgets('staff 360 × 800 × 1.3 ${language.name}: a long name is cut, '
          'the team badge stays on the line, nothing overflows', (
        tester,
      ) async {
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final ar = language == AppLanguage.ar;
        await pumpOther(
          tester,
          staffProfile(ar: ar).copyWith(
            displayName: ar
                ? 'مشرف كابسو للوطن العربي والمحتوى والبثوث المباشرة'
                : 'Kabso Moderator for the Arab World and live content',
          ),
          language: language,
          viewport: GoldenViewport.android,
        );
        expectD335(
          tester,
          screen: const Size(360, 800),
          rtl: ar,
          plainPhoto: false,
        );
        final line = _r(tester, ProfileCoverHeader.nameLineKey);
        final badge = tester.getRect(
          find.descendant(
            of: find.byKey(ProfileCoverHeader.nameLineKey),
            matching: find.byKey(KabsoTeamBadge.badgeKey),
          ),
        );
        expect(badge.left, greaterThanOrEqualTo(line.left - 0.5));
        expect(badge.right, lessThanOrEqualTo(line.right + 0.5));
        expect(line.left, greaterThanOrEqualTo(0));
        expect(line.right, lessThanOrEqualTo(360));
        await _end(tester);
      });
    }

    for (final language in AppLanguage.values) {
      testWidgets('founder ${language.name}: the same header over his video '
          'cover; D307 kept (no money numbers, no tabs, outline feedback, '
          'the ⋯ in the bar)', (tester) async {
        final ar = language == AppLanguage.ar;
        await pumpOwnerVisitor(tester, language: language);
        // D357: his page centres the photo and the name.
        expectD335(
          tester,
          screen: const Size(393, 852),
          rtl: ar,
          centred: true,
        );
        final cover = _r(tester, ProfileCoverHeader.coverAreaKey);
        final video = _r(tester, OwnerCoverVideoLayer.layerKey);
        expect(cover.contains(video.center), isTrue);
        // D357: his red badge replaces the seal on the photo.
        expect(find.byKey(ProfileCoverHeader.avatarBadgeKey), findsNothing);
        expect(find.byKey(ProfileCoverHeader.cherriesKey), findsNothing);
        expect(find.byKey(ProfileScreen.tabsKey), findsNothing);
        expect(find.byKey(OwnerVisitorActions.followKey), findsOneWidget);
        expect(find.byKey(OwnerVisitorActions.feedbackKey), findsOneWidget);
        // He holds nothing in the fixture: no chevron (D301 §10.112.6).
        expect(find.byKey(ProfileCoverHeader.bondsToggleKey), findsNothing);
        final bar = tester.getRect(find.byType(AppBar));
        expect(
          _r(tester, PublicProfileScreen.moreKey).bottom,
          lessThanOrEqualTo(bar.bottom),
        );
        await _end(tester);
      });
    }

    testWidgets('founder own page: the same header, «تعديل الملف»', (
      tester,
    ) async {
      await pumpOwnerOwn(tester, language: AppLanguage.ar);
      expectD335(
        tester,
        screen: const Size(393, 852),
        rtl: true,
        centred: true,
      );
      expect(find.byKey(ProfileScreen.editButtonKey), findsOneWidget);
      expect(find.byKey(ProfileScreen.tabsKey), findsNothing);
      await _end(tester);
    });
  });

  final captureDir = Platform.environment['D335_CAPTURE_DIR'];
  final refInset =
      double.tryParse(Platform.environment['D335_REF_INSET'] ?? '') ?? 38;
  group('D335 captures', skip: captureDir == null, () {
    Future<void> capture(WidgetTester tester, String name) async {
      await precacheImages(tester);
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final element = find.byType(MaterialApp).evaluate().first;
        final image = await captureImage(element);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('${captureDir!}/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
      });
    }

    for (final language in AppLanguage.values) {
      final ar = language == AppLanguage.ar;
      for (final brightness in Brightness.values) {
        final tag = '${language.name}.${brightness.name}';
        testWidgets('rich $tag', (tester) async {
          await pumpOther(
            tester,
            d335Rich(ar: ar),
            language: language,
            brightness: brightness,
          );
          await capture(tester, 'rich.$tag');
          await _end(tester);
        });
        testWidgets('plain $tag', (tester) async {
          await pumpOther(
            tester,
            d335Plain(ar: ar),
            language: language,
            brightness: brightness,
          );
          await capture(tester, 'plain.$tag');
          await _end(tester);
        });
        testWidgets('own $tag', (tester) async {
          await pumpOwn(
            tester,
            language: language,
            brightness: brightness,
            stats: d335Rich(ar: ar, self: true),
          );
          await capture(tester, 'own.$tag');
          await _end(tester);
        });
        testWidgets('founder $tag', (tester) async {
          await pumpOwnerVisitor(
            tester,
            language: language,
            brightness: brightness,
          );
          await capture(tester, 'founder.$tag');
          await _end(tester);
        });
        testWidgets('staff $tag', (tester) async {
          await pumpOther(
            tester,
            staffProfile(ar: ar),
            language: language,
            brightness: brightness,
          );
          await capture(tester, 'staff.$tag');
          await _end(tester);
        });
      }
      testWidgets('long + bonds open 360 ${language.name}', (tester) async {
        await pumpOther(
          tester,
          d335Long(ar: ar),
          language: language,
          viewport: GoldenViewport.android,
        );
        await tester.tap(find.byKey(ProfileCoverHeader.bondsToggleKey));
        await tester.pumpAndSettle();
        await capture(tester, 'long.bonds.360.${language.name}');
        await _end(tester);
      });
      testWidgets('private ${language.name}', (tester) async {
        await pumpOther(
          tester,
          apiProfile(ar: ar, isPrivate: true).copyWith(liveRoomId: null),
          language: language,
        );
        await capture(tester, 'private.${language.name}');
        await _end(tester);
      });
      testWidgets('founder own ${language.name}', (tester) async {
        await pumpOwnerOwn(tester, language: language);
        await capture(tester, 'founder.own.${language.name}');
        await _end(tester);
      });
      testWidgets('360 × 800 rich ${language.name}', (tester) async {
        await pumpOther(
          tester,
          d335Rich(ar: ar),
          language: language,
          viewport: GoldenViewport.android,
        );
        await capture(tester, 'rich.360.${language.name}');
        await _end(tester);
      });
    }
    testWidgets("ref en light (the reference's status bar)", (tester) async {
      await pumpOther(tester, d335AsReference(), language: AppLanguage.en);
      tester.view.padding = FakeViewPadding(
        top: refInset * GoldenViewport.pixelRatio,
        bottom: 34 * GoldenViewport.pixelRatio,
      );
      await tester.pumpAndSettle();
      await capture(tester, 'ref.en.light');
      await _end(tester);
    });
  });
}
