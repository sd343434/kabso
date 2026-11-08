// D244 (owner, a screenshot of their own profile, ar, light): «الاسم لا يظهر
// تحت الصورة، اجعل الصورة داخل الغلاف لحل المشكلة، يمكن أن تجعل الغلاف أكبر
// قليلاً ليناسب الوضع».
//
// The D218 header put the photo across the cover's lower edge, sized for the
// bare photo; a worn frame (the host-agent frame with the name plate, 1.6 ×
// the photo wide) hung far below it and covered the name («…si» showed).
// Now the photo, frame included, sits wholly inside a slightly taller cover
// at the reading start, and the name starts under the cover.
//
// Checked on the own profile and others' public profiles: no frame, the
// host-agent frame, the recharge-agent frame, a bag frame (all drawn in
// the same box as the CP heart frame), live (the ring and its badge — the
// profile has no animated frame art; the live ring is the moving case), a
// long name; ar / en, light / dark, 393×852 and 360×800 at 1.3.
//
// D278: the cover is now tall and full-bleed with the name over its lower
// part, beside the photo — still never under the photo or its frame.
//
// D299 (owner: «ضع الصورة الشخصية فوق الغلاف، وبجانبها الاسم والشارات»):
// the photo and its frame wholly on the picture again, the name beside it
// on the picture (one line, «…») — still never under the photo or frame.
//
// With D244_CAPTURE_DIR set, the capture test writes PNGs there (not
// committed).

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/features/auth/domain/entities.dart';
import 'package:kabso_live/features/auth/presentation/auth_controller.dart';
import 'package:kabso_live/features/profile/application/profile_grid_provider.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:kabso_live/features/profile/domain/profile_models.dart';
import 'package:kabso_live/features/profile/profile_cover_header.dart';
import 'package:kabso_live/features/profile/profile_screen.dart';
import 'package:kabso_live/features/profile/public_profile_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../helpers/fake_profile_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

const _longName = 'Nabulsi Abdulrahman Al-Khatib the Second';

enum _Look { none, hostAgent, rechargeAgent, bagFrame, live, longName }

PublicProfile _profile(_Look look, {bool self = false}) {
  final base = apiProfile(isSelf: self).copyWith(
    displayName: 'Nabulsi',
    liveRoomId: look == _Look.live ? 'room-0' : null,
  );
  return switch (look) {
    _Look.none || _Look.live => base,
    _Look.hostAgent => base.copyWith(hostAgentCode: 'H-1001'),
    _Look.rechargeAgent => base.copyWith(rechargeAgentCode: 'Nabulsi'),
    _Look.bagFrame => base.copyWith(
      avatarFrame: const AvatarFrame(
        code: 'HOST_FRAME_BLUE',
        assetKey: 'host_frame_blue',
      ),
    ),
    _Look.longName => base.copyWith(
      displayName: _longName,
      hostAgentCode: 'H-1001',
    ),
  };
}

User _me(String name) => User(
  id: 'user-0',
  email: 'me@example.invalid',
  emailVerified: true,
  username: 'coin0001',
  displayName: name,
  locale: 'ar',
  role: UserRole.user,
  isPrivate: false,
  createdAt: DateTime.utc(2026, 10),
  bio: 'hi hi hi hi',
);

final List<Override> _grid = [
  // The captures' real async work must not reach the platform keychain.
  secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
  profileGridProvider.overrideWith(
    (ref, _) =>
        FeedItems([for (var i = 0; i < 6; i++) const ProfileGridItem()]),
  ),
];

Future<void> _pumpPublic(
  WidgetTester tester,
  PublicProfile profile, {
  required AppLanguage language,
  required Brightness brightness,
  GoldenViewport viewport = GoldenViewport.phone,
}) async {
  setViewport(tester, viewport);
  await pumpScreen(
    tester,
    const PublicProfileScreen(username: 'host0'),
    language: language,
    brightness: brightness,
    disableAnimations: true,
    overrides: [
      profileRepositoryProvider.overrideWithValue(
        FakeProfileRepository(profile),
      ),
      ..._grid,
    ],
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpOwn(
  WidgetTester tester,
  PublicProfile stats, {
  required AppLanguage language,
  required Brightness brightness,
  GoldenViewport viewport = GoldenViewport.phone,
}) async {
  setViewport(tester, viewport);
  await pumpScreen(
    tester,
    const ProfileScreen(),
    language: language,
    brightness: brightness,
    disableAnimations: true,
    overrides: [
      meProvider.overrideWith((ref) => _me(stats.displayName)),
      profileStatsProvider.overrideWith((ref, username) => stats),
      ..._grid,
    ],
  );
  await tester.pumpAndSettle();
}

/// D316 (owner: «بدون غلاف»): no cover any more — the photo and the name
/// block at the top of the page ([ProfileCoverHeader.topBlockKey]).
Rect _cover(WidgetTester tester) {
  expect(find.byKey(ProfileCoverHeader.coverFallbackKey), findsNothing);
  expect(find.byKey(ProfileCoverHeader.coverKey), findsNothing);
  return tester.getRect(find.byKey(ProfileCoverHeader.topBlockKey));
}

/// D316 (was D299: at the reading start, the name beside it): the photo
/// and its frame (the avatar's box: the frames' common slot when a frame,
/// the live ring or a team frame is worn) wholly in the top block,
/// centred under the bar; the name centred under it, never under the photo
/// or its frame.
void _expectInside(
  WidgetTester tester, {
  required bool rtl,
  required double width,
}) {
  expect(tester.takeException(), isNull);
  final cover = _cover(tester);
  final photo = tester.getRect(find.byKey(ProfileHeaderView.avatarKey));
  // The avatar's box (frame included) is at most the frames' common slot,
  // wholly on the cover.
  expect(photo.width, lessThanOrEqualTo(KPublicProfile.avatarSlot.width + 0.5));
  expect(
    photo.height,
    lessThanOrEqualTo(KPublicProfile.avatarSlot.height + 0.5),
  );
  expect(photo.top, greaterThanOrEqualTo(cover.top));
  expect(photo.bottom, lessThanOrEqualTo(cover.bottom));
  expect(photo.left, greaterThanOrEqualTo(0));
  expect(photo.right, lessThanOrEqualTo(width));
  // Centred, in both directions ([rtl] mirrors nothing here).
  expect(photo.center.dx, moreOrLessEquals(width / 2, epsilon: 0.5));
  final name = find.byKey(const Key('profile.displayName'));
  final nameRect = tester.getRect(name);
  // The name under the photo's box on the cover, so never under the photo
  // or its frame; centred (a long one is cut with «…»).
  expect(nameRect.bottom, lessThanOrEqualTo(cover.bottom));
  expect(nameRect.overlaps(photo), isFalse);
  expect(nameRect.top, greaterThanOrEqualTo(photo.bottom));
  expect(nameRect.left, greaterThanOrEqualTo(0));
  expect(nameRect.right, lessThanOrEqualTo(width));
}

void main() {
  setUpAll(loadAppFonts);

  test("the photo slot is the frames' common box; the cover picture "
      'holds the whole slot under the bar (D299)', () {
    final slot = KPublicProfile.avatarSlot;
    expect(slot.width, closeTo(1.6 * KProfile.avatar, 0.01));
    expect(slot.height, greaterThanOrEqualTo(1.4 * KProfile.avatar));
    // D299: the bar, a gap, the whole slot and a margin.
    expect(
      KPublicProfile.coverHeightFor(125),
      moreOrLessEquals(
        125 +
            KPublicProfile.avatarTopGap +
            slot.height +
            KPublicProfile.coverBottomGap,
        epsilon: 0.5,
      ),
    );
  });

  group(
    'D244 public profile: the photo inside the cover, the name clear of it',
    () {
      for (final look in _Look.values) {
        for (final language in AppLanguage.values) {
          testWidgets('${look.name} (${language.name}, light, 393×852)', (
            tester,
          ) async {
            final profile = _profile(look);
            await _pumpPublic(
              tester,
              profile,
              language: language,
              brightness: Brightness.light,
            );
            _expectInside(tester, rtl: language == AppLanguage.ar, width: 393);
            if (look == _Look.longName) {
              // D299: the whole name, on one line cut with «…».
              final text = tester.widget<Text>(
                find.byKey(const Key('profile.displayName')),
              );
              expect(text.data, _longName);
              expect(text.maxLines, 1);
              expect(text.overflow, TextOverflow.ellipsis);
            }
          });
        }
      }

      for (final language in AppLanguage.values) {
        for (final look in [_Look.hostAgent, _Look.live, _Look.longName]) {
          testWidgets('${look.name} (${language.name}, dark, 360×800 ×1.3)', (
            tester,
          ) async {
            tester.platformDispatcher.textScaleFactorTestValue = 1.3;
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );
            await _pumpPublic(
              tester,
              _profile(look),
              language: language,
              brightness: Brightness.dark,
              viewport: GoldenViewport.android,
            );
            _expectInside(tester, rtl: language == AppLanguage.ar, width: 360);
          });
        }
      }
    },
  );

  group(
    'D244 own profile: the photo inside the cover, the name clear of it',
    () {
      for (final language in AppLanguage.values) {
        for (final brightness in Brightness.values) {
          for (final look in [_Look.none, _Look.hostAgent, _Look.bagFrame]) {
            testWidgets(
              '${look.name} (${language.name}, ${brightness.name}, 393×852)',
              (tester) async {
                await _pumpOwn(
                  tester,
                  _profile(look, self: true),
                  language: language,
                  brightness: brightness,
                );
                _expectInside(
                  tester,
                  rtl: language == AppLanguage.ar,
                  width: 393,
                );
                // D316: no cover on the page, so no cover button (it is
                // set in the edit screen).
                expect(
                  find.byKey(ProfileCoverHeader.coverButtonKey),
                  findsNothing,
                );
              },
            );
          }
        }
        testWidgets('long name + host frame (${language.name}, 360×800 ×1.3)', (
          tester,
        ) async {
          tester.platformDispatcher.textScaleFactorTestValue = 1.3;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await _pumpOwn(
            tester,
            _profile(_Look.longName, self: true),
            language: language,
            brightness: Brightness.light,
            viewport: GoldenViewport.android,
          );
          _expectInside(tester, rtl: language == AppLanguage.ar, width: 360);
        });
      }
    },
  );

  final captureDir = Platform.environment['D244_CAPTURE_DIR'];
  group('D244 captures', skip: captureDir == null, () {
    Future<void> capture(WidgetTester tester, String name) async {
      await tester.runAsync(() async {
        // Let the frame art decode, then draw it.
        for (final element in find.byType(Image).evaluate()) {
          final image = (element.widget as Image).image;
          await precacheImage(image, element);
        }
      });
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final element = find.byType(Scaffold).evaluate().first;
        final image = await captureImage(element);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('${captureDir!}/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
      });
    }

    testWidgets('own profile, big frame, ar light (393×852)', (tester) async {
      await _pumpOwn(
        tester,
        _profile(_Look.hostAgent, self: true),
        language: AppLanguage.ar,
        brightness: Brightness.light,
      );
      await capture(tester, 'own_big_frame.ar.light');
    });

    testWidgets('own profile, no frame, en dark (393×852)', (tester) async {
      await _pumpOwn(
        tester,
        _profile(_Look.none, self: true),
        language: AppLanguage.en,
        brightness: Brightness.dark,
      );
      await capture(tester, 'own_no_frame.en.dark');
    });

    testWidgets('public profile, recharge frame, ar light, 360×800 ×1.3', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _pumpPublic(
        tester,
        _profile(_Look.rechargeAgent),
        language: AppLanguage.ar,
        brightness: Brightness.light,
        viewport: GoldenViewport.android,
      );
      await capture(tester, 'public_recharge_frame.ar.light.360');
    });
  });
}
