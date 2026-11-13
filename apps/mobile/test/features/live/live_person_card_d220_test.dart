// D220 (owner 2026-11-01): the person card in a live, after the owner's
// reference (layout only): a compact sheet under the live, the picture over
// its top edge in the worn frame or a clean ring, «Report», the name and
// «ID: username», the badge pills, the four numbers (two hideable — the
// server leaves them out, the rest re-centre), the family/couple and gift
// wall pills, «+ Follow», the round gift and «Chat»; «Edit profile» on your
// own card. Arabic and English, 393×852 and 360×800 at text ×1.3, light and
// dark, long names, many badges, reduced motion.

import 'package:flutter_svga/flutter_svga.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/icons/kabso_art.dart';
import 'package:kabso_live/core/models/premium_tier.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/bag/domain/bag_models.dart';
import 'package:kabso_live/features/levels/application/levels_providers.dart';
import 'package:kabso_live/features/levels/domain/level_models.dart';
import 'package:kabso_live/features/live/live_room_screen.dart';
import 'package:kabso_live/features/live/presentation/widgets/kabso_team_badge.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_person_card.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_person_tools.dart';
import 'package:kabso_live/features/medals/domain/medal_models.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:kabso_live/features/profile/domain/profile_models.dart';
import 'package:kabso_live/features/profile/public_profile_screen.dart';
import 'package:kabso_live/features/profile_card/kabso_profile_header.dart';
import 'package:kabso_live/features/safety/safety_repository.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../helpers/fake_profile_repository.dart';
import '../../helpers/fake_safety_repository.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';
import '../bonds/bonds_harness.dart';

const _scope = LivePersonScope(roomId: 'room-0');

PublicProfile _profile({
  bool ar = false,
  bool self = false,
  int? cherries = 5830000,
  int? coins = 33200,
  String name = '',
  AvatarFrame? frame,
}) => apiProfile(ar: ar, isSelf: self, followerCount: 1510000).copyWith(
  displayName: name.isEmpty ? (ar ? 'سارة' : 'Sara') : name,
  followingCount: 59400,
  cherriesReceived: cherries,
  coinsSent: coins,
  avatarFrame: frame,
);

List<PublicLevel> _levels(int extra) => [
  PublicLevel(
    category: LevelCategory.attractiveness,
    name: 'Charm',
    level: LevelBrief(levelNumber: 32, name: 'x', requiredPoints: BigInt.zero),
  ),
  for (final (i, c) in [
    LevelCategory.support,
    LevelCategory.gaming,
    LevelCategory.wizard,
  ].indexed.take(extra))
    PublicLevel(
      category: c,
      name: c.name,
      level: LevelBrief(
        levelNumber: 10 + i,
        name: 'x',
        requiredPoints: BigInt.zero,
      ),
    ),
];

Future<BondFakes> _card(
  WidgetTester tester,
  PublicProfile profile, {
  AppLanguage language = AppLanguage.en,
  GoldenViewport viewport = GoldenViewport.phone,
  Brightness brightness = Brightness.light,
  LivePersonScope? scope = _scope,
  int levels = 1,
  KabsoProfileHeader? header,
  FakeSafetyRepository? safety,
}) async {
  setViewport(tester, viewport);
  await tester.pumpWidget(const SizedBox.shrink());
  final fakes = await pumpBonds(
    tester,
    Scaffold(
      backgroundColor: const Color(0xFF3A2A5A),
      body: Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () =>
                showHostSheet(context, 'host0', scope: scope, header: header),
            child: const Text('open'),
          ),
        ),
      ),
    ),
    language: language,
    brightness: brightness,
    overrides: [
      profileRepositoryProvider.overrideWithValue(
        FakeProfileRepository(profile),
      ),
      safetyRepositoryProvider.overrideWithValue(
        safety ?? FakeSafetyRepository(),
      ),
      profileLevelsProvider.overrideWith((ref, _) async => _levels(levels)),
    ],
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return fakes;
}

/// D220 (owner): the card's numbers are short Latin, isolated left to right.
String _ltr(String v) => '\u2066$v\u2069';

Finder _stat(LivePersonStat s) => find.byKey(LivePersonSheet.statKey(s));

void main() {
  final en = l10nFor(AppLanguage.en);

  group('D220 person card', () {
    testWidgets('four numbers in order, compact, with their labels', (
      tester,
    ) async {
      await _card(tester, _profile());
      for (final (stat, value, label) in [
        (LivePersonStat.followers, '1.5M', en.liveCardFollowers),
        (LivePersonStat.following, '59.4K', en.liveCardFollowing),
        (LivePersonStat.cherries, '5.8M', en.liveCardCherries),
        (LivePersonStat.coins, '33.2K', en.liveCardCoinsSent),
      ].map((e) => (e.$1, _ltr(e.$2), e.$3))) {
        expect(_stat(stat), findsOneWidget, reason: stat.name);
        expect(
          find.descendant(of: _stat(stat), matching: find.text(value)),
          findsOneWidget,
          reason: stat.name,
        );
        expect(
          find.descendant(of: _stat(stat), matching: find.text(label)),
          findsOneWidget,
          reason: stat.name,
        );
      }
      final xs = <double>[
        for (final s in LivePersonStat.values) tester.getCenter(_stat(s)).dx,
      ];
      expect(xs, orderedEquals(List<double>.of(xs)..sort()));
    });

    for (final (hidden, count) in [
      ((cherries: true, coins: false), 3),
      ((cherries: false, coins: true), 3),
      ((cherries: true, coins: true), 2),
    ]) {
      testWidgets('hidden by the person (cherries ${hidden.cherries}, coins '
          '${hidden.coins}): $count numbers, spread evenly', (tester) async {
        await _card(
          tester,
          _profile(
            cherries: hidden.cherries ? null : 1,
            coins: hidden.coins ? null : 2,
          ),
        );
        final shown = [
          for (final s in LivePersonStat.values)
            if (_stat(s).evaluate().isNotEmpty) s,
        ];
        expect(shown, hasLength(count));
        expect(
          _stat(LivePersonStat.cherries).evaluate().isEmpty,
          hidden.cherries,
        );
        expect(_stat(LivePersonStat.coins).evaluate().isEmpty, hidden.coins);
        // A thin divider only between the numbers shown.
        expect(
          find.byWidgetPredicate(
            (w) =>
                w.key is ValueKey<String> &&
                (w.key! as ValueKey<String>).value.startsWith(
                  'room.userCard.statDivider.',
                ),
          ),
          findsNWidgets(count - 1),
        );
        // Equal cells across the row, centred under the card.
        final rects = [for (final s in shown) tester.getRect(_stat(s))];
        final width = rects.first.width;
        for (final r in rects) {
          expect(r.width, closeTo(width, 0.5));
        }
        final row = tester.getRect(find.byKey(LivePersonSheet.statsKey));
        final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
        expect(row.center.dx, closeTo(screen.width / 2, 0.5));
      });
    }

    testWidgets('Arabic: the numbers read from the right, followers first', (
      tester,
    ) async {
      await _card(tester, _profile(ar: true), language: AppLanguage.ar);
      final xs = <double>[
        for (final s in LivePersonStat.values) tester.getCenter(_stat(s)).dx,
      ];
      expect(
        xs,
        orderedEquals(List<double>.of(xs)..sort((a, b) => b.compareTo(a))),
      );
      // «إبلاغ» at the reading start (the right).
      final report = tester.getCenter(
        find.byKey(LivePersonToolKeys.reportQuick),
      );
      final picture = tester.getCenter(
        find.byKey(const Key('room.userCard.profile')),
      );
      expect(report.dx, greaterThan(picture.dx));
    });

    testWidgets('the name and «ID: username» sit under the picture, which '
        'overlaps the top edge', (tester) async {
      await _card(tester, _profile());
      final sheet = tester.getRect(find.byKey(LivePersonSheet.sheetKey));
      final picture = tester.getRect(find.byKey(LivePersonSheet.ringKey));
      final name = tester.getRect(find.byKey(LivePersonSheet.nameKey));
      expect(
        find.text(en.liveCardId(KFormat.bidiIsolate('host0'))),
        findsOneWidget,
      );
      expect(picture.top, closeTo(sheet.top, 0.5));
      // D383 (owner: «لا يتجاوز منها البطاقة سوى قليلاً»): the sheet's white
      // starts near the circle's top — only 18 % of it above the card.
      final white = tester.getRect(
        find
            .descendant(
              of: find.byKey(LivePersonSheet.sheetKey),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect(
        white.top - picture.top,
        closeTo(picture.height * LivePersonCardMetrics.poke, 0.5),
      );
      expect(white.top, lessThan(picture.center.dy));
      expect(name.top, greaterThan(picture.bottom));
      expect(name.center.dx, closeTo(picture.center.dx, 1));
    });

    testWidgets('no frame: a clean white ring; a worn bag frame is drawn '
        'around the picture instead', (tester) async {
      await _card(tester, _profile());
      expect(find.byKey(LivePersonSheet.ringKey), findsOneWidget);
      expect(find.byKey(LivePersonSheet.bagFrameKey), findsNothing);
      await _card(
        tester,
        _profile(
          frame: const AvatarFrame(
            code: 'host_frame_pink',
            assetKey: 'host_frame_pink',
          ),
        ),
      );
      expect(find.byKey(LivePersonSheet.bagFrameKey), findsOneWidget);
      expect(find.byKey(LivePersonSheet.ringKey), findsNothing);
      // A frame this app has no art for: the ring.
      await _card(
        tester,
        _profile(
          frame: const AvatarFrame(code: 'future', assetKey: 'future_frame'),
        ),
      );
      expect(find.byKey(LivePersonSheet.ringKey), findsOneWidget);
    });

    testWidgets('the recharge-agent frame wins over the bag frame', (
      tester,
    ) async {
      await _card(
        tester,
        _profile(
          frame: const AvatarFrame(
            code: 'host_frame_blue',
            assetKey: 'host_frame_blue',
          ),
        ).copyWith(rechargeAgentCode: 'K7Q2'),
      );
      expect(find.byKey(LivePersonSheet.agentFrameKey), findsOneWidget);
      expect(find.byKey(LivePersonSheet.bagFrameKey), findsNothing);
    });

    testWidgets('«Report» asks for a reason and reports the person', (
      tester,
    ) async {
      final safety = FakeSafetyRepository();
      await _card(tester, _profile(), safety: safety);
      await tester.tap(find.byKey(LivePersonToolKeys.reportQuick));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('feed.post.report.spam')));
      await tester.pumpAndSettle();
      expect(safety.calls, ['reportUser:user-0:SPAM']);
      // ⋯ keeps report and block.
      expect(find.byKey(LivePersonToolKeys.more), findsOneWidget);
    });

    testWidgets('your own card: «Edit profile», your numbers, no follow, '
        'chat, gift or report', (tester) async {
      final fakes = await _card(
        tester,
        _profile(self: true),
        scope: LivePersonScope(roomId: 'room-0', onGift: (_) {}),
      );
      for (final k in [
        LivePersonSheet.followKey,
        LivePersonSheet.messageKey,
        LivePersonSheet.giftKey,
        LivePersonToolKeys.reportQuick,
      ]) {
        expect(find.byKey(k), findsNothing, reason: '$k');
      }
      expect(_stat(LivePersonStat.cherries), findsOneWidget);
      expect(_stat(LivePersonStat.coins), findsOneWidget);
      await tester.tap(find.byKey(LivePersonSheet.editKey));
      await tester.pumpAndSettle();
      expect(fakes.visited, ['/profile/edit']);
    });

    testWidgets('Chat opens the conversation; the name opens the profile', (
      tester,
    ) async {
      var fakes = await _card(tester, _profile());
      await tester.tap(find.byKey(LivePersonSheet.messageKey));
      await tester.pumpAndSettle();
      expect(fakes.visited, ['/messages/host0']);
      fakes = await _card(tester, _profile());
      await tester.tap(find.byKey(LivePersonSheet.nameKey));
      await tester.pumpAndSettle();
      expect(fakes.visited, ['/users/host0']);
    });

    testWidgets('the round gift opens the gift panel for this person', (
      tester,
    ) async {
      LiveGiftPreselectSeen? seen;
      await _card(
        tester,
        _profile(),
        scope: LivePersonScope(
          roomId: 'room-0',
          onGift: (p) => seen = (username: p.username, name: p.name),
        ),
      );
      final gift = find.byKey(LivePersonSheet.giftKey);
      // Owner: the app's main gift icon (the live bar's), not a new art.
      expect(
        tester
            .widget<KabsoArtIcon>(
              find.descendant(of: gift, matching: find.byType(KabsoArtIcon)),
            )
            .art,
        KabsoArt.mainGift,
      );
      // Owner: inside a circle as high as Follow / Chat, art ≈ 62 %.
      final circle = tester.widget<Container>(
        find.descendant(of: gift, matching: find.byType(Container)).first,
      );
      final deco = circle.decoration! as BoxDecoration;
      expect(deco.shape, BoxShape.circle);
      expect(deco.border, isNotNull);
      expect(deco.color, isNotNull);
      final art = tester.getSize(
        find.descendant(of: gift, matching: find.byType(KabsoArtIcon)),
      );
      final ring = tester.getSize(gift);
      expect(art.width / ring.width, inInclusiveRange(0.58, 0.68));
      expect(
        ring.height,
        closeTo(
          tester.getSize(find.byKey(LivePersonSheet.messageKey)).height,
          0.5,
        ),
      );
      final size = tester.getSize(gift);
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
      await tester.tap(gift);
      await tester.pumpAndSettle();
      expect(seen, (username: 'host0', name: 'Sara'));
      expect(find.byKey(LivePersonSheet.sheetKey), findsNothing);
    });

    testWidgets('light: a white sheet; dark: the app surface', (tester) async {
      Color sheet() {
        final box = tester.widget<Container>(
          find
              .descendant(
                of: find.byKey(LivePersonSheet.sheetKey),
                matching: find.byType(Container),
              )
              .first,
        );
        return (box.decoration! as BoxDecoration).color!;
      }

      await _card(tester, _profile());
      expect(sheet(), const Color(0xFFFFFFFF));
      await _card(tester, _profile(), brightness: Brightness.dark);
      expect(sheet(), isNot(const Color(0xFFFFFFFF)));
    });

    for (final language in AppLanguage.values) {
      for (final viewport in GoldenViewport.values) {
        testWidgets('${language.name} ${viewport.name} ×1.3: a long name, '
            'many badges, a premium ID, a frame — nothing overflows', (
          tester,
        ) async {
          tester.platformDispatcher.textScaleFactorTestValue = 1.3;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final ar = language == AppLanguage.ar;
          await _card(
            tester,
            _profile(
              ar: ar,
              name: ar
                  ? 'سارة عبد الرحمن الهاشمية من مدينة الإسكندرية الجميلة'
                  : 'Sara Abdulrahman Al-Hashimi from beautiful Alexandria',
              frame: const AvatarFrame(
                code: 'host_frame_pink',
                assetKey: 'host_frame_pink',
              ),
            ).copyWith(
              premiumTier: PremiumTier.gold,
              medals: ProfileMedals(
                owned: 6,
                total: 9,
                showcase: [
                  for (final c in ['A', 'B', 'C', 'D', 'E', 'F'])
                    ProfileMedal(code: c, name: c, iconKey: 'medal_$c'),
                ],
              ),
            ),
            language: language,
            viewport: viewport,
            levels: 3,
            scope: const LivePersonScope(
              roomId: 'room-0',
              viewer: LivePersonRole.host,
              target: LivePersonRole.moderator,
            ),
          );
          expect(tester.takeException(), isNull);
          // The name keeps one line with an ellipsis at its end.
          final name = tester.widget<Text>(
            find.descendant(
              of: find.byKey(LivePersonSheet.nameKey),
              matching: find.byType(Text),
            ),
          );
          expect(name.maxLines, 1);
          expect(name.overflow, TextOverflow.ellipsis);
          // Every part of the card is reachable (it scrolls with large
          // text) and inside the screen's width.
          final screen =
              tester.view.physicalSize / tester.view.devicePixelRatio;
          for (final k in [
            LivePersonSheet.badgesKey,
            LivePersonSheet.statsKey,
            LivePersonSheet.followKey,
            LivePersonSheet.messageKey,
          ]) {
            await tester.ensureVisible(find.byKey(k));
            await tester.pumpAndSettle();
            final r = tester.getRect(find.byKey(k));
            expect(r.left, greaterThanOrEqualTo(0), reason: '$k');
            expect(r.right, lessThanOrEqualTo(screen.width), reason: '$k');
          }
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('reduced motion: the profile card header stays still', (
      tester,
    ) async {
      // D383: hidden pending the owner's decision; the dormant feature.
      kabsoProfileHeadersHidden = false;
      addTearDown(() => kabsoProfileHeadersHidden = true);
      final animate = KabsoProfileHeaderArt.animate;
      KabsoProfileHeaderArt.animate = true;
      addTearDown(() => KabsoProfileHeaderArt.animate = animate);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await _card(
        tester,
        _profile().copyWith(
          profileCard: const ProfileCard(
            code: 'emerald_wings',
            assetKey: 'header_emerald_wings',
          ),
        ),
      );
      expect(find.byKey(const Key('room.userCard.header')), findsOneWidget);
      expect(find.byType(SVGAImage), findsNothing);
      expect(tester.takeException(), isNull);
      // The picture stays above the sheet with the header behind it.
      expect(find.byKey(LivePersonSheet.ringKey), findsOneWidget);
    });

    testWidgets('Arabic: short Latin numbers (no «مليون» / «ألف»), smaller '
        'than the name, grey dividers between them', (tester) async {
      await _card(tester, _profile(ar: true), language: AppLanguage.ar);
      for (final v in ['1.5M', '59.4K', '5.8M', '33.2K']) {
        expect(find.text(_ltr(v)), findsOneWidget, reason: v);
      }
      expect(find.textContaining('مليون'), findsNothing);
      expect(find.textContaining('ألف'), findsNothing);
      final number = tester.widget<Text>(
        find.descendant(
          of: _stat(LivePersonStat.followers),
          matching: find.text(_ltr('1.5M')),
        ),
      );
      expect(number.style!.fontSize, 17);
      final dividers = [
        for (var i = 1; i < 4; i++)
          find.byKey(LivePersonSheet.statDividerKey(i)),
      ];
      final row = tester.getRect(find.byKey(LivePersonSheet.statsKey));
      for (final d in dividers) {
        final r = tester.getRect(d);
        expect(r.width, 1);
        expect(r.height, lessThan(row.height * 0.75));
        expect(r.center.dy, closeTo(row.center.dy, 0.5));
        // Between two numbers.
      }
      // Each divider sits between its two neighbours (RTL: right to left).
      final f = tester.getCenter(_stat(LivePersonStat.followers)).dx;
      final g = tester.getCenter(_stat(LivePersonStat.following)).dx;
      final d1 = tester.getCenter(dividers.first).dx;
      expect(d1, lessThan(f));
      expect(d1, greaterThan(g));
    });

    testWidgets('dividers follow the theme token (light and dark)', (
      tester,
    ) async {
      Color line() => tester
          .widget<Container>(find.byKey(LivePersonSheet.statDividerKey(1)))
          .color!;
      await _card(tester, _profile());
      final light = line();
      await _card(tester, _profile(), brightness: Brightness.dark);
      final dark = line();
      expect(light, isNot(dark));
      expect(light.a, 1);
      // Owner: a little more visible in dark mode than the plain border.
      final context = tester.element(find.byKey(LivePersonSheet.statsKey));
      expect(
        dark.computeLuminance(),
        greaterThan(context.palette.border.computeLuminance()),
      );
    });

    testWidgets('owner: «+ Follow» is filled brand red with white text '
        '(≥ 4.5:1); followed, a neutral outline «Unfollow»', (tester) async {
      BoxDecoration pill() =>
          tester
                  .widget<DecoratedBox>(
                    find
                        .descendant(
                          of: find.byKey(LivePersonSheet.followKey),
                          matching: find.byType(DecoratedBox),
                        )
                        .first,
                  )
                  .decoration
              as BoxDecoration;
      Color label(String text) => tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(LivePersonSheet.followKey),
              matching: find.text(text),
            ),
          )
          .style!
          .color!;
      for (final brightness in Brightness.values) {
        await _card(tester, _profile(), brightness: brightness);
        final context = tester.element(find.byKey(LivePersonSheet.followKey));
        final red = context.palette.primary;
        expect(pill().color, red);
        // The theme's brand red (`primary`: #E50914 dark, #C8080F light).
        expect(
          red,
          brightness == Brightness.dark
              ? KBrandColors.red500
              : const Color(0xFFC8080F),
        );
        final white = label(en.liveCardFollow);
        expect(white, context.palette.onPrimary);
        double lum(Color c) => c.computeLuminance();
        final ratio = (lum(white) + 0.05) / (lum(red) + 0.05);
        expect(ratio, greaterThanOrEqualTo(4.5), reason: '$brightness');
      }
      await _card(tester, _profile().copyWith(isFollowing: true));
      expect(pill().color, isNull);
      expect(pill().border, isNotNull);
      expect(
        label(en.liveCardUnfollow),
        isNot(
          tester.element(find.byKey(LivePersonSheet.followKey)).palette.primary,
        ),
      );
    });

    testWidgets('followed: «Unfollow» asks, then unfollows; cancelling keeps '
        'the follow', (tester) async {
      final profiles = FakeProfileRepository(
        _profile().copyWith(isFollowing: true),
      );
      setViewport(tester, GoldenViewport.phone);
      await pumpBonds(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => showHostSheet(context, 'host0', scope: _scope),
                child: const Text('open'),
              ),
            ),
          ),
        ),
        brightness: Brightness.light,
        overrides: [
          profileRepositoryProvider.overrideWithValue(profiles),
          safetyRepositoryProvider.overrideWithValue(FakeSafetyRepository()),
          profileLevelsProvider.overrideWith((ref, _) async => _levels(1)),
        ],
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final follow = find.byKey(LivePersonSheet.followKey);
      await tester.tap(follow);
      await tester.pumpAndSettle();
      expect(find.text(en.profileUnfollowConfirm('Sara')), findsOneWidget);
      // Dismissed: nothing sent.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(profiles.calls.where((c) => c.startsWith('DELETE')), isEmpty);
      await tester.tap(follow);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(PublicProfileScreen.unfollowKey));
      await tester.pumpAndSettle();
      expect(profiles.calls.last, 'DELETE host0');
      expect(
        find.descendant(of: follow, matching: find.text(en.liveCardFollow)),
        findsOneWidget,
      );
    });

    testWidgets('semantics: each number is read with its label', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _card(tester, _profile());
      expect(
        find.bySemanticsLabel('${en.liveCardCherries} ${_ltr('5.8M')}'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(en.liveCardSendGift), findsNothing);
      handle.dispose();
    });

    // D218 × D220 (int9): PublicProfile.country and blockedByMe on the card.
    testWidgets('the country flag sits before «ID: username»; none without '
        'a country', (tester) async {
      final handle = tester.ensureSemantics();
      await _card(tester, _profile().copyWith(country: 'JO'));
      final flag = find.byKey(LivePersonSheet.countryKey);
      expect(flag, findsOneWidget);
      expect(tester.widget<Text>(flag).data, '\u{1F1EF}\u{1F1F4}');
      // Read inside the copy button's merged label.
      expect(find.bySemanticsLabel(RegExp('Jordan')), findsOneWidget);
      expect(
        tester.getCenter(flag).dx,
        lessThan(tester.getCenter(find.byKey(LivePersonSheet.copyKey)).dx),
      );
      handle.dispose();
      await _card(tester, _profile());
      expect(find.byKey(LivePersonSheet.countryKey), findsNothing);
    });

    testWidgets("someone you blocked: «Unblock» in Follow's place unblocks", (
      tester,
    ) async {
      final safety = FakeSafetyRepository();
      final profile = _profile().copyWith(blockedByMe: true, isFollowing: true);
      await _card(tester, profile, safety: safety);
      expect(find.byKey(LivePersonSheet.followKey), findsNothing);
      final unblock = find.byKey(LivePersonSheet.unblockKey);
      expect(
        find.descendant(of: unblock, matching: find.text(en.safetyUnblock)),
        findsOneWidget,
      );
      await tester.tap(unblock);
      await tester.pumpAndSettle();
      expect(safety.calls, contains('block:${profile.username}:false'));
      expect(
        find.text(en.safetyUnblocked(profile.displayName)),
        findsOneWidget,
      );
    });
  });

  // D282: a staff account's card wears the Kabso Team badge after the name,
  // the name in the phone's language; nothing overflows at 360 × 1.3.
  group('D282 the Kabso Team badge', () {
    for (final language in AppLanguage.values) {
      testWidgets('${language.name} android ×1.3: a long staff name', (
        tester,
      ) async {
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final ar = language == AppLanguage.ar;
        await _card(
          tester,
          _profile(
            ar: ar,
            name: ar
                ? 'سارة عبد الرحمن الهاشمية من الإسكندرية'
                : 'Sara Abdulrahman Al-Hashimi of Alexandria',
          ).copyWith(kabsoTeam: true),
          language: language,
          viewport: GoldenViewport.android,
        );
        expect(tester.takeException(), isNull);
        final badge = find.byKey(KabsoTeamBadge.badgeKey);
        expect(badge, findsOneWidget);
        // D299i: taller than the name's line, so its name reads.
        expect(tester.getSize(badge).height, KabsoTeamBadge.cardHeight);
        final name = tester.getRect(find.byKey(LivePersonSheet.nameKey));
        final b = tester.getRect(badge);
        // After the name in the reading direction, inside the screen.
        if (ar) {
          expect(b.right, lessThanOrEqualTo(name.left));
        } else {
          expect(b.left, greaterThanOrEqualTo(name.right));
        }
        expect(b.left, greaterThanOrEqualTo(0));
        expect(b.right, lessThanOrEqualTo(360));
        // D389: the crest alone, its name spoken (not written on it).
        expect(
          find.bySemanticsLabel(l10nFor(language).liveKabsoTeam),
          findsOneWidget,
        );
      });

      testWidgets('live_person_card_staff (${language.name})', (tester) async {
        await loadAppFonts();
        await _card(
          tester,
          _profile(ar: language == AppLanguage.ar).copyWith(kabsoTeam: true),
          language: language,
        );
        await precacheImages(tester);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            '../../goldens/png/live_person_card_staff_d282.${language.name}'
            '.phone.png',
          ),
        );
      }, tags: goldenTag);
    }

    testWidgets('a viewer is not badged', (tester) async {
      await _card(tester, _profile());
      expect(find.byKey(KabsoTeamBadge.badgeKey), findsNothing);
    });
  });
}

/// What the gift button handed to the panel.
typedef LiveGiftPreselectSeen = ({String username, String name});
