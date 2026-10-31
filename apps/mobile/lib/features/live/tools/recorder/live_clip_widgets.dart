import 'dart:async';
import 'dart:io' show File;

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/data/live_media_extras.dart';
import 'package:kabso_live/features/live/tools/live_tool_parts.dart';
import 'package:kabso_live/features/live/tools/recorder/live_clip_controller.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';
import 'package:video_player/video_player.dart';

/// D201 «التسجيل»: the tile. Recording → stops it; otherwise the sheet that
/// explains the clip (or why it cannot be recorded here) with «ابدأ التسجيل».
Future<void> showLiveClipRecorder(
  BuildContext context,
  WidgetRef ref, {
  required String roomId,
  required Object engine,
}) async {
  final controller = ref.read(liveClipProvider(roomId).notifier);
  if (ref.read(liveClipProvider(roomId)).phase == LiveClipPhase.recording) {
    await _guard(context, controller.stop);
    return;
  }
  final capture = engine is LiveClipCapture ? engine : null;
  await showLiveToolSheet<void>(
    context,
    builder: (sheet) => LiveClipStartSheet(
      unsupported: capture == null
          ? LiveClipUnsupported.web
          : capture.clipUnsupported,
      onStart: () async {
        Navigator.of(sheet).pop();
        await _guard(context, () => controller.start(capture!));
      },
    ),
  );
}

Future<void> _guard(BuildContext context, Future<void> Function() run) async {
  final l10n = context.l10n;
  try {
    await run();
  } on LiveClipException catch (e) {
    if (!context.mounted) return;
    KSnack.error(context, switch (e.problem) {
      LiveClipProblem.startFailed => l10n.liveClipFailed,
      LiveClipProblem.tooShort => l10n.liveClipTooShort,
      LiveClipProblem.unreadable => l10n.liveClipUnreadable,
    });
  }
}

class LiveClipStartSheet extends StatelessWidget {
  const new({required this.unsupported, required this.onStart, super.key});

  final LiveClipUnsupported? unsupported;
  final VoidCallback onStart;

  static const sheetKey = Key('clip.sheet');
  static const startKey = Key('clip.start');
  static const unsupportedKey = Key('clip.unsupported');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final reason = unsupported;
    return LiveToolSheetBody(
      key: sheetKey,
      title: l10n.liveClipTitle,
      children: [
        if (reason != null)
          LiveToolNote(
            key: unsupportedKey,
            icon: Icons.info_outline_rounded,
            text: switch (reason) {
              LiveClipUnsupported.ios => l10n.liveClipUnsupportedIos,
              LiveClipUnsupported.web => l10n.liveClipUnsupportedWeb,
              LiveClipUnsupported.noCamera => l10n.liveClipNoCamera,
            },
          )
        else ...[
          LiveToolNote(icon: Icons.timer_outlined, text: l10n.liveClipIntro),
          const SizedBox(height: KSpacing.sm),
          LiveToolNote(
            icon: Icons.visibility_outlined,
            text: l10n.liveClipTransparency,
          ),
          const SizedBox(height: KSpacing.sm),
          LiveToolNote(
            icon: Icons.layers_clear_outlined,
            text: l10n.liveClipLimits,
          ),
          const SizedBox(height: KSpacing.lg),
          KButton(
            key: startKey,
            label: l10n.liveClipStart,
            icon: Icons.fiber_manual_record_rounded,
            variant: KButtonVariant.destructive,
            onPressed: onStart,
          ),
        ],
      ],
    );
  }
}

/// The host's REC indicator over the stage while recording: the elapsed
/// time, the seconds left of 60 and Stop. When the clip is ready it opens the
/// preview.
class LiveClipRecBadge extends ConsumerWidget {
  const new({required this.roomId, super.key});

  final String roomId;

  static const badgeKey = Key('clip.rec');
  static const stopKey = Key('clip.stop');
  static const remainingKey = Key('clip.remaining');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(liveClipProvider(roomId).select((s) => s.phase), (
      before,
      phase,
    ) {
      if (phase == LiveClipPhase.ready && before != LiveClipPhase.posting) {
        unawaited(showLiveClipPreview(context, roomId: roomId));
      }
    });
    final state = ref.watch(liveClipProvider(roomId));
    if (state.phase != LiveClipPhase.recording &&
        state.phase != LiveClipPhase.stopping) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final t = context.textStyles;
    final left = state.remaining.inSeconds;
    return Semantics(
      liveRegion: true,
      label: l10n.liveClipRecSemantics(left),
      child: Container(
        key: badgeKey,
        padding: const EdgeInsetsDirectional.fromSTEB(10, 4, 4, 4),
        decoration: BoxDecoration(
          color: const Color(0xCC000000),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _Blink(),
            const SizedBox(width: 6),
            Text(
              l10n.liveClipRec,
              style: t.label.copyWith(color: const Color(0xFFFFFFFF)),
            ),
            const SizedBox(width: 6),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                liveToolClock(state.elapsed),
                style: t.label.copyWith(
                  color: const Color(0xFFFFFFFF),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              key: remainingKey,
              width: 30,
              height: 30,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value:
                        state.remaining.inMilliseconds /
                        liveClipMax.inMilliseconds,
                    strokeWidth: 2.5,
                    color: LiveToolColors.rec,
                    backgroundColor: const Color(0x33FFFFFF),
                  ),
                  Text(
                    '$left',
                    style: t.caption.copyWith(
                      color: const Color(0xFFFFFFFF),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              key: stopKey,
              tooltip: l10n.liveClipStop,
              style: IconButton.styleFrom(
                backgroundColor: LiveToolColors.rec,
                foregroundColor: const Color(0xFFFFFFFF),
                minimumSize: const Size(36, 36),
                tapTargetSize: MaterialTapTargetSize.padded,
              ),
              onPressed: state.phase == LiveClipPhase.recording
                  ? () => unawaited(
                      _guard(
                        context,
                        ref.read(liveClipProvider(roomId).notifier).stop,
                      ),
                    )
                  : null,
              icon: const Icon(Icons.stop_rounded, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

class _Blink extends StatefulWidget {
  const new();

  @override
  State<_Blink> createState() => _BlinkState();
}

class _BlinkState extends State<_Blink> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.value = 1;
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween<double>(begin: 0.35, end: 1).animate(_c),
    child: Container(
      width: 10,
      height: 10,
      decoration: const BoxDecoration(
        color: LiveToolColors.rec,
        shape: BoxShape.circle,
      ),
    ),
  );
}

/// The clip's preview: play it, then «حفظ في الجهاز», «نشر كريلز» (with a
/// caption) or «تجاهل».
Future<void> showLiveClipPreview(
  BuildContext context, {
  required String roomId,
}) => showLiveToolSheet<void>(
  context,
  builder: (_) => LiveClipPreviewSheet(roomId: roomId),
);

class LiveClipPreviewSheet extends ConsumerStatefulWidget {
  const new({required this.roomId, this.player, super.key});

  final String roomId;

  /// A seam for tests (no platform player there).
  final Widget? player;

  static const sheetKey = Key('clip.preview');
  static const saveKey = Key('clip.save');
  static const postKey = Key('clip.post');
  static const discardKey = Key('clip.discard');
  static const captionKey = Key('clip.caption');
  static const progressKey = Key('clip.progress');

  @override
  ConsumerState<LiveClipPreviewSheet> createState() => _PreviewState();
}

class _PreviewState extends ConsumerState<LiveClipPreviewSheet> {
  final _caption = TextEditingController();
  VideoPlayerController? _player;
  bool _saving = false;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    final clip = ref.read(liveClipProvider(widget.roomId)).clip;
    if (clip != null && widget.player == null) {
      final player = VideoPlayerController.file(File(clip.path));
      _player = player;
      unawaited(
        player
            .initialize()
            .then((_) async {
              await player.setLooping(true);
              await player.play();
              if (mounted) setState(() {});
            })
            .catchError((Object _) {}),
      );
    }
  }

  @override
  void dispose() {
    _caption.dispose();
    unawaited(_player?.dispose());
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    setState(() => _saving = true);
    try {
      await ref.read(liveClipProvider(widget.roomId).notifier).save();
      if (!mounted) return;
      setState(() => _saved = true);
      KSnack.success(context, l10n.liveClipSaved);
    } on Object {
      if (mounted) KSnack.error(context, l10n.liveClipSaveFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _post() async {
    final l10n = context.l10n;
    final navigator = Navigator.of(context);
    try {
      final review = await ref
          .read(liveClipProvider(widget.roomId).notifier)
          .postReel(_caption.text);
      if (!mounted) return;
      KSnack.success(
        context,
        review ? l10n.reelSharedInReview : l10n.reelShared,
      );
      navigator.pop();
    } on Object {
      if (mounted) KSnack.error(context, l10n.liveClipPostFailed);
    }
  }

  Future<void> _discard() async {
    final navigator = Navigator.of(context);
    await ref.read(liveClipProvider(widget.roomId).notifier).discard();
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final state = ref.watch(liveClipProvider(widget.roomId));
    final clip = state.clip;
    final posting = state.phase == LiveClipPhase.posting;
    final player = _player;
    final video =
        widget.player ??
        (player != null && player.value.isInitialized
            ? FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: player.value.size.width,
                  height: player.value.size.height,
                  child: VideoPlayer(player),
                ),
              )
            : (clip?.poster != null
                  ? Image.memory(clip!.poster!, fit: BoxFit.cover)
                  : const ColoredBox(color: Color(0xFF15171C))));
    return LiveToolSheetBody(
      key: LiveClipPreviewSheet.sheetKey,
      title: l10n.liveClipPreviewTitle,
      children: [
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: 180,
              height: 320,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  video,
                  PositionedDirectional(
                    bottom: 8,
                    end: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x99000000),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        liveToolClock(clip?.length ?? Duration.zero),
                        textDirection: TextDirection.ltr,
                        style: t.caption.copyWith(
                          color: const Color(0xFFFFFFFF),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: KSpacing.md),
        KTextField(
          key: LiveClipPreviewSheet.captionKey,
          controller: _caption,
          label: l10n.liveClipCaption,
          enabled: !posting,
          maxLength: 500,
        ),
        if (posting) ...[
          const SizedBox(height: KSpacing.sm),
          LinearProgressIndicator(
            key: LiveClipPreviewSheet.progressKey,
            value: state.progress,
            color: LiveToolColors.accent,
          ),
        ],
        const SizedBox(height: KSpacing.md),
        KButton(
          key: LiveClipPreviewSheet.postKey,
          label: l10n.liveClipPostReel,
          icon: Icons.movie_filter_outlined,
          loading: posting,
          onPressed: clip == null || posting ? null : () => unawaited(_post()),
        ),
        const SizedBox(height: KSpacing.sm),
        KButton(
          key: LiveClipPreviewSheet.saveKey,
          label: _saved ? l10n.liveClipSavedShort : l10n.liveClipSave,
          icon: _saved ? Icons.check_rounded : Icons.download_rounded,
          variant: KButtonVariant.secondary,
          loading: _saving,
          onPressed: clip == null || posting || _saved
              ? null
              : () => unawaited(_save()),
        ),
        const SizedBox(height: KSpacing.sm),
        KButton(
          key: LiveClipPreviewSheet.discardKey,
          label: l10n.liveClipDiscard,
          icon: Icons.delete_outline_rounded,
          variant: KButtonVariant.ghost,
          onPressed: posting ? null : () => unawaited(_discard()),
        ),
      ],
    );
  }
}

/// D201: the viewers' «يتم التسجيل» while the host records (the host's
/// `kabso.recordingUntil`); it hides itself at that time.
class LiveRecordingViewerBadge extends StatefulWidget {
  const new({required this.attributes, super.key});

  final Map<String, String> attributes;

  static const badgeKey = Key('room.recording');

  @override
  State<LiveRecordingViewerBadge> createState() => _ViewerBadgeState();
}

class _ViewerBadgeState extends State<LiveRecordingViewerBadge> {
  Timer? _hide;

  void _schedule() {
    _hide?.cancel();
    final until = DateTime.tryParse(
      widget.attributes[liveAttrRecordingUntil] ?? '',
    );
    if (until == null) return;
    final left = until.difference(clock.now());
    if (left.isNegative) return;
    _hide = Timer(left, () {
      if (mounted) setState(() {});
    });
  }

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(LiveRecordingViewerBadge old) {
    super.didUpdateWidget(old);
    _schedule();
  }

  @override
  void dispose() {
    _hide?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!liveRecordingNow(widget.attributes, clock.now())) {
      return const SizedBox.shrink();
    }
    final t = context.textStyles;
    return Container(
      key: LiveRecordingViewerBadge.badgeKey,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0x99000000),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _Blink(),
          const SizedBox(width: 6),
          Text(
            context.l10n.liveClipViewerBadge,
            style: t.label.copyWith(color: const Color(0xFFFFFFFF)),
          ),
        ],
      ),
    );
  }
}
