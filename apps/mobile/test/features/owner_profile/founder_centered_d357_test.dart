// D357 (owner, 2026-11-10; CONVENTIONS §10.153): the FOUNDER's page only —
// «اجعل صفحة مؤسس المنصة صورته الشخصية في المنتصف، واسمه اسفل بلون الأحمر،
// وشارته في المنتصف لكن بلون احمر وبداخلها اشارة مثلث كاليوتيوب مفرغة،
// والبايو في المنتصف، واظهر فقط عدد متابعين المؤسس وبجانبها عدد الاقتراحات
// والشكاوي».
//
//  - the photo centred over the cover's edge (his video kept), the name
//    centred under it in Kabso red, bold;
//  - his badge (owner: «الشارة مثلما كانت لكن بدل ما بداخلها صح يصبح مثلث»):
//    the D293 rosette seal in Kabso red with a white play triangle instead
//    of the check («مؤسس Kabso Live»); owner, the same day: «بجانب اسم
//    المؤسس ازل الشارة» — nothing beside or under his name: one seal at the
//    bottom centre of his photo (0.28 of it, ≥ 20 lp) over its rim, on a
//    white / surface ring; no D293 seal anywhere (photo, name, «ازيلها»);
//  - the bio centred; only two numbers — «المتابِعون» and «الاقتراحات
//    والشكاوى» (`founderFeedbackCount`, «–» when the server sends none);
//  - the follow and «اقترح ميزة / أبلغ» buttons, the own «تعديل الملف»;
//  - a regular user and a staff account keep the D335 layout;
//  - 360 × 800 at text scale 1.3, Arabic and English: nothing overflows.
//
// Captures (393 × 852 @3x): D357_CAPTURE_DIR=<dir> flutter test <this file>.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/models/profile_fields.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/owner_profile/presentation/founder_badge.dart';
import 'package:kabso_live/features/owner_profile/presentation/founder_socials.dart';
import 'package:kabso_live/features/owner_profile/presentation/owner_actions.dart';
import 'package:kabso_live/features/owner_profile/presentation/owner_cover_video.dart';
import 'package:kabso_live/features/profile/profile_cover_header.dart';
import 'package:kabso_live/features/profile/profile_fields_view.dart';
import 'package:kabso_live/features/profile/profile_screen.dart';
import 'package:kabso_live/features/profile/profile_verification_badge.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/owner/owner_fixtures.dart';
import '../../helpers/golden.dart';
import '../profile/profile_cover_d278_test.dart' show coverBytes, pumpOther;
import '../profile/profile_d335_test.dart' show d335Rich;
import '../staff/staff_d283_test.dart' show staffProfile;
import 'owner_profile_d301_test.dart'
    show d301Poster, pumpOwnerOwn, pumpOwnerVisitor;

Rect _r(WidgetTester tester, Key key) => tester.getRect(find.byKey(key));

class _Opener implements ExternalLinkOpener {
  final List<Uri> opened = [];
  bool ok = true;

  @override
  Future<bool> open(Uri url) async {
    opened.add(url);
    return ok;
  }
}

Future<void> _end(WidgetTester tester) => tester.pumpWidget(const SizedBox());

/// The text of the stat [key] (its number, then its label).
List<String> _statTexts(WidgetTester tester, Key key) => [
  for (final t in tester.widgetList<Text>(
    find.descendant(of: find.byKey(key), matching: find.byType(Text)),
  ))
    // The numbers are Latin isolates (D220): compare the visible text.
    (t.data ?? '').replaceAll(RegExp('[\u2066-\u2069]'), ''),
];

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

  test('the badge: the D293 rosette in Kabso red, a solid white play '
      'triangle (≥ 3 : 1), its corners 0.30 × 0.34 of the seal, nudged '
      'toward the point', () {
    expect(FounderBadge.fill, KBrandColors.red500);
    expect(FounderBadge.ink, const Color(0xFFFFFFFF));
    final contrast =
        (FounderBadge.ink.computeLuminance() + 0.05) /
        (FounderBadge.fill.computeLuminance() + 0.05);
    expect(contrast, greaterThanOrEqualTo(3));
    const box = Size(100, 100);
    final c = FounderPlayPainter.corners(box);
    final xs = c.map((p) => p.dx);
    final ys = c.map((p) => p.dy);
    final left = xs.reduce((a, b) => a < b ? a : b);
    final right = xs.reduce((a, b) => a > b ? a : b);
    final top = ys.reduce((a, b) => a < b ? a : b);
    final bottom = ys.reduce((a, b) => a > b ? a : b);
    expect(right - left, moreOrLessEquals(30));
    expect(bottom - top, moreOrLessEquals(34));
    // The point on the right, at mid-height; the box shifted toward it.
    expect(c[1].dx, right);
    expect(c[1].dy, moreOrLessEquals(50));
    expect((left + right) / 2, greaterThan(50));
    expect((left + right) / 2 - 50, lessThan(5));
    // The rounding stays inside the seal's inner disc.
    expect(FounderPlayPainter.round, lessThan(0.08));
  });

  for (final language in AppLanguage.values) {
    final ar = language == AppLanguage.ar;
    group('founder visitor ${language.name}', () {
      testWidgets('centred photo and red name, the red seal under the name '
          '(no blue seal), centred bio, only the two numbers', (tester) async {
        await pumpOwnerVisitor(tester, language: language);
        expect(tester.takeException(), isNull);
        const w = 393.0;
        // The cover video is kept at the top.
        expect(find.byKey(OwnerCoverVideoLayer.layerKey), findsOneWidget);
        final cover = _r(tester, ProfileCoverHeader.coverAreaKey);
        final photo = _r(tester, ProfileCoverHeader.photoKey);
        expect(photo.center.dx, moreOrLessEquals(w / 2, epsilon: 0.5));
        expect(photo.top, lessThan(cover.bottom));
        expect(photo.bottom, greaterThan(cover.bottom));
        // The name: centred under the photo, Kabso red, bold.
        final nameFinder = find.byKey(const Key('profile.displayName'));
        final name = tester.getRect(nameFinder);
        expect(name.center.dx, moreOrLessEquals(w / 2, epsilon: 0.5));
        expect(name.top, greaterThanOrEqualTo(photo.bottom - 0.5));
        final style = tester.widget<Text>(nameFinder).style!;
        expect(style.color, KBrandColors.red500);
        expect(style.fontWeight, FontWeight.w800);
        // The badge: at the photo's bottom centre, over its rim (part on
        // the photo, part below it), above the name — never beside or under
        // it; 0.28 of the 114 dp photo (32) + a 2.5 dp ring each side.
        final badge = _r(tester, FounderBadge.badgeKey);
        expect(badge.center.dx, moreOrLessEquals(w / 2, epsilon: 0.5));
        expect(badge.top, lessThan(photo.bottom));
        expect(badge.bottom, greaterThan(photo.bottom));
        expect(badge.center.dy, lessThan(photo.bottom));
        expect(badge.bottom, lessThanOrEqualTo(name.top));
        final seal = KPublicProfile.founderSealFor(KPublicProfile.avatarOuter);
        expect(seal, 32);
        expect(seal / KPublicProfile.avatarOuter, inInclusiveRange(0.26, 0.30));
        expect(
          badge.size,
          Size.square(seal + 2 * KPublicProfile.founderSealRing),
        );
        // The thin ring: white on the light page.
        final ring = tester.widget<FounderBadge>(find.byType(FounderBadge));
        expect(ring.ring, const Color(0xFFFFFFFF));
        expect(ring.size, seal);
        // Nothing on the name's line or under it.
        final line = _r(tester, ProfileCoverHeader.nameLineKey);
        expect(badge.bottom, lessThanOrEqualTo(line.top));
        // The D293 rosette itself (one painter, no copied path) in the
        // brand red, and the white triangle drawn over it.
        final paint = tester.widget<CustomPaint>(
          find.descendant(
            of: find.byKey(FounderBadge.badgeKey),
            matching: find.byType(CustomPaint),
          ),
        );
        expect(
          paint.painter,
          isA<VerificationSealPainter>()
              .having((p) => p.fill, 'fill', KBrandColors.red500)
              .having((p) => p.rim, 'rim', isNull),
        );
        expect(
          paint.foregroundPainter,
          isA<FounderPlayPainter>().having(
            (p) => p.color,
            'color',
            const Color(0xFFFFFFFF),
          ),
        );
        expect(
          find.descendant(
            of: find.byKey(FounderBadge.badgeKey),
            matching: find.byType(Icon),
          ),
          findsNothing,
        );
        expect(
          tester.getSemantics(find.byKey(FounderBadge.badgeKey)),
          matchesSemantics(
            label: ar ? 'مؤسس Kabso Live' : 'Kabso Live founder',
            isImage: true,
          ),
        );
        // The blue seal is gone from his header (photo and name line).
        expect(find.byKey(ProfileCoverHeader.avatarBadgeKey), findsNothing);
        expect(
          find.descendant(
            of: find.byKey(ProfileCoverHeader.headerKey),
            matching: find.byType(ProfileVerificationBadge),
          ),
          findsNothing,
        );
        // The bio: centred, under the name, up to four lines.
        final bioFinder = find.byKey(ProfileCoverHeader.bioKey);
        final bio = tester.widget<Text>(bioFinder);
        expect(bio.textAlign, TextAlign.center);
        expect(bio.maxLines, KPublicProfile.ownerBioLines);
        expect(tester.getRect(bioFinder).top, greaterThan(name.bottom));
        // Only two numbers: followers and suggestions + complaints.
        final stats = find.byKey(ProfileScreen.statsKey);
        expect(
          find.descendant(of: stats, matching: find.byType(Expanded)),
          findsNWidgets(2),
        );
        expect(_statTexts(tester, ProfileHeaderView.followersKey), [
          '2.4M',
          if (ar) 'المتابِعون' else 'Followers',
        ]);
        expect(_statTexts(tester, ProfileCoverHeader.founderFeedbackKey), [
          '1.2K',
          if (ar) 'الاقتراحات والشكاوى' else 'Suggestions & complaints',
        ]);
        for (final key in [
          ProfileHeaderView.followingKey,
          ProfileCoverHeader.cherriesKey,
          ProfileCoverHeader.coinsKey,
        ]) {
          expect(find.byKey(key), findsNothing);
        }
        final followers = _r(tester, ProfileHeaderView.followersKey);
        final feedback = _r(tester, ProfileCoverHeader.founderFeedbackKey);
        expect(followers.top, feedback.top);
        expect(
          (followers.center.dx + feedback.center.dx) / 2,
          moreOrLessEquals(w / 2, epsilon: 1),
        );
        // Reading order: followers first (the reading start).
        expect(
          ar
              ? followers.center.dx > feedback.center.dx
              : followers.center.dx < feedback.center.dx,
          isTrue,
        );
        // The buttons under the numbers.
        final follow = _r(tester, OwnerVisitorActions.followKey);
        expect(follow.top, greaterThan(feedback.bottom));
        expect(find.byKey(OwnerVisitorActions.feedbackKey), findsOneWidget);
        await _end(tester);
      });

      testWidgets('no count from the server: a dash, never a made-up 0', (
        tester,
      ) async {
        await pumpOwnerVisitor(
          tester,
          language: language,
          profile: ownerProfile(ar: ar, feedbackCount: null),
        );
        expect(
          _statTexts(tester, ProfileCoverHeader.founderFeedbackKey).first,
          '–',
        );
        await _end(tester);
      });

      testWidgets('dark: the lighter brand red for the name', (tester) async {
        await pumpOwnerVisitor(
          tester,
          language: language,
          brightness: Brightness.dark,
        );
        final style = tester
            .widget<Text>(find.byKey(const Key('profile.displayName')))
            .style!;
        expect(style.color, KBrandColors.red400);
        // The seal's ring: the dark surface (never a white halo at night).
        expect(
          tester.widget<FounderBadge>(find.byType(FounderBadge)).ring,
          KPalette.dark.surface,
        );
        await _end(tester);
      });

      testWidgets("in a frame (live ring): the seal stays at the photo's "
          'bottom centre, ≥ 20 lp, clear of the name', (tester) async {
        await pumpOwnerVisitor(
          tester,
          language: language,
          profile: ownerProfile(ar: ar).copyWith(liveRoomId: 'room-1'),
        );
        expect(tester.takeException(), isNull);
        final photo = _r(tester, ProfileCoverHeader.photoKey);
        final badge = _r(tester, FounderBadge.badgeKey);
        final line = _r(tester, ProfileCoverHeader.nameLineKey);
        expect(badge.center.dx, moreOrLessEquals(photo.center.dx, epsilon: .5));
        final seal = tester.widget<FounderBadge>(find.byType(FounderBadge));
        expect(seal.size, greaterThanOrEqualTo(KPublicProfile.founderSealMin));
        expect(seal.size, KPublicProfile.founderSealFor(KProfile.avatar));
        // On the photo circle's bottom rim (inside the frame's box).
        final rim = photo.center.dy + KProfile.avatar / 2;
        expect(badge.top, lessThan(rim));
        expect(badge.bottom, greaterThan(rim));
        expect(badge.bottom, lessThanOrEqualTo(line.top));
        await _end(tester);
      });

      testWidgets('360 × 800 at text scale 1.3: nothing overflows', (
        tester,
      ) async {
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await pumpOwnerVisitor(
          tester,
          language: language,
          viewport: GoldenViewport.android,
        );
        expect(tester.takeException(), isNull);
        final photo = _r(tester, ProfileCoverHeader.photoKey);
        expect(photo.center.dx, moreOrLessEquals(180, epsilon: 0.5));
        for (final key in [
          ProfileHeaderView.followersKey,
          ProfileCoverHeader.founderFeedbackKey,
          OwnerVisitorActions.followKey,
          OwnerVisitorActions.feedbackKey,
          FounderBadge.badgeKey,
        ]) {
          final r = _r(tester, key);
          expect(r.left, greaterThanOrEqualTo(0), reason: '$key');
          expect(r.right, lessThanOrEqualTo(360), reason: '$key');
        }
        await _end(tester);
      });
    });

    testWidgets('founder own ${language.name}: centred, «تعديل الملف», the '
        'two numbers', (tester) async {
      await pumpOwnerOwn(tester, language: language);
      expect(tester.takeException(), isNull);
      final photo = _r(tester, ProfileCoverHeader.photoKey);
      expect(photo.center.dx, moreOrLessEquals(393 / 2, epsilon: 0.5));
      expect(find.byKey(FounderBadge.badgeKey), findsOneWidget);
      expect(find.byKey(ProfileScreen.editButtonKey), findsOneWidget);
      expect(find.byKey(ProfileCoverHeader.founderFeedbackKey), findsOneWidget);
      expect(find.byKey(ProfileHeaderView.followingKey), findsNothing);
      await _end(tester);
    });

    testWidgets('regular user ${language.name}: the D335 layout unchanged', (
      tester,
    ) async {
      await pumpOther(tester, d335Rich(ar: ar), language: language);
      final photo = _r(tester, ProfileCoverHeader.photoKey);
      const centre =
          KPublicProfile.avatarStart + KPublicProfile.avatarOuter / 2;
      expect(
        ar ? 393 - photo.center.dx : photo.center.dx,
        moreOrLessEquals(centre, epsilon: 0.5),
      );
      expect(find.byKey(FounderBadge.badgeKey), findsNothing);
      expect(find.byKey(ProfileCoverHeader.founderFeedbackKey), findsNothing);
      expect(find.byKey(ProfileHeaderView.followingKey), findsOneWidget);
      final style = tester
          .widget<Text>(find.byKey(const Key('profile.displayName')))
          .style!;
      expect(style.color, isNot(KBrandColors.red500));
      await _end(tester);
    });

    testWidgets('staff ${language.name}: the D335 layout unchanged', (
      tester,
    ) async {
      await pumpOther(tester, staffProfile(ar: ar), language: language);
      final photo = _r(tester, ProfileCoverHeader.photoKey);
      expect(photo.center.dx, isNot(moreOrLessEquals(393 / 2, epsilon: 4)));
      expect(find.byKey(FounderBadge.badgeKey), findsNothing);
      expect(find.byKey(ProfileHeaderView.followingKey), findsOneWidget);
      await _end(tester);
    });
  }

  group('D357 social row', () {
    test('the app-side link rules: phone numbers for WhatsApp, https else', () {
      expect(ProfileLinkRules.isWhatsAppNumber('+966 50 123 4567'), isTrue);
      expect(ProfileLinkRules.isWhatsAppNumber('00966501234567'), isTrue);
      expect(ProfileLinkRules.isWhatsAppNumber('0501234567'), isFalse);
      expect(ProfileLinkRules.isWhatsAppNumber('+1234567'), isFalse);
      expect(ProfileLinkRules.issue('+966 50 123 4567'), isNull);
      expect(
        ProfileLinkRules.issue('http://instagram.com/k'),
        'invalid_format',
      );
      expect(ProfileLinkRules.maxFounderLinks, 7);
      expect(
        ProfileLinkPlatform.fromWire('WHATSAPP'),
        ProfileLinkPlatform.whatsapp,
      );
      expect(
        ProfileLinkPlatform.fromWire('SNAPCHAT'),
        ProfileLinkPlatform.snapchat,
      );
      expect(ProfileLinkPlatform.snapchat.known, isTrue);
      for (final p in ProfileLinkRules.founderSocials) {
        final f = File(FounderSocialRow.assetOf(p));
        expect(f.existsSync(), isTrue, reason: f.path);
        // The unaltered Simple Icons file (one path, the 24-unit box).
        expect(f.readAsStringSync(), contains('viewBox="0 0 24 24"'));
      }
    });

    for (final language in AppLanguage.values) {
      final ar = language == AppLanguage.ar;
      testWidgets("${language.name}: all four under the bio, in the owner's "
          'order in both directions, 48 dp targets, spoken names', (
        tester,
      ) async {
        await pumpOwnerVisitor(tester, language: language);
        expect(tester.takeException(), isNull);
        final row = _r(tester, FounderSocialRow.rowKey);
        final bio = _r(tester, ProfileCoverHeader.bioKey);
        expect(row.top, greaterThan(bio.bottom));
        expect(row.center.dx, moreOrLessEquals(393 / 2, epsilon: 0.5));
        final order = [
          for (final p in ProfileLinkRules.founderSocials)
            _r(tester, FounderSocialRow.buttonKey(p)),
        ];
        for (var i = 1; i < order.length; i++) {
          // Left to right in Arabic too (the owner's list order).
          expect(order[i].left, greaterThan(order[i - 1].right));
        }
        for (final r in order) {
          expect(r.width, greaterThanOrEqualTo(48));
          expect(r.height, greaterThanOrEqualTo(48));
        }
        final names = ar
            ? ['إنستغرام', 'فيسبوك', 'واتساب', 'سناب شات']
            : ['Instagram', 'Facebook', 'WhatsApp', 'Snapchat'];
        for (final n in names) {
          expect(find.bySemanticsLabel(n), findsOneWidget, reason: n);
        }
        // The other link stays a chip; the four are not repeated as chips.
        final chips = tester.widget<ProfileLinksRow>(
          find.byType(ProfileLinksRow),
        );
        expect(chips.links.map((l) => l.id), ['l-web']);
        // The numbers are still under it all.
        expect(
          _r(tester, ProfileHeaderView.followersKey).top,
          greaterThan(row.bottom),
        );
        await _end(tester);
      });
    }

    testWidgets('a tap asks «أنت تغادر Kabso» first (D361), then opens the '
        'link outside the app; cancel opens nothing; a failure says so', (
      tester,
    ) async {
      final opener = _Opener();
      await pumpOwnerVisitor(
        tester,
        language: AppLanguage.ar,
        overrides: [externalLinkOpenerProvider.overrideWithValue(opener)],
      );
      for (final platform in ProfileLinkRules.founderSocials) {
        expect(platform.opensDirectly, isFalse, reason: platform.wire);
      }
      await tester.tap(
        find.byKey(FounderSocialRow.buttonKey(ProfileLinkPlatform.whatsapp)),
      );
      await tester.pumpAndSettle();
      // D361 (owner: D357's direct opening was not approved): the sheet.
      expect(find.byKey(ProfileLinkKeys.leavingSheet), findsOneWidget);
      expect(find.text('https://wa.me/966500000000'), findsWidgets);
      expect(opener.opened, isEmpty);
      await tester.tap(find.byKey(ProfileLinkKeys.leavingOpen));
      await tester.pumpAndSettle();
      expect(opener.opened, [Uri.parse('https://wa.me/966500000000')]);
      await tester.tap(
        find.byKey(FounderSocialRow.buttonKey(ProfileLinkPlatform.instagram)),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(ProfileLinkKeys.leavingSheet), findsOneWidget);
      await tester.tap(find.text('إلغاء').last);
      await tester.pumpAndSettle();
      expect(opener.opened, hasLength(1));
      opener.ok = false;
      await tester.tap(
        find.byKey(FounderSocialRow.buttonKey(ProfileLinkPlatform.snapchat)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ProfileLinkKeys.leavingOpen));
      await tester.pump();
      expect(opener.opened.last.host, 'www.snapchat.com');
      expect(find.text('تعذّر فتح الرابط'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 5));
      await _end(tester);
    });

    testWidgets('only the platforms he linked; none → no row', (tester) async {
      await pumpOwnerVisitor(
        tester,
        language: AppLanguage.en,
        profile: ownerProfile(
          ar: false,
          links: [
            for (final l in ownerSocialLinks)
              if (l.platform == ProfileLinkPlatform.whatsapp ||
                  l.platform == ProfileLinkPlatform.other)
                l,
          ],
        ),
      );
      expect(find.byKey(FounderSocialRow.rowKey), findsOneWidget);
      expect(
        find.byKey(FounderSocialRow.buttonKey(ProfileLinkPlatform.whatsapp)),
        findsOneWidget,
      );
      for (final p in [
        ProfileLinkPlatform.instagram,
        ProfileLinkPlatform.facebook,
        ProfileLinkPlatform.snapchat,
      ]) {
        expect(find.byKey(FounderSocialRow.buttonKey(p)), findsNothing);
      }
      await _end(tester);
      await pumpOwnerVisitor(
        tester,
        language: AppLanguage.en,
        profile: ownerProfile(ar: false, links: const []),
      );
      expect(tester.takeException(), isNull);
      expect(find.byKey(FounderSocialRow.rowKey), findsNothing);
      expect(find.byType(ProfileLinksRow), findsNothing);
      await _end(tester);
    });

    testWidgets('a regular user has no social row (his links stay chips)', (
      tester,
    ) async {
      await pumpOther(
        tester,
        d335Rich(ar: false).copyWith(links: ownerSocialLinks),
        language: AppLanguage.en,
      );
      expect(find.byKey(FounderSocialRow.rowKey), findsNothing);
      await _end(tester);
    });
  });

  final captureDir = Platform.environment['D357_CAPTURE_DIR'];
  group('D357 captures', skip: captureDir == null, () {
    Future<void> save(WidgetTester tester, Finder of, String name) async {
      await precacheImages(tester);
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final image = await captureImage(of.evaluate().first);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('${captureDir!}/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
      });
    }

    for (final (language, brightness) in [
      (AppLanguage.ar, Brightness.light),
      (AppLanguage.ar, Brightness.dark),
      (AppLanguage.en, Brightness.light),
    ]) {
      final tag = '${language.name}.${brightness.name}';
      testWidgets('visitor $tag', (tester) async {
        await pumpOwnerVisitor(
          tester,
          language: language,
          brightness: brightness,
        );
        await save(tester, find.byType(MaterialApp), 'founder.visitor.$tag');
        await _end(tester);
      });
      testWidgets('own $tag', (tester) async {
        await pumpOwnerOwn(tester, language: language, brightness: brightness);
        await save(tester, find.byType(MaterialApp), 'founder.own.$tag');
        await _end(tester);
      });
    }
    testWidgets('360 × 800 text 1.3 ar', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpOwnerVisitor(
        tester,
        language: AppLanguage.ar,
        viewport: GoldenViewport.android,
      );
      await save(tester, find.byType(MaterialApp), 'founder.360.text1.3.ar');
      await _end(tester);
    });
    for (final brightness in Brightness.values) {
      testWidgets('badge 4× ${brightness.name}', (tester) async {
        setViewport(tester, GoldenViewport.phone);
        const key = Key('zoom');
        final seal = KPublicProfile.founderSealFor(KPublicProfile.avatarOuter);
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            // The seal is symmetric and its play never mirrors: one locale.
            locale: const Locale('en'),
            home: Center(
              child: RepaintBoundary(
                key: key,
                child: ColoredBox(
                  color: brightness == Brightness.dark
                      ? KPalette.dark.background
                      : KPalette.light.background,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: FounderBadge(
                      size: seal * 4,
                      ring: brightness == Brightness.dark
                          ? KPalette.dark.surface
                          : const Color(0xFFFFFFFF),
                      ringWidth: KPublicProfile.founderSealRing * 4,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        // 4 × the badge as the phone draws it (@3x).
        await tester.runAsync(() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(key),
          );
          final image = await boundary.toImage(
            pixelRatio: GoldenViewport.pixelRatio,
          );
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('${captureDir!}/founder.badge.4x.${brightness.name}.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
        });
        await _end(tester);
      });
    }
  });
}
