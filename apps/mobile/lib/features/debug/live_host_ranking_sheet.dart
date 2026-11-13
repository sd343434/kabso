import 'dart:math' as math;

import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/debug/live_leaderboard.dart';
import 'package:kabso_live/features/debug/preview_photo.dart';
import 'package:kabso_live/features/levels/domain/level_models.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D85: a host of the preview's hosts ranking (labelled test data), with
/// the gifts received in each period.
@immutable
class LiveHostPreview {
  const new({required this.host, required this.points});

  final LiveViewerPreview host;
  final Map<LiveRankingPeriod, int> points;
}

/// Test hosts (never shown in production). The room's own host,
/// [hostName], is among them: 3rd this hour, 7th today, 11th this month,
/// 13th of all time.
List<LiveHostPreview> liveHostsFixture({
  required bool ar,
  required String hostName,
  required String hostUsername,
}) {
  String n(String a, String e) => ar ? '$a (تجربة)' : '$e (test)';
  LiveHostPreview h(
    String name,
    String username,
    String country,
    int level,
    List<int> points, [
    String? photo,
  ]) => LiveHostPreview(
    host: LiveViewerPreview(
      name: name,
      username: username,
      country: country,
      photo: photo,
      support: 0,
      attraction: points.first,
      wizard: 0,
      levels: {LevelCategory.attractiveness: level},
    ),
    points: {
      for (final (i, p) in LiveRankingPeriod.hostPeriods.indexed) p: points[i],
    },
  );
  LiveHostPreview t(
    String a,
    String e,
    String country,
    int level,
    List<int> points, [
    String? photo,
  ]) =>
      h(n(a, e), 'test_host_${e.toLowerCase()}', country, level, points, photo);
  return [
    h(hostName, hostUsername, 'JO', 58, [96000, 410000, 6100000, 38000000]),
    t('هدى', 'Huda', 'JO', 88, [
      152000,
      980000,
      31000000,
      410000000,
    ], PreviewPhotos.huda),
    t('ليلى', 'Layla', 'SA', 74, [
      121000,
      1250000,
      26500000,
      298000000,
    ], PreviewPhotos.layla),
    t('رانيا', 'Rania', 'EG', 61, [
      54000,
      860000,
      19800000,
      176000000,
    ], PreviewPhotos.rania),
    t('عمر', 'Omar', 'IQ', 52, [
      41000,
      720000,
      15200000,
      121000000,
    ], PreviewPhotos.omar),
    t('كريم', 'Karim', 'MA', 47, [
      88000,
      640000,
      12900000,
      96000000,
    ], PreviewPhotos.karim),
    t('سامي', 'Sami', 'EG', 40, [22000, 530000, 11400000, 87000000]),
    t('نور', 'Nour', 'SA', 33, [65000, 395000, 9900000, 74000000]),
    t('دانة', 'Dana', 'SY', 27, [18000, 380000, 8800000, 66000000]),
    t('رنا', 'Rana', 'AE', 21, [12000, 220000, 7600000, 59000000]),
    t('مزن', 'Muzn', 'KW', 14, [9000, 180000, 6900000, 52000000]),
    t('جود', 'Joud', 'JO', 18, [7000, 150000, 6400000, 47000000]),
    t('ياسمين', 'Yasmin', 'EG', 12, [4000, 90000, 4800000, 41000000]),
    // D85: numbered test hosts fill the list to 100, all below the room's
    // host in every period (so its places above stay the same).
    for (var i = 14; i <= 100; i++)
      h(
        n('مضيف $i', 'Host $i'),
        'test_host_$i',
        _countries[i % _countries.length],
        math.max(1, 30 - i ~/ 4),
        [
          3900 - i * 30,
          89000 - i * 700,
          4700000 - i * 40000,
          37000000 - i * 300000,
        ],
      ),
  ];
}

const _countries = ['JO', 'SA', 'EG', 'IQ', 'MA', 'SY', 'AE', 'KW'];

/// D85 (owner): **Ranking list**, opened from the live header's chip — the
/// room's host among all hosts this hour, today, this month and of all
/// time, by gifts received (Attractiveness), in the D84 leaderboard look.
/// The host's own place is pinned at the bottom.
class LiveHostRankingSheet extends StatefulWidget {
  const new({
    required this.hosts,
    required this.hostUsername,
    super.key,
    this.onOpenProfile,
    this.now = DateTime.now,
  });

  final List<LiveHostPreview> hosts;

  /// The room's host (the pinned place).
  final String hostUsername;
  final ValueChanged<LiveViewerPreview>? onOpenProfile;
  final DateTime Function() now;

  static const sheetKey = Key('liveHostRanking.sheet');
  static const placeKey = Key('liveHostRanking.place');

  static Future<void> show(
    BuildContext context, {
    required List<LiveHostPreview> hosts,
    required String hostUsername,
    ValueChanged<LiveViewerPreview>? onOpenProfile,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => LiveHostRankingSheet(
      hosts: hosts,
      hostUsername: hostUsername,
      onOpenProfile: onOpenProfile,
    ),
  );

  @override
  State<LiveHostRankingSheet> createState() => _LiveHostRankingSheetState();
}

class _LiveHostRankingSheetState extends State<LiveHostRankingSheet> {
  LiveRankingPeriod _period = LiveRankingPeriod.hourly;

  /// Test data: each round ends a fixed time after the sheet opened.
  late final DateTime _opened = widget.now();

  late final Map<String, Map<LiveRankingPeriod, int>> _points = {
    for (final h in widget.hosts) h.host.username: h.points,
  };

  int _value(LiveViewerPreview host, LiveRankingPeriod period) =>
      _points[host.username]?[period] ?? 0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final hosts = [for (final h in widget.hosts) h.host];
    final ranked = [...hosts]
      ..sort((a, b) => _value(b, _period).compareTo(_value(a, _period)));
    final own = ranked.indexWhere((h) => h.username == widget.hostUsername);
    return SafeArea(
      key: LiveHostRankingSheet.sheetKey,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.94,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(start: KSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.liveRankingList,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.title.copyWith(fontSize: 16),
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.liveClose,
                    onPressed: () => Navigator.maybePop(context),
                    icon: Icon(Icons.close_rounded, color: p.textPrimary),
                  ),
                ],
              ),
            ),
            Expanded(
              child: LiveLeaderboard(
                viewers: hosts,
                period: _period,
                filter: LiveViewersFilter.attraction,
                periods: LiveRankingPeriod.hostPeriods,
                showGiftFilters: false,
                valueOf: _value,
                // D85 (owner): the top 100.
                maxRows: 100,
                endsAt: switch (_period.fixtureRemaining) {
                  final left? => _opened.add(left),
                  null => null,
                },
                now: widget.now,
                onPeriod: (v) => setState(() => _period = v),
                onFilter: (_) {},
                onGiftFilter: () {},
                onInfo: () => _help(context),
                onOpen: widget.onOpenProfile == null
                    ? null
                    : (v) {
                        Navigator.maybePop(context);
                        widget.onOpenProfile!(v);
                      },
              ),
            ),
            if (own >= 0)
              _HostPlace(
                rank: own + 1,
                host: ranked[own],
                value: _value(ranked[own], _period),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _help(BuildContext context) {
    final l10n = context.l10n;
    return showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l10n.liveRankingList),
        content: Text(l10n.liveHostRankingHelpBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(),
            child: Text(l10n.actionContinue),
          ),
        ],
      ),
    );
  }
}

/// The room's host's own place in the selected period.
class _HostPlace extends StatelessWidget {
  const new({required this.rank, required this.host, required this.value});

  final int rank;
  final LiveViewerPreview host;
  final int value;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    return Container(
      key: LiveHostRankingSheet.placeKey,
      padding: const EdgeInsets.symmetric(
        horizontal: KSpacing.lg,
        vertical: KSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(top: BorderSide(color: p.border)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Text(
              '$rank',
              textAlign: TextAlign.center,
              style: t.bodyStrong.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: KSpacing.sm),
          KAvatar(
            name: host.name,
            image: PreviewPhotos.asset(host.photo),
            size: 40,
          ),
          const SizedBox(width: KSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  host.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodyStrong,
                ),
                Text(
                  l10n.liveHostRankingPlace,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.caption.copyWith(color: p.textTertiary),
                ),
              ],
            ),
          ),
          const SizedBox(width: KSpacing.sm),
          LeaderboardScore(value: value),
        ],
      ),
    );
  }
}
