import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/features/live/data/home_banners_repository.dart';
import 'package:kabso_live/features/live/domain/home_banner.dart';

/// D124: in-memory promo banners (none by default, as after a deploy).
class FakeHomeBannersRepository implements HomeBannersRepository {
  new({this.banners = const [], this.failure, this.roomBanners = const []});

  List<HomeBanner> banners;

  /// D137: the in-room promo box's banners.
  List<HomeBanner> roomBanners;
  AppFailure? failure;
  int calls = 0;

  @override
  Future<List<HomeBanner>> listBanners({bool room = false}) async {
    calls++;
    final f = failure;
    if (f != null) throw f;
    return room ? roomBanners : banners;
  }
}

/// Three banners like the owner's (3:1, text in the picture, no overlay).
List<HomeBanner> sampleBanners({int count = 3}) => [
  for (var i = 0; i < count; i++)
    HomeBanner(
      id: 'banner-$i',
      imageUrl: 'https://media.example.test/media/banner-$i/1500.webp',
      link: const ['/families', '/cp/space', '/live?tab=trending'][i % 3],
    ),
];
