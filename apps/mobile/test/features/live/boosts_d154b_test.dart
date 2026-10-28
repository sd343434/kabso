// D154b («بطاقة الزيارات», CONVENTIONS §10.34): the traffic card sheet
// (lengths, prices and savings, the honest start, buying with coins after a
// confirmation, a reward card instead of coins, a live that has a card
// already, a viewer's gift to the host), the «مميز» lives pinned first on
// the hub, and the grid card's label — Arabic RTL and English at 360×800.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/features/live/application/live_rooms_provider.dart';
import 'package:kabso_live/features/live/domain/live_boost_models.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/live_screen.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_boost_sheet.dart';
import 'package:kabso_live/features/live/presentation/hub/live_grid_card.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_view_data.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_live_boost_repository.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

const _open = Key('test.openBoost');

class _Opener extends StatelessWidget {
  const new({this.hostName});

  final String? hostName;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        key: _open,
        onPressed: () => unawaited(
          showLiveBoostSheet(context, roomId: 'room-0', hostName: hostName),
        ),
        child: const SizedBox.square(dimension: 40),
      ),
    ),
  );
}

Future<FakeLiveBoostRepository> _pump(
  WidgetTester tester, {
  FakeLiveBoostRepository? repo,
  AppLanguage language = AppLanguage.en,
  String? hostName,
}) async {
  setViewport(tester, GoldenViewport.android);
  final boosts = repo ?? FakeLiveBoostRepository();
  await pumpScreen(
    tester,
    _Opener(hostName: hostName),
    language: language,
    liveBoostRepository: boosts,
  );
  await tester.tap(find.byKey(_open));
  await tester.pumpAndSettle();
  return boosts;
}

Future<void> _confirm(WidgetTester tester) async {
  await tester.tap(find.byKey(LiveBoostSheet.buyKey));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(LiveBoostSheet.confirmKey));
  await tester.pumpAndSettle();
}

LiveRoomSummary _room(String id, {LiveRoomMode mode = LiveRoomMode.solo}) =>
    LiveRoomSummary.fromJson({
      'id': id,
      'title': 'Room $id',
      'topic': null,
      'mode': mode.name.toUpperCase(),
      'host': {
        'id': 'host-$id',
        'username': 'host$id',
        'displayName': 'Host $id',
        'avatarUrl': null,
      },
      'category': null,
      'viewerCount': 3,
      'startedAt': '2026-10-28T12:00:00.000Z',
      'score': 0,
      'coverUrl': null,
    });

void main() {
  for (final language in AppLanguage.values) {
    testWidgets('the host buys a 20-minute card with coins after confirming '
        '(${language.name})', (tester) async {
      final repo = await _pump(tester, language: language);
      final ar = language == AppLanguage.ar;
      expect(find.text(ar ? '20 د' : '20 min'), findsOneWidget);
      expect(find.text('18,000'), findsOneWidget);
      expect(find.text(ar ? 'وفّر 25%' : 'Save 25%'), findsOneWidget);
      expect(
        find.text(ar ? 'يبدأ فوراً.' : 'Starts right away.'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(LiveBoostSheet.optionKey(20)));
      await tester.pumpAndSettle();
      expect(
        find.text(ar ? 'اشترِ بـ 18,000 عملة' : 'Buy for 18,000 coins'),
        findsOneWidget,
      );
      await _confirm(tester);
      expect(repo.bought.single.minutes, 20);
      expect(repo.bought.single.source, LiveBoostSource.coins);
      expect(repo.coins, 32000);
      expect(find.byKey(LiveBoostSheet.stateKey), findsOneWidget);
      expect(find.byKey(LiveBoostSheet.messageKey), findsOneWidget);
      // One card per live: buying again is off.
      final buy = tester.widget<FilledButton>(
        find.byKey(LiveBoostSheet.buyKey),
      );
      expect(buy.onPressed, isNull);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('all slots taken: the sheet says when it starts at the latest', (
    tester,
  ) async {
    final repo = await _pump(
      tester,
      repo: FakeLiveBoostRepository(waitMinutes: 15),
    );
    expect(find.textContaining('within 15 min at the latest'), findsOne);
    await _confirm(tester);
    expect(repo.bought, hasLength(1));
    expect(find.textContaining('Queued'), findsOneWidget);
  });

  testWidgets('a reward card is used instead of coins', (tester) async {
    final repo = await _pump(
      tester,
      repo: FakeLiveBoostRepository(cards: {10: 2}),
    );
    expect(find.text('You have 2'), findsOneWidget);
    await tester.tap(find.byKey(LiveBoostSheet.cardKey));
    await tester.pumpAndSettle();
    expect(find.text('Use the card'), findsOneWidget);
    await _confirm(tester);
    expect(repo.bought.single.source, LiveBoostSource.card);
    expect(repo.coins, 50000);
    expect(repo.cards[10], 1);
  });

  testWidgets('not enough coins: the refusal is said, nothing bought', (
    tester,
  ) async {
    final repo = await _pump(tester, repo: FakeLiveBoostRepository(coins: 5));
    await _confirm(tester);
    expect(repo.bought, isEmpty);
    expect(find.byKey(LiveBoostSheet.messageKey), findsOneWidget);
  });

  testWidgets("a viewer's gift to the host says the host earns nothing", (
    tester,
  ) async {
    await _pump(tester, hostName: 'Sara', language: AppLanguage.ar);
    expect(find.textContaining('المضيف لا يربح منها عملات'), findsOneWidget);
  });

  test('the hub pins the «مميز» lives first and leaves them out below', () {
    final rooms = [_room('a'), _room('b'), _room('c')];
    final content =
        liveHubContent(
              AsyncData(
                LiveHubState(
                  hostingEnabled: true,
                  fetchedAt: DateTime(2026),
                  rooms: rooms,
                ),
              ),
              pinned: [_room('c'), _room('z')],
            ).requireValue
            as FeedItems<LiveRoomCardData>;
    expect(content.items.map((r) => r.roomId), ['c', 'z', 'a', 'b']);
    expect(content.items.map((r) => r.featured), [true, true, false, false]);
  });

  testWidgets('a featured card shows «مميز» and says it', (tester) async {
    setViewport(tester, GoldenViewport.android);
    await pumpScreen(
      tester,
      Center(
        child: SizedBox(
          width: 170,
          height: 190,
          child: KLiveGridCard(
            room: LiveRoomCardData.fromSummary(_room('a'), featured: true),
          ),
        ),
      ),
      language: AppLanguage.ar,
    );
    expect(find.byKey(KLiveGridCard.featuredKey), findsOneWidget);
    expect(find.text('مميز'), findsOneWidget);
  });
}
