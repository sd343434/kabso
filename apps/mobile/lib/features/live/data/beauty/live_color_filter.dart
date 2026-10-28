import 'package:material_ui/material_ui.dart';

/// D143 (owner: "Magic → colour filters first"): a colour filter on the
/// camera picture, applied on the device before publishing — in the same
/// processing path as beauty, so viewers see it, not only the host.
///
/// Each filter is an affine colour transform on RGB in 0 … 1:
/// `out = M · rgb + offset`, kept as one source of truth for the publishing
/// shader ([shaderMatrix], [shaderOffset]) and the picker's swatches
/// ([flutterMatrix]).
enum LiveColorFilter {
  natural,
  warm,
  cool,
  mono,
  cinematic,
  vivid,
  soft;

  /// Row-major 3 × 4: `[r0 r1 r2 o, g0 g1 g2 o, b0 b1 b2 o]`.
  List<double> get matrix => _matrices[this]!;

  bool get isNatural => this == LiveColorFilter.natural;

  /// The 3 × 3 part, column-major (what `uniformMatrix3fv` takes).
  List<double> get shaderMatrix {
    final m = matrix;
    return [
      for (var col = 0; col < 3; col++)
        for (var row = 0; row < 3; row++) m[row * 4 + col],
    ];
  }

  /// The offset, in 0 … 1.
  List<double> get shaderOffset {
    final m = matrix;
    return [m[3], m[7], m[11]];
  }

  /// The same transform for [ColorFilter.matrix] (5 × 4, offsets in
  /// 0 … 255): used to tint the picker's swatches.
  List<double> get flutterMatrix {
    final m = matrix;
    return [
      for (var row = 0; row < 3; row++) ...[
        m[row * 4],
        m[row * 4 + 1],
        m[row * 4 + 2],
        0,
        m[row * 4 + 3] * 255,
      ],
      0,
      0,
      0,
      1,
      0,
    ];
  }

  /// Parses a stored name; unknown or `null` → [natural].
  static LiveColorFilter parse(String? name) => LiveColorFilter.values
      .firstWhere((f) => f.name == name, orElse: () => natural);
}

// ---- composition helpers (rows: r, g, b; each [x, y, z, offset]) --------

typedef _M = List<double>;

const _identity = <double>[1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0];

// Rec. 709 luma.
const _lr = 0.2126;
const _lg = 0.7152;
const _lb = 0.0722;

_M _saturation(double s) => [
  (1 - s) * _lr + s,
  (1 - s) * _lg,
  (1 - s) * _lb,
  0,
  (1 - s) * _lr,
  (1 - s) * _lg + s,
  (1 - s) * _lb,
  0,
  (1 - s) * _lr,
  (1 - s) * _lg,
  (1 - s) * _lb + s,
  0,
];

_M _contrast(double c) {
  final o = (1 - c) / 2;
  return [c, 0, 0, o, 0, c, 0, o, 0, 0, c, o];
}

_M _scale(double r, double g, double b, {double lift = 0}) => [
  r,
  0,
  0,
  lift,
  0,
  g,
  0,
  lift,
  0,
  0,
  b,
  lift,
];

_M _offset(double r, double g, double b) => [
  1,
  0,
  0,
  r,
  0,
  1,
  0,
  g,
  0,
  0,
  1,
  b,
];

/// [b] after [a].
_M _then(_M a, _M b) {
  final out = List<double>.filled(12, 0);
  for (var row = 0; row < 3; row++) {
    for (var col = 0; col < 3; col++) {
      var v = 0.0;
      for (var k = 0; k < 3; k++) {
        v += b[row * 4 + k] * a[k * 4 + col];
      }
      out[row * 4 + col] = v;
    }
    var o = b[row * 4 + 3];
    for (var k = 0; k < 3; k++) {
      o += b[row * 4 + k] * a[k * 4 + 3];
    }
    out[row * 4 + 3] = o;
  }
  return out;
}

_M _chain(List<_M> steps) => steps.fold(_identity, _then);

final Map<LiveColorFilter, List<double>> _matrices = {
  LiveColorFilter.natural: _identity,
  LiveColorFilter.warm: _chain([
    _scale(1.08, 1.02, 0.88),
    _offset(0.02, 0.01, 0),
  ]),
  LiveColorFilter.cool: _chain([_scale(0.92, 1, 1.08), _offset(0, 0.01, 0.02)]),
  LiveColorFilter.mono: _chain([_saturation(0), _contrast(1.08)]),
  // Muted colour, firmer contrast, teal shadows and warm highlights.
  LiveColorFilter.cinematic: _chain([
    _saturation(0.78),
    _contrast(1.14),
    _scale(1.04, 1, 0.94),
    _offset(-0.01, 0.01, 0.03),
  ]),
  LiveColorFilter.vivid: _chain([_saturation(1.35), _contrast(1.06)]),
  // Low contrast, lifted blacks, a touch less colour.
  LiveColorFilter.soft: _chain([
    _saturation(0.9),
    _contrast(0.86),
    _offset(0.03, 0.03, 0.03),
  ]),
};
