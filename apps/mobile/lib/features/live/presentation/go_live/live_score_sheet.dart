import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/presentation/go_live/go_live_parts.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// CP-012: the live's points and their parts (taps, support) from
/// `GET /live/rooms/{roomId}` `scoreParts`.
Future<void> showLiveScoreSheet(BuildContext context, String roomId) =>
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0x00000000),
      builder: (sheet) => LiveSheetFrame(
        title: sheet.l10n.liveScoreTitle,
        child: _ScoreParts(roomId: roomId),
      ),
    );

class _ScoreParts extends ConsumerStatefulWidget {
  const new({required this.roomId});

  final String roomId;

  static const totalKey = Key('liveScore.total');

  @override
  ConsumerState<_ScoreParts> createState() => _ScorePartsState();
}

class _ScorePartsState extends ConsumerState<_ScoreParts> {
  late final Future<LiveRoom> _room = ref
      .read(liveRepositoryProvider)
      .getRoom(widget.roomId);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.textStyles;
    const white = Color(0xFFFFFFFF);
    return FutureBuilder<LiveRoom>(
      future: _room,
      builder: (context, snap) {
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.all(KSpacing.xl),
            child: Text(
              failureMessage(l10n, toAppFailure(snap.error!)),
              textAlign: TextAlign.center,
              style: text.body.copyWith(color: white),
            ),
          );
        }
        final room = snap.data;
        if (room == null) {
          return const Padding(
            padding: EdgeInsets.all(KSpacing.xl),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final parts =
            room.scoreParts ??
            LiveScore(
              total: room.score,
              tapPoints: room.score,
              supportPoints: 0,
            );
        Widget row(IconData icon, String label, int value) => Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: KSpacing.xl,
            vertical: KSpacing.sm,
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: white),
              const SizedBox(width: KSpacing.md),
              Expanded(
                child: Text(label, style: text.body.copyWith(color: white)),
              ),
              Text(
                KFormat.grouped(value),
                style: text.bodyStrong.copyWith(color: white),
              ),
            ],
          ),
        );
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              key: _ScoreParts.totalKey,
              label: l10n.liveScore(parts.total, KFormat.grouped(parts.total)),
              excludeSemantics: true,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const KPointsIcon(size: 32),
                  const SizedBox(width: KSpacing.sm),
                  Text(
                    KFormat.grouped(parts.total),
                    style: text.headline.copyWith(
                      color: white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: KSpacing.md),
            row(Icons.touch_app_rounded, l10n.liveScoreTaps, parts.tapPoints),
            row(
              Icons.volunteer_activism_rounded,
              l10n.liveScoreSupport,
              parts.supportPoints,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                KSpacing.xl,
                KSpacing.sm,
                KSpacing.xl,
                0,
              ),
              child: Text(
                l10n.liveScoreHint,
                textAlign: TextAlign.center,
                style: text.caption.copyWith(
                  color: white.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
