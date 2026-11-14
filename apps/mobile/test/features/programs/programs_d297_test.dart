// D297 (owner: «مهام خاصة بصناع المحتوى، وقيمتها كمهام المضيف»): the Task
// Center shows a creator-programme member's creator tasks in their own cards
// «مهام صانع المحتوى» (today) and «مهام صانع المحتوى الأسبوعية» (this week),
// each new metric with its icon and «اذهب» to where it is done; nobody else
// gets the cards. Arabic and English, 360 × 800 at text scale 1.3. Server
// data only (fakes here, shaped like `GET /me/tasks`).

import 'dart:convert';
import 'dart:io';

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
import 'package:kabso_live/features/programs/application/programs_providers.dart';
import 'package:kabso_live/features/programs/data/programs_repository.dart';
import 'package:kabso_live/features/programs/presentation/task_center_screen.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

final AppLocalizations _en = l10nFor(AppLanguage.en);
final AppLocalizations _ar = l10nFor(AppLanguage.ar);

/// One `ProgramTask` as the server sends it.
Map<String, dynamic> d297TaskJson(
  String code,
  String metric, {
  String audience = 'CREATORS',
  String period = 'DAILY',
  String? name,
  int progress = 0,
  int target = 1,
  int reward = 4000,
  bool claimed = false,
}) => {
  'code': code,
  'pooled': period == 'DAILY',
  'period': period,
  'metric': metric,
  'audience': audience,
  'name': name ?? code,
  'gift': null,
  'window': null,
  'target': target,
  'progress': progress > target ? target : progress,
  'rewardCoins': 0,
  'rewardCherries': reward,
  'completed': progress >= target,
  'claimed': claimed,
  'claimedCoins': claimed ? 0 : null,
  'claimedCherries': claimed ? reward : null,
};

/// A creator's `MyTasks` (band 1) with today's and this week's creator tasks.
Map<String, dynamic> d297MyTasksJson({
  bool creator = true,
  bool arabic = false,
}) {
  String n(String ar, String en) => arabic ? ar : en;
  return {
    'day': '2026-11-06',
    'timeZone': 'Asia/Riyadh',
    'dayStartsAt': '2026-11-05T21:00:00.000Z',
    'dayResetsAt': '2026-11-06T21:00:00.000Z',
    'weekStartsAt': '2026-11-01T21:00:00.000Z',
    'weekResetsAt': '2026-11-08T21:00:00.000Z',
    'dailyCapCoins': 50,
    'dailyEarnedCoins': 5,
    'dailyCapCherries': 50000,
    'dailyEarnedCherries': 4000,
    'monthlyCapCherries': 4545454,
    'monthlyEarnedCherries': 4000,
    'band': {
      'band': 1,
      'level': 0,
      'name': n('مبتدئ', 'Starter'),
      'host': false,
      'creator': creator,
    },
    'checkIn': {
      'checkedInToday': true,
      'streak': 3,
      'cycleDays': 7,
      'rewardCoins': 5,
      'bonusCoins': 20,
      'days': [
        for (var i = 0; i < 7; i++)
          {
            'date': '2026-11-${(6 + i).toString().padLeft(2, '0')}',
            'cycleDay': 3 + i > 7 ? 3 + i - 7 : 3 + i,
            'today': i == 0,
            'checkedIn': i == 0,
            'rewardCoins': i == 4 ? 25 : 5,
          },
      ],
    },
    'tasks': [
      if (creator) ...[
        d297TaskJson(
          'P_CR_REEL',
          'REELS',
          name: n('انشر مقاطع ريلز', 'Publish reels'),
          progress: 1,
          claimed: true,
        ),
        d297TaskJson(
          'P_CR_VIEWS',
          'REEL_VIEWS_RECEIVED',
          name: n('مشاهدات ريلزك اليوم', 'Views on your reels today'),
          progress: 64,
          target: 100,
          reward: 3000,
        ),
      ],
      d297TaskJson(
        'P_FOLLOW',
        'FOLLOWS',
        audience: 'EVERYONE',
        name: n('تابع مستخدمين آخرين', 'Follow other users'),
        reward: 300,
      ),
      d297TaskJson(
        'P_LIVE_COMMENTS',
        'LIVE_CHAT_MESSAGES',
        audience: 'EVERYONE',
        name: n('علّق في بث مباشر', 'Comment in a live'),
        progress: 3,
        target: 3,
        reward: 300,
      ),
      if (creator) ...[
        d297TaskJson(
          'CREATOR_WEEKLY_REELS',
          'REELS',
          period: 'WEEKLY',
          name: n('انشر ريلز هذا الأسبوع', 'Publish reels this week'),
          progress: 5,
          target: 5,
          reward: 180000,
        ),
        d297TaskJson(
          'CREATOR_WEEKLY_VIEWS',
          'REEL_VIEWS_RECEIVED',
          period: 'WEEKLY',
          name: n('مشاهدات ريلزك هذا الأسبوع', 'Views on your reels this week'),
          progress: 1840,
          target: 5000,
          reward: 180000,
        ),
        d297TaskJson(
          'CREATOR_WEEKLY_FOLLOWERS',
          'NEW_FOLLOWERS',
          period: 'WEEKLY',
          name: n('متابعون جدد هذا الأسبوع', 'New followers this week'),
          progress: 12,
          target: 50,
          reward: 220000,
        ),
        d297TaskJson(
          'CREATOR_WEEKLY_SHARES',
          'SHARES_RECEIVED',
          period: 'WEEKLY',
          name: n(
            'مشاركات محتواك هذا الأسبوع',
            'Shares of your content this week',
          ),
          progress: 3,
          target: 20,
          reward: 220000,
        ),
      ],
    ],
  };
}

/// D297 follow-up: a real `GET /me/tasks` of the API with the generator on
/// (test/fixtures/programs: a creator at charm level 25, a host at 40).
Map<String, dynamic> d297Fixture(String who, AppLanguage language) =>
    jsonDecode(
      File('test/fixtures/programs/d297_$who.${language.name}.json')
          .readAsStringSync(),
    ) as Map<String, dynamic>;

/// The Task Center's repository answering with a `MyTasks` body.
class D297Programs implements ProgramsRepository {
  new(Map<String, dynamic> json) : tasksValue = MyTasks.fromJson(json);

  final MyTasks tasksValue;
  final List<String> claims = [];

  @override
  Future<MyTasks> tasks() async => tasksValue;

  @override
  Future<ProgramPayout> claim(String code) async {
    claims.add(code);
    return (paidCoins: 0, balanceCoins: 100, paidCherries: 3000);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The Task Center with [programs] (also used by the D297 goldens).
Future<void> pumpD297TaskCenter(
  WidgetTester tester, {
  required D297Programs programs,
  AppLanguage language = AppLanguage.en,
  Size size = const Size(393, 852),
  double textScale = 1,
  Brightness brightness = Brightness.light,
}) async {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const TaskCenterScreen()),
      for (final path in [
        AppRoutes.home,
        AppRoutes.newReel,
        AppRoutes.myProfile,
        AppRoutes.discover,
        AppRoutes.goLive,
      ])
        GoRoute(path: path, builder: (_, _) => Text('page $path')),
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
        taskBannersProvider.overrideWith((ref) async => const []),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        routerConfig: router,
        locale: language.locale,
        supportedLocales: KabsoApp.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        theme: buildAppTheme(brightness: brightness, locale: language.locale),
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

final Finder _page = find
    .descendant(
      of: find.byType(RefreshIndicator),
      matching: find.byType(Scrollable),
    )
    .first;

Future<void> _show(WidgetTester tester, Key key) async {
  await tester.scrollUntilVisible(find.byKey(key), 100, scrollable: _page);
  // Fully on screen (a row at the list's edge is not hit-testable).
  await tester.ensureVisible(find.byKey(key));
  await tester.pumpAndSettle();
}

/// The codes of the task rows inside the card [card].
List<String> _rows(WidgetTester tester, Key card) => [
  for (final e
      in find
          .descendant(
            of: find.byKey(card),
            matching: find.byWidgetPredicate(
              (w) =>
                  w.key is ValueKey<String> &&
                  (w.key! as ValueKey<String>).value.startsWith('tasks.task.'),
            ),
          )
          .evaluate())
    (e.widget.key! as ValueKey<String>).value.substring('tasks.task.'.length),
];

void main() {
  group('the wire (D297)', () {
    test('audience CREATORS, band.creator and the five new metrics', () {
      final mine = MyTasks.fromJson(d297MyTasksJson());
      expect(mine.creator, isTrue);
      expect(mine.creatorDaily.map((t) => t.code), ['P_CR_REEL', 'P_CR_VIEWS']);
      expect(mine.creatorWeekly.map((t) => t.code), [
        'CREATOR_WEEKLY_REELS',
        'CREATOR_WEEKLY_VIEWS',
        'CREATOR_WEEKLY_FOLLOWERS',
        'CREATOR_WEEKLY_SHARES',
      ]);
      // The other cards never hold a creator task.
      expect(mine.daily.map((t) => t.code), ['P_FOLLOW', 'P_LIVE_COMMENTS']);
      expect(mine.weekly, isEmpty);
      expect(mine.tasks.where((t) => t.forHosts), isEmpty);
      for (final (wire, metric) in const [
        ('REEL_VIEWS_RECEIVED', TaskMetric.reelViewsReceived),
        ('LIKES_RECEIVED', TaskMetric.likesReceived),
        ('COMMENT_REPLIES', TaskMetric.commentReplies),
        ('NEW_FOLLOWERS', TaskMetric.newFollowers),
        ('SHARES_RECEIVED', TaskMetric.sharesReceived),
      ]) {
        expect(TaskMetric.fromWire(wire), metric);
      }
      // A server before v1.94-social: no `creator` → false.
      final old = d297MyTasksJson(creator: false);
      (old['band'] as Map<String, dynamic>).remove('creator');
      expect(MyTasks.fromJson(old).creator, isFalse);
    });
  });

  group('task center: the creator cards (D297)', () {
    testWidgets('a creator sees «Content creator tasks» and the weekly card; '
        'the creator rows are not in «Task rewards»', (tester) async {
      await pumpD297TaskCenter(
        tester,
        programs: D297Programs(d297MyTasksJson()),
      );
      await _show(tester, TaskCenterScreen.creatorKey);
      expect(
        find.descendant(
          of: find.byKey(TaskCenterScreen.creatorKey),
          matching: find.text(_en.tasksCreatorTitle),
        ),
        findsOneWidget,
      );
      expect(_rows(tester, TaskCenterScreen.creatorKey), [
        'P_CR_REEL',
        'P_CR_VIEWS',
      ]);
      expect(find.text(_en.tasksCreatorHint), findsOneWidget);
      expect(_rows(tester, TaskCenterScreen.rewardsKey), [
        'P_FOLLOW',
        'P_LIVE_COMMENTS',
      ]);
      await _show(tester, TaskCenterScreen.creatorWeeklyKey);
      expect(find.text(_en.tasksCreatorWeeklyTitle), findsOneWidget);
      expect(_rows(tester, TaskCenterScreen.creatorWeeklyKey), [
        'CREATOR_WEEKLY_REELS',
        'CREATOR_WEEKLY_VIEWS',
        'CREATOR_WEEKLY_FOLLOWERS',
        'CREATOR_WEEKLY_SHARES',
      ]);
      // No weekly host card for a creator.
      expect(find.byKey(TaskCenterScreen.weeklyKey), findsNothing);
      expect(find.text(_en.tasksWeeklyTitle), findsNothing);
      // Progress with thousands separators and the cherry reward.
      expect(
        find.text('Views on your reels this week (1,840/5,000)'),
        findsOneWidget,
      );
      expect(find.text('+180,000'), findsWidgets);
    });

    testWidgets('someone who is not a creator gets no creator card', (
      tester,
    ) async {
      await pumpD297TaskCenter(
        tester,
        programs: D297Programs(d297MyTasksJson(creator: false)),
      );
      await tester.drag(_page, const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(find.byKey(TaskCenterScreen.creatorKey), findsNothing);
      expect(find.byKey(TaskCenterScreen.creatorWeeklyKey), findsNothing);
      expect(find.text(_en.tasksCreatorTitle), findsNothing);
    });

    testWidgets('each new metric has its own icon (never the generic one)', (
      tester,
    ) async {
      final json = d297MyTasksJson();
      (json['tasks'] as List<Map<String, dynamic>>).addAll([
        d297TaskJson('P_CR_LIKES', 'LIKES_RECEIVED', target: 20),
        d297TaskJson('P_CR_REPLIES', 'COMMENT_REPLIES', target: 3),
      ]);
      await pumpD297TaskCenter(tester, programs: D297Programs(json));
      for (final (code, icon) in const [
        ('P_CR_REEL', Icons.movie_rounded),
        ('P_CR_VIEWS', Icons.visibility_rounded),
        ('P_CR_LIKES', Icons.thumb_up_alt_rounded),
        ('P_CR_REPLIES', Icons.reply_rounded),
        ('CREATOR_WEEKLY_FOLLOWERS', Icons.group_add_rounded),
        ('CREATOR_WEEKLY_SHARES', Icons.share_rounded),
      ]) {
        await _show(tester, TaskCenterScreen.taskKey(code));
        expect(
          find.descendant(
            of: find.byKey(TaskCenterScreen.taskKey(code)),
            matching: find.byIcon(icon),
          ),
          findsOneWidget,
          reason: code,
        );
        expect(
          find.descendant(
            of: find.byKey(TaskCenterScreen.taskKey(code)),
            matching: find.byIcon(Icons.task_alt_rounded),
          ),
          findsNothing,
          reason: code,
        );
      }
    });

    for (final (code, route) in [
      ('CREATOR_WEEKLY_FOLLOWERS', AppRoutes.myProfile),
      ('P_CR_VIEWS', AppRoutes.myProfile),
      ('CREATOR_WEEKLY_SHARES', AppRoutes.myProfile),
    ]) {
      testWidgets('«Go» on $code leads to $route', (tester) async {
        await pumpD297TaskCenter(
          tester,
          programs: D297Programs(d297MyTasksJson()),
        );
        await _show(tester, TaskCenterScreen.actionKey(code));
        await tester.tap(find.byKey(TaskCenterScreen.actionKey(code)));
        await tester.pumpAndSettle();
        expect(find.text('page $route'), findsOneWidget);
      });
    }

    testWidgets('«Claim» on a completed weekly creator task claims it', (
      tester,
    ) async {
      final programs = D297Programs(d297MyTasksJson());
      await pumpD297TaskCenter(tester, programs: programs);
      await _show(tester, TaskCenterScreen.actionKey('CREATOR_WEEKLY_REELS'));
      await tester.tap(
        find.byKey(TaskCenterScreen.actionKey('CREATOR_WEEKLY_REELS')),
      );
      await tester.pumpAndSettle();
      expect(programs.claims, ['CREATOR_WEEKLY_REELS']);
    });

    for (final language in AppLanguage.values) {
      testWidgets('360 × 800 at text scale 1.3 (${language.name})', (
        tester,
      ) async {
        final l10n = language == AppLanguage.ar ? _ar : _en;
        await pumpD297TaskCenter(
          tester,
          programs: D297Programs(
            d297MyTasksJson(arabic: language == AppLanguage.ar),
          ),
          language: language,
          size: const Size(360, 800),
          textScale: 1.3,
        );
        await _show(tester, TaskCenterScreen.creatorWeeklyKey);
        expect(find.text(l10n.tasksCreatorTitle), findsOneWidget);
        expect(find.text(l10n.tasksCreatorWeeklyTitle), findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(
          Directionality.of(
            tester.element(find.byKey(TaskCenterScreen.creatorKey)),
          ),
          language == AppLanguage.ar ? TextDirection.rtl : TextDirection.ltr,
        );
      });
    }
  });

  group('the generated tasks (D297 follow-up, real API responses)', () {
    testWidgets('a creator: generated creator tasks in the creator cards', (
      tester,
    ) async {
      final json = d297Fixture('creator', AppLanguage.en);
      await pumpD297TaskCenter(tester, programs: D297Programs(json));
      final daily = [
        for (final t in json['tasks']! as List<dynamic>)
          if ((t as Map<String, dynamic>)['period'] == 'DAILY' &&
              (t['code'] as String).startsWith('G_CR_'))
            t['code'] as String,
      ];
      expect(daily, hasLength(2));
      await _show(tester, TaskCenterScreen.creatorKey);
      expect(_rows(tester, TaskCenterScreen.creatorKey), daily);
      expect(
        _rows(
          tester,
          TaskCenterScreen.rewardsKey,
        ).any((c) => c.startsWith('G_')),
        isFalse,
      );
      await _show(tester, TaskCenterScreen.creatorWeeklyKey);
      final weekly = _rows(tester, TaskCenterScreen.creatorWeeklyKey);
      expect(weekly, hasLength(6));
      expect(
        weekly.every((c) => c.startsWith('G_CR_') && c.endsWith('_W')),
        isTrue,
      );
      expect(find.byKey(TaskCenterScreen.weeklyKey), findsNothing);
      // The generated names, as the server wrote them.
      for (final t in json['tasks']! as List<dynamic>) {
        final task = t as Map<String, dynamic>;
        if (!(task['code'] as String).startsWith('G_CR_')) continue;
        await _show(tester, TaskCenterScreen.taskKey(task['code'] as String));
        expect(
          find.textContaining(task['name'] as String, findRichText: true),
          findsOneWidget,
        );
      }
    });

    testWidgets('a host: generated host tasks in «Task rewards» and four in '
        'the weekly host card; no creator card', (tester) async {
      final json = d297Fixture('host', AppLanguage.en);
      await pumpD297TaskCenter(tester, programs: D297Programs(json));
      expect(
        _rows(
          tester,
          TaskCenterScreen.rewardsKey,
        ).where((c) => c.startsWith('G_HO_')),
        hasLength(2),
      );
      await _show(tester, TaskCenterScreen.weeklyKey);
      final weekly = _rows(tester, TaskCenterScreen.weeklyKey);
      expect(weekly, hasLength(4));
      expect(weekly.every((c) => c.startsWith('G_HO_')), isTrue);
      expect(find.byKey(TaskCenterScreen.creatorKey), findsNothing);
      expect(find.byKey(TaskCenterScreen.creatorWeeklyKey), findsNothing);
      // «Go» on a generated host task opens Go Live.
      await _show(tester, TaskCenterScreen.actionKey(weekly.first));
      await tester.tap(find.byKey(TaskCenterScreen.actionKey(weekly.first)));
      await tester.pumpAndSettle();
      expect(find.text('page ${AppRoutes.goLive}'), findsOneWidget);
    });

    testWidgets('HOST_LIVE_DAYS has its own icon', (tester) async {
      final json = d297MyTasksJson(creator: false);
      (json['tasks'] as List<Map<String, dynamic>>).add(
        d297TaskJson(
          'G_HO_HOST_LIVE_DAYS_W',
          'HOST_LIVE_DAYS',
          audience: 'HOSTS',
          period: 'WEEKLY',
          target: 4,
          reward: 190000,
        ),
      );
      await pumpD297TaskCenter(tester, programs: D297Programs(json));
      await _show(tester, TaskCenterScreen.taskKey('G_HO_HOST_LIVE_DAYS_W'));
      expect(
        find.descendant(
          of: find.byKey(TaskCenterScreen.taskKey('G_HO_HOST_LIVE_DAYS_W')),
          matching: find.byIcon(Icons.calendar_month_rounded),
        ),
        findsOneWidget,
      );
      expect(TaskMetric.fromWire('HOST_LIVE_DAYS'), TaskMetric.hostLiveDays);
    });

    for (final language in AppLanguage.values) {
      for (final who in ['creator', 'host']) {
        testWidgets('$who at 360 × 800, text scale 1.3 (${language.name})', (
          tester,
        ) async {
          await pumpD297TaskCenter(
            tester,
            programs: D297Programs(d297Fixture(who, language)),
            language: language,
            size: const Size(360, 800),
            textScale: 1.3,
          );
          await tester.drag(_page, const Offset(0, -3000));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}
