// In-memory live programs (D154e, tests only): `set` answers as the server
// does (positions in order, `current` the last started one) and records the
// drafts.

import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/features/live/data/live_program_repository.dart';
import 'package:kabso_live/features/live/domain/live_program.dart';

class FakeLiveProgramRepository implements LiveProgramRepository {
  new({Map<String, LiveProgram>? programs, this.now})
    : programs = programs ?? {};

  final Map<String, LiveProgram> programs;

  /// The server's time (default: the wall clock).
  DateTime Function()? now;
  AppFailure? failure;
  final saved = <List<LiveProgramDraft>>[];
  int reads = 0;

  @override
  Future<LiveProgram> get(String roomId) async {
    reads++;
    if (failure case final f?) throw f;
    return programs[roomId] ?? LiveProgram(roomId: roomId, items: const []);
  }

  @override
  Future<LiveProgram> set(String roomId, List<LiveProgramDraft> items) async {
    if (failure case final f?) throw f;
    saved.add(items);
    final at = (now ?? DateTime.now)();
    final list = [
      for (final (i, d) in items.indexed)
        LiveProgramItem(position: i, startsAt: d.startsAt, title: d.title),
    ];
    final started = list.where((i) => !i.startsAt.isAfter(at));
    return programs[roomId] = LiveProgram(
      roomId: roomId,
      items: list,
      current: started.lastOrNull?.position,
    );
  }
}
