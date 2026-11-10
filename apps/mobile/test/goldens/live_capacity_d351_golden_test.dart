// D351 goldens: the capacity guard's sheet «البث مزدحم الآن، حاول بعد قليل»
// (LIVE_CAPACITY_FULL) — on the real go-live screen after a refused start
// (ar and en, 393×852), and the sheet alone at 360×800 with the text ×1.3.
// «حاول مجددًا» is shown waiting (0:45 left of Retry-After). Fake repository
// and media engine (tests only); no third-party art.
//
// With KABSO_CAPTURE_DIR set, each screen is also written there at @3x for
// the owner (never committed: the directory is outside the repository).
//
// Regenerate on Linux with the pinned Flutter:
//   flutter test --update-goldens test/goldens/live_capacity_d351_golden_test.dart
@Tags(['golden'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:clock/clock.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/data/live_blocked_words_repository.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/data/live_schedule_repository.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/go_live_screen.dart';
import 'package:kabso_live/features/live/presentation/live_capacity_sheet.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:material_ui/material_ui.dart';

import '../fixtures/live/live_api_fixtures.dart';
import '../helpers/fake_live_blocked_words_repository.dart';
import '../helpers/fake_live_media_engine.dart';
import '../helpers/fake_live_repository.dart';
import '../helpers/fake_live_schedule_repository.dart';
import '../helpers/fake_profile_repository.dart';
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

final DateTime _now = DateTime.utc(2026, 11, 10, 21, 30);

const _full = ServerFailure(
  code: ErrorCode.liveCapacityFull,
  rawCode: 'LIVE_CAPACITY_FULL',
  debugMessage: 'Live is busy right now, please try again shortly.',
  statusCode: 503,
  retryAfter: Duration(seconds: 45),
);

void main() {
  forEachLanguage((language) {
    final ar = language.name == 'ar';

    testWidgets('go-live refused: the busy sheet ($language)', (tester) async {
      await withClock(Clock.fixed(_now), () async {
        await loadAppFonts();
        setViewport(tester, GoldenViewport.phone);
        tester.view.padding = const FakeViewPadding(
          top: 59 * GoldenViewport.pixelRatio,
          bottom: 34 * GoldenViewport.pixelRatio,
        );
        addTearDown(tester.view.resetPadding);
        final repo = FakeLiveRepository(
          categories: [LiveCategory(slug: 'chat', name: ar ? 'دردشة' : 'Chat')],
        )..startFailure = _full;
        await pumpScreen(
          tester,
          const GoLiveScreen(),
          language: language,
          liveMediaEngine: FakeLiveMediaEngine(),
          overrides: [
            liveRepositoryProvider.overrideWithValue(repo),
            currentUserProvider.overrideWithValue(
              testUser(displayName: ar ? 'ليلى' : 'Layla')
                  .copyWith(canHost: true),
            ),
            liveBlockedWordsRepositoryProvider.overrideWithValue(
              FakeLiveBlockedWordsRepository(),
            ),
            liveScheduleRepositoryProvider.overrideWithValue(
              FakeLiveScheduleRepository(),
            ),
            profileRepositoryProvider.overrideWithValue(
              FakeProfileRepository(apiProfile(ar: ar)),
            ),
          ],
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(GoLiveScreen.titleKey),
          ar ? 'سهرة طرب' : 'Evening chat',
        );
        await tester.tap(find.byKey(GoLiveScreen.startKey));
        await tester.pumpAndSettle();
        expect(find.byKey(LiveCapacityKeys.sheet), findsOneWidget);
        await precacheImages(tester);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'png/live_capacity.go_live.${language.name}.phone.png',
          ),
        );
        await _capture(tester, 'go_live_busy.${language.name}.393x852@3x');
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      });
    });

    testWidgets('the busy sheet, 360×800, text ×1.3 ($language)', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await withClock(Clock.fixed(_now), () async {
        await pumpGolden(
          tester,
          ColoredBox(
            color: const Color(0xFF1B1530),
            child: Align(
              alignment: AlignmentDirectional.bottomCenter,
              child: LiveCapacitySheet(
                until: _now.add(const Duration(seconds: 45)),
                onRetry: () {},
                onClose: () {},
              ),
            ),
          ),
          language: language,
          viewport: GoldenViewport.android,
          bare: true,
        );
        await expectScreenGolden(
          'live_capacity.sheet',
          language: language,
          viewport: GoldenViewport.android,
        );
        await _capture(tester, 'sheet.${language.name}.360x800@3x.text1.3');
      });
    });
  });
}
