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

/// Audio seats (CP-011), after the owner's screen recording (D94): rows of
/// five round seats, 50 pt on a 76 pt pitch — the host first (their avatar
/// with the "Host" tag), then seats 1 … count-1: the guest's avatar (a mic
/// badge when muted), a locked seat, or an empty one with + and its number.
class AudioSeatRing extends StatelessWidget {
  const new({
    required this.count,
    required this.host,
    required this.hostName,
    super.key,
    this.hostMicOn,
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
  final List<LiveSeat> seats;
  final ValueChanged<int>? onSeat;

  /// Seat indexes speaking now (0 is the host): a glowing ring.
  final Set<int> speaking;

  static Key seatKey(int index) => Key('audioSeat.$index');

  static const columns = 5;

  @override
  Widget build(BuildContext context) {
    final cells = <Widget>[
      _SeatCircle(
        speaking: speaking.contains(0),
        circle: host,
        name: hostName,
        host: true,
        muted: hostMicOn == false,
      ),
      for (var i = 1; i < count; i++) _guest(i),
    ];
    return LayoutBuilder(
      builder: (context, box) {
        final width = box.maxWidth / columns;
        return Wrap(
          // 100 pt between rows in the recording.
          runSpacing: 30,
          children: [
            for (final cell in cells) SizedBox(width: width, child: cell),
          ],
        );
      },
    );
  }

  Widget _guest(int i) {
    final seat = seats.firstWhere(
      (s) => s.index == i,
      orElse: () => LiveSeat(index: i, state: LiveSeatState.empty, user: null),
    );
    final user = seat.user;
    final onTap = onSeat == null ? null : () => onSeat!(i);
    if (seat.state == LiveSeatState.taken && user != null) {
      return _SeatCircle(
        key: seatKey(i),
        speaking: speaking.contains(i),
        circle: KAvatar(
          name: user.displayName,
          imageUrl: user.avatarUrl,
          size: _SeatCircle.size,
        ),
        name: user.displayName,
        muted: seat.mutedByHost,
        onTap: onTap,
      );
    }
    final locked = seat.state == LiveSeatState.locked;
    return _SeatCircle(
      key: seatKey(i),
      speaking: false,
      circle: ColoredBox(
        color: KAudioRoom.emptySeat,
        child: Icon(
          locked ? Icons.lock_rounded : Icons.add_rounded,
          size: locked ? 18 : 22,
          color: KAudioRoom.textSoft,
        ),
      ),
      name: KFormat.grouped(i),
      onTap: onTap,
    );
  }
}

class _SeatCircle extends StatelessWidget {
  const new({
    required this.speaking,
    required this.circle,
    required this.name,
    super.key,
    this.host = false,
    this.muted = false,
    this.onTap,
  });

  final bool speaking;
  final Widget circle;
  final String name;
  final bool host;
  final bool muted;
  final VoidCallback? onTap;

  static const size = 50.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.textStyles;
    return Semantics(
      button: onTap != null,
      label: host ? '$name · ${l10n.goLiveHostTag}' : name,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: speaking
                        ? const [
                            BoxShadow(
                              color: Color(0xCCFFFFFF),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                  child: ClipOval(child: SizedBox.expand(child: circle)),
                ),
                if (host)
                  Positioned(
                    bottom: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
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
                    bottom: -1,
                    end: -1,
                    child: CircleAvatar(
                      radius: 8,
                      backgroundColor: KAudioRoom.badge,
                      child: Icon(
                        Icons.mic_off_rounded,
                        size: 10,
                        color: KAudioRoom.text,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.caption.copyWith(
                  fontSize: 11,
                  height: 1.1,
                  color: KAudioRoom.textSoft,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
