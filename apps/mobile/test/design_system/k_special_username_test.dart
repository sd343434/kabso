// D146: the owner's special-ID badge as `KSpecialUsername` — one medal and
// plate per tier (LEGEND, RUBY, GOLD, SILVER) with the username (no «@»,
// D158), the light
// sweep only when motion is on (never in tests, never with reduced motion),
// left-to-right in Arabic too, screen reader label, tap.
// D299j: every tier is the owner's art — a stretchable plate whose
// shortest length is for the owner's count of characters (LEGEND 3, RUBY 4,
// GOLD 5, SILVER 6), the ID centred in the visible glass.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/models/premium_tier.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/components/k_special_username.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/component_harness.dart';

void main() {
  for (final tier in PremiumTier.values) {
    testWidgets('$tier: its medal over its plate (D299j)', (tester) async {
      await pumpComponent(
        tester,
        Center(
          child: KSpecialUsername(username: '777', tier: tier),
        ),
      );
      final image = tester.widget<Image>(find.byKey(KSpecialUsername.medalKey));
      expect(
        (image.image as AssetImage).assetName,
        'assets/special_id/${tier.name}_medal.png',
      );
      // The plate's slices: the two ends, the gem and the two arcs (GOLD and
      // SILVER, whose shortest plate is for five and six characters, add
      // plain fills).
      final slices = [
        for (final i in tester.widgetList<Image>(
          find.descendant(
            of: find.byKey(KSpecialUsername.plateKey),
            matching: find.byType(Image),
          ),
        ))
          (i.image as AssetImage).assetName,
      ];
      expect(
        slices.toSet(),
        containsAll(<String>{
          for (final part in [
            'wing_left',
            'wing_right',
            'left',
            'gem',
            'right',
          ])
            'assets/special_id/${tier.name}_plate_$part.png',
        }),
      );
      // The medal over the plate's left end.
      final medal = tester.getRect(find.byKey(KSpecialUsername.medalKey));
      final plate = tester.getRect(find.byKey(KSpecialUsername.plateKey));
      expect(medal.left, lessThan(plate.left));
      expect(medal.right, greaterThan(plate.left));
      // D299k: the medal reaches over the plate's glass (no gap).
      final g = KSpecialUsername.geometry('777', tier, 22);
      final badge = tester.getTopLeft(find.byType(KSpecialUsername));
      expect(medal.right - badge.dx, moreOrLessEquals(g.medalRight));
      expect(medal.right - badge.dx, greaterThan(g.glassEnd));
      expect(
        tester.getSize(find.byType(KSpecialUsername)),
        KSpecialUsername.measure('777', tier, 22),
      );
      expect(tester.takeException(), isNull);
    });
  }

  test('the four tiers have their own art', () {
    expect(PremiumTier.values.map(kSpecialUsernameMedal).toSet(), hasLength(4));
    expect(PremiumTier.fromWire('LEGEND'), PremiumTier.legend);
    expect(PremiumTier.fromWire('DIAMOND'), isNull);
  });

  testWidgets('no endless animation in tests or with reduced motion', (
    tester,
  ) async {
    // The test setup turns the sweep off globally.
    expect(KSpecialUsername.motion, isFalse);
    await pumpComponent(
      tester,
      const Center(
        child: KSpecialUsername(username: 'ab', tier: PremiumTier.legend),
      ),
      disableAnimations: false,
    );
    expect(tester.hasRunningAnimations, isFalse);

    KSpecialUsername.motion = true;
    addTearDown(() => KSpecialUsername.motion = false);
    await pumpComponent(
      tester,
      const Center(
        child: KSpecialUsername(username: 'ab', tier: PremiumTier.legend),
      ),
      disableAnimations: false,
    );
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pump(const Duration(milliseconds: 700));
    expect(tester.takeException(), isNull);

    // Reduced motion and animate: false stop it.
    await pumpComponent(
      tester,
      const Center(
        child: KSpecialUsername(username: 'ab', tier: PremiumTier.legend),
      ),
    );
    // A finite transition of the app around it ends first.
    await tester.pump(const Duration(seconds: 3));
    expect(tester.hasRunningAnimations, isFalse);
    await pumpComponent(
      tester,
      const Center(
        child: KSpecialUsername(
          username: 'ab',
          tier: PremiumTier.gold,
          animate: false,
        ),
      ),
      disableAnimations: false,
    );
    await tester.pump(const Duration(seconds: 3));
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('Arabic: still the name left to right, no «@»; label; tap', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    var taps = 0;
    await pumpComponent(
      tester,
      Center(
        child: KSpecialUsername(
          username: 'layla',
          tier: PremiumTier.gold,
          onTap: () => taps++,
        ),
      ),
      language: AppLanguage.ar,
    );
    // D158: a premium username is read without «@».
    expect(find.bySemanticsLabel('layla'), findsOneWidget);
    expect(find.bySemanticsLabel('@layla'), findsNothing);
    final dir = tester.widget<Directionality>(
      find
          .descendant(
            of: find.byType(KSpecialUsername),
            matching: find.byType(Directionality),
          )
          .first,
    );
    expect(dir.textDirection, TextDirection.ltr);
    await tester.tap(find.byType(KSpecialUsername));
    expect(taps, 1);
    handle.dispose();
  });

  test('longer names make a wider badge; taller badges a bigger medal', () {
    final short = KSpecialUsername.measure('7', PremiumTier.legend, 22);
    final long = KSpecialUsername.measure('7777777', PremiumTier.ruby, 22);
    final tall = KSpecialUsername.measure('7', PremiumTier.legend, 30);
    expect(long.width, greaterThan(short.width));
    expect(tall.height, greaterThan(short.height));
  });

  // D299j (owner: «… بتصغير الشريط بحيث يتسع لثلاث مقاطع» for LEGEND, four
  // for RUBY, five for GOLD, six or more for SILVER).
  group('D299j: the stretchable plate', () {
    const counts = {
      PremiumTier.legend: 3,
      PremiumTier.ruby: 4,
      PremiumTier.gold: 5,
      PremiumTier.silver: 6,
    };
    for (final MapEntry(key: tier, value: n) in counts.entries) {
      test('$tier: the shortest plate holds $n characters; longer IDs '
          'widen it', () {
        expect(KSpecialUsername.shortestFor(tier), n);
        for (final h in [15.0, 18.0, 22.0, 30.0]) {
          final one = KSpecialUsername.geometry('7', tier, h);
          final fit = KSpecialUsername.geometry('W' * n, tier, h);
          final digits = KSpecialUsername.geometry('0' * n, tier, h);
          final long = KSpecialUsername.geometry('kingofthenight', tier, h);
          // n digits share the one-character plate: the shortest.
          expect(digits.plateWidth, moreOrLessEquals(one.plateWidth));
          // One character more than the owner's count widens it, unless the
          // art's own ends already leave room (LEGEND, RUBY).
          if (tier == PremiumTier.gold || tier == PremiumTier.silver) {
            expect(
              KSpecialUsername.geometry('0' * (n + 1), tier, h).plateWidth,
              greaterThan(one.plateWidth),
            );
          }
          expect(long.plateWidth, greaterThan(one.plateWidth));
          expect(fit.plateWidth, greaterThanOrEqualTo(one.plateWidth));
          for (final g in [one, fit, digits, long]) {
            // D299k: no gap — the medal's right edge lies over the plate's
            // glass (its curled left end hidden under the medal) …
            expect(g.medalRight, greaterThan(g.glassEnd));
            expect(g.glass.left, greaterThanOrEqualTo(g.medalRight - 1e-9));
            // … and the ID inside the visible glass, never under the medal.
            expect(g.nameLeft, greaterThan(g.medalRight));
            expect(g.nameLeft, greaterThanOrEqualTo(g.glass.left));
            expect(
              g.nameLeft + g.nameWidth,
              lessThanOrEqualTo(g.glass.right + .01),
            );
          }
          // The shortest plate is short: the ID's own width plus the ends
          // (D299k: 3.4 × the badge's height, was 3.2 — the glass now starts
          // after the medal, so SILVER's six characters need a little more).
          expect(
            one.plateWidth,
            lessThan(KSpecialUsername.measure('7', tier, h).height * 3.4),
          );
        }
      });
    }

    testWidgets('a long ID: the plain fills widen the plate, the slices '
        'join without a gap', (tester) async {
      for (final tier in PremiumTier.values) {
        await pumpComponent(
          tester,
          Center(
            child: KSpecialUsername(username: 'kingofthenight', tier: tier),
          ),
        );
        expect(tester.takeException(), isNull);
        final plate = find.byKey(KSpecialUsername.plateKey);
        final rects = [
          for (final e
              in find
                  .descendant(of: plate, matching: find.byType(Image))
                  .evaluate())
            tester.getRect(find.byWidget(e.widget)),
        ]..sort((a, b) => a.left.compareTo(b.left));
        expect(rects, hasLength(7), reason: '$tier');
        for (var i = 1; i < rects.length; i++) {
          expect(
            rects[i].left,
            lessThanOrEqualTo(rects[i - 1].right + .01),
            reason: '$tier slice $i',
          );
        }
        expect(rects.first.left, tester.getRect(plate).left);
        expect(
          rects.map((r) => r.right).reduce(math.max),
          moreOrLessEquals(tester.getRect(plate).right),
        );
      }
    });
  });

  // D299l (owner-approved motion, escalating by tier; the full set only
  // where the ID is prominent).
  group('D299l: the motion per tier', () {
    test('the sweep every 4 / 3 / 2.5 / 2 s; a loop is three sweeps', () {
      expect(
        {
          for (final t in PremiumTier.values)
            t: KSpecialUsername.sweepPeriod(t),
        },
        {
          PremiumTier.silver: const Duration(milliseconds: 4000),
          PremiumTier.gold: const Duration(milliseconds: 3000),
          PremiumTier.ruby: const Duration(milliseconds: 2500),
          PremiumTier.legend: const Duration(milliseconds: 2000),
        },
      );
      for (final t in PremiumTier.values) {
        expect(KSpecialUsername.loop(t), KSpecialUsername.sweepPeriod(t) * 3);
      }
      // Lists and chat lines get only the sweep unless asked.
      expect(
        const KSpecialUsername(username: 'a', tier: PremiumTier.legend).effects,
        KSpecialIdEffects.sweepOnly,
      );
    });

    Future<void> pumpBadge(
      WidgetTester tester,
      PremiumTier tier,
      KSpecialIdEffects effects, {
      bool reduceMotion = false,
    }) => pumpComponent(
      tester,
      Center(
        child: KSpecialUsername(
          username: 'kabso',
          tier: tier,
          height: 30,
          effects: effects,
        ),
      ),
      disableAnimations: reduceMotion,
    );

    for (final tier in PremiumTier.values) {
      testWidgets('$tier: the layers at full and sweep-only; reduced motion '
          'keeps it still', (tester) async {
        KSpecialUsername.motion = true;
        addTearDown(() => KSpecialUsername.motion = false);

        await pumpBadge(tester, tier, KSpecialIdEffects.full);
        expect(tester.hasRunningAnimations, isTrue);
        // GOLD and up twinkle (SILVER's full set is the sweep alone);
        // RUBY and LEGEND add the glow.
        final glows = tier == PremiumTier.ruby || tier == PremiumTier.legend;
        expect(
          find.byKey(KSpecialUsername.glowKey),
          glows ? findsOneWidget : findsNothing,
        );
        expect(
          find.byKey(KSpecialUsername.sparkleKey),
          tier == PremiumTier.silver ? findsNothing : findsOneWidget,
        );
        await tester.pump(KSpecialUsername.sweepPeriod(tier) * .3);
        expect(tester.takeException(), isNull);

        await pumpBadge(tester, tier, KSpecialIdEffects.sweepOnly);
        expect(tester.hasRunningAnimations, isTrue);
        expect(find.byKey(KSpecialUsername.glowKey), findsNothing);
        expect(find.byKey(KSpecialUsername.sparkleKey), findsNothing);

        await pumpBadge(
          tester,
          tier,
          KSpecialIdEffects.full,
          reduceMotion: true,
        );
        await tester.pump(const Duration(seconds: 3));
        expect(tester.hasRunningAnimations, isFalse);
        expect(find.byKey(KSpecialUsername.glowKey), findsNothing);
        expect(find.byKey(KSpecialUsername.sparkleKey), findsNothing);
      });
    }
  });
}
