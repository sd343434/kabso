// D166: the Me hub's programs — Task Center, Event Center (calendar, tabs,
// detail), SVIP and the wallet's recharge packages. Server data only
// (fakes here), loading / error / empty states, the task buttons' three
// states, the disabled «الدفع قريباً» purchase, Arabic RTL and English LTR.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/levels/application/levels_providers.dart';
import 'package:kabso_live/features/levels/domain/level_models.dart';
import 'package:kabso_live/features/live/application/live_wallet_controller.dart';
import 'package:kabso_live/features/programs/data/programs_repository.dart';
import 'package:kabso_live/features/programs/presentation/event_calendar.dart';
import 'package:kabso_live/features/programs/presentation/event_center_screen.dart';
import 'package:kabso_live/features/programs/presentation/event_detail_screen.dart';
import 'package:kabso_live/features/programs/presentation/svip_screen.dart';
import 'package:kabso_live/features/programs/presentation/task_center_screen.dart';
import 'package:kabso_live/features/wallet/data/wallet_repository.dart';
import 'package:kabso_live/features/wallet/presentation/wallet_screen.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

final AppLocalizations _en = l10nFor(AppLanguage.en);
final AppLocalizations _ar = l10nFor(AppLanguage.ar);

class _Coins extends LiveCoinsController {
  @override
  Future<int> build() async => 1250;
}

ProgramTask _task(
  String code,
  TaskMetric metric, {
  int progress = 0,
  int target = 10,
  bool claimed = false,
  bool weekly = false,
}) => ProgramTask(
  code: code,
  weekly: weekly,
  metric: metric,
  forHosts: weekly,
  name: code == 'FOLLOW_USERS' ? 'Follow other users' : code,
  target: target,
  progress: progress,
  rewardCoins: 5,
  completed: progress >= target,
  claimed: claimed,
  claimedCoins: claimed ? 5 : null,
);

MyTasks _tasks({bool checkedIn = false, List<ProgramTask>? tasks}) => MyTasks(
  dailyCapCoins: 50,
  dailyEarnedCoins: checkedIn ? 5 : 0,
  checkIn: CheckInState(
    checkedInToday: checkedIn,
    streak: 3,
    cycleDays: 7,
    rewardCoins: 5,
    bonusCoins: 20,
    days: [
      for (var i = 0; i < 7; i++)
        CheckInDay(
          date: DateTime.utc(2026, 10, 29 + i),
          cycleDay: 4 + i > 7 ? 4 + i - 7 : 4 + i,
          today: i == 0,
          checkedIn: i == 0 && checkedIn,
          rewardCoins: i == 3 ? 25 : 5,
        ),
    ],
  ),
  tasks:
      tasks ??
      [
        _task('WATCH_LIVE', TaskMetric.watchLives, target: 1),
        _task('FOLLOW_USERS', TaskMetric.follows, progress: 10),
        _task('LIVE_CHAT', TaskMetric.liveChatMessages, claimed: true),
      ],
);

EventSummary _event(
  String id, {
  required DateTime start,
  required DateTime? end,
  EventStatus status = EventStatus.running,
  bool featured = false,
  bool permanent = false,
}) => EventSummary(
  id: id,
  title: 'Event $id',
  startsAt: start,
  endsAt: end,
  status: status,
  metric: 'GIFT_COINS_RECEIVED',
  forHosts: false,
  permanent: permanent,
  featured: featured,
);

const UserSummary _winner = UserSummary(
  id: 'u-1',
  username: 'sara.m',
  displayName: 'Sara',
  avatarUrl: null,
);

SvipStatus _svip({int tier = 0}) => SvipStatus(
  tier: tier,
  expiresAt: tier == 0 ? null : DateTime.utc(2026, 11, 28),
  windowDays: 30,
  spentCoins: tier == 0 ? 12000 : 60000,
  thresholds: const [50000, 150000, 400000],
  nextTier: tier + 1,
  coinsToNext: tier == 0 ? 38000 : 90000,
  perks: [
    SvipPerk(
      code: 'BADGE',
      name: 'SVIP badge',
      unlockTier: 1,
      unlocked: tier >= 1,
      available: false,
    ),
    const SvipPerk(
      code: 'ENTRY_EFFECT',
      name: 'Entry effect',
      unlockTier: 3,
      unlocked: false,
      available: false,
    ),
  ],
);

class _FakePrograms implements ProgramsRepository {
  new({
    MyTasks? tasks,
    this.eventItems = const [],
    this.country = 'SA',
    this.svipStatus,
    this.fail = false,
    this.capOnClaim = false,
    this.packages,
  }) : tasksValue = tasks ?? _tasks();

  MyTasks tasksValue;
  final List<EventSummary> eventItems;
  final String? country;
  final SvipStatus? svipStatus;
  final bool fail;
  final bool capOnClaim;
  final List<RechargePackage>? packages;
  final List<String> claims = [];
  final List<EventTab> eventCalls = [];
  int checkIns = 0;

  @override
  Future<MyTasks> tasks() async {
    if (fail) throw const NetworkFailure.offline();
    return tasksValue;
  }

  @override
  Future<ProgramPayout> checkIn() async {
    checkIns++;
    tasksValue = _tasks(checkedIn: true);
    return (paidCoins: 5, balanceCoins: 1255);
  }

  @override
  Future<ProgramPayout> claim(String code) async {
    claims.add(code);
    if (capOnClaim) {
      throw const ServerFailure(
        code: ErrorCode.unknown,
        rawCode: 'TASK_DAILY_CAP_REACHED',
        debugMessage: 'cap',
        statusCode: 409,
      );
    }
    return (paidCoins: 5, balanceCoins: 1255);
  }

  @override
  Future<SvipStatus> svip() async {
    if (fail) throw const NetworkFailure.offline();
    return svipStatus ?? _svip();
  }

  @override
  Future<EventList> events(EventTab tab, {String? month}) async {
    eventCalls.add(tab);
    if (fail) throw const NetworkFailure.offline();
    return EventList(
      country: country,
      events: [
        for (final e in eventItems)
          if ((tab == EventTab.permanent) == e.permanent) e,
      ],
    );
  }

  @override
  Future<EventDetail> event(String eventId) async => EventDetail(
    id: eventId,
    title: 'Stars of the week',
    startsAt: DateTime.utc(2026, 10, 5),
    endsAt: DateTime.utc(2026, 10, 12),
    status: EventStatus.ended,
    metric: 'GIFT_COINS_RECEIVED',
    forHosts: false,
    permanent: false,
    featured: true,
    rules: 'Receive the most gifts.',
    prizes: const [
      (rankFrom: 1, rankTo: 1, coins: 500),
      (rankFrom: 2, rankTo: 10, coins: 100),
    ],
  );

  @override
  Future<EventLeaderboard> leaderboard(String eventId) async =>
      const EventLeaderboard(
        isFinal: true,
        rows: [(rank: 1, user: _winner, score: 1200, prizeCoins: 500)],
        myScore: 0,
        myPrize: 0,
      );

  @override
  Future<RechargeOffer> rechargePackages() async {
    if (fail) throw const NetworkFailure.offline();
    return RechargeOffer(
      currency: 'USD',
      purchasesEnabled: false,
      packages:
          packages ??
          const [
            RechargePackage(
              id: 'p1',
              coins: 10,
              bonusCoins: 20,
              priceMinor: 29,
            ),
            RechargePackage(
              id: 'p2',
              coins: 38,
              bonusCoins: 20,
              priceMinor: 99,
            ),
            RechargePackage(
              id: 'p3',
              coins: 276,
              bonusCoins: 28,
              priceMinor: 699,
              originalPriceMinor: 800,
            ),
            RechargePackage(
              id: 'p4',
              coins: 800,
              bonusCoins: 30,
              priceMinor: 1999,
            ),
          ],
    );
  }
}

class _FakeWallet implements WalletRepository {
  @override
  Future<WalletPage<WalletLedgerEntry>> ledger({String? cursor}) async => (
    items: [
      WalletLedgerEntry(
        id: 'l1',
        reason: WalletLedgerReason.taskReward,
        delta: 5,
        balanceAfter: 1250,
        createdAt: DateTime.utc(2026, 10, 29, 9),
      ),
    ],
    next: null,
  );

  @override
  Future<MyEarnings> earnings() async => const MyEarnings(
    totalCoins: 0,
    last7DaysCoins: 0,
    last30DaysCoins: 0,
    sendCount: 0,
  );

  @override
  Future<WalletPage<Earning>> earningHistory({String? cursor}) async =>
      (items: const <Earning>[], next: null);
}

List<LevelSummary> _levels() => [
  LevelSummary(
    category: LevelCategory.support,
    available: true,
    name: 'Support',
    description: '',
    points: BigInt.from(1450),
    level: LevelBrief(
      levelNumber: 3,
      name: 'Activator',
      requiredPoints: BigInt.zero,
    ),
    progressPercent: 12.5,
  ),
];

Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  required _FakePrograms programs,
  AppLanguage language = AppLanguage.en,
  List<Override> extra = const [],
}) async {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => screen),
      for (final path in [
        AppRoutes.home,
        AppRoutes.discover,
        AppRoutes.goLive,
        AppRoutes.levels,
      ])
        GoRoute(path: path, builder: (_, _) => Text('page $path')),
      GoRoute(
        path: AppRoutes.eventPattern,
        builder: (_, s) => Text('event ${s.pathParameters['eventId']}'),
      ),
    ],
  );
  await loadAppFonts();
  setViewport(tester, GoldenViewport.android);
  final prefs = await testPrefs(language: language.name);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
        currentUserProvider.overrideWithValue(testUser()),
        liveCoinsProvider.overrideWith(_Coins.new),
        programsRepositoryProvider.overrideWithValue(programs),
        walletRepositoryProvider.overrideWithValue(_FakeWallet()),
        myLevelsProvider.overrideWith((ref) => _levels()),
        ...extra,
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
  group('calendar layout', () {
    final october = DateTime(2026, 10);

    test('weeks start on the locale day; days outside the month fill', () {
      final sunday = layoutMonth(october, 0, const []);
      // 1 Oct 2026 is a Thursday: Sunday-first grid starts on 27 Sep.
      expect(sunday.first.days.first, DateTime(2026, 9, 27));
      expect(sunday, hasLength(5));
      final saturday = layoutMonth(october, 6, const []);
      expect(saturday.first.days.first, DateTime(2026, 9, 26));
      expect(saturday.last.days.last.month, 11);
    });

    test('an event spans its days and wraps across weeks', () {
      final e = _event(
        'a',
        start: DateTime(2026, 10, 2, 10),
        end: DateTime(2026, 10, 9),
      );
      final weeks = layoutMonth(october, 0, [e]);
      final first = weeks[0].segments.single;
      expect((first.startCol, first.endCol), (5, 6));
      expect(first.continuesAfter, isTrue);
      final second = weeks[1].segments.single;
      // The end is exclusive: 9 Oct 00:00 → the last day is 8 Oct.
      expect((second.startCol, second.endCol), (0, 4));
      expect(second.continuesBefore, isTrue);
      expect(second.continuesAfter, isFalse);
    });

    test('overlapping events take separate lanes', () {
      final weeks = layoutMonth(october, 0, [
        _event('a', start: DateTime(2026, 10, 11), end: DateTime(2026, 10, 15)),
        _event('b', start: DateTime(2026, 10, 13), end: DateTime(2026, 10, 18)),
        _event('c', start: DateTime(2026, 10, 15), end: DateTime(2026, 10, 16)),
      ]);
      final lanes = {for (final s in weeks[2].segments) s.event.id: s.lane};
      expect(lanes, {'a': 0, 'b': 1, 'c': 0});
      expect(weeks[2].lanes, 2);
    });
  });

  group('task center', () {
    testWidgets('the level card, the check-in strip and the three button '
        'states: go, claim and done', (tester) async {
      final programs = _FakePrograms();
      await _pump(tester, const TaskCenterScreen(), programs: programs);
      expect(find.byKey(TaskCenterScreen.levelCardKey), findsOneWidget);
      expect(find.text('Activator'), findsOneWidget);
      expect(find.text(_en.tasksLevelPoints('1,450')), findsOneWidget);
      expect(find.byKey(TaskCenterScreen.dayKey(6)), findsOneWidget);
      expect(find.text(_en.tasksCheckInToBonus('4', '20')), findsOneWidget);
      expect(find.text('Follow other users (10/10)'), findsOneWidget);
      Finder action(String code) => find.descendant(
        of: find.byKey(TaskCenterScreen.actionKey(code)),
        matching: find.byType(Text),
      );
      expect(tester.widget<Text>(action('WATCH_LIVE')).data, _en.tasksActionGo);
      expect(
        tester.widget<Text>(action('FOLLOW_USERS')).data,
        _en.tasksActionClaim,
      );
      expect(
        tester.widget<Text>(action('LIVE_CHAT')).data,
        _en.tasksActionDone,
      );

      await tester.tap(find.byKey(TaskCenterScreen.actionKey('FOLLOW_USERS')));
      await tester.pumpAndSettle();
      expect(programs.claims, ['FOLLOW_USERS']);
      expect(find.text(_en.tasksRewardReceived('5')), findsOneWidget);

      // A claimed task does nothing.
      await tester.tap(find.byKey(TaskCenterScreen.actionKey('LIVE_CHAT')));
      await tester.pumpAndSettle();
      expect(programs.claims, ['FOLLOW_USERS']);
    });

    testWidgets('check-in once; then «Done» and disabled', (tester) async {
      final programs = _FakePrograms();
      await _pump(tester, const TaskCenterScreen(), programs: programs);
      await tester.tap(find.byKey(TaskCenterScreen.checkInButtonKey));
      await tester.pumpAndSettle();
      expect(programs.checkIns, 1);
      final label = find.descendant(
        of: find.byKey(TaskCenterScreen.checkInButtonKey),
        matching: find.text(_en.tasksActionDone),
      );
      expect(label, findsOneWidget);
      await tester.tap(find.byKey(TaskCenterScreen.checkInButtonKey));
      await tester.pumpAndSettle();
      expect(programs.checkIns, 1);
    });

    testWidgets('the daily cap refusal has its own message', (tester) async {
      await _pump(
        tester,
        const TaskCenterScreen(),
        programs: _FakePrograms(capOnClaim: true),
      );
      await tester.tap(find.byKey(TaskCenterScreen.actionKey('FOLLOW_USERS')));
      await tester.pumpAndSettle();
      expect(find.text(_en.tasksCapReached), findsOneWidget);
    });

    testWidgets('«Go» leads to where the task is done', (tester) async {
      await _pump(tester, const TaskCenterScreen(), programs: _FakePrograms());
      await tester.tap(find.byKey(TaskCenterScreen.actionKey('WATCH_LIVE')));
      await tester.pumpAndSettle();
      expect(find.text('page ${AppRoutes.home}'), findsOneWidget);
    });

    testWidgets('weekly tab: honest empty state for non-hosts', (tester) async {
      await _pump(tester, const TaskCenterScreen(), programs: _FakePrograms());
      await tester.tap(find.text(_en.tasksTabWeekly));
      await tester.pumpAndSettle();
      expect(find.byKey(TaskCenterScreen.weeklyEmptyKey), findsOneWidget);
      expect(find.byKey(TaskCenterScreen.checkInKey), findsNothing);
    });

    testWidgets('weekly host tasks with their progress', (tester) async {
      await _pump(
        tester,
        const TaskCenterScreen(),
        programs: _FakePrograms(
          tasks: _tasks(
            tasks: [
              _task(
                'HOST_GIFT_COINS',
                TaskMetric.hostGiftCoins,
                progress: 100,
                target: 1000,
                weekly: true,
              ),
            ],
          ),
        ),
      );
      await tester.tap(find.text(_en.tasksTabWeekly));
      await tester.pumpAndSettle();
      expect(find.text('HOST_GIFT_COINS (100/1000)'), findsOneWidget);
    });

    testWidgets('a failure shows the error with a retry', (tester) async {
      await _pump(
        tester,
        const TaskCenterScreen(),
        programs: _FakePrograms(fail: true),
      );
      expect(find.text(_en.tasksLoadError), findsOneWidget);
      expect(find.text(_en.actionRetry), findsOneWidget);
    });

    testWidgets('Arabic: right to left, Arabic labels', (tester) async {
      await _pump(
        tester,
        const TaskCenterScreen(),
        programs: _FakePrograms(),
        language: AppLanguage.ar,
      );
      expect(find.text(_ar.tasksTabDaily), findsOneWidget);
      final today = tester.getCenter(find.byKey(TaskCenterScreen.dayKey(0)));
      final last = tester.getCenter(find.byKey(TaskCenterScreen.dayKey(6)));
      expect(today.dx, greaterThan(last.dx));
      expect(tester.takeException(), isNull);
    });
  });

  group('event center', () {
    final now = DateTime(2026, 10, 15);

    testWidgets('the intro, the month and a tappable event bar', (
      tester,
    ) async {
      final programs = _FakePrograms(
        eventItems: [
          _event(
            'e1',
            start: DateTime(2026, 10, 13),
            end: DateTime(2026, 10, 20),
            featured: true,
          ),
        ],
      );
      await _pump(
        tester,
        EventCenterScreen(initialMonth: now),
        programs: programs,
      );
      expect(find.byKey(EventCenterScreen.introKey), findsOneWidget);
      expect(
        find.text(_en.eventsCalendarMonth('October 2026')),
        findsOneWidget,
      );
      expect(find.byKey(EventCalendar.barKey('e1', 2)), findsOneWidget);
      await tester.tap(find.byKey(EventCalendar.barKey('e1', 2)));
      await tester.pumpAndSettle();
      expect(find.text('event e1'), findsOneWidget);
    });

    testWidgets('an empty month says so (never sample events)', (tester) async {
      await _pump(
        tester,
        EventCenterScreen(initialMonth: now),
        programs: _FakePrograms(),
      );
      await tester.scrollUntilVisible(
        find.byKey(EventCenterScreen.emptyKey),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text(_en.eventsEmptyMonth), findsOneWidget);
      await tester.tap(find.byKey(EventCenterScreen.nextKey));
      await tester.pumpAndSettle();
      expect(
        find.text(_en.eventsCalendarMonth('November 2026')),
        findsOneWidget,
      );
    });

    testWidgets('permanent and regional tabs', (tester) async {
      final programs = _FakePrograms(
        country: null,
        eventItems: [
          _event('p1', start: DateTime(2026, 9), end: null, permanent: true),
        ],
      );
      await _pump(
        tester,
        EventCenterScreen(initialMonth: now),
        programs: programs,
      );
      await tester.tap(find.text(_en.eventsTabPermanent));
      await tester.pumpAndSettle();
      expect(find.byKey(EventCenterScreen.eventKey('p1')), findsOneWidget);
      // The third tab may start off-screen at 360 lp (the tabs scroll).
      await tester.ensureVisible(find.text(_en.eventsTabRegional));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_en.eventsTabRegional));
      await tester.pumpAndSettle();
      expect(find.text(_en.eventsNoCountry), findsOneWidget);
    });

    testWidgets('a failure shows the error with a retry', (tester) async {
      await _pump(
        tester,
        EventCenterScreen(initialMonth: now),
        programs: _FakePrograms(fail: true),
      );
      expect(find.text(_en.eventsLoadError), findsOneWidget);
    });

    testWidgets('Arabic calendar mirrors (RTL)', (tester) async {
      await _pump(
        tester,
        EventCenterScreen(initialMonth: now),
        programs: _FakePrograms(),
        language: AppLanguage.ar,
      );
      expect(find.text(_ar.eventsTabCalendar), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the detail: rules, prizes and the final board', (
      tester,
    ) async {
      await _pump(
        tester,
        const EventDetailScreen(eventId: 'e1'),
        programs: _FakePrograms(),
      );
      expect(find.text('Stars of the week'), findsOneWidget);
      expect(find.text('Receive the most gifts.'), findsOneWidget);
      expect(find.text(_en.eventsRank('1')), findsOneWidget);
      expect(find.text(_en.eventsRanks('2', '10')), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(EventDetailScreen.rankKey(1)),
        100,
      );
      expect(find.text('Sara'), findsOneWidget);
      expect(find.text(_en.eventsMeNotRanked), findsOneWidget);
    });
  });

  group('svip', () {
    testWidgets('not SVIP yet: status, track, perks «Soon», the bar', (
      tester,
    ) async {
      await _pump(tester, const SvipScreen(), programs: _FakePrograms());
      expect(find.text(_en.svipNotYet), findsWidgets);
      expect(find.byKey(SvipScreen.nodeKey(3)), findsOneWidget);
      expect(
        find.text(_en.svipSpendMore('38,000', _en.svipTier('1'))),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.byKey(SvipScreen.perkKey('BADGE')),
        100,
      );
      // No perk is shown as active: each says «Soon».
      expect(find.text(_en.liveSoon), findsNWidgets(2));
      await tester.tap(find.byKey(SvipScreen.ctaKey));
      await tester.pumpAndSettle();
      expect(find.text('page ${AppRoutes.home}'), findsOneWidget);
    });

    testWidgets('SVIP 1 until a date', (tester) async {
      await _pump(
        tester,
        const SvipScreen(),
        programs: _FakePrograms(svipStatus: _svip(tier: 1)),
      );
      expect(
        find.text(_en.svipUntil(_en.svipTier('1'), '28 Nov 2026')),
        findsOneWidget,
      );
    });

    testWidgets('a failure shows the error with a retry', (tester) async {
      await _pump(
        tester,
        const SvipScreen(),
        programs: _FakePrograms(fail: true),
      );
      expect(find.text(_en.svipLoadError), findsOneWidget);
    });
  });

  group('wallet recharge', () {
    testWidgets('packages from the server, the deal ribbon, the selection; '
        'the purchase stays disabled (B5)', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester, const WalletScreen(), programs: _FakePrograms());
      expect(find.byKey(WalletScreen.packageKey('p4')), findsOneWidget);
      expect(find.text(r'$6.99'), findsOneWidget);
      expect(find.text(r'$8.00'), findsOneWidget);
      expect(find.text(_en.walletOffer), findsOneWidget);
      final node = tester.getSemantics(find.byKey(WalletScreen.rechargeKey));
      expect(node.label, _en.meHubSoonItem(_en.walletGetCoins('30', r'$0.29')));
      expect(node.flagsCollection.isEnabled.toBoolOrNull(), isFalse);
      await tester.tap(find.byKey(WalletScreen.packageKey('p3')));
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.byKey(WalletScreen.rechargeKey)).label,
        _en.meHubSoonItem(_en.walletGetCoins('304', r'$6.99')),
      );
      expect(find.text(_en.walletRechargeSoon), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('the history icon opens the history tab', (tester) async {
      await _pump(tester, const WalletScreen(), programs: _FakePrograms());
      await tester.tap(find.byKey(WalletScreen.historyButtonKey));
      await tester.pumpAndSettle();
      expect(find.text(_en.walletReasonTaskReward), findsOneWidget);
    });

    testWidgets('no packages configured: an empty state', (tester) async {
      await _pump(
        tester,
        const WalletScreen(),
        programs: _FakePrograms(packages: const []),
      );
      expect(find.byKey(WalletScreen.packagesEmptyKey), findsOneWidget);
    });
  });
}
