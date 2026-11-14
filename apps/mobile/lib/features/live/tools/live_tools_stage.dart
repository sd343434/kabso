import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/logging/app_logger.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/application/live_pk_controller.dart';
import 'package:kabso_live/features/live/data/live_media_engine.dart';
import 'package:kabso_live/features/live/data/live_media_extras.dart';
import 'package:kabso_live/features/live/tools/live_tools_repository.dart';
import 'package:kabso_live/features/live/tools/music/live_music_controller.dart';
import 'package:kabso_live/features/live/tools/recorder/live_clip_widgets.dart';
import 'package:kabso_live/features/live/tools/second_camera/live_dual_camera_view.dart';
import 'package:material_ui/material_ui.dart';

SecondCameraFeed _defaultMain(LiveMediaEngine engine, String identity) {
  final attrs = engine is LiveParticipantAttributes
      ? (engine as LiveParticipantAttributes).attributesOf(identity)
      : const <String, String>{};
  return attrs[liveAttrMainFeed] == 'SECOND'
      ? SecondCameraFeed.second
      : SecondCameraFeed.host;
}

/// D201: the host's own SOLO video stage with the live tools — the second
/// camera as the viewers see it (main + small picture, swap on this screen),
/// the REC badge while a clip records; it keeps the music player alive for
/// the live and ends the second camera when a PK starts (a PK shows the
/// host's camera only).
class LiveHostToolsStage extends ConsumerStatefulWidget {
  const new({
    required this.roomId,
    required this.engine,
    required this.camera,
    super.key,
  });

  final String roomId;
  final LiveMediaEngine engine;

  /// The host's own camera picture.
  final Widget camera;

  static const recKey = Key('tools.host.rec');

  @override
  ConsumerState<LiveHostToolsStage> createState() => _HostStageState();
}

class _HostStageState extends ConsumerState<LiveHostToolsStage> {
  @override
  void initState() {
    super.initState();
    widget.engine.changes.addListener(_changed);
  }

  @override
  void didUpdateWidget(LiveHostToolsStage old) {
    super.didUpdateWidget(old);
    if (old.engine != widget.engine) {
      old.engine.changes.removeListener(_changed);
      widget.engine.changes.addListener(_changed);
    }
  }

  @override
  void dispose() {
    widget.engine.changes.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  /// D210: a tool (music, PK) that failed: the stage is the host's plain
  /// camera from then on — the live picture never goes.
  bool _degraded = false;

  @override
  Widget build(BuildContext context) {
    if (_degraded) return widget.camera;
    try {
      return _tools(context);
    } on Object catch (e, stack) {
      AppLogger.error('live: host tools stage off', e, stack);
      _degraded = true;
      return widget.camera;
    }
  }

  Widget _tools(BuildContext context) {
    // The player lives as long as the live's stage (music stops with it).
    ref.watch(liveMusicProvider.select((s) => s.playing));
    final me = ref.watch(currentUserProvider)?.id;
    final inPk = ref.watch(
      livePkProvider(widget.roomId).select((p) => p.match != null),
    );
    final identity = me == null ? null : liveSecondCameraIdentity(me);
    ref.listen(livePkProvider(widget.roomId).select((p) => p.match != null), (
      _,
      pk,
    ) {
      if (pk && identity != null && widget.engine.isPresent(identity)) {
        unawaited(
          ref
              .read(liveToolsRepositoryProvider)
              .endSecondCamera(widget.roomId)
              .catchError((Object _) {}),
        );
      }
    });
    final second = identity == null || inPk
        ? null
        : widget.engine.remoteVideo(identity);
    final top = MediaQuery.paddingOf(context).top;
    return Stack(
      fit: StackFit.expand,
      children: [
        LiveDualCameraView(
          host: widget.camera,
          second: second,
          defaultMain: identity == null
              ? SecondCameraFeed.host
              : _defaultMain(widget.engine, identity),
          topInset: top + 112,
        ),
        PositionedDirectional(
          top: top + 112,
          start: 12,
          child: LiveClipRecBadge(
            key: LiveHostToolsStage.recKey,
            roomId: widget.roomId,
          ),
        ),
      ],
    );
  }
}

/// D201: a viewer's SOLO stage — the host's camera and, when the host has a
/// second camera, the small picture (tap to swap, on this screen only; the
/// default is the host's choice); «يتم التسجيل» while the host records.
class LiveViewerToolsStage extends StatelessWidget {
  const new({
    required this.engine,
    required this.hostId,
    required this.picture,
    super.key,
  });

  final LiveMediaEngine engine;
  final String hostId;

  /// The host's camera.
  final Widget picture;

  @override
  Widget build(BuildContext context) {
    final identity = liveSecondCameraIdentity(hostId);
    final second = engine.remoteVideo(identity);
    final attrs = engine is LiveParticipantAttributes
        ? (engine as LiveParticipantAttributes).attributesOf(hostId)
        : const <String, String>{};
    final top = MediaQuery.paddingOf(context).top;
    return Stack(
      fit: StackFit.expand,
      children: [
        LiveDualCameraView(
          host: picture,
          second: second,
          defaultMain: _defaultMain(engine, identity),
          topInset: top + 112,
        ),
        PositionedDirectional(
          top: top + 112,
          start: 12,
          child: LiveRecordingViewerBadge(attributes: attrs),
        ),
      ],
    );
  }
}
