// D253 (owner: «اجعل شاشة المضيف في تطبيقنا مثل التصميم ١٠٠٪»): the host's
// video live as the owner's reference (393 × 852 pt) — the top rows, the
// «Host Tasks» card (weekly host tasks), the flat chat, the bar without the
// microphone and with the box; what the reference does not show is in ≡.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/application/live_host_controller.dart';
import 'package:kabso_live/features/live/application/live_top_viewers.dart';
import 'package:kabso_live/features/live/data/live_host_targets_repository.dart';
import 'package:kabso_live/features/live/data/live_media_engine.dart';
import 'package:kabso_live/features/live/data/live_pk_media.dart';
import 'package:kabso_live/features/live/data/live_pk_repository.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/go_live_screen.dart';
import 'package:kabso_live/features/live/presentation/go_live/host_live_ref_parts.dart';
import 'package:kabso_live/features/live/presentation/go_live/host_performance_panel.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_audio_room.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_host_parts.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_mini_window.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_rankings_sheet.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_chat_flat_line.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_host_target_chip.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_chat.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_scaffold.dart';
import 'package:kabso_live/features/programs/application/programs_providers.dart';
import 'package:kabso_live/features/programs/data/programs_repository.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_live_host_targets_repository.dart';
import '../../helpers/fake_live_media_engine.dart';
import '../../helpers/fake_live_pk.dart';
import '../../helpers/fake_live_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

ProgramTask _weekly({int progress = 120, int target = 500}) => ProgramTask(
  code: 'W_HOST_GIFTS',
  weekly: true,
  metric: TaskMetric.fromWire('HOST_GIFTS_RECEIVED'),
  forHosts: true,
  name: 'Receive gifts',
  target: target,
  progress: progress,
  rewardCherries: 18000,
  completed: progress >= target,
  claimed: false,
);

MyTasks _tasks(List<ProgramTask> tasks) => MyTasks(
  dailyCapCoins: 50,
  dailyEarnedCoins: 0,
  band: (band: 1, level: 1, name: 'New', host: true),
  checkIn: const CheckInState(
    checkedInToday: true,
    streak: 1,
    cycleDays: 7,
    rewardCoins: 5,
    bonusCoins: 20,
    days: [],
  ),
  tasks: tasks,
);

const _target = LiveHostTargets(
  day: '2026-11-03',
  band: 1,
  cherries: HostTarget(received: 0, target: 50, reached: false),
  lucky: HostTarget(received: 0, target: 0, reached: false),
  topSupporters: [],
);

Future<FakeLiveMediaEngine> _pump(
  WidgetTester tester, {
  AppLanguage language = AppLanguage.en,
  List<ProgramTask>? tasks,
  bool chat = true,
}) async {
  final ar = language == AppLanguage.ar;
  final repo = FakeLiveRepository(
    categories: [LiveCategory(slug: 'chat', name: ar ? 'دردشة' : 'Chat')],
  );
  final user = testUser(displayName: ar ? 'ليلى' : 'Layla')
      .copyWith(canHost: true);
  if (chat) {
    repo.chat = [
      LiveChatEntry(
        id: 'm-1',
        roomId: 'room-host',
        author: repo.chatAuthor,
        authorRole: LiveChatRole.host,
        text: 'Gggh',
        createdAt: DateTime.utc(2026, 11, 3, 10),
        authorBadges: const LiveChatAuthorBadges(charmLevel: 3),
      ),
    ];
  }
  final prefs = await testPrefs(language: language.name);
  late FakeLiveMediaEngine engine;
  await pumpGolden(
    tester,
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        liveRepositoryProvider.overrideWithValue(repo),
        livePkRepositoryProvider.overrideWithValue(FakeLivePkRepository()),
        livePkOpponentMediaFactoryProvider.overrideWithValue(
          FakePkOpponentMedia.new,
        ),
        liveMediaEngineProvider.overrideWithValue(
          () => engine = FakeLiveMediaEngine(),
        ),
        currentUserProvider.overrideWithValue(user),
        liveHostTargetsRepositoryProvider.overrideWithValue(
          FakeLiveHostTargetsRepository(
            byHost: {user.username: _target, 'host0': _target},
          ),
        ),
        myTasksProvider.overrideWith(
          (ref) async => _tasks(tasks ?? [_weekly()]),
        ),
      ],
      // The reference's phone: 59 pt status bar, 34 pt home indicator.
      child: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            padding: const EdgeInsets.only(top: 59, bottom: 34),
            viewPadding: const EdgeInsets.only(top: 59, bottom: 34),
          ),
          child: Stack(
            children: [
              const GoLiveScreen(),
              LiveMiniWindow(router: GoRouter(routes: [])),
            ],
          ),
        ),
      ),
    ),
    language: language,
    bare: true,
  );
  final container = ProviderScope.containerOf(
    tester.element(find.byType(LiveMiniWindow)),
  );
  final keep = container.listen(liveHostControllerProvider, (_, _) {});
  addTearDown(keep.close);
  final host = container.read(liveHostControllerProvider.notifier);
  await host.setMode(LiveRoomMode.solo);
  repo.viewerList = [
    for (final (id, name) in [('v1', 'Huda'), ('v2', 'Karim'), ('v3', 'Mona')])
      LiveViewer(
        kind: LiveViewerKind.user,
        user: UserSummary(
          id: id,
          username: id,
          displayName: name,
          avatarUrl: null,
        ),
        guestNumber: null,
        joinedAt: DateTime.utc(2026, 11, 3),
      ),
  ];
  // D256: Mona supported this live most, then Karim, then Huda.
  repo.contributorList = [
    LiveContributor(user: repo.viewerList[2].user!, points: 8000),
    LiveContributor(user: repo.viewerList[1].user!, points: 300),
    LiveContributor(user: repo.viewerList[0].user!, points: 40),
  ];
  await host.goLive(title: 'Evening');
  await tester.pump();
  await tester.pump();
  await precacheImages(tester);
  return engine;
}

void main() {
  test('D256 the top supporters first, three places at most', () {
    LiveViewer v(String id) => LiveViewer(
      kind: LiveViewerKind.user,
      user: UserSummary(id: id, username: id, displayName: id, avatarUrl: null),
      guestNumber: null,
      joinedAt: DateTime.utc(2026, 11, 3),
    );
    LiveContributor c(String id, int points) => LiveContributor(
      user: UserSummary(id: id, username: id, displayName: id, avatarUrl: null),
      points: points,
    );
    final viewers = [v('a'), v('b'), v('c'), v('d'), v('e')];
    final ranked = rankViewersBySupport(viewers, [
      c('gone', 9000), // not here now: left out
      c('d', 500),
      c('b', 400),
      c('e', 300),
      c('a', 200),
      c('c', 0), // no points: no place
    ]);
    expect([for (final r in ranked) r.user.id], ['d', 'b', 'e', 'a', 'c']);
    expect([for (final r in ranked) r.rank], [1, 2, 3, null, null]);
    expect(rankPointsLabel(ranked.first, (p) => '$p'), '500');
    expect(rankPointsLabel(ranked[3], (p) => '$p'), isNull);
    // Nobody supported: the join order, no places.
    expect([
      for (final r in rankViewersBySupport(viewers, const [])) r.rank,
    ], everyElement(isNull));
  });

  test('D253 the weekly host task followed and the days left', () {
    final done = _weekly(progress: 500);
    final open = _weekly(progress: 3);
    expect(HostTasksCard.taskOf(_tasks([done, open])), same(open));
    expect(HostTasksCard.taskOf(_tasks([done])), same(done));
    expect(HostTasksCard.taskOf(_tasks(const [])), isNull);
    // Monday: the whole week; Sunday: one day.
    expect(HostTasksCard.daysLeft(DateTime(2026, 11, 2)), 7);
    expect(HostTasksCard.daysLeft(DateTime(2026, 11, 8)), 1);
  });

  testWidgets('D253 the host screen follows the reference', (tester) async {
    await _pump(tester);
    // The bar: no microphone, the box is there.
    expect(find.byKey(KHostBar.micKey), findsNothing);
    expect(find.byKey(KHostBar.boxKey), findsOneWidget);
    // No quick replies over the bar, no LIVE timer; the room rank (owner:
    // «بجانب طربوش الساحر») right after the targets.
    expect(find.byKey(GoLiveScreen.hostQuickRepliesKey), findsNothing);
    expect(find.byKey(GoLiveScreen.elapsedKey), findsNothing);
    final hat = tester.getRect(find.byKey(LiveHostTargetChip.luckyKey));
    final rank = tester.getRect(find.byKey(LiveRankChip.chipKey));
    expect(rank.left - hat.right, inInclusiveRange(4, 20));
    // The second row: the plain targets, the connection and the data.
    expect(find.byKey(LiveHostTargetChip.chipKey), findsOneWidget);
    expect(find.byKey(HostLiveStatus.dotKey), findsOneWidget);
    expect(find.byKey(HostLiveStatus.dataKey), findsOneWidget);
    // The «Host Tasks» card at the top end, 8.9 pt from the edge.
    expect(find.byKey(HostTasksCard.cardKey), findsOneWidget);
    final card = tester.getRect(find.byKey(HostTasksCard.cardKey));
    expect(card.right, moreOrLessEquals(393 - 8.9, epsilon: 0.1));
    expect(
      card.top,
      moreOrLessEquals(
        KLiveRoomScaffold.headerTop(59) + KLiveRoomScaffold.sideEndTop,
        epsilon: 0.1,
      ),
    );
    expect(card.width, moreOrLessEquals(82.6, epsilon: 0.01));
    expect(card.height, moreOrLessEquals(114.6, epsilon: 0.01));
    // The chat: the host's flat line with the orange tag.
    expect(find.byKey(LiveChatFlatLine.tagKey), findsOneWidget);
    final tag = tester.widget<Container>(find.byKey(LiveChatFlatLine.tagKey));
    expect((tag.decoration! as BoxDecoration).color, KFlatChat.hostTag);
    // D253d: the host's own live — the rules line is the first line, the
    // host's message under it.
    expect(
      tester.getRect(find.byKey(LiveRoomChatLines.noticeKey)).bottom,
      lessThanOrEqualTo(
        tester.getRect(find.byKey(LiveChatFlatLine.tagKey)).top,
      ),
    );
    // D256: Mona, Karim and Huda in the TOP 1, 2 and 3 frames.
    for (final rank in [1, 2, 3]) {
      expect(find.byKey(LiveViewersStack.frameKey(rank)), findsOneWidget);
    }
    // «–» hides the card for this live.
    await tester.tap(find.byKey(HostTasksCard.hideKey));
    await tester.pump();
    expect(find.byKey(HostTasksCard.cardKey), findsNothing);
  });

  testWidgets('D253 no weekly host task: no card', (tester) async {
    await _pump(tester, tasks: const []);
    expect(find.byKey(HostTasksCard.cardKey), findsNothing);
    expect(find.byKey(KLiveRoomScaffold.sideEndKey), findsOneWidget);
  });

  testWidgets('D253 the microphone and quick replies are in ≡', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(KHostBar.toolsKey));
    await tester.pumpAndSettle();
    expect(find.text('Microphone'), findsWidgets);
    expect(find.text('Quick replies'), findsOneWidget);
  });

  forEachLanguage((language) {
    testWidgets('D253 host live as the reference ($language)', (tester) async {
      await _pump(tester, language: language);
      await expectScreenGolden('go_live.host_ref', language: language);
    });

    testWidgets('D253b «⌂▶» opens the performance card ($language)', (
      tester,
    ) async {
      HostPerformancePanel.now = () => DateTime(2026, 11, 3, 22, 52);
      addTearDown(() => HostPerformancePanel.now = DateTime.now);
      await _pump(tester, language: language);
      await tester.tap(find.byKey(HostLiveStatus.dataKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(HostPerformancePanel.panelKey), findsOneWidget);
      for (final id in [
        'time',
        'viewers',
        'peak',
        'fans',
        'cherries',
        'givers',
      ]) {
        expect(find.byKey(HostPerformancePanel.valueKey(id)), findsOneWidget);
      }
      await expectScreenGolden('go_live.performance', language: language);
      await tester.tap(find.byKey(HostPerformancePanel.closeKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(HostPerformancePanel.panelKey), findsNothing);
    });
  });
}
