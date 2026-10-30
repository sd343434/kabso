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
/// D145e: the `luma` line — brightness (0–255, video black is 16) of the
/// frame fed to DeepAR (`in`) and of DeepAR's published picture (`out`),
/// how long the output has been black against a lit camera, and after a
/// `black_output` stop what DeepAR showed without the effect (`probe`).
/// D144a's `render` count is gone: DeepAR 5.6.22 never reports it.
///
/// D144b: the `camera` line — every frame the camera track handed to the
/// processor (effect or not) and how the attach found the track (`source`:
/// the camera's own frame path; `rebound`: a shared camera track moved onto
/// it; `unknown`). `camera 0` while `on track` means no picture can reach the
/// effect; the effect then stops after 10 s with `error (no_frames)`.
///
/// D144c: `engine` is DeepAR's own state (1 initializing, 2 running; stuck
/// at 0 or 1 with frames coming: it never started), and the `lit` line says
/// when DeepAR's picture was first seen lit after the pick and how many
/// black renders were held back (the camera went out instead). DeepAR's
/// warnings have their own `warn` line; `err` keeps the error that matters.
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
      'got ${d.delivered}  stale ${d.staleDropped}  busy ${d.busySkips}';
  String luma(int v) => v < 0 ? '-' : '$v';
  final black = d.blackMs > 0
      ? '  black ${(d.blackMs / 1000).toStringAsFixed(1)} s'
      : '';
  final brightness =
      'luma in ${luma(d.inputLuma)}  out ${luma(d.outputLuma)}$black'
      '${d.probe == null ? '' : '  probe ${d.probe}'}';
  final times =
      'wait ${ms(d.avgWaitMs)} ms  pack ${ms(d.avgPackMs)} ms  '
      'inflight ${d.inFlightMs} ms';
  final sdk = d.sdkVersion == null ? '' : '  SDK ${d.sdkVersion}';
  final input =
      'input ${d.input ?? '-'}  init ${d.initialized ? 'yes' : 'no'}  '
      '#${d.instances}  ${d.attached ? 'on track' : 'no track'}$sdk';
  final camera =
      'camera ${d.cameraFrames}  path ${d.framePath ?? '-'}  '
      'engine ${d.engine < 0 ? '-' : d.engine}';
  final lit = 'lit ${d.litMs < 0 ? '-' : '${d.litMs} ms'}  held ${d.heldBlack}';
  return [
    state,
    frames,
    renders,
    brightness,
    times,
    input,
    camera,
    lit,
    if (d.lastError case final e?)
      'err ${e.length > 80 ? '${e.substring(0, 80)}…' : e}',
    if (d.lastWarning case final w?)
      'warn ${w.length > 80 ? '${w.substring(0, 80)}…' : w}',
  ];
}
