import 'dart:math' as math;

import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_audio_room.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_cp_mic_effect.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_cp_seat_fx.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_cp_seats.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_glass.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Columns of a multi-guest grid with [count] tiles (host included).
int videoSeatColumns(int count) => count <= 4 ? 2 : 3;

/// Multi-guest video tiles (CP-011): the host's tile first, then seats
/// 1 … count-1 (empty with "Seat n", locked, or the guest).
class VideoSeatGrid extends StatelessWidget {
  const new({
    required this.count,
    required this.host,
    super.key,
    this.seats = const [],
    this.guestVideo,
    this.onSeat,
    this.accent = KBrandColors.red400,
  });

  /// Tiles, the host's included.
  final int count;

  /// The host's tile content (the camera, or an avatar).
  final Widget host;

  /// The server's seats; a missing index shows as empty.
  final List<LiveSeat> seats;

  /// A seated guest's picture, by seat index.
  final Widget? Function(LiveSeat seat)? guestVideo;
  final ValueChanged<int>? onSeat;
  final Color accent;

  static Key seatKey(int index) => Key('seat.$index');

  @override
  Widget build(BuildContext context) {
    final columns = videoSeatColumns(count);
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = KSpacing.xs + KSpacing.xxs;
        final rows = (count / columns).ceil();
        var side = (constraints.maxWidth - gap * (columns - 1)) / columns;
        if (constraints.hasBoundedHeight) {
          final byHeight = (constraints.maxHeight - gap * (rows - 1)) / rows;
          if (byHeight < side) side = byHeight;
        }
        return Center(
          child: SizedBox(
            width: side * columns + gap * (columns - 1),
            child: Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                SizedBox.square(
                  dimension: side,
                  child: _HostVideoTile(accent: accent, child: host),
                ),
                for (var i = 1; i < count; i++)
                  SizedBox.square(
                    key: seatKey(i),
                    dimension: side,
                    child: _VideoSeatTile(
                      seat: _seat(i),
                      video: guestVideo,
                      onTap: onSeat == null ? null : () => onSeat!(i),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  LiveSeat _seat(int index) => seats.firstWhere(
    (s) => s.index == index,
    orElse: () =>
        LiveSeat(index: index, state: LiveSeatState.empty, user: null),
  );
}

class _HostVideoTile extends StatelessWidget {
  const new({required this.child, required this.accent});

  final Widget child;
  final Color accent;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(KRadius.md + 2),
      border: Border.all(color: accent.withValues(alpha: 0.85), width: 1.5),
      boxShadow: [
        BoxShadow(color: accent.withValues(alpha: 0.35), blurRadius: 14),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(KRadius.md),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: KPalette.dark.surface, child: child),
          PositionedDirectional(
            start: KSpacing.xs + 2,
            bottom: KSpacing.xs + 2,
            child: _Tag(text: context.l10n.goLiveHostTag, color: accent),
          ),
        ],
      ),
    ),
  );
}

class _Tag extends StatelessWidget {
  const new({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: KSpacing.sm,
      vertical: KSpacing.xxs,
    ),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(KRadius.pill),
    ),
    child: Text(
      text,
      style: context.textStyles.caption.copyWith(
        color: KPalette.dark.textPrimary,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _VideoSeatTile extends StatelessWidget {
  const new({required this.seat, required this.video, required this.onTap});

  final LiveSeat seat;
  final Widget? Function(LiveSeat seat)? video;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    const p = KPalette.dark;
    final text = context.textStyles;
    final user = seat.user;
    final Widget content;
    if (seat.state == LiveSeatState.taken && user != null) {
      final picture = video?.call(seat);
      content = Stack(
        fit: StackFit.expand,
        children: [
          picture ??
              Center(
                child: KAvatar(
                  name: user.displayName,
                  imageUrl: user.avatarUrl,
                ),
              ),
          PositionedDirectional(
            start: KSpacing.xs + 2,
            end: KSpacing.xs + 2,
            bottom: KSpacing.xs + 2,
            child: Row(
              children: [
                if (seat.mutedByHost)
                  const Padding(
                    padding: EdgeInsetsDirectional.only(end: KSpacing.xxs),
                    child: Icon(
                      Icons.mic_off_rounded,
                      size: 14,
                      color: Color(0xFFFF5A5F),
                    ),
                  ),
                Expanded(
                  child: Text(
                    user.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.caption.copyWith(
                      color: p.textPrimary,
                      fontWeight: FontWeight.w600,
                      shadows: const [
                        Shadow(color: KLiveColors.chatScrim, blurRadius: 4),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    } else {
      final locked = seat.state == LiveSeatState.locked;
      content = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            locked ? Icons.lock_rounded : Icons.weekend_rounded,
            size: 30,
            color: p.textPrimary.withValues(alpha: locked ? 0.55 : 0.92),
          ),
          const SizedBox(height: KSpacing.xs),
          Text(
            l10n.goLiveSeat(seat.index + 1),
            style: text.label.copyWith(
              color: p.textPrimary.withValues(alpha: locked ? 0.55 : 0.92),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }
    return Semantics(
      button: onTap != null,
      child: GestureDetector(
        onTap: onTap,
        child: LiveGlass(radius: KRadius.md, child: content),
      ),
    );
  }
}

/// Audio seats (CP-011), laid out after the owner's ref 83 (430 pt wide):
/// the host in the middle (an 81 pt circle with the "Host" tag, their name
/// and the live's points under it) and the guests' seats on a circle around
/// them — seat 1 at the top, then clockwise (mirrored in RTL). Each seat is
/// a chair with + and its number, a locked chair, or the guest's picture and
/// name. Measured on the reference's eight seats: radius 152 pt, the first
/// at 22.5° past the top; 4 and 12 guests use the same circle (owner's
/// choice), and the circle shrinks on narrow screens.
class AudioSeatRing extends StatelessWidget {
  const new({
    required this.count,
    required this.host,
    required this.hostName,
    super.key,
    this.hostMicOn,
    this.hostPoints,
    this.seats = const [],
    this.onSeat,
    this.speaking = const {},
    this.micOff = const {},
    this.onHost,
    this.hostTapLabel,
    this.cpPairs = const [],
  });

  /// Owner D111: CP partners' tiles (0 is the host, see [cpSeatPairs]). Two
  /// partners next to each other — consecutive tiles of a row, or
  /// neighbouring guests on the circle — are joined by a band behind their
  /// pictures with an ornament between them; partners apart show nothing.
  final List<CpSeatPair> cpPairs;

  /// Seat indexes whose own mic is off (the guest muted themselves): the
  /// mic-off badge, as when the host mutes them.
  final Set<int> micOff;

  /// Tapping the host's picture (owner, 2026-10-26: the host mutes and
  /// unmutes themselves there, not with a bar button); [hostTapLabel] says
  /// what it does to screen readers.
  final VoidCallback? onHost;
  final String? hostTapLabel;

  /// Seats, the host's included (owner D103: 5, 10, 15, 20 or 25). Up to
  /// [circleMax] they sit on a circle around the host; above, every tile —
  /// the host's first — sits in rows of [rowSize].
  final int count;

  /// The host's circle content (their avatar).
  final Widget host;
  final String hostName;

  /// The host's mic badge when muted; null hides it (unknown to viewers).
  final bool? hostMicOn;

  /// CP-012: the live's points under the host's name (shortened), or null.
  final String? hostPoints;
  final List<LiveSeat> seats;
  final ValueChanged<int>? onSeat;

  /// Seat indexes speaking now (0 is the host): a glowing ring.
  final Set<int> speaking;

  static Key seatKey(int index) => Key('audioSeat.$index');

  /// D111: the band and the ornament of the CP pair on tiles [a] < [b].
  static Key cpBandKey(int a, int b) => Key('audioSeat.cp.$a.$b.band');
  static Key cpOrnamentKey(int a, int b) => Key('audioSeat.cp.$a.$b.ornament');

  /// D113: the rings of the couple's level frame around the visually left
  /// and right partner of the pair on tiles [a] < [b].
  static Key cpRingKey(int a, int b, {required bool left}) =>
      Key('audioSeat.cp.$a.$b.ring.${left ? 'l' : 'r'}');

  /// D115: the tiles of partners whose couple has the Couple Mic Effect
  /// (adjacent or not).
  Set<int> get cpMicTiles => {
    for (final p in cpPairs)
      if (p.micEffect) ...[p.a, p.b],
  };

  /// The CP pairs drawn joined in the current layout.
  List<CpSeatPair> get joinedPairs => [
    for (final p in cpPairs)
      if (count > circleMax
          ? cpRowsAdjacent(p, count: count)
          : cpCircleAdjacent(p, count: count))
        p,
  ];

  /// The largest room drawn as a circle (owner D100: "a circle of at most 11").
  static const circleMax = 11;

  /// Seats per row when the room is larger than [circleMax].
  static const rowSize = 5;

  /// Space between two rows of seats.
  static const rowGap = 10.0;

  /// Ref 83 (points at 430 pt).
  static const radius = 152.0;
  static const chair = 58.0;
  static const hostSize = 81.0;

  /// The host's circle sits this far below the ring's centre (measured: 0).
  static const hostDrop = 0.0;

  /// From a seat's centre to its label's centre.
  static const labelDrop = 39.0;

  /// The stage's height for [radius] r.
  static double heightFor(double r) => 2 * r + chair + 30;

  @override
  Widget build(BuildContext context) => count > circleMax ? _rows() : _circle();

  Widget _hostSeat({bool compact = false, bool ghost = false}) {
    final seat = _HostSeat(
      key: ghost ? null : seatKey(0),
      onTap: ghost ? null : onHost,
      tapLabel: hostTapLabel,
      circle: ghost ? const SizedBox.shrink() : host,
      name: hostName,
      muted: hostMicOn == false,
      speaking: !ghost && speaking.contains(0),
      points: hostPoints,
      compact: compact,
      cpMic: !ghost && cpMicTiles.contains(0),
    );
    return ghost ? _ghost(seat) : seat;
  }

  /// D113 (owner: the ornament exactly in the middle): a partner's tile
  /// again, without its picture, painted above the ornament layer so its
  /// name, mic-off badge and "Host" tag stay on top of the ornament. Never
  /// tapped, never read twice.
  static Widget _ghost(Widget tile) =>
      IgnorePointer(child: ExcludeSemantics(child: tile));

  /// Under a guest seat in the rows, the invisible space the host tile's
  /// taller name gap and points pill take, so every row has the same height
  /// and the rows the same spacing (owner request). It scales with the text.
  Widget _hostExtra() {
    final points = hostPoints;
    return ExcludeSemantics(
      child: Visibility(
        visible: false,
        maintainSize: true,
        maintainAnimation: true,
        maintainState: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 2),
            if (points != null) ...[
              const SizedBox(height: 2),
              _PointsPill(points),
            ],
          ],
        ),
      ),
    );
  }

  /// Owner D100: 15, 20 or 25 tiles in rows of [rowSize] — the host is the
  /// first tile, then seats 1 … count-1, in reading order (start to end, so
  /// mirrored in Arabic). A narrow screen scales the tiles down instead of
  /// wrapping them, and a short one (owner, 2026-10-26: 25 seats hid under
  /// the chat) scales every row down so all of them show.
  Widget _rows() => LayoutBuilder(
    builder: (context, box) {
      final cell = box.maxWidth / rowSize;
      Widget tile(int i, {bool ghost = false}) => SizedBox(
        width: cell,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: _Seat.width,
            child: i == 0
                ? _hostSeat(compact: true, ghost: ghost)
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _guest(i, ghost: ghost),
                      _hostExtra(),
                    ],
                  ),
          ),
        ),
      );
      final joined = joinedPairs;
      final labelHeight = MediaQuery.textScalerOf(context).scale(11.5) * 1.2;
      Widget row(int first) {
        final row = Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = first; i < first + rowSize && i < count; i++) tile(i),
          ],
        );
        final pairs = [
          for (final p in joined)
            if (p.a >= first && p.b < first + rowSize) p,
        ];
        if (pairs.isEmpty) return row;
        final partners = {
          for (final p in pairs) ...[p.a, p.b],
        };
        // The partners' tiles again (names, badges, tag) above the ornaments.
        final ghosts = Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = first; i < first + rowSize && i < count; i++)
              if (partners.contains(i))
                tile(i, ghost: true)
              else
                SizedBox(width: cell),
          ],
        );
        return _cpRow(
          ghosts: ghosts,
          rtl: Directionality.of(context) == TextDirection.rtl,
          joined: joined.length,
          first: first,
          width: box.maxWidth,
          cell: cell,
          labelHeight: labelHeight,
          pairs: pairs,
          row: row,
        );
      }

      final rows = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var first = 0; first < count; first += rowSize) ...[
            if (first > 0) const SizedBox(height: rowGap),
            row(first),
          ],
        ],
      );
      final height = AudioStageBounds.of(context);
      if (height == null || !height.isFinite) return rows;
      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: math.max(height, minRowsHeight),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.topCenter,
            child: SizedBox(width: box.maxWidth, child: rows),
          ),
        ),
      );
    },
  );

  /// The rows never shrink below this height (with the keyboard up, the
  /// stage scrolls instead).
  static const minRowsHeight = 240.0;

  Widget _circle() => LayoutBuilder(
    builder: (context, box) {
      final width = box.maxWidth;
      // Keep the side seats and their labels on screen.
      final r = math.min(radius, width / 2 - chair / 2 - 8);
      final height = heightFor(r);
      final cx = width / 2;
      final cy = r + chair / 2;
      final rtl = Directionality.of(context) == TextDirection.rtl;
      final guests = count - 1;
      final children = <Widget>[];
      final centres = <int, Offset>{};
      for (var i = 1; i <= guests; i++) {
        final angle =
            -math.pi / 2 + math.pi / guests + (i - 1) * 2 * math.pi / guests;
        final dx = r * math.cos(angle) * (rtl ? -1 : 1);
        final dy = r * math.sin(angle);
        centres[i] = Offset(cx + dx, cy + dy);
      }
      final joined = joinedPairs;
      final ornaments = <Widget>[];
      if (joined.isNotEmpty) {
        final labelHeight = MediaQuery.textScalerOf(context).scale(11.5) * 1.2;
        final obstacles = <CpObstacle>[
          // The host's circle, name and points in the middle.
          CpRectObstacle(
            Rect.fromLTRB(
              cx - hostSize / 2 - 4,
              cy - hostSize / 2 - 4,
              cx + hostSize / 2 + 4,
              cy + hostSize / 2 + 12 + 2 * labelHeight + 4,
            ),
          ),
          for (final MapEntry(key: i, value: c) in centres.entries)
            ..._seatObstacles(i, c, labelHeight, rtl: rtl),
        ];
        for (final p in joined) {
          final a = centres[p.a]!;
          final b = centres[p.b]!;
          children.add(
            cpBandBetween(a, b, _Seat.avatar, key: cpBandKey(p.a, p.b)),
          );
        }
        for (final p in joined) {
          children.addAll(
            _cpCircleRings(
              p,
              centres,
              labelHeight,
              hostRect: obstacles.first,
              rtl: rtl,
              stage: Rect.fromLTRB(0, -cpRingTop + chair / 2, width, height),
            ),
          );
        }
        for (final p in joined) {
          ornaments.add(
            _cpFx(
              p,
              centres[p.a]!,
              centres[p.b]!,
              obstacles: obstacles,
              pairs: joined.length,
            ),
          );
        }
      }
      for (var i = 1; i <= guests; i++) {
        final dx = centres[i]!.dx - cx;
        final dy = centres[i]!.dy - cy;
        children.add(
          Positioned(
            left: cx + dx - _Seat.width / 2,
            top: cy + dy - chair / 2,
            width: _Seat.width,
            child: _guest(i),
          ),
        );
      }
      children
        ..add(
          Positioned(
            left: cx - _HostSeat.width / 2,
            top: cy + hostDrop - hostSize / 2,
            width: _HostSeat.width,
            child: _hostSeat(),
          ),
        )
        ..addAll(ornaments)
        // The partners' names and badges above the ornaments (owner D113).
        ..addAll([
          for (final i in {
            for (final p in joined) ...[p.a, p.b],
          })
            Positioned(
              left: centres[i]!.dx - _Seat.width / 2,
              top: centres[i]!.dy - chair / 2,
              width: _Seat.width,
              child: _guest(i, ghost: true),
            ),
        ]);
      return SizedBox(
        height: height,
        child: Stack(clipBehavior: Clip.none, children: children),
      );
    },
  );

  /// The ornament's width (owner D113: 62 pt in rows and circle; rows
  /// scale it with the tiles).
  static const cpOrnamentSize = 62.0;

  /// D113: how far above a picture's centre its ring may show (the crown
  /// of the frame), in the tile's points; below, it stops above the name.
  static const double cpRingTop = chair / 2 + rowGap;

  /// The two rings of [p]'s level frame around pictures centred at [a] and
  /// [b] (visual coordinates, [scale] the tiles' scale): the visually left
  /// partner gets the left ring. Each shows only within its tile ([cell]
  /// wide) and above the name.
  List<Widget> _cpRings(
    CpSeatPair p,
    Offset a,
    Offset b,
    double labelHeight, {
    double scale = 1,
    double? cell,
  }) {
    final frame = CpSeatFrames.forLevel(p.level);
    final aLeft = a.dx <= b.dx;
    final half = (cell ?? _Seat.width) / 2;
    Widget ring(Offset c, {required bool left}) {
      final piece = left ? frame.left : frame.right;
      return cpRingAt(
        key: cpRingKey(p.a, p.b, left: left),
        piece: piece,
        ring: piece.rectFor(c, _Seat.avatar * scale),
        clip: Rect.fromLTRB(
          c.dx - half,
          c.dy - cpRingTop * scale,
          c.dx + half,
          c.dy + (chair / 2 + 2) * scale,
        ),
      );
    }

    return [ring(a, left: aLeft), ring(b, left: !aLeft)];
  }

  /// D113 review, the circle: each partner's ring drawn whole, shrunk
  /// (never cut) where it would reach another seat's picture or name, the
  /// host or the [stage]'s edges. The partner's own name is drawn on top.
  List<Widget> _cpCircleRings(
    CpSeatPair p,
    Map<int, Offset> centres,
    double labelHeight, {
    required CpObstacle hostRect,
    required bool rtl,
    required Rect stage,
  }) {
    final frame = CpSeatFrames.forLevel(p.level);
    final a = centres[p.a]!;
    final b = centres[p.b]!;
    final aLeft = a.dx <= b.dx;
    Widget ring(int tile, {required bool left}) {
      final c = centres[tile]!;
      return cpRingAround(
        key: cpRingKey(p.a, p.b, left: left),
        piece: left ? frame.left : frame.right,
        centre: c,
        picture: _Seat.avatar,
        bounds: stage,
        obstacles: [
          hostRect,
          for (final MapEntry(key: i, value: o) in centres.entries)
            if (i != tile) ..._seatObstacles(i, o, labelHeight, rtl: rtl),
        ],
      );
    }

    return [ring(p.a, left: aLeft), ring(p.b, left: !aLeft)];
  }

  /// Where a pair's animation may show: both partners' tiles ([cell] wide),
  /// from the crown down to the names.
  Rect _cpArea(Offset a, Offset b, {double scale = 1, double? cell}) {
    final half = (cell ?? _Seat.width) / 2;
    Rect tile(Offset c) => Rect.fromLTRB(
      c.dx - half,
      c.dy - cpRingTop * scale,
      c.dx + half,
      c.dy + (chair / 2 + 2) * scale,
    );
    return tile(a).expandToInclude(tile(b));
  }

  /// D113 amendment: the light animation around [p] (visual coordinates),
  /// clear of [obstacles]; fewer parts when the room shows many [pairs].
  Widget _cpFx(
    CpSeatPair p,
    Offset a,
    Offset b, {
    required List<CpObstacle> obstacles,
    required int pairs,
    double scale = 1,
    double? cell,
    double? ornamentTop,
  }) {
    final area = _cpArea(a, b, scale: scale, cell: cell);
    // What the ornament lets out may rise above the rings' area, into the
    // empty space between rows ([ornamentTop]), never over the row above's
    // names.
    final bounds = ornamentTop == null
        ? area
        : Rect.fromLTRB(area.left, ornamentTop, area.right, area.bottom);
    // Owner D113: the ornament sits exactly in the middle of the two
    // pictures, always upright, at its fixed size (62 pt at the room's
    // full size): it covers the inner edges of both pictures, and the
    // partners' names, mic-off badges and "Host" tag are painted above it.
    final rect = cpOrnamentRect(
      a,
      b,
      size: cpOrnamentSize * scale,
      aspect: CpSeatFrames.forLevel(p.level).centerAspect,
    );
    return CpPairFx(
      key: CpPairFx.keyFor(p.a, p.b),
      level: p.level,
      a: a,
      b: b,
      picture: _Seat.avatar * scale,
      area: area,
      obstacles: obstacles,
      budget: pairs > CpPairFx.crowdedPairs
          ? CpPairFx.crowdedParts
          : CpPairFx.maxParts,
      ornament: rect,
      ornamentBounds: bounds,
      ornamentKey: cpOrnamentKey(p.a, p.b),
      ornamentChild: _cpOrnament(p, rect.width),
    ).positioned();
  }

  bool _muted(int i) {
    if (i == 0) return hostMicOn == false;
    if (micOff.contains(i)) return true;
    for (final s in seats) {
      if (s.index == i) return s.state == LiveSeatState.taken && s.mutedByHost;
    }
    return false;
  }

  /// A seat's picture, name and mic badge as obstacles for the ornament: [c]
  /// is the picture's centre, [scale] the tile's scale. With [rtl] false the
  /// x axis may also be the row's start-to-end axis (the badge sits at the
  /// end).
  List<CpObstacle> _seatObstacles(
    int i,
    Offset c,
    double labelHeight, {
    required bool rtl,
    double scale = 1,
  }) {
    final half = _Seat.width / 2 * scale;
    final labelTop = c.dy + (AudioSeatRing.chair / 2 + 2) * scale;
    final picture = _Seat.avatar / 2 * scale;
    return [
      CpCircleObstacle(c, picture + 2 * scale),
      // The compact host's "Host" tag under its picture (rows).
      if (i == 0)
        CpRectObstacle(
          Rect.fromLTRB(
            c.dx - 24 * scale,
            c.dy + 16 * scale,
            c.dx + 24 * scale,
            c.dy + 32 * scale,
          ),
        ),
      CpRectObstacle(
        Rect.fromLTRB(
          c.dx - half + 2 * scale,
          labelTop,
          c.dx + half - 2 * scale,
          labelTop + labelHeight * scale,
        ),
      ),
      if (_muted(i))
        CpRectObstacle(
          // The mic-off badge at the picture's bottom end corner (the
          // compact host's is larger and further out).
          i == 0
              ? Rect.fromLTRB(
                  c.dx + (rtl ? -37 : 17) * scale,
                  c.dy + 11 * scale,
                  c.dx + (rtl ? -17 : 37) * scale,
                  c.dy + 31 * scale,
                )
              : Rect.fromLTRB(
                  c.dx + (rtl ? -26 : 10) * scale,
                  c.dy + 10 * scale,
                  c.dx + (rtl ? -10 : 26) * scale,
                  c.dy + 26 * scale,
                ),
        ),
    ];
  }

  Widget _cpOrnament(CpSeatPair p, double size) {
    final ornament = CpOrnament(level: p.level, size: size);
    return p.levelName.isEmpty
        ? ExcludeSemantics(child: ornament)
        : Semantics(label: p.levelName, child: ornament);
  }

  /// D111 in the rows: the bands behind the row's joined pairs and their
  /// ornaments over it. Positions run from the row's start (so they mirror
  /// with the row in Arabic); every tile is [cell] wide and scaled like
  /// [_rows] scales it.
  Widget _cpRow({
    required int first,
    required double width,
    required double cell,
    required double labelHeight,
    required List<CpSeatPair> pairs,
    required Widget row,
    required Widget ghosts,
    required bool rtl,
    required int joined,
  }) {
    final n = math.min(rowSize, count - first);
    final scale = math.min(1, cell / _Seat.width).toDouble();
    final offset = (width - n * cell) / 2;
    final y = AudioSeatRing.chair / 2 * scale;
    Offset centre(int i) => Offset(offset + (i - first + 0.5) * cell, y);
    // The rings are placed in visual coordinates (the art is never mirrored).
    Offset visual(Offset c) => rtl ? Offset(width - c.dx, c.dy) : c;
    final picture = _Seat.avatar * scale;
    final thickness = picture + 2 * cpBandPad * scale;
    // Pictures, names and badges where they show (visual coordinates), and
    // for the second row the host's points pill above it (host column).
    final hostColumn = visual(Offset(offset + 0.5 * cell, y)).dx;
    final shown = <CpObstacle>[
      if (first == rowSize && hostPoints != null)
        CpRectObstacle(
          Rect.fromLTRB(
            hostColumn - 30 * scale,
            y - (chair / 2 + rowGap + 40) * scale,
            hostColumn + 30 * scale,
            y - (chair / 2 + rowGap - 2) * scale,
          ),
        ),
      for (var i = first; i < first + n; i++)
        ..._seatObstacles(
          i,
          visual(centre(i)),
          labelHeight,
          rtl: rtl,
          scale: scale,
        ),
    ];
    final bands = <Widget>[];
    final rings = <Widget>[];
    final fx = <Widget>[];
    for (final p in pairs) {
      final a = centre(p.a);
      final b = centre(p.b);
      rings.addAll(
        _cpRings(
          p,
          visual(a),
          visual(b),
          labelHeight,
          scale: scale,
          cell: cell,
        ),
      );
      fx.add(
        _cpFx(
          p,
          visual(a),
          visual(b),
          obstacles: shown,
          pairs: joined,
          scale: scale,
          cell: cell,
          // Above a row: the row gap and the (empty) space under the row
          // above's names that the host's points take in its column.
          ornamentTop:
              y - (chair / 2 + rowGap + (hostPoints == null ? 2 : 19)) * scale,
        ),
      );
      bands.add(
        PositionedDirectional(
          key: cpBandKey(p.a, p.b),
          start: a.dx - thickness / 2,
          top: y - thickness / 2,
          width: b.dx - a.dx + thickness,
          height: thickness,
          child: CpBand(length: b.dx - a.dx + thickness, thickness: thickness),
        ),
      );
    }
    return Stack(
      clipBehavior: Clip.none,
      children: [...bands, ...rings, row, ...fx, ghosts],
    );
  }

  Widget _guest(int i, {bool ghost = false}) {
    final seat = seats.firstWhere(
      (s) => s.index == i,
      orElse: () => LiveSeat(index: i, state: LiveSeatState.empty, user: null),
    );
    final user = seat.user;
    final onTap = onSeat == null ? null : () => onSeat!(i);
    if (seat.state == LiveSeatState.taken && user != null) {
      if (ghost) {
        return _ghost(
          _Seat(
            label: user.displayName,
            semantics: user.displayName,
            muted: seat.mutedByHost || micOff.contains(i),
            framed:
                count <= circleMax &&
                joinedPairs.any((p) => p.a == i || p.b == i),
            child: const SizedBox.shrink(),
          ),
        );
      }
      return _Seat(
        key: seatKey(i),
        label: user.displayName,
        semantics: user.displayName,
        muted: seat.mutedByHost || micOff.contains(i),
        speaking: speaking.contains(i),
        onTap: onTap,
        // D113 review: in the circle a partner's ring is whole, so its own
        // name sits on the art; a soft shadow keeps it readable.
        framed:
            count <= circleMax && joinedPairs.any((p) => p.a == i || p.b == i),
        cpMic: cpMicTiles.contains(i),
        child: KAvatar(
          name: user.displayName,
          imageUrl: user.avatarUrl,
          size: _Seat.avatar,
        ),
      );
    }
    if (ghost) return const SizedBox.shrink();
    final locked = seat.state == LiveSeatState.locked;
    return _Seat(
      key: seatKey(i),
      label: KFormat.grouped(i),
      semantics: KFormat.grouped(i),
      onTap: onTap,
      child: _Chair(locked: locked),
    );
  }
}

/// An empty or locked seat: a chair in white 18 % with + (or a lock) on it.
class _Chair extends StatelessWidget {
  const new({required this.locked});

  final bool locked;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: AudioSeatRing.chair,
    child: Stack(
      alignment: Alignment.center,
      children: [
        const Icon(
          Icons.chair_rounded,
          size: AudioSeatRing.chair,
          color: KAudioRoom.chair,
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Icon(
            locked ? Icons.lock_rounded : Icons.add_rounded,
            size: locked ? 18 : 24,
            color: KAudioRoom.textSoft,
          ),
        ),
      ],
    ),
  );
}

/// A guest seat: the chair or the guest's picture, then the number or the
/// name under it.
class _Seat extends StatelessWidget {
  const new({
    required this.child,
    required this.label,
    required this.semantics,
    super.key,
    this.muted = false,
    this.speaking = false,
    this.onTap,
    this.framed = false,
    this.cpMic = false,
  });

  /// D113: the seat wears a CP ring drawn whole under its name.
  final bool framed;

  /// D115: the seat's partner couple has the Couple Mic Effect.
  final bool cpMic;

  final Widget child;
  final String label;
  final String semantics;
  final bool muted;
  final bool speaking;
  final VoidCallback? onTap;

  /// The seat's box (labels may be wider than the chair).
  static const width = 72.0;
  static const avatar = 50.0;

  @override
  Widget build(BuildContext context) => Semantics(
    button: onTap != null,
    label: semantics,
    onTap: onTap,
    excludeSemantics: true,
    child: GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: AudioSeatRing.chair,
            child: Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  if (child is _Chair)
                    child
                  else
                    _speakingPicture(
                      speaking: speaking,
                      cpMic: cpMic,
                      size: avatar,
                      picture: child,
                    ),
                  if (muted)
                    const PositionedDirectional(
                      bottom: -1,
                      end: -1,
                      child: _MicOffBadge(),
                    ),
                ],
              ),
            ),
          ),
          // The label's centre 39 pt below the seat's (ref 83).
          const SizedBox(height: 2),
          _SeatLabel(label, shadow: framed),
        ],
      ),
    ),
  );
}

/// The host in the middle: the circle with the "Host" tag and the mic badge,
/// the name, and the live's points.
class _HostSeat extends StatelessWidget {
  const new({
    required this.circle,
    required this.name,
    required this.muted,
    required this.speaking,
    super.key,
    this.points,
    this.compact = false,
    this.onTap,
    this.tapLabel,
    this.cpMic = false,
  });

  /// D115: the host's couple has the Couple Mic Effect.
  final bool cpMic;

  final VoidCallback? onTap;
  final String? tapLabel;

  final Widget circle;
  final String name;
  final bool muted;
  final bool speaking;
  final String? points;

  /// D100 rows: the host as one of the tiles, a seat's size.
  final bool compact;

  static const width = 140.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.textStyles;
    final points = this.points;
    final tapLabel = this.tapLabel;
    return Semantics(
      button: onTap != null,
      label: tapLabel == null
          ? '$name · ${l10n.goLiveHostTag}'
          : '$name · ${l10n.goLiveHostTag} · $tapLabel',
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              // Compact: the circle lines up with the chairs of its row.
              height: compact ? AudioSeatRing.chair : null,
              child: Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    _speakingPicture(
                      speaking: speaking,
                      cpMic: cpMic,
                      size: compact ? _Seat.avatar : AudioSeatRing.hostSize,
                      picture: circle,
                    ),
                    Positioned(
                      bottom: compact ? -2 : 3,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xB3000000),
                          borderRadius: BorderRadius.circular(KRadius.pill),
                        ),
                        child: Text(
                          l10n.goLiveHostTag,
                          style: text.caption.copyWith(
                            fontSize: compact ? 7.5 : 8.5,
                            height: 1.3,
                            color: KAudioRoom.hostTag,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    if (muted)
                      const PositionedDirectional(
                        bottom: -6,
                        end: -12,
                        child: _MicOffBadge(size: 20),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(height: compact ? 4 : 5),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.caption.copyWith(
                fontSize: compact ? 11.5 : 12.5,
                height: 1.2,
                color: KAudioRoom.text,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (points != null) ...[
              const SizedBox(height: 2),
              _PointsPill(points),
            ],
          ],
        ),
      ),
    );
  }
}

/// The live's points under the host's name.
class _PointsPill extends StatelessWidget {
  const new(this.points);

  final String points;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(
      color: const Color(0x33000000),
      borderRadius: BorderRadius.circular(KRadius.pill),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const KPointsIcon(size: 11),
        const SizedBox(width: 3),
        Text(
          points,
          style: context.textStyles.caption.copyWith(
            fontSize: 10.5,
            height: 1.2,
            color: KAudioRoom.text,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _SeatLabel extends StatelessWidget {
  const new(this.text, {this.shadow = false});

  final String text;

  /// A name on top of CP ring art (D113): a soft dark pill behind it keeps
  /// it readable.
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: context.textStyles.caption.copyWith(
        fontSize: 11.5,
        height: 1.2,
        color: shadow ? KAudioRoom.text : KAudioRoom.textSoft,
        fontWeight: FontWeight.w500,
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: shadow
          ? DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0x99000000),
                borderRadius: BorderRadius.circular(KRadius.pill),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: label,
              ),
            )
          : label,
    );
  }
}

/// A seat's round picture of [size]: while [speaking], the glowing ring, or
/// for a couple with the Couple Mic Effect ([cpMic], D115) the CP mic effect.
Widget _speakingPicture({
  required bool speaking,
  required bool cpMic,
  required double size,
  required Widget picture,
}) {
  final clipped = ClipOval(
    child: SizedBox.square(dimension: size, child: picture),
  );
  if (speaking && cpMic) {
    // The effect stays in the seat's tile, from the crown space down to the
    // name's top (the large host in the circle: its own column).
    final area = size == AudioSeatRing.hostSize
        ? Rect.fromLTRB(
            -_HostSeat.width / 2 + 20,
            -size / 2 - 12,
            _HostSeat.width / 2 - 20,
            size / 2 + 5,
          )
        : const Rect.fromLTRB(
            -_Seat.width / 2,
            -AudioSeatRing.cpRingTop,
            _Seat.width / 2,
            AudioSeatRing.chair / 2 + 2,
          );
    return CpMicEffect(size: size, area: area, child: clipped);
  }
  return _Glow(on: speaking, child: clipped);
}

/// A speaker's glowing ring.
class _Glow extends StatelessWidget {
  const new({required this.on, required this.child});

  final bool on;
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      boxShadow: on
          ? const [
              BoxShadow(
                color: Color(0xCCFFFFFF),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ]
          : null,
    ),
    child: child,
  );
}

/// A muted mic, in a dark circle.
class _MicOffBadge extends StatelessWidget {
  const new({this.size = 16});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(
      color: Color(0x99000000),
      shape: BoxShape.circle,
    ),
    child: Icon(
      Icons.mic_off_rounded,
      size: size * 0.62,
      color: KAudioRoom.text,
    ),
  );
}
