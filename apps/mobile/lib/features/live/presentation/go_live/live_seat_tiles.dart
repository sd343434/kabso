import 'dart:math' as math;

import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_audio_room.dart';
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
  });

  /// Seats, the host's included (5, 9 or 13).
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
  Widget build(BuildContext context) => LayoutBuilder(
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
      for (var i = 1; i <= guests; i++) {
        final angle =
            -math.pi / 2 + math.pi / guests + (i - 1) * 2 * math.pi / guests;
        final dx = r * math.cos(angle) * (rtl ? -1 : 1);
        final dy = r * math.sin(angle);
        children.add(
          Positioned(
            left: cx + dx - _Seat.width / 2,
            top: cy + dy - chair / 2,
            width: _Seat.width,
            child: _guest(i),
          ),
        );
      }
      children.add(
        Positioned(
          left: cx - _HostSeat.width / 2,
          top: cy + hostDrop - hostSize / 2,
          width: _HostSeat.width,
          child: _HostSeat(
            circle: host,
            name: hostName,
            muted: hostMicOn == false,
            speaking: speaking.contains(0),
            points: hostPoints,
          ),
        ),
      );
      return SizedBox(
        height: height,
        child: Stack(clipBehavior: Clip.none, children: children),
      );
    },
  );

  Widget _guest(int i) {
    final seat = seats.firstWhere(
      (s) => s.index == i,
      orElse: () => LiveSeat(index: i, state: LiveSeatState.empty, user: null),
    );
    final user = seat.user;
    final onTap = onSeat == null ? null : () => onSeat!(i);
    if (seat.state == LiveSeatState.taken && user != null) {
      return _Seat(
        key: seatKey(i),
        label: user.displayName,
        semantics: user.displayName,
        muted: seat.mutedByHost,
        speaking: speaking.contains(i),
        onTap: onTap,
        child: KAvatar(
          name: user.displayName,
          imageUrl: user.avatarUrl,
          size: _Seat.avatar,
        ),
      );
    }
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
  });

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
                    _Glow(
                      on: speaking,
                      child: ClipOval(
                        child: SizedBox.square(dimension: avatar, child: child),
                      ),
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
          _SeatLabel(label),
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
    this.points,
  });

  final Widget circle;
  final String name;
  final bool muted;
  final bool speaking;
  final String? points;

  static const width = 140.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.textStyles;
    final points = this.points;
    return Semantics(
      label: '$name · ${l10n.goLiveHostTag}',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              _Glow(
                on: speaking,
                child: ClipOval(
                  child: SizedBox.square(
                    dimension: AudioSeatRing.hostSize,
                    child: circle,
                  ),
                ),
              ),
              Positioned(
                bottom: 3,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xB3000000),
                    borderRadius: BorderRadius.circular(KRadius.pill),
                  ),
                  child: Text(
                    l10n.goLiveHostTag,
                    style: text.caption.copyWith(
                      fontSize: 8.5,
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
          const SizedBox(height: 5),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.caption.copyWith(
              fontSize: 12.5,
              height: 1.2,
              color: KAudioRoom.text,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (points != null) ...[
            const SizedBox(height: 2),
            Container(
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
                    style: text.caption.copyWith(
                      fontSize: 10.5,
                      height: 1.2,
                      color: KAudioRoom.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SeatLabel extends StatelessWidget {
  const new(this.text);

  final String text;

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
        color: KAudioRoom.textSoft,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
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
