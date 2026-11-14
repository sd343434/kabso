// D303 (owner 2026-11-07; CONVENTIONS §10.114): a gift event's page in the
// owner's reference order — banner and dates, «هدايا الفعالية» with each
// gift's price and points, the rules, and a tab per board the event has with
// its prize table (bundles of coins / cherries / items for days), the
// minimum, the caller's place and the live board. Arabic RTL and English LTR,
// light and dark goldens. Kabso's own fixtures only (no third-party art).
//
// D303 follow-ups: the page over the event's own art — the background
// `test/fixtures/programs/d303_event_bg_treasure.webp` is the OWNER'S sample
// (941 × 1672, a golden treasure hall, supplied by the owner for Kabso on
// 2026-11-07; a test fixture only, never bundled in the app) —, gold-framed
// cards, crowns, the countdown, the sticky «مركزي» bar, the CP two-amount
// line and permanent prizes.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/programs/data/programs_repository.dart';
import 'package:kabso_live/features/programs/presentation/event_detail_screen.dart';
import 'package:kabso_live/features/programs/presentation/gift_event_sections.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

UserSummary _u(String id, String name) =>
    UserSummary(id: id, username: id, displayName: name, avatarUrl: null);

EventDetail _event(bool ar, {bool art = false}) => EventDetail(
  id: '01a1b6a1-0000-7000-8000-000000000303',
  title: ar ? 'ملك الهدايا' : 'Gift King',
  startsAt: DateTime.utc(2026, 11, 10, 17),
  endsAt: DateTime.utc(2026, 11, 17, 17),
  status: EventStatus.running,
  metric: 'EVENT_GIFTS',
  forHosts: false,
  permanent: false,
  featured: true,
  rules: ar
      ? 'شارك بإرسال هدايا الفعالية.'
      : 'Join by sending the event gifts.',
  art: art
      ? const EventArt(
          backgroundKind: 'IMAGE',
          backgroundUrl: 'https://media.example.test/media/events/bg/x.webp',
        )
      : const EventArt(),
  prizes: const [],
  timeZone: 'Asia/Riyadh',
  gifts: [
    EventGiftInfo(
      code: 'rose',
      name: ar ? 'وردة' : 'Rose',
      priceCoins: 10,
      assetKey: 'gift_rose',
      pointsPerCoin: 2,
      pointsPerGift: 0,
      pointsEach: 20,
    ),
    EventGiftInfo(
      code: 'crown',
      name: ar ? 'تاج' : 'Crown',
      priceCoins: 1000,
      assetKey: 'gift_crown',
      pointsPerCoin: 1,
      pointsPerGift: 50,
      pointsEach: 1050,
    ),
  ],
  boards: [
    EventBoardInfo(
      kind: EventBoardKind.senders,
      minPoints: 1000,
      prizes: [
        (
          rankFrom: 1,
          rankTo: 1,
          items: [
            const EventPrizeItem(type: 'COINS', amount: 10000),
            EventPrizeItem(
              type: 'BAG_ITEM',
              days: 7,
              code: 'frame_gold',
              name: ar ? 'إطار ذهبي' : 'Gold frame',
              category: 'AVATAR_FRAME',
            ),
            EventPrizeItem(
              type: 'VIP',
              days: 30,
              code: 'VIP_1',
              name: ar ? 'في آي بي 1' : 'VIP 1',
              category: 'VIP',
            ),
          ],
        ),
        (
          rankFrom: 2,
          rankTo: 3,
          items: [const EventPrizeItem(type: 'CHERRIES', amount: 500)],
        ),
      ],
    ),
    const EventBoardInfo(
      kind: EventBoardKind.receivers,
      minPoints: 0,
      prizes: [
        (
          rankFrom: 1,
          rankTo: 1,
          items: [EventPrizeItem(type: 'COINS', amount: 7000)],
        ),
      ],
    ),
    const EventBoardInfo(
      kind: EventBoardKind.cp,
      minPoints: 0,
      prizes: [
        (
          rankFrom: 1,
          rankTo: 1,
          items: [
            EventPrizeItem(type: 'CP_MONEY', cherries: 400, coins: 250),
            EventPrizeItem(type: 'BAG_ITEM', code: 'car', name: 'Car'),
          ],
        ),
      ],
    ),
  ],
);

EventLeaderboard _board(EventBoardKind kind, bool ar) => switch (kind) {
  EventBoardKind.cp => EventLeaderboard(
    isFinal: false,
    rows: const [],
    myScore: 0,
    myPrize: 0,
    board: kind,
    giftRows: [
      GiftBoardRow(
        rank: 1,
        user: _u('p1', ar ? 'ليلى' : 'Layla'),
        partner: _u('p2', ar ? 'عمر' : 'Omar'),
        score: 2100,
        qualified: true,
        prize: const [],
      ),
    ],
  ),
  _ => EventLeaderboard(
    isFinal: false,
    rows: const [],
    myRank: 3,
    myScore: 400,
    myPrize: 0,
    board: kind,
    minPoints: 1000,
    pointsToQualify: 600,
    giftRows: [
      GiftBoardRow(
        rank: 1,
        user: _u('s1', ar ? 'سارة' : 'Sara'),
        score: 21000,
        qualified: true,
        prize: const [EventPrizeItem(type: 'COINS', amount: 10000)],
      ),
      GiftBoardRow(
        rank: 2,
        user: _u('s2', ar ? 'خالد' : 'Khaled'),
        score: 1500,
        qualified: true,
        prize: const [EventPrizeItem(type: 'CHERRIES', amount: 500)],
      ),
      GiftBoardRow(
        rank: 3,
        user: _u('me', ar ? 'أنا' : 'Me'),
        score: 400,
        qualified: false,
        prize: const [],
      ),
    ],
  ),
};

class _Programs implements ProgramsRepository {
  new({required this.ar, this.art = false});

  final bool ar;
  final bool art;
  final List<String?> boards = [];

  @override
  Future<EventDetail> event(String eventId) async => _event(ar, art: art);

  @override
  Future<EventLeaderboard> leaderboard(String eventId, {String? board}) async {
    boards.add(board);
    return _board(EventBoardKind.fromWire(board) ?? EventBoardKind.senders, ar);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final Uint8List _bg = File('test/fixtures/programs/d303_event_bg_treasure.webp')
    .readAsBytesSync();

Future<_Programs> _pump(
  WidgetTester tester, {
  AppLanguage language = AppLanguage.en,
  Brightness brightness = Brightness.dark,
  bool art = false,
}) async {
  GiftEventBackdrop.imageForTesting = (_) => MemoryImage(_bg);
  EventDetailScreen.countdownClock = () => DateTime.utc(2026, 11, 12, 9, 30);
  addTearDown(() {
    GiftEventBackdrop.imageForTesting = null;
    EventDetailScreen.countdownClock = null;
  });
  final repo = _Programs(ar: language == AppLanguage.ar, art: art);
  final prefs = await testPrefs(language: language.name);
  await pumpGolden(
    tester,
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
        currentUserProvider.overrideWithValue(testUser()),
        programsRepositoryProvider.overrideWithValue(repo),
      ],
      child: const EventDetailScreen(
        eventId: '01a1b6a1-0000-7000-8000-000000000303',
      ),
    ),
    language: language,
    brightness: brightness,
    bare: true,
  );
  return repo;
}

void main() {
  testWidgets('the gifts with price and points, the rules, the board tabs '
      'and the caller still missing points', (tester) async {
    final repo = await _pump(tester);
    expect(find.byKey(EventGiftsSection.sectionKey), findsOneWidget);
    expect(find.text('Event gifts'), findsOneWidget);
    expect(find.text('20 pts'), findsOneWidget);
    expect(find.text('1,050 pts'), findsOneWidget);
    expect(
      find.textContaining('Points come only from sending'),
      findsOneWidget,
    );
    expect(find.text('Dates in your local time'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(GiftEventBoards.tabKey(EventBoardKind.senders)),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    // Only the event's boards (no creators, no agencies).
    for (final k in [
      EventBoardKind.senders,
      EventBoardKind.receivers,
      EventBoardKind.cp,
    ]) {
      expect(find.byKey(GiftEventBoards.tabKey(k)), findsOneWidget);
    }
    expect(
      find.byKey(GiftEventBoards.tabKey(EventBoardKind.agencies)),
      findsNothing,
    );
    expect(find.text('Minimum to qualify: 1,000 pts'), findsOneWidget);
    expect(find.text('600 pts to qualify'), findsWidgets);
    expect(find.text('Your place: 3'), findsOneWidget);
    expect(find.text('Gold frame · 7 days'), findsOneWidget);
    expect(find.text('Not qualified'), findsWidgets);
    // No D166 prize list or board on a gift event.
    expect(find.byKey(EventDetailScreen.prizesKey), findsNothing);
    expect(repo.boards, ['SENDERS']);

    await tester.ensureVisible(
      find.byKey(GiftEventBoards.tabKey(EventBoardKind.cp)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(GiftEventBoards.tabKey(EventBoardKind.cp)));
    await tester.pumpAndSettle();
    expect(repo.boards.last, 'CP');
    expect(find.text('Layla & Omar'), findsOneWidget);
    // The couple's two amounts and a permanent item.
    expect(
      find.text('400 cherries to a host / 250 coins to others'),
      findsOneWidget,
    );
    expect(find.text('Car · permanent'), findsOneWidget);
  });

  testWidgets('the page over its art: countdown, crowns, sticky «my place» '
      'bar with the points to the minimum; a gift tap explains lives', (
    tester,
  ) async {
    await _pump(tester, art: true);
    expect(find.byKey(GiftEventBackdrop.backgroundKey), findsOneWidget);
    expect(find.text('Ends in 5d 07:30:00'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(GiftEventBoards.rowKey(1)),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byType(RankCrown), findsWidgets);
    expect(find.byKey(GiftEventMyBar.barKey), findsOneWidget);
    expect(find.text('My place: 3 · 400 pts'), findsOneWidget);
    expect(find.text('600 pts to qualify'), findsWidgets);
    await tester.scrollUntilVisible(
      find.byKey(EventGiftsSection.giftKey('rose')),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(EventGiftsSection.giftKey('rose')));
    await tester.pumpAndSettle();
    expect(find.text('Send Rose in a live'), findsOneWidget);
    expect(find.text('Go to lives'), findsOneWidget);
  });

  testWidgets('Arabic: the tabs start at the right (RTL)', (tester) async {
    await _pump(tester, language: AppLanguage.ar);
    await tester.scrollUntilVisible(
      find.byKey(GiftEventBoards.tabKey(EventBoardKind.senders)),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    final senders = tester.getRect(
      find.byKey(GiftEventBoards.tabKey(EventBoardKind.senders)),
    );
    final hosts = tester.getRect(
      find.byKey(GiftEventBoards.tabKey(EventBoardKind.receivers)),
    );
    expect(senders.left, greaterThan(hosts.left));
    expect(find.text('ترتيب الداعمين'), findsOneWidget);
    expect(find.text('هدايا الفعالية'), findsOneWidget);
    expect(find.text('باقي 600 نقطة للتأهل'), findsWidgets);
  });

  forEachLanguage((language) {
    testWidgets('golden events.gift.art ($language)', (tester) async {
      await _pump(tester, language: language, art: true);
      await expectScreenGolden('events.gift.art', language: language);
    }, tags: ['golden']);
    for (final brightness in Brightness.values) {
      testWidgets('golden events.gift.${brightness.name} ($language)', (
        tester,
      ) async {
        await _pump(tester, language: language, brightness: brightness);
        await expectScreenGolden(
          'events.gift.${brightness.name}',
          language: language,
        );
      }, tags: ['golden']);
    }
  });
}
