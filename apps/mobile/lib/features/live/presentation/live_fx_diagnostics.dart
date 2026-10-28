import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:kabso_camera_fx/kabso_camera_fx.dart';
import 'package:kabso_live/features/live/data/beauty/live_ar_effect.dart';
import 'package:material_ui/material_ui.dart';

/// D144a: the camera processor's diagnostics over the host's room —
/// **debug and profile builds only** (never in a release build), so the
/// owner can screenshot what DeepAR is doing on the device: its state, frames
/// in / fed / out, raw frames (timeouts), renders and re-draws dropped,
/// average wait and readback times, and whether a licence key is present
/// (never the key). A tap folds it to a small chip.
///
/// Technical read-out for the team, not product copy: not localized.
class LiveFxDiagnostics extends StatefulWidget {
  const new({
    required this.load,
    required this.status,
    super.key,
    this.interval = const Duration(seconds: 1),
  });

  static const overlayKey = Key('live.fxDiagnostics');

  /// Shown in this build: debug and profile, not release.
  static bool get enabled => !kReleaseMode;

  final Future<KabsoCameraFxDiagnostics?> Function() load;
  final ValueListenable<LiveArStatus> status;
  final Duration interval;

  @override
  State<LiveFxDiagnostics> createState() => _LiveFxDiagnosticsState();
}

class _LiveFxDiagnosticsState extends State<LiveFxDiagnostics> {
  Timer? _timer;
  KabsoCameraFxDiagnostics? _last;
  bool _folded = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    unawaited(_poll());
    _timer = Timer.periodic(widget.interval, (_) => unawaited(_poll()));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    if (_loading || _folded) return;
    _loading = true;
    try {
      final next = await widget.load();
      if (mounted) setState(() => _last = next);
    } on Object {
      // Diagnostics never break the room.
    } finally {
      _loading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      color: Color(0xFFFFFFFF),
      fontSize: 10.5,
      height: 1.35,
      fontFamily: 'monospace',
      fontFeatures: [FontFeature.tabularFigures()],
    );
    final d = _last;
    final lines = _folded
        ? const ['FX ▸']
        : [
            for (final line in liveFxDiagnosticsLines(d, widget.status.value))
              line,
          ];
    return Directionality(
      textDirection: TextDirection.ltr,
      child: GestureDetector(
        key: LiveFxDiagnostics.overlayKey,
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() => _folded = !_folded);
          if (!_folded) unawaited(_poll());
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xB3000000),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(lines.join('\n'), style: style),
        ),
      ),
    );
  }
}

/// The overlay's lines for [d] (null: the processor did not answer).
List<String> liveFxDiagnosticsLines(
  KabsoCameraFxDiagnostics? d,
  LiveArStatus status,
) {
  if (d == null) return ['DeepAR  no processor', 'app: ${status.state.name}'];
  String ms(double v) => v.toStringAsFixed(1);
  final reason = d.status.reason == null ? '' : ' (${d.status.reason})';
  final licence = d.licencePresent ? 'yes' : 'no';
  final state = 'DeepAR  ${d.status.state.name}$reason  licence $licence';
  final frames =
      'in ${d.framesIn}  fed ${d.fed}  out ${d.framesOut}  '
      'raw ${d.timeouts}  miss ${d.consecutiveMisses}';
  final renders =
      'render ${d.rendered}  got ${d.delivered}  stale ${d.staleDropped}  '
      'busy ${d.busySkips}';
  final times =
      'wait ${ms(d.avgWaitMs)} ms  pack ${ms(d.avgPackMs)} ms  '
      'inflight ${d.inFlightMs} ms';
  final sdk = d.sdkVersion == null ? '' : '  SDK ${d.sdkVersion}';
  final input =
      'input ${d.input ?? '-'}  init ${d.initialized ? 'yes' : 'no'}  '
      '#${d.instances}  ${d.attached ? 'on track' : 'no track'}$sdk';
  return [
    state,
    frames,
    renders,
    times,
    input,
    if (d.lastError case final e?)
      'err ${e.length > 80 ? '${e.substring(0, 80)}…' : e}',
  ];
}
