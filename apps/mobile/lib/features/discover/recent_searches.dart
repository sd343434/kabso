import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';

/// D157: this device's last searches (the normalized query), newest first,
/// at most [maxCount]; kept on the device only (shared preferences), per
/// account so another account on the phone never sees them. Never sent to
/// the server (trends are counted separately, §11.11).
class RecentSearchesController extends Notifier<List<String>> {
  static const maxCount = 10;

  String? get _key => switch (ref.read(currentUserProvider)) {
    final u? => 'pref.recentSearches.${u.id}',
    null => null,
  };

  @override
  List<String> build() {
    ref.watch(currentUserProvider.select((u) => u?.id));
    final key = _key;
    if (key == null) return const [];
    try {
      return List.unmodifiable(
        ref.read(sharedPreferencesProvider).getStringList(key) ?? const [],
      );
    } on Object {
      return const [];
    }
  }

  /// [query] was searched: it moves to the front (one entry per query,
  /// whatever its letter case).
  void add(String query) {
    final q = query.trim();
    if (q.isEmpty) return;
    final lower = q.toLowerCase();
    _save(
      [
        q,
        for (final s in state)
          if (s.toLowerCase() != lower) s,
      ].take(maxCount).toList(),
    );
  }

  void remove(String query) => _save([
    for (final s in state)
      if (s != query) s,
  ]);

  void clear() => _save(const []);

  void _save(List<String> next) {
    state = List.unmodifiable(next);
    final key = _key;
    if (key == null) return;
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      unawaited(
        next.isEmpty ? prefs.remove(key) : prefs.setStringList(key, next),
      );
    } on Object {
      // Kept in memory only.
    }
  }
}

final NotifierProvider<RecentSearchesController, List<String>>
recentSearchesProvider =
    NotifierProvider<RecentSearchesController, List<String>>(
      RecentSearchesController.new,
    );
