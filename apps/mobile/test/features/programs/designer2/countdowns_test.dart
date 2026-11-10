// KL-352 B: the five hero countdowns over the owner's sample background.
// Stills @3x (normal, final hour, ended, reduced motion) and GIF frames @1x.
// Run: flutter test test/features/programs/designer2/countdowns_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/features/programs/presentation/event_hero_countdown.dart';
import 'package:material_ui/material_ui.dart';

import 'capture.dart';

final _bg = File('test/fixtures/programs/d303_event_bg_treasure.webp')
    .readAsBytesSync();
final _start = DateTime.utc(2026, 11, 10, 17);
final _end = DateTime.utc(2026, 11, 17, 17);

Widget scene(HeroCountdownStyle style, {bool? reduce}) => RepaintBoundary(
  key: sceneKey,
  child: SizedBox(
    width: 393,
    height: 236,
    child: Stack(
      fit: StackFit.expand,
      children: [
        Image.memory(
          _bg,
          fit: BoxFit.cover,
          alignment: const Alignment(0, -.2),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x33000000), Color(0x8C12020A), Color(0xE612020A)],
            ),
          ),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: EventHeroCountdown(
              startsAt: _start,
              endsAt: _end,
              style: style,
              reduceMotion: reduce ?? false,
            ),
          ),
        ),
      ],
    ),
  ),
);

Future<void> _pump(WidgetTester tester, Widget w) =>
    pumpScene(tester, Align(alignment: Alignment.topCenter, child: w));

void main() {
  tearDown(() => EventHeroCountdown.debugClock = null);
  final gif = Platform.environment['D2_GIF'] == '1';

  for (final style in HeroCountdownStyle.values) {
    final n = '${style.index + 1}_${style.name}';
    testWidgets('countdown $n', (tester) async {
      // 5 d 07:29:58.6 left: the frames show several second changes and,
      // within ~3 s, the minute rolling over.
      EventHeroCountdown.debugClock = () =>
          DateTime.utc(2026, 11, 12, 9, 30, 1, 400);
      await _pump(tester, scene(style));
      await tester.pump(const Duration(milliseconds: 650));
      await shot(tester, 'B_countdowns/B_${n}.ar.png');
      dumpTextRects(tester, 'contrast/B_${n}.json');
      if (gif) {
        for (var f = 0; f < 45; f++) {
          await shot(
            tester,
            'B_countdowns/frames/$n/f${f.toString().padLeft(3, '0')}.png',
            ratio: 1,
          );
          await tester.pump(const Duration(milliseconds: 1000 ~/ 15));
        }
      }
      // Mid-change still (t ≈ 0.4: flip half-way, coin edge-on...).
      await tester.pump(const Duration(milliseconds: 140));
      await shot(tester, 'B_countdowns/B_${n}_midChange.ar.png');
      await tester.pumpWidget(const SizedBox());
    });
    testWidgets('countdown $n urgent', (tester) async {
      EventHeroCountdown.debugClock = () => _end.subtract(
        const Duration(minutes: 42, seconds: 10, milliseconds: 600),
      );
      await _pump(tester, scene(style));
      await tester.pump(const Duration(milliseconds: 700));
      await shot(tester, 'B_countdowns/B_${n}_urgent.ar.png');
      dumpTextRects(tester, 'contrast/B_${n}_urgent.json');
      if (gif) {
        for (var f = 0; f < 30; f++) {
          await shot(
            tester,
            'B_countdowns/frames/${n}_urgent/f${f.toString().padLeft(3, '0')}.png',
            ratio: 1,
          );
          await tester.pump(const Duration(milliseconds: 1000 ~/ 15));
        }
      }
      await tester.pumpWidget(const SizedBox());
    });
    testWidgets('countdown $n ended + reduced', (tester) async {
      EventHeroCountdown.debugClock = () => _end.add(const Duration(hours: 1));
      await _pump(tester, scene(style));
      await tester.pump(const Duration(milliseconds: 100));
      await shot(tester, 'B_countdowns/B_${n}_ended.ar.png');
      await tester.pumpWidget(const SizedBox());
      EventHeroCountdown.debugClock = () =>
          DateTime.utc(2026, 11, 12, 9, 30, 1, 400);
      await _pump(tester, scene(style, reduce: true));
      await shot(tester, 'B_countdowns/B_${n}_reducedMotion.ar.png');
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpWidget(const SizedBox());
    });
  }
}
