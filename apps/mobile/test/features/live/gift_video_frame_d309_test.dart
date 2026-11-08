// D309 (owner, from a device: «ارى ان الهدايا شاشة كاملة تظهر بهذا الشكل،
// أليس من المفترض ظهورها بشكل كامل»): a plain MP4 gift effect (`alpha` NONE,
// its own background) fills the whole live screen — D207's «played full
// screen as is» — instead of standing full width on the bottom edge with a
// band of the room above it; a side-by-side (transparent) one keeps the
// SVGA fit. The layer itself already covers the whole screen above the
// header (max_x_d145d_test: the effect's rect is the screen).

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/live/presentation/widgets/gift_video_effect.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_gift_art.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/golden.dart';

const _videoKey = Key('d309.video');

Future<void> _pump(
  WidgetTester tester, {
  required Size video,
  required bool sideBySide,
  required GoldenViewport viewport,
  required AppLanguage language,
}) async {
  setViewport(tester, viewport);
  await tester.pumpWidget(
    Directionality(
      textDirection: language == AppLanguage.ar
          ? TextDirection.rtl
          : TextDirection.ltr,
      child: GiftVideoFrame(
        video: video,
        sideBySide: sideBySide,
        movieFrame: (viewBox, child) =>
            KGiftMovieFrame(viewBox: viewBox, child: child),
        child: const ColoredBox(key: _videoKey, color: Color(0xFF00FF00)),
      ),
    ),
  );
}

void main() {
  for (final language in AppLanguage.values) {
    for (final viewport in GoldenViewport.values) {
      final screen = Offset.zero & viewport.logicalSize;
      final tag = '${language.name} ${viewport.name}';

      for (final video in const [
        Size(720, 1280), // 9 : 16, taller phones
        Size(1080, 1920),
        Size(1080, 2400), // the phone's own shape
        Size(1280, 720), // landscape
      ]) {
        testWidgets('$tag: a plain ${video.width.toInt()} × '
            '${video.height.toInt()} video fills the whole screen, centred '
            '(no band of the room)', (tester) async {
          await _pump(
            tester,
            video: video,
            sideBySide: false,
            viewport: viewport,
            language: language,
          );
          expect(find.byKey(GiftVideoFrame.plainKey), findsOneWidget);
          expect(tester.getRect(find.byKey(GiftVideoFrame.plainKey)), screen);
          final drawn = tester.getRect(find.byKey(_videoKey));
          // Covers every edge of the screen …
          expect(drawn.left, lessThanOrEqualTo(0.01));
          expect(drawn.top, lessThanOrEqualTo(0.01));
          expect(drawn.right, greaterThanOrEqualTo(screen.right - 0.01));
          expect(drawn.bottom, greaterThanOrEqualTo(screen.bottom - 0.01));
          // … centred, its own shape kept (not stretched).
          expect(drawn.center.dx, closeTo(screen.center.dx, 0.01));
          expect(drawn.center.dy, closeTo(screen.center.dy, 0.01));
          expect(
            drawn.width / drawn.height,
            closeTo(video.width / video.height, 0.001),
          );
          // Only the overflow at two opposite edges is cut: one of the
          // sides matches the screen exactly.
          expect(
            (drawn.width - screen.width).abs() < 0.01 ||
                (drawn.height - screen.height).abs() < 0.01,
            isTrue,
          );
          expect(tester.takeException(), isNull);
        });
      }

      testWidgets('$tag: a side-by-side (transparent) video keeps the SVGA '
          'fit: its colour half full width, on the bottom edge', (
        tester,
      ) async {
        await _pump(
          tester,
          video: const Size(1440, 1280),
          sideBySide: true,
          viewport: viewport,
          language: language,
        );
        expect(find.byKey(GiftVideoFrame.plainKey), findsNothing);
        final frame = tester.getRect(find.byType(KGiftMovieFrame));
        expect(frame, screen);
        final drawn = tester.getRect(find.byKey(_videoKey));
        expect(drawn.width, closeTo(screen.width, 0.01));
        expect(drawn.bottom, closeTo(screen.bottom, 0.01));
        // 720 × 1280 (the colour half) at the screen's width.
        expect(drawn.height, closeTo(screen.width * 1280 / 720, 0.01));
      });
    }
  }
}
