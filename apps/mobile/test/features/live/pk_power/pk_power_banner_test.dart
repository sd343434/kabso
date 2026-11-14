// Widget tests for the PK power banner. Run: flutter test
// test/pk_power_banner_test.dart

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/features/live/presentation/widgets/pk_power/pk_battle_bar.dart';
import 'package:kabso_live/features/live/presentation/widgets/pk_power/pk_power_banner.dart';
import 'package:kabso_live/features/live/presentation/widgets/pk_power/pk_power_layer.dart';
import 'package:kabso_live/features/live/presentation/widgets/pk_power/pk_power_models.dart';
import 'package:material_ui/material_ui.dart';

PkPowerActivation act(
  String id,
  PkPowerSide side, {
  Duration left = const Duration(seconds: 20),
  Object team = 'A',
  PkPowerTier tier = PkPowerTier.doublePower,
  int multiplier = 2,
}) => PkPowerActivation(
  id: id,
  teamId: team,
  side: side,
  tier: tier,
  multiplier: multiplier,
  endsAt: clock.now().add(left),
);

Widget host(Widget child) => MaterialApp(
  home: Scaffold(body: SizedBox(width: 400, height: 800, child: child)),
);

void main() {
  // D199: the repo freezes these for its screens' goldens
  // (flutter_test_config.dart); the owner's tests play them.
  setUp(() {
    PkPowerBanner.debugTimeMs = null;
    PkBattleBar.debugTimeMs = null;
  });
  tearDown(() {
    PkPowerBanner.debugTimeMs = 1200;
    PkBattleBar.debugTimeMs = 1200;
  });

  testWidgets('shows multiplier, label and countdown', (t) async {
    await t.pumpWidget(
      host(PkPowerBanner(activation: act('e1', PkPowerSide.left))),
    );
    await t.pump(const Duration(milliseconds: 500));
    expect(find.text('x2'), findsWidgets);
    expect(find.text('DOUBLE'), findsOneWidget);
    expect(find.textContaining(':'), findsOneWidget);
  });

  testWidgets(
    'rebuild with the same id keeps the same State (animation/countdown not restarted)',
    (t) async {
      final a = act('e1', PkPowerSide.left);
      await t.pumpWidget(host(PkPowerBanner(activation: a)));
      await t.pump(const Duration(milliseconds: 800));
      final s1 = t.state(find.byType(PkPowerBanner));
      await t.pumpWidget(host(PkPowerBanner(activation: a)));
      await t.pump(const Duration(milliseconds: 16));
      expect(identical(s1, t.state(find.byType(PkPowerBanner))), isTrue);
    },
  );

  testWidgets('expires: plays exit and calls onExited once', (t) async {
    var exited = 0;
    await t.pumpWidget(
      host(
        PkPowerBanner(
          activation: act(
            'e2',
            PkPowerSide.left,
            left: const Duration(milliseconds: 300),
          ),
          onExited: () => exited++,
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 400)); // expired → exit starts
    await t.pump(const Duration(milliseconds: 500)); // exit (420 ms) done
    await t.pump(const Duration(milliseconds: 500));
    expect(exited, 1);
  });

  testWidgets('teams are independent: activating right never replaces left', (
    t,
  ) async {
    final left = act('L1', PkPowerSide.left);
    await t.pumpWidget(host(PkPowerLayer(left: left)));
    await t.pump(const Duration(milliseconds: 500));
    await t.pumpWidget(
      host(
        PkPowerLayer(
          left: left,
          right: act('R1', PkPowerSide.right, team: 'B'),
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const ValueKey('pk-power-left-L1')), findsOneWidget);
    expect(find.byKey(const ValueKey('pk-power-right-R1')), findsOneWidget);
  });

  testWidgets('removing a side exits only that side, then disposes it', (
    t,
  ) async {
    final left = act('L1', PkPowerSide.left);
    final right = act('R1', PkPowerSide.right, team: 'B');
    await t.pumpWidget(host(PkPowerLayer(left: left, right: right)));
    await t.pump(const Duration(milliseconds: 600));
    await t.pumpWidget(host(PkPowerLayer(left: left)));
    await t.pump(const Duration(milliseconds: 600));
    await t.pump();
    expect(find.byKey(const ValueKey('pk-power-right-R1')), findsNothing);
    expect(find.byKey(const ValueKey('pk-power-left-L1')), findsOneWidget);
  });

  testWidgets('repeated activations do not leak tickers', (t) async {
    for (var i = 0; i < 5; i++) {
      await t.pumpWidget(
        host(PkPowerLayer(left: act('L$i', PkPowerSide.left))),
      );
      await t.pump(const Duration(milliseconds: 200));
    }
    await t.pumpWidget(host(const SizedBox()));
    await t.pump(const Duration(seconds: 1));
    // flutter_test fails the test automatically if a Ticker is still active
    // after dispose
  });

  testWidgets('reduced motion: no crash, simple fade', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: PkPowerBanner(activation: act('e3', PkPowerSide.right)),
          ),
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('DOUBLE'), findsOneWidget);
  });

  // ── DOUBLE TURBO ──
  testWidgets('TURBO shows its label and the multiplier from state', (t) async {
    await t.pumpWidget(
      host(
        PkPowerBanner(
          activation: act(
            't1',
            PkPowerSide.right,
            tier: PkPowerTier.doubleTurbo,
          ),
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 600));
    expect(find.text('TURBO'), findsOneWidget);
    expect(find.text('x2'), findsWidgets);
  });

  testWidgets(
    'upgrading DOUBLE → TURBO on the same team replaces only that team',
    (t) async {
      final right = act('R1', PkPowerSide.right, team: 'B');
      await t.pumpWidget(
        host(PkPowerLayer(left: act('L1', PkPowerSide.left), right: right)),
      );
      await t.pump(const Duration(milliseconds: 600));
      await t.pumpWidget(
        host(
          PkPowerLayer(
            left: act('L2', PkPowerSide.left, tier: PkPowerTier.doubleTurbo),
            right: right,
          ),
        ),
      );
      await t.pump(const Duration(milliseconds: 600));
      expect(find.byKey(const ValueKey('pk-power-left-L2')), findsOneWidget);
      expect(find.byKey(const ValueKey('pk-power-right-R1')), findsOneWidget);
    },
  );

  testWidgets('TURBO expiry exits and disposes cleanly', (t) async {
    var exited = 0;
    await t.pumpWidget(
      host(
        PkPowerBanner(
          activation: act(
            't2',
            PkPowerSide.left,
            tier: PkPowerTier.doubleTurbo,
            left: const Duration(milliseconds: 400),
          ),
          onExited: () => exited++,
        ),
      ),
    );
    for (var i = 0; i < 20; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(exited, 1);
    await t.pumpWidget(host(const SizedBox()));
  });

  // ── TRIPLE ──
  testWidgets('TRIPLE shows its label', (t) async {
    await t.pumpWidget(
      host(
        PkPowerBanner(
          activation: act(
            'x1',
            PkPowerSide.left,
            tier: PkPowerTier.triple,
            multiplier: 3,
          ),
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 900));
    expect(find.text('TRIPLE'), findsOneWidget);
    expect(find.text('x3'), findsWidgets);
  });

  testWidgets(
    'TRIPLE screen-edge pulse is on the activating side only and disposes',
    (t) async {
      await t.pumpWidget(
        host(
          PkPowerLayer(
            right: act(
              'R3',
              PkPowerSide.right,
              team: 'B',
              tier: PkPowerTier.triple,
              multiplier: 3,
            ),
          ),
        ),
      );
      await t.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('pk-edge-right-R3')), findsOneWidget);
      expect(find.byKey(const ValueKey('pk-edge-left-R3')), findsNothing);
      await t.pump(const Duration(milliseconds: 1200));
      await t.pumpWidget(host(const SizedBox()));
      await t.pump(const Duration(seconds: 1));
    },
  );

  testWidgets('TRIPLE edge pulse never blocks touches', (t) async {
    var taps = 0;
    await t.pumpWidget(
      host(
        Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => taps++,
                behavior: HitTestBehavior.opaque,
              ),
            ),
            PkPowerLayer(
              left: act(
                'L3',
                PkPowerSide.left,
                tier: PkPowerTier.triple,
                multiplier: 3,
              ),
            ),
          ],
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 400));
    await t.tapAt(const Offset(8, 400)); // inside the edge-pulse strip
    expect(taps, 1);
  });

  // ── TRIPLE TURBO (ultimate) ──
  testWidgets(
    'TRIPLE TURBO shows its label and runs its 800 ms entrance without errors',
    (t) async {
      await t.pumpWidget(
        host(
          PkPowerBanner(
            activation: act(
              'u1',
              PkPowerSide.right,
              tier: PkPowerTier.tripleTurbo,
              multiplier: 3,
            ),
          ),
        ),
      );
      for (var i = 0; i < 12; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('TRIPLE\nTURBO'), findsOneWidget);
    },
  );

  testWidgets(
    'tier hierarchy: every tier is denser and has a shorter sweep period '
    'than the one below',
    (t) async {
      final tiers = PkPowerTier.values
          .map(PkPowerTheme.of)
          .map((e) => e.fx)
          .toList();
      for (var i = 1; i < tiers.length; i++) {
        expect(tiers[i].particles, greaterThan(tiers[i - 1].particles));
        expect(tiers[i].sweepPeriodMs, lessThan(tiers[i - 1].sweepPeriodMs));
      }
      expect(PkPowerTheme.tripleTurbo.fx.rainbow, isTrue);
    },
  );

  testWidgets(
    'TRIPLE TURBO expiry: final shockwave, exit, dispose — no leaks',
    (t) async {
      await t.pumpWidget(
        host(
          PkPowerLayer(
            left: act(
              'u2',
              PkPowerSide.left,
              tier: PkPowerTier.tripleTurbo,
              multiplier: 3,
              left: const Duration(milliseconds: 1200),
            ),
          ),
        ),
      );
      for (var i = 0; i < 30; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(find.byKey(const ValueKey('pk-power-left-u2')), findsNothing);
      await t.pumpWidget(host(const SizedBox()));
      await t.pump(
        const Duration(seconds: 2),
      ); // flutter_test fails if any ticker is still active
    },
  );
}
