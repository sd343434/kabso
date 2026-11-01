// D220 (owner 2026-11-01): the person card over a real live room — the
// real `LiveRoomScreen` (an audio room with its theme and seats) against
// fake repositories shaped like contract v1.77-social, the host's card opened
// from the host pill. The live stays visible above the compact sheet.
//
//   room.person_card            light, no frame (the white ring), 4 numbers
//   room.person_card.frame      the worn bag frame (active-host pink)
//   room.person_card.dark       the app's dark theme
//   room.person_card.three      cherries hidden by the person: 3 numbers
//
// Regenerate on Linux with the pinned Flutter:
//   flutter test --update-goldens test/goldens/live_person_card_golden_test.dart
@Tags(['golden'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/levels/application/levels_providers.dart';
import 'package:kabso_live/features/levels/domain/level_models.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/live_room_screen.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_seat_tiles.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:kabso_live/features/profile/domain/profile_models.dart';
import 'package:material_ui/material_ui.dart';

import '../fixtures/live/live_api_fixtures.dart';
import '../helpers/fake_live_media_engine.dart';
import '../helpers/fake_live_repository.dart';
import '../helpers/fake_profile_repository.dart';
import '../helpers/fakes.dart';
import '../helpers/golden.dart';
import '../helpers/pump_app.dart';

/// The person shown on the card (test data, labelled as such).
PublicProfile personCardProfile({
  required bool ar,
  AvatarFrame? frame,
  bool hideCherries = false,
}) => apiProfile(ar: ar, followerCount: 1510000).copyWith(
  followingCount: 59400,
  cherriesReceived: hideCherries ? null : 5830000,
  coinsSent: 33200,
  avatarFrame: frame,
);

List<PublicLevel> personCardLevels({required bool ar}) => [
  PublicLevel(
    category: LevelCategory.attractiveness,
    name: ar ? 'الجاذبية' : 'Charm',
    level: LevelBrief(levelNumber: 32, name: 'x', requiredPoints: BigInt.zero),
  ),
  PublicLevel(
    category: LevelCategory.support,
    name: ar ? 'الدعم' : 'Support',
    level: LevelBrief(levelNumber: 12, name: 'x', requiredPoints: BigInt.zero),
  ),
];

/// Pumps the real audio room with [profile] as its host and opens the
/// host's card from the host pill.
Future<void> pumpPersonCardRoom(
  WidgetTester tester, {
  required AppLanguage language,
  required PublicProfile profile,
  GoldenViewport viewport = GoldenViewport.phone,
  Brightness brightness = Brightness.light,
}) async {
  final ar = language == AppLanguage.ar;
  await loadAppFonts();
  setViewport(tester, viewport);
  if (viewport == GoldenViewport.phone) {
    tester.view.padding = const FakeViewPadding(
      top: 59 * GoldenViewport.pixelRatio,
      bottom: 34 * GoldenViewport.pixelRatio,
    );
    addTearDown(tester.view.resetPadding);
  }
  final repo =
      FakeLiveRepository(
          room: (id) => apiRoom(
            id: id,
            ar: ar,
          ).copyWith(mode: LiveRoomMode.audio, seatCount: 10),
        )
        ..seatState = LiveSeats(
          roomId: 'room-0',
          mode: LiveRoomMode.audio,
          version: 1,
          seatCount: 10,
          seats: [
            LiveSeat(
              index: 1,
              state: LiveSeatState.taken,
              user: UserSummary(
                id: profile.id,
                username: profile.username,
                displayName: profile.displayName,
                avatarUrl: null,
              ),
            ),
            for (var i = 2; i < 10; i++)
              LiveSeat(index: i, state: LiveSeatState.empty, user: null),
          ],
          moderators: const [],
          mine: const LiveSeatsMine(
            role: LiveSeatRole.viewer,
            seatIndex: null,
            request: null,
            invite: null,
          ),
        );
  await pumpScreen(
    tester,
    const LiveRoomScreen(roomId: 'room-0'),
    language: language,
    brightness: brightness,
    disableAnimations: true,
    liveMediaEngine: FakeLiveMediaEngine()..present.add('user-0'),
    overrides: [
      liveRepositoryProvider.overrideWithValue(repo),
      profileRepositoryProvider.overrideWithValue(
        FakeProfileRepository(profile),
      ),
      currentUserProvider.overrideWithValue(testUser()),
      profileLevelsProvider.overrideWith(
        (ref, _) async => personCardLevels(ar: ar),
      ),
    ],
  );
  await tester.pumpAndSettle();
  // The person sits on seat 1; a tap opens their card.
  await tester.tap(find.byKey(AudioSeatRing.seatKey(1)));
  await tester.pumpAndSettle();
  await precacheImages(tester);
  await tester.pumpAndSettle();
}

void main() {
  Future<void> golden(
    WidgetTester tester,
    String name, {
    required AppLanguage language,
    GoldenViewport viewport = GoldenViewport.phone,
    Brightness brightness = Brightness.light,
    AvatarFrame? frame,
    bool hideCherries = false,
  }) async {
    final ar = language == AppLanguage.ar;
    await pumpPersonCardRoom(
      tester,
      language: language,
      viewport: viewport,
      brightness: brightness,
      profile: personCardProfile(
        ar: ar,
        frame: frame,
        hideCherries: hideCherries,
      ),
    );
    expect(find.byKey(const Key('room.hostSheet')), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('png/$name.${language.name}.${viewport.name}.png'),
    );
  }

  const pink = AvatarFrame(
    code: 'host_frame_pink',
    assetKey: 'host_frame_pink',
  );

  forEachLanguage((language) {
    testWidgets('room.person_card ${language.name}', (tester) async {
      await golden(tester, 'room.person_card', language: language);
    });
  });
  testWidgets('room.person_card.frame ar', (tester) async {
    await golden(
      tester,
      'room.person_card.frame',
      language: AppLanguage.ar,
      frame: pink,
    );
  });
  testWidgets('room.person_card.dark en', (tester) async {
    await golden(
      tester,
      'room.person_card.dark',
      language: AppLanguage.en,
      brightness: Brightness.dark,
      frame: pink,
    );
  });
  testWidgets('room.person_card.three ar android', (tester) async {
    await golden(
      tester,
      'room.person_card.three',
      language: AppLanguage.ar,
      viewport: GoldenViewport.android,
      hideCherries: true,
    );
  });
}
