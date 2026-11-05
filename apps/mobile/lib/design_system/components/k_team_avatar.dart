import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// v1.71-live (D283, CONVENTIONS §10.96.10): the Kabso Team's fixed look —
/// the picture (the owner's Kabi in a suit) and the locked team frame
/// (assets/staff/PROVENANCE.md; the region covers: `StaffCovers`). A limited staff account's
/// `avatarUrl` IS the API's team picture URL ([isTeamAvatarUrl]); wherever
/// an avatar shows it, the app draws the bundled art on a red radial
/// background inside the team frame instead of loading it.
abstract final class KabsoTeamLook {
  /// The path of the API's team picture (`getKabsoTeamAvatar`).
  static const avatarPath = '/api/v1/staff/team-avatar.png';

  static const avatarAsset = 'assets/staff/kabso_team_avatar.png';
  static const frameAsset = 'assets/staff/kabso_team_frame.png';

  /// The picture's head-and-shoulders window, as fractions of the trimmed
  /// art (497 × 512): left, top and side (of the art's width). The circle
  /// shows the face, the headset and the shoulders.
  static const double pictureLeft = 0.16;
  static const double pictureTop = 0.14;
  static const double pictureSide = 0.68;
  static const double pictureAspect = 497 / 512;

  /// The radial background behind the transparent art (Kabso red to a deep
  /// wine), so the mascot reads in any theme.
  static const background = RadialGradient(
    colors: [Color(0xFFE53935), Color(0xFF3B070B)],
  );

  /// The frame art's photo window, measured from the owner's art (768 ×
  /// 768) the way [KabsoTeamFrameWindow.measure] does on the device: centre and
  /// diameter as fractions of the art. Used until (and unless) the device's
  /// own measurement of the bundled file is ready — so a new art dropped in
  /// at [frameAsset] needs no code change.
  static const frameCentre = Offset(0.496, 0.500);
  static const double frameWindow = 0.714;

  /// How much of the window's rim the picture covers (no gap).
  static const double overlap = 1.02;
}

/// Whether [url] is the API's team picture (any origin: the path decides).
bool isTeamAvatarUrl(String? url) {
  if (url == null || url.isEmpty) return false;
  final uri = Uri.tryParse(url);
  return uri != null && uri.path == KabsoTeamLook.avatarPath;
}

/// The team picture alone: the mascot's head and shoulders in a circle
/// [size] across on the red radial background.
class KabsoTeamPicture extends StatelessWidget {
  const new({required this.size, super.key});

  static const pictureKey = Key('staff.team.picture');

  final double size;

  @override
  Widget build(BuildContext context) {
    final artW = size / KabsoTeamLook.pictureSide;
    final artH = artW / KabsoTeamLook.pictureAspect;
    return Semantics(
      image: true,
      label: context.l10n.staffTeamPicture,
      child: ClipOval(
        key: pictureKey,
        child: SizedBox.square(
          dimension: size,
          child: Stack(
            children: [
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: KabsoTeamLook.background,
                  ),
                ),
              ),
              Positioned(
                left: -KabsoTeamLook.pictureLeft * artW,
                top: -KabsoTeamLook.pictureTop * artW,
                width: artW,
                height: artH,
                child: const Image(
                  image: AssetImage(KabsoTeamLook.avatarAsset),
                  fit: BoxFit.fill,
                  excludeFromSemantics: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The team picture inside the locked team frame. [pictureSize]: the
/// picture's diameter; the frame overflows it (like the VIP frame) unless
/// [boxed], where [pictureSize] is the frame's whole box instead.
class KabsoTeamAvatar extends StatefulWidget {
  const new({required this.pictureSize, super.key}) : boxed = false;

  /// The frame fits a [box] square; the picture fills its window.
  const new boxed({required double box, super.key})
    : pictureSize = box,
      boxed = true;

  static const frameKey = Key('staff.team.frame');

  final double pictureSize;
  final bool boxed;

  @override
  State<KabsoTeamAvatar> createState() => _KabsoTeamAvatarState();
}

class _KabsoTeamAvatarState extends State<KabsoTeamAvatar> {
  ({Offset centre, double diameter}) _window = (
    centre: KabsoTeamLook.frameCentre,
    diameter: KabsoTeamLook.frameWindow,
  );

  @override
  void initState() {
    super.initState();
    final known = KabsoTeamFrameWindow.measured;
    if (known != null) {
      _window = known;
    } else {
      unawaited(
        KabsoTeamFrameWindow.measure().then((w) {
          if (w != null && mounted) setState(() => _window = w);
        }),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final (:centre, :diameter) = _window;
    // The art's side for the picture size (the window a hair smaller).
    final double art;
    final double picture;
    if (widget.boxed) {
      art = widget.pictureSize;
      picture = art * diameter * KabsoTeamLook.overlap;
    } else {
      picture = widget.pictureSize;
      art = picture / (diameter * KabsoTeamLook.overlap);
    }
    final box = widget.boxed ? art : picture;
    // The art's offset in the box: the window's centre on the box's centre
    // when overflowing; the art's own place when boxed.
    final artLeft = widget.boxed ? 0.0 : box / 2 - centre.dx * art;
    final artTop = widget.boxed ? 0.0 : box / 2 - centre.dy * art;
    final picLeft = artLeft + centre.dx * art - picture / 2;
    final picTop = artTop + centre.dy * art - picture / 2;
    return SizedBox.square(
      dimension: box,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: picLeft,
            top: picTop,
            width: picture,
            height: picture,
            child: KabsoTeamPicture(size: picture),
          ),
          Positioned(
            key: KabsoTeamAvatar.frameKey,
            left: artLeft,
            top: artTop,
            width: art,
            height: art,
            child: const IgnorePointer(
              child: Image(
                image: AssetImage(KabsoTeamLook.frameAsset),
                fit: BoxFit.fill,
                excludeFromSemantics: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The team frame's photo window, measured once from the bundled art: the
/// smallest circle around the transparent opening (rays from the canvas
/// centre to the first covered pixel, alpha ≥ 40), as D265's
/// `VipSvgaClip.window` does for the VIP frames. Null until measured (and
/// when the art has no round opening: the constants then stay).
abstract final class KabsoTeamFrameWindow {
  static ({Offset centre, double diameter})? measured;
  static Future<({Offset centre, double diameter})?>? _pending;

  static const int rays = 90;

  static Future<({Offset centre, double diameter})?> measure() =>
      _pending ??= _measure().then((w) => measured = w);

  static Future<({Offset centre, double diameter})?> _measure() async {
    try {
      final data = await rootBundle.load(KabsoTeamLook.frameAsset);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final bytes = await image.toByteData();
      if (bytes == null) return null;
      return windowOf(bytes, image.width, image.height);
    } on Object {
      return null;
    }
  }

  /// The window of an RGBA image (premultiplied or not: only alpha counts).
  static ({Offset centre, double diameter})? windowOf(
    ByteData data,
    int w,
    int h,
  ) {
    final cx = w / 2;
    final cy = h / 2;
    bool clear(int x, int y) => data.getUint8((y * w + x) * 4 + 3) < 40;
    if (!clear(cx.round(), cy.round())) return null;
    final start = math.min(w, h) * 0.12;
    final points = <Offset>[];
    for (var a = 0; a < rays; a++) {
      final t = a * 2 * math.pi / rays;
      final dx = math.cos(t);
      final dy = math.sin(t);
      var r = start;
      var last = r;
      var open = false;
      while (true) {
        r += 1;
        final x = (cx + r * dx).round();
        final y = (cy + r * dy).round();
        if (x < 0 || y < 0 || x >= w || y >= h) {
          open = true;
          break;
        }
        if (!clear(x, y)) break;
        last = r;
      }
      if (!open) points.add(Offset(cx + last * dx, cy + last * dy));
    }
    if (points.length < rays * 0.6) return null;
    final circle = enclosingCircle(points);
    final d = 2 * circle.radius / w;
    if (d < 0.2 || d > 1) return null;
    return (
      centre: Offset(circle.centre.dx / w, circle.centre.dy / h),
      diameter: d,
    );
  }

  /// The smallest circle around [points] (a narrowing grid search).
  static ({Offset centre, double radius}) enclosingCircle(
    List<Offset> points,
  ) {
    double radiusAt(Offset c) {
      var r = 0.0;
      for (final p in points) {
        r = math.max(r, (p - c).distance);
      }
      return r;
    }

    var left = double.infinity;
    var top = double.infinity;
    var right = double.negativeInfinity;
    var bottom = double.negativeInfinity;
    for (final p in points) {
      left = math.min(left, p.dx);
      top = math.min(top, p.dy);
      right = math.max(right, p.dx);
      bottom = math.max(bottom, p.dy);
    }
    var best = Offset((left + right) / 2, (top + bottom) / 2);
    var bestR = radiusAt(best);
    var span = math.max(right - left, bottom - top) / 4;
    while (span > 0.001 * math.max(1, bestR)) {
      final around = best;
      for (var i = -4; i <= 4; i++) {
        for (var j = -4; j <= 4; j++) {
          final c = around + Offset(i * span / 4, j * span / 4);
          final r = radiusAt(c);
          if (r < bestR) {
            bestR = r;
            best = c;
          }
        }
      }
      span /= 2;
    }
    return (centre: best, radius: bestR);
  }
}
