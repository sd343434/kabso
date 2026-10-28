import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;
import 'package:kabso_live/features/live/data/live_media_engine.dart';
import 'package:kabso_live/features/live/data/live_program_repository.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/live/domain/live_program.dart';

/// One live's program as this phone knows it, and the segment that just
/// began (shown for [LivePrograms.announceTime]).
typedef LiveProgramView = ({LiveProgram? program, LiveProgramItem? started});

/// D154e («قائمة البرامج», CONVENTIONS §10.37): the program of one live.
/// Loaded once when the room attaches (late joiners see it too), replaced
/// by the server's `program` messages when the host changes it, and moved
/// on by its `program-segment` messages — the server times them, so a
/// segment the host ended the live before is never announced. Nothing
/// shows while the program is empty or could not be loaded.
class LivePrograms extends Notifier<LiveProgramView> {
  new(this.roomId);

  final String roomId;

  /// How long «بدأت الفقرة» stays on the card.
  static const announceTime = Duration(seconds: 8);

  StreamSubscription<LiveChatEvent>? _events;
  Timer? _announce;

  @override
  LiveProgramView build() {
    ref.onDispose(() {
      unawaited(_events?.cancel());
      _announce?.cancel();
    });
    return (program: null, started: null);
  }

  /// Loads the program and follows the [engine]'s program messages (once).
  void attach(LiveMediaEngine engine) {
    if (_events != null) return;
    _events = engine.chatEvents.listen((event) {
      switch (event) {
        case LiveProgramChanged(:final program):
          replace(program);
        case LiveProgramSegmentStarted(:final item):
          started(item);
        default:
          break;
      }
    });
    unawaited(load());
  }

  /// `GET …/program`; a failure leaves what this phone had (best effort).
  Future<void> load() async {
    try {
      final program = await ref.read(liveProgramRepositoryProvider).get(roomId);
      if (ref.mounted) replace(program);
    } on Object {
      // No card rather than a wrong one.
    }
  }

  /// The program now (the host's own answer, or a `program` message).
  void replace(LiveProgram program) {
    if (!ref.mounted || program.roomId != roomId) return;
    state = (program: program, started: state.started);
  }

  /// A segment began: it becomes the current one and is announced.
  void started(LiveProgramItem item) {
    final program = state.program;
    if (!ref.mounted || program == null) return;
    if (!program.items.contains(item)) return;
    _announce?.cancel();
    _announce = Timer(announceTime, () {
      if (ref.mounted) state = (program: state.program, started: null);
    });
    state = (program: program.withCurrent(item.position), started: item);
  }
}

final NotifierProviderFamily<LivePrograms, LiveProgramView, String>
liveProgramProvider =
    NotifierProvider.family<LivePrograms, LiveProgramView, String>(
      LivePrograms.new,
    );
