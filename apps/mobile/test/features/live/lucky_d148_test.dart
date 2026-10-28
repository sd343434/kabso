// D148 (owner, 2026-10-28): lucky gifts —
// - eight tiers ×5 ×10 ×25 ×50 ×100 ×250 ×500 ×1000: MAX X maps each to
//   its own celebration; the room's big card fires for every ×100+;
// - the guarantee (×5 after 15 losing draws in a row): the normal ×5
//   celebration plus a small «ضمان» / "Guaranteed" label, from the
//   server's `luckyResult.guaranteed`;
// - the odds sheet lists the eight tiers and the guarantee (tested in
//   live_gift_sheet_test with the server's table);
// - «لحظة الحظ»: the gold ticker of a big win in another live, from the
//   `lucky-ticker` data message; a tap opens that live; blocked people's
//   wins are not shown; hideable through a provider flag (D151's switch);
//   reduced motion: no slide.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/application/live_chat_controller.dart';
import 'package:kabso_live/features/live/application/live_gift_effects.dart';
import 'package:kabso_live/features/live/application/live_lucky_combo.dart';
import 'package:kabso_live/features/live/application/live_lucky_ticker.dart';
import 'package:kabso_live/features/live/application/max_x.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/live/domain/live_gift_models.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_gift_effects_layer.dart';
import 'package:kabso_live/features/live/presentation/widgets/max_x_art.dart';
import 'package:kabso_live/features/safety/safety_repository.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_live_media_engine.dart';
import '../../helpers/fake_live_repository.dart';
import '../../helpers/fake_safety_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

UserSummary _user(String id, String name) =>
    UserSummary(id: id, username: id, displayName: name, avatarUrl: null);

LuckyWin _win({
  int multiplier = 500,
  int coins = 5000,
  String room = 'room-b',
  String giftId = 'g-1',
  UserSummary? sender,
}) => LuckyWin(
  giftId: giftId,
  roomId: room,
  giftCode: 'lucky_clover',
  sender: sender ?? _user('u-oz', 'Oz'),
  multiplier: multiplier,
  coinsWon: coins,
  createdAt: DateTime.utc(2026, 10, 28, 12),
);

LuckyTicker _ticker({
  int multiplier = 500,
  int coins = 5000,
  String room = 'room-b',
  String giftId = 'g-1',
  UserSummary? sender,
  UserSummary? host,
  String title = 'Friday night',
}) => LuckyTicker(
  win: _win(
    multiplier: multiplier,
    coins: coins,
    room: room,
    giftId: giftId,
    sender: sender,
  ),
  room: LuckyTickerRoom(
    id: room,
    title: title,
    host: host ?? _user('u-sara', 'Sara'),
  ),
);

Map<String, Object?> _result(int multiplier, {bool? guaranteed}) => {
  'draws': 1,
  'wins': [
    {'multiplier': multiplier, 'count': 1, 'coins': multiplier * 10},
  ],
  'coinsWon': multiplier * 10,
  'topMultiplier': multiplier,
  'downgraded': 0,
  'guaranteed': ?guaranteed,
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

/// The ticker bar of live `room-a` alone on a dark screen.
Future<ProviderContainer> _pumpBar(
  WidgetTester tester, {
  AppLanguage language = AppLanguage.en,
  GoldenViewport viewport = GoldenViewport.android,
  ValueChanged<String>? onOpenRoom,
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
  group('eight tiers', () {
    test('MAX X maps every server tier to its own celebration', () {
      expect(MaxXTiers.win, [5, 10, 25, 50, 100, 250, 500, 1000]);
      for (final tier in MaxXTiers.win) {
        expect(MaxXTiers.winTierOf(tier), tier);
      }
      expect(MaxXTiers.winTierOf(30), 25);
      expect(MaxXTiers.winTierOf(249), 100);
      expect(MaxXTiers.winTierOf(999), 500);
      expect(MaxXTiers.winTierOf(2), 5);
      expect(MaxXTiers.winTierOf(null), isNull);
    });

    test('the room card fires for every ×100+ win (×250 and ×1000 too), '
        'one after the other; ×50 does not', () {
      final c = _container();
      final effects = c.read(liveGiftEffectsProvider('room-b').notifier);
      c.listen(liveGiftEffectsProvider('room-b'), (_, _) {});
      effects.showLucky(_win(multiplier: 50, giftId: 'g-50'));
      expect(c.read(liveGiftEffectsProvider('room-b')).lucky, isNull);
      effects
        ..showLucky(_win(multiplier: 250, giftId: 'g-250'))
        ..showLucky(_win(multiplier: 1000, giftId: 'g-1000'));
      expect(c.read(liveGiftEffectsProvider('room-b')).lucky?.multiplier, 250);
    });
  });

  group('the guarantee', () {
    test('luckyResult.guaranteed reaches the MAX X win; older servers: '
        'false', () {
      final paid = LuckyGiftResult.fromJson(_result(5, guaranteed: true));
      expect(paid.guaranteed, isTrue);
      expect(MaxXWin.of(paid, id: 1)?.guaranteed, isTrue);
      final old = LuckyGiftResult.fromJson(_result(5));
      expect(old.guaranteed, isFalse);
      expect(MaxXWin.of(old, id: 2)?.guaranteed, isFalse);
    });

    for (final language in AppLanguage.values) {
      testWidgets('${language.name}: the ×5 celebration says «ضمان» / '
          'Guaranteed only for the guarantee', (tester) async {
        final l10n = l10nFor(language);
        Future<MaxXWinPainter> pump({required bool guaranteed}) async {
          setViewport(tester, GoldenViewport.android);
          await pumpScreen(
            tester,
            Scaffold(
              body: Stack(
                children: [
                  MaxXCelebration(
                    key: ValueKey(guaranteed),
                    win: MaxXWin(
                      id: 1,
                      multiplier: 5,
                      coins: 50,
                      guaranteed: guaranteed,
                    ),
                    centre: const Offset(180, 500),
                    radius: 40,
                    onDone: () {},
                  ),
                ],
              ),
            ),
            language: language,
          );
          await tester.pump(const Duration(milliseconds: 300));
          return tester
              .widgetList<CustomPaint>(find.byType(CustomPaint))
              .map((c) => c.painter)
              .whereType<MaxXWinPainter>()
              .single;
        }

        final paid = await pump(guaranteed: true);
        expect(paid.style.tier, 5);
        expect(paid.title, l10n.liveMaxXGuaranteed);
        expect(
          find.bySemanticsLabel(RegExp('^${l10n.liveMaxXGuaranteed}, ')),
          findsOneWidget,
        );
        await tester.pump(const Duration(seconds: 3));
        final normal = await pump(guaranteed: false);
        expect(normal.title, isNull);
        await tester.pump(const Duration(seconds: 3));
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('«لحظة الحظ»: the global ticker', () {
    test('the lucky-ticker data message parses; unknown ones are ignored', () {
      final event = LiveChatEvent.parse({
        'type': 'lucky-ticker',
        'win': {
          'giftId': 'g-1',
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
          'createdAt': '2026-10-28T12:00:00.000Z',
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
      });
      expect(event, isA<LuckyTickerReceived>());
      final t = (event! as LuckyTickerReceived).ticker;
      expect(t.win.multiplier, 1000);
      expect(t.room.title, 'Friday night');
      expect(LiveChatEvent.parse({'type': 'lucky-ticker'}), isNull);
    });

    test('one at a time; the biggest waits first; its own live and repeats '
        'are skipped; blocked senders and hosts are never shown', () async {
      final c = _container(blocked: [_user('u-bad', 'Bad')]);
      final engine = FakeLiveMediaEngine();
      // The room's chat is alive while the room shows (it holds the blocks).
      c.listen(liveChatProvider('room-a'), (_, _) {});
      await c
          .read(liveChatProvider('room-a').notifier)
          .attach(engine, enabled: true, muted: false);
      // The room's chat loads the block list in the background.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final tickers = c.read(liveLuckyTickersProvider('room-a').notifier);
      c.listen(liveLuckyTickersProvider('room-a'), (_, _) {});
      tickers.attach(engine);

      engine.chat.add(LuckyTickerReceived(_ticker(room: 'room-a')));
      await Future<void>.delayed(Duration.zero);
      expect(c.read(liveLuckyTickersProvider('room-a')), isNull);

      tickers
        ..show(_ticker(giftId: 'blocked', sender: _user('u-bad', 'Bad')))
        ..show(_ticker(giftId: 'host', host: _user('u-bad', 'Bad')));
      expect(c.read(liveLuckyTickersProvider('room-a')), isNull);

      engine.chat.add(LuckyTickerReceived(_ticker(multiplier: 100)));
      await Future<void>.delayed(Duration.zero);
      expect(c.read(liveLuckyTickersProvider('room-a'))?.win.multiplier, 100);
      tickers
        ..show(_ticker()) // g-1 again: a repeat, dropped
        ..show(_ticker(multiplier: 250, giftId: 'g-2'))
        ..show(_ticker(multiplier: 1000, giftId: 'g-3'))
        ..show(_ticker(multiplier: 100, giftId: 'g-4', coins: 100))
        ..show(_ticker(giftId: 'g-5'));
      final order = <int>[];
      for (var i = 0; i < 4; i++) {
        tickers.dismiss();
        order.add(
          c.read(liveLuckyTickersProvider('room-a'))?.win.multiplier ?? 0,
        );
      }
      // The biggest first; ×100 (the smallest) was dropped from the line.
      expect(order, [1000, 500, 250, 0]);
    });

    for (final language in AppLanguage.values) {
      for (final viewport in GoldenViewport.values) {
        testWidgets('${language.name} ${viewport.name}: a compact gold line '
            '«name won ×N in room», on screen; a tap opens that live', (
          tester,
        ) async {
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
                  sender: _user('u-oz', 'Oz Nabulsi with a long name'),
                  title: 'A very long live title that goes on and on',
                ),
              );
          await tester.pumpAndSettle();
          final bar = find.byKey(LiveLuckyTickerBar.tickerKey);
          expect(bar, findsOneWidget);
          final l10n = l10nFor(language);
          final text = tester
              .widgetList<Text>(
                find.descendant(of: bar, matching: find.byType(Text)),
              )
              .map((t) => t.data ?? '')
              .singleWhere((t) => t.contains('×'));
          expect(text, contains('×1,000'));
          expect(text, contains('Oz Nabulsi'));
          expect(
            text,
            l10n.liveLuckyTicker(
              '\u2068Oz Nabulsi with a long name\u2069',
              '1,000',
              '\u2068A very long live title that goes on and on\u2069',
            ),
          );
          final rect = tester.getRect(bar);
          expect(rect.height, lessThanOrEqualTo(48));
          expect(rect.width, lessThanOrEqualTo(LiveLuckyTickerBar.maxWidth));
          expect(
            (Offset.zero & viewport.logicalSize).contains(rect.topLeft),
            isTrue,
          );
          expect(
            (Offset.zero & viewport.logicalSize).contains(rect.bottomRight),
            isTrue,
          );
          expect(tester.takeException(), isNull);
          await tester.tap(bar);
          await tester.pumpAndSettle();
          expect(opened, ['room-b']);
          expect(find.byKey(LiveLuckyTickerBar.tickerKey), findsNothing);
        });
      }
    }

    testWidgets('gone after its time; not a button without onOpenRoom (the '
        'host on air); hidden by the provider flag', (tester) async {
      final c = await _pumpBar(tester);
      final tickers = c.read(liveLuckyTickersProvider('room-a').notifier)
        ..show(_ticker());
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.byKey(const ValueKey('ticker.g-1'))),
        isNot(isSemantics(isButton: true)),
      );
      await tester.pump(LiveLuckyTickers.showTime);
      await tester.pumpAndSettle();
      expect(find.byKey(LiveLuckyTickerBar.tickerKey), findsNothing);

      c.read(luckyTickerHiddenProvider.notifier).hidden = true;
      tickers.show(_ticker(giftId: 'g-2'));
      await tester.pumpAndSettle();
      expect(find.byKey(LiveLuckyTickerBar.tickerKey), findsNothing);
      c.read(luckyTickerHiddenProvider.notifier).hidden = false;
      await tester.pumpAndSettle();
      expect(find.byKey(LiveLuckyTickerBar.tickerKey), findsOneWidget);
      await tester.pump(LiveLuckyTickers.showTime);
      await tester.pumpAndSettle();
    });

    testWidgets('reduced motion: it appears without sliding', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final c = await _pumpBar(tester, onOpenRoom: (_) {});
      c.read(liveLuckyTickersProvider('room-a').notifier).show(_ticker());
      await tester.pump();
      final bar = find.byKey(LiveLuckyTickerBar.tickerKey);
      expect(bar, findsOneWidget);
      // At its place at once (no slide in progress).
      final y = tester.getRect(bar).top;
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.getRect(bar).top, y);
      expect(
        tester.getSemantics(find.byKey(const ValueKey('ticker.g-1'))),
        isSemantics(isButton: true),
      );
      await tester.pump(LiveLuckyTickers.showTime);
    });
  });
}
