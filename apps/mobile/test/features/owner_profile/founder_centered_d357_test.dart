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
//    of the check («مؤسس Kabso Live»), the size of the seal beside a name,
//    centred under the name; the blue seal gone (photo and name line);
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
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/owner_profile/presentation/founder_badge.dart';
import 'package:kabso_live/features/owner_profile/presentation/owner_actions.dart';
import 'package:kabso_live/features/owner_profile/presentation/owner_cover_video.dart';
import 'package:kabso_live/features/profile/profile_cover_header.dart';
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
        // The badge: centred under the name, read as the founder, the size
        // of the D293 seal beside a name of the same font (28 lp for 24 pt).
        final badge = _r(tester, FounderBadge.badgeKey);
        expect(badge.center.dx, moreOrLessEquals(w / 2, epsilon: 0.5));
        expect(badge.top, greaterThanOrEqualTo(name.bottom));
        final seal = ProfileVerificationBadge.sizeForFont(
          KPublicProfile.founderNameFont,
        );
        expect(seal, 28);
        expect(badge.size, Size.square(seal));
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
        // The bio: centred, under the badge, up to four lines.
        final bioFinder = find.byKey(ProfileCoverHeader.bioKey);
        final bio = tester.widget<Text>(bioFinder);
        expect(bio.textAlign, TextAlign.center);
        expect(bio.maxLines, KPublicProfile.ownerBioLines);
        expect(tester.getRect(bioFinder).top, greaterThan(badge.bottom));
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
        final seal = ProfileVerificationBadge.sizeForFont(
          KPublicProfile.founderNameFont,
        );
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
                    child: FounderBadge(size: seal * 4),
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
