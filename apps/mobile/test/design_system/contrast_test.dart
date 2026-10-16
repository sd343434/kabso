// KL-009: WCAG 2.x contrast computed from the token constants (tokens v1.1).
// Body text ≥ 4.5:1; outlines, focus indicators and large text ≥ 3:1.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/design_system/tokens/tokens.dart';
import 'package:material_ui/material_ui.dart';

double _channel(double c) =>
    c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

double _luminance(Color c) =>
    0.2126 * _channel(c.r) + 0.7152 * _channel(c.g) + 0.0722 * _channel(c.b);

/// Composites a translucent [fg] over an opaque [bg].
Color _over(Color fg, Color bg) => Color.alphaBlend(fg, bg);

double contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

const _body = 4.5;
const _large = 3.0;

void _expectAtLeast(Color fg, Color bg, double min, String what) {
  final ratio = contrast(fg, bg);
  expect(
    ratio,
    greaterThanOrEqualTo(min),
    reason: '$what: ${ratio.toStringAsFixed(2)}:1 < $min:1',
  );
}

void main() {
  test('reference values match the DESIGN_SYSTEM audit', () {
    // #FFFFFF on dark primary #E50914 = 4.79:1 (DESIGN_SYSTEM §2.4).
    expect(
      contrast(const Color(0xFFFFFFFF), KPalette.dark.primary),
      closeTo(4.79, 0.01),
    );
    expect(
      contrast(KPalette.dark.textPrimary, KPalette.dark.background),
      closeTo(19.66, 0.01),
    );
  });

  for (final (name, p) in [
    ('dark', KPalette.dark),
    ('light', KPalette.light),
  ]) {
    group('$name theme', () {
      final surfaces = {
        'background': p.background,
        'surface': p.surface,
        'surfaceRaised': p.surfaceRaised,
        'surfaceOverlay': p.surfaceOverlay,
      };

      test('body text on every surface ≥ 4.5:1', () {
        for (final MapEntry(key: s, value: bg) in surfaces.entries) {
          _expectAtLeast(p.textPrimary, bg, _body, 'textPrimary on $s');
          _expectAtLeast(p.textSecondary, bg, _body, 'textSecondary on $s');
          _expectAtLeast(p.textTertiary, bg, _body, 'textTertiary on $s');
        }
      });

      test('primaryText (red as text) ≥ 4.5:1 except on surfaceOverlay in '
          'dark (rule 2: never placed there)', () {
        for (final MapEntry(key: s, value: bg) in surfaces.entries) {
          if (name == 'dark' && s == 'surfaceOverlay') continue;
          _expectAtLeast(p.primaryText, bg, _body, 'primaryText on $s');
        }
      });

      test('label on primary fill ≥ 4.5:1', () {
        _expectAtLeast(p.onPrimary, p.primary, _body, 'onPrimary on primary');
      });

      test('status colours as text on background/surfaceRaised ≥ 4.5:1', () {
        for (final (s, c) in [
          ('error', p.error),
          ('info', p.info),
          ('success', p.success),
          ('warning', p.warning),
        ]) {
          _expectAtLeast(c, p.background, _body, '$s on background');
          _expectAtLeast(c, p.surfaceRaised, _body, '$s on surfaceRaised');
        }
      });

      test('outlines and focus indicators ≥ 3:1', () {
        for (final MapEntry(key: s, value: bg) in surfaces.entries) {
          if (s == 'surfaceOverlay') continue; // inputs never sit there
          _expectAtLeast(p.borderStrong, bg, _large, 'borderStrong on $s');
          _expectAtLeast(p.focusRing, bg, _large, 'focusRing on $s');
        }
      });

      test('destructive button label ≥ 4.5:1', () {
        final label = name == 'dark' ? KStatusColors.onStatus : p.onPrimary;
        _expectAtLeast(label, p.error, _body, 'label on error fill');
      });
    });
  }

  group('fills shared by both themes', () {
    test('onStatus on dark status fills and gold ≥ 4.5:1', () {
      const p = KPalette.dark;
      for (final (s, fill) in [
        ('success', p.success),
        ('warning', p.warning),
        ('info', p.info),
        ('error', p.error),
        ('gold', KBrandColors.gold),
      ]) {
        _expectAtLeast(KStatusColors.onStatus, fill, _body, 'onStatus on $s');
      }
    });

    test('LIVE badge label (white on live.badge) ≥ 4.5:1', () {
      _expectAtLeast(
        const Color(0xFFFFFFFF),
        KLiveColors.badge,
        _body,
        'LIVE badge',
      );
    });

    test('KL-033 VG-16: solid PK badge label (white on brand.red600) '
        '≥ 4.5:1', () {
      _expectAtLeast(
        const Color(0xFFFFFFFF),
        KBrandColors.red600,
        _body,
        'PK badge',
      );
    });

    test('KL-033: nav labels (textPrimary / textSecondary on surface) and '
        'chips ≥ 4.5:1', () {
      for (final p in [KPalette.dark, KPalette.light]) {
        _expectAtLeast(p.textPrimary, p.surface, _body, 'active nav label');
        _expectAtLeast(p.textSecondary, p.surface, _body, 'inactive label');
        _expectAtLeast(p.onPrimary, p.primary, _body, 'selected chip');
        _expectAtLeast(p.textPrimary, p.surfaceRaised, _body, 'chip');
      }
    });

    test('PK scores: white large text on pk fills ≥ 3:1; small labels use '
        'onStatus ≥ 4.5:1', () {
      for (final fill in [KLiveColors.pkLeft, KLiveColors.pkRight]) {
        _expectAtLeast(const Color(0xFFFFFFFF), fill, _large, 'PK score');
        _expectAtLeast(KStatusColors.onStatus, fill, _body, 'PK label');
      }
    });

    test('chat text on chatScrim stays ≥ 4.5:1 even over a white frame', () {
      final bg = _over(KLiveColors.chatScrim, const Color(0xFFFFFFFF));
      _expectAtLeast(const Color(0xFFFFFFFF), bg, _body, 'chat over white');
      // Gold (3.53:1) and primaryText fail over a white frame, so chat
      // usernames are white `bodyStrong`; gold appears only as an icon.
      expect(contrast(KBrandColors.gold, bg), lessThan(_body));
    });

    test(
      'caption over the live card scrim (dark scrim over white) ≥ 4.5:1',
      () {
        final bg = _over(KPalette.dark.scrim, const Color(0xFFFFFFFF));
        _expectAtLeast(const Color(0xFFFFFFFF), bg, _body, 'card caption');
      },
    );
  });
}
