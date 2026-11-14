import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;
import 'package:kabso_live/core/logging/app_logger.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/features/live/application/podcast_director.dart';
import 'package:kabso_live/features/live/data/live_media_engine.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_video_podcast_stage.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_video_podcast_studio.dart';
import 'package:material_ui/material_ui.dart';

/// D363 scope extension (§10.157): a video podcast's studio per room as
/// the server last said it — from `LiveSeats.studio`, the `studio` data
/// messages and the host's own changes; an older `seq` is dropped.
class PodcastStudioState extends Notifier<LivePodcastStudio?> {
  new(this.roomId);

  final String roomId;

  @override
  LivePodcastStudio? build() => null;

  /// Takes [studio] unless it is older than the one held.
  void apply(LivePodcastStudio? studio) {
    if (studio == null || !ref.mounted) return;
    final held = state;
    if (held != null && studio.seq < held.seq) return;
    if (held == studio) return;
    state = studio;
  }
}

final NotifierProviderFamily<PodcastStudioState, LivePodcastStudio?, String>
podcastStudioProvider = NotifierProvider.autoDispose
    .family<PodcastStudioState, LivePodcastStudio?, String>(
      PodcastStudioState.new,
    );

/// The newer of [held] and [seats] (`LiveSeats.studio`).
LivePodcastStudio? newerStudio(
  LivePodcastStudio? held,
  LivePodcastStudio? seats,
) {
  if (held == null) return seats;
  if (seats == null) return held;
  return seats.seq > held.seq ? seats : held;
}

/// The seats on air (taken, not backstage), in seat order.
List<LiveSeat> podcastOnAir(LiveSeats? seats) => [
  for (final s in seats?.seats ?? const <LiveSeat>[])
    if (s.user != null && !s.backstage) s,
]..sort((a, b) => a.index.compareTo(b.index));

/// The seats waiting backstage, in seat order.
List<LiveSeat> podcastBackstage(LiveSeats? seats) => [
  for (final s in seats?.seats ?? const <LiveSeat>[])
    if (s.user != null && s.backstage) s,
]..sort((a, b) => a.index.compareTo(b.index));

/// D363: the video podcast's stage in a live room — the host's app runs
/// the [PodcastDirector] on the media server's active speakers and relays
/// each shot (and every 10 s the same one) with `setLivePodcastDirector`;
/// a viewer's app draws the relayed shot ([PodcastShotFollower]), runs the
/// director itself while none comes, and lets the viewer pick a person.
class VideoPodcastRoomStage extends ConsumerStatefulWidget {
  const new({
    required this.roomId,
    required this.host,
    required this.seats,
    required this.engine,
    required this.me,
    super.key,
    this.isHost = false,
    this.hostMicOff = false,
    this.onBringOnAir,
  });

  final String roomId;
  final UserSummary host;
  final LiveSeats? seats;
  final LiveMediaEngine engine;

  /// The signed-in person (their own picture is the camera preview).
  final String? me;

  /// This phone runs the room's director (the host).
  final bool isHost;
  final bool hostMicOff;

  /// The host brings a backstage guest on air (the seat's index).
  final ValueChanged<int>? onBringOnAir;

  @override
  ConsumerState<VideoPodcastRoomStage> createState() =>
      _VideoPodcastRoomStageState();
}

class _VideoPodcastRoomStageState extends ConsumerState<VideoPodcastRoomStage> {
  late final PodcastDirector _director = PodcastDirector(
    hostId: widget.host.id,
  );
  late final PodcastShotFollower _follower = PodcastShotFollower(_director);
  StreamSubscription<PodcastEvent>? _events;
  Timer? _timer;
  DateTime? _sentAt;
  final Map<String, int> _votes = {};

  @override
  void initState() {
    super.initState();
    _syncStage();
    widget.engine.changes.addListener(_onChanges);
    _events = widget.engine.podcastEvents.listen(_onEvent);
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) => _tick());
  }

  @override
  void didUpdateWidget(VideoPodcastRoomStage old) {
    super.didUpdateWidget(old);
    if (old.engine != widget.engine) {
      old.engine.changes.removeListener(_onChanges);
      widget.engine.changes.addListener(_onChanges);
      unawaited(_events?.cancel());
      _events = widget.engine.podcastEvents.listen(_onEvent);
    }
    if (old.seats != widget.seats) _syncStage();
  }

  @override
  void dispose() {
    widget.engine.changes.removeListener(_onChanges);
    unawaited(_events?.cancel());
    _timer?.cancel();
    super.dispose();
  }

  /// D363 scope extension: the people on air (a backstage guest is not).
  List<LiveSeat> get _taken => podcastOnAir(widget.seats);

  LivePodcastStudio? get _studio => newerStudio(
    ref.read(podcastStudioProvider(widget.roomId)),
    widget.seats?.studio,
  );

  /// The studio's manual control and the question's answerer into the
  /// director (the host's relays the result; a viewer's runs it locally).
  void _applyStudio() {
    final studio = _studio;
    final now = clock.now();
    _relay(
      _director.control(
        pin: studio?.pinUserId,
        layout: studio?.layout,
        now: now,
      ),
    );
    _relay(_director.setAnswer(studio?.onScreen?.answerUserId, now));
  }

  LiveSeat? get _hotSeat => _taken.where((s) => s.hotSeat != null).firstOrNull;

  void _syncStage() {
    final now = clock.now();
    _relay(_director.setStage([for (final s in _taken) s.user!.id], now));
    _relay(_director.setHotSeat(_hotSeat?.user?.id, now));
    _applyStudio();
  }

  void _onChanges() {
    if (!mounted) return;
    _relay(_director.onSpeakers(widget.engine.speaking, clock.now()));
    setState(() {});
  }

  void _onEvent(PodcastEvent event) {
    if (!mounted) return;
    switch (event) {
      case PodcastDirectorEvent(:final shot):
        // The host draws its own director; viewers follow the relay.
        if (!widget.isHost) _follower.onRemote(shot, clock.now());
      case PodcastVotesEvent(:final requestId, :final votes):
        _votes[requestId] = votes;
      case PodcastStudioEvent(:final studio):
        ref.read(podcastStudioProvider(widget.roomId).notifier).apply(studio);
        _applyStudio();
    }
    setState(() {});
  }

  void _tick() {
    if (!mounted) return;
    final now = clock.now();
    _applyStudio();
    if (widget.isHost) {
      final changed = _relay(_director.tick(now));
      // The same shot again every 10 s (late joiners, a lost message).
      if (!changed &&
          (_sentAt == null ||
              now.difference(_sentAt!) >= _director.timing.heartbeat)) {
        _send(_director.shot);
      }
    } else {
      _director.tick(now);
    }
    setState(() {});
  }

  /// Relays [shot] when this phone is the host's; true when there was one.
  bool _relay(PodcastDirectorShot? shot) {
    if (shot == null) return false;
    if (widget.isHost) _send(shot);
    return true;
  }

  void _send(PodcastDirectorShot shot) {
    _sentAt = clock.now();
    unawaited(
      ref
          .read(liveRepositoryProvider)
          .setPodcastDirector(widget.roomId, shot)
          .catchError((Object e) {
            AppLogger.error('live: podcast director relay failed', e);
          }),
    );
  }

  Widget? _videoOf(String id) {
    final engine = widget.engine;
    if (id == widget.me) {
      return engine.videoPaused ? null : engine.preview();
    }
    if (engine.videoMuted(id)) return null;
    return engine.remoteVideo(id);
  }

  @override
  Widget build(BuildContext context) {
    // A change from the host's controls (or a message) shows at once.
    ref.listen(podcastStudioProvider(widget.roomId), (_, _) {
      _applyStudio();
      setState(() {});
    });
    final studio = _studio;
    final speaking = widget.engine.speaking;
    final host = widget.host;
    final people = <String, VideoPodcastPerson>{
      host.id: VideoPodcastPerson(
        userId: host.id,
        name: host.displayName,
        avatarUrl: host.avatarUrl,
        host: true,
        speaking: speaking.contains(host.id),
        muted: widget.hostMicOff,
      ),
      for (final s in _taken)
        s.user!.id: VideoPodcastPerson(
          userId: s.user!.id,
          name: s.user!.displayName,
          avatarUrl: s.user!.avatarUrl,
          speaking: speaking.contains(s.user!.id),
          muted: s.mutedByHost,
          guestTitle: s.guestTitle,
        ),
    };
    final hot = _hotSeat;
    final now = clock.now();
    final shot = widget.isHost ? _director.shot : _follower.shotAt(now);
    final repo = ref.read(liveRepositoryProvider);
    final studioState = ref.read(podcastStudioProvider(widget.roomId).notifier);
    // The host's changes: the answer is the new studio.
    void hostCall(Future<LivePodcastStudio> Function() call) => unawaited(
      call().then(studioState.apply).catchError((Object e) {
        AppLogger.error('live: podcast studio change failed', e);
      }),
    );
    return VideoPodcastStage(
      shot: shot,
      people: people,
      videoOf: _videoOf,
      studio: studio,
      onAuto: widget.isHost
          ? () => hostCall(() => repo.setPodcastControl(widget.roomId))
          : null,
      onNextSegment: widget.isHost
          ? () => hostCall(() => repo.nextPodcastSegment(widget.roomId))
          : null,
      onHideQuestion: widget.isHost
          ? () => hostCall(() => repo.hidePodcastQuestion(widget.roomId))
          : null,
      backstage: widget.isHost
          ? [
              for (final s in podcastBackstage(widget.seats))
                VideoPodcastBackstageGuest(
                  userId: s.user!.id,
                  name: s.user!.displayName,
                  avatarUrl: s.user!.avatarUrl,
                  speaking: speaking.contains(s.user!.id),
                  seatIndex: s.index,
                ),
            ]
          : const [],
      onBringOnAir: widget.onBringOnAir == null
          ? null
          : (g) => widget.onBringOnAir!(g.seatIndex),
      free: !widget.isHost && _follower.free,
      onThumbTap: widget.isHost
          ? null
          : (id) => setState(() => _follower.pinned = id),
      onBackToDirector: () => setState(() => _follower.pinned = null),
      hotSeat: hot == null
          ? null
          : VideoPodcastHotSeat(
              askerId: hot.user!.id,
              question: hot.hotSeat!.question,
              votes: _votes[hot.hotSeat!.requestId] ?? hot.hotSeat!.votes,
              endsAt: hot.demoteAt,
              seconds: hotSeatTotal(hot.demoteAt, now),
            ),
    );
  }
}

/// The hot seat's full time for the circular timer: the smallest of the
/// question times (60, 120, 180, 300 s) that holds what is left.
int hotSeatTotal(DateTime? endsAt, DateTime now) {
  if (endsAt == null) return 60;
  final left = endsAt.difference(now).inSeconds;
  for (final s in const [60, 120, 180, 300]) {
    if (left <= s) return s;
  }
  return 300;
}
