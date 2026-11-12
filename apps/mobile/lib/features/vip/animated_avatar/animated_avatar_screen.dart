// v1.136-social (D384, CONVENTIONS §10.173): «صورة متحركة» — the member
// records 3 s with the front camera, the phone removes the background, the
// cut-out plays as a preview over a checkerboard, then save (upload),
// record again, or remove the saved clip.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/application/live_viewer_prefs.dart';
import 'package:kabso_live/features/profile/application/public_profile_controller.dart';
import 'package:kabso_live/features/vip/animated_avatar/animated_avatar_repository.dart';
import 'package:kabso_live/features/vip/animated_avatar/cutout_compose.dart';
import 'package:kabso_live/features/vip/animated_avatar/cutout_recorder.dart';
import 'package:kabso_live/features/vip/animated_avatar/cutout_strip_player.dart';
import 'package:kabso_live/features/vip/presentation/vip_cutout.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

enum _Stage { idle, opening, recording, processing, preview }

/// «صورة متحركة» (members holding ANIMATED_AVATAR; the server refuses the
/// save otherwise).
class AnimatedAvatarScreen extends ConsumerStatefulWidget {
  const new({super.key});

  static const stageKey = Key('vip.animatedAvatar.stage');
  static const recordKey = Key('vip.animatedAvatar.record');
  static const saveKey = Key('vip.animatedAvatar.save');
  static const removeKey = Key('vip.animatedAvatar.remove');
  static const previewKey = Key('vip.animatedAvatar.preview');
  static const currentKey = Key('vip.animatedAvatar.current');
  static const emptyKey = Key('vip.animatedAvatar.empty');
  static const cameraKey = Key('vip.animatedAvatar.camera');
  static const progressKey = Key('vip.animatedAvatar.progress');
  static const errorKey = Key('vip.animatedAvatar.error');

  @override
  ConsumerState<AnimatedAvatarScreen> createState() =>
      _AnimatedAvatarScreenState();
}

class _AnimatedAvatarScreenState extends ConsumerState<AnimatedAvatarScreen> {
  _Stage _stage = _Stage.idle;
  double _progress = 0;
  CutoutStrip? _strip;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _strip?.image.dispose();
    super.dispose();
  }

  String? get _me => ref.read(currentUserProvider)?.username;

  Future<void> _record() async {
    final l10n = context.l10n;
    final recorder = ref.read(cutoutRecorderProvider);
    setState(() {
      _stage = _Stage.opening;
      _error = null;
      _progress = 0;
    });
    try {
      await recorder.open();
      if (!mounted) return;
      setState(() => _stage = _Stage.recording);
      final frames = await recorder.record(
        onProgress: (p) {
          if (!mounted) return;
          setState(() {
            _progress = p;
            if (p >= 0.5) _stage = _Stage.processing;
          });
        },
      );
      if (!mounted) return;
      setState(() => _stage = _Stage.processing);
      final strip = await composeCutoutStrip(frames);
      if (!mounted) {
        strip.image.dispose();
        return;
      }
      setState(() {
        _strip?.image.dispose();
        _strip = strip;
        _stage = _Stage.preview;
      });
    } on CutoutNoPersonException {
      _fail(l10n.vipAnimatedAvatarNoPerson);
    } on CutoutTooLargeException {
      _fail(l10n.vipAnimatedAvatarTooLarge);
    } on CutoutCameraException {
      _fail(l10n.vipAnimatedAvatarCameraError);
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _stage = _strip == null ? _Stage.idle : _Stage.preview;
      _error = message;
    });
  }

  Future<void> _save() async {
    final strip = _strip;
    if (strip == null) return;
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      await ref.read(animatedAvatarRepositoryProvider).save(strip.png);
      if (!mounted) return;
      _refreshMine();
      setState(() {
        _strip = null;
        _stage = _Stage.idle;
      });
      strip.image.dispose();
      KSnack.success(context, l10n.vipAnimatedAvatarSaved);
    } on Object catch (e) {
      if (!mounted) return;
      KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      await ref.read(animatedAvatarRepositoryProvider).remove();
      if (!mounted) return;
      _refreshMine();
      KSnack.success(context, l10n.vipAnimatedAvatarRemoved);
    } on Object catch (e) {
      if (!mounted) return;
      KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _refreshMine() {
    if (_me case final me?) ref.invalidate(publicProfileProvider(me));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final text = context.textStyles;
    final me = ref.watch(currentUserProvider)?.username;
    final current = me == null
        ? null
        : ref.watch(publicProfileProvider(me)).value?.animatedAvatar;
    final playing =
        !MediaQuery.disableAnimationsOf(context) &&
        !ref.watch(liveViewerPrefsProvider.select((p) => p.giftEffectsHidden));
    // The camera and the model live while the screen does.
    final recorder = ref.watch(cutoutRecorderProvider);
    final strip = _strip;
    final working =
        _stage == _Stage.opening ||
        _stage == _Stage.recording ||
        _stage == _Stage.processing;

    final stage = switch (_stage) {
      _Stage.recording || _Stage.opening => Stack(
        key: AnimatedAvatarScreen.cameraKey,
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(KRadius.lg),
            child: FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: 300,
                height: 400,
                child: recorder.preview(context),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(KSpacing.md),
              child: _Pill(text: l10n.vipAnimatedAvatarLook),
            ),
          ),
        ],
      ),
      _Stage.processing => Center(
        key: AnimatedAvatarScreen.progressKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: KSpacing.md),
            Text(
              l10n.vipAnimatedAvatarProcessing,
              textAlign: TextAlign.center,
              style: text.body.copyWith(color: palette.textSecondary),
            ),
          ],
        ),
      ),
      _Stage.preview when strip != null => CutoutStripPlayer(
        key: AnimatedAvatarScreen.previewKey,
        strip: strip.image,
        frames: strip.frames,
        playing: playing,
      ),
      _ when current != null => Image(
        key: AnimatedAvatarScreen.currentKey,
        image: animatedAvatarImage(playing ? current.url : current.stillUrl),
        fit: BoxFit.contain,
        alignment: Alignment.bottomCenter,
        gaplessPlayback: true,
        excludeFromSemantics: true,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      ),
      _ => Center(
        key: AnimatedAvatarScreen.emptyKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.face_retouching_natural_outlined,
              size: 56,
              color: palette.textTertiary,
            ),
            const SizedBox(height: KSpacing.sm),
            Text(
              l10n.vipAnimatedAvatarEmpty,
              textAlign: TextAlign.center,
              style: text.body.copyWith(color: palette.textSecondary),
            ),
          ],
        ),
      ),
    };

    return Scaffold(
      appBar: AppBar(title: Text(l10n.vipAnimatedAvatarEntry)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(KSpacing.lg),
          children: [
            Text(
              l10n.vipAnimatedAvatarIntro,
              textAlign: TextAlign.center,
              style: text.body.copyWith(color: palette.textSecondary),
            ),
            const SizedBox(height: KSpacing.lg),
            if (_stage == _Stage.preview) ...[
              Text(
                l10n.vipAnimatedAvatarPreview,
                textAlign: TextAlign.center,
                style: text.label.copyWith(color: palette.textPrimary),
              ),
              const SizedBox(height: KSpacing.sm),
            ],
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: AspectRatio(
                  aspectRatio:
                      _stage == _Stage.recording || _stage == _Stage.opening
                      ? 3 / 4
                      : 1,
                  child: DecoratedBox(
                    key: AnimatedAvatarScreen.stageKey,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(KRadius.lg),
                      border: Border.all(color: palette.border),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(KRadius.lg),
                      child: CustomPaint(
                        // The transparency checkerboard: two greys that
                        // read in either theme.
                        painter: Theme.of(context).brightness == Brightness.dark
                            ? _Checkerboard(
                                light: const Color(0xFF2A2A31),
                                dark: const Color(0xFF3A3A43),
                              )
                            : _Checkerboard(
                                light: const Color(0xFFF4F4F6),
                                dark: const Color(0xFFDDDDE3),
                              ),
                        child: stage,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_stage == _Stage.recording) ...[
              const SizedBox(height: KSpacing.md),
              LinearProgressIndicator(value: (_progress * 2).clamp(0, 1)),
              const SizedBox(height: KSpacing.xs),
              Text(
                l10n.vipAnimatedAvatarRecording,
                textAlign: TextAlign.center,
                style: text.caption.copyWith(color: palette.textSecondary),
              ),
            ],
            if (_error case final error?) ...[
              const SizedBox(height: KSpacing.md),
              Text(
                error,
                key: AnimatedAvatarScreen.errorKey,
                textAlign: TextAlign.center,
                style: text.body.copyWith(color: palette.error),
              ),
            ],
            const SizedBox(height: KSpacing.xl),
            if (_stage == _Stage.preview)
              KButton(
                key: AnimatedAvatarScreen.saveKey,
                label: l10n.vipAnimatedAvatarSave,
                loading: _busy,
                onPressed: _busy ? null : () => unawaited(_save()),
              ),
            const SizedBox(height: KSpacing.sm),
            KButton(
              key: AnimatedAvatarScreen.recordKey,
              label: _stage == _Stage.preview || current != null
                  ? l10n.vipAnimatedAvatarRerecord
                  : l10n.vipAnimatedAvatarRecord,
              icon: Icons.videocam_outlined,
              variant: _stage == _Stage.preview
                  ? KButtonVariant.secondary
                  : KButtonVariant.primary,
              loading: working,
              onPressed: working || _busy ? null : () => unawaited(_record()),
            ),
            if (current != null && _stage == _Stage.idle) ...[
              const SizedBox(height: KSpacing.sm),
              KButton(
                key: AnimatedAvatarScreen.removeKey,
                label: l10n.vipAnimatedAvatarRemove,
                variant: KButtonVariant.destructive,
                loading: _busy,
                onPressed: _busy ? null : () => unawaited(_remove()),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const new({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0x99000000),
      borderRadius: BorderRadius.circular(KRadius.pill),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: KSpacing.md,
        vertical: KSpacing.xs,
      ),
      child: Text(
        text,
        style: context.textStyles.caption.copyWith(
          color: const Color(0xFFFFFFFF),
        ),
      ),
    ),
  );
}

/// The transparency checkerboard behind a cut-out.
class _Checkerboard extends CustomPainter {
  new({required this.light, required this.dark});

  final Color light;
  final Color dark;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = light);
    const cell = 12.0;
    final paint = Paint()..color = dark;
    for (var y = 0; y * cell < size.height; y++) {
      for (var x = y.isEven ? 0 : 1; x * cell < size.width; x += 2) {
        canvas.drawRect(Rect.fromLTWH(x * cell, y * cell, cell, cell), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_Checkerboard old) =>
      old.light != light || old.dark != dark;
}
