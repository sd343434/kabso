import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/levels/data/levels_repository.dart';
import 'package:kabso_live/features/levels/domain/level_models.dart';

// Names and descriptions are localized by the server, so a language change
// reloads them.

/// The caller's four summaries (`GET /levels/me`).
final FutureProvider<List<LevelSummary>> myLevelsProvider =
    FutureProvider.autoDispose((ref) {
      ref.watch(languageControllerProvider);
      return ref.watch(levelsRepositoryProvider).getMyLevels();
    });

/// One category with its ladder (`GET /levels/me/{category}`).
final FutureProviderFamily<LevelDetail, LevelCategory> myLevelProvider =
    FutureProvider.autoDispose.family((ref, category) {
      ref.watch(languageControllerProvider);
      return ref.watch(levelsRepositoryProvider).getMyLevel(category);
    });

/// The levels shown on a profile: the caller's own (from
/// `GET /levels/me`) or another user's (`GET /users/{username}/levels`).
/// `username` null = the caller.
final FutureProviderFamily<List<PublicLevel>, String?> profileLevelsProvider =
    FutureProvider.autoDispose.family((ref, username) async {
      ref.watch(languageControllerProvider);
      final repo = ref.watch(levelsRepositoryProvider);
      if (username != null) return await repo.getUserLevels(username);
      return [
        for (final s in await repo.getMyLevels())
          PublicLevel(
            category: s.category,
            name: s.name,
            level: s.available ? s.level : null,
          ),
      ];
    });
