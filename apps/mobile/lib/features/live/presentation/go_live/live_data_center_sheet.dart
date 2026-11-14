import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/data/live_data_center_repository.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D154d («مركز البيانات», CONVENTIONS §10.36): the host's own data center —
/// a period (يوم / أسبوع / شهر / سنة), the totals (lives, live time, gifts'
/// value, earnings — display only —, new followers, viewers), a bar chart
/// of live time per hour, day or month, and the best hours (lives by
/// weekday and hour of the start, darker = more viewers). Ended lives only;
/// the live running now counts once it ends (said under the title).
Future<void> showLiveDataCenter(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1F1D24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(19)),
      ),
      builder: (_) => const LiveDataCenterSheet(),
    );

abstract final class _Ink {
  static const text = Color(0xFFFFFFFF);
  static const soft = Color(0xFFB9B6C2);
  static const tile = Color(0x14FFFFFF);
  static const accent = Color(0xFFFFD36E);
  static const bar = Color(0xFF7FE3C8);
}

class LiveDataCenterSheet extends ConsumerStatefulWidget {
  const new({super.key});

  static const sheetKey = Key('dataCenter.sheet');
  static const chartKey = Key('dataCenter.chart');
  static const heatmapKey = Key('dataCenter.heatmap');
  static const emptyKey = Key('dataCenter.empty');
  static Key periodKey(LiveStatsPeriod p) => Key('dataCenter.period.${p.wire}');
  static Key totalKey(String id) => Key('dataCenter.total.$id');

  @override
  ConsumerState<LiveDataCenterSheet> createState() =>
      _LiveDataCenterSheetState();
}

class _LiveDataCenterSheetState extends ConsumerState<LiveDataCenterSheet> {
  LiveStatsPeriod _period = LiveStatsPeriod.week;
  MyLiveStats? _stats;
  Object? _error;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() => _error = null);
    try {
      final stats = await ref
          .read(liveDataCenterRepositoryProvider)
          .mine(_period);
      if (mounted && request == _request) setState(() => _stats = stats);
    } on Object catch (e) {
      if (mounted && request == _request) setState(() => _error = e);
    }
  }

  String _duration(AppLocalizations l10n, int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    return l10n.liveDataDuration(h, m);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final stats = _stats?.period == _period ? _stats : null;
    Widget body;
    if (stats == null) {
      body = Padding(
        padding: const EdgeInsets.symmetric(vertical: KSpacing.xl),
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
      final totals = [
        ('lives', l10n.liveDataLives, KFormat.grouped(stats.lives)),
        ('time', l10n.liveDataLiveTime, _duration(l10n, stats.liveSeconds)),
        ('gifts', l10n.liveStatsGiftCoins, KFormat.grouped(stats.giftCoins)),
        (
          'earnings',
          l10n.liveStatsEarnings,
          KFormat.grouped(stats.earningsCoins),
        ),
        (
          'followers',
          l10n.liveDataNewFollowers,
          KFormat.grouped(stats.newFollowers),
        ),
        ('viewers', l10n.liveDataViewers, KFormat.grouped(stats.uniqueViewers)),
      ];
      body = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: KSpacing.sm,
            crossAxisSpacing: KSpacing.sm,
            childAspectRatio: 1.35,
            children: [
              for (final (id, label, value) in totals)
                Semantics(
                  key: LiveDataCenterSheet.totalKey(id),
                  container: true,
                  label: '$label: $value',
                  excludeSemantics: true,
                  child: Container(
                    padding: const EdgeInsets.all(KSpacing.sm),
                    decoration: BoxDecoration(
                      color: _Ink.tile,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            value,
                            maxLines: 1,
                            style: t.bodyStrong.copyWith(
                              color: _Ink.text,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          label,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: t.caption.copyWith(
                            color: _Ink.soft,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: KSpacing.md),
          Text(
            l10n.liveDataChartTitle,
            style: t.bodyStrong.copyWith(color: _Ink.text),
          ),
          const SizedBox(height: KSpacing.xs),
          if (stats.lives == 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: KSpacing.md),
              child: Text(
                l10n.liveDataEmpty,
                key: LiveDataCenterSheet.emptyKey,
                textAlign: TextAlign.center,
                style: t.body.copyWith(color: _Ink.soft),
              ),
            )
          else ...[
            Semantics(
              key: LiveDataCenterSheet.chartKey,
              label: l10n.liveDataChartTitle,
              child: SizedBox(
                height: 110,
                child: CustomPaint(
                  painter: _BarsPainter(
                    values: [for (final b in stats.series) b.liveSeconds],
                    rtl: Directionality.of(context) == TextDirection.rtl,
                  ),
                ),
              ),
            ),
            const SizedBox(height: KSpacing.md),
            Text(
              l10n.liveDataBestHours,
              style: t.bodyStrong.copyWith(color: _Ink.text),
            ),
            const SizedBox(height: KSpacing.xs),
            _Heatmap(key: LiveDataCenterSheet.heatmapKey, cells: stats.heatmap),
          ],
        ],
      );
    }
    final labels = {
      LiveStatsPeriod.day: l10n.liveDataPeriodDay,
      LiveStatsPeriod.week: l10n.liveDataPeriodWeek,
      LiveStatsPeriod.month: l10n.liveDataPeriodMonth,
      LiveStatsPeriod.year: l10n.liveDataPeriodYear,
    };
    return SafeArea(
      top: false,
      child: Semantics(
        key: LiveDataCenterSheet.sheetKey,
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        label: l10n.liveToolDataCenter,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            KSpacing.md,
            14,
            KSpacing.md,
            KSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  l10n.liveToolDataCenter,
                  style: t.title.copyWith(color: _Ink.text),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                l10n.liveDataHint,
                style: t.caption.copyWith(color: _Ink.soft),
              ),
              const SizedBox(height: KSpacing.sm),
              Row(
                children: [
                  for (final p in LiveStatsPeriod.values)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: ChoiceChip(
                          key: LiveDataCenterSheet.periodKey(p),
                          label: SizedBox(
                            width: double.infinity,
                            child: Text(
                              labels[p]!,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          selected: p == _period,
                          showCheckmark: false,
                          onSelected: (_) {
                            if (p == _period) return;
                            setState(() => _period = p);
                            unawaited(_load());
                          },
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: KSpacing.md),
              body,
            ],
          ),
        ),
      ),
    );
  }
}

/// Bars of [values] (oldest first, laid out in the reading direction).
class _BarsPainter extends CustomPainter {
  new({required this.values, required this.rtl});

  final List<int> values;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final top = values.reduce(math.max);
    final slot = size.width / values.length;
    final width = math.max(1.5, slot * 0.6);
    final base = Paint()..color = _Ink.tile;
    final bar = Paint()..color = _Ink.bar;
    canvas.drawRect(Rect.fromLTWH(0, size.height - 1, size.width, 1), base);
    for (var i = 0; i < values.length; i++) {
      final h = top == 0 ? 0.0 : (values[i] / top) * (size.height - 4);
      if (h <= 0) continue;
      final index = rtl ? values.length - 1 - i : i;
      final x = index * slot + (slot - width) / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, size.height - 1 - h, width, h),
          const Radius.circular(2),
        ),
        bar,
      );
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) =>
      old.rtl != rtl || !_same(old.values, values);

  static bool _same(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// The best hours: 7 rows (Monday … Sunday) × 24 hours; a cell darkens
/// with the viewers of the lives started then.
class _Heatmap extends StatelessWidget {
  const new({required this.cells, super.key});

  final List<LiveStatsHeatCell> cells;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final top = cells.fold<int>(0, (m, c) => math.max(m, c.viewers));
    final byKey = {for (final c in cells) (c.weekday, c.hour): c};
    final best = cells.isEmpty
        ? null
        : cells.reduce((a, b) => b.viewers > a.viewers ? b : a);
    final days = [
      l10n.liveDataMon,
      l10n.liveDataTue,
      l10n.liveDataWed,
      l10n.liveDataThu,
      l10n.liveDataFri,
      l10n.liveDataSat,
      l10n.liveDataSun,
    ];
    return Semantics(
      label: best == null
          ? l10n.liveDataBestHours
          : l10n.liveDataBestHourSemantics(days[best.weekday - 1], best.hour),
      excludeSemantics: true,
      child: Column(
        children: [
          for (var d = 1; d <= 7; d++)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                children: [
                  SizedBox(
                    width: 34,
                    child: Text(
                      days[d - 1],
                      maxLines: 1,
                      style: t.caption.copyWith(
                        color: _Ink.soft,
                        fontSize: 9.5,
                      ),
                    ),
                  ),
                  for (var h = 0; h < 24; h++)
                    Expanded(
                      child: Container(
                        height: 10,
                        margin: const EdgeInsets.symmetric(horizontal: 0.5),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(1.5),
                          color: switch (byKey[(d, h)]) {
                            final c? when top > 0 => Color.lerp(
                              const Color(0x33FFD36E),
                              _Ink.accent,
                              c.viewers / top,
                            ),
                            _ => _Ink.tile,
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 2),
          Row(
            children: [
              const SizedBox(width: 34),
              for (final h in const [0, 6, 12, 18])
                Expanded(
                  child: Text(
                    '$h',
                    style: t.caption.copyWith(color: _Ink.soft, fontSize: 9),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
