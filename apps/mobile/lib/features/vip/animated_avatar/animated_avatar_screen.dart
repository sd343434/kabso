// v1.136-social (D384, CONVENTIONS §10.173): «صورة متحركة» — the member
// records 3 s with the front camera, or picks a video from the gallery and
// keeps 3 s of it (owner 2026-11-12: «both»); the phone removes the
// background, the cut-out plays as a preview over a checkerboard, then save
// (upload), record or pick again, or remove the saved clip.

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
import 'package:kabso_live/features/vip/animated_avatar/cutout_frames.dart';
import 'package:kabso_live/features/vip/animated_avatar/cutout_gallery.dart';
import 'package:kabso_live/features/vip/animated_avatar/cutout_recorder.dart';
import 'package:kabso_live/features/vip/animated_avatar/cutout_strip_player.dart';
import 'package:kabso_live/features/vip/animated_avatar/cutout_trim.dart';
import 'package:kabso_live/features/vip/presentation/vip_cutout.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

enum _Stage { idle, opening, recording, trim, processing, preview }

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

  /// D384 (owner: «record and pick from the gallery»): the gallery button,
  /// the trim stage, its start slider, its range label and its buttons.
  static const pickKey = Key('vip.animatedAvatar.pick');
  static const trimKey = Key('vip.animatedAvatar.trim');
  static const trimSliderKey = Key('vip.animatedAvatar.trim.slider');
  static const trimRangeKey = Key('vip.animatedAvatar.trim.range');
  static const trimUseKey = Key('vip.animatedAvatar.trim.use');
  static const trimCancelKey = Key('vip.animatedAvatar.trim.cancel');

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

  /// D384: the picked video while it is trimmed, its start (ms) and the
  /// frame shown there.
  PickedClip? _clip;
  int _trimStart = 0;
  ImageProvider? _poster;
  int _posterAsk = 0;

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
      await _compose(frames);
    } on CutoutNoPersonException {
      _fail(l10n.vipAnimatedAvatarNoPerson);
    } on CutoutTooLargeException {
      _fail(l10n.vipAnimatedAvatarTooLarge);
    } on CutoutCameraException {
      _fail(l10n.vipAnimatedAvatarCameraError);
    }
  }

  /// The frames (either path) into the strip and its preview.
  Future<void> _compose(List<CutoutFrame> frames) async {
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
      _clip = null;
      _stage = _Stage.preview;
    });
  }

  /// D384: picks a video, then the trim stage (3 s of it).
  Future<void> _pick() async {
    final l10n = context.l10n;
    setState(() => _error = null);
    try {
      final clip = await ref.read(cutoutGalleryProvider).pick();
      if (clip == null || !mounted) return;
      setState(() {
        _clip = clip;
        _trimStart = 0;
        _poster = null;
        _stage = _Stage.trim;
      });
      unawaited(_loadPoster());
    } on CutoutClipException {
      _fail(l10n.vipAnimatedAvatarPickError);
    }
  }

  /// The frame at the trim's start (the latest request wins).
  Future<void> _loadPoster() async {
    final clip = _clip;
    if (clip == null) return;
    final ask = ++_posterAsk;
    final at = trimWindow(clip.durationMs, _trimStart).startMs;
    final poster = await ref.read(cutoutGalleryProvider).frameAt(clip, at);
    if (!mounted || ask != _posterAsk) return;
    setState(() => _poster = poster);
  }

  /// D384: the kept 3 s → frames (15 a second) → the same cut-out as a
  /// recording.
  Future<void> _useTrim() async {
    final clip = _clip;
    if (clip == null) return;
    final l10n = context.l10n;
    setState(() {
      _stage = _Stage.processing;
      _error = null;
      _progress = 0;
    });
    try {
      final frames = await ref
          .read(cutoutGalleryProvider)
          .frames(
            clip,
            _trimStart,
            onProgress: (p) {
              if (mounted) setState(() => _progress = p);
            },
          );
      await _compose(frames);
    } on CutoutNoPersonException {
      _fail(l10n.vipAnimatedAvatarNoPerson);
    } on CutoutTooLargeException {
      _fail(l10n.vipAnimatedAvatarTooLarge);
    } on CutoutClipException {
      _fail(l10n.vipAnimatedAvatarPickError);
    }
  }

  void _cancelTrim() => setState(() {
    _clip = null;
    _poster = null;
    _stage = _strip == null ? _Stage.idle : _Stage.preview;
  });

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _clip = null;
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
      _Stage.trim => KeyedSubtree(
        key: AnimatedAvatarScreen.trimKey,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Color(0xFF15171C)),
            if (_poster case final poster?)
              Image(
                image: poster,
                fit: BoxFit.contain,
                gaplessPlayback: true,
                excludeFromSemantics: true,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
          ],
        ),
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
                      _stage == _Stage.recording ||
                          _stage == _Stage.opening ||
                          _stage == _Stage.trim
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
            if (_stage == _Stage.trim && _clip != null)
              _TrimPanel(
                clip: _clip!,
                startMs: _trimStart,
                onChanged: (ms) => setState(() => _trimStart = ms),
                onChangeEnd: (_) => unawaited(_loadPoster()),
                onUse: () => unawaited(_useTrim()),
                onCancel: _cancelTrim,
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
            if (_stage != _Stage.trim) ...[
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
              // D384 (owner: «both»): a video from the gallery, 3 s of it.
              const SizedBox(height: KSpacing.sm),
              KButton(
                key: AnimatedAvatarScreen.pickKey,
                label: l10n.vipAnimatedAvatarPick,
                icon: Icons.video_library_outlined,
                variant: KButtonVariant.secondary,
                onPressed: working || _busy ? null : () => unawaited(_pick()),
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

/// D384: keep 3 s of a picked video — a start slider over its length, the
/// kept range (`m:ss.d – m:ss.d`), then «استخدام هذا الجزء» or «إلغاء». A
/// video of 3 s or less is kept whole (no slider to move).
class _TrimPanel extends StatelessWidget {
  const new({
    required this.clip,
    required this.startMs,
    required this.onChanged,
    required this.onChangeEnd,
    required this.onUse,
    required this.onCancel,
  });

  final PickedClip clip;
  final int startMs;
  final ValueChanged<int> onChanged;
  final ValueChanged<int> onChangeEnd;
  final VoidCallback onUse;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.textStyles;
    final palette = context.palette;
    final window = trimWindow(clip.durationMs, startMs);
    final maxStart = maxTrimStartMs(clip.durationMs);
    final end = window.startMs + window.lengthMs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: KSpacing.md),
        Text(
          l10n.vipAnimatedAvatarTrimTitle,
          textAlign: TextAlign.center,
          style: text.label.copyWith(color: palette.textPrimary),
        ),
        Slider(
          key: AnimatedAvatarScreen.trimSliderKey,
          max: maxStart <= 0 ? 1 : maxStart.toDouble(),
          value: maxStart <= 0 ? 0 : window.startMs.toDouble(),
          onChanged: maxStart <= 0 ? null : (v) => onChanged(v.round()),
          onChangeEnd: maxStart <= 0 ? null : (v) => onChangeEnd(v.round()),
        ),
        // Times read left to right in both languages.
        Text(
          '\u2066${trimTimeLabel(window.startMs)} – '
          '${trimTimeLabel(end)}\u2069',
          key: AnimatedAvatarScreen.trimRangeKey,
          textAlign: TextAlign.center,
          style: text.body.copyWith(color: palette.textPrimary),
        ),
        const SizedBox(height: KSpacing.xs),
        Text(
          maxStart <= 0
              ? l10n.vipAnimatedAvatarTrimWhole
              : l10n.vipAnimatedAvatarTrimHint,
          textAlign: TextAlign.center,
          style: text.caption.copyWith(color: palette.textSecondary),
        ),
        const SizedBox(height: KSpacing.lg),
        KButton(
          key: AnimatedAvatarScreen.trimUseKey,
          label: l10n.vipAnimatedAvatarTrimUse,
          onPressed: onUse,
        ),
        const SizedBox(height: KSpacing.sm),
        KButton(
          key: AnimatedAvatarScreen.trimCancelKey,
          label: l10n.vipAnimatedAvatarTrimCancel,
          variant: KButtonVariant.ghost,
          onPressed: onCancel,
        ),
      ],
    );
  }
}
