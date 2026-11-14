// D257 (owner: «اجعل شاشة المشاهد في تطبيقنا مثل التصميم ١٠٠٪»): the
// viewer's video live as the owner's Bigo reference (393 × 852 pt) — the
// name alone on the pill, the faces with the count pill, the chips row with
// the host's ID, the host's daily rank card, the boxed chat lines and the
// bar: «قل مرحباً…» (210 × 35 pt), ≡, recharge, the box, the gift; the quick
// replies and ∞ in ≡.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/data/live_gift_repository.dart';
import 'package:kabso_live/features/live/data/live_host_targets_repository.dart';
import 'package:kabso_live/features/live/data/live_media_engine.dart';
import 'package:kabso_live/features/live/data/live_rankings_repository.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/live_room_screen.dart';
import 'package:kabso_live/features/live/presentation/go_live/go_live_parts.dart';
import 'package:kabso_live/features/live/presentation/go_live/viewer_live_ref_parts.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_host_target_chip.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_chat.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_scaffold.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_viewer_parts.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../fixtures/live/live_gift_fixtures.dart';
import '../../helpers/fake_live_gift_repository.dart';
import '../../helpers/fake_live_host_targets_repository.dart';
import '../../helpers/fake_live_media_engine.dart';
import '../../helpers/fake_live_pk.dart';
import '../../helpers/fake_live_rankings_repository.dart';
import '../../helpers/fake_live_repository.dart';
import '../../helpers/fake_profile_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

final _now = DateTime(2026, 11, 3, 12, 16);

LiveRankingEntry _entry(int rank, String id, int points) => LiveRankingEntry(
  rank: rank,
  host: UserSummary(id: id, username: id, displayName: id, avatarUrl: null),
  points: points,
);

const _target = LiveHostTargets(
  day: '2026-11-03',
  band: 1,
  gifts: HostTarget(received: 162, target: 200, reached: false),
  lucky: HostTarget(received: 0, target: 0, reached: false),
  topSupporters: [],
);

Future<FakeLiveMediaEngine> _pump(
  WidgetTester tester, {
  AppLanguage language = AppLanguage.en,
  List<LiveRankingEntry>? board,
}) async {
  final ar = language == AppLanguage.ar;
  tester.view.padding = const FakeViewPadding(
    top: 59 * GoldenViewport.pixelRatio,
    bottom: 34 * GoldenViewport.pixelRatio,
  );
  addTearDown(tester.view.resetPadding);
  HostDailyRankCard.now = () => _now;
  addTearDown(() => HostDailyRankCard.now = DateTime.now);
  final room = apiRoom(ar: ar);
  final prefs = await testPrefs(language: language.name);
  late FakeLiveMediaEngine engine;
  await pumpGolden(
    tester,
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        liveRepositoryProvider.overrideWithValue(
          FakeLiveRepository(
            room: (id) => apiRoom(id: id, ar: ar),
          ),
        ),
        profileRepositoryProvider.overrideWithValue(
          FakeProfileRepository(apiProfile(ar: ar)),
        ),
        liveGiftRepositoryProvider.overrideWithValue(
          FakeLiveGiftRepository(codes: giftFixtureCodes),
        ),
        liveHostTargetsRepositoryProvider.overrideWithValue(
          FakeLiveHostTargetsRepository(byHost: {room.host.username: _target}),
        ),
        liveRankingsRepositoryProvider.overrideWithValue(
          FakeLiveRankingsRepository({
            LiveRankingPeriod.day: LiveRankings(
              period: LiveRankingPeriod.day,
              startsAt: DateTime(2026, 11, 3),
              endsAt: DateTime(2026, 11, 4),
              entries:
                  board ??
                  [_entry(1, 'top', 9000), _entry(2, room.host.id, 5400)],
            ),
          }),
        ),
        ...pkTestOverrides(),
        liveMediaEngineProvider.overrideWithValue(
          () => engine = FakeLiveMediaEngine()..present.add('user-0'),
        ),
        currentUserProvider.overrideWithValue(testUser()),
      ],
      child: const LiveRoomScreen(roomId: 'room-0'),
    ),
    language: language,
    bare: true,
  );
  await tester.pumpAndSettle();
  await precacheImages(tester);
  return engine;
}

void main() {
  test("D257 the host on today's board: rank, points, gap above", () {
    final board = LiveRankings(
      period: LiveRankingPeriod.day,
      startsAt: _now,
      endsAt: _now,
      entries: [_entry(1, 'a', 900), _entry(2, 'h', 500)],
    );
    expect(HostDailyRankCard.standingOf(board, 'h'), (
      rank: 2,
      points: 500,
      gap: 400,
    ));
    expect(HostDailyRankCard.standingOf(board, 'a').gap, isNull);
    expect(HostDailyRankCard.standingOf(board, 'x'), (
      rank: null,
      points: 0,
      gap: null,
    ));
  });

  testWidgets('D257 the viewer screen follows the reference', (tester) async {
    await _pump(tester);
    // No @username on the pill, no minimize at the top.
    expect(find.byKey(LiveRoomScreen.minimizeKey), findsNothing);
    // The second row: the chips with their glass and the host's ID.
    expect(find.byKey(KRoomChipsRow.idKey), findsOneWidget);
    expect(find.byKey(LiveHostTargetChip.chipKey), findsOneWidget);
    // The daily rank card at the top end: 2nd today, 3.6K below the first.
    expect(find.byKey(HostDailyRankCard.cardKey), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(HostDailyRankCard.rankKey)).data,
      '2',
    );
    final card = tester.getRect(find.byKey(HostDailyRankCard.cardKey));
    expect(
      card.right,
      moreOrLessEquals(393 - KLiveRoomScaffold.sideEndInset, epsilon: 0.1),
    );
    // The chat: the reference's boxed rows.
    expect(find.byKey(LiveRoomChatLines.noticeKey), findsOneWidget);
    // The bar: the 210 pt pill, ≡, recharge, the box, the gift; no quick
    // replies and no ∞ on it.
    expect(
      tester.getSize(find.byKey(AudioRoomViewKeys.chat)).width,
      moreOrLessEquals(210, epsilon: 0.5),
    );
    for (final key in [
      LiveRoomScreen.menuKey,
      LiveRoomScreen.rechargeKey,
      LiveRoomScreen.gamesKey,
      LiveRoomScreen.giftKey,
    ]) {
      expect(find.byKey(key), findsOneWidget);
    }
    expect(find.byKey(LiveRoomScreen.guestKey), findsNothing);
    expect(find.byType(KQuickReplies), findsNothing);
    // ≡ holds the quick replies, ∞ and minimize.
    await tester.tap(find.byKey(LiveRoomScreen.menuKey));
    await tester.pumpAndSettle();
    for (final id in ['quickReplies', 'guest', 'minimize']) {
      expect(find.byKey(GoLiveKeys.tool(id)), findsOneWidget, reason: id);
    }
  });

  testWidgets("D257 a host off today's board reads 99+; «–» hides it", (
    tester,
  ) async {
    await _pump(tester, board: [_entry(1, 'top', 9000)]);
    expect(
      tester.widget<Text>(find.byKey(HostDailyRankCard.rankKey)).data,
      '99+',
    );
    await tester.tap(find.byKey(HostDailyRankCard.hideKey));
    await tester.pump();
    expect(find.byKey(HostDailyRankCard.cardKey), findsNothing);
  });

  forEachLanguage((language) {
    testWidgets('D257 viewer live as the reference ($language)', (
      tester,
    ) async {
      await _pump(tester, language: language);
      await expectScreenGolden('live_room.viewer_ref', language: language);
    });
  });
}
