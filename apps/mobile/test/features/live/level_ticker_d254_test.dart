// D254 (owner: «شريط متحرك لاعلان عن ترقية الحسابات وصعود ليفيلات لليفيلات
// المرتفعة»): the level banner in every live — the `level-ticker` data
// message (topic `level`, v1.62-live) parsed; one banner at a time, oldest
// first; its own live too; the support / charm badge at the start; the text
// scrolls (still with an ellipsis under reduced motion); a tap opens the live
// where it happened; under the header row of the host's screen (the D253
// reference, 393 × 852 pt) and of the viewer's.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/levels/domain/level_models.dart';
import 'package:kabso_live/features/levels/presentation/level_badge.dart';
import 'package:kabso_live/features/live/application/live_chat_controller.dart';
import 'package:kabso_live/features/live/application/live_host_controller.dart';
import 'package:kabso_live/features/live/application/live_level_ticker.dart';
import 'package:kabso_live/features/live/data/live_gift_repository.dart';
import 'package:kabso_live/features/live/data/live_host_targets_repository.dart';
import 'package:kabso_live/features/live/data/live_media_engine.dart';
import 'package:kabso_live/features/live/data/live_pk_media.dart';
import 'package:kabso_live/features/live/data/live_pk_repository.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/live/domain/live_gift_models.dart';
import 'package:kabso_live/features/live/domain/live_level_ticker.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/go_live_screen.dart';
import 'package:kabso_live/features/live/live_room_screen.dart';
import 'package:kabso_live/features/live/presentation/go_live/host_live_ref_parts.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_mini_window.dart';
import 'package:kabso_live/features/live/presentation/widgets/charm_level_badge.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_level_ticker_bar.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_scaffold.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:kabso_live/features/programs/application/programs_providers.dart';
import 'package:kabso_live/features/programs/data/programs_repository.dart';
import 'package:kabso_live/features/safety/safety_repository.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../fixtures/live/live_gift_fixtures.dart';
import '../../helpers/fake_live_gift_repository.dart';
import '../../helpers/fake_live_host_targets_repository.dart';
import '../../helpers/fake_live_media_engine.dart';
import '../../helpers/fake_live_pk.dart';
import '../../helpers/fake_live_repository.dart';
import '../../helpers/fake_profile_repository.dart';
import '../../helpers/fake_safety_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

UserSummary _user(String id, String name) =>
    UserSummary(id: id, username: id, displayName: name, avatarUrl: null);

LevelTicker _ticker({
  String userId = 'u-nour',
  String name = 'Nour',
  LevelCategory category = LevelCategory.support,
  int level = 31,
  String room = 'room-b',
  UserSummary? host,
}) => LevelTicker(
  id: '$userId:${category.wire}:$level',
  user: _user(userId, name),
  category: category,
  level: level,
  previousLevel: level - 1,
  room: LuckyTickerRoom(
    id: room,
    title: 'Friday night',
    host: host ?? _user('u-sara', 'Sara'),
  ),
);

Map<String, Object?> _json({String category = 'SUPPORT'}) => {
  'type': 'level-ticker',
  'levelUp': {
    'id': 'u-nour:$category:31',
    'user': {
      'id': 'u-nour',
      'username': 'nour',
      'displayName': 'Nour',
      'avatarUrl': null,
    },
    'category': category,
    'level': 31,
    'previousLevel': 30,
    'roomId': 'room-b',
    'createdAt': '2026-11-03T10:00:00.000Z',
  },
  'room': {
    'id': 'room-b',
    'title': 'Friday night',
    'host': {
      'id': 'u-sara',
      'username': 'sara',
      'displayName': 'Sara',
      'avatarUrl': null,
    },
  },
};

ProviderContainer _container({List<UserSummary> blocked = const []}) {
  final c = ProviderContainer(
    overrides: [
      liveRepositoryProvider.overrideWithValue(FakeLiveRepository()),
      safetyRepositoryProvider.overrideWithValue(
        FakeSafetyRepository(blockedUsers: [...blocked]),
      ),
      currentUserProvider.overrideWithValue(testUser()),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

/// The banner of live `room-a` alone, where the live screens put it.
Future<ProviderContainer> _pumpBar(
  WidgetTester tester, {
  AppLanguage language = AppLanguage.en,
  ValueChanged<String>? onOpenRoom,
}) async {
  setViewport(tester, GoldenViewport.phone);
  await pumpScreen(
    tester,
    Scaffold(
      backgroundColor: const Color(0xFF101018),
      body: Stack(
        fit: StackFit.expand,
        children: [
          PositionedDirectional(
            top: 100,
            start: LiveLevelTickerBar.start,
            end: LiveLevelTickerBar.end,
            child: LiveLevelTickerBar(roomId: 'room-a', onOpenRoom: onOpenRoom),
          ),
        ],
      ),
    ),
    language: language,
    overrides: [
      liveRepositoryProvider.overrideWithValue(FakeLiveRepository()),
      currentUserProvider.overrideWithValue(testUser()),
    ],
  );
  return ProviderScope.containerOf(
    tester.element(find.byType(LiveLevelTickerBar)),
  );
}

double _moved(WidgetTester tester) => tester
    .widget<Transform>(find.byKey(LiveMarqueeText.movingKey))
    .transform
    .getTranslation()
    .x;

/// Lets the banner's time run out (no timer left behind).
Future<void> _drain(WidgetTester tester) async {
  await tester.pump(LiveLevelTickers.showTime * 4);
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  test('the level-ticker message parses; WIZARD / GAMING and malformed ones '
      'are ignored', () {
    final event = LiveChatEvent.parse(_json());
    expect(event, isA<LevelTickerReceived>());
    final t = (event! as LevelTickerReceived).ticker;
    expect(t.id, 'u-nour:SUPPORT:31');
    expect(t.user.displayName, 'Nour');
    expect(t.category, LevelCategory.support);
    expect(t.level, 31);
    expect(t.previousLevel, 30);
    expect(t.room.id, 'room-b');
    expect(t.room.host.displayName, 'Sara');
    expect(
      (LiveChatEvent.parse(_json(category: 'ATTRACTIVENESS'))!
              as LevelTickerReceived)
          .ticker
          .category,
      LevelCategory.attractiveness,
    );
    expect(LiveChatEvent.parse(_json(category: 'WIZARD')), isNull);
    expect(LiveChatEvent.parse(_json(category: 'GAMING')), isNull);
    expect(LiveChatEvent.parse({'type': 'level-ticker'}), isNull);
  });

  test('one at a time, oldest first; its own live too; repeats and blocked '
      'people are skipped', () async {
    final c = _container(blocked: [_user('u-bad', 'Bad')]);
    final engine = FakeLiveMediaEngine();
    c.listen(liveChatProvider('room-a'), (_, _) {});
    await c
        .read(liveChatProvider('room-a').notifier)
        .attach(engine, enabled: true, muted: false);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final tickers = c.read(liveLevelTickersProvider('room-a').notifier);
    c.listen(liveLevelTickersProvider('room-a'), (_, _) {});
    tickers
      ..attach(engine)
      ..show(_ticker(userId: 'u-bad', name: 'Bad'))
      ..show(_ticker(host: _user('u-bad', 'Bad')));
    expect(c.read(liveLevelTickersProvider('room-a')), isNull);

    // This very live: shown too (the owner: «في كل البثوث»).
    engine.chat.add(LevelTickerReceived(_ticker(level: 30, room: 'room-a')));
    await Future<void>.delayed(Duration.zero);
    expect(c.read(liveLevelTickersProvider('room-a'))?.level, 30);
    tickers
      ..show(_ticker(level: 30, room: 'room-a')) // a repeat: dropped
      ..show(_ticker())
      ..show(_ticker(level: 32))
      ..show(_ticker(level: 33))
      ..show(_ticker(level: 34));
    final order = <int>[];
    for (var i = 0; i < 4; i++) {
      tickers.dismiss();
      order.add(c.read(liveLevelTickersProvider('room-a'))?.level ?? 0);
    }
    // Oldest first; the line holds three (31 was dropped when 34 came).
    expect(order, [32, 33, 34, 0]);
    expect(LiveLevelTickers.showTime, const Duration(seconds: 8));
  });

  testWidgets('the support badge, the text scrolls in the reading direction, '
      'a tap opens the live', (tester) async {
    final opened = <String>[];
    final c = await _pumpBar(tester, onOpenRoom: opened.add);
    expect(find.byKey(LiveLevelTickerBar.tickerKey), findsNothing);
    c.read(liveLevelTickersProvider('room-a').notifier).show(_ticker());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final bar = find.byKey(LiveLevelTickerBar.tickerKey);
    expect(bar, findsOneWidget);
    final rect = tester.getRect(bar);
    expect(rect.height, LiveLevelTickerBar.height);
    expect(rect.left, LiveLevelTickerBar.start);
    expect(rect.right, 393 - LiveLevelTickerBar.end);
    expect(
      find.descendant(of: bar, matching: find.byType(KLevelBadge)),
      findsOneWidget,
    );
    final text = l10nFor(AppLanguage.en)
        .liveLevelTicker('\u2068Nour\u2069', 31, '\u2068Sara\u2069');
    expect(find.text(text), findsNWidgets(2)); // the line and its copy
    // Waits at its start, then moves left (English reads left to right).
    expect(_moved(tester), 0);
    await tester.pump(const Duration(milliseconds: 900));
    expect(_moved(tester), 0);
    await tester.pump(const Duration(seconds: 2));
    expect(_moved(tester), lessThan(-40));
    expect(
      tester.getSemantics(
        find.byKey(const ValueKey('levelTicker.u-nour:SUPPORT:31')),
      ),
      isSemantics(isButton: true, label: 'Support level. $text'),
    );
    await tester.tap(bar);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(opened, ['room-b']);
    expect(find.byKey(LiveLevelTickerBar.tickerKey), findsNothing);
    await _drain(tester);
  });

  testWidgets('Arabic: the charm badge, the text moves right; its own live is '
      'not a button; gone after 8 s', (tester) async {
    final opened = <String>[];
    final c = await _pumpBar(
      tester,
      language: AppLanguage.ar,
      onOpenRoom: opened.add,
    );
    c
        .read(liveLevelTickersProvider('room-a').notifier)
        .show(
          _ticker(
            category: LevelCategory.attractiveness,
            level: 45,
            room: 'room-a',
          ),
        );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 3));
    final bar = find.byKey(LiveLevelTickerBar.tickerKey);
    expect(
      find.descendant(of: bar, matching: find.byType(CharmLevelBadge)),
      findsOneWidget,
    );
    expect(_moved(tester), greaterThan(40));
    expect(
      tester.getSemantics(
        find.byKey(const ValueKey('levelTicker.u-nour:ATTRACTIVENESS:45')),
      ),
      isNot(isSemantics(isButton: true)),
    );
    await tester.tap(bar);
    await tester.pump();
    expect(opened, isEmpty);
    await tester.pump(LiveLevelTickers.showTime);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(LiveLevelTickerBar.tickerKey), findsNothing);
    await _drain(tester);
  });

  testWidgets('reduced motion: the text does not move, it ends in an '
      'ellipsis', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final c = await _pumpBar(tester, onOpenRoom: (_) {});
    c.read(liveLevelTickersProvider('room-a').notifier).show(_ticker());
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(find.byKey(LiveMarqueeText.movingKey), findsNothing);
    final still = tester.widget<Text>(find.byKey(LiveMarqueeText.stillKey));
    expect(still.overflow, TextOverflow.ellipsis);
    expect(still.maxLines, 1);
    await _drain(tester);
  });

  testWidgets('a short text fits: it does not move', (tester) async {
    setViewport(tester, GoldenViewport.phone);
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 300,
            child: LiveMarqueeText('Short', style: TextStyle(fontSize: 12)),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 3));
    expect(find.byKey(LiveMarqueeText.movingKey), findsNothing);
    expect(find.byKey(LiveMarqueeText.stillKey), findsOneWidget);
  });

  forEachLanguage((language) {
    testWidgets('D254 the banner on the host screen, under the header row, '
        'above the Host Tasks card ($language)', (tester) async {
      final engine = await _pumpHost(tester, language: language);
      engine.chat.add(
        LevelTickerReceived(
          _ticker(
            name: language == AppLanguage.ar ? 'نور' : 'Nour',
            host: _user('u-sara', language == AppLanguage.ar ? 'سارة' : 'Sara'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final bar = find.byKey(LiveLevelTickerBar.tickerKey);
      expect(bar, findsOneWidget);
      final rect = tester.getRect(bar);
      final headerTop = KLiveRoomScaffold.headerTop(59);
      expect(rect.top, moreOrLessEquals(LiveLevelTickerBar.topFor(59)));
      // Ref: ≈ 8 pt to 384 pt, ≈ 21 pt tall, under the header row's pill.
      // Arabic mirrors it (owner, D253): 8 pt from the reading start.
      final ar = language == AppLanguage.ar;
      expect(rect.left, moreOrLessEquals(ar ? 9 : 8));
      expect(rect.right, moreOrLessEquals(ar ? 385 : 384));
      expect(rect.height, 21);
      final card = tester.getRect(find.byKey(HostTasksCard.cardKey));
      expect(rect.bottom, lessThanOrEqualTo(card.top));
      expect(rect.top, greaterThan(headerTop + 35));
      // The host on air stays in their live: not a button.
      expect(
        tester.getSemantics(
          find.byKey(const ValueKey('levelTicker.u-nour:SUPPORT:31')),
        ),
        isNot(isSemantics(isButton: true)),
      );
      // The badges' art decoded before the picture.
      await precacheImages(tester);
      await expectScreenGolden('go_live.level_ticker', language: language);
      await _drain(tester);
    });

    testWidgets('D254 the banner on the viewer screen ($language)', (
      tester,
    ) async {
      final engine = await _pumpViewer(tester, language: language);
      engine.chat.add(
        LevelTickerReceived(
          _ticker(
            category: LevelCategory.attractiveness,
            level: 40,
            name: language == AppLanguage.ar ? 'نور' : 'Nour',
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final bar = find.byKey(LiveLevelTickerBar.tickerKey);
      expect(bar, findsOneWidget);
      expect(
        tester.getRect(bar).top,
        moreOrLessEquals(LiveLevelTickerBar.topFor(59)),
      );
      // Another live's: a tap opens it (a button).
      expect(
        find.descendant(of: bar, matching: find.byType(GestureDetector)),
        findsWidgets,
      );
      // The badges' art decoded before the picture.
      await precacheImages(tester);
      await expectScreenGolden('live_room.level_ticker', language: language);
      await _drain(tester);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 10));
    });
  });
}

// ---- The live screens at the reference's size (393 × 852, 59 / 34 insets) --

Widget _insets(Widget child) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      padding: const EdgeInsets.only(top: 59, bottom: 34),
      viewPadding: const EdgeInsets.only(top: 59, bottom: 34),
    ),
    child: child,
  ),
);

Future<FakeLiveMediaEngine> _pumpViewer(
  WidgetTester tester, {
  required AppLanguage language,
}) async {
  final ar = language == AppLanguage.ar;
  tester.view.padding = const FakeViewPadding(
    top: 59 * GoldenViewport.pixelRatio,
    bottom: 34 * GoldenViewport.pixelRatio,
  );
  addTearDown(tester.view.resetPadding);
  final prefs = await testPrefs(language: language.name);
  late FakeLiveMediaEngine engine;
  await pumpGolden(
    tester,
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        liveRepositoryProvider.overrideWithValue(
          FakeLiveRepository(
            room: (id) => apiRoom(id: id, ar: ar),
          ),
        ),
        profileRepositoryProvider.overrideWithValue(
          FakeProfileRepository(apiProfile(ar: ar)),
        ),
        liveGiftRepositoryProvider.overrideWithValue(
          FakeLiveGiftRepository(codes: giftFixtureCodes),
        ),
        ...pkTestOverrides(),
        liveMediaEngineProvider.overrideWithValue(
          () => engine = FakeLiveMediaEngine()..present.add('user-0'),
        ),
        currentUserProvider.overrideWithValue(testUser()),
      ],
      child: const LiveRoomScreen(roomId: 'room-0'),
    ),
    language: language,
    bare: true,
  );
  await tester.pumpAndSettle();
  await precacheImages(tester);
  return engine;
}

ProgramTask _weekly() => ProgramTask(
  code: 'W_HOST_GIFTS',
  weekly: true,
  metric: TaskMetric.fromWire('HOST_GIFTS_RECEIVED'),
  forHosts: true,
  name: 'Receive gifts',
  target: 500,
  progress: 120,
  rewardCherries: 18000,
  completed: false,
  claimed: false,
);

MyTasks _tasks() => MyTasks(
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
  tasks: [_weekly()],
);

const _target = LiveHostTargets(
  day: '2026-11-03',
  band: 1,
  cherries: HostTarget(received: 0, target: 50, reached: false),
  lucky: HostTarget(received: 0, target: 0, reached: false),
  topSupporters: [],
);

/// The host's video live as in D253's harness.
Future<FakeLiveMediaEngine> _pumpHost(
  WidgetTester tester, {
  required AppLanguage language,
}) async {
  final ar = language == AppLanguage.ar;
  final repo = FakeLiveRepository(
    categories: [LiveCategory(slug: 'chat', name: ar ? 'دردشة' : 'Chat')],
  );
  final user = testUser(displayName: ar ? 'ليلى' : 'Layla')
      .copyWith(canHost: true);
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
        myTasksProvider.overrideWith((ref) async => _tasks()),
      ],
      child: _insets(
        Stack(
          children: [
            const GoLiveScreen(),
            LiveMiniWindow(router: GoRouter(routes: [])),
          ],
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
  await host.goLive(title: 'Evening');
  await tester.pump();
  await tester.pump();
  await precacheImages(tester);
  return engine;
}
