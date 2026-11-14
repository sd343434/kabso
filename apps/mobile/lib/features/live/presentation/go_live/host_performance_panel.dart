import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/data/live_media_engine.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_room_stats.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_quality_sheet.dart';
import 'package:kabso_live/features/live/presentation/widgets/host_target_sheet.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// One reading of the live's numbers (the chart's points).
typedef HostPerformanceSample = ({
  DateTime at,
  int cherries,
  int givers,
  int followers,
});

/// D253b: the readings of this live taken while the panel was open (kept
/// for the live; never sent anywhere).
final NotifierProviderFamily<
  HostPerformanceSamples,
  List<HostPerformanceSample>,
  String
>
hostPerformanceSamplesProvider =
    NotifierProvider.family<
      HostPerformanceSamples,
      List<HostPerformanceSample>,
      String
    >(HostPerformanceSamples.new);

class HostPerformanceSamples extends Notifier<List<HostPerformanceSample>> {
  new(this.roomId);

  final String roomId;

  /// At most this many points (one a minute: two hours).
  static const int cap = 120;

  @override
  List<HostPerformanceSample> build() => const [];

  /// Adds [s] read at [at]; a reading within the same minute replaces the
  /// last point.
  void add(LiveRoomStats s, DateTime at) {
    final point = (
      at: at,
      // D259: the real cherries (the score is points).
      cherries: s.hostCherries,
      givers: s.giftGivers,
      followers: s.newFollowers,
    );
    final list = [...state];
    if (list.isNotEmpty &&
        list.last.at.difference(at).inMinutes.abs() < 1 &&
        list.last.at.minute == at.minute) {
      list[list.length - 1] = point;
    } else {
      list.add(point);
    }
    state = list.length > cap ? list.sublist(list.length - cap) : list;
  }
}

/// D253b (owner: «عند ضغط على اشارة المنزل … يظهر هذا البوكس», the
/// reference's «Performance Status» card, measured at 393 × 852 pt): the
/// host's live numbers in a floating dark card — the connection, six
/// numbers (time, unique viewers, peak, new followers, cherries › the gift
/// stats, gift-givers) and a chart of cherries / gift-givers / new
/// followers over this live. Nothing is invented: the readings are
/// `GET /live/rooms/{id}/stats`, every 15 s while open.
Future<void> showHostPerformancePanel(
  BuildContext context, {
  required String roomId,
  required LiveMediaEngine engine,
}) {
  final container = ProviderScope.containerOf(context);
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: context.l10n.liveClose,
    barrierColor: const Color(0x00000000),
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (_, _, _) => UncontrolledProviderScope(
      container: container,
      child: HostPerformancePanel(roomId: roomId, engine: engine),
    ),
    transitionBuilder: (_, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

/// Measured on the reference (pt at 393 wide).
abstract final class KPerformance {
  static const double side = 15;
  static const double height = 464.9;
  static const double radius = 20;
  static const Color card = Color(0xF2141414);
  static const Color line = Color(0xFF3C3C3C);
  static const Color soft = Color(0xFF9C9C9C);
  static const Color tabOff = Color(0xFF888888);
  static const Color chart = Color(0xFF00D8C8);

  /// The card's top: the reference's 11.3 pt into a tall (notched) inset;
  /// a short status bar (Android) is never covered.
  static double top(double inset) => inset >= 44 ? inset - 11.3 : inset + 6;
}

class HostPerformancePanel extends ConsumerStatefulWidget {
  const new({required this.roomId, required this.engine, super.key});

  final String roomId;
  final LiveMediaEngine engine;

  /// The clock (tests fix it).
  @visibleForTesting
  static DateTime Function() now = DateTime.now;

  static const panelKey = Key('performance.panel');
  static const closeKey = Key('performance.close');
  static const helpKey = Key('performance.help');
  static const cherriesKey = Key('performance.cherries');
  static Key valueKey(String id) => Key('performance.value.$id');
  static Key tabKey(int i) => Key('performance.tab.$i');

  @override
  ConsumerState<HostPerformancePanel> createState() => _State();
}

class _State extends ConsumerState<HostPerformancePanel> {
  LiveRoomStats? _stats;
  DateTime _readAt = HostPerformancePanel.now();
  Timer? _refresh;
  Timer? _clock;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    _refresh = Timer.periodic(
      const Duration(seconds: 15),
      (_) => unawaited(_load()),
    );
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _stats != null) setState(() {});
    });
  }

  @override
  void dispose() {
    _refresh?.cancel();
    _clock?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final s = await ref.read(liveRepositoryProvider).roomStats(widget.roomId);
      if (!mounted) return;
      final now = HostPerformancePanel.now();
      ref
          .read(hostPerformanceSamplesProvider(widget.roomId).notifier)
          .add(s, now);
      setState(() {
        _stats = s;
        _readAt = now;
      });
    } on Object {
      // The last numbers stay; the next reading tries again.
    }
  }

  static String _hms(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inHours)}:${two(d.inMinutes % 60)}:'
        '${two(d.inSeconds % 60)}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final inset = MediaQuery.paddingOf(context).top;
    final s = _stats;
    final elapsed = s == null
        ? Duration.zero
        : s.ended
        ? s.duration
        : s.duration + HostPerformancePanel.now().difference(_readAt);
    final samples = ref.watch(hostPerformanceSamplesProvider(widget.roomId));
    final tabs = [
      l10n.liveDataNowCherries,
      l10n.liveDataNowGivers,
      l10n.liveDataNowFans,
    ];
    final white = context.textStyles.body.copyWith(
      color: const Color(0xFFFFFFFF),
      height: 1.2,
    );
    Widget cell(String id, String value, String label, {VoidCallback? onTap}) {
      final body = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            textDirection: TextDirection.ltr,
            style: white.copyWith(
              fontSize: 17,
              fontWeight: FontWeight.w500,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            onTap == null ? label : '$label›',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: white.copyWith(fontSize: 12, color: KPerformance.soft),
          ),
        ],
      );
      return Expanded(
        child: Semantics(
          key: HostPerformancePanel.valueKey(id),
          label: '$label: $value',
          button: onTap != null,
          excludeSemantics: true,
          child: onTap == null
              ? body
              : GestureDetector(
                  key: HostPerformancePanel.cherriesKey,
                  behavior: HitTestBehavior.opaque,
                  onTap: onTap,
                  child: body,
                ),
        ),
      );
    }

    final viewers = s?.viewers;
    return Stack(
      children: [
        PositionedDirectional(
          start: KPerformance.side,
          end: KPerformance.side,
          top: KPerformance.top(inset),
          height: KPerformance.height,
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: KMetrics.overlayMaxTextScale,
            child: Material(
              key: HostPerformancePanel.panelKey,
              color: KPerformance.card,
              borderRadius: BorderRadius.circular(KPerformance.radius),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header: the title, the connection, ✕.
                  SizedBox(
                    height: 38,
                    child: Row(
                      children: [
                        const SizedBox(width: 15),
                        Expanded(
                          child: Text(
                            l10n.livePerformanceTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: white.copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        ListenableBuilder(
                          listenable: widget.engine.changes,
                          builder: (context, _) {
                            final q = widget.engine.connectionQuality;
                            return Semantics(
                              label: liveConnectionText(l10n, q),
                              child: Container(
                                width: 41,
                                height: 17,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF181818),
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                    color: const Color(0xFF2C2C2C),
                                    width: 0.6,
                                  ),
                                ),
                                child: Icon(
                                  Icons.wifi_rounded,
                                  size: 12,
                                  color:
                                      q == LiveConnectionQuality.good ||
                                          q == LiveConnectionQuality.excellent
                                      ? KPerformance.chart
                                      : liveConnectionColor(q),
                                ),
                              ),
                            );
                          },
                        ),
                        Semantics(
                          button: true,
                          label: l10n.liveClose,
                          excludeSemantics: true,
                          child: GestureDetector(
                            key: HostPerformancePanel.closeKey,
                            behavior: HitTestBehavior.opaque,
                            onTap: () => Navigator.of(context).maybePop(),
                            child: const SizedBox(
                              width: 44,
                              height: 38,
                              child: Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: Color(0xFFFFFFFF),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(
                    height: 0.8,
                    thickness: 0.8,
                    color: KPerformance.line,
                  ),
                  // «Real-time data» and its help.
                  SizedBox(
                    height: 56,
                    child: Row(
                      children: [
                        const SizedBox(width: 17),
                        Expanded(
                          child: Text(
                            l10n.livePerformanceRealtime,
                            style: white.copyWith(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Semantics(
                          button: true,
                          label: l10n.livePerformanceHelpLabel,
                          excludeSemantics: true,
                          child: GestureDetector(
                            key: HostPerformancePanel.helpKey,
                            behavior: HitTestBehavior.opaque,
                            onTap: () => unawaited(
                              showKLiveInfo(
                                context,
                                title: l10n.livePerformanceRealtime,
                                message: l10n.livePerformanceHelp,
                              ),
                            ),
                            child: const SizedBox(
                              width: 44,
                              height: 44,
                              child: Icon(
                                Icons.help_outline_rounded,
                                size: 19,
                                color: Color(0xFFFFFFFF),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            cell(
                              'time',
                              _hms(elapsed),
                              l10n.liveDataNowLiveTime,
                            ),
                            cell(
                              'viewers',
                              KFormat.grouped(viewers?.unique ?? 0),
                              l10n.liveDataNowViewers,
                            ),
                            cell(
                              'peak',
                              KFormat.grouped(viewers?.peak ?? 0),
                              l10n.livePerformancePeak,
                            ),
                          ],
                        ),
                        const SizedBox(height: 23),
                        Row(
                          children: [
                            cell(
                              'fans',
                              KFormat.grouped(s?.newFollowers ?? 0),
                              l10n.liveDataNowFans,
                            ),
                            cell(
                              'cherries',
                              KFormat.grouped(s?.hostCherries ?? 0),
                              l10n.liveDataNowCherries,
                              onTap: () =>
                                  unawaited(showHostGiftStats(context)),
                            ),
                            cell(
                              'givers',
                              KFormat.grouped(s?.giftGivers ?? 0),
                              l10n.liveDataNowGivers,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Divider(
                      height: 0.8,
                      thickness: 0.8,
                      color: KPerformance.line,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // The chart's three tabs.
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: 17,
                      end: 12,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final (i, t) in tabs.indexed)
                          Expanded(
                            flex: i == 0 ? 9 : 13,
                            child: Semantics(
                              selected: i == _tab,
                              button: true,
                              child: GestureDetector(
                                key: HostPerformancePanel.tabKey(i),
                                behavior: HitTestBehavior.opaque,
                                onTap: () => setState(() => _tab = i),
                                child: Text(
                                  t,
                                  maxLines: 2,
                                  style: white.copyWith(
                                    fontSize: 13.5,
                                    height: 1.15,
                                    fontWeight: FontWeight.w500,
                                    color: i == _tab
                                        ? const Color(0xFFFFFFFF)
                                        : KPerformance.tabOff,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(
                        start: 12,
                        end: 23,
                        bottom: 20,
                      ),
                      child: _Chart(
                        points: [
                          for (final p in samples)
                            (
                              at: p.at,
                              value: switch (_tab) {
                                0 => p.cherries,
                                1 => p.givers,
                                _ => p.followers,
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The reference's chart: six dashed lines (0 … the top), the values as a
/// teal line with ringed points, the first and last times under it.
class _Chart extends StatelessWidget {
  const new({required this.points});

  final List<({DateTime at, int value})> points;

  /// The chart's top: 1 with nothing yet, else a round number at or above
  /// the largest value (the lines are its fifths).
  static double topOf(int max) {
    if (max <= 1) return 1;
    final step = math.pow(10, (math.log(max / 5) / math.ln10).floor());
    for (final m in [1, 2, 2.5, 5, 10]) {
      final t = m * step * 5;
      if (t >= max) return t.toDouble();
    }
    return (max * 1.2).ceilToDouble();
  }

  @override
  Widget build(BuildContext context) {
    final style = context.textStyles.caption.copyWith(
      fontSize: 9,
      height: 1,
      color: const Color(0xFFFFFFFF),
    );
    final maxValue = points.fold<int>(0, (m, p) => math.max(m, p.value));
    final top = topOf(maxValue);
    String label(double v) {
      if (top <= 1) {
        return v == 0 || v == 1 ? v.toInt().toString() : v.toStringAsFixed(1);
      }
      return KFormat.compact(v.round(), context.l10n);
    }

    String time(DateTime t) =>
        '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}';
    return Directionality(
      textDirection: TextDirection.ltr,
      child: LayoutBuilder(
        builder: (context, box) {
          const axis = 40.0;
          const xLabel = 16.0;
          final h = box.maxHeight - xLabel;
          final w = box.maxWidth - axis;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              for (var i = 0; i <= 5; i++)
                Positioned(
                  left: 0,
                  width: axis - 8,
                  top: h * (1 - i / 5) - 5,
                  child: Text(
                    label(top * i / 5),
                    textAlign: TextAlign.end,
                    style: style,
                  ),
                ),
              Positioned(
                left: axis,
                top: 0,
                width: w,
                height: h,
                child: CustomPaint(
                  painter: _ChartPainter(
                    values: [for (final p in points) p.value / top],
                  ),
                ),
              ),
              if (points.isNotEmpty) ...[
                Positioned(
                  left: axis,
                  width: w,
                  top: h + 6,
                  child: Row(
                    mainAxisAlignment: points.length == 1
                        ? MainAxisAlignment.center
                        : MainAxisAlignment.spaceBetween,
                    children: [
                      Text(time(points.first.at), style: style),
                      if (points.length > 1)
                        Text(time(points.last.at), style: style),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  const new({required this.values});

  /// Each value as a share of the chart's top (0 … 1).
  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    final dash = Paint()
      ..color = KPerformance.line
      ..strokeWidth = 0.6;
    for (var i = 0; i <= 5; i++) {
      final y = size.height * i / 5;
      for (double x = 0; x < size.width; x += 6) {
        canvas.drawLine(
          Offset(x, y),
          Offset(math.min(x + 3, size.width), y),
          dash,
        );
      }
    }
    if (values.isEmpty) return;
    Offset at(int i) => Offset(
      values.length == 1
          ? size.width / 2
          : size.width * i / (values.length - 1),
      size.height * (1 - values[i].clamp(0, 1)),
    );
    final line = Paint()
      ..color = KPerformance.chart
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    if (values.length > 1) {
      final path = Path()..moveTo(at(0).dx, at(0).dy);
      for (var i = 1; i < values.length; i++) {
        path.lineTo(at(i).dx, at(i).dy);
      }
      canvas.drawPath(path, line);
    }
    final fill = Paint()..color = KPerformance.card;
    for (var i = 0; i < values.length; i++) {
      canvas
        ..drawCircle(at(i), 2.6, fill)
        ..drawCircle(at(i), 2.6, line);
    }
  }

  @override
  bool shouldRepaint(_ChartPainter oldDelegate) =>
      oldDelegate.values.length != values.length ||
      !Iterable<int>.generate(values.length)
          .every((i) => oldDelegate.values[i] == values[i]);
}
