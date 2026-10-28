// D154g («الجودة», owner item 7): when the weak-connection suggestion comes
// (20 s in a row, normal picture only, at most every 5 min) and the sheet in
// Arabic RTL and English at 360×800.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/live/data/live_media_engine.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_quality_sheet.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_live_media_engine.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

void main() {
  test('the suggestion: 20 s weak in a row, normal picture, every 5 min', () {
    final w = PoorConnectionWatch();
    final t0 = DateTime.utc(2026, 10, 28, 20);
    DateTime at(int s) => t0.add(Duration(seconds: s));
    const poor = LiveConnectionQuality.poor;
    const normal = LiveVideoQuality.normal;
    expect(w.feed(poor, normal, at(0)), isFalse);
    expect(w.feed(poor, normal, at(19)), isFalse);
    expect(w.feed(LiveConnectionQuality.good, normal, at(20)), isFalse);
    expect(w.feed(poor, normal, at(21)), isFalse);
    expect(w.feed(LiveConnectionQuality.lost, normal, at(41)), isTrue);
    expect(w.feed(poor, normal, at(100)), isFalse);
    expect(w.feed(poor, LiveVideoQuality.smooth, at(400)), isFalse);
    expect(w.feed(poor, normal, at(401)), isFalse);
    expect(w.feed(poor, normal, at(421)), isTrue);
  });

  for (final language in AppLanguage.values) {
    testWidgets('the sheet: connection and the two pictures '
        '(${language.name})', (tester) async {
      setViewport(tester, GoldenViewport.android);
      final engine = FakeLiveMediaEngine()
        ..connection = LiveConnectionQuality.poor;
      await pumpScreen(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                key: const Key('test.open'),
                onPressed: () =>
                    unawaited(showLiveQualitySheet(context, engine: engine)),
                child: const SizedBox.square(dimension: 40),
              ),
            ),
          ),
        ),
        language: language,
        liveMediaEngine: engine,
      );
      await tester.tap(find.byKey(const Key('test.open')));
      await tester.pumpAndSettle();
      final ar = language == AppLanguage.ar;
      expect(
        find.text(ar ? 'الاتصال ضعيف' : 'Connection weak'),
        findsOneWidget,
      );
      expect(find.text(ar ? 'سلس' : 'Smooth'), findsOneWidget);
      expect(find.text(ar ? 'عادي' : 'Normal'), findsOneWidget);
      expect(
        tester.getSemantics(
          find.byKey(LiveQualitySheet.optionKey(LiveVideoQuality.normal)),
        ),
        isSemantics(isSelected: true, isButton: true),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
