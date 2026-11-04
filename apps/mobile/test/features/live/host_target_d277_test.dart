// D277 (owner, CONVENTIONS §10.62.1): the host's two targets in cherries —
// «هدف الهدايا» (gifts outside the lucky category from other people; was the
// cherries target) and «هدف هدايا الحظ» (lucky gifts, self-sends included).
// The app reads `gifts` (a server before v1.69-live: `cherries`), shows each
// target's badge from its asset slot on the chip and in the sheet, and the
// renamed texts in Arabic and English.

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/data/live_host_targets_repository.dart';
import 'package:kabso_live/features/live/presentation/widgets/host_target_badge.dart';
import 'package:kabso_live/features/live/presentation/widgets/host_target_sheet.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_host_target_chip.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_viewer_parts.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_live_host_targets_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

Map<String, Object?> _json({
  Object? gifts = const {
    'received': 2_645,
    'target': 650_000,
    'reached': false,
  },
  Object? cherries = const {'received': 1, 'target': 2, 'reached': false},
  Object? me,
}) => {
  'day': '2027-01-13',
  'timeZone': 'Asia/Riyadh',
  'endsAt': '2027-01-13T21:00:00.000Z',
  'band': 1,
  'gifts': ?gifts,
  'cherries': ?cherries,
  'lucky': {'received': 100, 'target': 100, 'reached': true},
  'topSupporters': const <Object?>[],
  'luckySupporters': const <Object?>[],
  'me': me,
};

Future<void> _pump(WidgetTester tester, AppLanguage language) async {
  HostTargetSheet.clock = () => DateTime.utc(2027, 1, 13, 15);
  addTearDown(() => HostTargetSheet.clock = DateTime.now);
  setViewport(tester, GoldenViewport.phone);
  final repo = FakeLiveHostTargetsRepository(
    byHost: {'host': LiveHostTargets.fromJson(_json())},
  );
  await pumpScreen(
    tester,
    const Scaffold(
      backgroundColor: Color(0xFF2A2333),
      body: Padding(
        padding: EdgeInsets.fromLTRB(12, 60, 12, 0),
        child: KRoomChipsRow(
          roomNumber: 1,
          targetChip: LiveHostTargetChip(username: 'host', isHost: false),
        ),
      ),
    ),
    language: language,
    liveHostTargetsRepository: repo,
    overrides: [currentUserProvider.overrideWithValue(testUser())],
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  test('reads `gifts` first, an older server `cherries`; `me.gifts` too', () {
    final now = LiveHostTargets.fromJson(
      _json(
        me: const {
          'gifts': {'rank': 1, 'amount': 1_995},
          'cherries': {'rank': 9, 'amount': 9},
          'lucky': {'rank': 2, 'amount': 20},
        },
      ),
    );
    expect(now.gifts.received, 2_645);
    expect(now.gifts.target, 650_000);
    expect(now.meGifts?.amount, 1_995);
    expect(now.lucky.reached, isTrue);

    final old = LiveHostTargets.fromJson(
      _json(
        gifts: null,
        cherries: const {'received': 12, 'target': 50, 'reached': false},
        me: const {
          'cherries': {'rank': 3, 'amount': 7},
          'lucky': {'rank': null, 'amount': 0},
        },
      ),
    );
    expect([old.gifts.received, old.gifts.target], [12, 50]);
    expect(old.meGifts?.rank, 3);
  });

  test('the stats read the lucky cherries (0 from an older server)', () {
    Map<String, Object?> stats(Map<String, Object?> lucky) => {
      'period': 'DAY',
      'timeZone': 'Asia/Riyadh',
      'from': null,
      'to': '2027-01-13T21:00:00.000Z',
      'cherries': {
        'received': 2_645,
        'gifts': 5,
        'givers': 2,
        'topSupporters': const <Object?>[],
        'series': const <Object?>[],
      },
      'lucky': lucky,
      'targets': null,
    };
    const base = {
      'coins': 70,
      'gifts': 7,
      'givers': 2,
      'topSupporters': <Object?>[],
    };
    expect(
      HostGiftStats.fromJson(stats({...base, 'cherries': 100})).luckyCherries,
      100,
    );
    expect(HostGiftStats.fromJson(stats(base)).luckyCherries, 0);
  });

  test('the badges have fixed asset slots (the owner swaps the files)', () {
    expect(HostTargetKind.gifts.asset, 'assets/host_targets/gifts_target.png');
    expect(HostTargetKind.lucky.asset, 'assets/host_targets/lucky_target.png');
  });

  for (final language in AppLanguage.values) {
    testWidgets('the chip and the sheet: badges and the renamed targets '
        '(${language.name})', (tester) async {
      await _pump(tester, language);
      // The chip turns between the faces, each with its badge.
      final chip = find.byKey(LiveHostTargetChip.chipKey);
      expect(chip, findsOneWidget);
      for (final kind in HostTargetKind.values) {
        if (kind == HostTargetKind.lucky) {
          await tester.pump(LiveHostTargetChip.rotateEvery);
          await tester.pump(const Duration(seconds: 1));
        }
        final badge = find.descendant(
          of: chip,
          matching: find.byKey(KHostTargetBadge.keyOf(kind)),
        );
        expect(badge, findsOneWidget, reason: kind.name);
        expect((tester.widget(badge) as Image).image, isA<AssetImage>());
        expect(
          ((tester.widget(badge) as Image).image as AssetImage).assetName,
          kind.asset,
        );
      }
      final ar = language == AppLanguage.ar;
      expect(
        tester.getSemantics(chip).label,
        contains(
          ar
              ? 'هدف الهدايا اليوم: 2,645 كرز'
              : 'Gifts target today: 2,645 '
                    'cherries',
        ),
      );

      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(find.text(ar ? 'الهدايا' : 'Gifts'), findsOneWidget);
      expect(find.text(ar ? 'هدايا الحظ' : 'Lucky gifts'), findsOneWidget);
      final block = find.byKey(HostTargetSheet.targetsKey);
      expect(block, findsOneWidget);
      for (final kind in HostTargetKind.values) {
        expect(
          find.descendant(
            of: block,
            matching: find.byKey(KHostTargetBadge.keyOf(kind)),
          ),
          findsOneWidget,
        );
      }
      expect(
        find.descendant(
          of: block,
          matching: find.text(ar ? 'هدف الهدايا' : 'Gifts target'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: block,
          matching: find.text(ar ? 'هدف هدايا الحظ' : 'Lucky gifts target'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('650,000'), findsOneWidget);
    });
  }
}
