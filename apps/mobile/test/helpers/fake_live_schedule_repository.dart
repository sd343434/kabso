import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/features/live/data/live_schedule_repository.dart';

/// An in-memory [LiveScheduleRepository] (tests only): keeps the slots
/// soonest first, like the server.
class FakeLiveScheduleRepository implements LiveScheduleRepository {
  new([List<LiveScheduleSlot> slots = const []]) : slots = [...slots];

  List<LiveScheduleSlot> slots;
  final List<({String title, DateTime startsAt})> created = [];
  final List<String> removed = [];
  int _next = 0;

  /// Fails the next calls.
  AppFailure? failure;

  @override
  Future<List<LiveScheduleSlot>> list() async {
    if (failure case final f?) throw f;
    return [...slots];
  }

  @override
  Future<LiveScheduleSlot> create({
    required String title,
    required DateTime startsAt,
  }) async {
    if (failure case final f?) throw f;
    created.add((title: title, startsAt: startsAt));
    final slot = LiveScheduleSlot(
      id: 'slot-${_next++}',
      title: title.trim(),
      startsAt: startsAt,
    );
    slots = [...slots, slot]..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return slot;
  }

  @override
  Future<void> remove(String slotId) async {
    if (failure case final f?) throw f;
    removed.add(slotId);
    slots = [
      for (final s in slots)
        if (s.id != slotId) s,
    ];
  }
}
