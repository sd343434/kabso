// D299j (owner, new art for every special-ID tier: «… بتصغير الشريط بحيث
// يتسع لثلاث مقاطع» — LEGEND 3, RUBY 4, GOLD 5, SILVER 6 or more): the
// medal over a stretchable plate, the ID centred in the glass.
//
//   special_id.tiers.<brightness>   each tier at its shortest length, a
//                                   medium and a long ID (22 pt), the gold
//                                   staff ID «Kabso01» and the chat size
//   special_id.chat                 a live chat line of each tier
//   special_id.profile.<tier>       the profile bar's @username of a premium
//                                   account (393 × 852)
//   special_id.motion.<tier>        D299l: a frame of the tier's full motion
//
// Regenerate on Linux with the pinned Flutter:
//   flutter test --update-goldens test/goldens/special_id_d299j_golden_test.dart
@Tags(['golden'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/models/premium_tier.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/components/k_special_username.dart';
import 'package:kabso_live/design_system/components/k_staff_id.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_chat.dart';
import 'package:material_ui/material_ui.dart';

import '../features/profile/profile_cover_d278_test.dart' show pumpOther;
import '../features/profile/profile_on_cover_d299_test.dart' show d299Other;
import '../helpers/golden.dart';
import '../helpers/pump_app.dart';

/// Per tier: the shortest length (the owner's count), a medium and a long
/// ID.
const Map<PremiumTier, List<String>> ids = {
  PremiumTier.legend: ['777', 'kabso', 'kingofthenight'],
  PremiumTier.ruby: ['7777', 'layla7', 'rubyqueen2026'],
  PremiumTier.gold: ['77777', 'goldfox', 'goldenking2026'],
  PremiumTier.silver: ['777777', 'silvermoon', 'silverstarlight7'],
};

Future<void> _shot(
  WidgetTester tester,
  Widget child, {
  Brightness brightness = Brightness.dark,
}) async {
  await loadAppFonts();
  setViewport(tester, GoldenViewport.phone);
  await pumpScreen(
    tester,
    Scaffold(
      body: SafeArea(
        child: Padding(padding: const EdgeInsets.all(12), child: child),
      ),
    ),
    brightness: brightness,
  );
  await precacheImages(tester);
}

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('special_id.tiers.${brightness.name}', (tester) async {
      await _shot(
        tester,
        SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final MapEntry(key: tier, value: names) in ids.entries) ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (final n in names)
                      KSpecialUsername(username: n, tier: tier),
                  ],
                ),
                const SizedBox(height: 6),
              ],
              const KStaffIdText('Kabso01'),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final MapEntry(key: tier, value: names) in ids.entries)
                    KSpecialUsername(
                      username: names.first,
                      tier: tier,
                      height: 15,
                    ),
                ],
              ),
            ],
          ),
        ),
        brightness: brightness,
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('png/special_id.tiers.${brightness.name}.phone.png'),
      );
    });
  }

  testWidgets('special_id.chat', (tester) async {
    await _shot(
      tester,
      ProviderScope(
        child: ColoredBox(
          color: const Color(0xFF2A1F3D),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final MapEntry(key: tier, value: names) in ids.entries)
                  for (final n in [names.first, names.last]) ...[
                    LiveChatAuthoredLine(
                      name: 'Omar',
                      avatarUrl: null,
                      label: 'line',
                      message: const Text('Hello'),
                      maxWidth: 300,
                      color: LiveRoomChatLines.messageBox,
                      username: n,
                      premiumTier: tier,
                    ),
                    const SizedBox(height: 6),
                  ],
              ],
            ),
          ),
        ),
      ),
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('png/special_id.chat.phone.png'),
    );
  });

  for (final MapEntry(key: tier, value: names) in ids.entries) {
    testWidgets('special_id.profile.${tier.name}', (tester) async {
      await loadAppFonts();
      await pumpOther(
        tester,
        d299Other(ar: false).copyWith(username: names[1], premiumTier: tier),
        language: AppLanguage.en,
      );
      await precacheImages(tester);
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('png/special_id.profile.${tier.name}.phone.png'),
      );
    });
  }

  // D299l: one frame of each tier's full motion (motion forced on in this
  // test only), at 0.3 of a sweep — the sweep on the glass, a gem glinting,
  // RUBY's glow, LEGEND's glow and floating stars.
  const frameKey = Key('special_id.motion.frame');
  for (final MapEntry(key: tier, value: names) in ids.entries) {
    testWidgets('special_id.motion.${tier.name}', (tester) async {
      // Drawn at 30 pt, magnified ×≈2.5 into a 380 × 150 frame (with room
      // for the glow) so the effects can be judged.
      Widget screen(Key key) => Scaffold(
        backgroundColor: const Color(0xFF0B0B10),
        body: Center(
          child: RepaintBoundary(
            key: frameKey,
            child: ColoredBox(
              color: const Color(0xFF0B0B10),
              child: SizedBox(
                width: 380,
                height: 150,
                child: FittedBox(
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: KSpecialUsername(
                      key: key,
                      username: names[1],
                      tier: tier,
                      height: 30,
                      effects: KSpecialIdEffects.full,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await loadAppFonts();
      setViewport(tester, GoldenViewport.phone);
      // The art decoded while still, then the badge again with motion on.
      await pumpScreen(tester, screen(const ValueKey('still')));
      await precacheImages(tester);
      KSpecialUsername.motion = true;
      addTearDown(() => KSpecialUsername.motion = false);
      await pumpScreen(tester, screen(const ValueKey('moving')));
      await tester.pump(KSpecialUsername.sweepPeriod(tier) * .3);
      await expectLater(
        find.byKey(frameKey),
        matchesGoldenFile('png/special_id.motion.${tier.name}.png'),
      );
      await tester.pumpWidget(const SizedBox());
    });
  }
}
