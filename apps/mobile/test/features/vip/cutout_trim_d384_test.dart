// D384 (owner 2026-11-12: «record and pick from the gallery», 15 frames a
// second): keeping 3 s of a picked video and the times of its frames.

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/features/vip/animated_avatar/cutout_frames.dart';
import 'package:kabso_live/features/vip/animated_avatar/cutout_trim.dart';

void main() {
  group('D384 trim window', () {
    test('3 s from the start asked, pulled back before the end', () {
      expect(trimWindow(10000, 0), (startMs: 0, lengthMs: 3000));
      expect(trimWindow(10000, 4200), (startMs: 4200, lengthMs: 3000));
      expect(trimWindow(10000, 9000), (startMs: 7000, lengthMs: 3000));
      expect(trimWindow(10000, -50), (startMs: 0, lengthMs: 3000));
    });

    test('a clip of 3 s or less is kept whole', () {
      expect(trimWindow(2400, 0), (startMs: 0, lengthMs: 2400));
      expect(trimWindow(2400, 1000), (startMs: 0, lengthMs: 2400));
      expect(trimWindow(3000, 500), (startMs: 0, lengthMs: 3000));
      expect(trimWindow(0, 0), (startMs: 0, lengthMs: 0));
      expect(maxTrimStartMs(2400), 0);
      expect(maxTrimStartMs(3000), 0);
      expect(maxTrimStartMs(10000), 7000);
    });
  });

  group('D384 frame times (15 a second)', () {
    test('3 s → 45 frames, one every 66.7 ms, from the start', () {
      final times = frameTimesMs(4200, 3000);
      expect(times, hasLength(45));
      expect(times.first, 4200);
      expect(times[1], 4267);
      expect(times[3], 4400);
      expect(times.last, 4200 + 2933);
      expect(times.last, lessThan(4200 + 3000));
      for (var i = 1; i < times.length; i++) {
        expect(times[i] - times[i - 1], inInclusiveRange(66, 67));
      }
    });

    test('a shorter window has fewer frames; never more than the cap', () {
      expect(frameTimesMs(0, 2400), hasLength(36));
      expect(frameTimesMs(0, 1000), hasLength(15));
      expect(frameTimesMs(0, 0), isEmpty);
      expect(frameTimesMs(0, 60000), hasLength(CutoutLimits.maxFrames));
      expect(frameTimesMs(0, 3000, fps: 12), hasLength(36));
    });

    test('times read m:ss.d', () {
      expect(trimTimeLabel(0), '0:00.0');
      expect(trimTimeLabel(4200), '0:04.2');
      expect(trimTimeLabel(7249), '0:07.2');
      expect(trimTimeLabel(65400), '1:05.4');
    });
  });
}
