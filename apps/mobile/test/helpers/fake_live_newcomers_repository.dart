// In-memory newcomers (D154c, tests only).

import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/features/live/data/live_newcomers_repository.dart';

class FakeLiveNewcomersRepository implements LiveNewcomersRepository {
  new({this.people = const [], this.failure});

  List<UserSummary> people;
  AppFailure? failure;
  int calls = 0;

  @override
  Future<LiveNewcomers> list(String roomId) async {
    calls++;
    if (failure case final f?) throw f;
    return (newcomerDays: 30, people: people);
  }
}
