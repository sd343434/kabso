// D213 goldens: the streamer live «بث ستريمر» — the go-live setup (Android),
// the host on air, the viewer's portrait and landscape pictures with the
// camera bubble, and the hub card's «ستريمر» tag (light and dark), ar and
// en; the viewer also at 360×800 with text ×1.3. The "game" and the face
// are drawn shapes (no third-party art, no real person); fake repositories,
// media engine and native side (tests only).
//
// With KABSO_CAPTURE_DIR set, each screen is also written there at @3x for
// the owner (never committed: the directory is outside the repository).
//
// Regenerate on Linux with the pinned Flutter:
//   flutter test --update-goldens test/goldens/streamer_golden_test.dart
@Tags(['golden'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:clock/clock.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/application/live_background.dart';
import 'package:kabso_live/features/live/application/live_host_controller.dart';
import 'package:kabso_live/features/live/application/live_streamer_host.dart';
import 'package:kabso_live/features/live/application/streamer_diagnostics.dart';
import 'package:kabso_live/features/live/data/live_media_engine.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/data/streamer/live_streamer_platform.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/go_live_screen.dart';
import 'package:kabso_live/features/live/live_room_screen.dart';
import 'package:kabso_live/features/live/presentation/hub/live_grid_card.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_view_data.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:material_ui/material_ui.dart';

import '../fixtures/live/live_api_fixtures.dart';
import '../helpers/fake_live_media_engine.dart';
import '../helpers/fake_live_pk.dart';
import '../helpers/fake_live_repository.dart';
import '../helpers/fake_profile_repository.dart';
import '../helpers/fake_streamer_platform.dart';
import '../helpers/fakes.dart';
import '../helpers/golden.dart';
import '../helpers/pump_app.dart';

final String? _captureDir = Platform.environment['KABSO_CAPTURE_DIR'];

/// Writes the whole screen at @3x to KABSO_CAPTURE_DIR (when set).
Future<void> _capture(WidgetTester tester, String name) async {
  final dir = _captureDir;
  if (dir == null) return;
  final view = tester.binding.renderViews.first;
  await tester.runAsync(() async {
    final layer = view.debugLayer! as OffsetLayer;
    final image = await layer.toImage(
      Offset.zero & (view.size * GoldenViewport.pixelRatio),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('$dir/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
  });
}

final DateTime _now = DateTime.utc(2026, 10, 16, 19, 18, 42);

void _testGolden(String name, Future<void> Function(WidgetTester) body) =>
    testWidgets(
      name,
      (tester) => withClock(Clock.fixed(_now), () => body(tester)),
    );

void _insets(WidgetTester tester, GoldenViewport viewport) {
  if (viewport != GoldenViewport.phone) return;
  tester.view.padding = const FakeViewPadding(
    top: 59 * GoldenViewport.pixelRatio,
    bottom: 34 * GoldenViewport.pixelRatio,
  );
  addTearDown(tester.view.resetPadding);
}

/// A drawn "game": sky, hills, a runner, coins and a score line.
class _GamePainter extends CustomPainter {
  const new();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(Offset.zero, Offset(0, h), const [
          Color(0xFF3A7BD5),
          Color(0xFF9AD0F5),
        ]),
    );
    final hills = Path()
      ..moveTo(0, h * 0.72)
      ..quadraticBezierTo(w * 0.25, h * 0.6, w * 0.5, h * 0.7)
      ..quadraticBezierTo(w * 0.75, h * 0.8, w, h * 0.66)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas
      ..drawPath(hills, Paint()..color = const Color(0xFF3FA34D))
      ..drawRect(
        Rect.fromLTWH(0, h * 0.86, w, h * 0.14),
        Paint()..color = const Color(0xFF8B5A2B),
      );
    final coin = Paint()..color = const Color(0xFFFFC83D);
    for (var i = 0; i < 5; i++) {
      canvas.drawCircle(
        Offset(w * (0.3 + i * 0.1), h * 0.5),
        math(w, h) * 0.018,
        coin,
      );
    }
    final body = Paint()..color = const Color(0xFFE5484D);
    final r = math(w, h) * 0.05;
    canvas
      ..drawCircle(Offset(w * 0.2, h * 0.86 - r * 2.2), r, body)
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(w * 0.2, h * 0.86 - r * 0.7),
            width: r * 1.4,
            height: r * 1.6,
          ),
          Radius.circular(r * 0.3),
        ),
        body,
      );
    final tp = TextPainter(
      text: TextSpan(
        text: '★ 1250   ×3',
        style: TextStyle(
          color: const Color(0xFFFFFFFF),
          fontSize: math(w, h) * 0.05,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(w * 0.5 - tp.width / 2, h * 0.08));
  }

  static double math(double w, double h) => w < h ? w : h;

  @override
  bool shouldRepaint(_GamePainter old) => false;
}

/// A drawn face for the camera bubble (no real person).
class _FacePainter extends CustomPainter {
  const new();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final s = size.shortestSide;
    canvas
      ..drawRect(Offset.zero & size, Paint()..color = const Color(0xFF6C5B7B))
      ..drawCircle(
        c.translate(0, s * 0.62),
        s * 0.42,
        Paint()..color = const Color(0xFF2E2A3A),
      )
      ..drawCircle(
        c.translate(0, -s * 0.06),
        s * 0.26,
        Paint()..color = const Color(0xFFF2C6A0),
      );
    final eye = Paint()..color = const Color(0xFF2E2A3A);
    canvas
      ..drawCircle(c.translate(-s * 0.09, -s * 0.09), s * 0.025, eye)
      ..drawCircle(c.translate(s * 0.09, -s * 0.09), s * 0.025, eye)
      ..drawArc(
        Rect.fromCenter(
          center: c.translate(0, s * 0.0),
          width: s * 0.14,
          height: s * 0.08,
        ),
        0.2,
        2.7,
        false,
        Paint()
          ..color = const Color(0xFF9C3D3D)
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.018,
      );
  }

  @override
  bool shouldRepaint(_FacePainter old) => false;
}

/// The fake engine with the drawn game and face.
class _ShowEngine extends FakeLiveMediaEngine {
  bool landscape = false;

  @override
  Widget? remoteScreen(String identity) =>
      !screenIds.contains(identity) || screenPausedIds.contains(identity)
      ? null
      : Center(
          child: AspectRatio(
            aspectRatio: landscape ? 19.5 / 9 : 9 / 19.5,
            child: const CustomPaint(painter: _GamePainter()),
          ),
        );

  @override
  Widget? remoteVideo(String identity) => present.contains(identity)
      ? const CustomPaint(painter: _FacePainter(), child: SizedBox.expand())
      : null;

  @override
  Widget? preview() =>
      const CustomPaint(painter: _FacePainter(), child: SizedBox.expand());
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  required AppLanguage language,
  required List<Override> overrides,
  GoldenViewport viewport = GoldenViewport.phone,
}) async {
  _insets(tester, viewport);
  final prefs = await testPrefs(language: language.name);
  await pumpGolden(
    tester,
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        ...pkTestOverrides(),
        ...overrides,
      ],
      child: child,
    ),
    language: language,
    viewport: viewport,
    bare: true,
  );
}

void main() {
  forEachLanguage((language) {
    final ar = language == AppLanguage.ar;

    List<Override> hostOverrides(
      FakeLiveRepository repo,
      _ShowEngine engine,
      FakeStreamerPlatform native,
    ) => [
      liveRepositoryProvider.overrideWithValue(repo),
      liveMediaEngineProvider.overrideWithValue(() => engine),
      currentUserProvider.overrideWithValue(
        testUser(displayName: ar ? 'ليلى' : 'Layla').copyWith(canHost: true),
      ),
      profileRepositoryProvider.overrideWithValue(
        FakeProfileRepository(apiProfile(ar: ar)),
      ),
      streamerPlatformProvider.overrideWithValue(native),
      liveBackgroundServiceProvider.overrideWithValue(FakeBackground()),
    ];

    _testGolden('streamer setup ($language)', (tester) async {
      final repo = FakeLiveRepository();
      final engine = _ShowEngine();
      await _pump(
        tester,
        const GoLiveScreen(),
        language: language,
        overrides: hostOverrides(repo, engine, FakeStreamerPlatform()),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(GoLiveScreen)),
      );
      final host = container.read(liveHostControllerProvider.notifier);
      await host.setMode(LiveRoomMode.streamer);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(EditableText).first,
        ar ? 'نلعب ببجي مع المتابعين' : 'Playing with my followers',
      );
      await tester.pumpAndSettle();
      await expectScreenGolden('streamer.setup', language: language);
      await _capture(tester, 'setup.${language.name}.393x852@3x');
    });

    // D346: a failed start — its own message and «نسخ تقرير المشكلة».
    _testGolden('streamer setup after a failed start ($language)', (
      tester,
    ) async {
      final repo = FakeLiveRepository();
      final engine = _ShowEngine();
      await _pump(
        tester,
        const GoLiveScreen(),
        language: language,
        overrides: hostOverrides(repo, engine, FakeStreamerPlatform()),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(GoLiveScreen)),
      );
      await container
          .read(liveHostControllerProvider.notifier)
          .setMode(LiveRoomMode.streamer);
      await container
          .read(liveStreamerHostProvider.notifier)
          .recordFailure(StreamerFailure.blocked('no_service'));
      await tester.pumpAndSettle();
      await expectScreenGolden('streamer.setup_failed', language: language);
      await _capture(tester, 'setup_failed.${language.name}.393x852@3x');
    });

    _testGolden('streamer host on air ($language)', (tester) async {
      final repo = FakeLiveRepository();
      final engine = _ShowEngine();
      await _pump(
        tester,
        const GoLiveScreen(),
        language: language,
        overrides: hostOverrides(repo, engine, FakeStreamerPlatform()),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(GoLiveScreen)),
      );
      final keep = container.listen(liveHostControllerProvider, (_, _) {});
      addTearDown(keep.close);
      final host = container.read(liveHostControllerProvider.notifier);
      await host.setMode(LiveRoomMode.streamer);
      await tester.pumpAndSettle();
      await host.goLive(title: ar ? 'نلعب ببجي' : 'Playing now');
      await tester.pumpAndSettle();
      await expectScreenGolden('streamer.host_live', language: language);
      await _capture(tester, 'host_live.${language.name}.393x852@3x');
    });

    for (final viewport in GoldenViewport.values) {
      for (final landscape in [false, true]) {
        final shape = landscape ? 'landscape' : 'portrait';
        _testGolden('streamer viewer $shape ($language, ${viewport.name})', (
          tester,
        ) async {
          // The 360×800 check runs with the text ×1.3.
          if (viewport == GoldenViewport.android) {
            tester.platformDispatcher.textScaleFactorTestValue = 1.3;
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );
          }
          final engine = _ShowEngine()..landscape = landscape;
          final hostId = apiRoom().host.id;
          engine
            ..present.add(hostId)
            ..screenIds.add(hostId);
          final room = apiRoom(ar: ar, viewerCount: 128).copyWith(
            title: ar ? 'نلعب ببجي مع المتابعين' : 'Playing with my followers',
            mode: LiveRoomMode.streamer,
            streamer: LiveStreamer(
              orientation: landscape
                  ? StreamerOrientation.landscape
                  : StreamerOrientation.portrait,
              corner: landscape
                  ? StreamerCorner.bottomRight
                  : StreamerCorner.topRight,
            ),
          );
          await _pump(
            tester,
            const LiveRoomScreen(roomId: 'room-0'),
            language: language,
            viewport: viewport,
            overrides: [
              liveRepositoryProvider.overrideWithValue(
                FakeLiveRepository(room: (id) => room.copyWith(id: id)),
              ),
              profileRepositoryProvider.overrideWithValue(
                FakeProfileRepository(apiProfile(ar: ar)),
              ),
              liveMediaEngineProvider.overrideWithValue(() => engine),
              currentUserProvider.overrideWithValue(null),
            ],
          );
          await tester.pumpAndSettle();
          await expectScreenGolden(
            'streamer.viewer.$shape',
            language: language,
            viewport: viewport,
          );
          final size = viewport == GoldenViewport.phone
              ? '393x852'
              : '360x800.ts13';
          await _capture(tester, 'viewer_$shape.${language.name}.$size@3x');
        });
      }
    }

    for (final brightness in Brightness.values) {
      _testGolden('streamer hub card ($language, ${brightness.name})', (
        tester,
      ) async {
        await pumpGolden(
          tester,
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final (streamer, name, title) in [
                  (
                    true,
                    ar ? 'ليلى' : 'Layla',
                    ar ? 'نلعب ببجي' : 'Playing now',
                  ),
                  (
                    false,
                    ar ? 'سارة' : 'Sara',
                    ar ? 'أمسية موسيقى' : 'Music night',
                  ),
                ])
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: SizedBox(
                      width: 160,
                      height: 201,
                      child: KLiveGridCard(
                        room: LiveRoomCardData(
                          hostName: name,
                          title: title,
                          viewerCount: 128,
                          isStreamer: streamer,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          language: language,
          brightness: brightness,
        );
        await tester.pumpAndSettle();
        await expectScreenGolden(
          'streamer.hub_card.${brightness.name}',
          language: language,
        );
        await _capture(
          tester,
          'hub_card.${language.name}.${brightness.name}@3x',
        );
      });
    }
  });
}
