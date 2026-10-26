import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/data/live_gift_repository.dart';
import 'package:kabso_live/features/live/domain/live_gift_models.dart';

/// The last catalogue read per app language (CONVENTIONS §10.23: the app
/// caches per language and `version`). Lives as long as the app.
final _giftCatalogueCache = Provider<Map<AppLanguage, GiftCatalogue>>(
  (ref) => {},
);

/// The gift catalogue (`GET /gifts/catalogue`, CP-020). A catalogue read
/// before in this language shows at once and is checked again in the
/// background; the panel redraws only when its `version` moved. Guests
/// read nothing (every gift route needs a token): an empty catalogue.
class GiftCatalogueController extends AsyncNotifier<GiftCatalogue> {
  @override
  Future<GiftCatalogue> build() async {
    final language = ref.watch(languageControllerProvider);
    final signedIn = ref.watch(currentUserProvider.select((u) => u != null));
    if (!signedIn) return emptyGiftCatalogue;
    final cached = ref.read(_giftCatalogueCache)[language];
    if (cached != null) {
      unawaited(_revalidate(language, cached));
      return cached;
    }
    return await _fetch(language);
  }

  Future<GiftCatalogue> _fetch(AppLanguage language) async {
    final catalogue = await ref.read(liveGiftRepositoryProvider).catalogue();
    ref.read(_giftCatalogueCache)[language] = catalogue;
    return catalogue;
  }

  Future<void> _revalidate(AppLanguage language, GiftCatalogue shown) async {
    try {
      final fresh = await _fetch(language);
      if (!ref.mounted) return;
      if (fresh.version != shown.version) state = AsyncData(fresh);
    } on Object {
      // The cached catalogue stays; a send names a gone gift with
      // GIFT_UNAVAILABLE, which reloads.
    }
  }

  /// `GIFT_UNAVAILABLE`: read the catalogue again (and show it).
  Future<void> reload() async {
    final language = ref.read(languageControllerProvider);
    try {
      final fresh = await _fetch(language);
      if (ref.mounted) state = AsyncData(fresh);
    } on Object {
      // Keep what is shown.
    }
  }
}

/// What a guest sees, and the shape of "no gifts yet".
const emptyGiftCatalogue = GiftCatalogue(
  version: '',
  categories: GiftCategory.values,
  quantities: [1],
  maxRecipients: 25,
  comboWindowSeconds: 5,
  data: [],
);

final AsyncNotifierProvider<GiftCatalogueController, GiftCatalogue>
giftCatalogueProvider =
    AsyncNotifierProvider.autoDispose<GiftCatalogueController, GiftCatalogue>(
      GiftCatalogueController.new,
    );

/// The caller's gift bag (`GET /me/gifts/bag`, CP-020): gifts sent without
/// coins. A send's answer carries what is left of that gift ([setQuantity]).
class GiftBagController extends AsyncNotifier<List<GiftBagItem>> {
  @override
  Future<List<GiftBagItem>> build() async {
    ref.watch(languageControllerProvider);
    final signedIn = ref.watch(currentUserProvider.select((u) => u != null));
    if (!signedIn) return const [];
    return await ref.read(liveGiftRepositoryProvider).bag();
  }

  /// The bag holds [quantity] of [code] now (0: it leaves the bag).
  void setQuantity(String code, int quantity) {
    final items = state.value;
    if (items == null) return;
    state = AsyncData([
      for (final item in items)
        if (item.gift.code != code)
          item
        else if (quantity > 0)
          item.copyWith(quantity: quantity),
    ]);
  }
}

final AsyncNotifierProvider<GiftBagController, List<GiftBagItem>>
giftBagProvider =
    AsyncNotifierProvider.autoDispose<GiftBagController, List<GiftBagItem>>(
      GiftBagController.new,
    );
