// D199 «تارجت» (CONVENTIONS §10.62): the chip next to «ترتيب الغرف» turns
// every 4 s between today's cherries and lucky-gift value; reduced motion
// shows both and never turns; a reached target shows a check and a glow.
// The host's tap opens the gift stats (يومي / أسبوعي / شهري / الكل, today's
// targets and the task center on the daily tab); a viewer's opens today's
// progress and top supporters only. Arabic and English at 360×800, 1.3.

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/live/data/live_host_targets_repository.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_host_target_chip.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_viewer_parts.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_live_host_targets_repository.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

Map<String, Object?> _user(String id, String name) => {
  'id': id,
  'username': id,
  'displayName': name,
  'avatarUrl': null,
};

LiveHostTargets targetsFixture({
  int cherries = 12_400,
  int cherriesTarget = 50_000,
  int lucky = 3_000,
  int luckyTarget = 20_000,
}) => LiveHostTargets.fromJson({
  'day': '2026-10-31',
  'timeZone': 'Asia/Riyadh',
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
  'topSupporters': [
    {'user': _user('u1', 'Layla'), 'coins': 9_000},
    {'user': _user('u2', 'Omar'), 'coins': 4_200},
    {'user': _user('u3', 'Sara'), 'coins': 1_100},
  ],
});

HostGiftStats statsFixture(HostStatsPeriod period) => HostGiftStats.fromJson({
  'period': period.wire,
  'timeZone': 'Asia/Riyadh',
  'from': period == HostStatsPeriod.all ? null : '2026-10-30T21:00:00.000Z',
  'to': '2026-10-31T21:00:00.000Z',
  'cherries': {
    'received': period == HostStatsPeriod.day ? 12_400 : 186_000,
    'gifts': period == HostStatsPeriod.day ? 31 : 402,
    'givers': period == HostStatsPeriod.day ? 9 : 57,
    'topSupporters': [
      {'user': _user('u1', 'Layla'), 'coins': 9_000},
      {'user': _user('u2', 'Omar'), 'coins': 4_200},
    ],
    'series': [
      for (var i = 0; i < (period == HostStatsPeriod.day ? 24 : 30); i++)
        {'start': '2026-10-31T00:00:00', 'cherries': (i * 37) % 11 * 120},
    ],
  },
  'lucky': {
    'coins': period == HostStatsPeriod.day ? 3_000 : 41_500,
    'gifts': period == HostStatsPeriod.day ? 6 : 88,
    'givers': period == HostStatsPeriod.day ? 2 : 14,
    'topSupporters': [
      {'user': _user('u2', 'Omar'), 'coins': 2_000},
    ],
  },
  'targets': period == HostStatsPeriod.day ? _targetsJson() : null,
});

Map<String, Object?> _targetsJson() => {
  'day': '2026-10-31',
  'timeZone': 'Asia/Riyadh',
  'band': 1,
  'cherries': {'received': 12_400, 'target': 50_000, 'reached': false},
  'lucky': {'received': 3_000, 'target': 20_000, 'reached': false},
  'topSupporters': <Object?>[],
};

/// The chips row over a dark room, inside a router (the task center).
class _Room extends StatelessWidget {
  const new({required this.isHost});

  final bool isHost;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF2A2333),
    body: Padding(
      padding: const EdgeInsets.fromLTRB(12, 60, 12, 0),
      child: KRoomChipsRow(
        level: 3,
        roomNumber: 1234,
        targetChip: LiveHostTargetChip(username: 'host', isHost: isHost),
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
}) async {
  setViewport(tester, GoldenViewport.android);
  final repo = FakeLiveHostTargetsRepository(
    byHost: noHost ? {} : {'host': targets ?? targetsFixture()},
    stats: {for (final p in HostStatsPeriod.values) p: statsFixture(p)},
  );
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => _Room(isHost: isHost),
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
  );
  await tester.pump();
  await tester.pump();
  return repo;
}

void main() {
  tearDown(() => LiveHostTargetChip.rotateEvery = const Duration(seconds: 4));

  testWidgets('not a host: no chip', (tester) async {
    await _pump(tester, noHost: true);
    expect(find.byKey(LiveHostTargetChip.chipKey), findsNothing);
  });

  testWidgets('turns every 4 s between cherries and the lucky gifts', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.byKey(LiveHostTargetChip.cherriesKey), findsOneWidget);
    expect(find.byKey(LiveHostTargetChip.luckyKey), findsNothing);
    expect(find.text('12.4K/50K'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(LiveHostTargetChip.luckyKey), findsOneWidget);
    expect(find.byKey(LiveHostTargetChip.cherriesKey), findsNothing);
    expect(find.text('3K/20K'), findsOneWidget);
    expect(find.byType(KWizardHatIcon), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(LiveHostTargetChip.cherriesKey), findsOneWidget);
    // Both read out at once, whatever the face.
    expect(
      find.bySemanticsLabel(
        'Target: Cherries today: 12,400 of 50,000 · '
        'Lucky gifts today: 3,000 of 20,000 coins',
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
    await tester.pump(const Duration(seconds: 9));
    expect(find.byKey(LiveHostTargetChip.cherriesKey), findsOneWidget);
    expect(find.byKey(LiveHostTargetChip.luckyKey), findsOneWidget);
  });

  testWidgets('a reached target: a check and the gold glow', (tester) async {
    await _pump(tester, targets: targetsFixture(cherries: 50_000));
    expect(find.byKey(LiveHostTargetChip.reachedKey), findsOneWidget);
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

  testWidgets('a target switched off is left out (no turning)', (tester) async {
    await _pump(tester, targets: targetsFixture(luckyTarget: 0));
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(LiveHostTargetChip.cherriesKey), findsOneWidget);
    expect(find.byKey(LiveHostTargetChip.luckyKey), findsNothing);
  });

  testWidgets('the host: the daily tab, then monthly; the task center', (
    tester,
  ) async {
    final repo = await _pump(tester);
    await tester.tap(find.byKey(LiveHostTargetChip.chipKey));
    await tester.pumpAndSettle();
    expect(find.byKey(HostGiftStatsSheet.sheetKey), findsOneWidget);
    expect(repo.askedStats, [HostStatsPeriod.day]);
    expect(find.byKey(HostGiftStatsSheet.targetsKey), findsOneWidget);
    expect(find.byKey(HostGiftStatsSheet.taskCenterKey), findsOneWidget);
    expect(find.byKey(HostGiftStatsSheet.chartKey), findsOneWidget);
    expect(find.text('12,400 / 50,000'), findsOneWidget);
    expect(find.bySemanticsLabel('Received: 12,400'), findsOneWidget);
    expect(find.bySemanticsLabel('Value (coins): 3,000'), findsOneWidget);
    await tester.tap(
      find.byKey(HostGiftStatsSheet.periodKey(HostStatsPeriod.month)),
    );
    await tester.pumpAndSettle();
    expect(repo.askedStats, [HostStatsPeriod.day, HostStatsPeriod.month]);
    expect(find.byKey(HostGiftStatsSheet.targetsKey), findsNothing);
    expect(find.byKey(HostGiftStatsSheet.taskCenterKey), findsNothing);
    expect(find.bySemanticsLabel('Received: 186,000'), findsOneWidget);
    await tester.tap(
      find.byKey(HostGiftStatsSheet.periodKey(HostStatsPeriod.all)),
    );
    await tester.pumpAndSettle();
    expect(repo.askedStats.last, HostStatsPeriod.all);
    await tester.tap(
      find.byKey(HostGiftStatsSheet.periodKey(HostStatsPeriod.day)),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(HostGiftStatsSheet.taskCenterKey));
    await tester.tap(find.byKey(HostGiftStatsSheet.taskCenterKey));
    await tester.pumpAndSettle();
    expect(find.text('TASK CENTER'), findsOneWidget);
  });

  testWidgets('a viewer: today and the top supporters only', (tester) async {
    final repo = await _pump(tester, isHost: false);
    await tester.tap(find.byKey(LiveHostTargetChip.chipKey));
    await tester.pumpAndSettle();
    expect(find.byKey(HostTargetsPublicSheet.sheetKey), findsOneWidget);
    expect(find.byKey(HostGiftStatsSheet.sheetKey), findsNothing);
    expect(repo.askedStats, isEmpty);
    expect(find.text('Layla'), findsOneWidget);
    expect(find.text('Sara'), findsOneWidget);
    expect(find.text('3,000 / 20,000'), findsOneWidget);
  });

  for (final language in AppLanguage.values) {
    testWidgets('${language.name} at 360×800, text 1.3: chip and sheets fit', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _pump(tester, language: language);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(LiveHostTargetChip.chipKey));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (language == AppLanguage.ar) {
        expect(find.text('يومي'), findsOneWidget);
        expect(find.text('الكل'), findsOneWidget);
        expect(find.text('مركز المهام'), findsOneWidget);
      }
      for (final p in HostStatsPeriod.values) {
        await tester.tap(find.byKey(HostGiftStatsSheet.periodKey(p)));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      await tester.drag(
        find.byKey(HostGiftStatsSheet.sheetKey),
        const Offset(0, -600),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
