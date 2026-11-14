import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_room_stats.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_data_center_sheet.dart';
import 'package:kabso_live/features/live/presentation/widgets/charm_level_badge.dart';
import 'package:kabso_live/features/owner_profile/data/owner_profile_repository.dart'
    show isKabsoOwnerProvider;
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D199 (owner's reference 274, «طبق تصميم 100%»): the host's data of the
/// live running now, on a black page — «مركز المبدعين» (D172) and ✕ at the
/// top, the title, the «هذا البث» card with five real numbers from
/// `GET /live/rooms/{roomId}/stats` (live time, **unique** viewers with the
/// peak under them, new cherries — D259: the host's real cherries,
/// `score.hostCherries` (the score is points) —, gift-givers,
/// new followers), the row to D154d's data center of earlier periods, and
/// the host's charm level. The reference's «Live Quality» score and «Skill
/// Improvement» tutorials have no Kabso content: they are left out.
Future<void> showLiveDataNow(
  BuildContext context, {
  required String? roomId,
  required int? level,
}) {
  // The page's route lives in the app's navigator: it keeps the live's
  // provider container.
  final container = ProviderScope.containerOf(context);
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => UncontrolledProviderScope(
        container: container,
        child: LiveDataNowPage(roomId: roomId, level: level),
      ),
    ),
  );
}

/// Measured on ref 274 (393 lp wide; 1.878 px per lp).
abstract final class LiveDataNowMetrics {
  static const side = 24.0;
  static const pillTop = 52.2;
  static const pillHeight = 25.6;
  static const pillEnd = 52.2;
  static const titleTop = 80.9;
  static const cardTop = 133.7;
  static const cardHeight = 133.1;
  static const cardRadius = 11.7;
  static const rowHeight = 33.0;
  static const card = Color(0xFF191919);
  static const row = Color(0xFF262626);
  static const soft = Color(0xFF8E8E93);
}

class LiveDataNowPage extends ConsumerStatefulWidget {
  const new({required this.roomId, required this.level, super.key});

  /// The live running now (null: not live yet — the page says so).
  final String? roomId;

  /// The host's charm level (`GET /levels/me`), or null while unknown.
  final int? level;

  static const pageKey = Key('liveDataNow.page');
  static const creatorKey = Key('liveDataNow.creator');
  static const closeKey = Key('liveDataNow.close');
  static const historyKey = Key('liveDataNow.history');
  static const levelKey = Key('liveDataNow.level');
  static Key valueKey(String id) => Key('liveDataNow.value.$id');

  @override
  ConsumerState<LiveDataNowPage> createState() => _LiveDataNowPageState();
}

class _LiveDataNowPageState extends ConsumerState<LiveDataNowPage> {
  LiveRoomStats? _stats;
  Object? _error;
  Timer? _refresh;
  Timer? _clock;
  DateTime _readAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.roomId != null) {
      unawaited(_load());
      // The numbers every 15 s; the live time every second in between.
      _refresh = Timer.periodic(
        const Duration(seconds: 15),
        (_) => unawaited(_load()),
      );
      _clock = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted && _stats != null) setState(() {});
      });
    }
  }

  Future<void> _load() async {
    try {
      final s = await ref
          .read(liveRepositoryProvider)
          .roomStats(widget.roomId!);
      if (mounted) {
        setState(() {
          _stats = s;
          _error = null;
          _readAt = DateTime.now();
        });
      }
    } on Object catch (e) {
      if (mounted && _stats == null) setState(() => _error = e);
    }
  }

  @override
  void dispose() {
    _refresh?.cancel();
    _clock?.cancel();
    super.dispose();
  }

  String _hms(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = two(d.inHours);
    return '$h:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final top = MediaQuery.paddingOf(context).top;
    // The reference's status bar is 59 lp; its pill starts 6.8 lp above.
    // Without a tall inset (Android, 360×800) the pill keeps 8 lp clear.
    final shift = math.max(top - 59, 8 - LiveDataNowMetrics.pillTop);
    const white = Color(0xFFFFFFFF);
    return Scaffold(
      key: LiveDataNowPage.pageKey,
      backgroundColor: const Color(0xFF000000),
      body: Stack(
        children: [
          PositionedDirectional(
            top: LiveDataNowMetrics.pillTop + shift,
            end: LiveDataNowMetrics.pillEnd,
            child: _CreatorPill(
              key: LiveDataNowPage.creatorKey,
              label: l10n.liveDataCreatorCenter,
              onTap: () => unawaited(context.push(AppRoutes.creatorCenter)),
            ),
          ),
          PositionedDirectional(
            top: LiveDataNowMetrics.pillTop + shift - 5.6,
            end: 6,
            child: IconButton(
              key: LiveDataNowPage.closeKey,
              tooltip: MaterialLocalizations.of(context).closeButtonLabel,
              icon: const Icon(Icons.close_rounded, color: white, size: 26),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
          Positioned.fill(
            top: LiveDataNowMetrics.titleTop + shift - 4,
            child: ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: LiveDataNowMetrics.side,
              ),
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    l10n.liveDataPageTitle,
                    style: t.title.copyWith(
                      fontSize: 21,
                      height: 1.2,
                      fontWeight: FontWeight.w800,
                      color: white,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.roomId == null
                      ? l10n.liveDataNotLive
                      : l10n.liveDataHint,
                  style: t.body.copyWith(
                    fontSize: 13,
                    height: 1.25,
                    color: LiveDataNowMetrics.soft,
                  ),
                ),
                const SizedBox(height: 17),
                _card(context),
                const SizedBox(height: 10.6),
                _row(
                  key: LiveDataNowPage.historyKey,
                  icon: const Icon(
                    Icons.insights_outlined,
                    size: 17,
                    color: Color(0xFFFFD36E),
                  ),
                  label: l10n.liveDataHistory,
                  chevron: true,
                  onTap: () => unawaited(showLiveDataCenter(context)),
                ),
                // D361 (§10.156; owner: «المؤسس ليس له ليفيل»): no level
                // row for the founder (never «Lv 0»).
                if (!ref.watch(isKabsoOwnerProvider)) ...[
                  const SizedBox(height: 10.6),
                  _row(
                    key: LiveDataNowPage.levelKey,
                    icon: CharmLevelBadge(level: widget.level ?? 0, height: 16),
                    label: l10n.liveDataLevel('${widget.level ?? 0}'),
                    help: l10n.liveDataLevelHelp,
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final s = _stats;
    Widget content;
    if (widget.roomId == null) {
      content = const SizedBox(height: 72);
    } else if (s == null) {
      content = ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 96),
        child: Center(
          child: _error == null
              ? const CircularProgressIndicator()
              : KErrorState(
                  title: l10n.liveDataLoadError,
                  message: failureMessage(l10n, toAppFailure(_error!)),
                  retryLabel: l10n.actionRetry,
                  onRetry: () => unawaited(_load()),
                  compact: true,
                ),
        ),
      );
    } else {
      final elapsed = s.ended
          ? s.duration
          : s.duration + DateTime.now().difference(_readAt);
      final viewers = s.viewers;
      Widget cell(String id, String value, String label, {String? hint}) =>
          Semantics(
            key: LiveDataNowPage.valueKey(id),
            label: '$label: $value${hint == null ? '' : '، $hint'}',
            excludeSemantics: true,
            child: Column(
              children: [
                Text(
                  value,
                  textDirection: TextDirection.ltr,
                  style: t.bodyStrong.copyWith(
                    fontSize: 15,
                    height: 1.2,
                    fontWeight: FontWeight.w500,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: const Color(0xFFFFFFFF),
                  ),
                ),
                const SizedBox(height: 4.5),
                Text(
                  label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: t.caption.copyWith(
                    fontSize: 12,
                    height: 1.2,
                    color: LiveDataNowMetrics.soft,
                  ),
                ),
                if (hint != null)
                  Text(
                    hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.caption.copyWith(
                      fontSize: 9.5,
                      height: 1.2,
                      color: const Color(0xFF6E6E73),
                    ),
                  ),
              ],
            ),
          );
      content = Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: cell('time', _hms(elapsed), l10n.liveDataNowLiveTime),
              ),
              Expanded(
                child: cell(
                  'viewers',
                  KFormat.grouped(viewers?.unique ?? 0),
                  l10n.liveDataNowViewers,
                  hint: viewers == null
                      ? null
                      : l10n.liveDataNowViewersHint(
                          KFormat.grouped(viewers.peak),
                        ),
                ),
              ),
              Expanded(
                child: cell(
                  'cherries',
                  KFormat.grouped(s.hostCherries),
                  l10n.liveDataNowCherries,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: cell(
                  'givers',
                  KFormat.grouped(s.giftGivers),
                  l10n.liveDataNowGivers,
                ),
              ),
              Expanded(
                child: cell(
                  'fans',
                  KFormat.grouped(s.newFollowers),
                  l10n.liveDataNowFans,
                ),
              ),
              const Spacer(),
            ],
          ),
        ],
      );
    }
    return Container(
      constraints: const BoxConstraints(
        minHeight: LiveDataNowMetrics.cardHeight,
      ),
      padding: const EdgeInsets.fromLTRB(13.8, 9, 13.8, 14),
      decoration: BoxDecoration(
        color: LiveDataNowMetrics.card,
        borderRadius: BorderRadius.circular(LiveDataNowMetrics.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.liveDataPageTitle,
            style: t.bodyStrong.copyWith(
              fontSize: 13.5,
              height: 1.4,
              fontWeight: FontWeight.w800,
              color: const Color(0xFFFFFFFF),
            ),
          ),
          const SizedBox(height: 17),
          content,
        ],
      ),
    );
  }

  Widget _row({
    required Key key,
    required Widget icon,
    required String label,
    String? help,
    bool chevron = false,
    VoidCallback? onTap,
  }) => Material(
    key: key,
    color: LiveDataNowMetrics.row,
    borderRadius: BorderRadius.circular(LiveDataNowMetrics.cardRadius),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: SizedBox(
        height: LiveDataNowMetrics.rowHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              icon,
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textStyles.bodyStrong.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFFFFFFF),
                  ),
                ),
              ),
              if (help != null)
                Tooltip(
                  message: help,
                  triggerMode: TooltipTriggerMode.tap,
                  child: const Padding(
                    padding: EdgeInsetsDirectional.only(start: 6),
                    child: Icon(
                      Icons.help_outline_rounded,
                      size: 15,
                      color: LiveDataNowMetrics.soft,
                    ),
                  ),
                ),
              if (chevron)
                Icon(
                  Directionality.of(context) == TextDirection.rtl
                      ? Icons.chevron_left_rounded
                      : Icons.chevron_right_rounded,
                  size: 20,
                  color: LiveDataNowMetrics.soft,
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _CreatorPill extends StatelessWidget {
  const new({required this.label, required this.onTap, super.key});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        height: LiveDataNowMetrics.pillHeight,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(KRadius.pill),
          border: Border.all(color: const Color(0xFF5A5A5E)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.support_agent_outlined,
              size: 15,
              color: Color(0xFFFFFFFF),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              textScaler: MediaQuery.textScalerOf(context)
                  .clamp(maxScaleFactor: 1.2),
              style: context.textStyles.bodyStrong.copyWith(
                fontSize: 13.5,
                height: 1.1,
                fontWeight: FontWeight.w800,
                color: const Color(0xFFFFFFFF),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
