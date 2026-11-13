import 'dart:async';

import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/data/live_media_engine.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D154g: the colour of a connection quality (green / yellow / red).
Color liveConnectionColor(LiveConnectionQuality q) => switch (q) {
  LiveConnectionQuality.excellent ||
  LiveConnectionQuality.good => const Color(0xFF2BB673),
  LiveConnectionQuality.poor => const Color(0xFFF2B01E),
  LiveConnectionQuality.lost => const Color(0xFFE5484D),
  LiveConnectionQuality.unknown => const Color(0xFF9A9BAA),
};

/// D154g: the Room Tools icon of the quality tool, by the connection.
IconData liveConnectionIcon(LiveConnectionQuality q) => switch (q) {
  LiveConnectionQuality.excellent => Icons.signal_cellular_alt_rounded,
  LiveConnectionQuality.good => Icons.signal_cellular_alt_2_bar_rounded,
  LiveConnectionQuality.poor => Icons.signal_cellular_alt_1_bar_rounded,
  LiveConnectionQuality.lost =>
    Icons.signal_cellular_connected_no_internet_0_bar_rounded,
  LiveConnectionQuality.unknown => Icons.signal_cellular_alt_rounded,
};

String liveConnectionText(AppLocalizations l10n, LiveConnectionQuality q) =>
    switch (q) {
      LiveConnectionQuality.excellent => l10n.liveQualityConnExcellent,
      LiveConnectionQuality.good => l10n.liveQualityConnGood,
      LiveConnectionQuality.poor => l10n.liveQualityConnPoor,
      LiveConnectionQuality.lost => l10n.liveQualityConnLost,
      LiveConnectionQuality.unknown => l10n.liveQualityConnUnknown,
    };

/// D154g: when to suggest «السلاسة» — the connection poor (or lost) for
/// [after] in a row while the picture is normal, at most every [gap].
class PoorConnectionWatch {
  static const after = Duration(seconds: 20);
  static const gap = Duration(minutes: 5);

  DateTime? _poorSince;
  DateTime? _suggested;

  /// Feeds the connection at [now]; true: suggest now.
  bool feed(LiveConnectionQuality q, LiveVideoQuality video, DateTime now) {
    final poor =
        q == LiveConnectionQuality.poor || q == LiveConnectionQuality.lost;
    if (!poor || video != LiveVideoQuality.normal) {
      _poorSince = null;
      return false;
    }
    _poorSince ??= now;
    if (now.difference(_poorSince!) < after) return false;
    if (_suggested != null && now.difference(_suggested!) < gap) return false;
    _suggested = now;
    return true;
  }
}

/// D160: when 1080p falls back to 720p by itself — the connection poor (or
/// lost) for [after] in a row while publishing 1080p. Once per weak spell:
/// the host can pick 1080p again.
class HdFallbackWatch {
  static const after = Duration(seconds: 10);

  DateTime? _poorSince;

  /// Feeds the connection at [now]; true: fall back now.
  bool feed(LiveConnectionQuality q, LiveVideoQuality video, DateTime now) {
    final poor =
        q == LiveConnectionQuality.poor || q == LiveConnectionQuality.lost;
    if (!poor || video != LiveVideoQuality.high) {
      _poorSince = null;
      return false;
    }
    _poorSince ??= now;
    if (now.difference(_poorSince!) < after) return false;
    _poorSince = null;
    return true;
  }
}

/// D154g «الجودة» (owner item 7, HD and «السلاسة» in one tool): the host's
/// connection (green / yellow / red, from LiveKit) and the picture —
/// «سلس» 480p at 15 fps for a weak connection, or «عادي» 720p (default).
/// D160: «عالي 1080p» only where this camera captures 1080p; greyed (with
/// why) while the measured uplink is too slow; tried when not measured yet
/// (it falls back to 720p by itself, [HdFallbackWatch]).
Future<void> showLiveQualitySheet(
  BuildContext context, {
  required LiveMediaEngine engine,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: const Color(0xFFFFFFFF),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
  ),
  builder: (_) => LiveQualitySheet(engine: engine),
);

class LiveQualitySheet extends StatefulWidget {
  const new({required this.engine, super.key});

  final LiveMediaEngine engine;

  static const connectionKey = Key('quality.connection');
  static Key optionKey(LiveVideoQuality q) => Key('quality.${q.name}');

  @override
  State<LiveQualitySheet> createState() => _LiveQualitySheetState();
}

class _LiveQualitySheetState extends State<LiveQualitySheet> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    widget.engine.changes.addListener(_changed);
  }

  @override
  void dispose() {
    widget.engine.changes.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _pick(LiveVideoQuality q) async {
    if (_busy || q == widget.engine.videoQuality) return;
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      await widget.engine.setVideoQuality(q);
    } on LiveHdUnsupportedException {
      if (mounted) KSnack.error(context, l10n.liveQualityHighUnsupported);
    } on LiveCaptureException {
      if (mounted) KSnack.error(context, l10n.liveQualityFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    const ink = Color(0xFF1C1B2E);
    const soft = Color(0xFF6E6E7A);
    final conn = widget.engine.connectionQuality;
    final current = widget.engine.videoQuality;
    Widget option(
      LiveVideoQuality q,
      String title,
      String detail, {
      bool enabled = true,
    }) {
      final selected = q == current;
      return Semantics(
        selected: selected,
        button: true,
        enabled: enabled,
        child: InkWell(
          key: LiveQualitySheet.optionKey(q),
          borderRadius: BorderRadius.circular(14),
          onTap: _busy || !enabled ? null : () => unawaited(_pick(q)),
          child: Container(
            margin: const EdgeInsets.only(bottom: KSpacing.sm),
            padding: const EdgeInsets.all(KSpacing.md),
            decoration: BoxDecoration(
              color: selected
                  ? const Color(0x1A7B5CFF)
                  : const Color(0xFFF5F7FB),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? const Color(0xFF7B5CFF)
                    : const Color(0x00000000),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: t.bodyStrong.copyWith(
                          color: enabled ? ink : soft,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(detail, style: t.caption.copyWith(color: soft)),
                    ],
                  ),
                ),
                if (selected)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF7B5CFF),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    // D160: a measured slow uplink greys 1080p (not while it is on).
    final hdSlow =
        widget.engine.uplink == LiveUplink.insufficient &&
        current != LiveVideoQuality.high;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          KSpacing.lg,
          KSpacing.lg,
          KSpacing.lg,
          KSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.liveToolQuality, style: t.title.copyWith(color: ink)),
            const SizedBox(height: KSpacing.md),
            Row(
              key: LiveQualitySheet.connectionKey,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: liveConnectionColor(conn),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: KSpacing.sm),
                Expanded(
                  child: Text(
                    liveConnectionText(l10n, conn),
                    style: t.body.copyWith(color: ink),
                  ),
                ),
              ],
            ),
            const SizedBox(height: KSpacing.md),
            option(
              LiveVideoQuality.smooth,
              l10n.liveQualitySmooth,
              l10n.liveQualitySmoothDetail,
            ),
            option(
              LiveVideoQuality.normal,
              l10n.liveQualityNormal,
              l10n.liveQualityNormalDetail,
            ),
            // D160: only where this camera captures 1080p.
            if (widget.engine.hdCapture || current == LiveVideoQuality.high)
              option(
                LiveVideoQuality.high,
                l10n.liveQualityHigh,
                hdSlow
                    ? l10n.liveQualityHighSlowUplink
                    : l10n.liveQualityHighDetail,
                enabled: !hdSlow,
              ),
            if (_busy) const LinearProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
