import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/tools/live_tool_parts.dart';
import 'package:kabso_live/features/live/tools/live_tools_repository.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D201 «كاميرتان» on the main device: a pairing code (120 s, single use,
/// this account only), then the second camera's state, the viewers' default
/// main feed and «فصل». Before going live, in a PK or in another kind of
/// live it says why it is not available.
Future<void> showSecondCameraSheet(
  BuildContext context, {
  required String? roomId,
  required bool inPk,
}) => showLiveToolSheet<void>(
  context,
  builder: (_) => SecondCameraSheet(roomId: roomId, inPk: inPk),
);

class SecondCameraSheet extends ConsumerStatefulWidget {
  const new({required this.roomId, required this.inPk, super.key});

  /// Null before the live started.
  final String? roomId;
  final bool inPk;

  static const sheetKey = Key('cam2.sheet');
  static const createKey = Key('cam2.create');
  static const codeKey = Key('cam2.code');
  static const countdownKey = Key('cam2.countdown');
  static const expiredKey = Key('cam2.expired');
  static const cancelKey = Key('cam2.cancel');
  static const waitingKey = Key('cam2.waiting');
  static const connectedKey = Key('cam2.connected');
  static const endKey = Key('cam2.end');
  static const unavailableKey = Key('cam2.unavailable');
  static Key mainKey(SecondCameraFeed f) => Key('cam2.main.${f.name}');

  /// How often the sheet re-reads the state while a code or camera is open.
  static const poll = Duration(seconds: 2);

  @override
  ConsumerState<SecondCameraSheet> createState() => _SecondCameraSheetState();
}

class _SecondCameraSheetState extends ConsumerState<SecondCameraSheet> {
  SecondCameraState? _state;
  SecondCameraCode? _code;
  bool _busy = false;
  bool _failed = false;
  Timer? _tick;
  Timer? _poll;

  LiveToolsRepository get _repo => ref.read(liveToolsRepositoryProvider);

  @override
  void initState() {
    super.initState();
    if (widget.roomId != null && !widget.inPk) unawaited(_load());
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _code != null) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final roomId = widget.roomId;
    if (roomId == null) return;
    try {
      final state = await _repo.secondCamera(roomId);
      if (!mounted) return;
      setState(() {
        _state = state;
        _failed = false;
        if (state.paired) _code = null;
      });
      _schedule();
    } on Object {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _schedule() {
    _poll?.cancel();
    final s = _state;
    final open =
        _code != null || (s != null && s.status != SecondCameraStatus.none);
    if (open) _poll = Timer(SecondCameraSheet.poll, () => unawaited(_load()));
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } on AppFailure catch (e) {
      if (!mounted) return;
      final l10n = context.l10n;
      KSnack.error(context, switch (e) {
        ServerFailure(rawCode: 'SECOND_CAMERA_BUSY') => l10n.liveCam2Busy,
        ServerFailure(rawCode: 'SECOND_CAMERA_UNAVAILABLE') =>
          l10n.liveCam2Unavailable,
        _ => l10n.liveToolsFailed,
      });
    } on Object {
      if (mounted) KSnack.error(context, context.l10n.liveToolsFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _create() => _run(() async {
    final code = await _repo.createCode(widget.roomId!);
    if (!mounted) return;
    setState(() => _code = code);
    await _load();
  });

  Future<void> _end() => _run(() async {
    await _repo.endSecondCamera(widget.roomId!);
    if (!mounted) return;
    setState(() => _code = null);
    await _load();
  });

  Future<void> _main(SecondCameraFeed feed) => _run(() async {
    final state = await _repo.setMain(widget.roomId!, feed);
    if (mounted) setState(() => _state = state);
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final s = _state;
    final children = <Widget>[];
    String? unavailable;
    if (widget.roomId == null) {
      unavailable = l10n.liveCam2NotLive;
    } else if (widget.inPk ||
        s?.unavailableReason == SecondCameraUnavailable.pk) {
      unavailable = l10n.liveCam2InPk;
    } else if (s?.unavailableReason == SecondCameraUnavailable.notSolo) {
      unavailable = l10n.liveCam2NotSolo;
    } else if (s?.unavailableReason == SecondCameraUnavailable.notLive) {
      unavailable = l10n.liveCam2NotLive;
    }
    children
      ..add(LiveToolNote(icon: Icons.devices_rounded, text: l10n.liveCam2Intro))
      ..add(const SizedBox(height: KSpacing.md));
    if (unavailable != null) {
      children.add(
        LiveToolNote(
          key: SecondCameraSheet.unavailableKey,
          icon: Icons.info_outline_rounded,
          text: unavailable,
          warning: true,
        ),
      );
    } else if (s == null) {
      children.add(
        _failed
            ? LiveToolNote(
                icon: Icons.wifi_off_rounded,
                text: l10n.liveToolsFailed,
                warning: true,
              )
            : const Center(child: CircularProgressIndicator()),
      );
    } else if (s.status == SecondCameraStatus.connected) {
      children.addAll([
        Row(
          key: SecondCameraSheet.connectedKey,
          children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF1FA463)),
            const SizedBox(width: KSpacing.sm),
            Expanded(
              child: Text(
                l10n.liveCam2Connected,
                style: t.bodyStrong.copyWith(color: LiveToolColors.ink),
              ),
            ),
          ],
        ),
        const SizedBox(height: KSpacing.md),
        Text(
          l10n.liveCam2MainLabel,
          style: t.label.copyWith(color: LiveToolColors.ink),
        ),
        const SizedBox(height: KSpacing.sm),
        SegmentedButton<SecondCameraFeed>(
          segments: [
            ButtonSegment(
              value: SecondCameraFeed.host,
              icon: const Icon(Icons.smartphone_rounded),
              label: Text(
                l10n.liveCam2MainHost,
                key: SecondCameraSheet.mainKey(SecondCameraFeed.host),
              ),
            ),
            ButtonSegment(
              value: SecondCameraFeed.second,
              icon: const Icon(Icons.tablet_android_rounded),
              label: Text(
                l10n.liveCam2MainSecond,
                key: SecondCameraSheet.mainKey(SecondCameraFeed.second),
              ),
            ),
          ],
          selected: {s.main},
          showSelectedIcon: false,
          onSelectionChanged: _busy ? null : (v) => unawaited(_main(v.first)),
        ),
        const SizedBox(height: KSpacing.sm),
        LiveToolNote(
          icon: Icons.swap_horiz_rounded,
          text: l10n.liveCam2MainNote,
        ),
        const SizedBox(height: KSpacing.lg),
        KButton(
          key: SecondCameraSheet.endKey,
          label: l10n.liveCam2End,
          icon: Icons.link_off_rounded,
          variant: KButtonVariant.destructive,
          loading: _busy,
          onPressed: () => unawaited(_end()),
        ),
      ]);
    } else if (s.status == SecondCameraStatus.paired) {
      children.addAll([
        Row(
          key: SecondCameraSheet.waitingKey,
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: KSpacing.sm),
            Expanded(
              child: Text(
                l10n.liveCam2Waiting,
                style: t.body.copyWith(color: LiveToolColors.ink),
              ),
            ),
          ],
        ),
        const SizedBox(height: KSpacing.lg),
        KButton(
          key: SecondCameraSheet.endKey,
          label: l10n.liveCam2End,
          variant: KButtonVariant.secondary,
          onPressed: _busy ? null : () => unawaited(_end()),
        ),
      ]);
    } else if (_code case final code?) {
      final left = code.expiresAt.difference(clock.now());
      final expired = left <= Duration.zero;
      children.addAll([
        Text(
          l10n.liveCam2CodeLabel,
          textAlign: TextAlign.center,
          style: t.label.copyWith(color: LiveToolColors.soft),
        ),
        const SizedBox(height: KSpacing.xs),
        Semantics(
          label: '${l10n.liveCam2CodeLabel}: ${code.code.split('').join(' ')}',
          child: ExcludeSemantics(
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                '${code.code.substring(0, 3)} ${code.code.substring(3)}',
                key: SecondCameraSheet.codeKey,
                textAlign: TextAlign.center,
                style: t.display.copyWith(
                  color: expired ? LiveToolColors.soft : LiveToolColors.ink,
                  letterSpacing: 6,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  decoration: expired ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: KSpacing.xs),
        if (expired)
          Text(
            l10n.liveCam2CodeExpired,
            key: SecondCameraSheet.expiredKey,
            textAlign: TextAlign.center,
            style: t.body.copyWith(color: LiveToolColors.warning),
          )
        else
          Text(
            l10n.liveCam2CodeExpires(liveToolClock(left)),
            key: SecondCameraSheet.countdownKey,
            textAlign: TextAlign.center,
            style: t.body.copyWith(color: LiveToolColors.ink),
          ),
        const SizedBox(height: KSpacing.xs),
        Text(
          l10n.liveCam2CodeOnce,
          textAlign: TextAlign.center,
          style: t.caption.copyWith(color: LiveToolColors.soft),
        ),
        const SizedBox(height: KSpacing.md),
        LiveToolNote(
          icon: Icons.format_list_numbered_rounded,
          text: l10n.liveCam2Steps,
        ),
        const SizedBox(height: KSpacing.md),
        KButton(
          key: SecondCameraSheet.createKey,
          label: l10n.liveCam2NewCode,
          icon: Icons.refresh_rounded,
          variant: expired ? KButtonVariant.primary : KButtonVariant.secondary,
          loading: _busy,
          onPressed: () => unawaited(_create()),
        ),
        const SizedBox(height: KSpacing.sm),
        KButton(
          key: SecondCameraSheet.cancelKey,
          label: l10n.liveCam2Cancel,
          variant: KButtonVariant.ghost,
          onPressed: _busy ? null : () => unawaited(_end()),
        ),
      ]);
    } else {
      children.addAll([
        LiveToolNote(
          icon: Icons.format_list_numbered_rounded,
          text: l10n.liveCam2Steps,
        ),
        const SizedBox(height: KSpacing.sm),
        LiveToolNote(
          icon: Icons.picture_in_picture_alt_rounded,
          text: l10n.liveCam2Layout,
        ),
        const SizedBox(height: KSpacing.lg),
        KButton(
          key: SecondCameraSheet.createKey,
          label: l10n.liveCam2CreateCode,
          icon: Icons.qr_code_2_rounded,
          loading: _busy,
          onPressed: () => unawaited(_create()),
        ),
      ]);
    }
    return LiveToolSheetBody(
      key: SecondCameraSheet.sheetKey,
      title: l10n.liveToolDual,
      children: children,
    );
  }
}
