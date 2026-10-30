import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/bag/data/bag_repository.dart';
import 'package:kabso_live/features/bag/domain/bag_models.dart';

// Item names are localized by the server, so a language change reloads
// them.

/// D171: the items the caller owns now, every category
/// (`GET /me/bag`). The bag never lists items the caller does not own.
final FutureProvider<List<BagItem>> myBagItemsProvider =
    FutureProvider.autoDispose((ref) {
      ref
        ..watch(languageControllerProvider)
        ..watch(currentUserProvider.select((u) => u?.id));
      return ref.watch(bagRepositoryProvider).myBag();
    });

/// D186: the caller's active-host frame (`GET /me/host-frame`): whether the
/// bag asks a host without a stated gender to pick the colour.
final FutureProvider<HostFrame> myHostFrameProvider =
    FutureProvider.autoDispose((ref) {
      ref.watch(currentUserProvider.select((u) => u?.id));
      return ref.watch(bagRepositoryProvider).hostFrame();
    });
