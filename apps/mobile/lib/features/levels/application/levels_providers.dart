import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/levels/data/levels_repository.dart';
import 'package:kabso_live/features/levels/domain/level_models.dart';
import 'package:kabso_live/features/owner_profile/data/owner_profile_repository.dart'
    show isKabsoOwnerProvider;

// Names and descriptions are localized by the server, so a language change
// reloads them.

/// The caller's four summaries (`GET /levels/me`).
///
/// v1.121-social (D361, §10.156; owner: «المؤسس ليس له ليفيل»): none for
/// the founder — the app guard beside the server's (his public levels are
/// already empty): his Me tab, his own profile, the gift sheet's wealth
/// strip, the live data page and the end-of-live charm card show no level.
final FutureProvider<List<LevelSummary>> myLevelsProvider =
    FutureProvider.autoDispose((ref) async {
      ref.watch(languageControllerProvider);
      if (ref.watch(isKabsoOwnerProvider)) return const <LevelSummary>[];
      return await ref.watch(levelsRepositoryProvider).getMyLevels();
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
      // D361: the founder's own levels — none (see [myLevelsProvider]).
      if (ref.watch(isKabsoOwnerProvider)) return const <PublicLevel>[];
      return [
        for (final s in await repo.getMyLevels())
          PublicLevel(
            category: s.category,
            name: s.name,
            level: s.available ? s.level : null,
          ),
      ];
    });
