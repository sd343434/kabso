import 'package:kabso_live/features/live/domain/live_podcast_video.dart';

/// v1.114-live (D363, CONVENTIONS §10.157): the video podcast's automatic
/// director — which shot everyone sees, from the media server's
/// active-speaker events.
///
/// * SPEAKER: the current speaker full screen (the others as thumbnails).
/// * SPLIT: two people alternating within [PodcastDirectorTiming.splitWindow]
///   (A → B → A): top / bottom.
/// * GRID: [PodcastDirectorTiming.gridSpeakers] or more speaking at once:
///   everyone, for [PodcastDirectorTiming.gridHold] after the burst, then
///   back.
/// * HOT_SEAT: a listener is «في الكرسي الساخن».
///
/// Every automatic change waits until the shot on screen has been held
/// [PodcastDirectorTiming.minHold] (hysteresis). The host's lock (a pinned
/// guest) and the hot seat apply at once. Pure Dart: the time comes in with
/// every call, so it is tested without a clock.
///
/// D363 scope extension (owner 2026-11-11): the host's manual control — a
/// pinned person and/or a locked layout (SPEAKER / SPLIT / HOT_SEAT) — wins
/// over everything; then the hot seat; then, while a listener's question is
/// on screen, the person answering it; then the automatic rules.
class PodcastDirectorTiming {
  const new({
    this.minHold = const Duration(milliseconds: 2500),
    this.splitWindow = const Duration(seconds: 6),
    this.gridHold = const Duration(seconds: 3),
    this.gridSpeakers = 3,
    this.remoteTimeout = const Duration(seconds: 15),
    this.heartbeat = const Duration(seconds: 10),
  });

  /// The least time a shot stays before the director changes it.
  final Duration minHold;

  /// Two people alternating within this window make a split.
  final Duration splitWindow;

  /// How long the grid stays after fewer than [gridSpeakers] speak.
  final Duration gridHold;

  /// This many people speaking at once make a grid.
  final int gridSpeakers;

  /// Viewers: no `director` message for this long → the host's director is
  /// gone (away, background, a late join): run the director locally.
  final Duration remoteTimeout;

  /// The host re-sends the shot on screen this often.
  final Duration heartbeat;
}

class PodcastDirector {
  new({required this.hostId, this.timing = const PodcastDirectorTiming()})
    : _stage = [hostId],
      _shot = PodcastDirectorShot(
        kind: PodcastShotKind.speaker,
        userIds: [hostId],
      );

  final String hostId;
  final PodcastDirectorTiming timing;

  /// The people on stage: the host first, then the seated speakers.
  List<String> _stage;
  String? _hotSeat;
  String? _locked;
  PodcastShotKind? _layout;
  String? _answer;

  /// Speaker turns (who became the main voice, when), newest last.
  final List<({String id, DateTime at})> _turns = [];
  Set<String> _speaking = const {};
  DateTime? _gridUntil;

  PodcastDirectorShot _shot;
  DateTime? _since;
  int _seq = 0;

  /// The shot on screen now.
  PodcastDirectorShot get shot => _shot;

  /// The people on stage, the host first.
  List<String> get stage => List.unmodifiable(_stage);

  /// Who the host pinned (the director paused), or null («تلقائي»).
  String? get locked => _locked;

  /// The layout the host locked, or null.
  PodcastShotKind? get layout => _layout;

  /// Who answers the question on screen (preferred while it is up).
  String? get answering => _answer;

  /// The people on stage now ([ids] the seated speakers in seat order; the
  /// host is always first). Someone who left is dropped from the shot at
  /// once.
  PodcastDirectorShot? setStage(List<String> ids, DateTime now) {
    _stage = [hostId, ...ids.where((id) => id != hostId)];
    if (_locked != null && !_stage.contains(_locked)) _locked = null;
    if (_hotSeat != null && !_stage.contains(_hotSeat)) _hotSeat = null;
    if (_answer != null && !_stage.contains(_answer)) _answer = null;
    _speaking = _speaking.where(_stage.contains).toSet();
    final gone = _shot.userIds.any((id) => !_stage.contains(id));
    return _decide(now, force: gone);
  }

  /// The hot seat's asker (null: none) — shown at once.
  PodcastDirectorShot? setHotSeat(String? userId, DateTime now) {
    final next = userId != null && _stage.contains(userId) ? userId : null;
    if (next == _hotSeat) return null;
    _hotSeat = next;
    return _decide(now, force: true);
  }

  /// The host pins [userId] (null: no pin; the layout lock stays) —
  /// applied at once.
  PodcastDirectorShot? lock(String? userId, DateTime now) =>
      control(pin: userId, layout: _layout, now: now);

  /// D363 scope extension: the host's manual control — [pin] a person on
  /// stage and/or keep [layout] (SPEAKER, SPLIT or HOT_SEAT; GRID is never
  /// locked). Both null = «تلقائي». Applied at once.
  PodcastDirectorShot? control({
    required String? pin,
    required PodcastShotKind? layout,
    required DateTime now,
  }) {
    final nextPin = pin != null && _stage.contains(pin) ? pin : null;
    final nextLayout = layout == PodcastShotKind.grid ? null : layout;
    if (nextPin == _locked && nextLayout == _layout) return null;
    _locked = nextPin;
    _layout = nextLayout;
    return _decide(now, force: true);
  }

  /// D363 scope extension: a listener's question is on screen and [userId]
  /// answers it (null: no card, or whoever speaks) — the director prefers
  /// their shot at once, unless the host controls the shot.
  PodcastDirectorShot? setAnswer(String? userId, DateTime now) {
    final next = userId != null && _stage.contains(userId) ? userId : null;
    if (next == _answer) return null;
    _answer = next;
    return _decide(now, force: true);
  }

  /// The media server's active speakers changed.
  PodcastDirectorShot? onSpeakers(Set<String> speaking, DateTime now) {
    final onStage = speaking.where(_stage.contains).toSet();
    // A new main voice: someone who was not speaking a moment ago, or the
    // only one left speaking.
    final started = onStage.difference(_speaking);
    String? main;
    if (started.isNotEmpty) {
      main = _stage.firstWhere(started.contains);
    } else if (onStage.length == 1 && _turns.lastOrNull?.id != onStage.first) {
      main = onStage.first;
    }
    if (main != null && _turns.lastOrNull?.id != main) {
      _turns.add((id: main, at: now));
      _forget(now);
    }
    // The grid stays [gridHold] after the burst ends.
    if (_speaking.length >= timing.gridSpeakers &&
        onStage.length < timing.gridSpeakers) {
      _gridUntil = now.add(timing.gridHold);
    }
    _speaking = onStage;
    return _decide(now);
  }

  /// Time passed (a timer): a held shot may now change.
  PodcastDirectorShot? tick(DateTime now) => _decide(now);

  void _forget(DateTime now) {
    final keep = now.subtract(timing.splitWindow * 2);
    _turns.removeWhere((t) => t.at.isBefore(keep));
  }

  /// The shot the rules want now (before the hold).
  PodcastDirectorShot _want(DateTime now) {
    List<String> others(String main) => [
      main,
      ..._stage.where((id) => id != main),
    ];
    // The host's manual control first.
    final manual = _manual(now, others);
    if (manual != null) return manual;
    if (_hotSeat case final asker?) {
      return PodcastDirectorShot(
        kind: PodcastShotKind.hotSeat,
        userIds: others(asker),
      );
    }
    // A question on screen: the person answering it.
    if (_answer case final answering?) {
      return PodcastDirectorShot(
        kind: PodcastShotKind.speaker,
        userIds: others(answering),
      );
    }
    if (_stage.length >= timing.gridSpeakers &&
        (_speaking.length >= timing.gridSpeakers ||
            (_gridUntil != null && now.isBefore(_gridUntil!)))) {
      return PodcastDirectorShot(kind: PodcastShotKind.grid, userIds: _stage);
    }
    final pair = _alternating(now);
    if (pair != null) {
      return PodcastDirectorShot(kind: PodcastShotKind.split, userIds: pair);
    }
    final current = _turns.lastOrNull?.id;
    final main = current != null && _stage.contains(current)
        ? current
        : (_shot.main != null && _stage.contains(_shot.main)
              ? _shot.main!
              : hostId);
    return PodcastDirectorShot(
      kind: PodcastShotKind.speaker,
      userIds: others(main),
    );
  }

  /// The host's shot ([_locked] and/or [_layout]), or null («تلقائي», or a
  /// HOT_SEAT layout without a hot seat).
  PodcastDirectorShot? _manual(
    DateTime now,
    List<String> Function(String main) others,
  ) {
    final pinned = _locked;
    switch (_layout) {
      case null:
        if (pinned == null) return null;
        return PodcastDirectorShot(
          kind: PodcastShotKind.speaker,
          userIds: others(pinned),
          locked: true,
        );
      case PodcastShotKind.hotSeat:
        final asker = _hotSeat;
        if (asker == null) {
          return pinned == null
              ? null
              : PodcastDirectorShot(
                  kind: PodcastShotKind.speaker,
                  userIds: others(pinned),
                  locked: true,
                );
        }
        return PodcastDirectorShot(
          kind: PodcastShotKind.hotSeat,
          userIds: others(asker),
          locked: true,
        );
      case PodcastShotKind.split:
        final first = pinned ?? _answer ?? _current() ?? hostId;
        final second = _partner(first);
        return PodcastDirectorShot(
          kind: PodcastShotKind.split,
          userIds: second == null ? [first] : [first, second],
          locked: true,
        );
      case PodcastShotKind.speaker:
      case PodcastShotKind.grid:
        final main = pinned ?? _answer ?? _current() ?? hostId;
        return PodcastDirectorShot(
          kind: PodcastShotKind.speaker,
          userIds: others(main),
          locked: true,
        );
    }
  }

  /// The latest main voice on stage, or the one on screen.
  String? _current() {
    final current = _turns.lastOrNull?.id;
    if (current != null && _stage.contains(current)) return current;
    final shown = _shot.main;
    return shown != null && _stage.contains(shown) ? shown : null;
  }

  /// The split's second person: the latest other voice, else the first
  /// other person on stage (the host first).
  String? _partner(String first) {
    for (final t in _turns.reversed) {
      if (t.id != first && _stage.contains(t.id)) return t.id;
    }
    for (final id in _stage) {
      if (id != first) return id;
    }
    return null;
  }

  /// Two people who alternate (A → B → A, at least three turns) within the
  /// split window, the latest first; else null.
  List<String>? _alternating(DateTime now) {
    final from = now.subtract(timing.splitWindow);
    final recent = [
      for (final t in _turns)
        if (!t.at.isBefore(from) && _stage.contains(t.id)) t.id,
    ];
    if (recent.length < 3) return null;
    final people = recent.toSet();
    if (people.length != 2) return null;
    final last = recent.last;
    return [last, people.firstWhere((id) => id != last)];
  }

  PodcastDirectorShot? _decide(DateTime now, {bool force = false}) {
    final want = _want(now);
    // The split keeps its order while the same two alternate (no flicker).
    if (want.kind == PodcastShotKind.split &&
        _shot.kind == PodcastShotKind.split &&
        want.locked == _shot.locked &&
        want.userIds.length == _shot.userIds.length &&
        want.userIds.toSet().containsAll(_shot.userIds)) {
      return null;
    }
    if (want.sameAs(_shot)) return null;
    // The same picture with other thumbnails (someone joined or left the
    // stage behind it) is not a cut: no hold, and the hold goes on.
    if (want.kind == _shot.kind &&
        want.main == _shot.main &&
        want.locked == _shot.locked) {
      _seq += 1;
      return _shot = want.copyWith(seq: _seq);
    }
    final held = _since == null || now.difference(_since!) >= timing.minHold;
    final urgent =
        force ||
        want.locked != _shot.locked ||
        (want.kind == PodcastShotKind.hotSeat) !=
            (_shot.kind == PodcastShotKind.hotSeat);
    if (!held && !urgent) return null;
    _seq += 1;
    _since = now;
    return _shot = want.copyWith(seq: _seq);
  }
}

/// What a phone shows: the host's director's shot as relayed (`podcast`
/// topic), else its own [PodcastDirector] (no message for
/// [PodcastDirectorTiming.remoteTimeout]), unless the viewer picked a
/// person themself ([free]: «رجوع للمخرج» returns).
class PodcastShotFollower {
  new(this.local);

  final PodcastDirector local;

  PodcastDirectorShot? _remote;
  DateTime? _remoteAt;

  /// The viewer's own pick (a thumbnail tap; null: back to the director).
  String? pinned;

  /// Whether the viewer watches someone of their choice.
  bool get free => pinned != null;

  /// A `director` message from the host's app; an older [shot] (lower
  /// `seq`) is dropped. Returns whether it was taken.
  bool onRemote(PodcastDirectorShot shot, DateTime now) {
    if (_remote case final r? when shot.seq < r.seq && !_stale(now)) {
      return false;
    }
    _remote = shot;
    _remoteAt = now;
    return true;
  }

  bool _stale(DateTime now) =>
      _remoteAt == null ||
      now.difference(_remoteAt!) > local.timing.remoteTimeout;

  /// Whether the host's director is heard now.
  bool following(DateTime now) => !_stale(now);

  /// The shot to show at [now].
  PodcastDirectorShot shotAt(DateTime now) {
    final base = !_stale(now) ? _remote! : local.shot;
    if (pinned case final p? when local.stage.contains(p)) {
      return PodcastDirectorShot(
        kind: PodcastShotKind.speaker,
        userIds: [p, ...local.stage.where((id) => id != p)],
        seq: base.seq,
      );
    }
    // Someone who left the stage since the message is not drawn.
    final ids = base.userIds.where(local.stage.contains).toList();
    if (ids.isEmpty) return local.shot;
    return base.copyWith(userIds: ids);
  }
}
