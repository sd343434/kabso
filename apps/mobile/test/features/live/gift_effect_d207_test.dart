// D207 (owner 2026-10-31, CONVENTIONS §10.66): what a gift's full-screen
// effect plays — SVGA, a plain MP4, a side-by-side alpha MP4, its MP3 alone
// or nothing — and the fallbacks when the device cannot play it.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/features/live/data/gift_art_cache.dart';
import 'package:kabso_live/features/live/domain/live_gift_models.dart';
import 'package:kabso_live/features/live/presentation/widgets/gift_effect_sound.dart';
import 'package:kabso_live/features/live/presentation/widgets/gift_video_effect.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_gift_art.dart';
import 'package:material_ui/material_ui.dart';

class _FailingCache extends GiftArtCache {
  final asked = <String>[];

  @override
  Future<Uint8List> load(String url) {
    asked.add(url);
    return Future.error(StateError('offline'));
  }

  @override
  Future<String> path(String url) {
    asked.add(url);
    return Future.error(StateError('offline'));
  }
}

void main() {
  GiftEffectKind kind({
    String? url = 'https://m/x',
    GiftAnimationFormat? format,
    GiftVideoAlpha? alpha,
    bool bundled = false,
    String? audio,
  }) => giftEffectKind(
    animationUrl: url,
    animationFormat: format,
    animationAlpha: alpha,
    hasBundledSvga: bundled,
    audioUrl: audio,
  );

  test(
    'the effect kind: SVGA (also an older API), each MP4 kind, MP3 alone',
    () {
      expect(kind(), GiftEffectKind.svga);
      expect(kind(format: GiftAnimationFormat.svga), GiftEffectKind.svga);
      expect(
        kind(format: GiftAnimationFormat.mp4, alpha: GiftVideoAlpha.none),
        GiftEffectKind.mp4,
      );
      expect(kind(format: GiftAnimationFormat.mp4), GiftEffectKind.mp4);
      expect(
        kind(format: GiftAnimationFormat.mp4, alpha: GiftVideoAlpha.sideBySide),
        GiftEffectKind.mp4Alpha,
      );
      // A format the app does not know is never guessed as SVGA.
      expect(kind(format: GiftAnimationFormat.unknown), GiftEffectKind.none);
      expect(
        kind(format: GiftAnimationFormat.unknown, audio: 'https://m/s.mp3'),
        GiftEffectKind.soundOnly,
      );
      expect(kind(url: null, bundled: true), GiftEffectKind.svga);
      expect(
        kind(url: null, audio: 'https://m/s.mp3'),
        GiftEffectKind.soundOnly,
      );
      expect(kind(url: null), GiftEffectKind.none);
    },
  );

  test('a side-by-side MP4 shows half its width', () {
    expect(
      giftVideoViewBox(const Size(1440, 1280), sideBySide: true),
      const Size(720, 1280),
    );
    expect(
      giftVideoViewBox(const Size(720, 1280), sideBySide: false),
      const Size(720, 1280),
    );
  });

  group('fallbacks (never a crash; the strip keeps the picture)', () {
    late GiftArtCache saved;
    late bool savedSupported;
    late _FailingCache cache;
    setUp(() {
      saved = GiftArtCache.instance;
      savedSupported = GiftAlphaShader.supported();
      cache = _FailingCache();
      GiftArtCache.instance = cache;
      KGiftEffect.animate = true;
    });
    tearDown(() {
      GiftArtCache.instance = saved;
      GiftAlphaShader.supported = () => savedSupported;
      KGiftEffect.animate = false;
    });

    Future<int> run(
      WidgetTester tester,
      KGiftEffect Function(VoidCallback) make,
    ) async {
      var done = 0;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.rtl,
          child: make(() => done++),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      return done;
    }

    testWidgets('side-by-side without shader support: skipped, nothing drawn', (
      tester,
    ) async {
      GiftAlphaShader.supported = () => false;
      final done = await run(
        tester,
        (onDone) => KGiftEffect(
          animationKey: null,
          animationUrl: 'https://m/x.mp4',
          animationFormat: GiftAnimationFormat.mp4,
          animationAlpha: GiftVideoAlpha.sideBySide,
          onDone: onDone,
        ),
      );
      expect(done, 1);
      // The video was never fetched (it could not be composited).
      expect(cache.asked, isEmpty);
      expect(find.byType(GiftVideoView), findsNothing);
    });

    testWidgets('a plain MP4 that cannot be fetched: skipped once', (
      tester,
    ) async {
      final done = await tester.runAsync(
        () => run(
          tester,
          (onDone) => KGiftEffect(
            animationKey: null,
            animationUrl: 'https://m/plain.mp4',
            animationFormat: GiftAnimationFormat.mp4,
            animationAlpha: GiftVideoAlpha.none,
            onDone: onDone,
          ),
        ),
      );
      await tester.pump();
      expect(done, 1);
      expect(cache.asked, ['https://m/plain.mp4']);
      expect(find.byType(GiftVideoView), findsNothing);
    });

    testWidgets('an unknown format: nothing fetched, done at once', (
      tester,
    ) async {
      final done = await run(
        tester,
        (onDone) => KGiftEffect(
          animationKey: null,
          animationUrl: 'https://m/x.lottie',
          animationFormat: GiftAnimationFormat.unknown,
          onDone: onDone,
        ),
      );
      expect(done, 1);
      expect(cache.asked, isEmpty);
    });

    testWidgets('MP3 only with sound off: nothing fetched, done at once', (
      tester,
    ) async {
      final done = await run(
        tester,
        (onDone) => KGiftEffect(
          animationKey: null,
          audioUrl: 'https://m/s.mp3',
          audioDurationMs: 3000,
          soundOn: false,
          onDone: onDone,
        ),
      );
      expect(done, 1);
      expect(cache.asked, isEmpty);
    });

    testWidgets(
      'MP3 only with sound on: fetched; the effect lasts its length',
      (tester) async {
        final savedEnabled = GiftEffectSound.enabled;
        addTearDown(() => GiftEffectSound.enabled = savedEnabled);
        var done = 0;
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: KGiftEffect(
              animationKey: null,
              audioUrl: 'https://m/s.mp3',
              audioDurationMs: 3000,
              onDone: () => done++,
            ),
          ),
        );
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pump();
        expect(cache.asked, ['https://m/s.mp3']);
        expect(done, 0);
        await tester.pump(const Duration(milliseconds: 3100));
        expect(done, 1);
      },
    );
  });
}
