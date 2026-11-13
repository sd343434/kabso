// D160 («الجودة»: «عالي 1080p»): when the phone and the uplink allow 1080p,
// its layers (1080 / 720 / 360 at 30 fps), the automatic fall back to 720p
// after 10 s of a weak connection, and the sheet in Arabic RTL and English
// at 360×800. The camera's formats and the publisher's stats are fakes.

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
  final t0 = DateTime.utc(2026, 10, 28, 20);
  DateTime at(int s) => t0.add(Duration(seconds: s));

  test('1080p capture: what the camera (or browser) reports', () {
    expect(liveCaptures1080({'width': 1920, 'height': 1080}), isTrue);
    // Portrait (a phone's browser).
    expect(liveCaptures1080({'width': 1080, 'height': 1920}), isTrue);
    expect(liveCaptures1080({'width': 1280, 'height': 720}), isFalse);
    expect(liveCaptures1080({'width': 1920, 'height': 960}), isFalse);
    expect(liveCaptures1080(const {}), isFalse);
  });

  test('the uplink: 10 s in a row on one side of 4 Mbps', () {
    final m = UplinkMeter();
    expect(m.state, LiveUplink.unmeasured);
    // No stat: still unmeasured.
    expect(m.feed(null, at(0)), LiveUplink.unmeasured);
    expect(m.feed(5000000, at(0)), LiveUplink.unmeasured);
    expect(m.feed(4200000, at(8)), LiveUplink.unmeasured);
    expect(m.feed(4000000, at(10)), LiveUplink.sufficient);
    // A dip does not undo it until it lasts 10 s.
    expect(m.feed(1500000, at(12)), LiveUplink.sufficient);
    expect(m.feed(6000000, at(14)), LiveUplink.sufficient);
    expect(m.feed(2000000, at(16)), LiveUplink.sufficient);
    expect(m.feed(3900000, at(26)), LiveUplink.insufficient);
    expect(m.lastBps, 3900000);
    m.reset();
    expect(m.state, LiveUplink.unmeasured);
  });

  test('the layers: 1080 / 720 / 360 at 1080p, LiveKit’s 720p otherwise', () {
    const high = LiveVideoQuality.high;
    expect(liveLayerEncoding(high, 'f'), (
      scaleDown: 1.0,
      maxBitrate: 3000000,
      maxFramerate: 30,
    ));
    // 1080 / 1.5 = 720, 1080 / 3 = 360.
    expect(liveLayerEncoding(high, 'h').scaleDown, 1.5);
    expect(liveLayerEncoding(high, 'q').scaleDown, 3);
    expect(liveLayerEncoding(high, null).scaleDown, 1);
    for (final q in [LiveVideoQuality.normal, LiveVideoQuality.smooth]) {
      expect(liveLayerEncoding(q, 'f').maxBitrate, 1700000);
      expect(liveLayerEncoding(q, 'h').scaleDown, 2);
      expect(liveLayerEncoding(q, 'q').scaleDown, 4);
    }
  });

  test('the fall back: 10 s weak in a row at 1080p, once a spell', () {
    final w = HdFallbackWatch();
    const poor = LiveConnectionQuality.poor;
    const high = LiveVideoQuality.high;
    expect(w.feed(poor, high, at(0)), isFalse);
    expect(w.feed(LiveConnectionQuality.good, high, at(5)), isFalse);
    expect(w.feed(poor, high, at(6)), isFalse);
    expect(w.feed(LiveConnectionQuality.lost, high, at(15)), isFalse);
    expect(w.feed(poor, high, at(16)), isTrue);
    // Not at 720p.
    expect(w.feed(poor, LiveVideoQuality.normal, at(40)), isFalse);
    expect(w.feed(poor, high, at(41)), isFalse);
    expect(w.feed(poor, high, at(51)), isTrue);
  });

  Future<void> open(
    WidgetTester tester,
    FakeLiveMediaEngine engine,
    AppLanguage language,
  ) async {
    setViewport(tester, GoldenViewport.android);
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
  }

  final highKey = LiveQualitySheet.optionKey(LiveVideoQuality.high);

  for (final language in AppLanguage.values) {
    final ar = language == AppLanguage.ar;

    testWidgets('no 1080p camera: no «عالي» option (${language.name})', (
      tester,
    ) async {
      await open(tester, FakeLiveMediaEngine(), language);
      expect(find.byKey(highKey), findsNothing);
      expect(find.text(ar ? 'عادي' : 'Normal'), findsOneWidget);
      expect(find.textContaining('2K'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a 1080p camera, uplink not measured yet: «عالي» is tried, '
        'with the fall back said (${language.name})', (tester) async {
      final engine = FakeLiveMediaEngine()..hd = true;
      await open(tester, engine, language);
      expect(find.text(ar ? 'عالي 1080p' : 'High 1080p'), findsOneWidget);
      expect(
        find.textContaining(ar ? 'يعود إلى 720p' : 'back to 720p'),
        findsOneWidget,
      );
      final rect = tester.getRect(find.byKey(highKey));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(360));
      await tester.tap(find.byKey(highKey));
      await tester.pumpAndSettle();
      expect(engine.quality, LiveVideoQuality.high);
      expect(
        tester.getSemantics(find.byKey(highKey)),
        isSemantics(isSelected: true, isButton: true, isEnabled: true),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a measured slow uplink greys «عالي» and says why '
        '(${language.name})', (tester) async {
      final engine = FakeLiveMediaEngine()
        ..hd = true
        ..uplinkState = LiveUplink.insufficient;
      await open(tester, engine, language);
      expect(
        find.text(
          ar
              ? 'سرعة الرفع الآن أقل من المطلوب لـ 1080p'
              : 'Your upload speed is below what 1080p needs right now',
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(highKey));
      await tester.pumpAndSettle();
      expect(engine.quality, LiveVideoQuality.normal);
      // Measured fast enough: offered again.
      engine
        ..uplinkState = LiveUplink.sufficient
        ..ping();
      await tester.pump();
      await tester.tap(find.byKey(highKey));
      await tester.pumpAndSettle();
      expect(engine.quality, LiveVideoQuality.high);
    });
  }

  testWidgets('a camera that delivers less than 1080p: the quality stays and '
      'it says so', (tester) async {
    final engine = FakeLiveMediaEngine()..hd = true;
    await open(tester, engine, AppLanguage.ar);
    engine.hd = false;
    await tester.tap(find.byKey(highKey));
    await tester.pumpAndSettle();
    expect(engine.quality, LiveVideoQuality.normal);
    expect(
      find.text('هذه الكاميرا لا تلتقط 1080p، بقيت الجودة كما كانت'),
      findsOneWidget,
    );
  });
}
