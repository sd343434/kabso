import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/features/live/application/live_rooms_provider.dart';
import 'package:kabso_live/features/live/data/home_banners_repository.dart';
import 'package:kabso_live/features/live/domain/home_banner.dart';

/// D124: the active promo banners of the live hub, reloaded when the user
/// or the language changes (titles are localized by the server) and by the
/// hub's pull to refresh. A failure shows no banner (the banner is never a
/// reason to show an error on the hub).
final homeBannersProvider = FutureProvider<List<HomeBanner>>((ref) {
  ref.watch(liveScopeProvider);
  return ref.watch(homeBannersRepositoryProvider).listBanners();
});
