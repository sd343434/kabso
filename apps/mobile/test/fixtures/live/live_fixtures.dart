// Seeded, fake live data for widget and golden tests ONLY (G-26). Never
// imported by lib/ (enforced by test/fixtures/fixtures_isolation_test.dart);
// production screens keep their honest empty states until the Phase 6/7
// APIs exist.

import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/tokens/tokens.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_view_data.dart';
import 'package:material_ui/material_ui.dart';

import '../fixture_images.dart';

/// Cover stand-ins in Kabso token colours.
final MemoryImage coverRed = fixtureImage(
  top: KBrandColors.red400,
  bottom: KBrandColors.red700,
);
final MemoryImage coverBlue = fixtureImage(
  top: KLiveColors.pkRight,
  bottom: KPalette.dark.surfaceOverlay,
);
final MemoryImage coverGold = fixtureImage(
  top: KBrandColors.gold,
  bottom: KBrandColors.red600,
);
final MemoryImage avatarImage = fixtureImage(
  top: KLiveColors.pkLeft,
  bottom: KLiveColors.pkRight,
  width: 48,
  height: 48,
);

/// Viewer counts covering every compact-format band (DESIGN_SYSTEM §3.3).
const viewerCountSamples = [0, 987, 9999, 12345, 1234567, 2000000000];

List<LiveRoomCardData> liveRooms(AppLanguage language) {
  final ar = language == AppLanguage.ar;
  return [
    LiveRoomCardData(
      hostName: ar ? 'سارة' : 'Sara',
      title: ar ? 'سهرة موسيقى عربية' : 'Arabic music night',
      viewerCount: 12345,
      cover: coverRed,
    ),
    LiveRoomCardData(
      hostName: ar ? 'خالد' : 'Khalid',
      title: ar ? 'تحدي PK مع المتابعين' : 'PK challenge with fans',
      viewerCount: 987,
      cover: coverBlue,
      inPk: true,
    ),
    LiveRoomCardData(
      // Long title: must stay on one line with an ellipsis.
      hostName: ar ? 'نور الهدى عبد الرحمن' : 'Nour Al-Huda Abdulrahman',
      title: ar
          ? 'دردشة مفتوحة عن السفر والطبخ والكتب وكل ما تحبون الحديث عنه الليلة'
          : 'Open chat about travel, cooking, books and anything you like',
      viewerCount: 1234567,
      cover: coverGold,
    ),
    LiveRoomCardData(
      hostName: ar ? 'Omar' : 'عمر',
      title: ar ? 'Morning coffee' : 'قهوة الصباح',
      viewerCount: 0,
      cover: brokenFixtureImage,
    ),
  ];
}

/// Mixed-script chat: Arabic lines in an English UI and the reverse.
List<LiveChatLine> chatLines(AppLanguage language) {
  final ar = language == AppLanguage.ar;
  return [
    LiveChatSystem(
      text: ar
          ? 'مرحبًا بكم! التزموا بإرشادات المجتمع.'
          : 'Welcome! Please follow the community guidelines.',
    ),
    const LiveChatJoin(name: 'layla_99'),
    const LiveChatMessage(name: 'Ahmad', text: 'السلام عليكم'),
    const LiveChatMessage(name: 'مريم', text: 'Hello from Dubai!'),
    LiveChatGift(name: 'Yousef', giftName: ar ? 'نجمة' : 'Star', count: 3),
    const LiveChatMessage(
      name: 'سامي',
      text: 'صوتك رائع ما شاء الله، كمّلي الأغنية',
    ),
    const LiveChatJoin(name: 'رنا'),
    const LiveChatMessage(name: 'Lina', text: 'Can you play it again?'),
  ];
}

List<GiftItemData> gifts(AppLanguage language) {
  final ar = language == AppLanguage.ar;
  return [
    GiftItemData(
      id: 'heart',
      name: ar ? 'قلب' : 'Heart',
      price: 1,
      shape: GiftShape.heart,
    ),
    GiftItemData(
      id: 'star',
      name: ar ? 'نجمة' : 'Star',
      price: 10,
      shape: GiftShape.star,
    ),
    GiftItemData(
      id: 'diamond',
      name: ar ? 'ماسة' : 'Diamond',
      price: 99,
      shape: GiftShape.diamond,
    ),
    GiftItemData(
      id: 'crown',
      name: ar ? 'تاج' : 'Crown',
      price: 520,
      shape: GiftShape.crown,
    ),
    GiftItemData(
      id: 'heart-xl',
      name: ar ? 'قلب كبير' : 'Big heart',
      price: 1314,
      shape: GiftShape.heart,
    ),
    GiftItemData(
      id: 'star-xl',
      name: ar ? 'مطر النجوم' : 'Star shower',
      price: 9999,
      shape: GiftShape.star,
    ),
    GiftItemData(
      id: 'diamond-xl',
      name: ar ? 'كنز الماس' : 'Diamond chest',
      price: 12500,
      shape: GiftShape.diamond,
    ),
    GiftItemData(
      id: 'crown-xl',
      name: ar ? 'تاج الملوك' : 'Royal crown',
      price: 30000,
      shape: GiftShape.crown,
    ),
  ];
}

/// Category tab labels (server-defined in the future).
List<String> categories(AppLanguage language) => language == AppLanguage.ar
    ? const ['الكل', 'قريب', 'موسيقى', 'ألعاب', 'دردشة', 'PK', 'جديد', 'رياضة']
    : const ['All', 'Nearby', 'Music', 'Games', 'Chat', 'PK', 'New', 'Sports'];

/// PK snapshots: (host, opponent, time left, result).
const pkSnapshots = <(int, int, Duration?, PkResult?)>[
  (0, 0, Duration(minutes: 2), null),
  (9000, 1000, Duration(seconds: 9), null),
  (4200, 3800, null, PkResult.win),
  (1500, 2500, null, PkResult.lose),
  (2000, 2000, null, PkResult.draw),
];

/// Viewer names for the room's viewer strip.
const viewerNames = ['Ahmad', 'مريم', 'Lina', 'Yousef'];

/// A muted backdrop used behind overlay goldens instead of real video.
Widget fakeVideoFrame() => DecoratedBox(
  decoration: BoxDecoration(
    image: DecorationImage(image: coverBlue, fit: BoxFit.cover),
  ),
);
