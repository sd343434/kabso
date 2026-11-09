// D317 (owner, from a device: the 500 000-coin «الملاك المحارب»
// `angel_warrior` — an SVGA — showed the room's header above it and looked
// cropped; «the full-screen gift must appear filling the whole screen»): a
// full-screen SVGA covers the whole live screen with its own canvas,
// centred, its aspect kept — like D309's plain MP4. Other effects keep the
// D145d fit (full width on the bottom edge).
//
// D324 (owner: «نعم»): full screen ONLY with the gift's «شاشة كاملة» badge
// (D289); a portrait canvas without the badge keeps the normal fit.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/application/live_gift_effects.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/live/domain/live_gift_models.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_gift_art.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_gift_effects_layer.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_gift_fixtures.dart';
import '../../helpers/fake_live_gift_repository.dart';
import '../../helpers/fake_live_media_engine.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

const _movieKey = Key('d317.movie');

void main() {
  for (final language in AppLanguage.values) {
    for (final viewport in GoldenViewport.values) {
      final screen = Offset.zero & viewport.logicalSize;
      final tag = '${language.name} ${viewport.name}';

      for (final canvas in const [
        Size(750, 1624), // angel_warrior's canvas (portrait)
        Size(750, 1334), // 9 : 16 portrait
        Size(750, 750), // square
        Size(1624, 750), // landscape
      ]) {
        testWidgets('$tag: a full-screen ${canvas.width.toInt()} × '
            '${canvas.height.toInt()} SVGA canvas covers the whole screen, '
            'centred, its shape kept', (tester) async {
          setViewport(tester, viewport);
          await tester.pumpWidget(
            Directionality(
              textDirection: language == AppLanguage.ar
                  ? TextDirection.rtl
                  : TextDirection.ltr,
              child: KGiftFullScreenFrame(
                viewBox: canvas,
                child: const SizedBox.expand(key: _movieKey),
              ),
            ),
          );
          expect(
            tester.getRect(find.byKey(KGiftFullScreenFrame.frameKey)),
            screen,
          );
          final drawn = tester.getRect(find.byKey(_movieKey));
          expect(drawn.left, lessThanOrEqualTo(0.01));
          expect(drawn.top, lessThanOrEqualTo(0.01));
          expect(drawn.right, greaterThanOrEqualTo(screen.right - 0.01));
          expect(drawn.bottom, greaterThanOrEqualTo(screen.bottom - 0.01));
          expect(drawn.center.dx, closeTo(screen.center.dx, 0.01));
          expect(drawn.center.dy, closeTo(screen.center.dy, 0.01));
          expect(
            drawn.width / drawn.height,
            closeTo(canvas.width / canvas.height, 0.001),
          );
          expect(
            (drawn.width - screen.width).abs() < 0.01 ||
                (drawn.height - screen.height).abs() < 0.01,
            isTrue,
          );
          expect(tester.takeException(), isNull);
        });
      }

      testWidgets('$tag: D324 — a portrait 750 × 1624 canvas WITHOUT the '
          'badge keeps the normal fit (full width, on the bottom edge)', (
        tester,
      ) async {
        setViewport(tester, viewport);
        await tester.pumpWidget(
          Directionality(
            textDirection: language == AppLanguage.ar
                ? TextDirection.rtl
                : TextDirection.ltr,
            child: giftSvgaFrame(
              viewBox: const Size(750, 1624),
              fullScreen: false,
              child: const SizedBox.expand(key: _movieKey),
            ),
          ),
        );
        expect(find.byKey(KGiftFullScreenFrame.frameKey), findsNothing);
        expect(find.byType(KGiftMovieFrame), findsOneWidget);
        final drawn = tester.getRect(find.byKey(_movieKey));
        expect(drawn.left, closeTo(0, 0.01));
        expect(drawn.width, closeTo(screen.width, 0.01));
        expect(drawn.height, closeTo(screen.width * 1624 / 750, 0.01));
        expect(drawn.bottom, closeTo(screen.bottom, 0.01));
        expect(tester.takeException(), isNull);
      });

      testWidgets('$tag: D324 — the same canvas WITH the badge covers the '
          'whole screen', (tester) async {
        setViewport(tester, viewport);
        await tester.pumpWidget(
          Directionality(
            textDirection: language == AppLanguage.ar
                ? TextDirection.rtl
                : TextDirection.ltr,
            child: giftSvgaFrame(
              viewBox: const Size(750, 1624),
              fullScreen: true,
              child: const SizedBox.expand(key: _movieKey),
            ),
          ),
        );
        expect(
          tester.getRect(find.byKey(KGiftFullScreenFrame.frameKey)),
          screen,
        );
        final drawn = tester.getRect(find.byKey(_movieKey));
        expect(drawn.left, lessThanOrEqualTo(0.01));
        expect(drawn.top, lessThanOrEqualTo(0.01));
        expect(drawn.right, greaterThanOrEqualTo(screen.right - 0.01));
        expect(drawn.bottom, greaterThanOrEqualTo(screen.bottom - 0.01));
        expect(drawn.center.dy, closeTo(screen.center.dy, 0.01));
        expect(tester.takeException(), isNull);
      });

      testWidgets('$tag: a non-full-screen effect keeps the D145d fit (full '
          'width, on the bottom edge)', (tester) async {
        setViewport(tester, viewport);
        await tester.pumpWidget(
          const Directionality(
            textDirection: TextDirection.ltr,
            child: KGiftMovieFrame(
              viewBox: Size(750, 750),
              child: SizedBox.expand(key: _movieKey),
            ),
          ),
        );
        final drawn = tester.getRect(find.byKey(_movieKey));
        expect(drawn.width, closeTo(screen.width, 0.01));
        expect(drawn.height, closeTo(screen.width, 0.01));
        expect(drawn.bottom, closeTo(screen.bottom, 0.01));
      });
    }
  }

  group('the effects layer', () {
    Future<void> play(WidgetTester tester, {required bool badge}) async {
      setViewport(tester, GoldenViewport.phone);
      final engine = FakeLiveMediaEngine();
      await pumpScreen(
        tester,
        const Scaffold(body: LiveGiftEffectsLayer(roomId: 'room-0')),
        liveGiftRepository: FakeLiveGiftRepository()
          ..extraGifts = [
            {
              ...giftJson('crown'),
              if (badge)
                'badges': [
                  {'code': 'FULLSCREEN'},
                ],
            },
          ],
        overrides: [currentUserProvider.overrideWithValue(testUser())],
      );
      await tester.pumpAndSettle();
      ProviderScope.containerOf(
        tester.element(find.byType(LiveGiftEffectsLayer)),
      ).read(liveGiftEffectsProvider('room-0').notifier).attach(engine);
      engine.chat.add(
        LiveGiftReceived(
          LiveGift.fromJson(
            liveGiftJson(
              code: 'crown',
              quantity: 1,
              recipients: [giftUserJson('sara', 'Sara')],
              art: const {
                'animationUrl':
                    'https://media.example.test/media/gifts/crown/a.svga',
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('a gift marked «شاشة كاملة» plays full screen', (tester) async {
      await play(tester, badge: true);
      expect(
        tester.widget<KGiftEffect>(find.byType(KGiftEffect)).fullScreen,
        isTrue,
      );
      await tester.pump(LiveGiftEffects.bigTime);
      await tester.pumpAndSettle();
    });

    testWidgets('a gift without the badge is not full screen (D324)', (
      tester,
    ) async {
      await play(tester, badge: false);
      expect(
        tester.widget<KGiftEffect>(find.byType(KGiftEffect)).fullScreen,
        isFalse,
      );
      await tester.pump(LiveGiftEffects.bigTime);
      await tester.pumpAndSettle();
    });
  });
}
