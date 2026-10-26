import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:material_ui/material_ui.dart';

part 'live_cp_seats.frames.dart';

/// Owner D111 ("CP pair on seats"): when two CP partners (CP-018) sit on
/// seats next to each other, the two seats read as one unit — a soft
/// translucent pink-lilac pill behind both pictures and an ornament centred
/// between them. The data is `LiveSeats.couples` (v1.23.3-live); this file
/// turns it into seat pairs, decides adjacency for both audio layouts, and
/// draws the band, the ornament and where the ornament fits.
///
/// Owner D113: the couple's level frame (the owner's art, one per CP level
/// 1–6) is cut into a left ring, a right ring and a centre piece
/// ([CpSeatFrame]): each ring sits around a partner's picture with its hole
/// matching the picture exactly, and the centre piece is the ornament.

/// Two partners' tiles: [a] < [b], 0 is the host. [level] is the couple's
/// CP level, [levelName] its tier name for screen readers.
@immutable
class CpSeatPair {
  const new(
    this.a,
    this.b, {
    this.level = 1,
    this.levelName = '',
    this.micEffect = false,
  });

  final int a;
  final int b;
  final int level;
  final String levelName;

  /// D115: the couple has the Couple Mic Effect (`MIC_EFFECT`).
  final bool micEffect;

  @override
  bool operator ==(Object other) =>
      other is CpSeatPair &&
      other.a == a &&
      other.b == b &&
      other.level == level &&
      other.levelName == levelName &&
      other.micEffect == micEffect;

  @override
  int get hashCode => Object.hash(a, b, level, levelName, micEffect);

  @override
  String toString() => 'CpSeatPair($a, $b, level $level)';
}

/// The couples of [seats] as tile pairs: the host ([hostId]) is tile 0, a
/// TAKEN seat its index. A couple with a partner not found on a tile is left
/// out (the seats moved since).
List<CpSeatPair> cpSeatPairs(LiveSeats? seats, {required String hostId}) {
  if (seats == null || seats.couples.isEmpty) return const [];
  final tile = <String, int>{hostId: 0};
  for (final seat in seats.seats) {
    final user = seat.user;
    if (seat.state == LiveSeatState.taken && user != null) {
      tile[user.id] = seat.index;
    }
  }
  final pairs = <CpSeatPair>[];
  for (final couple in seats.couples) {
    if (couple.userIds.length != 2) continue;
    final x = tile[couple.userIds[0]];
    final y = tile[couple.userIds[1]];
    if (x == null || y == null || x == y) continue;
    pairs.add(
      CpSeatPair(
        math.min(x, y),
        math.max(x, y),
        level: couple.level,
        levelName: couple.levelName,
        micEffect: couple.privileges.contains(cpMicEffectPrivilege),
      ),
    );
  }
  return pairs;
}

/// The CP privilege code of the Couple Mic Effect (D112, D115).
const cpMicEffectPrivilege = 'MIC_EFFECT';

/// Rows layout (15, 20, 25 tiles, D103): consecutive tiles of the same row
/// of [rowSize].
bool cpRowsAdjacent(CpSeatPair p, {required int count, int rowSize = 5}) =>
    p.b == p.a + 1 && p.b < count && p.a ~/ rowSize == p.b ~/ rowSize;

/// Circle layout (5, 10 tiles): neighbouring guests on the ring (the last
/// and the first too). The host sits in the middle, never next to a seat.
bool cpCircleAdjacent(CpSeatPair p, {required int count}) {
  final guests = count - 1;
  if (p.a < 1 || p.b > guests || guests < 2) return false;
  return p.b - p.a == 1 || (guests > 2 && p.a == 1 && p.b == guests);
}

/// One ring of a CP level frame (D113): the [asset] of [size] pixels whose
/// transparent hole is centred at [hole] with [holeDiameter] pixels.
@immutable
class CpRingPiece {
  const new(
    this.asset, {
    required this.size,
    required this.hole,
    required this.holeDiameter,
  });

  final String asset;
  final Size size;
  final Offset hole;
  final double holeDiameter;

  /// Where the piece goes so that its hole is exactly a picture of
  /// [picture] diameter centred at [centre].
  Rect rectFor(Offset centre, double picture) {
    final s = picture / holeDiameter;
    return Rect.fromLTWH(
      centre.dx - hole.dx * s,
      centre.dy - hole.dy * s,
      size.width * s,
      size.height * s,
    );
  }
}

/// A CP level's frame (owner art, D113), cut into the ring around the
/// visually left partner, the one around the right partner, and the centre
/// piece drawn between them (the ornament, [centerSize] pixels).
@immutable
class CpSeatFrame {
  const new({
    required this.left,
    required this.right,
    required this.center,
    required this.centerSize,
  });

  final CpRingPiece left;
  final CpRingPiece right;
  final String center;
  final Size centerSize;

  /// The centre piece's width over its height.
  double get centerAspect => centerSize.width / centerSize.height;
}

/// The frames per CP level (D113: levels 1–6, `assets/live_cp_seats/`,
/// geometry in `live_cp_seats.frames.dart`). A level outside the table
/// (a future tier) uses the nearest frame.
abstract final class CpSeatFrames {
  static const levels = <int>[1, 2, 3, 4, 5, 6];

  static CpSeatFrame forLevel(int level) =>
      _cpSeatFrames[level.clamp(levels.first, levels.last)]!;
}

/// The band's and ornament's colours (D111; Kabso's own, not sampled from
/// the reference).
abstract final class KCpSeats {
  static const pink = Color(0x80FF7EB9);
  static const lilac = Color(0x80B58CFF);
  static const edge = Color(0x59FFFFFF);
  static const glow = Color(0x73FF6FB1);
}

/// How far the band reaches past each picture's edge.
const cpBandPad = 4.0;

/// The translucent pill behind two partners' pictures: [length] along the
/// line between them, [thickness] across.
class CpBand extends StatelessWidget {
  const new({required this.length, required this.thickness, super.key});

  final double length;
  final double thickness;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: SizedBox(
      width: length,
      height: thickness,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(thickness / 2),
          gradient: const LinearGradient(
            colors: [KCpSeats.pink, KCpSeats.lilac, KCpSeats.pink],
          ),
          border: Border.all(color: KCpSeats.edge, width: 0.8),
          boxShadow: const [
            BoxShadow(color: KCpSeats.glow, blurRadius: 12, spreadRadius: 1),
          ],
        ),
      ),
    ),
  );
}

/// The ornament between two partners' pictures: the centre piece of the
/// couple's level frame (D113), [size] wide (its height follows the art).
class CpOrnament extends StatelessWidget {
  const new({required this.level, required this.size, super.key});

  final int level;
  final double size;

  @override
  Widget build(BuildContext context) {
    final frame = CpSeatFrames.forLevel(level);
    final height = size / frame.centerAspect;
    return IgnorePointer(
      child: Image.asset(
        frame.center,
        width: size,
        height: height,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => Icon(
          Icons.favorite_rounded,
          size: math.min(size, height) * 0.8,
          color: const Color(0xFFFF6FB1),
        ),
      ),
    );
  }
}

/// A partner's ring of the couple's level frame (D113), drawn behind the
/// seat: [ring] is where the whole piece goes (its hole on the picture) and
/// [clip] the part of the stage it may show in (the tile, above the name);
/// the art is never mirrored.
Widget cpRingAt({
  required CpRingPiece piece,
  required Rect ring,
  required Rect clip,
  Key? key,
}) {
  final shown = ring.intersect(clip);
  if (shown.width <= 0 || shown.height <= 0) {
    return SizedBox.shrink(key: key);
  }
  // Where the art is cut, it fades out over a few points instead of
  // ending on a hard straight edge.
  final fade = math.min(cpRingFade, math.min(shown.width, shown.height) / 4);
  double stop({required bool cut, required double length}) =>
      cut ? fade / length : 0;
  final cutLeft = stop(cut: ring.left < shown.left - 0.01, length: shown.width);
  final cutRight = stop(
    cut: ring.right > shown.right + 0.01,
    length: shown.width,
  );
  final cutTop = stop(cut: ring.top < shown.top - 0.01, length: shown.height);
  final cutBottom = stop(
    cut: ring.bottom > shown.bottom + 0.01,
    length: shown.height,
  );
  Widget faded(Widget child, {required bool across}) {
    final (a, b) = across ? (cutLeft, cutRight) : (cutTop, cutBottom);
    if (a == 0 && b == 0) return child;
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) => LinearGradient(
        begin: across ? Alignment.centerLeft : Alignment.topCenter,
        end: across ? Alignment.centerRight : Alignment.bottomCenter,
        colors: const [
          Color(0x00FFFFFF),
          Color(0xFFFFFFFF),
          Color(0xFFFFFFFF),
          Color(0x00FFFFFF),
        ],
        stops: [0, a, 1 - b, 1],
      ).createShader(bounds),
      child: child,
    );
  }

  return Positioned.fromRect(
    key: key,
    rect: shown,
    child: IgnorePointer(
      child: ExcludeSemantics(
        child: faded(
          across: true,
          faded(
            across: false,
            ClipRect(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: ring.left - shown.left,
                    top: ring.top - shown.top,
                    width: ring.width,
                    height: ring.height,
                    child: Image.asset(
                      piece.asset,
                      fit: BoxFit.fill,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// The circle layout (D113 review): a partner's ring drawn whole around the
/// picture centred at [centre] ([picture] its diameter), never cut by a
/// rectangle. Where it would reach another seat's picture or name (the
/// [obstacles]) or leave [bounds], its outer extent shrinks uniformly: the
/// art shows within a circle of the largest clear radius, fading over its
/// last points; the hole stays on the picture.
Widget cpRingAround({
  required CpRingPiece piece,
  required Offset centre,
  required double picture,
  required List<CpObstacle> obstacles,
  required Rect bounds,
  Key? key,
}) {
  final ring = piece.rectFor(centre, picture);
  final radius = cpRingRadius(
    centre,
    ring,
    obstacles: obstacles,
    bounds: bounds,
  );
  return Positioned.fromRect(
    key: key,
    rect: ring,
    child: IgnorePointer(
      child: ExcludeSemantics(
        child: CpRingArt(
          piece: piece,
          radius: radius,
          centre: centre - ring.topLeft,
        ),
      ),
    ),
  );
}

/// The largest radius around [centre] the ring art ([ring], its whole
/// piece) may reach: its own farthest corner at most, and clear of every
/// obstacle and of the [bounds] edges.
double cpRingRadius(
  Offset centre,
  Rect ring, {
  required List<CpObstacle> obstacles,
  required Rect bounds,
}) {
  var r = [
    ring.topLeft,
    ring.topRight,
    ring.bottomLeft,
    ring.bottomRight,
  ].map((c) => (c - centre).distance).reduce(math.max);
  for (final o in obstacles) {
    r = math.min(r, o.distanceTo(centre));
  }
  return math.min(
    r,
    [
      centre.dx - bounds.left,
      bounds.right - centre.dx,
      centre.dy - bounds.top,
      bounds.bottom - centre.dy,
    ].reduce(math.min),
  );
}

/// A ring's art, shown within [radius] of [centre] (local coordinates).
class CpRingArt extends StatelessWidget {
  const new({
    required this.piece,
    required this.radius,
    required this.centre,
    super.key,
  });

  final CpRingPiece piece;
  final double radius;
  final Offset centre;

  @override
  Widget build(BuildContext context) {
    final art = Image.asset(
      piece.asset,
      fit: BoxFit.fill,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );
    final fade = math.min(cpRingFade, radius / 4);
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) => ui.Gradient.radial(
        centre,
        radius,
        const [Color(0xFFFFFFFF), Color(0xFFFFFFFF), Color(0x00FFFFFF)],
        [0, (radius - fade) / radius, 1],
      ),
      child: art,
    );
  }
}

/// How far a ring's art fades where the tile cuts it.
const cpRingFade = 5.0;

/// Something the ornament must not cover: a picture (circle) or a name
/// (rectangle), in the stage's coordinates.
sealed class CpObstacle {
  const new();
  bool overlaps(Rect r);

  /// How far [p] is from the obstacle (0 inside it).
  double distanceTo(Offset p);
}

class CpCircleObstacle extends CpObstacle {
  const new(this.center, this.radius);
  final Offset center;
  final double radius;

  @override
  bool overlaps(Rect r) {
    final nx = center.dx.clamp(r.left, r.right);
    final ny = center.dy.clamp(r.top, r.bottom);
    final dx = center.dx - nx;
    final dy = center.dy - ny;
    return dx * dx + dy * dy < radius * radius;
  }

  @override
  double distanceTo(Offset p) =>
      math.max(0, (p - center).distance - radius).toDouble();
}

class CpRectObstacle extends CpObstacle {
  const new(this.rect);
  final Rect rect;

  @override
  bool overlaps(Rect r) => rect.overlaps(r);

  @override
  double distanceTo(Offset p) {
    final dx = math.max(0, math.max(rect.left - p.dx, p.dx - rect.right));
    final dy = math.max(0, math.max(rect.top - p.dy, p.dy - rect.bottom));
    return math.sqrt(dx * dx + dy * dy);
  }
}

/// Whether the ellipse inscribed in [e] touches [o] (sampled on its edge,
/// plus the obstacle's own centre or corners inside it).
bool cpEllipseHits(CpObstacle o, Rect e) {
  final c = e.center;
  final rx = e.width / 2;
  final ry = e.height / 2;
  bool inside(Offset p) {
    final dx = (p.dx - c.dx) / rx;
    final dy = (p.dy - c.dy) / ry;
    return dx * dx + dy * dy <= 1;
  }

  switch (o) {
    case CpCircleObstacle(:final center, :final radius):
      if (inside(center)) return true;
      for (var i = 0; i < 32; i++) {
        final t = i * math.pi / 16;
        final p = c + Offset(rx * math.cos(t), ry * math.sin(t));
        if ((p - center).distance < radius) return true;
      }
      return false;
    case CpRectObstacle(:final rect):
      if (!rect.overlaps(e)) return false;
      if (rect.contains(c)) return true;
      if ([
        rect.topLeft,
        rect.topRight,
        rect.bottomLeft,
        rect.bottomRight,
      ].any(inside)) {
        return true;
      }
      for (var i = 0; i < 32; i++) {
        final t = i * math.pi / 16;
        if (rect.contains(c + Offset(rx * math.cos(t), ry * math.sin(t)))) {
          return true;
        }
      }
      return false;
  }
}

/// Where the ornament goes between pictures centred at [a] and [b] (owner
/// D113): centred exactly on their midpoint, [size] wide and [aspect] times
/// wider than tall, upright whatever the pair's angle.
Rect cpOrnamentRect(
  Offset a,
  Offset b, {
  required double size,
  double aspect = 1,
}) => Rect.fromCenter(
  center: Offset.lerp(a, b, 0.5)!,
  width: size,
  height: size / aspect,
);

/// A band between two picture centres [a] and [b] ([picture] is the
/// pictures' diameter), positioned in a [Stack]: centred on the midpoint and
/// turned along the line.
Widget cpBandBetween(Offset a, Offset b, double picture, {Key? key}) {
  final d = b - a;
  final length = d.distance + picture + 2 * cpBandPad;
  final thickness = picture + 2 * cpBandPad;
  final mid = Offset.lerp(a, b, 0.5)!;
  return Positioned(
    key: key,
    left: mid.dx - length / 2,
    top: mid.dy - thickness / 2,
    width: length,
    height: thickness,
    child: Transform.rotate(
      angle: math.atan2(d.dy, d.dx),
      child: CpBand(length: length, thickness: thickness),
    ),
  );
}
