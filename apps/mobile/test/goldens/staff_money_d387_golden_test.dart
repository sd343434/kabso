// D387 follow-up (owner 2026-11-12: «اي موظف لدينا لا يمكنه ارسال الهدايا —
// بالاضافة للموظفين الذين لديهم كرز يسحب من خلالنا فقط», CONVENTIONS
// §10.176.8–9):
//
//   staff_money_d387.gift      a staff account in a live's gift panel: the
//                              gifts can be looked at, a gift is picked, and
//                              Send stays off with «حسابات فريق كابسو لا ترسل
//                              الهدايا.»
//   staff_money_d387.cherries  «بيع الكرز» for a staff account: the notice
//                              (cherries only through a withdrawal request to
//                              Kabso) and no offer button
//
// Arabic and English, dark and light, on the phone (393 × 852 with the
// status bar 59 and the home indicator 34). A fixed clock; the gift art is the
// test fixtures' own. Regenerate on Linux with the pinned Flutter:
//   flutter test --update-goldens test/goldens/staff_money_d387_golden_test.dart
@Tags(['golden'])
library;

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_gift_sheet.dart';
import 'package:kabso_live/features/recharge/presentation/recharge_cherry_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../fixtures/live/live_gift_fixtures.dart';
import '../helpers/fake_live_gift_repository.dart';
import '../helpers/fake_live_repository.dart';
import '../helpers/fakes.dart';
import '../helpers/golden.dart';
import '../helpers/pump_app.dart';

final DateTime _now = DateTime.utc(2026, 11, 12, 12);
const _open = Key('test.openGifts');

const _host = UserSummary(
  id: 'user-sara',
  username: 'sara',
  displayName: 'Sara',
  avatarUrl: null,
);

class _Opener extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        key: _open,
        onPressed: () => unawaited(
          KLiveGiftSheet.show(
            context,
            room: LiveGiftRoom(
              roomId: 'room-0',
              host: _host,
              seated: (_) => const [],
              onSeatsStale: () {},
            ),
          ),
        ),
        child: const SizedBox.square(dimension: 40),
      ),
    ),
  );
}

Future<void> _phone(WidgetTester tester) async {
  await loadAppFonts();
  setViewport(tester, GoldenViewport.phone);
  tester.view.padding = const FakeViewPadding(
    top: 59 * GoldenViewport.pixelRatio,
    bottom: 34 * GoldenViewport.pixelRatio,
  );
  addTearDown(tester.view.resetPadding);
}

Future<void> _end(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

void main() {
  setUpAll(loadAppFonts);
  final staff = testUser().copyWith(staffId: 'Kabso11');

  forEachLanguage((language) {
    final name = language.name;
    final ar = language == AppLanguage.ar;
    for (final (label, brightness) in [
      ('phone', Brightness.dark),
      ('phone.light', Brightness.light),
    ]) {
      testWidgets('staff_money_d387.gift $name $label', (tester) async {
        await _phone(tester);
        await withClock(Clock.fixed(_now), () async {
          await pumpScreen(
            tester,
            const _Opener(),
            language: language,
            brightness: brightness,
            liveGiftRepository: FakeLiveGiftRepository(
              codes: giftFixtureCodes,
              ar: ar,
            ),
            overrides: [
              liveRepositoryProvider.overrideWithValue(
                FakeLiveRepository()..coins = 1000,
              ),
              currentUserProvider.overrideWithValue(staff),
            ],
          );
          await tester.tap(find.byKey(_open));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(KLiveGiftSheet.cellKey('rose')));
          await tester.pumpAndSettle();
          await precacheImages(tester);
        });
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('png/staff_money_d387.gift.$name.$label.png'),
        );
        await _end(tester);
      });

      testWidgets('staff_money_d387.cherries $name $label', (tester) async {
        await _phone(tester);
        await withClock(Clock.fixed(_now), () async {
          await pumpScreen(
            tester,
            const RechargeCherryScreen(),
            language: language,
            brightness: brightness,
            overrides: [currentUserProvider.overrideWithValue(staff)],
          );
          await tester.pumpAndSettle();
        });
        expect(tester.takeException(), isNull);
        expect(find.byKey(RechargeCherryScreen.staffKey), findsOneWidget);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('png/staff_money_d387.cherries.$name.$label.png'),
        );
        await _end(tester);
      });
    }
  });
}
