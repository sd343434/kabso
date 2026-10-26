import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/medals/data/medals_repository.dart';
import 'package:kabso_live/features/medals/domain/medal_models.dart';

// Medal names are localized by the server, so a language change reloads
// them.

/// The catalogue with the caller's medals (`GET /medals`).
final FutureProvider<MedalCatalogue> medalCatalogueProvider =
    FutureProvider.autoDispose((ref) {
      ref
        ..watch(languageControllerProvider)
        ..watch(currentUserProvider.select((u) => u?.id));
      return ref.watch(medalsRepositoryProvider).catalogue();
    });

/// The caller's showcase (`GET /me/medals/showcase`).
final FutureProvider<List<ProfileMedal>> myShowcaseProvider =
    FutureProvider.autoDispose((ref) {
      ref
        ..watch(languageControllerProvider)
        ..watch(currentUserProvider.select((u) => u?.id));
      return ref.watch(medalsRepositoryProvider).showcase();
    });

/// Another user's medals (`GET /users/{username}/medals`).
final FutureProviderFamily<UserMedalList, String> userMedalsProvider =
    FutureProvider.autoDispose.family((ref, username) {
      ref.watch(languageControllerProvider);
      return ref.watch(medalsRepositoryProvider).userMedals(username);
    });
