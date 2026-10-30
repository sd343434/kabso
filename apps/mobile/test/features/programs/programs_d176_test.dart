// D176: the Task Center and the Event Center in the layout of the owner's
// references with Kabso's colours — the daily pool's tasks (new metrics and
// where «اذهب» leads; rewards in cherries since D184 — the old coins ×10),
// the sign-in calendar
// sheet, the banner slot (hidden when none), the calendar bars' second line,
// tags and tone, the Arabic week start, and 360 × 800 at text scale 1.3.
// Server data only (fakes here).

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
import 'package:kabso_live/features/live/domain/home_banner.dart';
import 'package:kabso_live/features/live/presentation/hub/home_banner_carousel.dart';
import 'package:kabso_live/features/programs/application/programs_providers.dart';
import 'package:kabso_live/features/programs/data/programs_repository.dart';
import 'package:kabso_live/features/programs/presentation/event_calendar.dart';
import 'package:kabso_live/features/programs/presentation/event_center_screen.dart';
import 'package:kabso_live/features/programs/presentation/task_center_screen.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

final AppLocalizations _en = l10nFor(AppLanguage.en);
final AppLocalizations _ar = l10nFor(AppLanguage.ar);

ProgramTask _task(
  String code,
  TaskMetric metric, {
  int progress = 0,
  int target = 1,
  bool claimed = false,
  bool weekly = false,
}) => ProgramTask(
  code: code,
  pooled: !weekly,
  weekly: weekly,
  metric: metric,
  forHosts: weekly,
  name: code,
  target: target,
  progress: progress,
  rewardCherries: 60,
  completed: progress >= target,
  claimed: claimed,
  claimedCoins: claimed ? 0 : null,
  claimedCherries: claimed ? 60 : null,
);

MyTasks _tasks(List<ProgramTask> tasks) => MyTasks(
  dailyCapCoins: 50,
  dailyEarnedCoins: 0,
  dailyCapCherries: 500,
  band: (band: 2, level: 12, name: 'Active', host: false),
  checkIn: CheckInState(
    checkedInToday: true,
    streak: 4,
    cycleDays: 7,
    rewardCoins: 5,
    bonusCoins: 20,
    days: [
      for (var i = 0; i < 7; i++)
        CheckInDay(
          date: DateTime.utc(2026, 10, 30 + i),
          cycleDay: 5 + i > 7 ? 5 + i - 7 : 5 + i,
          today: i == 0,
          checkedIn: i == 0,
          rewardCoins: i == 2 ? 25 : 5,
        ),
    ],
  ),
  tasks: tasks,
);

final List<ProgramTask> _pool = [
  _task('P_AUDIO_ROOMS', TaskMetric.audioRooms, target: 2),
  _task('P_DM_FRIEND', TaskMetric.dmFriends),
  _task('P_STORY', TaskMetric.stories),
  _task('P_POST_COMMENTS', TaskMetric.postComments, progress: 3, target: 3),
  _task('P_LIVE_TAPS', TaskMetric.liveTaps, claimed: true, progress: 1),
  _task('P_FUTURE', TaskMetric.fromWire('SOMETHING_NEW')),
];

EventSummary _event(
  String id, {
  required DateTime start,
  required DateTime end,
  EventStatus status = EventStatus.running,
  bool featured = false,
  String? summary,
  EventTone? tone,
}) => EventSummary(
  id: id,
  title: 'Event $id',
  startsAt: start,
  endsAt: end,
  status: status,
  metric: 'GIFT_COINS_SENT',
  forHosts: false,
  permanent: false,
  featured: featured,
  summary: summary,
  tone: tone,
);

class _Programs implements ProgramsRepository {
  new({List<ProgramTask>? tasks, this.eventItems = const []})
    : tasksValue = _tasks(tasks ?? _pool);

  final MyTasks tasksValue;
  final List<EventSummary> eventItems;
  final List<String> claims = [];

  @override
  Future<MyTasks> tasks() async => tasksValue;

  @override
  Future<ProgramPayout> claim(String code) async {
    claims.add(code);
    return (paidCoins: 0, balanceCoins: 100, paidCherries: 60);
  }

  @override
  Future<EventList> events(EventTab tab, {String? month}) async => EventList(
    country: 'SA',
    events: tab == EventTab.calendar ? eventItems : const [],
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  required _Programs programs,
  AppLanguage language = AppLanguage.en,
  List<HomeBanner> banners = const [],
  Size size = const Size(393, 852),
  double textScale = 1,
}) async {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => screen),
      for (final path in [
        AppRoutes.home,
        AppRoutes.discover,
        AppRoutes.voiceRooms,
        AppRoutes.messages,
        AppRoutes.newStory,
        AppRoutes.goLive,
        AppRoutes.families,
      ])
        GoRoute(path: path, builder: (_, _) => Text('page $path')),
      GoRoute(
        path: AppRoutes.eventPattern,
        builder: (_, s) => Text('event ${s.pathParameters['eventId']}'),
      ),
    ],
  );
  await loadAppFonts();
  tester.view
    ..physicalSize = size * 3
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
        programsRepositoryProvider.overrideWithValue(programs),
        taskBannersProvider.overrideWith((ref) async => banners),
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
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The page's vertical list (the day strip and banners scroll too).
final Finder _page = find
    .descendant(
      of: find.byType(RefreshIndicator),
      matching: find.byType(Scrollable),
    )
    .first;

String _label(WidgetTester tester, String code) => tester
    .widget<Text>(
      find.descendant(
        of: find.byKey(TaskCenterScreen.actionKey(code)),
        matching: find.byType(Text),
      ),
    )
    .data!;

void main() {
  group('task center (D176)', () {
    testWidgets('pool tasks: «name (x/y)», cherries (D184), and the three pill '
        'states; an unknown metric still shows', (tester) async {
      final programs = _Programs();
      await _pump(tester, const TaskCenterScreen(), programs: programs);
      expect(find.text('P_AUDIO_ROOMS (0/2)'), findsOneWidget);
      expect(_label(tester, 'P_AUDIO_ROOMS'), _en.tasksActionGo);
      expect(_label(tester, 'P_POST_COMMENTS'), _en.tasksActionClaim);
      expect(_label(tester, 'P_LIVE_TAPS'), _en.tasksActionDone);
      // D184: «+60» with the cherry on every row (6 coins → 60 cherries).
      expect(find.text('+60'), findsWidgets);
      expect(
        find.descendant(
          of: find.byKey(TaskCenterScreen.rewardAmountKey('P_AUDIO_ROOMS')),
          matching: find.byType(KCherryIcon),
        ),
        findsOneWidget,
      );
      // No experience reward anywhere (owner 2026-10-30).
      expect(find.textContaining('EXP'), findsNothing);
      await tester.tap(
        find.byKey(TaskCenterScreen.actionKey('P_POST_COMMENTS')),
      );
      await tester.pumpAndSettle();
      expect(programs.claims, ['P_POST_COMMENTS']);
      await tester.scrollUntilVisible(
        find.byKey(TaskCenterScreen.taskKey('P_FUTURE')),
        100,
        scrollable: _page,
      );
      expect(find.text('P_FUTURE (0/1)'), findsOneWidget);
    });

    for (final (code, route) in [
      ('P_AUDIO_ROOMS', AppRoutes.voiceRooms),
      ('P_DM_FRIEND', AppRoutes.messages),
      ('P_STORY', AppRoutes.newStory),
    ]) {
      testWidgets('«Go» on $code leads to $route', (tester) async {
        await _pump(tester, const TaskCenterScreen(), programs: _Programs());
        await tester.scrollUntilVisible(
          find.byKey(TaskCenterScreen.actionKey(code)),
          100,
          scrollable: _page,
        );
        await tester.tap(find.byKey(TaskCenterScreen.actionKey(code)));
        await tester.pumpAndSettle();
        expect(find.text('page $route'), findsOneWidget);
      });
    }

    testWidgets('the sign-in card: «2 more days», «Done» when checked in, '
        'and «Calendar» opens the 7 days', (tester) async {
      await _pump(tester, const TaskCenterScreen(), programs: _Programs());
      expect(find.text(_en.tasksCheckInMoreDays(2)), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(TaskCenterScreen.checkInButtonKey),
          matching: find.text(_en.tasksActionDone),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(TaskCenterScreen.calendarKey));
      await tester.pumpAndSettle();
      expect(find.byKey(TaskCenterScreen.calendarSheetKey), findsOneWidget);
      expect(find.text(_en.tasksCalendarBody('20')), findsOneWidget);
      expect(find.text(_en.tasksDayCoins('25')), findsOneWidget);
    });

    testWidgets('the banner slot is hidden without banners', (tester) async {
      await _pump(tester, const TaskCenterScreen(), programs: _Programs());
      await tester.drag(_page, const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(find.byKey(TaskCenterScreen.bannerKey), findsNothing);
    });

    testWidgets("the banner slot shows the team's banners", (tester) async {
      await _pump(
        tester,
        const TaskCenterScreen(),
        programs: _Programs(),
        banners: const [
          HomeBanner(
            id: 'b1',
            imageUrl: 'https://example.invalid/b.webp',
            link: '/families',
          ),
        ],
      );
      await tester.scrollUntilVisible(
        find.byKey(TaskCenterScreen.bannerKey),
        100,
        scrollable: _page,
      );
      expect(find.byType(KHomeBannerCarousel), findsOneWidget);
    });

    for (final language in AppLanguage.values) {
      testWidgets('360 × 800 at text scale 1.3 (${language.name})', (
        tester,
      ) async {
        await _pump(
          tester,
          const TaskCenterScreen(),
          programs: _Programs(
            tasks: [
              ..._pool,
              _task(
                'HOST_LIVE_MINUTES',
                TaskMetric.hostLiveMinutes,
                target: 60,
                weekly: true,
              ),
            ],
          ),
          language: language,
          size: const Size(360, 800),
          textScale: 1.3,
        );
        expect(tester.takeException(), isNull);
        if (language == AppLanguage.ar) {
          expect(find.text(_ar.tasksCheckInTitle), findsOneWidget);
          // RTL: today is at the reading start (the right).
          final today = tester.getCenter(
            find.byKey(TaskCenterScreen.dayKey(0)),
          );
          final next = tester.getCenter(find.byKey(TaskCenterScreen.dayKey(1)));
          expect(today.dx, greaterThan(next.dx));
        }
      });
    }
  });

  group('event center (D176)', () {
    final october = DateTime(2026, 10);
    final events = [
      _event(
        'ended',
        start: DateTime(2026, 10, 13),
        end: DateTime(2026, 10, 21),
        status: EventStatus.ended,
        summary: 'First place wins 5,000 coins',
        tone: EventTone.teal,
      ),
      _event(
        'hot',
        start: DateTime(2026, 10),
        end: DateTime(2026, 10, 3),
        featured: true,
      ),
    ];

    testWidgets('the title «Activities»; bars with a second line, «Ended» '
        'and «Hot» tags; a bar opens the event', (tester) async {
      await _pump(
        tester,
        EventCenterScreen(initialMonth: october),
        programs: _Programs(eventItems: events),
      );
      expect(find.text(_en.eventsTitle), findsOneWidget);
      expect(find.byKey(EventCalendar.tagKey('hot')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(EventCalendar.tagKey('hot')),
          matching: find.text(_en.eventsFeatured),
        ),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.byKey(EventCalendar.barKey('ended', 2)),
        100,
        scrollable: _page,
      );
      expect(find.text('First place wins 5,000 coins'), findsWidgets);
      expect(
        find.descendant(
          of: find.byKey(EventCalendar.tagKey('ended')),
          matching: find.text(_en.eventsEnded),
        ),
        findsOneWidget,
      );
      // A two-line bar is taller than a one-line one.
      expect(
        tester.getSize(find.byKey(EventCalendar.barKey('ended', 2))).height,
        EventCalendar.barHeightTwoLines,
      );
      expect(
        tester.getSize(find.byKey(EventCalendar.barKey('hot', 0))).height,
        EventCalendar.barHeight,
      );
      // The wrapped part of the ended event (next week) carries no tag.
      expect(find.byKey(EventCalendar.barKey('ended', 3)), findsOneWidget);
      expect(eventHue(events.first), const Color(0xFF14B8A6));
      await tester.tap(find.byKey(EventCalendar.barKey('ended', 2)));
      await tester.pumpAndSettle();
      expect(find.text('event ended'), findsOneWidget);
    });

    testWidgets('Arabic: the week starts on Saturday at the right', (
      tester,
    ) async {
      await _pump(
        tester,
        EventCenterScreen(initialMonth: october),
        programs: _Programs(eventItems: events),
        language: AppLanguage.ar,
      );
      final saturday = tester.getCenter(find.text('السبت'));
      final friday = tester.getCenter(find.text('الجمعة'));
      expect(saturday.dx, greaterThan(friday.dx));
      // 1 Oct 2026 is a Thursday: the Saturday-first grid starts on 26 Sep.
      expect(find.text('26'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    for (final language in AppLanguage.values) {
      testWidgets('360 × 800 at text scale 1.3 (${language.name})', (
        tester,
      ) async {
        await _pump(
          tester,
          EventCenterScreen(initialMonth: october),
          programs: _Programs(eventItems: events),
          language: language,
          size: const Size(360, 800),
          textScale: 1.3,
        );
        await tester.drag(find.byType(Scrollable).last, const Offset(0, -600));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });
}
