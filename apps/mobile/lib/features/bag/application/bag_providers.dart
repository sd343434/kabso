import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/bag/data/bag_repository.dart';
import 'package:kabso_live/features/bag/domain/bag_models.dart';

// Item names are localized by the server, so a language change reloads
// them.

/// The catalogue of one category (`GET /bag/catalogue?category=`).
final FutureProviderFamily<List<BagCatalogueItem>, BagCategory>
bagCatalogueProvider = FutureProvider.autoDispose.family((ref, category) {
  ref
    ..watch(languageControllerProvider)
    ..watch(currentUserProvider.select((u) => u?.id));
  return ref.watch(bagRepositoryProvider).catalogue(category: category);
});

/// The caller's items of one category (`GET /me/bag?category=`).
final FutureProviderFamily<List<BagItem>, BagCategory> myBagProvider =
    FutureProvider.autoDispose.family((ref, category) {
      ref
        ..watch(languageControllerProvider)
        ..watch(currentUserProvider.select((u) => u?.id));
      return ref.watch(bagRepositoryProvider).myBag(category: category);
    });
