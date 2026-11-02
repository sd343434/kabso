// D199 «تارجت» (CONVENTIONS §10.62): the chip next to «ترتيب الغرف» turns
// every 4 s between today's cherries and lucky-gift value; reduced motion
// shows both and never turns; a reached target shows a check and a glow.
// D199b: the chip shows the amount received only; its tap opens the
// ranking sheet (owner's reference layout): «الكرز» | «هدايا الحظ», the
// periods (the host; a viewer has today), the countdown, today's targets on
// the daily tab, the ranked supporters and the caller's own bar with
// «مركز المهام» (host) or «ادعم» (viewer). Arabic and English at 360×800,
// text 1.3.
// D214: the chip is always shown once the targets have loaded — both faces,
// «0» when nothing was received, also with no target today (no check, no
// glow); nothing while loading or for a 404.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/data/live_host_targets_repository.dart';
import 'package:kabso_live/features/live/presentation/widgets/host_target_sheet.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_host_target_chip.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_viewer_parts.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_live_host_targets_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

Map<String, Object?> _user(String id, String name) => {
  'id': id,
  'username': id,
  'displayName': name,
  'avatarUrl': null,
};

/// Test fixtures (D199b): [count] supporters, the first with the most.
List<Map<String, Object?>> supportersJson({
  int count = 3,
  List<String> names = const ['Layla', 'Omar', 'Sara'],
  int top = 9_000,
}) => [
  for (var i = 0; i < count; i++)
    {
      'user': _user('u${i + 1}', i < names.length ? names[i] : 'Fan ${i + 1}'),
      'coins': top ~/ (i + 1),
      'cherries': top * 13 ~/ 2 ~/ (i + 1),
      'supportLevel': i.isEven ? 12 + i : null,
    },
];

LiveHostTargets targetsFixture({
  int cherries = 12_400,
  int cherriesTarget = 50_000,
  int lucky = 3_000,
  int luckyTarget = 20_000,
  int supporters = 3,
  Map<String, Object?>? me,
}) => LiveHostTargets.fromJson({
  'day': '2026-10-31',
  'timeZone': 'Asia/Riyadh',
  'endsAt': '2026-10-31T21:00:00.000Z',
  'band': 1,
  'cherries': {
    'received': cherries,
    'target': cherriesTarget,
    'reached': cherriesTarget > 0 && cherries >= cherriesTarget,
  },
  'lucky': {
    'received': lucky,
    'target': luckyTarget,
    'reached': luckyTarget > 0 && lucky >= luckyTarget,
  },
  'topSupporters': supportersJson(count: supporters),
  'luckySupporters': supportersJson(
    count: 2,
    names: const ['Omar', 'Layla'],
    top: 2_000,
  ),
  'me': me,
});

HostGiftStats statsFixture(HostStatsPeriod period, {int supporters = 2}) =>
    HostGiftStats.fromJson({
      'period': period.wire,
      'timeZone': 'Asia/Riyadh',
      'from': period == HostStatsPeriod.all ? null : '2026-10-30T21:00:00.000Z',
      'to': switch (period) {
        HostStatsPeriod.week => '2026-11-01T21:00:00.000Z',
        HostStatsPeriod.month => '2026-11-30T21:00:00.000Z',
        _ => '2026-10-31T21:00:00.000Z',
      },
      'cherries': {
        'received': period == HostStatsPeriod.day ? 12_400 : 186_000,
        'gifts': period == HostStatsPeriod.day ? 31 : 402,
        'givers': period == HostStatsPeriod.day ? 9 : 57,
        'topSupporters': supportersJson(
          count: supporters,
          top: period == HostStatsPeriod.day ? 9_000 : 90_000,
        ),
        'series': [
          for (var i = 0; i < (period == HostStatsPeriod.day ? 24 : 30); i++)
            {'start': '2026-10-31T00:00:00', 'cherries': (i * 37) % 11 * 120},
        ],
      },
      'lucky': {
        'coins': period == HostStatsPeriod.day ? 3_000 : 41_500,
        'gifts': period == HostStatsPeriod.day ? 6 : 88,
        'givers': period == HostStatsPeriod.day ? 2 : 14,
        'topSupporters': supportersJson(
          count: 1,
          names: const ['Omar'],
          top: 2_000,
        ),
      },
      'targets': period == HostStatsPeriod.day ? _targetsJson() : null,
    });

Map<String, Object?> _targetsJson() => {
  'day': '2026-10-31',
  'timeZone': 'Asia/Riyadh',
  'endsAt': '2026-10-31T21:00:00.000Z',
  'band': 1,
  'cherries': {'received': 12_400, 'target': 50_000, 'reached': false},
  'lucky': {'received': 3_000, 'target': 20_000, 'reached': false},
  'topSupporters': <Object?>[],
  'luckySupporters': <Object?>[],
  'me': null,
};

/// The chips row over a dark room, inside a router (the task center).
class _Room extends StatelessWidget {
  const new({required this.isHost, this.onSupport});

  final bool isHost;
  final VoidCallback? onSupport;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF2A2333),
    body: Padding(
      padding: const EdgeInsets.fromLTRB(12, 60, 12, 0),
      child: KRoomChipsRow(
        roomNumber: 1234,
        targetChip: LiveHostTargetChip(
          username: 'host',
          isHost: isHost,
          onSupport: onSupport,
        ),
      ),
    ),
  );
}

Future<FakeLiveHostTargetsRepository> _pump(
  WidgetTester tester, {
  bool isHost = true,
  AppLanguage language = AppLanguage.en,
  LiveHostTargets? targets,
  bool noHost = false,
  bool signedIn = true,
  VoidCallback? onSupport,
  GoldenViewport viewport = GoldenViewport.android,
  Future<void>? hold,
}) async {
  setViewport(tester, viewport);
  final repo = FakeLiveHostTargetsRepository(
    byHost: noHost ? {} : {'host': targets ?? targetsFixture()},
    stats: {for (final p in HostStatsPeriod.values) p: statsFixture(p)},
  )..hold = hold;
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => _Room(isHost: isHost, onSupport: onSupport),
      ),
      GoRoute(
        path: '/tasks',
        builder: (_, _) => const Scaffold(body: Text('TASK CENTER')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await pumpScreen(
    tester,
    Router.withConfig(config: router),
    language: language,
    liveHostTargetsRepository: repo,
    overrides: [
      currentUserProvider.overrideWithValue(signedIn ? testUser() : null),
    ],
  );
  await tester.pump();
  await tester.pump();
  return repo;
}

/// The pills scroll sideways (as the reference's) when they do not fit.
Future<void> _period(WidgetTester tester, HostStatsPeriod p) async {
  final pill = find.byKey(HostTargetSheet.periodKey(p));
  await tester.ensureVisible(pill);
  await tester.pumpAndSettle();
  await tester.tap(pill);
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.byKey(LiveHostTargetChip.chipKey));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => HostTargetSheet.clock = () => DateTime.utc(2026, 10, 31, 15, 43));
  tearDown(() {
    LiveHostTargetChip.rotateEvery = const Duration(seconds: 4);
    HostTargetSheet.clock = DateTime.now;
  });

  testWidgets('not a host: no chip', (tester) async {
    await _pump(tester, noHost: true);
    expect(find.byKey(LiveHostTargetChip.chipKey), findsNothing);
  });

  testWidgets('turns every 4 s between cherries and the lucky gifts, '
      'the amount received only (D199b)', (tester) async {
    await _pump(tester);
    expect(find.byKey(LiveHostTargetChip.cherriesKey), findsOneWidget);
    expect(find.byKey(LiveHostTargetChip.luckyKey), findsNothing);
    expect(find.text('12.4K'), findsOneWidget);
    // Never the target on the chip.
    expect(find.textContaining('50K'), findsNothing);
    expect(find.textContaining('/'), findsNothing);
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(LiveHostTargetChip.luckyKey), findsOneWidget);
    expect(find.byKey(LiveHostTargetChip.cherriesKey), findsNothing);
    expect(find.text('3K'), findsOneWidget);
    expect(find.textContaining('20K'), findsNothing);
    expect(find.byType(KWizardHatIcon), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(LiveHostTargetChip.cherriesKey), findsOneWidget);
    // Both read out at once, whatever the face.
    expect(
      find.bySemanticsLabel(
        'Target: Cherries today: 12,400 · Lucky gifts today: 3,000 coins',
      ),
      findsOneWidget,
    );
  });

  testWidgets('reduced motion: both side by side, never turning', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await _pump(tester);
    expect(find.byKey(LiveHostTargetChip.cherriesKey), findsOneWidget);
    expect(find.byKey(LiveHostTargetChip.luckyKey), findsOneWidget);
    expect(find.text('12.4K'), findsOneWidget);
    expect(find.text('3K'), findsOneWidget);
    await tester.pump(const Duration(seconds: 9));
    expect(find.byKey(LiveHostTargetChip.cherriesKey), findsOneWidget);
    expect(find.byKey(LiveHostTargetChip.luckyKey), findsOneWidget);
  });

  testWidgets('a reached target: a check and the gold glow', (tester) async {
    await _pump(tester, targets: targetsFixture(cherries: 50_000));
    expect(find.byKey(LiveHostTargetChip.reachedKey), findsOneWidget);
    expect(find.text('50K'), findsOneWidget);
    final box = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byKey(LiveHostTargetChip.chipKey),
        matching: find.byType(AnimatedContainer),
      ),
    );
    final decoration = box.decoration! as BoxDecoration;
    expect(decoration.boxShadow, isNotEmpty);
    expect(find.bySemanticsLabel(RegExp('Target reached')), findsOneWidget);
    // The lucky face (not reached): no check, no glow.
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(LiveHostTargetChip.reachedKey), findsNothing);
  });

  testWidgets('D214: a target switched off still turns, showing what was '
      'received (no check)', (tester) async {
    await _pump(tester, targets: targetsFixture(luckyTarget: 0, lucky: 25_000));
    expect(find.byKey(LiveHostTargetChip.cherriesKey), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(LiveHostTargetChip.luckyKey), findsOneWidget);
    expect(find.text('25K'), findsOneWidget);
    expect(find.byKey(LiveHostTargetChip.reachedKey), findsNothing);
  });

  LiveHostTargets zeroTargets() => targetsFixture(
    cherries: 0,
    cherriesTarget: 0,
    lucky: 0,
    luckyTarget: 0,
    supporters: 0,
  );

  testWidgets('D214: nothing received and no target today — the chip still '
      'shows, both faces «0», no check or glow', (tester) async {
    await _pump(tester, targets: zeroTargets());
    expect(find.byKey(LiveHostTargetChip.chipKey), findsOneWidget);
    expect(find.byKey(LiveHostTargetChip.cherriesKey), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(find.byKey(LiveHostTargetChip.reachedKey), findsNothing);
    final box = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byKey(LiveHostTargetChip.chipKey),
        matching: find.byType(AnimatedContainer),
      ),
    );
    expect((box.decoration! as BoxDecoration).boxShadow, isNull);
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(LiveHostTargetChip.luckyKey), findsOneWidget);
    expect(find.byType(KWizardHatIcon), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'Target: Cherries today: 0 · Lucky gifts today: 0 coins',
      ),
      findsOneWidget,
    );
  });

  testWidgets('D214: reduced motion with no target — both faces «0»', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await _pump(tester, targets: zeroTargets());
    expect(find.byKey(LiveHostTargetChip.cherriesKey), findsOneWidget);
    expect(find.byKey(LiveHostTargetChip.luckyKey), findsOneWidget);
    expect(find.text('0'), findsNWidgets(2));
  });

  testWidgets('D214: a reached flag without a target shows no check', (
    tester,
  ) async {
    final odd = LiveHostTargets.fromJson(const {
      'day': '2026-10-31',
      'timeZone': 'Asia/Riyadh',
      'endsAt': '2026-10-31T21:00:00.000Z',
      'band': 1,
      'cherries': {'received': 0, 'target': 0, 'reached': true},
      'lucky': {'received': 0, 'target': 0, 'reached': true},
      'topSupporters': <Object?>[],
      'luckySupporters': <Object?>[],
      'me': null,
    });
    await _pump(tester, targets: odd);
    expect(find.byKey(LiveHostTargetChip.chipKey), findsOneWidget);
    expect(find.byKey(LiveHostTargetChip.reachedKey), findsNothing);
  });

  testWidgets('D214: while the targets load, nothing (no fake 0)', (
    tester,
  ) async {
    final gate = Completer<void>();
    await _pump(tester, targets: zeroTargets(), hold: gate.future);
    expect(find.byKey(LiveHostTargetChip.chipKey), findsNothing);
    expect(find.text('0'), findsNothing);
    gate.complete();
    await tester.pump();
    await tester.pump();
    expect(find.byKey(LiveHostTargetChip.chipKey), findsOneWidget);
  });

  test('D214: shows() only needs the data', () {
    expect(LiveHostTargetChip.shows(null), isFalse);
    expect(LiveHostTargetChip.shows(zeroTargets()), isTrue);
  });

  testWidgets('D214: a viewer opens the sheet with no target today — no '
      'targets block, no progress, nothing thrown', (tester) async {
    await _pump(tester, isHost: false, targets: zeroTargets());
    await _open(tester);
    expect(tester.takeException(), isNull);
    expect(find.byKey(HostTargetSheet.sheetKey), findsOneWidget);
    expect(find.byKey(HostTargetSheet.targetsKey), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('the host: tabs, periods, countdown, targets, ranked list, '
      'own bar and the task center', (tester) async {
    final repo = await _pump(tester);
    await _open(tester);
    expect(find.byKey(HostTargetSheet.sheetKey), findsOneWidget);
    expect(repo.askedStats, [HostStatsPeriod.day]);
    // Daily: the countdown to Riyadh midnight (21:00 UTC) and the targets.
    expect(find.text('Countdown 5H 17M'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.byKey(HostTargetSheet.targetsKey), findsOneWidget);
    expect(find.text('12,400 / 50,000'), findsOneWidget);
    expect(find.text('3,000 / 20,000'), findsOneWidget);
    // The cherries list (cherries, by rank) and the host's own total.
    expect(find.byKey(HostTargetSheet.rowKey('u1')), findsOneWidget);
    expect(find.byKey(HostTargetSheet.rowKey('u2')), findsOneWidget);
    expect(find.bySemanticsLabel('1. Layla: 58,500'), findsOneWidget);
    expect(find.bySemanticsLabel('2. Omar: 29,250'), findsOneWidget);
    expect(find.bySemanticsLabel('Your place —: 12,400'), findsOneWidget);
    // «هدايا الحظ»: coins.
    await tester.tap(find.byKey(HostTargetSheet.tabKey(TargetTab.lucky)));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('1. Omar: 2,000'), findsOneWidget);
    expect(find.bySemanticsLabel('Your place —: 3,000'), findsOneWidget);
    await tester.tap(find.byKey(HostTargetSheet.tabKey(TargetTab.cherries)));
    // Monthly: no targets; the countdown in days.
    await _period(tester, HostStatsPeriod.month);
    await tester.pumpAndSettle();
    expect(repo.askedStats, [HostStatsPeriod.day, HostStatsPeriod.month]);
    expect(find.byKey(HostTargetSheet.targetsKey), findsNothing);
    expect(find.text('Countdown 30D 5H'), findsOneWidget);
    expect(find.text('This month'), findsOneWidget);
    expect(find.bySemanticsLabel('1. Layla: 585,000'), findsOneWidget);
    // All: no countdown; the dropdown chooses a period too.
    await _period(tester, HostStatsPeriod.all);
    await tester.pumpAndSettle();
    expect(find.byKey(HostTargetSheet.countdownKey), findsNothing);
    expect(find.text('All time'), findsOneWidget);
    await tester.tap(find.byKey(HostTargetSheet.rangeKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('This week').last);
    await tester.pumpAndSettle();
    expect(repo.askedStats.last, HostStatsPeriod.week);
    expect(find.text('Countdown 1D 5H'), findsOneWidget);
    await _period(tester, HostStatsPeriod.day);
    await tester.pumpAndSettle();
    expect(find.byKey(HostTargetSheet.supportKey), findsNothing);
    await tester.tap(find.byKey(HostTargetSheet.taskCenterKey));
    await tester.pumpAndSettle();
    expect(find.text('TASK CENTER'), findsOneWidget);
  });

  testWidgets('«?» explains the targets; ✕ closes', (tester) async {
    await _pump(tester);
    await _open(tester);
    await tester.tap(find.byKey(HostTargetSheet.helpKey));
    await tester.pumpAndSettle();
    expect(find.text('What is the target?'), findsOneWidget);
    expect(find.textContaining('midnight Riyadh time'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(HostTargetSheet.closeKey));
    await tester.pumpAndSettle();
    expect(find.byKey(HostTargetSheet.sheetKey), findsNothing);
  });

  testWidgets('a viewer: today only, their own place, «ادعم» opens the gifts', (
    tester,
  ) async {
    var gifts = 0;
    final repo = await _pump(
      tester,
      isHost: false,
      onSupport: () => gifts++,
      targets: targetsFixture(
        supporters: 8,
        me: {
          'cherries': {'rank': null, 'amount': 0},
          'lucky': {'rank': 2, 'amount': 1_000},
        },
      ),
    );
    await _open(tester);
    expect(find.byKey(HostTargetSheet.sheetKey), findsOneWidget);
    expect(repo.askedStats, isEmpty);
    // Today only: one pill, no dropdown menu.
    expect(
      find.byKey(HostTargetSheet.periodKey(HostStatsPeriod.day)),
      findsOneWidget,
    );
    expect(
      find.byKey(HostTargetSheet.periodKey(HostStatsPeriod.month)),
      findsNothing,
    );
    expect(find.text('Countdown 5H 17M'), findsOneWidget);
    expect(find.byKey(HostTargetSheet.targetsKey), findsOneWidget);
    expect(find.text('3,000 / 20,000'), findsOneWidget);
    expect(find.text('Layla'), findsWidgets);
    expect(find.text('Sara'), findsOneWidget);
    // Places 1–3 on shields, 4+ as numbers.
    expect(find.text('4'), findsOneWidget);
    expect(find.bySemanticsLabel('Your place 20+: 0'), findsOneWidget);
    await tester.tap(find.byKey(HostTargetSheet.tabKey(TargetTab.lucky)));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Your place 2: 1,000'), findsOneWidget);
    expect(find.byKey(HostTargetSheet.taskCenterKey), findsNothing);
    await tester.tap(find.byKey(HostTargetSheet.supportKey));
    await tester.pumpAndSettle();
    expect(gifts, 1);
    expect(find.byKey(HostTargetSheet.sheetKey), findsNothing);
  });

  testWidgets('a guest: the list, no own bar and no button', (tester) async {
    await _pump(tester, isHost: false, signedIn: false);
    await _open(tester);
    expect(find.text('Layla'), findsOneWidget);
    expect(find.byKey(HostTargetSheet.meKey), findsNothing);
    expect(find.byKey(HostTargetSheet.supportKey), findsNothing);
  });

  for (final language in AppLanguage.values) {
    testWidgets('D214 ${language.name} at 360×800, text 1.3: the zero chip '
        'fits, both faces', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _pump(tester, language: language, targets: zeroTargets());
      expect(tester.takeException(), isNull);
      expect(find.byKey(LiveHostTargetChip.cherriesKey), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      expect(find.byKey(LiveHostTargetChip.luckyKey), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
      await _open(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('${language.name} at 360×800, text 1.3: chip and sheet fit', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _pump(tester, language: language);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      await _open(tester);
      expect(tester.takeException(), isNull);
      if (language == AppLanguage.ar) {
        expect(find.text('يومي'), findsOneWidget);
        expect(find.text('الكل'), findsOneWidget);
        expect(find.text('الكرز'), findsOneWidget);
        expect(find.text('هدايا الحظ'), findsOneWidget);
        expect(find.text('مركز المهام'), findsOneWidget);
        expect(find.text('العد التنازلي 5س 17د'), findsOneWidget);
      }
      for (final p in HostStatsPeriod.values) {
        await _period(tester, p);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      await tester.tap(find.byKey(HostTargetSheet.tabKey(TargetTab.lucky)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
