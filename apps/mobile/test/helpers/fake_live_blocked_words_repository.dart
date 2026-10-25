import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/features/live/data/live_blocked_words_repository.dart';

/// An in-memory [LiveBlockedWordsRepository] (tests only): saves what it
/// gets, like the server (trimmed, duplicates by lower case dropped).
class FakeLiveBlockedWordsRepository implements LiveBlockedWordsRepository {
  new([List<String> words = const []]) : words = [...words];

  List<String> words;
  final List<List<String>> saves = [];

  /// Fails the next calls.
  AppFailure? failure;

  @override
  Future<List<String>> get() async {
    if (failure case final f?) throw f;
    return [...words];
  }

  @override
  Future<List<String>> set(List<String> next) async {
    if (failure case final f?) throw f;
    saves.add(next);
    final seen = <String>{};
    words = [
      for (final w in next.map((w) => w.trim()))
        if (w.isNotEmpty && seen.add(w.toLowerCase())) w,
    ];
    return [...words];
  }
}
