// D265 (owner feedback on VIP 1, D258): the VIP frame's picture fills the
// frame's whole opening (the person card, the seats, the profile), and a VIP
// member's chat lines wear the VIP layout in every chat (the D258 rule: the
// VIP badge, the name, the levels and up to 3 medals on line 1; the message
// alone in the VIP bubble).
//
//   room.person_card.vip   the host's card with the owner's VIP 1 frame
//   room.audio.vip_chat    the audio room: the VIP host's seat frame and the
//                          VIP lines in the chat (the owner's 44.webp)
//   live.flat_chat.vip     the host's flat chat (D253) with a VIP line
//   profile.vip            the profile header with the VIP 1 frame
//   profile.vip_cp         D392: a VIP 1 member whose couple unlocked the CP
//                          Special Frame — one frame (the heart), not the
//                          VIP frame drawn around it as well
//
// The frame is a 256 px still of the owner's `svip_1_frame` (its SVGA stays
// out of git, as D258's); the badge and the bubble have no art here (the
// «VIP1» pill and the tier's deep bubble).
//
// Regenerate on Linux with the pinned Flutter:
//   flutter test --update-goldens test/goldens/vip_d265_golden_test.dart
@Tags(['golden'])
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/cp/domain/cp_models.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/live_room_screen.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_chat_flat_line.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_chat.dart';
import 'package:kabso_live/features/profile/application/profile_grid_provider.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:kabso_live/features/profile/profile_screen.dart';
import 'package:kabso_live/features/profile/public_profile_screen.dart';
import 'package:kabso_live/features/vip/application/vip_look.dart';
import 'package:kabso_live/features/vip/data/vip_repository.dart';
import 'package:kabso_live/features/vip/presentation/vip_parts.dart';
import 'package:kabso_live/features/vip/presentation/vip_wear.dart';
import 'package:material_ui/material_ui.dart';

import '../fixtures/live/live_api_fixtures.dart';
import '../helpers/fake_live_media_engine.dart';
import '../helpers/fake_live_repository.dart';
import '../helpers/fake_profile_repository.dart';
import '../helpers/fakes.dart';
import '../helpers/golden.dart';
import '../helpers/pump_app.dart';
import 'live_person_card_golden_test.dart'
    show personCardProfile, pumpPersonCardRoom;

const _vip1 = UserVip(tier: 'VIP_1', rank: 1, color: 0xFF2E8B3D);
const _frameUrl = 'https://cdn.k.test/vip/svip_1_frame.png';

const _catalog = VipTierList(
  tiers: [
    VipTier(
      id: 'id-VIP_1',
      code: 'VIP_1',
      name: 'VIP 1',
      level: 1,
      color: 0xFF2E8B3D,
      nameColor: 0xFFFFC928,
      priceCoins: 1000000,
      durationDays: 30,
      perks: [
        VipPerk(code: VipPerks.badge, title: 'badge', available: true),
        VipPerk(
          code: VipPerks.avatarFrame,
          title: 'frame',
          available: true,
          still: _frameUrl,
        ),
        VipPerk(code: VipPerks.nameColor, title: 'name', available: true),
        VipPerk(code: VipPerks.bubble, title: 'bubble', available: true),
      ],
    ),
  ],
  maxAheadDays: 400,
);

final Uint8List _frameBytes = File('test/fixtures/vip/svip_1_frame_still.png')
    .readAsBytesSync();

const _badges = LiveChatAuthorBadges(
  charmLevel: 17,
  supportLevel: 12,
  newcomer: true,
  medals: [
    LiveChatAuthorMedal(code: 'm1', iconKey: 'medal_first_family'),
    LiveChatAuthorMedal(code: 'm2', iconKey: 'medal_first_cp'),
    LiveChatAuthorMedal(code: 'm3', iconKey: 'medal_charm_10'),
    LiveChatAuthorMedal(code: 'm4', iconKey: 'medal_first_live'),
  ],
);

UserSummary _host({required bool ar}) => UserSummary(
  id: 'user-0',
  username: 'host0',
  displayName: ar ? 'نبّ' : 'nabb',
  avatarUrl: null,
  vip: _vip1,
);

void main() {
  setUp(() => vipImageFor = (_) => MemoryImage(_frameBytes));
  tearDown(() => vipImageFor = NetworkImage.new);

  testWidgets('room.person_card.vip ar', (tester) async {
    await pumpPersonCardRoom(
      tester,
      language: AppLanguage.ar,
      profile: personCardProfile(ar: true).copyWith(vip: _vip1),
      extraOverrides: [
        vipCatalogProvider.overrideWith((ref) async => _catalog),
      ],
    );
    await precacheImages(tester);
    await tester.pumpAndSettle();
    expect(find.byKey(VipAvatarFrame.frameKey), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('png/room.person_card.vip.ar.phone.png'),
    );
  });

  testWidgets('room.audio.vip_chat ar', (tester) async {
    const ar = true;
    await loadAppFonts();
    setViewport(tester, GoldenViewport.phone);
    tester.view.padding = const FakeViewPadding(
      top: 59 * GoldenViewport.pixelRatio,
      bottom: 34 * GoldenViewport.pixelRatio,
    );
    addTearDown(tester.view.resetPadding);
    final host = _host(ar: ar);
    final repo =
        FakeLiveRepository(
            room: (id) => apiRoom(
              id: id,
              ar: ar,
            ).copyWith(mode: LiveRoomMode.audio, seatCount: 10, host: host),
          )
          ..chat = [
            LiveChatEntry(
              id: 'm1',
              roomId: 'room-0',
              author: host,
              authorRole: LiveChatRole.host,
              text: 'أهلاً بكم في البث',
              createdAt: DateTime.utc(2026, 11, 4, 16, 29),
              authorBadges: _badges,
            ),
            LiveChatEntry(
              id: 'm2',
              roomId: 'room-0',
              author: const UserSummary(
                id: 'user-2',
                username: 'muna',
                displayName: 'منى',
                avatarUrl: null,
              ),
              authorRole: LiveChatRole.viewer,
              text: 'مساء الخير',
              createdAt: DateTime.utc(2026, 11, 4, 16, 30),
              authorBadges: const LiveChatAuthorBadges(charmLevel: 3),
            ),
            LiveChatEntry(
              id: 'm3',
              roomId: 'room-0',
              author: host,
              authorRole: LiveChatRole.host,
              text: 'jdk',
              createdAt: DateTime.utc(2026, 11, 4, 16, 31),
              authorBadges: _badges,
            ),
          ];
    await pumpScreen(
      tester,
      const LiveRoomScreen(roomId: 'room-0'),
      language: AppLanguage.ar,
      brightness: Brightness.light,
      disableAnimations: true,
      liveMediaEngine: FakeLiveMediaEngine()..present.add('user-0'),
      overrides: [
        liveRepositoryProvider.overrideWithValue(repo),
        profileRepositoryProvider.overrideWithValue(
          FakeProfileRepository(personCardProfile(ar: ar)),
        ),
        currentUserProvider.overrideWithValue(testUser()),
        vipCatalogProvider.overrideWith((ref) async => _catalog),
      ],
    );
    await tester.pumpAndSettle();
    await precacheImages(tester);
    await tester.pumpAndSettle();
    // Both of the host's lines in the VIP layout (the bubble, the badge);
    // the plain line keeps its box. The host's seat wears the frame.
    expect(find.byKey(LiveRoomChatLines.vipLineKey), findsNWidgets(2));
    expect(find.byKey(KFlatChat.vipBubbleKey), findsNWidgets(2));
    expect(find.byKey(VipNameBadge.badgeKey), findsNWidgets(2));
    expect(find.byKey(LiveChatAuthoredLine.boxKey), findsOneWidget);
    expect(find.byKey(VipAvatarFrame.frameKey), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('png/room.audio.vip_chat.ar.phone.png'),
    );
  });

  testWidgets('live.flat_chat.vip ar', (tester) async {
    await pumpGolden(
      tester,
      ProviderScope(
        overrides: [vipCatalogProvider.overrideWith((ref) async => _catalog)],
        child: const ColoredBox(
          color: Color(0xFF3A4150),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LiveChatFlatLine(
                    name: 'نبّ',
                    text: 'أهلاً بكم في البث',
                    label: 'line',
                    role: LiveChatRole.host,
                    vip: _vip1,
                    badges: _badges,
                  ),
                  SizedBox(height: KFlatChat.gap),
                  LiveChatFlatLine(
                    name: 'منى',
                    text: 'مساء الخير',
                    label: 'line',
                    role: LiveChatRole.viewer,
                    badges: LiveChatAuthorBadges(charmLevel: 3),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      language: AppLanguage.ar,
      bare: true,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(KFlatChat.vipBubbleKey), findsOneWidget);
    expect(find.byKey(LiveChatFlatLine.vipHeaderKey), findsOneWidget);
    await expectScreenGolden('live.flat_chat.vip', language: AppLanguage.ar);
  });

  testWidgets('profile.vip ar', (tester) async {
    await loadAppFonts();
    setViewport(tester, GoldenViewport.phone);
    await pumpScreen(
      tester,
      const PublicProfileScreen(username: 'host0'),
      language: AppLanguage.ar,
      brightness: Brightness.light,
      disableAnimations: true,
      overrides: [
        profileRepositoryProvider.overrideWithValue(
          FakeProfileRepository(
            apiProfile(ar: true)
                .copyWith(displayName: 'نبّ', vip: _vip1, liveRoomId: null),
          ),
        ),
        vipCatalogProvider.overrideWith((ref) async => _catalog),
        secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
        profileGridProvider.overrideWith(
          (ref, _) =>
              FeedItems([for (var i = 0; i < 6; i++) const ProfileGridItem()]),
        ),
      ],
    );
    await tester.pumpAndSettle();
    await precacheImages(tester);
    await tester.pumpAndSettle();
    expect(find.byKey(VipAvatarFrame.frameKey), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('png/profile.vip.ar.phone.png'),
    );
  });

  // D392 (owner: «هناك إطارين والصورة شخصية اسفل الإطار»): a VIP 1 member
  // whose couple unlocked the CP Special Frame wore both frames on the
  // profile header — the VIP frame centred on the photo slot and, inside it,
  // the heart frame with the picture in the heart's lower opening. The
  // Special Frame wins (as on the person card): one frame, the picture in
  // its opening.
  testWidgets('profile.vip_cp ar', (tester) async {
    await loadAppFonts();
    setViewport(tester, GoldenViewport.phone);
    await pumpScreen(
      tester,
      const PublicProfileScreen(username: 'host0'),
      language: AppLanguage.ar,
      brightness: Brightness.light,
      disableAnimations: true,
      overrides: [
        profileRepositoryProvider.overrideWithValue(
          FakeProfileRepository(
            apiProfile(ar: true).copyWith(
              displayName: 'نبّ',
              vip: _vip1,
              liveRoomId: null,
              cp: ProfileCp(
                id: 'cp-1',
                partner: const UserSummary(
                  id: 'u-omar',
                  username: 'omar',
                  displayName: 'Omar',
                  avatarUrl: null,
                ),
                since: DateTime.utc(2026, 10, 2),
                level: 4,
                levelName: 'Diamond couple',
                points: 6000,
                privileges: const ['SPECIAL_FRAME'],
              ),
            ),
          ),
        ),
        vipCatalogProvider.overrideWith((ref) async => _catalog),
        secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
        profileGridProvider.overrideWith(
          (ref, _) =>
              FeedItems([for (var i = 0; i < 6; i++) const ProfileGridItem()]),
        ),
      ],
    );
    await tester.pumpAndSettle();
    await precacheImages(tester);
    await tester.pumpAndSettle();
    expect(find.byKey(ProfileHeaderView.cpFrameKey), findsOneWidget);
    expect(find.byKey(VipAvatarFrame.frameKey), findsNothing);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('png/profile.vip_cp.ar.phone.png'),
    );
  });
}
