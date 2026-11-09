// D347 (owner, 2026-11-09: «شريط المردود يظهر في كل لايفات للشريط x250 /
// x500 / x1000», CONVENTIONS §10.146): the global lucky banner —
// - the server sends `lucky-ticker` for a ×250 / ×500 / ×1000 win to every
//   other live (its set, `LUCKY_GLOBAL_BANNER_MULTIPLIERS`); the message now
//   carries the gift's art (`gift`) and the live's mode;
// - the app shows it as the room's own win banner «شريط المردود» with a tag
//   under it: the winner's avatar, «في {room}», the gift and a chevron;
// - a tap opens that live; a host on air (no onOpenRoom) gets no button;
// - never in the live the win happened in (it has its own banner); one at a
//   time, the biggest first, at most 3 waiting, none older than 30 s;
// - reduced motion: still.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/application/live_lucky_ticker.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/live/domain/live_gift_models.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_gift_effects_layer.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_win_banner.dart';
import 'package:kabso_live/features/safety/safety_repository.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_live_repository.dart';
import '../../helpers/fake_safety_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

UserSummary _user(String id, String name) =>
    UserSummary(id: id, username: id, displayName: name, avatarUrl: null);

const _clover = LuckyTickerGift(
  code: 'lucky_clover',
  assetKey: 'gift_lucky_clover',
);

LuckyTicker _ticker({
  int multiplier = 500,
  int coins = 5000,
  String room = 'room-b',
  String giftId = 'g-1',
  String name = 'Oz',
  String title = 'Friday night',
}) => LuckyTicker(
  win: LuckyWin(
    giftId: giftId,
    roomId: room,
    giftCode: 'lucky_clover',
    sender: _user('u-oz', name),
    multiplier: multiplier,
    coinsWon: coins,
    createdAt: DateTime.utc(2026, 11, 9, 12),
  ),
  room: LuckyTickerRoom(id: room, title: title, host: _user('u-sara', 'Sara')),
);

Map<String, Object?> _wire({Object? gift}) => {
  'type': 'lucky-ticker',
  'win': {
    'giftId': 'g-9',
    'roomId': 'room-b',
    'giftCode': 'lucky_clover',
    'sender': {
      'id': 'u-oz',
      'username': 'oz',
      'displayName': 'Oz',
      'avatarUrl': null,
    },
    'multiplier': 1000,
    'coinsWon': 10000,
    'createdAt': '2026-11-09T12:00:00.000Z',
  },
  'gift': ?gift,
  'room': {
    'id': 'room-b',
    'title': 'Friday night',
    'mode': 'AUDIO',
    'host': {
      'id': 'u-sara',
      'username': 'sara',
      'displayName': 'Sara',
      'avatarUrl': null,
    },
  },
};

ProviderContainer _container() {
  final c = ProviderContainer(
    overrides: [
      liveRepositoryProvider.overrideWithValue(FakeLiveRepository()),
      safetyRepositoryProvider.overrideWithValue(FakeSafetyRepository()),
      currentUserProvider.overrideWithValue(testUser()),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

/// The banner of live `room-a` where the effects layer puts it.
Future<ProviderContainer> _pumpBar(
  WidgetTester tester, {
  AppLanguage language = AppLanguage.en,
  GoldenViewport viewport = GoldenViewport.phone,
  ValueChanged<String>? onOpenRoom,
  bool still = false,
}) async {
  setViewport(tester, viewport);
  await pumpScreen(
    tester,
    Scaffold(
      backgroundColor: const Color(0xFF101018),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: 96,
            left: 16,
            right: 16,
            child: Align(
              alignment: Alignment.topCenter,
              child: LiveLuckyTickerBar(
                roomId: 'room-a',
                onOpenRoom: onOpenRoom,
              ),
            ),
          ),
        ],
      ),
    ),
    language: language,
    disableAnimations: still,
    overrides: [
      liveRepositoryProvider.overrideWithValue(FakeLiveRepository()),
      currentUserProvider.overrideWithValue(testUser()),
    ],
  );
  return ProviderScope.containerOf(
    tester.element(find.byType(LiveLuckyTickerBar)),
  );
}

void main() {
  group('the lucky-ticker message (v1.111-live)', () {
    test('carries the gift art; an older server (no gift) or a bad one '
        'still shows the banner without it', () {
      final event =
          LiveChatEvent.parse(
                _wire(
                  gift: {
                    'code': 'lucky_clover',
                    'assetKey': 'gift_lucky_clover',
                    'imageUrl': 'https://media.example/clover.webp',
                  },
                ),
              )!
              as LuckyTickerReceived;
      expect(event.ticker.win.multiplier, 1000);
      expect(event.ticker.room.title, 'Friday night');
      expect(event.gift?.assetKey, 'gift_lucky_clover');
      expect(event.gift?.imageUrl, 'https://media.example/clover.webp');
      final old = LiveChatEvent.parse(_wire())! as LuckyTickerReceived;
      expect(old.gift, isNull);
      final bad =
          LiveChatEvent.parse(_wire(gift: {'code': 3}))! as LuckyTickerReceived;
      expect(bad.gift, isNull);
    });
  });

  group('the queue', () {
    tearDown(() => LiveLuckyTickers.now = DateTime.now);

    test('never in the live the win happened in (it has its own banner); a '
        'repeat is dropped; the biggest waits first, at most 3; a banner '
        'that waited more than 30 s is dropped', () {
      final c = _container()
        ..listen(liveLuckyTickersProvider('room-a'), (_, _) {});
      final q = c.read(liveLuckyTickersProvider('room-a').notifier)
        ..show(_ticker(room: 'room-a'));
      expect(c.read(liveLuckyTickersProvider('room-a')), isNull);

      var at = DateTime.utc(2026, 11, 9, 12);
      LiveLuckyTickers.now = () => at;
      q
        ..show(_ticker(multiplier: 250), gift: _clover)
        ..show(_ticker(multiplier: 250)) // g-1 again
        ..show(_ticker(giftId: 'g-2')) // ×500
        ..show(_ticker(multiplier: 1000, giftId: 'g-3'))
        ..show(_ticker(multiplier: 250, giftId: 'g-4', coins: 10))
        ..show(_ticker(multiplier: 250, giftId: 'g-5', coins: 9000));
      final shown = c.read(liveLuckyTickersProvider('room-a'))!;
      expect(shown.win.giftId, 'g-1');
      expect(shown.gift, same(_clover));
      q.dismiss();
      expect(c.read(liveLuckyTickersProvider('room-a'))?.win.giftId, 'g-3');
      q.dismiss();
      expect(c.read(liveLuckyTickersProvider('room-a'))?.win.giftId, 'g-2');
      // The smaller ×250 (10 coins) was dropped when the line was full.
      at = at.add(const Duration(seconds: 31));
      q.dismiss();
      expect(c.read(liveLuckyTickersProvider('room-a')), isNull);
    });
  });

  group('the banner', () {
    for (final language in AppLanguage.values) {
      for (final viewport in GoldenViewport.values) {
        testWidgets('${language.name} ${viewport.name}: the room banner '
            '«شريط المردود» with the name of the live, on screen; a tap opens '
            'that live', (tester) async {
          final opened = <String>[];
          final c = await _pumpBar(
            tester,
            language: language,
            viewport: viewport,
            onOpenRoom: opened.add,
          );
          expect(find.byKey(LiveLuckyTickerBar.tickerKey), findsNothing);
          c
              .read(liveLuckyTickersProvider('room-a').notifier)
              .show(
                _ticker(
                  multiplier: 1000,
                  name: 'Oz Nabulsi with a long name',
                  title: 'A very long live title that goes on and on',
                ),
                gift: _clover,
              );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 900));
          final bar = find.byKey(LiveLuckyTickerBar.tickerKey);
          expect(bar, findsOneWidget);
          expect(
            find.descendant(
              of: bar,
              matching: find.byKey(LiveWinBanner.frameKey),
            ),
            findsOneWidget,
          );
          final l10n = l10nFor(language);
          final tag = find.byKey(LiveWinBanner.roomKey);
          expect(
            find.descendant(
              of: tag,
              matching: find.text(
                l10n.liveLuckyGlobalIn(
                  '\u2068A very long live title that goes on and on\u2069',
                ),
              ),
            ),
            findsOneWidget,
          );
          final rect = tester.getRect(bar);
          final screen = Offset.zero & viewport.logicalSize;
          expect(screen.contains(rect.topLeft), isTrue);
          expect(screen.contains(rect.bottomRight), isTrue);
          expect(rect.width, lessThanOrEqualTo(LiveWinBanner.maxWidth));
          expect(
            tester.getSemantics(find.byKey(const ValueKey('ticker.g-1'))),
            isSemantics(isButton: true, hasTapAction: true),
          );
          expect(tester.takeException(), isNull);
          await tester.tap(tag);
          await tester.pump();
          expect(opened, ['room-b']);
          expect(find.byKey(LiveLuckyTickerBar.tickerKey), findsNothing);
        });
      }
    }

    testWidgets('a host on air (no onOpenRoom): no button, a tap does '
        'nothing; gone after its time; hidden by the provider flag', (
      tester,
    ) async {
      final c = await _pumpBar(tester);
      final q = c.read(liveLuckyTickersProvider('room-a').notifier)
        ..show(_ticker());
      await tester.pump(const Duration(milliseconds: 900));
      expect(
        tester.getSemantics(find.byKey(const ValueKey('ticker.g-1'))),
        isNot(isSemantics(isButton: true)),
      );
      await tester.tap(
        find.byKey(LiveLuckyTickerBar.tickerKey),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(find.byKey(LiveLuckyTickerBar.tickerKey), findsOneWidget);
      await tester.pump(LiveLuckyTickers.showTime);
      expect(find.byKey(LiveLuckyTickerBar.tickerKey), findsNothing);

      c.read(luckyTickerHiddenProvider.notifier).hidden = true;
      q.show(_ticker(giftId: 'g-2'));
      await tester.pump();
      expect(find.byKey(LiveLuckyTickerBar.tickerKey), findsNothing);
      c.read(luckyTickerHiddenProvider.notifier).hidden = false;
      await tester.pump();
      expect(find.byKey(LiveLuckyTickerBar.tickerKey), findsOneWidget);
      await tester.pump(LiveLuckyTickers.showTime);
    });

    testWidgets('reduced motion: it shows still (no slide)', (tester) async {
      final c = await _pumpBar(tester, onOpenRoom: (_) {}, still: true);
      c.read(liveLuckyTickersProvider('room-a').notifier).show(_ticker());
      await tester.pump();
      final frame = find.byKey(LiveWinBanner.frameKey);
      final x = tester.getRect(frame).left;
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.getRect(frame).left, x);
      await tester.pump(LiveLuckyTickers.showTime);
    });
  });
}
