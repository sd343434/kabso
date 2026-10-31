import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/data/live_media_engine.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/tools/live_tool_parts.dart';
import 'package:kabso_live/features/live/tools/live_tools_repository.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D201 «الانضمام ككاميرا ثانية» (`/live/second-camera`): on the host's
/// second phone or tablet, signed in to the same account. The code from the
/// main device's «كاميرتان» → a minimal camera screen: the picture, flip, the
/// microphone (off at first) and leave. No chat, no viewers' things: this
/// device only publishes its camera into the host's live.
class SecondCameraScreen extends ConsumerStatefulWidget {
  const new({super.key});

  static const codeKey = Key('cam2b.code');
  static const joinKey = Key('cam2b.join');
  static const errorKey = Key('cam2b.error');
  static const cameraKey = Key('cam2b.camera');
  static const flipKey = Key('cam2b.flip');
  static const micKey = Key('cam2b.mic');
  static const leaveKey = Key('cam2b.leave');
  static const endedKey = Key('cam2b.ended');
  static const onAirKey = Key('cam2b.onAir');

  @override
  ConsumerState<SecondCameraScreen> createState() => _SecondCameraScreenState();
}

enum _Phase { code, joining, live, ended }

class _SecondCameraScreenState extends ConsumerState<SecondCameraScreen> {
  final _code = TextEditingController();
  _Phase _phase = _Phase.code;
  String? _error;
  LiveMediaEngine? _engine;
  SecondCameraAccess? _access;
  bool _wasConnected = false;

  LiveToolsRepository get _repo => ref.read(liveToolsRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _code.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _code.dispose();
    final engine = _engine;
    _engine = null;
    engine?.changes.removeListener(_changed);
    unawaited(engine?.stop());
    super.dispose();
  }

  void _changed() {
    final engine = _engine;
    if (!mounted || engine == null) return;
    if (engine.connected) _wasConnected = true;
    if (_phase == _Phase.live &&
        (engine.removed || (_wasConnected && !engine.connected))) {
      setState(() => _phase = _Phase.ended);
      unawaited(engine.stop());
      return;
    }
    setState(() {});
  }

  Future<void> _join() async {
    final l10n = context.l10n;
    final code = _code.text.trim();
    if (code.length != 6 || _phase != _Phase.code) return;
    setState(() {
      _phase = _Phase.joining;
      _error = null;
    });
    SecondCameraAccess access;
    try {
      access = await _repo.redeem(code);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.code;
        _error = switch (e) {
          ServerFailure(rawCode: 'SECOND_CAMERA_CODE_INVALID') ||
          ServerFailure(
            rawCode: 'VALIDATION_FAILED',
          ) => l10n.liveCam2CodeInvalid,
          ServerFailure(rawCode: 'SECOND_CAMERA_UNAVAILABLE') =>
            l10n.liveCam2Unavailable,
          ServerFailure(rawCode: 'SECOND_CAMERA_BUSY') => l10n.liveCam2Busy,
          ServerFailure(rawCode: 'RATE_LIMITED') => l10n.liveCam2TooMany,
          _ => l10n.liveCam2Failed,
        };
      });
      return;
    }
    final engine = ref.read(liveMediaEngineProvider)();
    _engine = engine;
    _access = access;
    engine.changes.addListener(_changed);
    try {
      // The microphone starts off; the host turns it on here if wanted.
      await engine.setMicEnabled(enabled: false);
      await engine.startPreview();
      await engine.publish(
        LiveMediaAccess(
          url: access.url,
          token: access.token,
          expiresAt: access.expiresAt,
          role: LiveMediaRole.speaker,
          identity: access.identity,
        ),
      );
      if (!mounted) return;
      setState(() => _phase = _Phase.live);
    } on LiveCaptureException catch (e) {
      await _abandon();
      if (!mounted) return;
      setState(() {
        _phase = _Phase.code;
        _error = e.problem == LiveCaptureProblem.unavailable
            ? l10n.liveCam2Failed
            : l10n.liveCam2PermissionDenied;
      });
    } on Object {
      await _abandon();
      if (!mounted) return;
      setState(() {
        _phase = _Phase.code;
        _error = l10n.liveCam2Failed;
      });
    }
  }

  /// Leaves the media room and tells the server (the main device's state).
  Future<void> _abandon() async {
    final engine = _engine;
    _engine = null;
    engine?.changes.removeListener(_changed);
    await engine?.stop();
    final access = _access;
    _access = null;
    if (access != null) {
      try {
        await _repo.endSecondCamera(access.roomId);
      } on Object {
        // The server also ends it when the device leaves the media room.
      }
    }
  }

  Future<void> _leave() async {
    await _abandon();
    if (!mounted) return;
    final router = GoRouter.maybeOf(context);
    if (router != null && !router.canPop()) {
      router.go('/');
    } else {
      await Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) => switch (_phase) {
    _Phase.code || _Phase.joining => _codeView(context),
    _Phase.live => _cameraView(context),
    _Phase.ended => _endedView(context),
  };

  Widget _codeView(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final joining = _phase == _Phase.joining;
    return LiveToolLightTheme(
      child: Scaffold(
        backgroundColor: const Color(0xFFFFFFFF),
        appBar: AppBar(
          backgroundColor: const Color(0xFFFFFFFF),
          foregroundColor: LiveToolColors.ink,
          title: Text(l10n.liveSecondCameraJoin),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(KSpacing.lg),
            children: [
              const Icon(
                Icons.video_camera_front_rounded,
                size: 56,
                color: LiveToolColors.accent,
              ),
              const SizedBox(height: KSpacing.md),
              Text(
                l10n.liveCam2JoinIntro,
                textAlign: TextAlign.center,
                style: t.body.copyWith(color: LiveToolColors.ink, height: 1.5),
              ),
              const SizedBox(height: KSpacing.lg),
              Directionality(
                textDirection: TextDirection.ltr,
                child: TextField(
                  key: SecondCameraScreen.codeKey,
                  controller: _code,
                  enabled: !joining,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  style: t.display.copyWith(
                    letterSpacing: 8,
                    color: LiveToolColors.ink,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '000000',
                    labelText: l10n.liveCam2CodeLabel,
                    errorText: _error,
                    errorMaxLines: 3,
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => unawaited(_join()),
                ),
              ),
              if (_error != null)
                Semantics(
                  liveRegion: true,
                  child: const SizedBox(
                    key: SecondCameraScreen.errorKey,
                    height: 0,
                  ),
                ),
              const SizedBox(height: KSpacing.md),
              KButton(
                key: SecondCameraScreen.joinKey,
                label: l10n.liveCam2JoinButton,
                loading: joining,
                onPressed: _code.text.trim().length == 6 && !joining
                    ? () => unawaited(_join())
                    : null,
              ),
              const SizedBox(height: KSpacing.lg),
              LiveToolNote(
                icon: Icons.privacy_tip_outlined,
                text: l10n.liveCam2JoinPermissions,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cameraView(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final engine = _engine;
    final mic = engine?.micEnabled ?? false;
    Widget control({
      required Key key,
      required IconData icon,
      required String label,
      required VoidCallback onTap,
      Color color = const Color(0x66000000),
    }) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: key,
          tooltip: label,
          iconSize: 28,
          style: IconButton.styleFrom(
            backgroundColor: color,
            foregroundColor: const Color(0xFFFFFFFF),
            minimumSize: const Size(56, 56),
          ),
          onPressed: onTap,
          icon: Icon(icon),
        ),
        const SizedBox(height: 4),
        Text(label, style: t.caption.copyWith(color: const Color(0xFFFFFFFF))),
      ],
    );
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: Stack(
        fit: StackFit.expand,
        children: [
          KeyedSubtree(
            key: SecondCameraScreen.cameraKey,
            child:
                engine?.preview() ?? const ColoredBox(color: Color(0xFF000000)),
          ),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: KSpacing.sm),
                Container(
                  key: SecondCameraScreen.onAirKey,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x99000000),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: engine?.connected ?? false
                              ? LiveToolColors.rec
                              : const Color(0xFFB0B0B8),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        engine?.connected ?? false
                            ? l10n.liveCam2OnAir
                            : l10n.liveCam2Connecting,
                        style: t.label.copyWith(color: const Color(0xFFFFFFFF)),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(bottom: KSpacing.lg),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      control(
                        key: SecondCameraScreen.flipKey,
                        icon: Icons.flip_camera_ios_rounded,
                        label: l10n.liveCam2Flip,
                        onTap: () => unawaited(engine?.flipCamera()),
                      ),
                      control(
                        key: SecondCameraScreen.micKey,
                        icon: mic ? Icons.mic_rounded : Icons.mic_off_rounded,
                        label: mic ? l10n.liveCam2MicOff : l10n.liveCam2MicOn,
                        onTap: () async {
                          await engine?.setMicEnabled(enabled: !mic);
                          if (mounted) setState(() {});
                        },
                      ),
                      control(
                        key: SecondCameraScreen.leaveKey,
                        icon: Icons.call_end_rounded,
                        label: l10n.liveCam2Leave,
                        color: LiveToolColors.rec,
                        onTap: () => unawaited(_leave()),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _endedView(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(KSpacing.lg),
            child: Column(
              key: SecondCameraScreen.endedKey,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.videocam_off_outlined,
                  size: 56,
                  color: LiveToolColors.soft,
                ),
                const SizedBox(height: KSpacing.md),
                Text(
                  l10n.liveCam2Ended,
                  textAlign: TextAlign.center,
                  style: t.body.copyWith(color: LiveToolColors.ink),
                ),
                const SizedBox(height: KSpacing.lg),
                KButton(
                  label: l10n.liveToolsClose,
                  onPressed: () => unawaited(_leave()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
