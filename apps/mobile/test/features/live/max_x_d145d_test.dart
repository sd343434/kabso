// D145d (owner, 2026-10-28): the owner's animated MAX X button — heat
// tiers by streak, the 4 s countdown (one constant), «ماكس x12» / «MAX x12»,
// a celebration per win tier driven only by the server's answer of each
// send, the owner's sounds on the sender's phone only (gated by the app's
// sound-effects setting and the foreground), and reduced motion. Also D145d
// part A: the full-screen effect's layer covers the whole screen in a real
// room (KGiftMovieFrame then stands the movie on the bottom edge).

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/application/live_lucky_combo.dart';
import 'package:kabso_live/features/live/application/live_wallet_controller.dart';
import 'package:kabso_live/features/live/application/max_x.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/live/domain/live_gift_models.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/live_room_screen.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_gift_effects_layer.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_gift_sheet.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_lucky_combo_button.dart';
import 'package:kabso_live/features/live/presentation/widgets/max_x_art.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:kabso_live/features/settings/settings_screen.dart';
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

const _host = UserSummary(
  id: 'user-sara',
  username: 'sara',
  displayName: 'Sara',
  avatarUrl: null,
);

const _open = Key('test.openGifts');

/// Records what would be played.
class _Sounds implements MaxXSoundPlayer {
  int taps = 0;
  final wins = <int>[];

  @override
  Future<void> tap() async => taps++;

  @override
  Future<void> win(int tier) async => wins.add(tier);

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

Future<(FakeLiveGiftRepository, _Sounds)> _pump(
  WidgetTester tester, {
  AppLanguage language = AppLanguage.en,
}) async {
  setViewport(tester, GoldenViewport.phone);
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

Future<void> _run(WidgetTester tester, Duration d) async {
  var left = d;
  const step = Duration(milliseconds: 100);
  while (left > Duration.zero) {
    await tester.pump(left < step ? left : step);
    left -= step;
  }
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

Map<String, Object?> _won(int multiplier, int coins) => {
  'draws': 1,
  'wins': [
    {'multiplier': multiplier, 'count': 1, 'coins': coins},
  ],
  'coinsWon': coins,
  'topMultiplier': multiplier,
  'downgraded': 0,
};

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(LuckyComboLayer)));

MaxXOrbPainter _orb(WidgetTester tester) =>
    tester.widget<CustomPaint>(find.byKey(LuckyComboCluster.ringKey)).painter!
        as MaxXOrbPainter;

String _semantics(WidgetTester tester) => tester
    .getSemantics(find.byKey(MaxXCelebration.bannerKey))
    .getSemanticsData()
    .label;

void main() {
  setUp(() => MaxXSounds.foreground = () => true);

  group('rules', () {
    test('heat tiers by streak: x1–9 red, x10–29 pink, x30–99 purple, x100+ '
        'gold', () {
      for (final (n, heat) in const [
        (0, MaxXHeat.red),
        (1, MaxXHeat.red),
        (9, MaxXHeat.red),
        (10, MaxXHeat.pink),
        (29, MaxXHeat.pink),
        (30, MaxXHeat.purple),
        (99, MaxXHeat.purple),
        (100, MaxXHeat.gold),
        (5000, MaxXHeat.gold),
      ]) {
        expect(MaxXHeat.of(n), heat, reason: 'x$n');
      }
      // Each tier has its own orb.
      expect({
        for (final h in MaxXHeat.values) MaxXHeatColors.of(h).mid,
      }, hasLength(4));
    });

    test("the countdown is ONE constant of 4 s (the owner's file said 3 s; "
        'he set 4 s), its last second urgent; the queue paces at 10 ms', () {
      expect(LuckyComboController.ringTime, const Duration(seconds: 4));
      expect(LuckyComboController.urgentTime, const Duration(seconds: 1));
      expect(LuckyComboController.minGap, const Duration(milliseconds: 10));
    });

    test("a win maps to the owner's 8 celebrations; other multipliers take "
        'the closest lower tier; no win, none', () {
      expect(MaxXTiers.win, [5, 10, 25, 50, 100, 250, 500, 1000]);
      for (final (m, tier) in const [
        (null, null),
        (0, null),
        (-3, null),
        (1, 5),
        (2, 5),
        (5, 5),
        (9, 5),
        (10, 10),
        (24, 10),
        (25, 25),
        (30, 25),
        (50, 50),
        (99, 50),
        (100, 100),
        (249, 100),
        (250, 250),
        (500, 500),
        (999, 500),
        (1000, 1000),
        (10000, 1000),
      ]) {
        expect(MaxXTiers.winTierOf(m), tier, reason: 'x$m');
      }
      for (final t in MaxXTiers.win) {
        expect(MaxXWinStyle.of(t).tier, t);
      }
      // Bigger wins celebrate longer, with more coins.
      final styles = [for (final t in MaxXTiers.win) MaxXWinStyle.of(t)];
      for (var i = 1; i < styles.length; i++) {
        expect(styles[i].seconds, greaterThan(styles[i - 1].seconds));
        expect(styles[i].coins, greaterThan(styles[i - 1].coins));
      }
    });

    test("a win comes only from the server's answer", () {
      LuckyGiftResult r(int? top, int coins) => LuckyGiftResult(
        draws: 1,
        wins: const [],
        coinsWon: coins,
        topMultiplier: top,
        downgraded: 0,
      );
      expect(MaxXWin.of(null, id: 1), isNull);
      expect(MaxXWin.of(r(null, 0), id: 1), isNull);
      expect(MaxXWin.of(r(0, 0), id: 1), isNull);
      final w = MaxXWin.of(r(100, 1000), id: 7)!;
      expect((w.id, w.multiplier, w.coins), (7, 100, 1000));
    });

    test('labels: «ماكس» / «MAX» before the number; JACKPOT titles', () {
      final en = l10nFor(AppLanguage.en);
      final ar = l10nFor(AppLanguage.ar);
      expect(en.liveComboLabel, 'MAX');
      expect(ar.liveComboLabel, 'ماكس');
      expect(en.liveMaxXJackpot, 'JACKPOT');
      expect(ar.liveMaxXJackpot, 'جاكبوت');
      expect(en.liveMaxXSuperJackpot, 'SUPER JACKPOT');
      expect(ar.liveMaxXSuperJackpot, 'سوبر جاكبوت');
    });
  });

  group('the button', () {
    for (final language in AppLanguage.values) {
      testWidgets(
        '${language.name}: «${language == AppLanguage.ar ? 'ماكس' : 'MAX'} '
        'x1», the number at the reading end; it counts each tap at once and '
        'the heat follows the streak',
        (tester) async {
          final (gifts, _) = await _pump(tester, language: language);
          await _sendLucky(tester);
          final l10n = l10nFor(language);
          final word = tester.getRect(find.text(l10n.liveComboLabel));
          final number = tester.getRect(
            find.descendant(
              of: find.byKey(LuckyComboCluster.countKey),
              matching: find.text('x1'),
            ),
          );
          if (language == AppLanguage.ar) {
            expect(word.left, greaterThanOrEqualTo(number.right));
          } else {
            expect(number.left, greaterThanOrEqualTo(word.right));
          }
          expect(_orb(tester).heat, MaxXHeatColors.of(MaxXHeat.red));
          // A tap counts at once (before its answer).
          final gate = Completer<void>();
          gifts.sendGate = gate;
          await tester.tap(_button);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          expect(find.text('x2'), findsOneWidget);
          gifts.sendGate = null;
          gate.complete();
          await _run(tester, const Duration(milliseconds: 300));
          expect(find.text('x2'), findsOneWidget);
          // Eight more: a streak of 10 is pink.
          for (var i = 0; i < 8; i++) {
            await tester.tap(_button);
            await tester.pump(const Duration(milliseconds: 50));
          }
          await _run(tester, const Duration(milliseconds: 400));
          expect(find.text('x10'), findsOneWidget);
          expect(_orb(tester).heat, MaxXHeatColors.of(MaxXHeat.pink));
          await _run(tester, const Duration(seconds: 5));
        },
      );
    }

    testWidgets('the ring empties over 4 s and turns urgent in its last '
        'second, then the button goes', (tester) async {
      await _pump(tester);
      await _sendLucky(tester);
      expect(_orb(tester).urgent, isFalse);
      await _run(tester, const Duration(milliseconds: 2500));
      expect(_orb(tester).urgent, isFalse);
      expect(_orb(tester).left, closeTo(1 - 3.1 / 4, 0.06));
      await _run(tester, const Duration(milliseconds: 600));
      expect(_orb(tester).urgent, isTrue);
      await _run(tester, const Duration(milliseconds: 1000));
      expect(_button, findsNothing);
    });
  });

  group('wins come from the server, one celebration each', () {
    testWidgets('no win: no celebration and no jingle; ×100: the ×100 '
        'celebration with the coins the server says, and its jingle; '
        'the next send without a win does not celebrate again', (tester) async {
      final (gifts, sounds) = await _pump(tester);
      await _sendLucky(tester);
      await tester.tap(_button);
      await _run(tester, const Duration(milliseconds: 300));
      expect(find.byType(MaxXCelebration), findsNothing);
      expect(sounds.wins, isEmpty);
      expect(sounds.taps, 1);

      gifts.nextLucky = _won(100, 1000);
      await tester.tap(_button);
      await _run(tester, const Duration(milliseconds: 300));
      expect(find.byType(MaxXCelebration), findsOneWidget);
      expect(sounds.wins, [100]);
      final en = l10nFor(AppLanguage.en);
      expect(_semantics(tester), contains('1,000'));
      expect(_semantics(tester), contains('100'));
      expect(_semantics(tester), isNot(contains(en.liveMaxXJackpot)));
      final painter = tester
          .widgetList<CustomPaint>(
            find.descendant(
              of: find.byType(MaxXCelebration),
              matching: find.byType(CustomPaint),
            ),
          )
          .map((c) => c.painter)
          .whereType<MaxXWinPainter>()
          .single;
      expect(painter.multiplier, 100);
      expect(painter.coins, 1000);
      expect(painter.style.tier, 100);
      expect(painter.still, isFalse);

      await tester.tap(_button);
      await _run(tester, const Duration(seconds: 2));
      expect(find.byType(MaxXCelebration), findsNothing);
      expect(sounds.wins, [100]);
      expect(sounds.taps, 3);
      await _run(tester, const Duration(seconds: 5));
    });

    for (final (m, tier, title) in const [
      (30, 25, null),
      (500, 500, 'JACKPOT'),
      (1000, 1000, 'SUPER JACKPOT'),
    ]) {
      testWidgets('×$m from the server: the ×$tier celebration'
          '${title == null ? '' : ' «$title»'}, its number ×$m', (
        tester,
      ) async {
        final (gifts, sounds) = await _pump(tester);
        await _sendLucky(tester);
        gifts.nextLucky = _won(m, m * 10);
        await tester.tap(_button);
        await _run(tester, const Duration(milliseconds: 300));
        final painter = tester
            .widgetList<CustomPaint>(
              find.descendant(
                of: find.byType(MaxXCelebration),
                matching: find.byType(CustomPaint),
              ),
            )
            .map((c) => c.painter)
            .whereType<MaxXWinPainter>()
            .single;
        expect(painter.style.tier, tier);
        expect(painter.multiplier, m);
        expect(painter.title, title);
        expect(sounds.wins, [tier]);
        if (title != null) expect(_semantics(tester), startsWith(title));
        await _run(tester, const Duration(seconds: 5));
      });
    }

    testWidgets("the panel's own send celebrates too when it won", (
      tester,
    ) async {
      final (gifts, sounds) = await _pump(tester);
      gifts.nextLucky = _won(5, 50);
      await _sendLucky(tester);
      expect(find.byType(MaxXCelebration), findsOneWidget);
      expect(sounds.wins, [5]);
      await _run(tester, const Duration(seconds: 5));
    });

    testWidgets('Arabic: «جاكبوت» for ×500', (tester) async {
      final (gifts, _) = await _pump(tester, language: AppLanguage.ar);
      await _sendLucky(tester);
      gifts.nextLucky = _won(500, 5000);
      await tester.tap(_button);
      await _run(tester, const Duration(milliseconds: 300));
      expect(_semantics(tester), startsWith('جاكبوت'));
      await _run(tester, const Duration(seconds: 5));
    });

    testWidgets('reduced motion: the celebration is a still banner; the orb '
        'does not move but its ring counts down', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final (gifts, _) = await _pump(tester);
      await _sendLucky(tester);
      gifts.nextLucky = _won(250, 2500);
      await tester.tap(_button);
      await _run(tester, const Duration(milliseconds: 300));
      final painter = tester
          .widgetList<CustomPaint>(
            find.descendant(
              of: find.byType(MaxXCelebration),
              matching: find.byType(CustomPaint),
            ),
          )
          .map((c) => c.painter)
          .whereType<MaxXWinPainter>()
          .single;
      expect(painter.still, isTrue);
      expect(_orb(tester).animated, isFalse);
      expect(_orb(tester).left, lessThan(1));
      await _run(tester, const Duration(seconds: 5));
    });
  });

  group("sounds: the sender's phone only, gated", () {
    testWidgets('sound effects off in Settings: no tap or win sound', (
      tester,
    ) async {
      final (gifts, sounds) = await _pump(tester);
      await _container(tester)
          .read(soundEffectsProvider.notifier)
          .set(on: false);
      await _sendLucky(tester);
      gifts.nextLucky = _won(100, 1000);
      await tester.tap(_button);
      await _run(tester, const Duration(milliseconds: 300));
      // The celebration still shows; only the sound is off.
      expect(find.byType(MaxXCelebration), findsOneWidget);
      expect(sounds.taps, 0);
      expect(sounds.wins, isEmpty);
      await _run(tester, const Duration(seconds: 5));
    });

    testWidgets('in the background: nothing plays', (tester) async {
      MaxXSounds.foreground = () => false;
      final (gifts, sounds) = await _pump(tester);
      await _sendLucky(tester);
      gifts.nextLucky = _won(10, 100);
      await tester.tap(_button);
      await _run(tester, const Duration(milliseconds: 300));
      expect(sounds.taps, 0);
      expect(sounds.wins, isEmpty);
      await _run(tester, const Duration(seconds: 5));
    });

    testWidgets('a tap the combo does not take (no coins) makes no sound', (
      tester,
    ) async {
      final (gifts, sounds) = await _pump(tester);
      await _sendLucky(tester);
      gifts.coins = 0;
      _container(tester).read(liveCoinsProvider.notifier).set(0);
      await tester.tap(_button);
      await _run(tester, const Duration(milliseconds: 300));
      expect(sounds.taps, 0);
      await _run(tester, const Duration(seconds: 5));
    });

    test("the player plays the owner's files", () {
      expect(AudioplayersMaxXSounds.tapAsset, 'sounds/max_tap.mp3');
      expect(
        [for (final t in MaxXTiers.win) AudioplayersMaxXSounds.winAsset(t)],
        [
          'sounds/max_win_5.mp3',
          'sounds/max_win_10.mp3',
          'sounds/max_win_25.mp3',
          'sounds/max_win_50.mp3',
          'sounds/max_win_100.mp3',
          'sounds/max_win_250.mp3',
          'sounds/max_win_500.mp3',
          'sounds/max_win_1000.mp3',
        ],
      );
    });

    testWidgets('Settings: the sound effects switch is on by default and '
        'remembers off', (tester) async {
      setViewport(tester, GoldenViewport.phone);
      await pumpScreen(tester, const SettingsScreen());
      await tester.pumpAndSettle();
      final tile = find.byKey(SettingsScreen.soundEffectsKey);
      await tester.ensureVisible(tile);
      expect(tester.widget<SwitchListTile>(tile).value, isTrue);
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(tile).value, isFalse);
      final container = ProviderScope.containerOf(tester.element(tile));
      expect(container.read(soundEffectsProvider), isFalse);
    });
  });

  group('D145d part A: the effect layer covers the whole screen in a room', () {
    for (final audio in [false, true]) {
      for (final size in const [Size(360, 800), Size(430, 932)]) {
        testWidgets('${audio ? 'audio' : 'video'} '
            '${size.width.toInt()}×${size.height.toInt()}: the big effect '
            'gets the whole screen (through the bottom inset and under the '
            'bottom bar), so the movie stands on the bottom edge', (
          tester,
        ) async {
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
            liveMediaEngine: engine,
            liveGiftRepository: FakeLiveGiftRepository(codes: giftFixtureCodes),
            overrides: [
              liveRepositoryProvider.overrideWithValue(
                FakeLiveRepository(
                  room: (id) {
                    final r = apiRoom(id: id);
                    return audio
                        ? r.copyWith(mode: LiveRoomMode.audio, seatCount: 10)
                        : r;
                  },
                ),
              ),
              profileRepositoryProvider.overrideWithValue(
                FakeProfileRepository(apiProfile()),
              ),
              currentUserProvider.overrideWithValue(testUser()),
            ],
          );
          await tester.pumpAndSettle();
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
          final effect = tester.getRect(
            find.byKey(LiveGiftEffectsLayer.effectKey),
          );
          expect(effect, Offset.zero & size);
          final bar = tester.getRect(
            find.byKey(audio ? AudioRoomViewKeys.gift : LiveRoomScreen.giftKey),
          );
          // The bottom bar sits inside what the effect covers.
          expect(effect.bottom, greaterThan(bar.bottom));
          await tester.pump(const Duration(seconds: 10));
          await tester.pumpAndSettle();
        });
      }
    }
  });
}
