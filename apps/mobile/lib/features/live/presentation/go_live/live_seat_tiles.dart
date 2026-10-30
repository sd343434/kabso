import 'dart:math' as math;

import 'package:flutter_svg/flutter_svg.dart';
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

/// Audio seats (CP-011): every room size in rows of five (owner,
/// 2026-10-26, D118: no circle any more) — the host the first tile, with
/// the "Host" tag and the live's points, then seats 1 … count-1 in reading
/// order (mirrored in Arabic). Each seat is an empty seat (a dark glass
/// circle with a light ring, readable on every room theme), a locked one,
/// or the guest's picture and name.
class AudioSeatRing extends StatelessWidget {
  const new({
    required this.count,
    required this.host,
    required this.hostName,
    super.key,
    this.hostMicOn,
    this.hostPoints,
    this.compact = false,
    this.seats = const [],
    this.onSeat,
    this.speaking = const {},
    this.micOff = const {},
    this.onHost,
    this.hostTapLabel,
    this.cpPairs = const [],
    this.overlay,
  });

  /// D138: what plays over tile `i`'s picture now (0 is the host), e.g. a
  /// seat emoji; null for nothing.
  final Widget? Function(int index)? overlay;

  /// Owner D111: CP partners' tiles (0 is the host, see [cpSeatPairs]). Two
  /// partners next to each other — consecutive tiles of a row — are joined
  /// by a band behind their pictures with an ornament between them;
  /// partners apart show nothing.
  final List<CpSeatPair> cpPairs;

  /// Seat indexes whose own mic is off (the guest muted themselves): the
  /// mic-off badge, as when the host mutes them.
  final Set<int> micOff;

  /// Tapping the host's picture (owner, 2026-10-26: the host mutes and
  /// unmutes themselves there, not with a bar button); [hostTapLabel] says
  /// what it does to screen readers.
  final VoidCallback? onHost;
  final String? hostTapLabel;

  /// Seats, the host's included (owner D103, D123: 5, 10, 15 or 20; a room
  /// started with 25 before D123 shows 25), in rows
  /// of [rowSize], the host's tile first (D118).
  final int count;

  /// The host's picture (their avatar, [picture] wide).
  final Widget host;
  final String hostName;

  /// The host's mic badge when muted; null hides it (unknown to viewers).
  final bool? hostMicOn;

  /// CP-012: the live's points under the host's name (shortened), or null.
  final String? hostPoints;

  /// D166: the cinema rows under the YouTube screen — the points pills are
  /// left out so every seat fits at a usable size.
  final bool compact;

  String? get _points => compact ? null : hostPoints;
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
      if (cpRowsAdjacent(p, count: count)) p,
  ];

  /// Seats per row (every room size, D118).
  static const rowSize = 5;

  /// Space between two rows of seats.
  static const rowGap = 10.0;

  /// A tile's picture box (ref 83, points at 430 pt).
  static const chair = 58.0;

  /// The diameter of a picture (the host's too) and of an empty seat.
  static const double picture = _Seat.avatar;

  /// D166: a tile's natural width (its picture is [picture] across).
  static const double tileWidth = _Seat.width;

  /// D166: the picture's top inside a tile (it is centred in the [chair]).
  static const double pictureTop = (chair - picture) / 2;

  /// D166: seat [index]'s tile alone (the host's for 0) — for the cinema,
  /// where each one sits on a seat drawn in the picture. No points pills
  /// ([compact]) and no CP ornament (the seats are apart there).
  Widget cinemaTile(int index) => SizedBox(
    width: _Seat.width,
    child: index == 0 ? _hostSeat() : _guest(index),
  );

  @override
  Widget build(BuildContext context) => _rows();

  Widget _hostSeat({bool ghost = false}) {
    final seat = _HostSeat(
      key: ghost ? null : seatKey(0),
      onTap: ghost ? null : onHost,
      tapLabel: hostTapLabel,
      circle: ghost ? const SizedBox.shrink() : host,
      name: hostName,
      muted: hostMicOn == false,
      speaking: !ghost && speaking.contains(0),
      points: _points,
      cpMic: !ghost && cpMicTiles.contains(0),
      overlay: ghost ? null : overlay?.call(0),
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
    final points = _points;
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

  /// D135 (owner: "the support the others received does not show under
  /// their mic"): under a taken seat, the points its person received in
  /// this live ([LiveSeat.points], the cherry, as under the host) in the
  /// space the host's points take; an empty or locked seat keeps that space
  /// empty so every row has the same height.
  Widget _guestExtra(BuildContext context, int i) {
    final seat = seats.where((s) => s.index == i).firstOrNull;
    if (seat == null ||
        seat.state != LiveSeatState.taken ||
        seat.user == null ||
        _points == null) {
      return _hostExtra();
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 4),
        _PointsPill(
          KFormat.compact(seat.points, context.l10n),
          key: seatPointsKey(i),
        ),
      ],
    );
  }

  /// D135: the points under seat [index] (1 … count-1).
  static Key seatPointsKey(int index) => Key('audioSeat.$index.points');

  /// Owner D100, D118: every size in rows of [rowSize] — the host is the
  /// first tile, then seats 1 … count-1, in reading order (start to end, so
  /// mirrored in Arabic). D123 (owner: avatar frames show on the seats and
  /// must look the same in every room): a seat has one size whatever the
  /// count — a 360 pt phone fits five 70 pt tiles at full size; only a
  /// narrower screen scales the tiles down (the same for every count). The
  /// rows never shrink to fit the height: the room's stage scrolls instead.
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
                ? _hostSeat(ghost: ghost)
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _guest(i, ghost: ghost),
                      if (ghost) _hostExtra() else _guestExtra(context, i),
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

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var first = 0; first < count; first += rowSize) ...[
            if (first > 0) const SizedBox(height: rowGap),
            row(first),
          ],
        ],
      );
    },
  );

  /// The ornament's width (owner D113: 62 pt; a narrow screen scales it
  /// with the tiles).
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
      // The host's "Host" tag under its picture.
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
          // host's is larger and further out).
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
      if (first == rowSize && _points != null)
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
              y - (chair / 2 + rowGap + (_points == null ? 2 : 19)) * scale,
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
        cpMic: cpMicTiles.contains(i),
        overlay: overlay?.call(i),
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

/// An empty or locked seat (owner, 2026-10-26, D118: empty seats vanished
/// on bright themes): a dark glass circle the size of a picture with a
/// light ring and a soft shadow, and Kabso's white seat outline (or a lock)
/// in it — readable on every room theme.
class _Chair extends StatelessWidget {
  const new({required this.locked});

  final bool locked;

  /// The glass: dark, a little lighter at the top.
  static const fillTop = Color(0x8C2A2140);
  static const fillBottom = Color(0xB3120D1E);

  /// The light ring.
  static const ring = Color(0xD9FFFFFF);
  static const shadow = Color(0x66000000);

  static const iconKey = Key('audioSeat.emptyIcon');

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: AudioSeatRing.chair,
    child: Center(
      child: Container(
        width: _Seat.avatar,
        height: _Seat.avatar,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [fillTop, fillBottom],
          ),
          border: Border.all(color: ring, width: 1.6),
          boxShadow: const [
            BoxShadow(color: shadow, blurRadius: 8, offset: Offset(0, 2)),
          ],
        ),
        child: locked
            ? const Icon(Icons.lock_rounded, size: 20, color: KAudioRoom.text)
            : SvgPicture.asset(
                'assets/live_room_icons/seat_outline.svg',
                key: iconKey,
                width: 22,
                colorFilter: const ColorFilter.mode(
                  KAudioRoom.text,
                  BlendMode.srcIn,
                ),
              ),
      ),
    ),
  );
}

/// A guest seat: the empty seat or the guest's picture, then the number or
/// the name under it.
class _Seat extends StatelessWidget {
  const new({
    required this.child,
    required this.label,
    required this.semantics,
    super.key,
    this.muted = false,
    this.speaking = false,
    this.onTap,
    this.cpMic = false,
    this.overlay,
  });

  /// D115: the seat's partner couple has the Couple Mic Effect.
  final bool cpMic;

  /// D138: over the picture, under the name.
  final Widget? overlay;

  final Widget child;
  final String label;
  final String semantics;
  final bool muted;
  final bool speaking;
  final VoidCallback? onTap;

  /// The seat's box (labels may be wider than the chair). D123: 70 pt, so
  /// five fit a 360 pt phone at full size (one seat size in every room).
  static const width = 70.0;
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
                  if (overlay case final overlay?)
                    Positioned.fill(child: overlay),
                ],
              ),
            ),
          ),
          // The label's centre 39 pt below the seat's (ref 83).
          const SizedBox(height: 2),
          _SeatLabel(label),
        ],
      ),
    ),
  );
}

/// The host's tile, the first of the rows: the picture with the "Host" tag
/// and the mic badge, the name, and the live's points.
class _HostSeat extends StatelessWidget {
  const new({
    required this.circle,
    required this.name,
    required this.muted,
    required this.speaking,
    super.key,
    this.points,
    this.onTap,
    this.tapLabel,
    this.cpMic = false,
    this.overlay,
  });

  /// D115: the host's couple has the Couple Mic Effect.
  final bool cpMic;

  /// D138: over the picture, under the name.
  final Widget? overlay;

  final VoidCallback? onTap;
  final String? tapLabel;

  final Widget circle;
  final String name;
  final bool muted;
  final bool speaking;
  final String? points;

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
              // The picture lines up with the seats of its row.
              height: AudioSeatRing.chair,
              child: Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    _speakingPicture(
                      speaking: speaking,
                      cpMic: cpMic,
                      size: _Seat.avatar,
                      picture: circle,
                    ),
                    Positioned(
                      bottom: -2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xB3000000),
                          borderRadius: BorderRadius.circular(KRadius.pill),
                        ),
                        child: Text(
                          l10n.goLiveHostTag,
                          style: text.caption.copyWith(
                            fontSize: 7.5,
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
                    if (overlay case final overlay?)
                      Positioned.fill(child: overlay),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.caption.copyWith(
                fontSize: 11.5,
                height: 1.2,
                color: KAudioRoom.text,
                fontWeight: FontWeight.w600,
                shadows: _SeatLabel.shadows,
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

/// The live's points under the host's name, and (D135) the points a
/// seated person received under theirs.
class _PointsPill extends StatelessWidget {
  const new(this.points, {super.key});

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
        const KCherryIcon(size: 11),
        const SizedBox(width: 3),
        // A long score shrinks to the tile's width (D118: the host is
        // always a 72 pt tile now).
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              points,
              maxLines: 1,
              style: context.textStyles.caption.copyWith(
                fontSize: 10.5,
                height: 1.2,
                color: KAudioRoom.text,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _SeatLabel extends StatelessWidget {
  const new(this.text);

  final String text;

  /// A soft dark shadow keeps a seat's number or name readable on every
  /// room theme, bright ones too (D118), and on CP ring art.
  static const shadows = [
    Shadow(color: Color(0xCC000000), blurRadius: 4),
    Shadow(color: Color(0x80000000), blurRadius: 1, offset: Offset(0, 0.5)),
  ];

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 2),
    child: Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: context.textStyles.caption.copyWith(
        fontSize: 11.5,
        height: 1.2,
        color: KAudioRoom.text,
        fontWeight: FontWeight.w600,
        shadows: shadows,
      ),
    ),
  );
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
    // name's top.
    const area = Rect.fromLTRB(
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
