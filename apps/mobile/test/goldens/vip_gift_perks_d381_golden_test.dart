// D381 (owner 2026-11-11; contract v1.134-social, CONVENTIONS §10.171) VIP
// perks phase 2:
//
//   vip.d381_mine.<ar|en>.<dark|light>       «الخاص بي VIP» with every D381
//                                            perk held: this month's
//                                            rockets, free CP requests, the
//                                            VIP gifts, the largest quantity,
//                                            the voice length, priority
//                                            support and «هدية مؤجلة»
//   vip.d381_scheduled.<ar|en>.<dark|light>  «هدية مؤجلة»: waiting (with
//                                            «إلغاء الهدية»), sent, failed
//
// 393 × 852 with the status bar 59 and the home indicator 34; the clock is
// pinned (2026-11-11 09:30 UTC). Test-only stand-in art (the fixtures' gift
// assets). Regenerate on Linux with the pinned Flutter:
//   flutter test --update-goldens test/goldens/vip_gift_perks_d381_golden_test.dart
@Tags(['golden'])
library;

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/vip/data/vip_gift_perks_repository.dart';
import 'package:kabso_live/features/vip/data/vip_repository.dart';
import 'package:kabso_live/features/vip/presentation/vip_gift_perks.dart';
import 'package:kabso_live/features/vip/presentation/vip_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../features/vip/vip_gift_perks_d381_test.dart'
    show FakeVipGiftPerks, fullPerksNowJson, scheduledGiftJson;
import '../features/vip/vip_points_harness.dart';
import '../fixtures/vip/vip_points_d370_fixtures.dart';
import '../helpers/fake_live_gift_repository.dart';
import '../helpers/fakes.dart';
import '../helpers/golden.dart';
import '../helpers/pump_app.dart';

VipMembership _member() => VipMembership(
  tierId: 'p1',
  tierCode: 'VIP_1',
  tierName: 'VIP 1',
  tierColor: 0xFF2E8B3D,
  onSale: true,
  startedAt: d370Now.subtract(const Duration(days: 11)),
  expiresAt: d370Now.add(const Duration(days: 19)),
  daysLeft: 19,
  perksNow: VipPerksNow.fromJson(fullPerksNowJson),
);

void main() {
  // The captures go to the owner: no debug banner.
  setUp(() => WidgetsApp.debugAllowBannerOverride = false);
  tearDown(() => WidgetsApp.debugAllowBannerOverride = true);

  for (final language in AppLanguage.values) {
    for (final brightness in Brightness.values) {
      final tag = '${language.name}.${brightness.name}';

      testWidgets('«الخاص بي VIP» ($tag)', (tester) async {
        await withClock(Clock.fixed(d370Now), () async {
          await pumpPoints(
            tester,
            vip: FakePointsVip(membership: _member()),
            language: language,
            brightness: brightness,
          );
          await tester.tap(find.byKey(VipScreen.statusKey));
          await tester.pumpAndSettle();
          expect(find.byKey(VipPerksNowSection.sectionKey), findsOneWidget);
          await precacheImages(tester);
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('png/vip.d381_mine.$tag.phone.png'),
          );
        });
      });

      testWidgets('«هدية مؤجلة» ($tag)', (tester) async {
        await withClock(Clock.fixed(d370Now), () async {
          await loadAppFonts();
          setViewport(tester, GoldenViewport.phone);
          tester.view.padding = const FakeViewPadding(
            top: 59 * GoldenViewport.pixelRatio,
            bottom: 34 * GoldenViewport.pixelRatio,
          );
          addTearDown(tester.view.resetPadding);
          final ar = language == AppLanguage.ar;
          final at = DateTime.utc(2026, 11, 20, 18);
          final repo = FakeVipGiftPerks(
            items: [
              VipScheduledGift.fromJson(
                scheduledGiftJson(
                  'g1',
                  'PENDING',
                  at: at,
                  name: ar ? 'سارة' : 'Sara',
                  ar: ar,
                ),
              ),
              VipScheduledGift.fromJson(
                scheduledGiftJson(
                  'g2',
                  'DELIVERED',
                  at: at.subtract(const Duration(days: 12)),
                  name: ar ? 'ليلى' : 'Layla',
                  gift: 'rose',
                  ar: ar,
                ),
              ),
              VipScheduledGift.fromJson(
                scheduledGiftJson(
                  'g3',
                  'FAILED',
                  at: at.subtract(const Duration(days: 20)),
                  name: ar ? 'منى' : 'Mona',
                  gift: 'sports_car',
                  ar: ar,
                ),
              ),
            ],
          );
          await pumpScreen(
            tester,
            const VipScheduledGiftsScreen(),
            language: language,
            brightness: brightness,
            liveGiftRepository: FakeLiveGiftRepository(ar: ar),
            overrides: [
              currentUserProvider.overrideWithValue(testUser()),
              vipGiftPerksRepositoryProvider.overrideWithValue(repo),
            ],
          );
          await tester.pumpAndSettle();
          await precacheImages(tester);
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('png/vip.d381_scheduled.$tag.phone.png'),
          );
        });
      });
    }
  }
}
