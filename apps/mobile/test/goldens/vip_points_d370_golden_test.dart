// D370 (owner 2026-11-11) «نقاط الشحن»:
//
//   vip.points.<ar|en>.<dark|light>   the VIP page with «استبدل بالنقاط»
//                                     chosen: the two ways to pay, the points
//                                     price / 30 days and the balance line
//   wallet.points_row.<ar|en>.<light|dark>  the wallet's gold tab with the row
//                                     «نقاط الشحن» and its balance
//   wallet.points_history.ar.light    the history page: balance, how points
//                                     are earned, every reason
//
// 393 × 852 with the status bar 59 and the home indicator 34; the clock is
// pinned (fixtures' 2026-11-11 09:30 UTC). Regenerate on Linux with the
// pinned Flutter:
//   flutter test --update-goldens test/goldens/vip_points_d370_golden_test.dart
@Tags(['golden'])
library;

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/vip/presentation/vip_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../features/vip/vip_points_harness.dart';
import '../fixtures/vip/vip_points_d370_fixtures.dart';
import '../helpers/golden.dart';

void main() {
  for (final language in AppLanguage.values) {
    for (final brightness in Brightness.values) {
      testWidgets('VIP page, points (${language.name} ${brightness.name})', (
        tester,
      ) async {
        await withClock(Clock.fixed(d370Now), () async {
          await pumpPoints(tester, language: language, brightness: brightness);
          await tester.tap(find.byKey(VipScreen.payPointsKey));
          await tester.pumpAndSettle();
          await precacheImages(tester);
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
              'png/vip.points.${language.name}.${brightness.name}.phone.png',
            ),
          );
        });
      });

      testWidgets('wallet row (${language.name} ${brightness.name})', (
        tester,
      ) async {
        await withClock(Clock.fixed(d370Now), () async {
          await pumpPoints(
            tester,
            initial: '/wallet',
            language: language,
            brightness: brightness,
          );
          await precacheImages(tester);
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
              'png/wallet.points_row.${language.name}.${brightness.name}'
              '.phone.png',
            ),
          );
        });
      });
    }
  }

  testWidgets('points history (ar light)', (tester) async {
    await withClock(Clock.fixed(d370Now), () async {
      await pumpPoints(
        tester,
        initial: '/wallet/recharge-points',
        brightness: Brightness.light,
        points: FakeRechargePoints(history: d370History),
      );
      await precacheImages(tester);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('png/wallet.points_history.ar.light.phone.png'),
      );
    });
  });
}
