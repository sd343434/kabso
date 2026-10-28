// D146: the owner's special-ID badge as `KSpecialUsername` — one medal and
// pill per tier (LEGEND, RUBY, GOLD, SILVER) with the username (no «@»,
// D158), the light
// sweep only when motion is on (never in tests, never with reduced motion),
// left-to-right in Arabic too, screen reader label, tap.

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/models/premium_tier.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/components/k_special_username.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/component_harness.dart';

void main() {
  for (final tier in PremiumTier.values) {
    testWidgets('$tier: its medal and its pill colours', (tester) async {
      await pumpComponent(
        tester,
        Center(
          child: KSpecialUsername(username: '777', tier: tier),
        ),
      );
      final image = tester.widget<Image>(find.byType(Image));
      expect(
        (image.image as AssetImage).assetName,
        'assets/special_id/medal_${tier.name}.png',
      );
      expect(
        tester.getSize(find.byType(KSpecialUsername)),
        KSpecialUsername.measure('777', tier, 22),
      );
      expect(tester.takeException(), isNull);
    });
  }

  test('the four tiers have their own pill; ruby is Kabso red', () {
    final pills = PremiumTier.values
        .map((t) => KSpecialUsernameStyle.of(t).pill)
        .toSet();
    expect(pills, hasLength(4));
    expect(KSpecialUsernameStyle.ruby.pill, contains(const Color(0xFFFF3B47)));
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
}
