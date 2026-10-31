import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/tools/live_tool_parts.dart';
import 'package:kabso_live/features/live/tools/music/live_music_controller.dart';
import 'package:kabso_live/features/live/tools/music/live_music_mixer.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D201 «موسيقى»: opens the player — after the one-time rights notice
/// (accepted once per account, recorded on the server). Where music cannot
/// be mixed (iOS, the web) the sheet says why instead.
Future<void> showLiveMusic(
  BuildContext context,
  WidgetRef ref, {
  required bool micEnabled,
}) async {
  final mixer = ref.read(liveMusicMixerProvider);
  if (mixer.unsupported == null) {
    final rights = ref.read(liveMusicRightsProvider.notifier);
    bool accepted;
    try {
      accepted = await rights.accepted();
    } on Object {
      if (context.mounted) KSnack.error(context, context.l10n.liveToolsFailed);
      return;
    }
    if (!context.mounted) return;
    if (!accepted) {
      final ok = await showLiveMusicRightsNotice(context);
      if (ok != true || !context.mounted) return;
      try {
        await rights.accept();
      } on Object {
        if (context.mounted) {
          KSnack.error(context, context.l10n.liveToolsFailed);
        }
        return;
      }
      if (!context.mounted) return;
    }
  }
  await showLiveToolSheet<void>(
    context,
    builder: (_) => LiveMusicSheet(micEnabled: micEnabled),
  );
}

/// The one-time notice; true when accepted.
Future<bool?> showLiveMusicRightsNotice(BuildContext context) =>
    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final l10n = context.l10n;
        final t = context.textStyles;
        return LiveToolLightTheme(
          child: AlertDialog(
            key: LiveMusicSheet.rightsKey,
            backgroundColor: const Color(0xFFFFFFFF),
            icon: const Icon(
              Icons.copyright_rounded,
              color: LiveToolColors.accent,
              size: 36,
            ),
            title: Text(
              l10n.liveMusicRightsTitle,
              style: t.title.copyWith(color: LiveToolColors.ink),
            ),
            content: Text(
              l10n.liveMusicRightsBody,
              style: t.body.copyWith(color: LiveToolColors.ink, height: 1.5),
            ),
            actions: [
              TextButton(
                key: LiveMusicSheet.rightsCancelKey,
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.liveToolsCancel),
              ),
              FilledButton(
                key: LiveMusicSheet.rightsAcceptKey,
                style: FilledButton.styleFrom(
                  backgroundColor: LiveToolColors.accent,
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.liveMusicRightsAccept),
              ),
            ],
          ),
        );
      },
    );

/// The player: the queue, play / pause, next, the music's level, ducking.
class LiveMusicSheet extends ConsumerWidget {
  const new({required this.micEnabled, super.key});

  final bool micEnabled;

  static const sheetKey = Key('music.sheet');
  static const rightsKey = Key('music.rights');
  static const rightsAcceptKey = Key('music.rights.accept');
  static const rightsCancelKey = Key('music.rights.cancel');
  static const addKey = Key('music.add');
  static const playKey = Key('music.play');
  static const nextKey = Key('music.next');
  static const volumeKey = Key('music.volume');
  static const duckingKey = Key('music.ducking');
  static const unsupportedKey = Key('music.unsupported');
  static const emptyKey = Key('music.empty');
  static const micOffKey = Key('music.micOff');
  static Key itemKey(int i) => Key('music.item.$i');
  static Key removeKey(int i) => Key('music.remove.$i');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final unsupported = ref.watch(liveMusicMixerProvider).unsupported;
    if (unsupported != null) {
      return LiveToolSheetBody(
        key: sheetKey,
        title: l10n.liveToolMusic,
        children: [
          LiveToolNote(
            key: unsupportedKey,
            icon: Icons.info_outline_rounded,
            text: switch (unsupported) {
              LiveMusicUnsupported.ios => l10n.liveMusicUnsupportedIos,
              LiveMusicUnsupported.web => l10n.liveMusicUnsupportedWeb,
            },
          ),
        ],
      );
    }
    final state = ref.watch(liveMusicProvider);
    final music = ref.read(liveMusicProvider.notifier);
    Future<void> add() async {
      try {
        final left = await music.addFiles();
        if (left > 0 && context.mounted) {
          KSnack.info(
            context,
            l10n.liveMusicQueueFull(LiveMusicController.maxQueue),
          );
        }
      } on Object {
        if (context.mounted) KSnack.error(context, l10n.liveMusicUnreadable);
      }
    }

    final track = state.track;
    return LiveToolSheetBody(
      key: sheetKey,
      title: l10n.liveToolMusic,
      children: [
        if (!micEnabled) ...[
          LiveToolNote(
            key: micOffKey,
            icon: Icons.mic_off_rounded,
            text: l10n.liveMusicMicOff,
            warning: true,
          ),
          const SizedBox(height: KSpacing.sm),
        ],
        // Now playing and the controls.
        Container(
          padding: const EdgeInsets.all(KSpacing.md),
          decoration: BoxDecoration(
            color: LiveToolColors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.music_note_rounded,
                    color: LiveToolColors.accent,
                  ),
                  const SizedBox(width: KSpacing.sm),
                  Expanded(
                    child: Text(
                      track?.name ?? l10n.liveMusicNothing,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodyStrong.copyWith(color: LiveToolColors.ink),
                    ),
                  ),
                  if (track != null)
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        [
                          liveToolClock(state.position),
                          if (state.duration case final d?) liveToolClock(d),
                        ].join(' / '),
                        style: t.caption.copyWith(color: LiveToolColors.soft),
                      ),
                    ),
                ],
              ),
              if (state.failed) ...[
                const SizedBox(height: KSpacing.xs),
                Text(
                  l10n.liveMusicUnreadable,
                  style: t.caption.copyWith(color: const Color(0xFFD93B4F)),
                ),
              ],
              const SizedBox(height: KSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filled(
                    key: playKey,
                    iconSize: 32,
                    style: IconButton.styleFrom(
                      backgroundColor: LiveToolColors.accent,
                      foregroundColor: const Color(0xFFFFFFFF),
                      minimumSize: const Size(56, 56),
                    ),
                    tooltip: state.playing
                        ? l10n.liveMusicPause
                        : l10n.liveMusicPlay,
                    onPressed: state.queue.isEmpty
                        ? null
                        : () => unawaited(music.toggle()),
                    icon: Icon(
                      state.playing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
                  ),
                  const SizedBox(width: KSpacing.md),
                  IconButton(
                    key: nextKey,
                    iconSize: 28,
                    style: IconButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    color: LiveToolColors.ink,
                    tooltip: l10n.liveMusicNext,
                    onPressed: track == null
                        ? null
                        : () => unawaited(music.next()),
                    // Next follows the reading direction.
                    icon: const Icon(Icons.skip_next_rounded),
                  ),
                ],
              ),
              const SizedBox(height: KSpacing.xs),
              Row(
                children: [
                  const Icon(
                    Icons.volume_down_rounded,
                    color: LiveToolColors.soft,
                    size: 20,
                  ),
                  Expanded(
                    child: Semantics(
                      label: l10n.liveMusicVolume,
                      child: Slider(
                        key: volumeKey,
                        value: state.volume,
                        activeColor: LiveToolColors.accent,
                        label: '${(state.volume * 100).round()}%',
                        divisions: 20,
                        onChanged: (v) => unawaited(music.setVolume(v)),
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.volume_up_rounded,
                    color: LiveToolColors.soft,
                    size: 20,
                  ),
                ],
              ),
              Text(
                l10n.liveMusicVolume,
                textAlign: TextAlign.center,
                style: t.caption.copyWith(color: LiveToolColors.soft),
              ),
            ],
          ),
        ),
        SwitchListTile.adaptive(
          key: duckingKey,
          contentPadding: EdgeInsets.zero,
          value: state.ducking,
          activeTrackColor: LiveToolColors.accent,
          title: Text(
            l10n.liveMusicDucking,
            style: t.body.copyWith(color: LiveToolColors.ink),
          ),
          onChanged: (on) => unawaited(music.setDucking(on: on)),
        ),
        // The queue.
        if (state.queue.isEmpty)
          Padding(
            key: emptyKey,
            padding: const EdgeInsets.symmetric(vertical: KSpacing.sm),
            child: Text(
              l10n.liveMusicEmpty,
              style: t.body.copyWith(color: LiveToolColors.soft),
            ),
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: state.queue.length,
              itemBuilder: (context, i) {
                final selected = i == state.current;
                return ListTile(
                  key: itemKey(i),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  selected: selected,
                  selectedColor: LiveToolColors.accent,
                  leading: Icon(
                    selected && state.playing
                        ? Icons.graphic_eq_rounded
                        : Icons.audio_file_outlined,
                  ),
                  title: Text(
                    state.queue[i].name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.body.copyWith(
                      color: selected
                          ? LiveToolColors.accent
                          : LiveToolColors.ink,
                    ),
                  ),
                  onTap: () => unawaited(music.playAt(i)),
                  trailing: IconButton(
                    key: removeKey(i),
                    tooltip: l10n.liveMusicRemove,
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => unawaited(music.remove(i)),
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: KSpacing.sm),
        KButton(
          key: addKey,
          label: l10n.liveMusicAdd,
          icon: Icons.library_music_outlined,
          variant: KButtonVariant.secondary,
          onPressed: state.queue.length >= LiveMusicController.maxQueue
              ? null
              : () => unawaited(add()),
        ),
        const SizedBox(height: KSpacing.sm),
        LiveToolNote(
          icon: Icons.privacy_tip_outlined,
          text: l10n.liveMusicPickerNote,
        ),
        const SizedBox(height: KSpacing.xs),
        LiveToolNote(
          icon: Icons.headphones_rounded,
          text: l10n.liveMusicMixNote,
        ),
      ],
    );
  }
}
