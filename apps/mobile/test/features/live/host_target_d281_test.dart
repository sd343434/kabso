// D281 (owner, CONVENTIONS §10.62.2, §10.41.4): «الأهداف الذكية» — the host's
// three smart targets of today at three levels («سهل / متوسط / صعب») on the
// «تارجت» chip (one face at a time: the mark, the level, the progress, the
// reward; all three compact under reduced motion) and in the sheet (each
// with its mark — the gift's own picture for a gift target —, the level, the
// title, the progress and the reward in locked cherries, «تم ✓» once paid);
// the cherry history's new reason; the Task Center's chosen-gift task with
// the gift's picture and the new metrics. A fixed clock (the sheet's
// countdown), no device.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/data/live_host_targets_repository.dart';
import 'package:kabso_live/features/live/presentation/widgets/host_target_badge.dart';
import 'package:kabso_live/features/live/presentation/widgets/host_target_sheet.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_gift_art.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_host_target_chip.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_viewer_parts.dart';
import 'package:kabso_live/features/programs/application/programs_providers.dart';
import 'package:kabso_live/features/programs/data/programs_repository.dart';
import 'package:kabso_live/features/programs/presentation/task_center_screen.dart';
import 'package:kabso_live/features/wallet/data/cherry_repository.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_live_host_targets_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

/// The server's `LiveHostTargets` with three smart targets (a gift count of
/// «المحارب», a supporters target paid, a hard cherries target in a window).
Map<String, Object?> d281Json({String lang = 'ar'}) => {
  'day': '2027-01-14',
  'timeZone': 'Asia/Riyadh',
  'endsAt': '2027-01-14T21:00:00.000Z',
  'band': 2,
  'gifts': {'received': 1_250_000, 'target': 0, 'reached': false},
  'cherries': {'received': 1_250_000, 'target': 0, 'reached': false},
  'lucky': {'received': 40, 'target': 0, 'reached': false},
  'topSupporters': const <Object?>[],
  'luckySupporters': const <Object?>[],
  'me': null,
  'daily': [
    {
      'level': 'EASY',
      'code': 'T.GIFT_COUNT.warrior.100.0-1440',
      'kind': 'GIFT_COUNT',
      'title': lang == 'ar'
          ? 'استقبل 100 هدية من المحارب'
          : 'Receive 100 × Warrior',
      'amount': 100,
      'progress': 37,
      'reached': false,
      'rewardCherries': 7_295,
      'rewardBps': 150,
      'paidCherries': null,
      'locked': true,
      'window': null,
      'gift': {
        'code': 'warrior',
        'name': lang == 'ar' ? 'المحارب' : 'Warrior',
        'assetKey': 'gift_warrior',
        'imageUrl': null,
      },
      'category': null,
    },
    {
      'level': 'MEDIUM',
      'code': 'T.SUPPORTERS.*.8.0-1440',
      'kind': 'SUPPORTERS',
      'title': lang == 'ar' ? '8 داعمين مختلفين' : '8 different supporters',
      'amount': 8,
      'progress': 8,
      'reached': true,
      'rewardCherries': 12_000,
      'rewardBps': 250,
      'paidCherries': 11_870,
      'locked': true,
      'window': null,
      'gift': null,
      'category': null,
    },
    {
      'level': 'HARD',
      'code': 'T.GIFT_CHERRIES.*.3000000.1200-1440',
      'kind': 'GIFT_CHERRIES',
      'title': lang == 'ar'
          ? 'هدف الهدايا: 3,000,000 كرزة من 20:00 إلى 24:00'
          : 'Gifts target: 3,000,000 cherries between 20:00–24:00',
      'amount': 3_000_000,
      'progress': 1_250_000,
      'reached': false,
      'rewardCherries': 89_790,
      'rewardBps': 400,
      'paidCherries': null,
      'locked': true,
      'window': {'from': '20:00', 'to': '24:00'},
      'gift': null,
      'category': null,
    },
  ],
};

Future<void> _pumpChip(
  WidgetTester tester,
  AppLanguage language, {
  bool reduced = false,
  Size? size,
  double textScale = 1,
}) async {
  HostTargetSheet.clock = () => DateTime.utc(2027, 1, 14, 15);
  addTearDown(() => HostTargetSheet.clock = DateTime.now);
  setViewport(tester, GoldenViewport.phone);
  if (size != null) {
    tester.view
      ..physicalSize = size * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }
  final repo = FakeLiveHostTargetsRepository(
    byHost: {'host': LiveHostTargets.fromJson(d281Json(lang: language.name))},
  );
  await pumpScreen(
    tester,
    Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: reduced,
          textScaler: TextScaler.linear(textScale),
        ),
        child: const Scaffold(
          backgroundColor: Color(0xFF2A2333),
          body: Padding(
            padding: EdgeInsets.fromLTRB(12, 60, 12, 0),
            child: KRoomChipsRow(
              roomNumber: 1,
              targetChip: LiveHostTargetChip(username: 'host', isHost: false),
            ),
          ),
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

class _Programs implements ProgramsRepository {
  new(this.value);

  final MyTasks value;

  @override
  Future<MyTasks> tasks() async => value;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

MyTasks _myTasks(List<ProgramTask> tasks) => MyTasks(
  dailyCapCoins: 50,
  dailyEarnedCoins: 0,
  dailyCapCherries: 50000,
  band: (band: 2, level: 12, name: 'Active', host: false),
  checkIn: CheckInState(
    checkedInToday: true,
    streak: 1,
    cycleDays: 7,
    rewardCoins: 5,
    bonusCoins: 20,
    days: [
      for (var i = 0; i < 7; i++)
        CheckInDay(
          date: DateTime.utc(2027, 1, 14 + i),
          cycleDay: i + 1,
          today: i == 0,
          checkedIn: i == 0,
          rewardCoins: 5,
        ),
    ],
  ),
  tasks: tasks,
);

Future<void> _pumpTasks(
  WidgetTester tester,
  List<ProgramTask> tasks, {
  AppLanguage language = AppLanguage.en,
}) async {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const TaskCenterScreen()),
      for (final path in [AppRoutes.home, AppRoutes.families, AppRoutes.goLive])
        GoRoute(path: path, builder: (_, _) => Text('page $path')),
    ],
  );
  await loadAppFonts();
  tester.view
    ..physicalSize = const Size(393, 852) * 3
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final prefs = await testPrefs(language: language.name);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
        currentUserProvider.overrideWithValue(testUser()),
        programsRepositoryProvider.overrideWithValue(
          _Programs(_myTasks(tasks)),
        ),
        taskBannersProvider.overrideWith((ref) async => const []),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: language.locale,
        supportedLocales: KabsoApp.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        theme: buildAppTheme(
          brightness: Brightness.light,
          locale: language.locale,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('reads the three smart targets (gift, window, paid); none from an '
      'older server', () {
    final t = LiveHostTargets.fromJson(d281Json());
    expect(t.daily.map((x) => x.level), TargetLevel.values);
    final easy = t.daily[0];
    expect([easy.kind, easy.amount, easy.progress], ['GIFT_COUNT', 100, 37]);
    expect(easy.gift?.code, 'warrior');
    expect(easy.gift?.name, 'المحارب');
    expect(easy.fraction, closeTo(0.37, 1e-9));
    expect(easy.paid, isFalse);
    expect(easy.shownReward, 7_295);
    final medium = t.daily[1];
    expect([medium.paid, medium.shownReward], [true, 11_870]);
    final hard = t.daily[2];
    expect([hard.windowFrom, hard.windowTo], ['20:00', '24:00']);
    expect(hard.lucky, isFalse);
    final old = LiveHostTargets.fromJson({...d281Json()}..remove('daily'));
    expect(old.daily, isEmpty);
    // The cherry history knows the new reason.
    expect(
      CherryLedgerReason.fromWire('HOST_TARGET_REWARD'),
      CherryLedgerReason.hostTargetReward,
    );
  });

  for (final language in AppLanguage.values) {
    final ar = language == AppLanguage.ar;
    testWidgets('the chip turns through easy / medium / hard with the '
        'level, progress and reward (${language.name})', (tester) async {
      LiveHostTargetChip.debugIgnoreReducedMotion = true;
      addTearDown(() => LiveHostTargetChip.debugIgnoreReducedMotion = false);
      await _pumpChip(tester, language);
      final chip = find.byKey(LiveHostTargetChip.chipKey);
      expect(chip, findsOneWidget);
      final l10n = l10nFor(language);
      // EASY first: the warrior's own picture, «سهل», 37/100 and +7.2K.
      expect(
        find.byKey(LiveHostTargetChip.dailyKey(TargetLevel.easy)),
        findsOneWidget,
      );
      expect(
        find.byKey(KDailyTargetBadge.giftKeyOf(TargetLevel.easy)),
        findsOneWidget,
      );
      expect(find.byType(KGiftImage), findsOneWidget);
      expect(find.text(l10n.liveTargetLevelEasy), findsOneWidget);
      expect(find.text('37/100'), findsOneWidget);
      expect(find.text('+7.2K'), findsOneWidget);
      // MEDIUM: reached (the check and the glow), paid 11.8K.
      await tester.pump(LiveHostTargetChip.rotateEvery);
      await tester.pump(const Duration(seconds: 1));
      expect(
        find.byKey(LiveHostTargetChip.dailyKey(TargetLevel.medium)),
        findsOneWidget,
      );
      expect(find.text(l10n.liveTargetLevelMedium), findsOneWidget);
      expect(find.byKey(LiveHostTargetChip.reachedKey), findsOneWidget);
      expect(find.text('+11.8K'), findsOneWidget);
      // HARD: the gift-box badge (a cherries target), 1.2M/3M, +89.7K.
      await tester.pump(LiveHostTargetChip.rotateEvery);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text(l10n.liveTargetLevelHard), findsOneWidget);
      expect(find.text('1.2M/3M'), findsOneWidget);
      expect(find.text('+89.7K'), findsOneWidget);
      expect(
        find.byKey(KHostTargetBadge.keyOf(HostTargetKind.gifts)),
        findsOneWidget,
      );
      // The label reads all three.
      final label = tester.getSemantics(chip).label;
      expect(label, contains(ar ? 'سهل' : 'Easy'));
      expect(label, contains('89,790'));
      expect(label, contains(ar ? 'استقبل 100 هدية من المحارب' : 'Warrior'));
    });

    testWidgets('reduced motion: all three compact side by side '
        '(${language.name})', (tester) async {
      await _pumpChip(tester, language, reduced: true);
      for (final level in TargetLevel.values) {
        expect(find.byKey(LiveHostTargetChip.dailyKey(level)), findsOneWidget);
      }
      // Compact: the share done of each.
      expect(find.text('37%'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
      expect(find.text('41%'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the sheet: three rows with the level, title, progress and '
        'the reward in locked cherries; «done» once paid (${language.name})', (
      tester,
    ) async {
      await _pumpChip(tester, language);
      await tester.tap(find.byKey(LiveHostTargetChip.chipKey));
      await tester.pumpAndSettle();
      final l10n = l10nFor(language);
      final block = find.byKey(HostTargetSheet.targetsKey);
      expect(block, findsOneWidget);
      for (final level in TargetLevel.values) {
        expect(find.byKey(HostTargetSheet.dailyKey(level)), findsOneWidget);
      }
      Text reward(TargetLevel level) =>
          tester.widget<Text>(find.byKey(HostTargetSheet.rewardKey(level)));
      expect(
        reward(TargetLevel.easy).data,
        l10n.liveTargetRewardLocked('7,295'),
      );
      expect(
        reward(TargetLevel.medium).data,
        l10n.liveTargetRewardPaid('11,870'),
      );
      expect(
        reward(TargetLevel.hard).data,
        l10n.liveTargetRewardLocked('89,790'),
      );
      expect(find.text('37 / 100'), findsOneWidget);
      expect(find.text('1,250,000 / 3,000,000'), findsOneWidget);
      expect(
        find.text(
          ar
              ? 'هدف الهدايا: 3,000,000 كرزة من 20:00 إلى 24:00'
              : 'Gifts target: 3,000,000 cherries between 20:00–24:00',
        ),
        findsOneWidget,
      );
      // The gift target shows the gift's picture in the sheet too.
      expect(
        find.descendant(
          of: block,
          matching: find.byKey(KDailyTargetBadge.giftKeyOf(TargetLevel.easy)),
        ),
        findsOneWidget,
      );
      expect(find.text(l10n.liveTargetRewardHint), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('360 × 800 at text scale 1.3: no overflow (${language.name})', (
      tester,
    ) async {
      await _pumpChip(
        tester,
        language,
        size: const Size(360, 800),
        textScale: 1.3,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(LiveHostTargetChip.chipKey));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Task Center: a chosen-gift task shows the gift; the new '
      'metrics have their icons and «Go»', (tester) async {
    await _pumpTasks(tester, [
      ProgramTask(
        code: 'P_SEND_GIFT_OF',
        weekly: false,
        pooled: true,
        metric: TaskMetric.fromWire('GIFT_COUNT_SENT'),
        forHosts: false,
        name: 'Send 2 × Rose',
        target: 2,
        progress: 1,
        rewardCherries: 20,
        completed: false,
        claimed: false,
        gift: const TaskGift(code: 'rose', name: 'Rose', assetKey: 'gift_rose'),
      ),
      ProgramTask.fromJson(const {
        'code': 'P_FAMILY_JOIN',
        'pooled': true,
        'period': 'DAILY',
        'metric': 'FAMILY_JOIN',
        'audience': 'EVERYONE',
        'name': 'Join a family',
        'gift': null,
        'window': {'from': '20:00', 'to': '23:00'},
        'target': 1,
        'progress': 0,
        'rewardCoins': 0,
        'rewardCherries': 300,
        'completed': false,
        'claimed': false,
        'claimedCoins': null,
        'claimedCherries': null,
      }),
    ]);
    expect(
      find.byKey(TaskCenterScreen.giftKey('P_SEND_GIFT_OF')),
      findsOneWidget,
    );
    expect(find.text('Send 2 × Rose (1/2)'), findsOneWidget);
    expect(find.byIcon(Icons.groups_rounded), findsOneWidget);
    expect(TaskMetric.fromWire('PK_BATTLES'), TaskMetric.pkBattles);
    // «Go» on «join a family» opens the families hub.
    await tester.tap(find.byKey(TaskCenterScreen.actionKey('P_FAMILY_JOIN')));
    await tester.pumpAndSettle();
    expect(find.text('page ${AppRoutes.families}'), findsOneWidget);
  });
}
