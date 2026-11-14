// D376 (owner 2026-11-12) «الحالة» — animated status emoji over a picture:
//
//   status.picker.<ar|en>.<light|dark>   Edit profile › «الحالة»: the live
//                                        preview (bubbles), the pack tabs,
//                                        «عام» with «حفلة» chosen
//   status.picker_locked.ar.dark         «المميزة» not held: an emoji
//                                        previewed, the lock, «افتح المتجر»
//   status.store.ar.dark                 «متجر الحالة»: preview, the pack,
//                                        100,000 coins / 30 days, Buy
//   status.store_held.en.light           held: «active until», Renew
//   status.store_short.ar.light          too few coins: «اشحن العملات»
//   status.profile.ar.dark               a profile with its status rising
//   status.profile_reduced.ar.light      reduced motion: the still emoji
//   status.seats.ar.dark                 the audio seats (host + guests)
//
// 393 × 852 with the status bar 59 and the home indicator 34; the clock is
// pinned (2027-05-05 10:00 UTC) and the bubbles hold one moment
// (`StatusEmojiLayer.debugTime`, flutter_test_config.dart). Regenerate on
// Linux with the pinned Flutter:
//   flutter test --update-goldens test/goldens/status_emoji_d376_golden_test.dart
@Tags(['golden'])
library;

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_seat_tiles.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:kabso_live/features/profile/public_profile_screen.dart';
import 'package:kabso_live/features/status/status_emoji_layer.dart';
import 'package:kabso_live/features/status/status_picker_sheet.dart';
import 'package:kabso_live/features/status/status_store_screen.dart';
import 'package:material_ui/material_ui.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../features/status/status_harness.dart';
import '../fixtures/live/live_api_fixtures.dart';
import '../fixtures/status/status_fixtures.dart';
import '../helpers/fake_profile_repository.dart';
import '../helpers/fake_status_repository.dart';
import '../helpers/golden.dart';

Future<void> _golden(String name) => expectLater(
  find.byType(MaterialApp),
  matchesGoldenFile('png/$name.phone.png'),
);

UserSummary _guest(int i, String name, String? status) => UserSummary(
  id: 'u$i',
  username: 'guest$i',
  displayName: name,
  avatarUrl: null,
  statusEmojiId: status,
);

void main() {
  for (final language in AppLanguage.values) {
    for (final brightness in Brightness.values) {
      testWidgets('picker (${language.name} ${brightness.name})', (
        tester,
      ) async {
        await withClock(Clock.fixed(statusFixtureNow), () async {
          await pumpStatus(
            tester,
            const StatusSheetHost(initialId: 'noto.party'),
            language: language,
            brightness: brightness,
          );
          expect(
            find.byKey(StatusEmojiLayer.keyOf('noto.party')),
            findsOneWidget,
          );
          await _golden('status.picker.${language.name}.${brightness.name}');
        });
      });
    }
  }

  testWidgets('picker, «المميزة» locked (ar dark)', (tester) async {
    await withClock(Clock.fixed(statusFixtureNow), () async {
      await pumpStatus(
        tester,
        const StatusSheetHost(initialId: 'premium.eagle'),
      );
      await settleStatus(tester);
      expect(find.byKey(StatusPickerSheet.storeKey), findsOneWidget);
      await _golden('status.picker_locked.ar.dark');
    });
  });

  testWidgets('store (ar dark)', (tester) async {
    await withClock(Clock.fixed(statusFixtureNow), () async {
      await pumpStatus(
        tester,
        const StatusStoreScreen(
          packId: 'premium',
          displayName: 'ليلى',
          initialPreviewId: 'premium.peacock',
        ),
      );
      await _golden('status.store.ar.dark');
    });
  });

  testWidgets('store, held (en light)', (tester) async {
    await withClock(Clock.fixed(statusFixtureNow), () async {
      await pumpStatus(
        tester,
        const StatusStoreScreen(packId: 'premium', displayName: 'Layla'),
        language: AppLanguage.en,
        brightness: Brightness.light,
        repo: FakeStatusRepository(
          list: statusPackListFixture(
            heldUntil: statusFixtureNow.add(const Duration(days: 12)),
          ),
        ),
      );
      expect(find.byKey(StatusStoreScreen.activeKey), findsOneWidget);
      await _golden('status.store_held.en.light');
    });
  });

  testWidgets('store, too few coins (ar light)', (tester) async {
    await withClock(Clock.fixed(statusFixtureNow), () async {
      await pumpStatus(
        tester,
        const StatusStoreScreen(
          packId: 'premium',
          displayName: 'ليلى',
          initialPreviewId: 'premium.crown',
        ),
        brightness: Brightness.light,
        repo: FakeStatusRepository(
          list: statusPackListFixture(coins: 4200),
          buyFailure: const ServerFailure(
            code: ErrorCode.insufficientCoins,
            rawCode: 'INSUFFICIENT_COINS',
            debugMessage: 'short',
            statusCode: 409,
          ),
        ),
      );
      await tester.tap(find.byKey(StatusStoreScreen.buyKey));
      await settleStatus(tester);
      await tester.tap(find.byType(FilledButton).last);
      await settleStatus(tester);
      expect(find.byKey(StatusStoreScreen.rechargeKey), findsOneWidget);
      await _golden('status.store_short.ar.light');
    });
  });

  for (final reduced in [false, true]) {
    testWidgets('profile${reduced ? ', reduced motion' : ''}', (tester) async {
      await withClock(Clock.fixed(statusFixtureNow), () async {
        final profile = apiProfile(ar: true)
            .copyWith(liveRoomId: null, statusEmojiId: 'premium.eagle');
        await pumpStatus(
          tester,
          const PublicProfileScreen(username: 'host0'),
          brightness: reduced ? Brightness.light : Brightness.dark,
          disableAnimations: reduced,
          overrides: [
            profileRepositoryProvider.overrideWithValue(
              FakeProfileRepository(profile),
            ),
          ],
        );
        await precacheImages(tester);
        await settleStatus(tester);
        final layer = find.byKey(StatusEmojiLayer.keyOf('premium.eagle'));
        expect(layer, findsOneWidget);
        expect(
          find.descendant(of: layer, matching: find.byType(VisibilityDetector)),
          reduced ? findsNothing : findsOneWidget,
        );
        await _golden(
          reduced
              ? 'status.profile_reduced.ar.light'
              : 'status.profile.ar.dark',
        );
      });
    });
  }

  testWidgets('audio seats (ar dark)', (tester) async {
    await withClock(Clock.fixed(statusFixtureNow), () async {
      await pumpStatus(
        tester,
        Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 120),
              child: AudioSeatRing(
                count: 8,
                host: const KAvatar(name: 'ليلى', size: AudioSeatRing.picture),
                hostName: 'ليلى',
                hostStatusEmojiId: 'noto.party',
                seats: [
                  LiveSeat(
                    index: 1,
                    state: LiveSeatState.taken,
                    user: _guest(1, 'عمر', 'premium.crown'),
                  ),
                  LiveSeat(
                    index: 2,
                    state: LiveSeatState.taken,
                    user: _guest(2, 'سامي', 'kabi.love'),
                  ),
                  LiveSeat(
                    index: 3,
                    state: LiveSeatState.taken,
                    user: _guest(3, 'نور', null),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await _golden('status.seats.ar.dark');
    });
  });
}
