// D159 (owner, 2026-10-28: «الإطار الخاص بهدية المكسب غيّره واجعلها بهذا
// الشكل، وكل مكسب له شكل معين», with his `kabso_win_banner.dart` and four
// frames):
// - a lucky win is announced in its tier's frame — sapphire «فوز» ×5…×25,
//   ruby «فوز كبير» ×50…×100, amethyst «فوز ضخم» ×250, onyx «جاكبوت»
//   ×500…×1000 — avatar, name, label, ×N and the coins counting up; it
//   slides in from the reading start and out to the reading end; reduced
//   motion: still, then a fade;
// - the room's `lucky-win` messages (the server's ×100+ rule) and the
//   sender's own wins of every tier (from the send's answer); one at a
//   time, a bigger win replaces smaller ones waiting, at most 3 wait;
// - under the header, clear of the seats and the MAX X button;
// - the MAX X celebration and its winnings chip take the tier's colours;
// - BUG (owner's screenshot): «ضمان» over a ×100 — the send-level
//   `luckyResult.guaranteed` was put on the send's best multiplier.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/application/live_gift_effects.dart';
import 'package:kabso_live/features/live/application/live_lucky_combo.dart';
import 'package:kabso_live/features/live/application/max_x.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_gift_models.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/live_room_screen.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_audio_room.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_seat_tiles.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_gift_effects_layer.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_gift_sheet.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_lucky_combo_button.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_win_banner.dart';
import 'package:kabso_live/features/live/presentation/widgets/max_x_art.dart';
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

UserSummary _user(String name, {String username = 'oz'}) => UserSummary(
  id: 'u-$username',
  username: username,
  displayName: name,
  avatarUrl: null,
);

LuckyWin _win({
  int multiplier = 100,
  int coins = 650,
  String name = 'Oz Nabulsi',
  String? giftId,
}) => LuckyWin(
  giftId: giftId ?? 'g-$multiplier',
  roomId: 'room-0',
  giftCode: 'lucky_clover',
  sender: _user(name),
  multiplier: multiplier,
  coinsWon: coins,
  createdAt: DateTime.utc(2026, 10, 28, 12),
);

/// A send's answer with [wins] (multiplier → count) at a unit price of 5.
LuckyGiftResult _result(
  Map<int, int> wins, {
  bool guaranteed = false,
  int draws = 66,
}) {
  final list = [
    for (final MapEntry(key: m, value: n) in wins.entries)
      LuckyGiftWin(multiplier: m, count: n, coins: m * 5 * n),
  ]..sort((a, b) => a.multiplier.compareTo(b.multiplier));
  return LuckyGiftResult(
    draws: draws,
    wins: list,
    coinsWon: list.fold(0, (a, w) => a + w.coins),
    topMultiplier: list.isEmpty ? null : list.last.multiplier,
    downgraded: 0,
    guaranteed: guaranteed,
  );
}

LiveGiftResult _send(String id, LuckyGiftResult lucky, {String name = 'Oz'}) =>
    LiveGiftResult(
      gift: LiveGift.fromJson(
        liveGiftJson(
          id: id,
          code: 'lucky_clover',
          quantity: 66,
          sender: giftUserJson('oz', name),
          recipients: [giftUserJson('sara', 'Sara')],
        ),
      ),
      coins: 1000,
      bagQuantity: 0,
      luckyResult: lucky,
    );

ProviderContainer _container() {
  final c = ProviderContainer(
    overrides: [
      liveRepositoryProvider.overrideWithValue(FakeLiveRepository()),
      currentUserProvider.overrideWithValue(testUser()),
    ],
  );
  addTearDown(c.dispose);
  c.listen(liveGiftEffectsProvider('room-0'), (_, _) {});
  return c;
}

Future<void> _pumpBanner(
  WidgetTester tester,
  LuckyWin win, {
  AppLanguage language = AppLanguage.en,
  GoldenViewport viewport = GoldenViewport.android,
}) async {
  setViewport(tester, viewport);
  await pumpScreen(
    tester,
    Scaffold(
      backgroundColor: const Color(0xFF5B4AB2),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: LiveWinBanner.top,
            left: 0,
            right: 0,
            child: Center(
              child: LiveWinBanner(
                win: win,
                width: LiveWinBanner.widthOn(viewport.logicalSize.width),
              ),
            ),
          ),
        ],
      ),
    ),
    language: language,
  );
}

Future<void> _run(WidgetTester tester, Duration d) async {
  var left = d;
  const step = Duration(milliseconds: 50);
  while (left > Duration.zero) {
    await tester.pump(left < step ? left : step);
    left -= step;
  }
}

Finder get _banner => find.byType(LiveWinBanner);

/// Where the banner's frame is drawn now (its slide included).
Rect _frame(WidgetTester tester) =>
    tester.getRect(find.byKey(LiveWinBanner.frameKey));

String _text(WidgetTester tester, Key key) =>
    tester.widget<Text>(find.byKey(key)).data!;

void main() {
  setUp(() => MaxXSounds.foreground = () => true);

  group('tiers', () {
    test("the owner's four frames by multiplier", () {
      const expected = {
        5: LuckyWinTier.sapphire,
        10: LuckyWinTier.sapphire,
        25: LuckyWinTier.sapphire,
        49: LuckyWinTier.sapphire,
        50: LuckyWinTier.ruby,
        100: LuckyWinTier.ruby,
        250: LuckyWinTier.amethyst,
        499: LuckyWinTier.amethyst,
        500: LuckyWinTier.onyx,
        1000: LuckyWinTier.onyx,
      };
      for (final MapEntry(key: m, value: tier) in expected.entries) {
        expect(LuckyWinTier.of(m), tier, reason: '×$m');
      }
      expect(
        LuckyWinTier.sapphire.frame,
        'assets/win_frames/win_frame_sapphire.png',
      );
    });

    test('labels: «فوز», «فوز كبير», «فوز ضخم», «جاكبوت» / WIN … JACKPOT', () {
      final ar = l10nFor(AppLanguage.ar);
      final en = l10nFor(AppLanguage.en);
      expect(
        [for (final t in LuckyWinTier.values) LuckyWinTierArt.label(ar, t)],
        ['فوز', 'فوز كبير', 'فوز ضخم', 'جاكبوت'],
      );
      expect(
        [for (final t in LuckyWinTier.values) LuckyWinTierArt.label(en, t)],
        ['WIN', 'BIG WIN', 'HUGE WIN', 'JACKPOT'],
      );
    });

    test("the MAX X celebration takes its tier's colours (jewel ribbon, "
        "glow, the owner's gold ×N)", () {
      for (final style in MaxXWinStyle.all) {
        final art = LuckyWinTierArt.of(LuckyWinTier.of(style.tier));
        expect(style.ribbon, [art.panelTop, art.panelBottom]);
        expect(style.color, art.glow);
        expect(style.numberColors, LuckyWinTierArt.numberColors);
      }
    });
  });

  group('the banner', () {
    const cases = [
      (10, 1200, LuckyWinTier.sapphire),
      (100, 650, LuckyWinTier.ruby),
      (250, 25000, LuckyWinTier.amethyst),
      (1000, 99878, LuckyWinTier.onyx),
    ];
    for (final language in AppLanguage.values) {
      for (final viewport in GoldenViewport.values) {
        for (final (m, coins, tier) in cases) {
          testWidgets('${language.name} ${viewport.name} ×$m: the $tier frame, '
              'avatar, name, label, ×N, coins counting up; slides in from '
              'the reading start and out to the reading end', (tester) async {
            final l10n = l10nFor(language);
            await _pumpBanner(
              tester,
              _win(multiplier: m, coins: coins),
              language: language,
              viewport: viewport,
            );
            final width = viewport.logicalSize.width;
            final rest = (width - LiveWinBanner.widthOn(width)) / 2;
            final image = tester.widget<Image>(
              find.byKey(LiveWinBanner.frameKey),
            );
            expect((image.image as AssetImage).assetName, tier.frame);
            // Entering: still off its place, on the reading-start side.
            await tester.pump(const Duration(milliseconds: 120));
            final rtl = language == AppLanguage.ar;
            final entering = _frame(tester).left;
            rtl
                ? expect(entering, greaterThan(rest + 20))
                : expect(entering, lessThan(rest - 20));
            // At rest: whole on screen, centred.
            await _run(tester, const Duration(milliseconds: 900));
            final r = _frame(tester);
            expect(r.left, closeTo(rest, .5));
            expect(r.right, lessThanOrEqualTo(width));
            expect(_text(tester, LiveWinBanner.nameKey), 'Oz Nabulsi');
            expect(
              _text(tester, LiveWinBanner.labelKey),
              LuckyWinTierArt.label(l10n, tier),
            );
            expect(
              _text(tester, LiveWinBanner.numberKey),
              '×${m == 1000 ? '1,000' : m}',
            );
            expect(find.byType(KAvatar), findsOneWidget);
            // The avatar sits at the reading start of the panel.
            final avatar = tester.getCenter(find.byType(KAvatar));
            final number = tester.getCenter(
              find.byKey(LiveWinBanner.numberKey),
            );
            rtl
                ? expect(avatar.dx, greaterThan(number.dx))
                : expect(avatar.dx, lessThan(number.dx));
            // Coins: counting at 0.9 s, all of it after 1.3 s.
            expect(
              _text(tester, LiveWinBanner.coinsKey),
              isNot('+${_grouped(coins)}'),
            );
            await _run(tester, const Duration(milliseconds: 500));
            expect(
              _text(tester, LiveWinBanner.coinsKey),
              '+${_grouped(coins)}',
            );
            // Leaving (2.75–3.15 s): toward the reading end.
            await _run(tester, const Duration(milliseconds: 1500));
            final leaving = _frame(tester).left;
            rtl
                ? expect(leaving, lessThan(rest - 20))
                : expect(leaving, greaterThan(rest + 20));
            expect(tester.takeException(), isNull);
            await _run(tester, const Duration(milliseconds: 400));
          });
        }
      }
    }

    testWidgets('a long name stays on one line, cut with an ellipsis; the '
        'display name, never the @username', (tester) async {
      for (final language in AppLanguage.values) {
        await _pumpBanner(
          tester,
          _win(name: 'A very very long display name that goes on and on'),
          language: language,
        );
        await _run(tester, const Duration(milliseconds: 1000));
        final name = tester.widget<Text>(find.byKey(LiveWinBanner.nameKey));
        expect(name.maxLines, 1);
        expect(name.overflow, TextOverflow.ellipsis);
        expect(find.textContaining('@'), findsNothing);
        // Inside the panel, not over the ×N.
        final nameRect = tester.getRect(find.byKey(LiveWinBanner.nameKey));
        final numberRect = tester.getRect(find.byKey(LiveWinBanner.numberKey));
        expect(nameRect.overlaps(numberRect), isFalse);
        expect(tester.takeException(), isNull);
        await _run(tester, const Duration(seconds: 3));
      }
    });

    testWidgets('reduced motion: no slide, no sweep, no sparkles; the whole '
        'amount at once; still, then a fade', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await _pumpBanner(tester, _win(coins: 7725), language: AppLanguage.ar);
      await tester.pump(const Duration(milliseconds: 30));
      final first = _frame(tester);
      expect(_text(tester, LiveWinBanner.coinsKey), '+7,725');
      expect(
        find.descendant(of: _banner, matching: find.byType(ShaderMask)),
        // Only the ×N's gold fill; no light sweep over the frame.
        findsOneWidget,
      );
      await tester.pump(const Duration(milliseconds: 1500));
      expect(_frame(tester), first);
      Opacity opacity() => tester.widget<Opacity>(
        find.descendant(of: _banner, matching: find.byType(Opacity)).first,
      );
      expect(opacity().opacity, 1);
      // Fading over the last 0.4 s of its 3.2 s.
      await tester.pump(const Duration(milliseconds: 1400));
      expect(opacity().opacity, inExclusiveRange(.3, .8));
      await tester.pump(const Duration(milliseconds: 260));
      expect(opacity().opacity, lessThan(.05));
    });

    testWidgets('screen readers hear it once: label, name, ×N, coins', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pumpBanner(tester, _win(multiplier: 250, coins: 25000));
      await tester.pump(const Duration(milliseconds: 100));
      final label = tester.getSemantics(_banner).getSemanticsData().label;
      expect(label, startsWith('HUGE WIN'));
      expect(label, contains('Oz Nabulsi'));
      expect(label, contains('×250'));
      expect(label, contains('+25,000'));
      handle.dispose();
      await _run(tester, const Duration(seconds: 4));
    });
  });

  group('the queue', () {
    test("the sender's own win shows whatever its tier (a ×5 too); the "
        "room's ×50 message does not (the server sends ×100+ only)", () {
      final c = _container();
      final effects = c.read(liveGiftEffectsProvider('room-0').notifier)
        ..showLucky(_win(multiplier: 50, giftId: 'r-50'));
      expect(c.read(liveGiftEffectsProvider('room-0')).lucky, isNull);
      effects.showOwnWin(_send('g-own', _result({5: 1})));
      final shown = c.read(liveGiftEffectsProvider('room-0')).lucky!;
      expect(shown.multiplier, 5);
      expect(shown.coinsWon, 25);
      expect(shown.giftId, 'g-own');
      expect(LuckyWinTier.of(shown.multiplier), LuckyWinTier.sapphire);
    });

    test('no win, no banner', () {
      final c = _container();
      c
          .read(liveGiftEffectsProvider('room-0').notifier)
          .showOwnWin(_send('g-0', _result({})));
      expect(c.read(liveGiftEffectsProvider('room-0')).lucky, isNull);
    });

    testWidgets('one at a time; at most ${LiveGiftEffects.maxLuckyWaiting} '
        'wait; a bigger win replaces the smaller ones waiting; the same '
        'send twice shows once', (tester) async {
      final c = _container();
      LuckyWin? now() => c.read(liveGiftEffectsProvider('room-0')).lucky;
      final effects = c.read(liveGiftEffectsProvider('room-0').notifier)
        ..showOwnWin(_send('a', _result({10: 1})));
      expect(now()?.giftId, 'a');
      // The room's message for the same send (×100+): nothing more.
      effects
        ..showLucky(_win(giftId: 'a'))
        // Waiting [b ×5, c ×5]; d ×25 replaces both: [d].
        ..showOwnWin(_send('b', _result({5: 1})))
        ..showOwnWin(_send('c', _result({5: 1})))
        ..showOwnWin(_send('d', _result({25: 1})))
        // [d, e ×10, f ×5]: full.
        ..showOwnWin(_send('e', _result({10: 1})))
        ..showOwnWin(_send('f', _result({5: 1})))
        // Full and no bigger than any waiting: dropped.
        ..showOwnWin(_send('g', _result({5: 1})));
      final order = <String>[];
      for (var i = 0; i < 5; i++) {
        await tester.pump(LiveGiftEffects.luckyTime);
        order.add(now()?.giftId ?? '-');
      }
      expect(order, ['d', 'e', 'f', '-', '-']);

      // h shows; i, then j, then k, then l ×1000 each replace the smaller
      // ones waiting.
      effects
        ..showOwnWin(_send('h', _result({5: 1})))
        ..showOwnWin(_send('i', _result({5: 1})))
        ..showOwnWin(_send('j', _result({10: 1})))
        ..showOwnWin(_send('k', _result({25: 1})))
        ..showOwnWin(_send('l', _result({1000: 1})));
      order.clear();
      for (var i = 0; i < 3; i++) {
        await tester.pump(LiveGiftEffects.luckyTime);
        order.add(now()?.giftId ?? '-');
      }
      expect(order, ['l', '-', '-']);
    });
  });

  group('BUG «ضمان» on a ×100 (owner screenshot)', () {
    test('a send of 66 draws: a ×100 and a ×25 the draws won, and a '
        'guaranteed ×5 — the ×100 celebration does not say «ضمان»', () {
      // +650 at 5 coins a gift: ×100 + ×25 + ×5, as in the screenshot.
      final send = _result({100: 1, 25: 1, 5: 1}, guaranteed: true);
      expect(send.coinsWon, 650);
      final win = MaxXWin.of(send, id: 1)!;
      expect(win.multiplier, 100);
      expect(win.guaranteed, isFalse);
    });

    test('the guaranteed ×5 alone (or with other ×5s) still says it', () {
      expect(
        MaxXWin.of(_result({5: 1}, guaranteed: true), id: 1)!.guaranteed,
        isTrue,
      );
      expect(
        MaxXWin.of(_result({5: 3}, guaranteed: true), id: 1)!.guaranteed,
        isTrue,
      );
      expect(MaxXWin.of(_result({5: 1}), id: 1)!.guaranteed, isFalse);
    });

    testWidgets('in a MAX X streak: a guaranteed ×5, then a ×100 the draws '
        'won (its send also had a guaranteed draw): only the ×5 says «ضمان»', (
      tester,
    ) async {
      final l10n = l10nFor(AppLanguage.ar);
      final (gifts, _) = await _pumpCombo(tester, language: AppLanguage.ar);
      await _sendLucky(tester);
      gifts.nextLucky = _json({5: 1}, guaranteed: true);
      await tester.tap(_button);
      await _run(tester, const Duration(milliseconds: 150));
      expect(_celebration(tester).title, l10n.liveMaxXGuaranteed);
      gifts.nextLucky = _json({100: 1, 25: 1, 5: 1}, guaranteed: true);
      await tester.tap(_button);
      await _run(tester, const Duration(milliseconds: 1700));
      final big = _celebration(tester);
      expect(big.multiplier, 100);
      expect(big.coins, 650);
      expect(big.title, isNull);
      await _run(tester, const Duration(seconds: 6));
    });
  });

  group('in the room', () {
    testWidgets("the sender's own ×5 (sapphire) plays the banner over the "
        'room, clear of the MAX X button and its chips; the winnings chip is '
        "in the tier's jewel", (tester) async {
      final (gifts, _) = await _pumpCombo(tester);
      await _sendLucky(tester);
      gifts.nextLucky = _json({5: 1});
      await tester.tap(_button);
      await _run(tester, const Duration(milliseconds: 900));
      expect(_banner, findsOneWidget);
      final image = tester.widget<Image>(find.byKey(LiveWinBanner.frameKey));
      expect(
        (image.image as AssetImage).assetName,
        LuckyWinTier.sapphire.frame,
      );
      final banner = _frame(tester);
      for (final key in [
        LuckyComboCluster.buttonKey,
        LuckyComboCluster.resultKey,
        LuckyComboCluster.balanceKey,
      ]) {
        expect(
          banner.overlaps(tester.getRect(find.byKey(key))),
          isFalse,
          reason: '$key',
        );
      }
      final chip = tester.widget<Container>(
        find
            .descendant(
              of: find.byKey(LuckyComboCluster.resultKey),
              matching: find.byType(Container),
            )
            .first,
      );
      final art = LuckyWinTierArt.of(LuckyWinTier.sapphire);
      final gradient =
          (chip.decoration! as BoxDecoration).gradient! as LinearGradient;
      expect(gradient.colors, [art.panelTop, art.panelBottom]);
      await _run(tester, const Duration(seconds: 6));
    });

    for (final language in AppLanguage.values) {
      for (final size in const [Size(360, 800), Size(393, 852)]) {
        testWidgets('${language.name} ${size.width.toInt()}: audio room — '
            'under the header, above the first seats', (tester) async {
          tester.view
            ..physicalSize = size * 3
            ..devicePixelRatio = 3
            ..padding = const FakeViewPadding(top: 59 * 3, bottom: 34 * 3)
            ..viewPadding = const FakeViewPadding(top: 59 * 3, bottom: 34 * 3);
          addTearDown(tester.view.reset);
          final engine = FakeLiveMediaEngine()..present.add('user-0');
          await pumpScreen(
            tester,
            const LiveRoomScreen(roomId: 'room-0'),
            language: language,
            liveMediaEngine: engine,
            liveGiftRepository: FakeLiveGiftRepository(codes: giftFixtureCodes),
            overrides: [
              liveRepositoryProvider.overrideWithValue(
                FakeLiveRepository(
                  room: (id) =>
                      apiRoom(id: id)
                          .copyWith(mode: LiveRoomMode.audio, seatCount: 10),
                ),
              ),
              profileRepositoryProvider.overrideWithValue(
                FakeProfileRepository(apiProfile()),
              ),
              currentUserProvider.overrideWithValue(testUser()),
            ],
          );
          await tester.pumpAndSettle();
          ProviderScope.containerOf(tester.element(find.byType(LiveRoomScreen)))
              .read(liveGiftEffectsProvider('room-0').notifier)
              .showOwnWin(_send('g-1', _result({1000: 1}), name: 'Mona'));
          await _run(tester, const Duration(milliseconds: 1000));
          final banner = _frame(tester);
          final header = tester.getRect(find.byType(LiveAudioRoomHeader));
          final seat = tester.getRect(find.byKey(AudioSeatRing.seatKey(0)));
          expect(banner.top, greaterThanOrEqualTo(header.bottom));
          expect(banner.bottom, lessThanOrEqualTo(seat.top));
          expect(banner.left, greaterThanOrEqualTo(0));
          expect(banner.right, lessThanOrEqualTo(size.width));
          expect(tester.takeException(), isNull);
          await _run(tester, const Duration(seconds: 3));
        });
      }
    }
  });
}

String _grouped(int v) => v.toString().replaceAllMapped(
  RegExp(r'(\d)(?=(\d{3})+$)'),
  (m) => '${m[1]},',
);

Map<String, Object?> _json(Map<int, int> wins, {bool guaranteed = false}) {
  final r = _result(wins, guaranteed: guaranteed);
  return {
    'draws': r.draws,
    'wins': [
      for (final w in r.wins)
        {'multiplier': w.multiplier, 'count': w.count, 'coins': w.coins},
    ],
    'coinsWon': r.coinsWon,
    'topMultiplier': r.topMultiplier,
    'downgraded': 0,
    'guaranteed': guaranteed,
  };
}

// ── The MAX X harness (as lucky_wins_d145e_test), with the room's effects
// layer so the sender's own banner shows.

const _host = UserSummary(
  id: 'user-sara',
  username: 'sara',
  displayName: 'Sara',
  avatarUrl: null,
);

const _open = Key('test.openGifts');

class _Sounds implements MaxXSoundPlayer {
  @override
  Future<void> tap() async {}

  @override
  Future<void> win(int tier) async {}

  @override
  Future<void> dispose() async {}
}

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
        const LiveGiftEffectsLayer(roomId: 'room-0'),
        const LuckyComboLayer(roomId: 'room-0', hostUsername: 'sara'),
        const Align(
          alignment: AlignmentDirectional.bottomEnd,
          child: Padding(
            padding: EdgeInsets.only(bottom: 80),
            child: LuckyComboCluster(roomId: 'room-0'),
          ),
        ),
      ],
    ),
  );
}

Future<(FakeLiveGiftRepository, _Sounds)> _pumpCombo(
  WidgetTester tester, {
  AppLanguage language = AppLanguage.en,
}) async {
  setViewport(tester, GoldenViewport.android);
  final gifts = FakeLiveGiftRepository(
    codes: [...giftFixtureCodes, 'lucky_clover'],
    coins: 100000,
    ar: language == AppLanguage.ar,
  )..categories = const ['POPULAR', 'EVENT', 'FUN', 'LUCKY'];
  final sounds = _Sounds();
  await pumpScreen(
    tester,
    const _Room(),
    language: language,
    liveGiftRepository: gifts,
    overrides: [
      liveRepositoryProvider.overrideWithValue(
        FakeLiveRepository()..coins = 100000,
      ),
      currentUserProvider.overrideWithValue(testUser()),
      maxXSoundPlayerProvider.overrideWithValue(sounds),
    ],
  );
  await tester.tap(find.byKey(_open));
  await tester.pumpAndSettle();
  return (gifts, sounds);
}

Future<void> _tapIn(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Future<void> _sendLucky(WidgetTester tester) async {
  await _tapIn(tester, find.byKey(KLiveGiftSheet.tabKey('LUCKY')));
  await _tapIn(tester, find.byKey(KLiveGiftSheet.cellKey('lucky_clover')));
  await tester.tap(find.byKey(KLiveGiftSheet.sendKey));
  await _run(tester, const Duration(milliseconds: 600));
}

final Finder _button = find.byKey(LuckyComboCluster.buttonKey);

MaxXWinPainter _celebration(WidgetTester tester) => tester
    .widgetList<CustomPaint>(
      find.descendant(
        of: find.byType(MaxXCelebration),
        matching: find.byType(CustomPaint),
      ),
    )
    .map((c) => c.painter)
    .whereType<MaxXWinPainter>()
    .single;
