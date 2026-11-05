// D281 / D281b (owner, CONVENTIONS §10.62.2, §10.41.4): «الأهداف الذكية» — the
// host's smart targets of today, three on each tab («الهدايا» and «هدايا
// الحظ») at three levels («سهل / متوسط / صعب»). The «تارجت» chip turns
// through all six (the mark, the level, the progress, the reward); under
// reduced motion one compact face per tab («1/3»). The sheet shows the active
// tab's three. Marks: a target about ONE gift shows that gift's CURRENT
// hosted picture (`imageUrl`, served here by a fake art cache with a real
// gift image); other gift targets the gift-box badge; other lucky targets the
// lucky badge. Also: the cherry history's new reason; the Task Center's
// chosen-gift task with the gift's picture and the new metrics. A fixed clock
// (the sheet's countdown), no device.

import 'dart:io';
import 'dart:typed_data';

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
import 'package:kabso_live/features/live/data/gift_art_cache.dart';
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

/// The gifts' hosted art (the catalogue's current pictures), as the CDN
/// would serve it.
const d281AngelUrl = 'https://media.kabso.test/media/gifts/angel/art.webp';
const d281TreasureUrl =
    'https://media.kabso.test/media/gifts/treasure/art.webp';

/// D281b: the hosted art from real gift images (the app's CP-space gift art
/// stands in for the CDN), so the goldens show a current gift picture.
class D281ArtCache extends GiftArtCache {
  new()
    : _bytes = {
        d281AngelUrl: File('assets/cp_space/gift_angel.webp').readAsBytesSync(),
        d281TreasureUrl: File('assets/cp_space/gift_carriage.webp')
            .readAsBytesSync(),
      };

  final Map<String, Uint8List> _bytes;

  @override
  Future<Uint8List> load(String url) async {
    final b = _bytes[url];
    if (b == null) throw StateError('no art for $url');
    return b;
  }
}

/// Installs [D281ArtCache] for one test.
void useD281Art() {
  final saved = GiftArtCache.instance;
  GiftArtCache.instance = D281ArtCache();
  addTearDown(() => GiftArtCache.instance = saved);
}

Map<String, Object?> _t({
  required String track,
  required String level,
  required String kind,
  required String title,
  required int amount,
  required int progress,
  required int reward,
  required int bps,
  int? paid,
  Map<String, Object?>? window,
  Map<String, Object?>? gift,
}) => {
  'track': track,
  'level': level,
  'code': 'T.$kind.*.$amount.0-1440',
  'kind': kind,
  'title': title,
  'amount': amount,
  'progress': progress,
  'reached': progress >= amount,
  'rewardCherries': reward,
  'rewardBps': bps,
  'paidCherries': paid,
  'locked': true,
  'window': window,
  'gift': gift,
  'category': null,
};

/// The server's `LiveHostTargets` with six smart targets: the gifts tab (a
/// count of «الملاك» with its picture, supporters paid, cherries in a window)
/// and the lucky tab (lucky gifts received, a count of the lucky «كنز» with
/// its picture, lucky cherries).
Map<String, Object?> d281Json({String lang = 'ar'}) {
  final ar = lang == 'ar';
  return {
    'day': '2027-01-14',
    'timeZone': 'Asia/Riyadh',
    'endsAt': '2027-01-14T21:00:00.000Z',
    'band': 2,
    'gifts': {'received': 1_250_000, 'target': 0, 'reached': false},
    'cherries': {'received': 1_250_000, 'target': 0, 'reached': false},
    'lucky': {'received': 40_000, 'target': 120_000, 'reached': false},
    'topSupporters': const <Object?>[],
    'luckySupporters': const <Object?>[],
    'me': null,
    'daily': [
      _t(
        track: 'GIFTS',
        level: 'EASY',
        kind: 'GIFT_COUNT',
        title: ar ? 'استقبل 100 هدية من الملاك' : 'Receive 100 × Angel',
        amount: 100,
        progress: 37,
        reward: 7_295,
        bps: 150,
        gift: {
          'code': 'angel',
          'name': ar ? 'الملاك' : 'Angel',
          'assetKey': 'gift_angel',
          'imageUrl': d281AngelUrl,
        },
      ),
      _t(
        track: 'GIFTS',
        level: 'MEDIUM',
        kind: 'SUPPORTERS',
        title: ar ? '8 داعمين مختلفين' : '8 different supporters',
        amount: 8,
        progress: 8,
        reward: 12_000,
        bps: 250,
        paid: 11_870,
      ),
      _t(
        track: 'GIFTS',
        level: 'HARD',
        kind: 'GIFT_CHERRIES',
        title: ar
            ? 'هدف الهدايا: 3,000,000 كرزة من 20:00 إلى 24:00'
            : 'Gifts target: 3,000,000 cherries between 20:00–24:00',
        amount: 3_000_000,
        progress: 1_250_000,
        reward: 89_790,
        bps: 400,
        window: {'from': '20:00', 'to': '24:00'},
      ),
      _t(
        track: 'LUCKY',
        level: 'EASY',
        kind: 'LUCKY_SENDS',
        title: ar ? 'استقبل 20 هدية حظ' : 'Receive 20 lucky gifts',
        amount: 20,
        progress: 12,
        reward: 1_480,
        bps: 150,
      ),
      _t(
        track: 'LUCKY',
        level: 'MEDIUM',
        kind: 'LUCKY_GIFT_COUNT',
        title: ar
            ? 'استقبل 10 من هدية الحظ كنز'
            : 'Receive 10 × lucky Treasure',
        amount: 10,
        progress: 3,
        reward: 3_250,
        bps: 250,
        gift: {
          'code': 'treasure',
          'name': ar ? 'كنز' : 'Treasure',
          'assetKey': 'gift_treasure',
          'imageUrl': d281TreasureUrl,
        },
      ),
      _t(
        track: 'LUCKY',
        level: 'HARD',
        kind: 'LUCKY_CHERRIES',
        title: ar
            ? 'هدف هدايا الحظ: 120,000 كرزة'
            : 'Lucky gifts target: 120,000 cherries',
        amount: 120_000,
        progress: 40_000,
        reward: 8_836,
        bps: 400,
      ),
    ],
  };
}

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
  test('reads six smart targets (two tabs; gift, window, paid); none from an '
      'older server', () {
    final t = LiveHostTargets.fromJson(d281Json());
    expect(t.daily.map((x) => '${x.track.name}.${x.level.name}'), [
      'gifts.easy',
      'gifts.medium',
      'gifts.hard',
      'lucky.easy',
      'lucky.medium',
      'lucky.hard',
    ]);
    final easy = t.daily[0];
    expect([easy.kind, easy.amount, easy.progress], ['GIFT_COUNT', 100, 37]);
    expect(easy.gift?.code, 'angel');
    expect(easy.gift?.imageUrl, d281AngelUrl);
    expect(easy.fraction, closeTo(0.37, 1e-9));
    expect([easy.paid, easy.lucky], [false, false]);
    expect([t.daily[1].paid, t.daily[1].shownReward], [true, 11_870]);
    expect([t.daily[2].windowFrom, t.daily[2].windowTo], ['20:00', '24:00']);
    expect(t.daily[4].lucky, isTrue);
    expect(t.daily[4].gift?.code, 'treasure');
    // A server before D281b sends gift targets only (no `track`).
    final before = LiveHostTargets.fromJson({
      ...d281Json(),
      'daily': [
        {
          ...(d281Json()['daily']! as List<Object?>).first!
              as Map<String, Object?>,
        }..remove('track'),
      ],
    });
    expect(before.daily.single.track, TargetTrack.gifts);
    final old = LiveHostTargets.fromJson({...d281Json()}..remove('daily'));
    expect(old.daily, isEmpty);
    expect(
      CherryLedgerReason.fromWire('HOST_TARGET_REWARD'),
      CherryLedgerReason.hostTargetReward,
    );
  });

  for (final language in AppLanguage.values) {
    final ar = language == AppLanguage.ar;
    testWidgets('the chip turns through the six: the gift picture for a '
        'gift target, the tab badges for the others (${language.name})', (
      tester,
    ) async {
      useD281Art();
      LiveHostTargetChip.debugIgnoreReducedMotion = true;
      // A long turn, so each step (a turn + 1 s for the switch) lands on
      // one turn.
      final turn = LiveHostTargetChip.rotateEvery;
      LiveHostTargetChip.rotateEvery = const Duration(seconds: 10);
      addTearDown(() => LiveHostTargetChip.rotateEvery = turn);
      addTearDown(() => LiveHostTargetChip.debugIgnoreReducedMotion = false);
      await _pumpChip(tester, language);
      final chip = find.byKey(LiveHostTargetChip.chipKey);
      expect(chip, findsOneWidget);
      final l10n = l10nFor(language);
      Future<void> next() async {
        await tester.pump(LiveHostTargetChip.rotateEvery);
        await tester.pump(const Duration(seconds: 1));
      }

      // Gifts EASY: the angel's CURRENT hosted picture, «سهل», 37/100, +7.2K.
      expect(
        find.byKey(LiveHostTargetChip.dailyKey(TargetLevel.easy)),
        findsOneWidget,
      );
      expect(find.byKey(KGiftImage.networkKey), findsOneWidget);
      expect(find.text(l10n.liveTargetLevelEasy), findsOneWidget);
      expect(find.text('37/100'), findsOneWidget);
      expect(find.text('+7.2K'), findsOneWidget);
      // Gifts MEDIUM: reached, paid 11.8K, the gift-box badge.
      await next();
      expect(find.byKey(LiveHostTargetChip.reachedKey), findsOneWidget);
      expect(find.text('+11.8K'), findsOneWidget);
      expect(
        find.byKey(KHostTargetBadge.keyOf(HostTargetKind.gifts)),
        findsOneWidget,
      );
      // Gifts HARD.
      await next();
      expect(find.text('1.2M/3M'), findsOneWidget);
      // Lucky EASY: the lucky badge.
      await next();
      expect(
        find.byKey(
          LiveHostTargetChip.dailyKey(TargetLevel.easy, TargetTrack.lucky),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(KHostTargetBadge.keyOf(HostTargetKind.lucky)),
        findsOneWidget,
      );
      expect(find.text('12/20'), findsOneWidget);
      // Lucky MEDIUM: a count of ONE lucky gift — its picture.
      await next();
      expect(find.byKey(KGiftImage.networkKey), findsOneWidget);
      expect(find.text('3/10'), findsOneWidget);
      // Lucky HARD, then back to the first.
      await next();
      expect(find.text('40K/120K'), findsOneWidget);
      await next();
      expect(find.text('37/100'), findsOneWidget);
      final label = tester.getSemantics(chip).label;
      expect(label, contains(ar ? 'سهل' : 'Easy'));
      expect(label, contains('89,790'));
      expect(label, contains(ar ? 'كنز' : 'Treasure'));
    });

    testWidgets('reduced motion: one compact face per tab (reached / 3) '
        '(${language.name})', (tester) async {
      useD281Art();
      await _pumpChip(tester, language, reduced: true);
      for (final track in TargetTrack.values) {
        expect(
          find.byKey(LiveHostTargetChip.summaryKey(track)),
          findsOneWidget,
        );
      }
      expect(find.text('1/3'), findsOneWidget);
      expect(find.text('0/3'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the sheet: each tab shows its three, with the level, title, '
        'progress and reward; «done» once paid (${language.name})', (
      tester,
    ) async {
      useD281Art();
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
      expect(find.text('37 / 100'), findsOneWidget);
      // Gifts tab: the angel's picture on the gift count; the gift box on the
      // others; no lucky badge.
      expect(
        find.descendant(of: block, matching: find.byKey(KGiftImage.networkKey)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: block,
          matching: find.byKey(KHostTargetBadge.keyOf(HostTargetKind.gifts)),
        ),
        findsNWidgets(2),
      );
      expect(find.text(l10n.liveTargetRewardHint), findsOneWidget);
      // The lucky tab: its own three.
      await tester.tap(find.byKey(HostTargetSheet.tabKey(TargetTab.lucky)));
      await tester.pumpAndSettle();
      expect(
        find.text(ar ? 'استقبل 20 هدية حظ' : 'Receive 20 lucky gifts'),
        findsOneWidget,
      );
      expect(find.text('12 / 20'), findsOneWidget);
      expect(find.text('40,000 / 120,000'), findsOneWidget);
      expect(
        reward(TargetLevel.hard).data,
        l10n.liveTargetRewardLocked('8,836'),
      );
      final lblock = find.byKey(HostTargetSheet.targetsKey);
      expect(
        find.descendant(
          of: lblock,
          matching: find.byKey(KHostTargetBadge.keyOf(HostTargetKind.lucky)),
        ),
        findsNWidgets(2),
      );
      expect(
        find.descendant(
          of: lblock,
          matching: find.byKey(KGiftImage.networkKey),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('360 × 800 at text scale 1.3: no overflow (${language.name})', (
      tester,
    ) async {
      useD281Art();
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
      await tester.tap(find.byKey(HostTargetSheet.tabKey(TargetTab.lucky)));
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
