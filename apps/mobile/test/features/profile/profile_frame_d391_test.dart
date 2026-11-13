// D391 (owner, a VIP 1 member's public profile: «انظر للإطار هناك إطارين
// والصورة شخصية اسفل الإطار هناك خلل واضح»): the profile header drew the VIP
// frame around the CP Special Frame — two frames, the VIP one centred on the
// photo slot and the picture low and small in the heart's opening. One frame
// shows (the Special Frame wins, as on the person card), and with the VIP
// frame alone the picture sits centred in its window, a hair larger.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/design_system/components/k_avatar.dart';
import 'package:kabso_live/features/cp/domain/cp_models.dart';
import 'package:kabso_live/features/cp/presentation/cp_special_frame.dart';
import 'package:kabso_live/features/profile/application/profile_grid_provider.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:kabso_live/features/profile/domain/profile_models.dart';
import 'package:kabso_live/features/profile/profile_screen.dart';
import 'package:kabso_live/features/profile/public_profile_screen.dart';
import 'package:kabso_live/features/vip/application/vip_look.dart';
import 'package:kabso_live/features/vip/data/vip_repository.dart';
import 'package:kabso_live/features/vip/presentation/vip_parts.dart';
import 'package:kabso_live/features/vip/presentation/vip_wear.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../helpers/fake_profile_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

const _vip1 = UserVip(tier: 'VIP_1', rank: 1, color: 0xFF2E8B3D);

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
        VipPerk(
          code: VipPerks.avatarFrame,
          title: 'frame',
          available: true,
          still: 'https://cdn.k.test/vip/svip_1_frame.png',
        ),
      ],
    ),
  ],
  maxAheadDays: 400,
);

/// The existing test still of the VIP 1 frame (D265's fixture).
final Uint8List _frameBytes = File('test/fixtures/vip/svip_1_frame_still.png')
    .readAsBytesSync();

PublicProfile _profile({required bool ar, required bool cp}) =>
    apiProfile(ar: ar).copyWith(
      vip: _vip1,
      liveRoomId: null,
      cp: cp
          ? ProfileCp(
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
            )
          : null,
    );

Future<void> _pump(
  WidgetTester tester, {
  required AppLanguage language,
  required bool cp,
}) async {
  setViewport(tester, GoldenViewport.android);
  await tester.pumpWidget(const SizedBox.shrink());
  await pumpScreen(
    tester,
    const PublicProfileScreen(username: 'host0'),
    language: language,
    disableAnimations: true,
    overrides: [
      profileRepositoryProvider.overrideWithValue(
        FakeProfileRepository(_profile(ar: language == AppLanguage.ar, cp: cp)),
      ),
      vipCatalogProvider.overrideWith((ref) async => _catalog),
      secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
      profileGridProvider.overrideWith(
        (ref, _) =>
            FeedItems([for (var i = 0; i < 3; i++) const ProfileGridItem()]),
      ),
    ],
  );
  await tester.pumpAndSettle();
}

/// The header's photo (the one [KAvatar] inside the avatar slot).
Rect _picture(WidgetTester tester) => tester.getRect(
  find.descendant(
    of: find.byKey(ProfileHeaderView.avatarKey),
    matching: find.byType(KAvatar),
  ),
);

void main() {
  setUp(() => vipImageFor = (_) => MemoryImage(_frameBytes));
  tearDown(() => vipImageFor = NetworkImage.new);

  for (final language in AppLanguage.values) {
    testWidgets('VIP + CP Special Frame: one frame, the picture in the '
        "heart's opening (${language.name})", (tester) async {
      await _pump(tester, language: language, cp: true);
      expect(find.byKey(ProfileHeaderView.cpFrameKey), findsOneWidget);
      // Before D391 the VIP frame was drawn around the heart as well.
      expect(find.byKey(VipAvatarFrame.frameKey), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(ProfileHeaderView.avatarKey),
          matching: find.byType(KAvatar),
        ),
        findsOneWidget,
      );
      // The picture fills the heart's opening (it is clipped to it): as
      // wide at least, centred across, its centre inside the opening.
      final heart = tester.getRect(find.byKey(ProfileHeaderView.cpFrameKey));
      final picture = _picture(tester);
      final width = heart.width;
      final hole = CpSpecialFrameAvatar.pictureWidth(width);
      final holeCentreY =
          heart.top + CpSpecialFrameAvatar.pictureCentreY(width);
      expect(picture.width, greaterThanOrEqualTo(hole - 1));
      expect(picture.center.dx, closeTo(heart.center.dx, 2));
      expect(picture.center.dy, closeTo(holeCentreY, hole / 2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('VIP frame alone: the picture is centred in its window, a '
        'hair larger, and bare (${language.name})', (tester) async {
      await _pump(tester, language: language, cp: false);
      expect(find.byKey(ProfileHeaderView.cpFrameKey), findsNothing);
      final frame = tester.getRect(find.byKey(VipAvatarFrame.frameKey));
      final picture = _picture(tester);
      expect(picture.center.dx, closeTo(frame.center.dx, 0.5));
      expect(picture.center.dy, closeTo(frame.center.dy, 0.5));
      final window = frame.width * VipAvatarFrame.templateWindow;
      expect(picture.width, greaterThanOrEqualTo(window));
      expect(picture.width, lessThan(window * 1.03));
      // No ring of its own between the picture and the frame (D265).
      final avatar = tester.widget<KAvatar>(
        find.descendant(
          of: find.byKey(ProfileHeaderView.avatarKey),
          matching: find.byType(KAvatar),
        ),
      );
      expect(avatar.ring, KAvatarRing.none);
      expect(tester.takeException(), isNull);
    });
  }
}
