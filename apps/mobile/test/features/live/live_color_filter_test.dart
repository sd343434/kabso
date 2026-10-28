import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/features/live/data/beauty/live_beauty.dart';
import 'package:kabso_live/features/live/data/beauty/live_color_filter.dart';

/// Applies [f]'s row-major 3 × 4 transform to an RGB colour in 0 … 1.
List<double> _apply(LiveColorFilter f, List<double> rgb) {
  final m = f.matrix;
  return [
    for (var row = 0; row < 3; row++)
      m[row * 4] * rgb[0] +
          m[row * 4 + 1] * rgb[1] +
          m[row * 4 + 2] * rgb[2] +
          m[row * 4 + 3],
  ];
}

void main() {
  test('D143: natural is the identity (the published picture unchanged)', () {
    expect(LiveColorFilter.natural.matrix, [
      1,
      0,
      0,
      0,
      0,
      1,
      0,
      0,
      0,
      0,
      1,
      0,
    ]);
    expect(LiveColorFilter.natural.isNatural, isTrue);
  });

  test('every filter is a 3 × 4 transform and keeps mid grey near grey '
      '(except the tinted ones)', () {
    for (final f in LiveColorFilter.values) {
      expect(f.matrix, hasLength(12), reason: f.name);
      expect(f.shaderMatrix, hasLength(9), reason: f.name);
      expect(f.shaderOffset, hasLength(3), reason: f.name);
      expect(f.flutterMatrix, hasLength(20), reason: f.name);
    }
    final grey = _apply(LiveColorFilter.mono, const [0.5, 0.5, 0.5]);
    expect(grey[0], closeTo(0.5, 1e-9));
  });

  test('mono has no colour; warm warms, cool cools; vivid adds colour', () {
    final mono = _apply(LiveColorFilter.mono, const [0.9, 0.3, 0.1]);
    expect(mono[0], closeTo(mono[1], 1e-9));
    expect(mono[1], closeTo(mono[2], 1e-9));
    final warm = _apply(LiveColorFilter.warm, const [0.5, 0.5, 0.5]);
    expect(warm[0], greaterThan(warm[2]));
    final cool = _apply(LiveColorFilter.cool, const [0.5, 0.5, 0.5]);
    expect(cool[2], greaterThan(cool[0]));
    final vivid = _apply(LiveColorFilter.vivid, const [0.6, 0.4, 0.4]);
    expect(vivid[0] - vivid[1], greaterThan(0.2));
  });

  test('the shader matrix is column-major; offsets are 0 … 1 for the '
      'shader and 0 … 255 for Flutter', () {
    const f = LiveColorFilter.cinematic;
    final m = f.matrix;
    // Column 0 = the red input's weight on r, g, b.
    expect(f.shaderMatrix.sublist(0, 3), [m[0], m[4], m[8]]);
    expect(f.shaderOffset, [m[3], m[7], m[11]]);
    expect(f.flutterMatrix[4], closeTo(m[3] * 255, 1e-9));
    expect(f.flutterMatrix.sublist(15), [0, 0, 0, 1, 0]);
  });

  test('parse falls back to natural', () {
    expect(LiveColorFilter.parse('warm'), LiveColorFilter.warm);
    expect(LiveColorFilter.parse('sepia'), LiveColorFilter.natural);
    expect(LiveColorFilter.parse(null), LiveColorFilter.natural);
  });

  test('the filter rides with beauty to the pipeline (copyWith, equality)', () {
    const base = LiveBeauty(enabled: true, smooth: 0.7);
    final filtered = base.copyWith(filter: LiveColorFilter.vivid);
    expect(filtered.filter, LiveColorFilter.vivid);
    expect(filtered.smooth, 0.7);
    expect(filtered, isNot(base));
    expect(filtered, base.copyWith(filter: LiveColorFilter.vivid));
    expect(base.copyWith(smooth: 0.2).filter, LiveColorFilter.natural);
  });
}
