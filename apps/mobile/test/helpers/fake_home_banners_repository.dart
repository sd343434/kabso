import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/features/live/data/home_banners_repository.dart';
import 'package:kabso_live/features/live/domain/home_banner.dart';

/// D124: in-memory promo banners (none by default, as after a deploy).
class FakeHomeBannersRepository implements HomeBannersRepository {
  new({
    this.banners = const [],
    this.failure,
    this.roomBanners = const [],
    this.walletBanners = const [],
    this.hubCardBanners = const [],
    this.hubCardCell = HubCardBanners.defaultCell,
  });

  List<HomeBanner> banners;

  /// D137: the in-room promo box's banners.
  List<HomeBanner> roomBanners;

  /// D177: the wallet page's banners.
  List<HomeBanner> walletBanners;

  /// D248: the live hub's card-size banners and their cell.
  List<HomeBanner> hubCardBanners;
  int hubCardCell;
  AppFailure? failure;
  int calls = 0;

  @override
  Future<List<HomeBanner>> listBanners({
    bool room = false,
    bool wallet = false,
  }) async {
    calls++;
    final f = failure;
    if (f != null) throw f;
    return room
        ? roomBanners
        : wallet
        ? walletBanners
        : banners;
  }

  @override
  Future<HubCardBanners> listHubCardBanners() async {
    calls++;
    final f = failure;
    if (f != null) throw f;
    return HubCardBanners(banners: hubCardBanners, cell: hubCardCell);
  }
}

/// D248: card-size banners (720 × 805, the picture carries its text).
List<HomeBanner> sampleCardBanners({int count = 2}) => [
  for (var i = 0; i < count; i++)
    HomeBanner(
      id: 'card-$i',
      imageUrl: 'https://media.example.test/media/card-$i/720.webp',
      width: 720,
      height: 805,
      link: const ['/families', '/cp/space'][i % 2],
    ),
];

/// Three banners like the owner's (3:1, text in the picture, no overlay).
List<HomeBanner> sampleBanners({int count = 3}) => [
  for (var i = 0; i < count; i++)
    HomeBanner(
      id: 'banner-$i',
      imageUrl: 'https://media.example.test/media/banner-$i/1500.webp',
      link: const ['/families', '/cp/space', '/live?tab=trending'][i % 3],
    ),
];
