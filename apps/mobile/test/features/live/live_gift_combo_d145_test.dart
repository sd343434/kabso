// D145 (owner, after another app's screen recording; lucky gifts only):
// after a lucky gift is sent the panel closes and a round Combo button with
// a 4 s countdown ring sends the same gift again on every tap; taps queue
// and go one at a time (never lost, never charged twice); the balance
// follows; a refusal stops the combo and says why. Normal gifts keep the
// panel and its Send. Also D145: the gift strips (three at once, newest on
// top, a tap opens the sender) and the full-screen effect contained in the
// safe area on every phone size.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/application/live_gift_effects.dart';
import 'package:kabso_live/features/live/application/live_lucky_combo.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/live/domain/live_gift_models.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_gift_art.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_gift_effects_layer.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_gift_sheet.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_lucky_combo_button.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_gift_fixtures.dart';
import '../../helpers/fake_live_gift_repository.dart';
import '../../helpers/fake_live_media_engine.dart';
import '../../helpers/fake_live_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

const _host = UserSummary(
  id: 'user-sara',
  username: 'sara',
  displayName: 'Sara',
  avatarUrl: null,
);

const _open = Key('test.openGifts');

class _Room extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: TextButton(
            key: _open,
            onPressed: () => unawaited(
              KLiveGiftSheet.show(
                context,
                room: LiveGiftRoom(
                  roomId: 'room-0',
                  host: _host,
                  seated: (_) => const [],
                ),
              ),
            ),
            child: const SizedBox.square(dimension: 40),
          ),
        ),
        const LuckyComboLayer(roomId: 'room-0', hostUsername: 'sara'),
      ],
    ),
  );
}

class _H {
  new(this.gifts, this.live);

  final FakeLiveGiftRepository gifts;
  final FakeLiveRepository live;
}

Future<_H> _pump(
  WidgetTester tester, {
  int coins = 1000,
  AppLanguage language = AppLanguage.en,
  GoldenViewport viewport = GoldenViewport.phone,
}) async {
  setViewport(tester, viewport);
  final h = _H(
    FakeLiveGiftRepository(
      codes: [...giftFixtureCodes, 'lucky_clover'],
      coins: coins,
      ar: language == AppLanguage.ar,
    )..categories = const ['POPULAR', 'EVENT', 'FUN', 'LUCKY'],
    FakeLiveRepository()..coins = coins,
  );
  await pumpScreen(
    tester,
    const _Room(),
    language: language,
    liveGiftRepository: h.gifts,
    overrides: [
      liveRepositoryProvider.overrideWithValue(h.live),
      currentUserProvider.overrideWithValue(testUser()),
    ],
  );
  await tester.tap(find.byKey(_open));
  await tester.pumpAndSettle();
  return h;
}

/// Frames for [d] in 100 ms steps (never pumpAndSettle: the ring runs).
Future<void> _run(WidgetTester tester, Duration d) async {
  var left = d;
  const step = Duration(milliseconds: 100);
  while (left > Duration.zero) {
    await tester.pump(left < step ? left : step);
    left -= step;
  }
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.tap(f);
  await tester.pumpAndSettle();
}

/// Picks the lucky gift and sends it from the panel.
Future<void> _sendLucky(WidgetTester tester) async {
  await _tap(tester, find.byKey(KLiveGiftSheet.tabKey('LUCKY')));
  await _tap(tester, find.byKey(KLiveGiftSheet.cellKey('lucky_clover')));
  await tester.tap(find.byKey(KLiveGiftSheet.sendKey));
  await _run(tester, const Duration(milliseconds: 600));
}

final Finder _button = find.byKey(LuckyComboLayer.buttonKey);

Future<void> _combo(WidgetTester tester) async {
  await tester.tap(_button);
  await _run(tester, const Duration(milliseconds: 300));
}

String? _text(WidgetTester tester, Key key) {
  final f = find.descendant(of: find.byKey(key), matching: find.byType(Text));
  if (f.evaluate().isEmpty) return null;
  return tester.widget<Text>(f.first).data;
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(LuckyComboLayer)));

void main() {
  final en = l10nFor(AppLanguage.en);

  group('the combo button (lucky gifts only)', () {
    testWidgets('a lucky send closes the panel and shows the button with its '
        'ring, ×1 and the balance; a normal gift keeps the panel and shows '
        'no combo', (tester) async {
      final h = await _pump(tester);
      // A normal gift first: the panel stays, no combo.
      await _tap(tester, find.byKey(KLiveGiftSheet.cellKey('rose')));
      await tester.tap(find.byKey(KLiveGiftSheet.sendKey));
      await _run(tester, const Duration(milliseconds: 600));
      expect(h.gifts.sends, hasLength(1));
      expect(find.byKey(KLiveGiftSheet.sheetKey), findsOneWidget);
      expect(_button, findsNothing);
      // Then a lucky one.
      await _sendLucky(tester);
      expect(h.gifts.sends, hasLength(2));
      expect(find.byKey(KLiveGiftSheet.sheetKey), findsNothing);
      expect(_button, findsOneWidget);
      expect(find.byKey(LuckyComboLayer.ringKey), findsOneWidget);
      expect(_text(tester, LuckyComboLayer.countKey), en.giftCombo(1));
      expect(find.text(en.liveComboLabel), findsOneWidget);
      // 1000 − 1 (rose) − 10 (clover).
      expect(_text(tester, LuckyComboLayer.balanceKey), '989');
      expect(_text(tester, LuckyComboLayer.resultKey), en.liveLuckyNoWin);
      await _run(tester, const Duration(seconds: 5));
    });

    testWidgets('each tap sends the same gift to the same people again (a new '
        'clientId each), ×N grows and the ring restarts; 4 s without a tap '
        'and it goes', (tester) async {
      final h = await _pump(tester);
      await _sendLucky(tester);
      await _run(tester, const Duration(seconds: 3));
      await _combo(tester);
      // 3.3 s after the send: still there (the tap restarted the ring).
      await _run(tester, const Duration(seconds: 3));
      expect(_button, findsOneWidget);
      await _combo(tester);
      expect(h.gifts.sends, hasLength(3));
      for (final s in h.gifts.sends) {
        expect(s.giftCode, 'lucky_clover');
        expect(s.recipients, ['sara']);
        expect(s.quantity, 1);
        expect(s.source, LiveGiftSource.coins);
      }
      expect({for (final s in h.gifts.sends) s.clientId}, hasLength(3));
      expect(_text(tester, LuckyComboLayer.countKey), en.giftCombo(3));
      expect(_text(tester, LuckyComboLayer.balanceKey), '970');
      await _run(tester, const Duration(milliseconds: 3500));
      expect(_button, findsOneWidget);
      await _run(tester, const Duration(milliseconds: 700));
      expect(_button, findsNothing);
      expect(h.gifts.sends, hasLength(3));
    });

    testWidgets('quick taps queue and go one at a time: none lost, none sent '
        'twice, the balance follows; the lucky results add up', (tester) async {
      final h = await _pump(tester);
      await _sendLucky(tester);
      final gate = Completer<void>();
      h.gifts.sendGate = gate;
      for (var i = 0; i < 5; i++) {
        await tester.tap(_button);
        await tester.pump(const Duration(milliseconds: 50));
      }
      // One in flight, four waiting.
      expect(h.gifts.sends, hasLength(2));
      expect(
        _container(tester).read(liveLuckyComboProvider('room-0')).queued,
        4,
      );
      h.gifts
        ..sendGate = null
        ..nextLucky = {
          'draws': 1,
          'wins': [
            {'multiplier': 5, 'count': 1, 'coins': 50},
          ],
          'coinsWon': 50,
          'topMultiplier': 5,
          'downgraded': 0,
        };
      gate.complete();
      await _run(tester, const Duration(milliseconds: 600));
      expect(h.gifts.sends, hasLength(6));
      expect({for (final s in h.gifts.sends) s.clientId}, hasLength(6));
      // 1000 − 6 × 10 + 50 won.
      expect(h.gifts.coins, 990);
      expect(_text(tester, LuckyComboLayer.balanceKey), '990');
      expect(_text(tester, LuckyComboLayer.countKey), en.giftCombo(6));
      expect(
        _text(tester, LuckyComboLayer.resultKey),
        en.liveLuckyWon('\u206850\u2069', '5'),
      );
      await _run(tester, const Duration(seconds: 5));
    });

    testWidgets('a tap the balance cannot pay stops the combo without a '
        'request and says so', (tester) async {
      final h = await _pump(tester, coins: 25);
      await _sendLucky(tester);
      await _combo(tester);
      expect(h.gifts.sends, hasLength(2));
      // 5 coins left: the next tap is not sent.
      await tester.tap(_button);
      await _run(tester, const Duration(milliseconds: 300));
      expect(h.gifts.sends, hasLength(2));
      expect(_button, findsNothing);
      expect(
        _text(tester, LuckyComboLayer.messageKey),
        en.liveGiftNotEnoughCoins,
      );
      await _run(tester, LuckyComboLayer.messageTime);
      expect(find.byKey(LuckyComboLayer.messageKey), findsNothing);
    });

    testWidgets('a refusal stops the combo with the real reason; queued taps '
        'are dropped', (tester) async {
      final h = await _pump(tester);
      await _sendLucky(tester);
      const ended = ServerFailure(
        code: ErrorCode.liveRoomEnded,
        rawCode: 'LIVE_ROOM_ENDED',
        debugMessage: 'x',
        statusCode: 409,
      );
      h.gifts.failNext['send'] = ended;
      await tester.tap(_button);
      await tester.tap(_button);
      await _run(tester, const Duration(milliseconds: 400));
      expect(_button, findsNothing);
      expect(
        _text(tester, LuckyComboLayer.messageKey),
        failureMessage(en, ended),
      );
      expect(h.gifts.sends, hasLength(2));
      expect(h.gifts.coins, 990);
      await _run(tester, const Duration(seconds: 5));
    });

    testWidgets('an answer lost to the network is sent once more with the '
        'same clientId: charged once', (tester) async {
      final h = await _pump(tester);
      await _sendLucky(tester);
      h.gifts.failNext['send'] = const NetworkFailure.timeout();
      await _combo(tester);
      expect(h.gifts.sends, hasLength(3));
      expect(h.gifts.sends[1].clientId, h.gifts.sends[2].clientId);
      expect(h.gifts.coins, 980);
      expect(_button, findsOneWidget);
      expect(_text(tester, LuckyComboLayer.countKey), en.giftCombo(2));
      await _run(tester, const Duration(seconds: 5));
    });

    testWidgets("the panel's quantity is kept; a panel tap still waiting goes "
        'with the combo', (tester) async {
      final h = await _pump(tester);
      Navigator.of(tester.element(find.byKey(KLiveGiftSheet.sheetKey))).pop();
      await tester.pumpAndSettle();
      final container = _container(tester);
      final first = await h.gifts.send(
        'room-0',
        giftCode: 'lucky_clover',
        quantity: 10,
        recipients: const ['sara'],
        source: LiveGiftSource.coins,
        clientId: 'c-0',
      );
      container
          .read(liveLuckyComboProvider('room-0').notifier)
          .start(
            const LuckyComboGift(
              code: 'lucky_clover',
              quantity: 10,
              recipients: ['sara'],
              unitPrice: 10,
              assetKey: 'gift_clover',
            ),
            first,
            pending: 1,
          );
      await _run(tester, const Duration(milliseconds: 300));
      expect(h.gifts.sends, hasLength(2));
      expect(h.gifts.sends.last.quantity, 10);
      await _combo(tester);
      expect(h.gifts.sends, hasLength(3));
      expect(h.gifts.sends.last.quantity, 10);
      await _run(tester, const Duration(seconds: 5));
    });

    testWidgets('a tap flies the gift up; with reduced motion nothing flies '
        'and the button does not pulse', (tester) async {
      await _pump(tester);
      await _sendLucky(tester);
      await tester.tap(_button);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(LuckyComboLayer.flightKey), findsOneWidget);
      await _run(tester, const Duration(seconds: 5));
      await tester.pumpWidget(const SizedBox.shrink());

      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await _pump(tester);
      await _sendLucky(tester);
      await tester.tap(_button);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(LuckyComboLayer.flightKey), findsNothing);
      await _run(tester, const Duration(milliseconds: 500));
      final ring = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byKey(LuckyComboLayer.ringKey),
          matching: find.byType(CustomPaint),
        ),
      );
      expect((ring.painter! as ComboRingPainter).glow, 0);
      // The ring still counts down.
      expect((ring.painter! as ComboRingPainter).remaining, lessThan(1));
      await _run(tester, const Duration(seconds: 5));
    });

    for (final language in AppLanguage.values) {
      for (final viewport in GoldenViewport.values) {
        testWidgets('placement (${language.name}, ${viewport.name}, text 1.3): '
            'centred over the bar, ×N on the reading end, inside the screen', (
          tester,
        ) async {
          tester.platformDispatcher.textScaleFactorTestValue = 1.3;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await _pump(tester, language: language, viewport: viewport);
          await _sendLucky(tester);
          final size = viewport.logicalSize;
          final button = tester.getRect(_button);
          expect((button.center.dx - size.width / 2).abs(), lessThan(1));
          expect(button.width, LuckyComboLayer.size);
          expect(button.bottom, lessThan(size.height - 60));
          final count = tester.getRect(find.byKey(LuckyComboLayer.countKey));
          if (language == AppLanguage.ar) {
            expect(count.right, lessThanOrEqualTo(button.left + 1));
          } else {
            expect(count.left, greaterThanOrEqualTo(button.right - 1));
          }
          for (final key in [
            LuckyComboLayer.resultKey,
            LuckyComboLayer.balanceKey,
          ]) {
            final r = tester.getRect(find.byKey(key));
            expect(r.left, greaterThanOrEqualTo(0));
            expect(r.right, lessThanOrEqualTo(size.width));
          }
          expect(tester.takeException(), isNull);
          await _run(tester, const Duration(seconds: 5));
        });
      }
    }
  });

  group('the gift strips', () {
    testWidgets('a tap on a strip opens the sender; the strips draw over the '
        'large effect', (tester) async {
      setViewport(tester, GoldenViewport.phone);
      final engine = FakeLiveMediaEngine();
      UserSummary? opened;
      await pumpScreen(
        tester,
        Scaffold(
          body: LiveGiftEffectsLayer(
            roomId: 'room-0',
            onSender: (u) => opened = u,
          ),
        ),
        liveGiftRepository: FakeLiveGiftRepository(codes: giftFixtureCodes),
        overrides: [currentUserProvider.overrideWithValue(testUser())],
      );
      await tester.pumpAndSettle();
      ProviderScope.containerOf(
        tester.element(find.byType(LiveGiftEffectsLayer)),
      ).read(liveGiftEffectsProvider('room-0').notifier).attach(engine);
      engine.chat.add(
        LiveGiftReceived(
          LiveGift.fromJson(
            liveGiftJson(
              id: 'car',
              code: 'sports_car',
              quantity: 1,
              sender: giftUserJson('lina', 'Lina'),
              recipients: [giftUserJson('sara', 'Sara')],
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(KGiftEffect), findsOneWidget);
      final strip = find.byKey(LiveGiftEffectsLayer.bannerKey('car'));
      expect(strip, findsOneWidget);
      await tester.tap(strip);
      expect(opened?.username, 'lina');
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });
  });

  group('the full-screen effect fits the screen', () {
    const phones = [
      Size(360, 800),
      Size(393, 852),
      Size(430, 932),
      Size(412, 915),
    ];
    const movies = [
      Size(750, 1334),
      Size(1080, 1920),
      Size(750, 750),
      Size(1920, 1080),
      Size(750, 1624),
    ];
    for (final phone in phones) {
      testWidgets('${phone.width.toInt()}×${phone.height.toInt()}: every '
          'movie is contained in the safe area, centred, its aspect kept', (
        tester,
      ) async {
        tester.view
          ..physicalSize = phone * 3
          ..devicePixelRatio = 3
          ..padding = const FakeViewPadding(top: 59 * 3, bottom: 34 * 3);
        addTearDown(tester.view.reset);
        for (final movie in movies) {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: KGiftMovieFrame(
                  viewBox: movie,
                  child: const ColoredBox(
                    key: Key('movie'),
                    color: Color(0xFFFF0000),
                  ),
                ),
              ),
            ),
          );
          final r = tester.getRect(find.byKey(const Key('movie')));
          final safe = Rect.fromLTRB(0, 59, phone.width, phone.height - 34);
          expect(r.left, greaterThanOrEqualTo(safe.left - 0.01));
          expect(r.top, greaterThanOrEqualTo(safe.top - 0.01));
          expect(r.right, lessThanOrEqualTo(safe.right + 0.01));
          expect(r.bottom, lessThanOrEqualTo(safe.bottom + 0.01));
          expect(r.width / r.height, closeTo(movie.width / movie.height, 0.01));
          // It fills one side of the safe area and is centred.
          expect(
            (r.width - safe.width).abs() < 0.5 ||
                (r.height - safe.height).abs() < 0.5,
            isTrue,
          );
          expect((r.center - safe.center).distance, lessThan(0.5));
        }
      });
    }
  });
}
