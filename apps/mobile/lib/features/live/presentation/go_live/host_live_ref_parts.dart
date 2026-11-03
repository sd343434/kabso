import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/data/live_media_engine.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_quality_sheet.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_viewer_parts.dart'
    show KViewerRoom;
import 'package:kabso_live/features/programs/application/programs_providers.dart';
import 'package:kabso_live/features/programs/data/programs_repository.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D253 (owner: «اجعل شاشة المضيف في تطبيقنا مثل التصميم ١٠٠٪», the
/// reference measured at 393 × 852 pt): the host's second row — the
/// targets at the reading start (`LiveHostTargetChip(plain: true)`), and at
/// the end the connection dot and the live's data («⌂▶ ›»).
class HostLiveInfoRow extends StatelessWidget {
  const new({required this.end, super.key, this.start});

  final Widget? start;
  final Widget end;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: KViewerRoom.chipHeight + 2,
    child: Row(
      children: [
        Expanded(
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: start ?? const SizedBox.shrink(),
          ),
        ),
        end,
      ],
    ),
  );
}

/// D253: the reference's «● ⌂▶ ›» — the house opens the host's
/// «Performance Status» card. D253b (owner: «اجعل نقطة بجانب المنزل بلون
/// احمر»): the dot is Kabso red; a weak or lost connection shows it amber /
/// grey (the card shows the connection itself).
class HostLiveStatus extends StatelessWidget {
  const new({required this.engine, required this.onData, super.key});

  final LiveMediaEngine engine;
  final VoidCallback onData;

  static const dotKey = Key('hostLive.connection');
  static const dataKey = Key('hostLive.data');

  /// Kabso red `#E50914`, 4.6 pt.
  static const Color good = Color(0xFFE50914);

  static Color colorOf(LiveConnectionQuality q) => switch (q) {
    LiveConnectionQuality.poor => liveConnectionColor(q),
    LiveConnectionQuality.lost => const Color(0xFF9A9BAA),
    _ => good,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListenableBuilder(
      listenable: engine.changes,
      builder: (context, _) {
        final q = engine.connectionQuality;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              label: liveConnectionText(l10n, q),
              child: Container(
                key: dotKey,
                width: 4.6,
                height: 4.6,
                decoration: BoxDecoration(
                  color: colorOf(q),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Semantics(
              button: true,
              label: l10n.liveToolDataCenter,
              excludeSemantics: true,
              child: GestureDetector(
                key: dataKey,
                behavior: HitTestBehavior.opaque,
                onTap: onData,
                child: const SizedBox(
                  height: KSizes.minTouchTarget,
                  child: Padding(
                    // Ref: the house 6.9 pt after the dot, the chevron
                    // 5.9 pt after the house, 15.3 pt from the edge.
                    padding: EdgeInsetsDirectional.only(start: 6.9, end: 7),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _HouseIcon(),
                        SizedBox(width: 5.9),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 8,
                          color: Color(0xFFFFFFFF),
                          shadows: KLiveColors.glassShadow,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The reference's house with a ▶ inside (12 pt), drawn as a line icon.
class _HouseIcon extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) =>
      const CustomPaint(size: Size(12, 12.4), painter: _HousePainter());
}

class _HousePainter extends CustomPainter {
  const new();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final line = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeJoin = StrokeJoin.round;
    final house = Path()
      ..moveTo(w * 0.5, h * 0.06)
      ..lineTo(w * 0.95, h * 0.42)
      ..lineTo(w * 0.95, h * 0.94)
      ..lineTo(w * 0.05, h * 0.94)
      ..lineTo(w * 0.05, h * 0.42)
      ..close();
    canvas.drawPath(house, line);
    final play = Path()
      ..moveTo(w * 0.4, h * 0.48)
      ..lineTo(w * 0.66, h * 0.65)
      ..lineTo(w * 0.4, h * 0.82)
      ..close();
    canvas.drawPath(
      play,
      Paint()
        ..color = const Color(0xFFFFFFFF)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_HousePainter oldDelegate) => false;
}

/// D253 (the reference's «Host Tasks» card, linked to Kabso's weekly host
/// tasks, D184): the host's band level, the first weekly host task not yet
/// completed (its name and progress) and the days left in the week. A tap
/// opens the Task Center; «–» hides it for this live. Nothing when the host
/// has no weekly host tasks (never a placeholder).
class HostTasksCard extends ConsumerStatefulWidget {
  const new({super.key, this.avatar, this.now});

  final ImageProvider? avatar;

  /// Tests fix the clock.
  final DateTime Function()? now;

  /// Ref: 82.6 × 114.6 pt.
  static const double width = 82.6;
  static const double height = 114.6;

  static const cardKey = Key('hostLive.tasks');
  static const hideKey = Key('hostLive.tasks.hide');

  /// The weekly host task the card follows: the first one not completed,
  /// else the last one.
  static ProgramTask? taskOf(MyTasks tasks) {
    final weekly = [
      for (final t in tasks.weekly)
        if (t.forHosts) t,
    ];
    if (weekly.isEmpty) return null;
    return weekly.firstWhere((t) => !t.completed, orElse: () => weekly.last);
  }

  /// Days left in the week (the week ends on Sunday night): 7 on a
  /// Monday, 1 on a Sunday.
  static int daysLeft(DateTime now) => 8 - now.weekday;

  @override
  ConsumerState<HostTasksCard> createState() => _HostTasksCardState();
}

class _HostTasksCardState extends ConsumerState<HostTasksCard> {
  bool _hidden = false;

  @override
  Widget build(BuildContext context) {
    if (_hidden) return const SizedBox.shrink();
    final tasks = ref.watch(myTasksProvider).value;
    final task = tasks == null ? null : HostTasksCard.taskOf(tasks);
    if (tasks == null || task == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final level = tasks.band?.level;
    final days = HostTasksCard.daysLeft((widget.now ?? DateTime.now)());
    final progress = task.progress.clamp(0, task.target);
    final share = task.target <= 0 ? 0.0 : progress / task.target;
    const white = Color(0xFFFFFFFF);
    TextStyle text(double size, {FontWeight weight = FontWeight.w600}) =>
        TextStyle(
          fontSize: size,
          height: 1,
          color: white,
          fontWeight: weight,
          fontFamily: context.textStyles.caption.fontFamily,
        );
    return Semantics(
      button: true,
      label: l10n.liveHostTasksLabel(
        task.name,
        KFormat.grouped(progress),
        KFormat.grouped(task.target),
        days,
      ),
      excludeSemantics: true,
      child: GestureDetector(
        key: HostTasksCard.cardKey,
        behavior: HitTestBehavior.opaque,
        onTap: () => context.push(AppRoutes.taskCenter),
        child: MediaQuery.withNoTextScaling(
          child: SizedBox(
            width: HostTasksCard.width,
            height: HostTasksCard.height,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // The card: Kabso's deep blue with a light centre (ref).
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0x80BFD9FF),
                        width: 0.8,
                      ),
                      gradient: const RadialGradient(
                        center: Alignment(0, -0.35),
                        radius: 0.95,
                        colors: [Color(0xFF3C86DA), Color(0xFF1B5CA6)],
                      ),
                    ),
                  ),
                ),
                // The title tab.
                Positioned(
                  top: 0,
                  left: 11,
                  right: 11,
                  height: 14,
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      color: Color(0xFF1A4E92),
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(5),
                      ),
                      border: Border(
                        left: BorderSide(color: Color(0x99BFD9FF), width: 0.6),
                        right: BorderSide(color: Color(0x99BFD9FF), width: 0.6),
                        bottom: BorderSide(
                          color: Color(0x99BFD9FF),
                          width: 0.6,
                        ),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        l10n.liveHostTasksTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text(7, weight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
                // «–»: hide for this live.
                PositionedDirectional(
                  top: -4,
                  end: -4,
                  child: Semantics(
                    button: true,
                    label: l10n.liveHostTasksHide,
                    excludeSemantics: true,
                    child: GestureDetector(
                      key: HostTasksCard.hideKey,
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _hidden = true),
                      child: SizedBox.square(
                        dimension: 24,
                        child: Center(
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2F6FBF),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xCCDCEBFF),
                                width: 0.7,
                              ),
                            ),
                            child: const Icon(
                              Icons.remove_rounded,
                              size: 8,
                              color: white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // The host's picture in a gold ring and the band level.
                Positioned(
                  top: 32.4,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      width: 21.8,
                      height: 21.8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF0B0B0B),
                        border: Border.all(
                          color: const Color(0xFFE9C46A),
                          width: 0.9,
                        ),
                        image: widget.avatar == null
                            ? null
                            : DecorationImage(
                                image: widget.avatar!,
                                fit: BoxFit.cover,
                              ),
                      ),
                    ),
                  ),
                ),
                if (level != null)
                  Positioned(
                    top: 51.8,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        height: 9.6,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C4F93),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          l10n.liveHostTasksLevel(level),
                          style: text(8),
                        ),
                      ),
                    ),
                  ),
                // The task (the reference's «… to next level» band).
                Positioned(
                  top: 65.6,
                  left: 7,
                  right: 7,
                  height: 9.4,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0x33FFFFFF),
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                    child: Center(
                      child: Text(
                        task.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text(5, weight: FontWeight.w500),
                      ),
                    ),
                  ),
                ),
                // Progress.
                Positioned(
                  top: 79.5,
                  left: 7.5,
                  right: 7.5,
                  height: 6.6,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3.3),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        const ColoredBox(color: Color(0xFF6FA8E8)),
                        FractionallySizedBox(
                          alignment: AlignmentDirectional.centerStart,
                          widthFactor: share,
                          child: const ColoredBox(color: Color(0xFFFFC64A)),
                        ),
                        Center(
                          child: Text(
                            '${KFormat.compact(progress, l10n)}/'
                            '${KFormat.compact(task.target, l10n)}',
                            textDirection: TextDirection.ltr,
                            style: text(6, weight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Days left in the week.
                Positioned(
                  top: 90.6,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.autorenew_rounded,
                        size: 7,
                        color: Color(0xFFE9C46A),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        l10n.liveHostTasksDays(days),
                        style: text(6.5, weight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
