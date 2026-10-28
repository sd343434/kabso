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

/// Applies a row-major 3 × 4 [m] to an RGB colour in 0 … 1.
List<double> _applyM(List<double> m, List<double> rgb) => [
  for (var row = 0; row < 3; row++)
    m[row * 4] * rgb[0] +
        m[row * 4 + 1] * rgb[1] +
        m[row * 4 + 2] * rgb[2] +
        m[row * 4 + 3],
];

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

  group('D157 fill light', () {
    test('off changes nothing; Natural with no light sends no matrix', () {
      expect(LiveFillLight.off.matrix, liveIdentityMatrix);
      expect(liveColorMatrix(LiveColorFilter.natural, LiveFillLight.off), null);
      expect(const LiveBeauty().colorMatrix, isNull);
      expect(
        liveColorMatrix(LiveColorFilter.warm, LiveFillLight.off),
        LiveColorFilter.warm.matrix,
      );
      expect(
        liveColorMatrix(LiveColorFilter.natural, LiveFillLight.medium),
        LiveFillLight.medium.matrix,
      );
    });

    test('a soft, even lift with a slight warm tint, stronger per level, '
        'never a wash-out', () {
      const grey = [0.5, 0.5, 0.5];
      const shadow = [0.15, 0.12, 0.1];
      var last = _applyM(LiveFillLight.off.matrix, grey);
      for (final level in [
        LiveFillLight.low,
        LiveFillLight.medium,
        LiveFillLight.high,
      ]) {
        final g = _applyM(level.matrix, grey);
        final luma = 0.2126 * g[0] + 0.7152 * g[1] + 0.0722 * g[2];
        final lastLuma = 0.2126 * last[0] + 0.7152 * last[1] + 0.0722 * last[2];
        expect(luma, greaterThan(lastLuma), reason: '$level brighter');
        // Mid-grey gains at most ~0.15: a gentle exposure lift.
        expect(luma, lessThan(0.66), reason: '$level stays gentle');
        expect(g[0], greaterThan(g[2]), reason: '$level slightly warm');
        expect(g[0] - g[2], lessThan(0.05), reason: '$level only slightly');
        // Shadows are lifted too (a fill light), and stay dark.
        final s = _applyM(level.matrix, shadow);
        expect(s[1], greaterThan(shadow[1]));
        expect(s[1], lessThan(0.25));
        last = g;
      }
    });

    test('the light comes before the filter (one colour stage)', () {
      final m = liveColorMatrix(LiveColorFilter.mono, LiveFillLight.high)!;
      const rgb = [0.6, 0.4, 0.3];
      final expected = _apply(
        LiveColorFilter.mono,
        _applyM(LiveFillLight.high.matrix, rgb),
      );
      final got = _applyM(m, rgb);
      for (var i = 0; i < 3; i++) {
        expect(got[i], closeTo(expected[i], 1e-9));
      }
      expect(liveShaderMatrix(m).sublist(0, 3), [m[0], m[4], m[8]]);
      expect(liveShaderOffset(m), [m[3], m[7], m[11]]);
    });

    test('the light rides with beauty (copyWith, equality, colorMatrix)', () {
      const base = LiveBeauty(filter: LiveColorFilter.cool);
      final lit = base.copyWith(light: LiveFillLight.low);
      expect(lit, isNot(base));
      expect(lit, base.copyWith(light: LiveFillLight.low));
      expect(lit.hashCode, base.copyWith(light: LiveFillLight.low).hashCode);
      expect(lit.copyWith(smooth: 0.1).light, LiveFillLight.low);
      expect(
        lit.colorMatrix,
        liveColorMatrix(LiveColorFilter.cool, LiveFillLight.low),
      );
      expect(LiveFillLight.parse('high'), LiveFillLight.high);
      expect(LiveFillLight.parse('nope'), LiveFillLight.medium);
    });
  });
}
