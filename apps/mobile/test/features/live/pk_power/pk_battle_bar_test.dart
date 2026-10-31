// Widget tests for PkBattleBar. Run: flutter test test/pk_battle_bar_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/features/live/presentation/widgets/pk_power/pk_battle_bar.dart';
import 'package:kabso_live/features/live/presentation/widgets/pk_power/pk_power_banner.dart';
import 'package:kabso_live/features/live/presentation/widgets/pk_power/pk_power_models.dart';
import 'package:material_ui/material_ui.dart';

Widget host({int l = 1000, int r = 1000, PkPowerTier? lt, PkPowerTier? rt}) =>
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 390,
            child: PkBattleBar(
              leftScore: l,
              rightScore: r,
              leftTier: lt,
              rightTier: rt,
            ),
          ),
        ),
      ),
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

  testWidgets('shows both scores for every tier combination, size unchanged', (
    t,
  ) async {
    await t.pumpWidget(host());
    await t.pump(const Duration(milliseconds: 100));
    final size = t.getSize(find.byType(PkBattleBar));
    for (final a in [null, ...PkPowerTier.values]) {
      for (final b in [null, PkPowerTier.triple]) {
        await t.pumpWidget(host(l: 1200, r: 800, lt: a, rt: b));
        await t.pump(const Duration(milliseconds: 300));
        expect(find.text('1200'), findsOneWidget);
        expect(find.text('800'), findsOneWidget);
        expect(t.getSize(find.byType(PkBattleBar)), size);
      }
    }
  });

  testWidgets(
    'the PK emblem moves toward the trailing team when the left team leads',
    (t) async {
      await t.pumpWidget(host());
      await t.pump(const Duration(milliseconds: 100));
      final emblem = find.byWidgetPredicate(
        (w) =>
            w is Image &&
            w.image is AssetImage &&
            (w.image as AssetImage).assetName.contains('emblem_'),
      );
      final x0 = t.getCenter(emblem).dx;
      await t.pumpWidget(host(l: 3000, lt: PkPowerTier.doubleTurbo));
      for (var i = 0; i < 40; i++) {
        await t.pump(const Duration(milliseconds: 33));
      }
      expect(
        t.getCenter(emblem).dx,
        greaterThan(x0),
      ); // split moved right, into the right team's side
    },
  );

  testWidgets(
    'score updates keep the same State (spring continues, no restart)',
    (t) async {
      await t.pumpWidget(host(lt: PkPowerTier.tripleTurbo));
      await t.pump(const Duration(milliseconds: 200));
      final s = t.state(find.byType(PkBattleBar));
      for (final l in [1100, 1300, 900]) {
        await t.pumpWidget(host(l: l, lt: PkPowerTier.tripleTurbo));
        await t.pump(const Duration(milliseconds: 50));
      }
      expect(identical(s, t.state(find.byType(PkBattleBar))), isTrue);
    },
  );

  testWidgets('disposes cleanly and works with reduced motion', (t) async {
    await t.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: SizedBox(
              width: 390,
              child: PkBattleBar(
                leftScore: 5,
                rightScore: 9,
                rightTier: PkPowerTier.triple,
              ),
            ),
          ),
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 200));
    expect(find.text('9'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 1));
  });
}
