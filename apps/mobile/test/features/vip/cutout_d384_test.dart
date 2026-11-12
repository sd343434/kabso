// D384 (the VIP animated picture «صورة متحركة», CONVENTIONS §10.173.2): the
// pixel work on the phone — camera buffers to RGBA, turning and mirroring,
// the person's alpha from the model, the shared head-and-shoulders square,
// the PNG strip — and the contract's `AnimatedAvatar`.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/features/profile/domain/profile_models.dart';
import 'package:kabso_live/features/vip/animated_avatar/cutout_compose.dart';
import 'package:kabso_live/features/vip/animated_avatar/cutout_frames.dart';
import 'package:kabso_live/features/vip/domain/animated_avatar.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../fixtures/vip/cutout_d384_fixtures.dart';

void main() {
  group('D384 AnimatedAvatar', () {
    test('reads the contract shape; anything incomplete is null', () {
      final json = {
        'url': 'https://m.test/media/a/clip.webp',
        'stillUrl': 'https://m.test/media/a/still.webp',
        'width': 320,
        'height': 320,
      };
      final a = AnimatedAvatar.tryParse(json)!;
      expect(a.url, endsWith('clip.webp'));
      expect(a.stillUrl, endsWith('still.webp'));
      expect(a.toJson(), json);
      expect(AnimatedAvatar.tryParse({...json, 'url': ''}), isNull);
      expect(AnimatedAvatar.tryParse({...json}..remove('stillUrl')), isNull);
      expect(AnimatedAvatar.tryParse(null), isNull);
      expect(AnimatedAvatar.tryParse('x'), isNull);
    });

    test('PublicProfile.animatedAvatar: present, absent (older servers)', () {
      final base = publicProfileJson();
      expect(PublicProfile.fromJson(base).animatedAvatar, isNull);
      final withClip = PublicProfile.fromJson({
        ...base,
        'animatedAvatar': syntheticCutout.toJson(),
      });
      expect(withClip.animatedAvatar, syntheticCutout);
      expect(withClip.toJson()['animatedAvatar'], syntheticCutout.toJson());
    });
  });

  group('D384 pixels', () {
    test('NV21 → RGBA: grey stays grey, chroma moves the colour', () {
      // 2 × 2: Y = 128 everywhere, then one V/U pair.
      final grey = Uint8List.fromList([128, 128, 128, 128, 128, 128]);
      expect(nv21ToRgba(grey, 2, 2), [
        for (var i = 0; i < 4; i++) ...[128, 128, 128, 255],
      ]);
      final red = Uint8List.fromList([128, 128, 128, 128, 255, 128]);
      final out = nv21ToRgba(red, 2, 2);
      expect(out[0], greaterThan(200));
      expect(out[2], 128);
      expect(out[3], 255);
    });

    test('BGRA (padded rows) → RGBA', () {
      final bgra = Uint8List.fromList([
        1, 2, 3, 4, 9, 9, 9, 9, // row 0 + padding
        5, 6, 7, 8, 9, 9, 9, 9, // row 1 + padding
      ]);
      expect(bgraToRgba(bgra, 1, 2, 8), [3, 2, 1, 255, 7, 6, 5, 255]);
    });

    test('turning clockwise and mirroring', () {
      // 2 × 1: A B.
      final ab = Uint8List.fromList([1, 2]);
      final cw = orientPixels(ab, 2, 1, 1, quarterTurns: 1);
      expect((cw.width, cw.height), (1, 2));
      expect(cw.data, [1, 2]);
      final ccw = orientPixels(ab, 2, 1, 1, quarterTurns: 3);
      expect((ccw.width, ccw.height), (1, 2));
      expect(ccw.data, [2, 1]);
      final half = orientPixels(ab, 2, 1, 1, quarterTurns: 2);
      expect(half.data, [2, 1]);
      final mirrored = orientPixels(ab, 2, 1, 1, mirror: true);
      expect(mirrored.data, [2, 1]);
      // 4 bytes a pixel keep together.
      final rgba = Uint8List.fromList([1, 1, 1, 1, 2, 2, 2, 2]);
      expect(orientPixels(rgba, 2, 1, 4, mirror: true).data, [
        2,
        2,
        2,
        2,
        1,
        1,
        1,
        1,
      ]);
    });

    test('the alpha from the confidences: a soft edge, scaled, mirrored', () {
      // 2 × 1 mask: background, person.
      final alpha = alphaFromConfidences([0.0, 1.0], 2, 1, 4, 1);
      expect(alpha.first, 0);
      expect(alpha.last, 255);
      expect(alpha[1], lessThanOrEqualTo(alpha[2]));
      final mirrored = alphaFromConfidences(
        [0.0, 1.0],
        2,
        1,
        4,
        1,
        mirror: true,
      );
      expect(mirrored.first, 255);
      expect(mirrored.last, 0);
      // 0.35 and below is background; 0.65 and above is the person.
      expect(alphaFromConfidences([0.3], 1, 1, 1, 1), [0]);
      expect(alphaFromConfidences([0.7], 1, 1, 1, 1), [255]);
    });

    test('one head-and-shoulders square for every frame; refused without '
        'a person in most frames', () {
      final frames = syntheticCutoutFrames();
      final box = headAndShoulders(frames)!;
      expect(box.side, lessThanOrEqualTo(96));
      expect(box.left, greaterThanOrEqualTo(0));
      expect(box.left + box.side, lessThanOrEqualTo(96));
      expect(box.top + box.side, lessThanOrEqualTo(128));
      // The head's top is near the square's top.
      expect(box.top, lessThan(128 * 0.25));
      expect(headAndShoulders(syntheticCutoutFrames(person: false)), isNull);
      // 30 % of the frames with a person is not enough.
      final few = [
        ...syntheticCutoutFrames(count: 3),
        ...syntheticCutoutFrames(count: 7, person: false),
      ];
      expect(headAndShoulders(few), isNull);
      expect(headAndShoulders(const []), isNull);
    });

    test('at most 36 frames, evenly spread', () {
      final many = List<int>.generate(50, (i) => i);
      final kept = evenlyCapped(many);
      expect(kept, hasLength(36));
      expect(kept.first, 0);
      expect(kept.last, lessThan(50));
      expect(evenlyCapped([1, 2, 3]), [1, 2, 3]);
      expect(CutoutLimits.fps * CutoutLimits.length.inSeconds, 36);
      expect(CutoutLimits.side, lessThanOrEqualTo(512));
    });
  });

  group('D384 the strip', () {
    testWidgets('a PNG strip of square frames with alpha, the background '
        'transparent', (tester) async {
      await tester.runAsync(() async {
        final strip = await composeCutoutStrip(
          syntheticCutoutFrames(count: 12),
          side: 64,
        );
        expect(strip.frames, 12);
        expect(strip.side, 64);
        expect(strip.png.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
        expect(strip.png.length, lessThanOrEqualTo(CutoutLimits.maxBytes));
        final codec = await ui.instantiateImageCodec(strip.png);
        final image = (await codec.getNextFrame()).image;
        expect((image.width, image.height), (64, 64 * 12));
        final pixels = (await image.toByteData())!;
        // A corner is background: transparent. The middle of the head is
        // the person: opaque.
        expect(pixels.getUint8(3), 0);
        final mid = ((64 * 0.4).round() * 64 + 32) * 4 + 3;
        expect(pixels.getUint8(mid), 255);
        image.dispose();
        strip.image.dispose();
      });
    });

    testWidgets('no person in most frames → refused on the phone', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await expectLater(
          composeCutoutStrip(syntheticCutoutFrames(count: 6, person: false)),
          throwsA(isA<CutoutNoPersonException>()),
        );
      });
    });
  });
}
