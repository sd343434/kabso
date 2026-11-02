import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/application/live_streamer_host.dart';
import 'package:kabso_live/features/live/data/streamer/live_screen_share.dart';
import 'package:kabso_live/features/live/data/streamer/live_streamer_platform.dart';
import 'package:kabso_live/features/live/domain/live_streamer.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_glass.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_interruption.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

// D213 (v1.56-live, CONVENTIONS §10.86) «بث ستريمر»: the host's phone screen
// with a small round front-camera bubble at a corner the host picks.

/// Sizes of the streamer's pieces.
abstract final class KStreamer {
  /// The camera bubble: 28 % of the screen picture's short side, between
  /// 56 and 96 dp, with a 2.5 dp white ring, 10 dp from the picture's edge.
  static double bubbleFor(Size picture) =>
      (math.min(picture.width, picture.height) * 0.28).clamp(56, 96);
  static const double ring = 2.5;
  static const double bubbleInset = 10;

  /// A phone screen's shape (portrait), for the picture's box before the
  /// first frame tells the real one.
  static const double phoneAspect = 9 / 19.5;

  /// The room's chrome over a viewer's picture: the host pill and chips
  /// (below the status bar) and the chat and bar at the bottom.
  static const double roomTop = 96;
  static const double roomBottom = 200;

  /// The setup's corner picker: a 40 × 70 dp phone with four 24 dp dots.
  static const Size pickerPhone = Size(40, 70);
}

String _cornerLabel(AppLocalizations l10n, StreamerCorner c) => switch (c) {
  StreamerCorner.topLeft => l10n.streamerCornerTopLeft,
  StreamerCorner.topRight => l10n.streamerCornerTopRight,
  StreamerCorner.bottomLeft => l10n.streamerCornerBottomLeft,
  StreamerCorner.bottomRight => l10n.streamerCornerBottomRight,
};

/// The bubble's place inside a [box] (physical: the screen picture is never
/// mirrored for Arabic).
Offset streamerBubbleOffset(StreamerCorner corner, Size box, double size) {
  const inset = KStreamer.bubbleInset;
  final x = corner.left ? inset : box.width - size - inset;
  final y = corner.top ? inset : box.height - size - inset;
  return Offset(math.max(0, x), math.max(0, y));
}

/// Where the viewer's bubble may sit: the [picture] minus the room's chrome
/// ([top] from the box's top, [bottom] from its bottom); the whole picture
/// when too little is left for the bubble (a short landscape picture sits
/// between them anyway).
Rect streamerBubbleArea(
  Rect picture,
  Size box, {
  required double top,
  required double bottom,
  required double bubble,
}) {
  final area = Rect.fromLTRB(
    picture.left,
    math.max(picture.top, top),
    picture.right,
    math.min(picture.bottom, box.height - bottom),
  );
  return area.height < bubble + 2 * KStreamer.bubbleInset ? picture : area;
}

/// The screen picture's rect in a [box]: the host's phone screen fitted
/// (contain) by its orientation — a landscape game is letterboxed in the
/// portrait room.
Rect streamerPictureRect(Size box, {required bool landscape}) {
  final aspect = landscape ? 1 / KStreamer.phoneAspect : KStreamer.phoneAspect;
  var w = box.width;
  var h = w / aspect;
  if (h > box.height) {
    h = box.height;
    w = h * aspect;
  }
  return Rect.fromLTWH((box.width - w) / 2, (box.height - h) / 2, w, h);
}

/// The round camera bubble: [camera] cover-fit in a circle with a white
/// ring and a soft shadow.
class StreamerBubble extends StatelessWidget {
  const new({required this.camera, required this.size, super.key});

  final Widget camera;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      color: Color(0xFF1B1B1F),
      boxShadow: [
        BoxShadow(
          color: Color(0x66000000),
          blurRadius: 10,
          offset: Offset(0, 3),
        ),
      ],
    ),
    foregroundDecoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: const Color(0xFFFFFFFF), width: KStreamer.ring),
    ),
    child: ClipOval(child: SizedBox.expand(child: camera)),
  );
}

/// The setup's corner picker: a small phone with a dot at each corner (the
/// chosen one red). Physical corners (left is left in Arabic too).
class StreamerCornerPicker extends StatelessWidget {
  const new({required this.selected, required this.onSelect, super.key});

  final StreamerCorner selected;
  final ValueChanged<StreamerCorner>? onSelect;

  static Key cornerKey(StreamerCorner c) => Key('streamer.corner.${c.wire}');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    const phone = KStreamer.pickerPhone;
    const dot = 24.0;
    Widget corner(StreamerCorner c) {
      final on = c == selected;
      return Positioned(
        left: c.left ? -dot / 2 + 6 : null,
        right: c.left ? null : -dot / 2 + 6,
        top: c.top ? -dot / 2 + 6 : null,
        bottom: c.top ? null : -dot / 2 + 6,
        child: Semantics(
          button: true,
          selected: on,
          label: _cornerLabel(l10n, c),
          excludeSemantics: true,
          child: GestureDetector(
            key: cornerKey(c),
            behavior: HitTestBehavior.opaque,
            onTap: onSelect == null ? null : () => onSelect!(c),
            child: Container(
              width: dot,
              height: dot,
              alignment: Alignment.center,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: on ? 14 : 9,
                height: on ? 14 : 9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: on
                      ? KBrandColors.red500
                      : const Color(0xFFFFFFFF).withValues(alpha: 0.45),
                  border: on
                      ? Border.all(color: const Color(0xFFFFFFFF), width: 1.5)
                      : null,
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Physical corners: never mirrored by the reading direction.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        width: phone.width + dot,
        height: phone.height + dot,
        child: Center(
          child: SizedBox(
            width: phone.width,
            height: phone.height,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFFFFFFF).withValues(alpha: 0.7),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                for (final c in StreamerCorner.values) corner(c),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A switch row of the streamer's setup card.
class _SwitchRow extends StatelessWidget {
  const new({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.icon,
    this.note,
    this.keyName,
  });

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final IconData icon;
  final String? note;
  final String? keyName;

  @override
  Widget build(BuildContext context) {
    final text = context.textStyles;
    const white = Color(0xFFFFFFFF);
    return MergeSemantics(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: KSizes.minTouchTarget),
        child: Row(
          children: [
            Icon(icon, color: white, size: 20),
            const SizedBox(width: KSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: text.bodyStrong.copyWith(color: white, fontSize: 14),
                  ),
                  if (note case final n?)
                    Text(
                      n,
                      style: text.caption.copyWith(
                        color: white.withValues(alpha: 0.72),
                        fontSize: 11.5,
                        height: 1.3,
                      ),
                    ),
                ],
              ),
            ),
            Switch(
              key: keyName == null ? null : Key(keyName!),
              value: value,
              onChanged: onChanged,
              activeThumbColor: white,
              activeTrackColor: KBrandColors.red500,
            ),
          ],
        ),
      ),
    );
  }
}

/// D213: the streamer's setup (under the title card): what viewers will
/// see, the camera bubble and its corner, the microphone and the game sound
/// (Android 10+; «بعض الألعاب تمنع التقاط صوتها»), and the privacy rule.
class GoLiveStreamerPanel extends StatelessWidget {
  const new({
    required this.host,
    required this.micOn,
    required this.onMic,
    required this.onCameraVisible,
    required this.onCorner,
    required this.onGameAudio,
    super.key,
  });

  final StreamerHostState host;
  final bool micOn;
  final VoidCallback? onMic;
  final ValueChanged<bool>? onCameraVisible;
  final ValueChanged<StreamerCorner>? onCorner;
  final ValueChanged<bool>? onGameAudio;

  static const panelKey = Key('goLive.streamer.panel');
  static const cameraKey = 'goLive.streamer.camera';
  static const micKey = 'goLive.streamer.mic';
  static const gameKey = 'goLive.streamer.game';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.textStyles;
    const white = Color(0xFFFFFFFF);
    final oldAndroid = !host.gameAudioPossible;
    return LiveGlass(
      key: panelKey,
      radius: 13,
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.screen_share_rounded, color: white, size: 20),
                const SizedBox(width: KSpacing.sm),
                Expanded(
                  child: Text(
                    l10n.streamerSetupBody,
                    style: text.caption.copyWith(
                      color: white,
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: KSpacing.xs),
          Row(
            children: [
              Expanded(
                child: _SwitchRow(
                  keyName: cameraKey,
                  icon: Icons.account_circle_outlined,
                  label: l10n.streamerCameraBubble,
                  note: host.cameraVisible
                      ? '${l10n.streamerCameraCorner}: '
                            '${_cornerLabel(l10n, host.corner)}'
                      : null,
                  value: host.cameraVisible,
                  onChanged: onCameraVisible,
                ),
              ),
              if (host.cameraVisible)
                StreamerCornerPicker(selected: host.corner, onSelect: onCorner),
            ],
          ),
          _SwitchRow(
            keyName: micKey,
            icon: micOn ? Icons.mic_rounded : Icons.mic_off_rounded,
            label: l10n.streamerMic,
            value: micOn,
            onChanged: onMic == null ? null : (_) => onMic!(),
          ),
          _SwitchRow(
            keyName: gameKey,
            icon: Icons.sports_esports_rounded,
            label: l10n.streamerGameAudio,
            note: oldAndroid
                ? l10n.streamerGameAudioOld
                : l10n.streamerGameAudioNote,
            value: host.gameAudioOn && !oldAndroid,
            onChanged: oldAndroid ? null : onGameAudio,
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 2, end: 6),
            child: Row(
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 14,
                  color: white.withValues(alpha: 0.72),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    l10n.streamerPrivacyNote,
                    style: text.caption.copyWith(
                      color: white.withValues(alpha: 0.72),
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A round toggle of the host's streamer stage.
class _StageToggle extends StatelessWidget {
  const new({
    required this.icon,
    required this.label,
    required this.on,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final bool on;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = context.textStyles;
    const white = Color(0xFFFFFFFF);
    return Semantics(
      button: true,
      toggled: on,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 72, minHeight: 64),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: on
                      ? white.withValues(alpha: 0.16)
                      : KBrandColors.red500,
                  border: Border.all(color: white.withValues(alpha: 0.3)),
                ),
                child: Icon(icon, color: white, size: 22),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.caption.copyWith(color: white, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// D213: the streamer host's own room background while on air. The screen
/// itself is not shown here (Kabso in front pauses it, and a preview of
/// the screen would film itself): the state of the stream, «اذهب إلى
/// اللعبة», the microphone, the game sound and the camera bubble — the
/// bubble preview sits at its corner and can be dragged to another one.
class StreamerHostStage extends StatelessWidget {
  const new({
    required this.host,
    required this.micOn,
    required this.camera,
    required this.onMic,
    required this.onGame,
    required this.onCamera,
    required this.onCorner,
    required this.onGoToGame,
    required this.onShareAgain,
    super.key,
  });

  final StreamerHostState host;
  final bool micOn;
  final Widget? camera;
  final VoidCallback? onMic;
  final VoidCallback? onGame;
  final VoidCallback? onCamera;
  final ValueChanged<StreamerCorner>? onCorner;
  final VoidCallback? onGoToGame;
  final VoidCallback? onShareAgain;

  static const stageKey = Key('streamer.host.stage');
  static const goToGameKey = Key('streamer.host.goToGame');
  static const shareAgainKey = Key('streamer.host.shareAgain');
  static const micKey = Key('streamer.host.mic');
  static const gameKey = Key('streamer.host.game');
  static const cameraKey = Key('streamer.host.camera');
  static const bubbleKey = Key('streamer.host.bubble');

  String _status(AppLocalizations l10n) {
    if (host.pauses.contains(StreamerPause.call)) {
      return l10n.streamerPausedCall;
    }
    if (host.pauses.contains(StreamerPause.screenOff)) {
      return l10n.streamerPausedScreenOff;
    }
    if (host.pauses.contains(StreamerPause.inApp)) {
      return l10n.streamerPausedInApp;
    }
    return l10n.streamerOnAir;
  }

  String? _game(AppLocalizations l10n) => switch (host.gameAudio) {
    StreamerGameAudio.ok =>
      host.gameMuted ? l10n.streamerGameMuted : l10n.streamerGameLive,
    StreamerGameAudio.unsupportedOs => l10n.streamerGameAudioOld,
    StreamerGameAudio.noProjection ||
    StreamerGameAudio.failed => l10n.streamerGameUnavailable,
    StreamerGameAudio.off || null => null,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.textStyles;
    const white = Color(0xFFFFFFFF);
    final game = _game(l10n);
    final padding = MediaQuery.paddingOf(context);
    return DecoratedBox(
      key: stageKey,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A1020), Color(0xFF0B0B10), Color(0xFF15060A)],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          // The bubble moves over the area between the host pill and the
          // chat (the screen's shape on the host's phone).
          final area = Rect.fromLTRB(
            KSpacing.md,
            padding.top + 72,
            box.maxWidth - KSpacing.md,
            box.maxHeight - padding.bottom - 190,
          );
          final bubble = KStreamer.bubbleFor(area.size);
          final at = streamerBubbleOffset(host.corner, area.size, bubble);
          final status = Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (host.stopped) ...[
                const Icon(
                  Icons.stop_screen_share_rounded,
                  color: white,
                  size: 40,
                ),
                const SizedBox(height: KSpacing.sm),
                Text(
                  l10n.streamerStoppedTitle,
                  textAlign: TextAlign.center,
                  style: text.title.copyWith(color: white, fontSize: 18),
                ),
                const SizedBox(height: KSpacing.md),
                FilledButton.icon(
                  key: shareAgainKey,
                  onPressed: onShareAgain,
                  style: FilledButton.styleFrom(
                    backgroundColor: KBrandColors.red500,
                    foregroundColor: white,
                    minimumSize: const Size(0, KSizes.minTouchTarget),
                  ),
                  icon: const Icon(Icons.screen_share_rounded),
                  label: Text(l10n.streamerShareAgain),
                ),
              ] else ...[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: host.paused
                            ? const Color(0xFFFFB020)
                            : const Color(0xFF2BD46B),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _status(l10n),
                        textAlign: TextAlign.center,
                        style: text.bodyStrong.copyWith(color: white),
                      ),
                    ),
                  ],
                ),
                if (game != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    game,
                    textAlign: TextAlign.center,
                    style: text.caption.copyWith(
                      color: white.withValues(alpha: 0.75),
                    ),
                  ),
                ],
                if (host.gameAudio == StreamerGameAudio.ok) ...[
                  const SizedBox(height: 2),
                  Text(
                    l10n.streamerGameAudioNote,
                    textAlign: TextAlign.center,
                    style: text.caption.copyWith(
                      color: white.withValues(alpha: 0.6),
                      fontSize: 11,
                    ),
                  ),
                ],
                const SizedBox(height: KSpacing.md),
                OutlinedButton.icon(
                  key: goToGameKey,
                  onPressed: onGoToGame,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: white,
                    side: BorderSide(color: white.withValues(alpha: 0.7)),
                    minimumSize: const Size(0, KSizes.minTouchTarget),
                    shape: const StadiumBorder(),
                  ),
                  icon: const Icon(Icons.sports_esports_rounded),
                  label: Text(l10n.streamerGoToGame),
                ),
              ],
              const SizedBox(height: KSpacing.md),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: KSpacing.xs,
                children: [
                  _StageToggle(
                    key: micKey,
                    icon: micOn ? Icons.mic_rounded : Icons.mic_off_rounded,
                    label: micOn
                        ? l10n.streamerNotifMicOff
                        : l10n.streamerNotifMicOn,
                    on: micOn,
                    onTap: onMic,
                  ),
                  if (host.gameAudio == StreamerGameAudio.ok)
                    _StageToggle(
                      key: gameKey,
                      icon: host.gameMuted
                          ? Icons.volume_off_rounded
                          : Icons.volume_up_rounded,
                      label: host.gameMuted
                          ? l10n.streamerUnmuteGame
                          : l10n.streamerMuteGame,
                      on: !host.gameMuted,
                      onTap: onGame,
                    ),
                  _StageToggle(
                    key: cameraKey,
                    icon: host.cameraVisible
                        ? Icons.videocam_rounded
                        : Icons.videocam_off_rounded,
                    label: host.cameraVisible
                        ? l10n.streamerHideCamera
                        : l10n.streamerShowCamera,
                    on: host.cameraVisible,
                    onTap: onCamera,
                  ),
                ],
              ),
            ],
          );
          return Stack(
            children: [
              Positioned.fromRect(
                rect: area,
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: bubble * 0.5),
                    child: SingleChildScrollView(child: status),
                  ),
                ),
              ),
              if (host.cameraVisible && camera != null)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  left: area.left + at.dx,
                  top: area.top + at.dy,
                  child: _DraggableBubble(
                    key: bubbleKey,
                    size: bubble,
                    area: area,
                    camera: camera!,
                    hint: l10n.streamerDragHint,
                    onDrop: onCorner,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// The host's bubble preview: dragged anywhere, dropped into the nearest
/// corner.
class _DraggableBubble extends StatefulWidget {
  const new({
    required this.size,
    required this.area,
    required this.camera,
    required this.hint,
    required this.onDrop,
    super.key,
  });

  final double size;
  final Rect area;
  final Widget camera;
  final String hint;
  final ValueChanged<StreamerCorner>? onDrop;

  @override
  State<_DraggableBubble> createState() => _DraggableBubbleState();
}

class _DraggableBubbleState extends State<_DraggableBubble> {
  Offset _drag = Offset.zero;

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.hint,
    child: GestureDetector(
      onPanUpdate: widget.onDrop == null
          ? null
          : (d) => setState(() => _drag += d.delta),
      onPanEnd: widget.onDrop == null
          ? null
          : (_) {
              final box = context.findRenderObject();
              if (box is RenderBox) {
                final centre = box.localToGlobal(
                  Offset(widget.size / 2, widget.size / 2),
                );
                widget.onDrop!(
                  StreamerCorner.nearest(
                    centre.dx - widget.area.left,
                    centre.dy - widget.area.top,
                    widget.area.width,
                    widget.area.height,
                  ),
                );
              }
              setState(() => _drag = Offset.zero);
            },
      child: Transform.translate(
        offset: _drag,
        child: StreamerBubble(camera: widget.camera, size: widget.size),
      ),
    ),
  );
}

/// D213: a viewer's streamer stage — the host's screen fitted to its
/// orientation (a landscape game letterboxed in the portrait room), the
/// camera bubble at the host's corner of the picture, «الشاشة متوقفة
/// مؤقتاً» while the host pauses it, and the fullscreen button. The layout
/// follows the `streamer` messages (the newest version wins); a metadata
/// version above it re-reads the room ([reload]).
class StreamerViewerStage extends StatefulWidget {
  const new({
    required this.engine,
    required this.hostId,
    required this.hostName,
    required this.initial,
    required this.joined,
    this.changes,
    this.reload,
    this.fullscreen = false,
    super.key,
  });

  final LiveScreenShare engine;

  /// The session's changes (tracks, metadata); the stage redraws on them.
  final Listenable? changes;
  final String hostId;
  final String hostName;
  final LiveStreamer initial;
  final bool joined;
  final Future<LiveStreamer?> Function()? reload;

  /// Inside the fullscreen page (no fullscreen button, an exit one).
  final bool fullscreen;

  static const stageKey = Key('streamer.viewer.stage');
  static const pictureKey = Key('streamer.viewer.picture');
  static const bubbleKey = Key('streamer.viewer.bubble');
  static const pausedKey = Key('streamer.viewer.paused');
  static const waitingKey = Key('streamer.viewer.waiting');
  static const fullscreenKey = Key('streamer.viewer.fullscreen');
  static const exitKey = Key('streamer.viewer.exitFullscreen');

  @override
  State<StreamerViewerStage> createState() => _StreamerViewerStageState();
}

class _StreamerViewerStageState extends State<StreamerViewerStage> {
  late LiveStreamer _layout = widget.initial;
  StreamSubscription<LiveStreamerEvent>? _sub;
  bool _reloading = false;

  @override
  void initState() {
    super.initState();
    _sub = widget.engine.streamerEvents.listen(_onEvent);
  }

  @override
  void didUpdateWidget(StreamerViewerStage old) {
    super.didUpdateWidget(old);
    final newer = _layout.newest(widget.initial);
    if (newer != _layout) _layout = newer;
    if (old.engine != widget.engine) {
      unawaited(_sub?.cancel());
      _sub = widget.engine.streamerEvents.listen(_onEvent);
    }
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }

  void _onEvent(LiveStreamerEvent e) {
    final next = _layout.newest(e.streamer);
    if (next != _layout && mounted) setState(() => _layout = next);
  }

  /// A metadata version above the one held: a message was missed.
  void _checkVersion() {
    final v = widget.engine.streamerVersion;
    final reload = widget.reload;
    if (v == null || v <= _layout.version || reload == null || _reloading) {
      return;
    }
    _reloading = true;
    unawaited(
      reload()
          .then((s) {
            if (s != null) _onEvent(LiveStreamerEvent('', s));
          }, onError: (_) {})
          .whenComplete(() => _reloading = false),
    );
  }

  Future<void> _openFullscreen(BuildContext context) async {
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => StreamerFullscreenPage(
          engine: widget.engine,
          hostId: widget.hostId,
          hostName: widget.hostName,
          layout: _layout,
          changes: widget.changes,
          reload: widget.reload,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final changes = widget.changes;
    return changes == null
        ? _build(context)
        : ListenableBuilder(
            listenable: changes,
            builder: (context, _) {
              _checkVersion();
              return _build(context);
            },
          );
  }

  Widget _build(BuildContext context) {
    final l10n = context.l10n;
    final engine = widget.engine;
    final layout = _layout;
    final screen = engine.remoteScreen(widget.hostId);
    final paused = engine.remoteScreenPaused(widget.hostId);
    final camera = layout.cameraVisible
        ? engine.remoteCamera(widget.hostId)
        : null;
    final padding = MediaQuery.paddingOf(context);
    return ColoredBox(
      key: StreamerViewerStage.stageKey,
      color: const Color(0xFF000000),
      child: LayoutBuilder(
        builder: (context, box) {
          final size = Size(box.maxWidth, box.maxHeight);
          final rect = streamerPictureRect(size, landscape: layout.landscape);
          final bubble = KStreamer.bubbleFor(rect.size);
          // In the room (not fullscreen) the host pill and chips sit over the
          // picture's top and the chat over its bottom: the bubble keeps the
          // host's corner inside the part between them.
          final room = streamerBubbleArea(
            rect,
            size,
            top: widget.fullscreen ? 0 : padding.top + KStreamer.roomTop,
            bottom: widget.fullscreen ? 0 : KStreamer.roomBottom,
            bubble: bubble,
          );
          final at = streamerBubbleOffset(layout.corner, room.size, bubble);
          final Widget picture;
          if (screen != null) {
            picture = Semantics(
              image: true,
              label: l10n.streamerScreenSemantics(widget.hostName),
              child: SizedBox.expand(child: screen),
            );
          } else if (paused) {
            picture = Center(
              key: StreamerViewerStage.pausedKey,
              child: KLiveInterruption(
                compact: true,
                icon: Icons.pause_circle_outline_rounded,
                title: l10n.streamerPausedViewer,
              ),
            );
          } else {
            picture = Center(
              key: StreamerViewerStage.waitingKey,
              child: KLiveInterruption(
                compact: true,
                icon: Icons.screen_share_outlined,
                busy: widget.joined,
                title: l10n.streamerWaiting,
              ),
            );
          }
          // Physical corners: the bubble and the buttons never mirror.
          return Directionality(
            textDirection: TextDirection.ltr,
            child: Stack(
              children: [
                Positioned.fromRect(
                  key: StreamerViewerStage.pictureKey,
                  rect: rect,
                  child: picture,
                ),
                if (camera != null)
                  AnimatedPositioned(
                    key: StreamerViewerStage.bubbleKey,
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    left: room.left + at.dx,
                    top: room.top + at.dy,
                    width: bubble,
                    height: bubble,
                    child: StreamerBubble(camera: camera, size: bubble),
                  ),
                if (!widget.fullscreen && screen != null)
                  Positioned(
                    // Landscape: under the picture's right end. Portrait: at
                    // the top of the bubble's area, on the side away from a
                    // bubble at the top (never over it).
                    left:
                        !layout.landscape &&
                            layout.corner == StreamerCorner.topRight &&
                            camera != null
                        ? room.left + 6
                        : null,
                    right:
                        !layout.landscape &&
                            layout.corner == StreamerCorner.topRight &&
                            camera != null
                        ? null
                        : size.width - rect.right + 6,
                    top: layout.landscape ? rect.bottom + 6 : room.top + 6,
                    child: _RoundButton(
                      key: StreamerViewerStage.fullscreenKey,
                      icon: layout.landscape
                          ? Icons.screen_rotation_rounded
                          : Icons.fullscreen_rounded,
                      label: l10n.streamerFullscreen,
                      onTap: () => unawaited(_openFullscreen(context)),
                    ),
                  ),
                if (widget.fullscreen)
                  Positioned(
                    right: padding.right + 12,
                    top: padding.top + 12,
                    child: _RoundButton(
                      key: StreamerViewerStage.exitKey,
                      icon: Icons.fullscreen_exit_rounded,
                      label: l10n.streamerExitFullscreen,
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const new({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    child: Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: SizedBox(
          width: KSizes.minTouchTarget,
          height: KSizes.minTouchTarget,
          child: Center(
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0x8C000000),
                border: Border.all(color: const Color(0x66FFFFFF)),
              ),
              child: Icon(icon, color: const Color(0xFFFFFFFF), size: 22),
            ),
          ),
        ),
      ),
    ),
  );
}

/// D213: the viewer's fullscreen — a landscape game turns the phone to
/// landscape; portrait stays portrait with nothing but the screen and the
/// bubble. The orientations and the system bars come back on exit.
class StreamerFullscreenPage extends StatefulWidget {
  const new({
    required this.engine,
    required this.hostId,
    required this.hostName,
    required this.layout,
    this.changes,
    this.reload,
    super.key,
  });

  final LiveScreenShare engine;
  final String hostId;
  final String hostName;
  final LiveStreamer layout;
  final Listenable? changes;
  final Future<LiveStreamer?> Function()? reload;

  static const pageKey = Key('streamer.fullscreen');

  @override
  State<StreamerFullscreenPage> createState() => _StreamerFullscreenPageState();
}

class _StreamerFullscreenPageState extends State<StreamerFullscreenPage> {
  @override
  void initState() {
    super.initState();
    unawaited(
      SystemChrome.setPreferredOrientations(
        widget.layout.landscape
            ? const [
                DeviceOrientation.landscapeLeft,
                DeviceOrientation.landscapeRight,
              ]
            : const [DeviceOrientation.portraitUp],
      ),
    );
    unawaited(
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
    );
  }

  @override
  void dispose() {
    // The app's own rule: no preferred orientation (the system's).
    unawaited(SystemChrome.setPreferredOrientations(const []));
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    key: StreamerFullscreenPage.pageKey,
    backgroundColor: const Color(0xFF000000),
    body: StreamerViewerStage(
      engine: widget.engine,
      hostId: widget.hostId,
      hostName: widget.hostName,
      initial: widget.layout,
      joined: true,
      changes: widget.changes,
      reload: widget.reload,
      fullscreen: true,
    ),
  );
}
