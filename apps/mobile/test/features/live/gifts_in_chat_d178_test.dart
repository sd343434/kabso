// D178 (owner: «عندما يلعب أحد هدايا الحظ لا يظهر المكسب في التكست،
// والشرائط يجب أن تكون ظاهرة عند الجميع حتى الصغيرة. والهدايا يجب أن تظهر
// في شريط في جميع البثوث، بالإضافة تظهر في تكست البث الذي أُرسلت فيه
// الهدية»), through the real viewer screen: gift and win lines in the chat,
// a small win's banner for everyone, the global gift strip.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/application/live_gift_effects.dart';
import 'package:kabso_live/features/live/application/live_gift_ticker.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/live/domain/live_gift_models.dart';
import 'package:kabso_live/features/live/live_room_screen.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_chat_gift_line.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_gift_ticker_bar.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../fixtures/live/live_gift_fixtures.dart';
import '../../helpers/fake_live_gift_repository.dart';
import '../../helpers/fake_live_media_engine.dart';
import '../../helpers/fake_live_repository.dart';
import '../../helpers/fake_profile_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

const _omar = UserSummary(
  id: 'user-omar',
  username: 'omar',
  displayName: 'Omar',
  avatarUrl: null,
);

LiveGift _gift(String id, {int quantity = 1, String at = '12:00:00'}) =>
    LiveGift.fromJson({
      ...liveGiftJson(
        id: id,
        quantity: quantity,
        sender: giftUserJson('lina', 'Lina'),
        recipients: [giftUserJson('sara', 'Sara')],
      ),
      'createdAt': '2026-10-30T$at.000Z',
    });

LuckyWin _win(String id, int multiplier, int coins) => LuckyWin(
  giftId: id,
  roomId: 'room-0',
  giftCode: 'rose',
  sender: _omar,
  multiplier: multiplier,
  coinsWon: coins,
  createdAt: DateTime.utc(2026, 10, 30, 12),
);

Future<(FakeLiveMediaEngine, List<String>)> _pump(
  WidgetTester tester, {
  AppLanguage language = AppLanguage.en,
}) async {
  setViewport(tester, GoldenViewport.phone);
  final engine = FakeLiveMediaEngine()..present.add('user-0');
  final opened = <String>[];
  await pumpScreen(
    tester,
    const LiveRoomScreen(roomId: 'room-0'),
    language: language,
    liveMediaEngine: engine,
    liveGiftRepository: FakeLiveGiftRepository(codes: giftFixtureCodes),
    overrides: [
      liveRepositoryProvider.overrideWithValue(
        FakeLiveRepository(room: (id) => apiRoom(id: id)),
      ),
      profileRepositoryProvider.overrideWithValue(
        FakeProfileRepository(apiProfile()),
      ),
      currentUserProvider.overrideWithValue(testUser()),
    ],
  );
  await tester.pumpAndSettle();
  return (engine, opened);
}

Future<void> _leave(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 10));
}

void main() {
  final en = l10nFor(AppLanguage.en);

  testWidgets("a gift message is a chat line; the same sender's taps add to "
      'one line', (tester) async {
    final (engine, _) = await _pump(tester);
    engine.chat
      ..add(LiveGiftReceived(_gift('g1', quantity: 3)))
      ..add(LiveGiftReceived(_gift('g2', quantity: 2, at: '12:00:02')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final lines = find.byType(LiveChatGiftLineView);
    expect(lines, findsOneWidget);
    expect(
      find.descendant(
        of: lines,
        matching: find.text(
          en.liveChatGiftLine(
            '\u2068Lina\u2069',
            '\u2068Rose\u2069',
            5,
            '\u2068Sara\u2069',
          ),
        ),
      ),
      findsOneWidget,
    );
    // Much later: a new line.
    engine.chat.add(LiveGiftReceived(_gift('g3', at: '12:01:00')));
    await tester.pump();
    expect(find.byType(LiveChatGiftLineView), findsNWidgets(2));
    await _leave(tester);
  });

  testWidgets('a small lucky win (×5) reaches every viewer: its banner and '
      'its chat line', (tester) async {
    final (engine, _) = await _pump(tester);
    engine.chat.add(LuckyWinReceived(_win('w1', 5, 50)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final element = tester.element(find.byType(LiveRoomScreen));
    final container = ProviderScope.containerOf(element);
    expect(
      container.read(liveGiftEffectsProvider('room-0')).lucky?.multiplier,
      5,
    );
    expect(
      find.text(en.liveChatLuckyLine('\u2068Omar\u2069', '5', '50')),
      findsOneWidget,
    );
    await _leave(tester);
  });

  testWidgets('a big gift in another live is the global strip (3 s); one of '
      'this live is not', (tester) async {
    final (engine, _) = await _pump(tester);
    GiftTicker ticker(String id, String room) => GiftTicker(
      gift: LiveGift.fromJson({
        ...liveGiftJson(
          id: id,
          roomId: room,
          quantity: 9,
          sender: giftUserJson('nour', 'Nour'),
          recipients: [giftUserJson('host9', 'Host 9')],
        ),
      }),
      room: LuckyTickerRoom(id: room, title: 'Party', host: _omar),
    );
    engine.chat.add(GiftTickerReceived(ticker('t0', 'room-0')));
    await tester.pump();
    expect(find.byKey(LiveGiftTickerBar.tickerKey), findsNothing);
    engine.chat.add(GiftTickerReceived(ticker('t1', 'room-9')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(LiveGiftTickerBar.tickerKey), findsOneWidget);
    expect(LiveGiftTickers.showTime, const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.byKey(LiveGiftTickerBar.tickerKey), findsNothing);
    await _leave(tester);
  });
}
