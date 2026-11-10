// KL-352 A / C / D captures (scratch, not a regression test).
// Run: flutter test test/features/programs/designer2/pages_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/programs/presentation/event_concepts.dart';
import 'package:kabso_live/features/programs/presentation/event_hero_countdown.dart';
import 'package:kabso_live/features/programs/presentation/event_leaderboard_styles.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import 'capture.dart';
import 'data.dart';

/// The D captures: a leaderboard screen (title bar, board pills, stage,
/// rows 4–7, sticky «مركزي» bar).
class _LbScreen extends StatelessWidget {
  const _LbScreen(this.style, {this.list = entries, this.adminBg});

  final LeaderboardStyle style;
  final List<LbEntry> list;
  final ImageProvider? adminBg;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: kPageBg,
    child: Stack(
      children: [
        Positioned.fill(
          child: StageBackground(
            style: style,
            t: 0,
            motion: false,
            image: adminBg,
          ),
        ),
        ListView(
          padding: EdgeInsets.zero,
          children: [
            const SizedBox(height: 54),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
              child: Row(
                children: [
                  const Icon(Icons.arrow_back_rounded, color: Colors.white),
                  const SizedBox(width: KSpacing.md),
                  Text(
                    context.l10n.eventsBoard,
                    style: context.textStyles.title.copyWith(
                      color: kGoldLight,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: KSpacing.md),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: KSpacing.lg),
              child: BoardPills(),
            ),
            const SizedBox(height: KSpacing.lg),
            LeaderboardStage(
              style: style,
              entries: list,
              withBackground: false,
            ),
            const SizedBox(height: 90),
          ],
        ),
        const Positioned(
          left: KSpacing.md,
          right: KSpacing.md,
          bottom: KSpacing.md,
          child: MyRankBar(me: me, toNext: 38200),
        ),
      ],
    ),
  );
}

Widget _framed(Widget child) => RepaintBoundary(key: sceneKey, child: child);

void main() {
  setUp(
    () =>
        EventHeroCountdown.debugClock = () =>
            DateTime.utc(2026, 11, 12, 9, 30, 1, 400),
  );
  tearDown(() => EventHeroCountdown.debugClock = null);
  final gif = Platform.environment['D2_GIF'] == '1';
  final only = Platform.environment['D2_ONLY'];
  bool want(String s) => only == null || s.startsWith(only);

  // D. Leaderboard styles.
  for (final style in LeaderboardStyle.values) {
    final n = 'D_${style.index + 1}_${style.name}';
    if (!want('D')) continue;
    testWidgets(n, (tester) async {
      await pumpScene(tester, _framed(_LbScreen(style)));
      await tester.pump(const Duration(milliseconds: 700));
      await shot(tester, 'D_leaderboards/$n.ar.png');
      dumpTextRects(tester, 'contrast/$n.json');
      await tester.pumpWidget(const SizedBox());
    });
  }
  if (want('D')) {
    testWidgets('D empty + admin bg', (tester) async {
      await pumpScene(
        tester,
        _framed(_LbScreen(LeaderboardStyle.throne, list: [entries.first])),
      );
      await tester.pump(const Duration(milliseconds: 700));
      await shot(tester, 'D_leaderboards/D_1_throne_empty.ar.png');
      await tester.pumpWidget(const SizedBox());
      await pumpScene(
        tester,
        _framed(
          _LbScreen(LeaderboardStyle.podium, adminBg: MemoryImage(bgBytes)),
        ),
      );
      await tester.pump(const Duration(milliseconds: 700));
      await shot(tester, 'D_leaderboards/D_2_podium_adminBg.ar.png');
      await tester.pumpWidget(const SizedBox());
    });
    testWidgets('D reduced motion + gif', (tester) async {
      await pumpScene(
        tester,
        _framed(const _LbScreen(LeaderboardStyle.throne)),
        reduceMotion: true,
      );
      await shot(tester, 'D_leaderboards/D_1_throne_reducedMotion.ar.png');
      await tester.pumpWidget(const SizedBox());
      if (gif) {
        await pumpScene(
          tester,
          _framed(const _LbScreen(LeaderboardStyle.throne)),
        );
        for (var f = 0; f < 48; f++) {
          await shot(
            tester,
            'D_leaderboards/frames/f${f.toString().padLeft(3, '0')}.png',
            ratio: 1,
          );
          await tester.pump(const Duration(milliseconds: 1000 ~/ 12));
        }
        await tester.pumpWidget(const SizedBox());
      }
    });
  }

  // Responsive / LTR spot checks of the recommended concept.
  if (want('A') || want('R')) {
    testWidgets('A_1 360 + en', (tester) async {
      final data = showcase();
      final sc = ScrollController();
      await pumpScene(
        tester,
        _framed(
          EventConceptPage(
            concept: EventConcept.heroPodium,
            data: data,
            controller: sc,
          ),
        ),
        size: const Size(360, 800),
      );
      await tester.pump(const Duration(milliseconds: 700));
      await shot(tester, 'A_layouts/R_heroPodium_top.ar.360x800.png');
      sc.jumpTo(452);
      await tester.pump(const Duration(milliseconds: 300));
      await shot(tester, 'A_layouts/R_heroPodium_ranking.ar.360x800.png');
      await tester.pumpWidget(const SizedBox());
      final sc2 = ScrollController();
      await pumpScene(
        tester,
        _framed(
          EventConceptPage(
            concept: EventConcept.heroPodium,
            data: data,
            controller: sc2,
            tab: 1,
          ),
        ),
        ar: false,
      );
      sc2.jumpTo(452);
      await tester.pump(const Duration(milliseconds: 300));
      await shot(tester, 'A_layouts/R_heroPodium_rewards.en.png');
      await tester.pumpWidget(const SizedBox());
    });
  }

  if (want('C')) {
    testWidgets('C full rewards tab', (tester) async {
      Widget page() => RepaintBoundary(
        key: sceneKey,
        child: ColoredBox(
          color: kPageBg,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: KSpacing.lg),
                child: GoldTabs(selected: 1),
              ),
              const SizedBox(height: 16),
              for (final t in tiers) ...[
                RewardTierCard(t),
                const SizedBox(height: KSpacing.xl),
              ],
            ],
          ),
        ),
      );
      await pumpScene(
        tester,
        Align(alignment: Alignment.topCenter, child: page()),
        size: const Size(393, 2600),
      );
      final h = tester.getSize(find.byKey(sceneKey)).height;
      await tester.pumpWidget(const SizedBox());
      await pumpScene(tester, page(), size: Size(393, h));
      await tester.pump(const Duration(milliseconds: 100));
      await shot(tester, 'C_rewards/C_rewards_full.ar.png', ratio: 2);
      await tester.pumpWidget(const SizedBox());
    });
  }

  // A. Concepts: top, scrolled ranking, rewards tab.
  for (final c in EventConcept.values) {
    final n = 'A_${c.index + 1}_${c.name}';
    if (!want('A') && !want('C')) continue;
    testWidgets(n, (tester) async {
      final data = showcase();
      final sc = ScrollController();
      await pumpScene(
        tester,
        _framed(EventConceptPage(concept: c, data: data, controller: sc)),
      );
      await tester.pump(const Duration(milliseconds: 700));
      await shot(tester, 'A_layouts/${n}_1_top.ar.png');
      dumpTextRects(tester, 'contrast/${n}_1_top.json');
      sc.jumpTo(switch (c) {
        EventConcept.heroPodium => 452 - 0,
        EventConcept.stage => 330,
        EventConcept.deck => 440 + 150,
      });
      await tester.pump(const Duration(milliseconds: 300));
      await shot(tester, 'A_layouts/${n}_2_ranking.ar.png');
      await tester.pumpWidget(const SizedBox());
      final sc2 = ScrollController();
      await pumpScene(
        tester,
        _framed(
          EventConceptPage(concept: c, data: data, controller: sc2, tab: 1),
        ),
      );
      sc2.jumpTo(switch (c) {
        EventConcept.heroPodium => 452,
        EventConcept.stage => 330,
        EventConcept.deck => 440 + 150,
      });
      await tester.pump(const Duration(milliseconds: 300));
      await shot(tester, 'A_layouts/${n}_3_rewards.ar.png');
      dumpTextRects(tester, 'contrast/${n}_3_rewards.json');
      if (c == EventConcept.heroPodium) {
        sc2.jumpTo(sc2.position.maxScrollExtent);
        await tester.pump(const Duration(milliseconds: 300));
        await shot(tester, 'C_rewards/C_rewards_end.ar.png');
      }
      await tester.pumpWidget(const SizedBox());
    });
  }
}
