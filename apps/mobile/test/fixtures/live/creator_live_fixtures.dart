// v1.82-live (D295): hub cards alternating a host's live and a content
// creator's live (the purple «صانع محتوى» badge), as the 1 : 1 list returns
// them. Test-only (never imported by lib/).

import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_view_data.dart';

import 'live_fixtures.dart';

List<LiveRoomCardData> creatorLiveRooms(AppLanguage language) {
  final ar = language == AppLanguage.ar;
  return [
    LiveRoomCardData(
      hostName: ar ? 'خالد' : 'Khalid',
      title: ar ? 'سهرة طرب مع المتابعين' : 'Music night with fans',
      viewerCount: 1240,
      cover: coverRed,
    ),
    LiveRoomCardData(
      hostName: ar ? 'سارة' : 'Sara',
      title: ar ? 'كواليس تصوير الفيديو' : 'Behind my video shoot',
      viewerCount: 3180,
      cover: coverBlue,
      hostIsCreator: true,
    ),
    LiveRoomCardData(
      hostName: ar ? 'ليلى' : 'Layla',
      title: ar ? 'دردشة الصباح' : 'Morning chat',
      viewerCount: 87,
      cover: coverGold,
      isAudio: true,
    ),
    LiveRoomCardData(
      hostName: ar ? 'يوسف' : 'Youssef',
      title: ar ? 'تحدي الكوميديا' : 'Comedy challenge',
      viewerCount: 0,
      cover: coverRed,
      hostIsCreator: true,
    ),
  ];
}
