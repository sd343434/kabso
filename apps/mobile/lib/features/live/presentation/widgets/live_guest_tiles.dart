import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D174 (owner «نعم بالطبع»: viewers join a solo live as guests, at most 3):
/// the guests of a solo live as small video tiles stacked at the reading end
/// over the chat, the host staying full screen. Each tile shows the guest's
/// camera ([video]; their picture while the camera is off), their name and
/// a muted mark when the host muted them; a tap opens their card ([onTap]:
/// the host can remove or mute them there).
class LiveGuestTiles extends StatelessWidget {
  const new({
    required this.seats,
    required this.video,
    required this.onTap,
    super.key,
  });

  final List<LiveSeat> seats;
  final Widget? Function(UserSummary user) video;
  final ValueChanged<UserSummary> onTap;

  /// A tile: 3:4, 76 × 101 pt; 6 pt apart.
  static const double width = 76;
  static const double height = width * 4 / 3;
  static const double gap = 6;

  static Key tileKey(int index) => Key('live.guestTile.$index');

  @override
  Widget build(BuildContext context) {
    final taken = [
      for (final seat in seats)
        if (seat.state == LiveSeatState.taken && seat.user != null) seat,
    ]..sort((a, b) => a.index.compareTo(b.index));
    if (taken.isEmpty) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final (i, seat) in taken.take(3).indexed) ...[
          if (i > 0) const SizedBox(height: gap),
          _Tile(seat: seat, video: video(seat.user!), onTap: onTap),
        ],
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const new({required this.seat, required this.video, required this.onTap});

  final LiveSeat seat;
  final Widget? video;
  final ValueChanged<UserSummary> onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final user = seat.user!;
    final scaler = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: KMetrics.overlayMaxTextScale);
    return Semantics(
      button: true,
      label: seat.mutedByHost
          ? '${user.displayName}, ${l10n.liveSeatMutedByHost}'
          : user.displayName,
      excludeSemantics: true,
      child: GestureDetector(
        key: LiveGuestTiles.tileKey(seat.index),
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(user),
        child: Container(
          width: LiveGuestTiles.width,
          height: LiveGuestTiles.height,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A24),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0x66FFFFFF)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              video ??
                  Center(
                    child: KAvatar(
                      name: user.displayName,
                      imageUrl: user.avatarUrl,
                      size: 44,
                    ),
                  ),
              // The name over a dark fade at the bottom.
              PositionedDirectional(
                start: 0,
                end: 0,
                bottom: 0,
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x00000000), Color(0xB3000000)],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(5, 8, 5, 4),
                    child: Row(
                      children: [
                        if (seat.mutedByHost) ...[
                          const Icon(
                            Icons.mic_off_rounded,
                            size: 12,
                            color: Color(0xFFFF6B6B),
                          ),
                          const SizedBox(width: 2),
                        ],
                        Expanded(
                          child: Text(
                            user.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textScaler: scaler,
                            style: context.textStyles.caption.copyWith(
                              fontSize: 10.5,
                              height: 1.2,
                              color: const Color(0xFFFFFFFF),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
