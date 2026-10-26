import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_audio_room.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// A voice clip in the live chat (CP-017): a compact play / pause pill with
/// the clip's length. The player starts on the first tap.
class LiveVoiceClipPill extends StatefulWidget {
  const new({required this.media, super.key});

  final LiveChatMedia media;

  static Key keyFor(String mediaId) => Key('liveChat.voice.$mediaId');

  /// Makes the player (tests replace it).
  @visibleForTesting
  static AudioPlayer Function() newPlayer = AudioPlayer.new;

  @override
  State<LiveVoiceClipPill> createState() => _LiveVoiceClipPillState();
}

class _LiveVoiceClipPillState extends State<LiveVoiceClipPill> {
  AudioPlayer? _player;
  StreamSubscription<void>? _done;
  bool _playing = false;
  bool _started = false;

  @override
  void dispose() {
    unawaited(_done?.cancel());
    unawaited(_player?.dispose());
    super.dispose();
  }

  Future<void> _toggle() async {
    try {
      final player = _player ??= LiveVoiceClipPill.newPlayer();
      _done ??= player.onPlayerComplete.listen((_) {
        if (mounted) {
          setState(() {
            _playing = false;
            _started = false;
          });
        }
      });
      if (_playing) {
        setState(() => _playing = false);
        await player.pause();
      } else {
        setState(() => _playing = true);
        if (_started) {
          await player.resume();
        } else {
          _started = true;
          await player.play(UrlSource(widget.media.url));
        }
      }
    } on Object {
      // No player here, or the clip could not be loaded (gone, or not
      // served as audio): back to idle, and say so instead of staying
      // silent.
      if (mounted) {
        setState(() {
          _playing = false;
          _started = false;
        });
        KSnack.error(context, context.l10n.liveVoicePlayFailed);
      }
      final player = _player;
      _player = null;
      unawaited(_done?.cancel());
      _done = null;
      unawaited(player?.dispose().then((_) {}, onError: (Object _) {}));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final length = KFormat.countdown(
      Duration(milliseconds: widget.media.durationMs ?? 0),
    );
    return Semantics(
      button: true,
      label: '${_playing ? l10n.liveChatPause : l10n.liveChatPlay}, $length',
      onTap: () => unawaited(_toggle()),
      excludeSemantics: true,
      child: GestureDetector(
        key: LiveVoiceClipPill.keyFor(widget.media.id),
        behavior: HitTestBehavior.opaque,
        onTap: () => unawaited(_toggle()),
        child: Container(
          height: 28,
          padding: const EdgeInsetsDirectional.only(start: 4, end: 10),
          decoration: BoxDecoration(
            color: const Color(0x33FFFFFF),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: KAudioRoom.text,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 16,
                  color: LiveChatComposer.sendOn,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.graphic_eq_rounded,
                size: 16,
                color: KAudioRoom.textSoft,
              ),
              const SizedBox(width: 6),
              Text(
                length,
                textDirection: TextDirection.ltr,
                style: context.textStyles.caption.copyWith(
                  fontSize: 12,
                  color: KAudioRoom.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A picture in the live chat (CP-017): a small rounded thumbnail; a tap
/// shows it larger.
class LiveChatPictureThumb extends StatelessWidget {
  const new({required this.media, super.key});

  final LiveChatMedia media;

  static Key keyFor(String mediaId) => Key('liveChat.picture.$mediaId');
  static const viewerKey = Key('liveChat.picture.viewer');

  /// The thumbnail's long side.
  static const size = 84.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final aspect = media.width > 0 && media.height > 0
        ? (media.width / media.height).clamp(0.6, 1.6)
        : 1.0;
    final width = aspect >= 1 ? size : size * aspect;
    final height = aspect >= 1 ? size / aspect : size;
    return Semantics(
      button: true,
      image: true,
      label: l10n.liveChatPicture,
      onTap: () => unawaited(_open(context)),
      excludeSemantics: true,
      child: GestureDetector(
        key: keyFor(media.id),
        onTap: () => unawaited(_open(context)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: width,
            height: height,
            child: Image.network(
              media.thumbUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const _PicturePlaceholder(),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context) => showDialog<void>(
    context: context,
    builder: (dialog) => Dialog(
      key: viewerKey,
      backgroundColor: const Color(0xFF000000),
      insetPadding: const EdgeInsets.all(16),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Stack(
        children: [
          InteractiveViewer(
            child: Image.network(
              media.url,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const AspectRatio(
                aspectRatio: 1,
                child: _PicturePlaceholder(),
              ),
            ),
          ),
          PositionedDirectional(
            top: 4,
            end: 4,
            child: IconButton(
              tooltip: MaterialLocalizations.of(dialog).closeButtonTooltip,
              onPressed: () => Navigator.of(dialog).pop(),
              icon: const Icon(Icons.close_rounded, color: KAudioRoom.text),
            ),
          ),
        ],
      ),
    ),
  );
}

class _PicturePlaceholder extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: Color(0x33FFFFFF),
    child: Center(
      child: Icon(Icons.image_outlined, size: 24, color: KAudioRoom.textSoft),
    ),
  );
}
