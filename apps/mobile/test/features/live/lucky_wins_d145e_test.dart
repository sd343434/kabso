// D145e (owner device test, 2026-10-28):
// - the room's ×100+ lucky win was a small gold pill: D145e made it a
//   centred gold card; D159 replaced that with the owner's tier banner
//   (win_banner_d159_test);
// - two MAX X wins («×10 +550», «×100 +2,300») overlapped each other and the
//   orb: one celebration at a time, the banner clear of the winnings chip;
// - «ماكس 264» was cut: the label fits inside the orb;
// - DeepAR's black picture: the effect turns itself off with its own honest
//   message (`black_output`).

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_camera_fx/kabso_camera_fx.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/application/max_x.dart';
import 'package:kabso_live/features/live/data/beauty/live_ar_effect.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/presentation/go_live/go_live_parts.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_gift_sheet.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_lucky_combo_button.dart';
import 'package:kabso_live/features/live/presentation/widgets/max_x_art.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_gift_fixtures.dart';
import '../../helpers/fake_live_gift_repository.dart';
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

class _Sounds implements MaxXSoundPlayer {
  final wins = <int>[];

  @override
  Future<void> tap() async {}

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

Future<void> _run(WidgetTester tester, Duration d) async {
  var left = d;
  const step = Duration(milliseconds: 50);
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

Map<String, Object?> _won(int multiplier, int coins) => {
  'draws': 1,
  'wins': [
    {'multiplier': multiplier, 'count': 1, 'coins': coins},
  ],
  'coinsWon': coins,
  'topMultiplier': multiplier,
  'downgraded': 0,
};

final Finder _button = find.byKey(LuckyComboCluster.buttonKey);

List<MaxXWinPainter> _winPainters(WidgetTester tester) => tester
    .widgetList<CustomPaint>(
      find.descendant(
        of: find.byType(MaxXCelebration),
        matching: find.byType(CustomPaint),
      ),
    )
    .map((c) => c.painter)
    .whereType<MaxXWinPainter>()
    .toList();

void main() {
  setUp(() => MaxXSounds.foreground = () => true);

  // D159: the room's card was replaced by the owner's tier banner
  // (`LiveWinBanner`, tested in win_banner_d159_test).

  group('MAX X wins: one at a time, clear of the orb', () {
    testWidgets('×10 then ×100 at once: one celebration on screen, then the '
        'next (its jingle when it shows); the banner ends above the winnings '
        'chip', (tester) async {
      final (gifts, sounds) = await _pumpCombo(tester);
      await _sendLucky(tester);
      gifts.nextLucky = _won(10, 550);
      await tester.tap(_button);
      await _run(tester, const Duration(milliseconds: 150));
      gifts.nextLucky = _won(100, 2300);
      await tester.tap(_button);
      await _run(tester, const Duration(milliseconds: 150));
      expect(find.byType(MaxXCelebration), findsOneWidget);
      expect(_winPainters(tester).single.multiplier, 10);
      expect(sounds.wins, [10]);

      await _run(tester, const Duration(milliseconds: 1600));
      expect(find.byType(MaxXCelebration), findsOneWidget);
      final painter = _winPainters(tester).single;
      expect(painter.multiplier, 100);
      expect(sounds.wins, [10, 100]);

      // Geometry: at its largest the banner's coins line ends above the
      // winnings chip that sits on the orb.
      final celebration = tester.widget<MaxXCelebration>(
        find.byType(MaxXCelebration),
      );
      final chip = tester.getRect(find.byKey(LuckyComboCluster.resultKey));
      for (final style in MaxXWinStyle.all) {
        final r = celebration.radius;
        final rh = r * style.size * 1.25 * .95;
        final below = (rh * .8 + r * .2) * 1.12;
        final bottom =
            celebration.centre.dy +
            MaxXWinPainter.bannerDyAt(style, r, coins: true) +
            below;
        expect(
          bottom,
          lessThanOrEqualTo(chip.top - 8),
          reason: '×${style.tier}',
        );
        // …and under the status bar / header (not off the top).
        final top =
            celebration.centre.dy +
            MaxXWinPainter.bannerDyAt(style, r, coins: true) -
            rh * 1.12;
        expect(top, greaterThan(0), reason: '×${style.tier}');
      }
      await _run(tester, const Duration(seconds: 3));
      expect(find.byType(MaxXCelebration), findsNothing);
      await _run(tester, const Duration(seconds: 5));
    });

    testWidgets('a burst of wins: at most ${LuckyComboLayer.maxWaitingWins} '
        'wait, the bigger ones kept', (tester) async {
      final (gifts, sounds) = await _pumpCombo(tester);
      await _sendLucky(tester);
      for (final m in const [5, 5, 5, 5, 250]) {
        gifts.nextLucky = _won(m, m * 10);
        await tester.tap(_button);
        await _run(tester, const Duration(milliseconds: 100));
      }
      expect(find.byType(MaxXCelebration), findsOneWidget);
      await _run(tester, const Duration(seconds: 12));
      expect(sounds.wins, [5, 5, 5, 250]);
      expect(find.byType(MaxXCelebration), findsNothing);
      await _run(tester, const Duration(seconds: 5));
    });
  });

  group('the MAX X label fits the orb', () {
    Future<void> pumpOrb(
      WidgetTester tester,
      int count, {
      AppLanguage language = AppLanguage.ar,
    }) async {
      setViewport(tester, GoldenViewport.android);
      final ring = AnimationController(
        vsync: const TestVSync(),
        duration: const Duration(seconds: 4),
      );
      addTearDown(ring.dispose);
      final l10n = l10nFor(language);
      await pumpScreen(
        tester,
        Scaffold(
          body: Align(
            alignment: AlignmentDirectional.bottomEnd,
            child: MaxXOrb(
              ring: ring,
              streak: count,
              count: count,
              taps: 0,
              word: l10n.liveComboLabel,
              assetKey: 'lucky_clover',
            ),
          ),
        ),
        language: language,
      );
    }

    for (final count in const [12, 264, 999, 1264]) {
      testWidgets("×$count: inside the orb's chord, on screen", (tester) async {
        await pumpOrb(tester, count);
        final orb = tester.getRect(find.byType(MaxXOrb));
        final r = MaxXOrb.radiusOf(orb.width);
        final label = tester.getRect(find.byKey(MaxXOrb.labelKey));
        expect(label.width, lessThanOrEqualTo(MaxXOrb.labelWidthOf(r) + .01));
        expect(label.left, greaterThanOrEqualTo(orb.left));
        expect(label.right, lessThanOrEqualTo(orb.right));
        expect(label.right, lessThanOrEqualTo(360));
        final word = l10nFor(AppLanguage.ar).liveComboLabel;
        expect(find.text(word), count < 1000 ? findsOneWidget : findsNothing);
        expect(find.text('x$count'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('DeepAR black picture (black_output)', () {
    test('its own honest Magic line, in both languages', () {
      final status = LiveArStatus.from(
        const KabsoCameraFxStatus(KabsoCameraFxState.disabled, 'black_output'),
      );
      expect(status.state, LiveArState.unavailable);
      expect(status.problem, LiveArProblem.blackPicture);
      expect(status.code, 'black_output');
      for (final language in AppLanguage.values) {
        final l10n = l10nFor(language);
        expect(
          liveEffectStatusText(l10n, status),
          l10n.liveEffectUnavailableBlack,
        );
      }
      expect(
        LiveArStatus.from(
          const KabsoCameraFxStatus(KabsoCameraFxState.disabled, 'no_output'),
        ).problem,
        LiveArProblem.stopped,
      );
    });
  });
}
