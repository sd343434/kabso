// D187: the daily recharge badge (`UserSummary.rechargeBadge`,
// `PublicProfile.rechargeBadge`, tier 1–5 until `until`) — the owner's art
// for the tier next to the name everywhere the level badge shows: live chat
// lines, the join line, the host pill, the viewers list, seats, the person
// card, the profile header and the Me hub card. It disappears by itself when
// `until` passes (no refresh), and an expired one never draws. Arabic RTL and
// English LTR.

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/auth_controller.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/cp/data/cp_repository.dart';
import 'package:kabso_live/features/levels/application/levels_providers.dart';
import 'package:kabso_live/features/live/application/live_wallet_controller.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/live_room_screen.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_seat_tiles.dart';
import 'package:kabso_live/features/live/presentation/go_live/seat_controls.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_chat.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_scaffold.dart';
import 'package:kabso_live/features/profile/application/profile_grid_provider.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:kabso_live/features/profile/me_hub_screen.dart';
import 'package:kabso_live/features/profile/profile_screen.dart';
import 'package:kabso_live/features/recharge/presentation/recharge_badge.dart';
import 'package:kabso_live/features/safety/safety_repository.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../helpers/fake_bonds_repositories.dart';
import '../../helpers/fake_live_media_engine.dart';
import '../../helpers/fake_live_repository.dart';
import '../../helpers/fake_profile_repository.dart';
import '../../helpers/fake_safety_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';
import '../bonds/bonds_harness.dart';

/// A badge of [tier] that ends [left] from the (test) clock's now.
RechargeBadge _badge(int tier, {Duration left = const Duration(minutes: 10)}) =>
    RechargeBadge(tier: tier, until: clock.now().toUtc().add(left));

UserSummary _user(String id, String name, {RechargeBadge? badge}) =>
    UserSummary(
      id: id,
      username: id,
      displayName: name,
      avatarUrl: null,
      rechargeBadge: badge,
    );

LiveChatEntry _entry(String id, String text, UserSummary author) =>
    LiveChatEntry(
      id: id,
      roomId: 'room-0',
      author: author,
      authorRole: LiveChatRole.viewer,
      text: text,
      createdAt: DateTime.utc(2026, 10, 30, 20),
    );

final Finder _badges = find.byKey(RechargeTierBadge.badgeKey);

/// The asset of the first badge under [of].
String _asset(WidgetTester tester, Finder of) {
  final image = tester.widget<Image>(
    find.descendant(of: of, matching: _badges).first,
  );
  return (image.image as AssetImage).assetName;
}

Future<FakeLiveMediaEngine> _room(
  WidgetTester tester, {
  AppLanguage language = AppLanguage.en,
  RechargeBadge? hostBadge,
}) async {
  final engine = FakeLiveMediaEngine()..present.add('user-0');
  setViewport(tester, GoldenViewport.android);
  await pumpScreen(
    tester,
    const LiveRoomScreen(roomId: 'room-0'),
    language: language,
    liveMediaEngine: engine,
    overrides: [
      liveRepositoryProvider.overrideWithValue(
        FakeLiveRepository(
          room: (id) {
            final room = apiRoom(id: id, ar: language == AppLanguage.ar);
            return room.copyWith(
              host: room.host.copyWith(rechargeBadge: hostBadge),
            );
          },
        ),
      ),
      profileRepositoryProvider.overrideWithValue(
        FakeProfileRepository(apiProfile(ar: language == AppLanguage.ar)),
      ),
      cpRepositoryProvider.overrideWithValue(FakeCpRepository()),
      currentUserProvider.overrideWithValue(testUser()),
    ],
  );
  await tester.pumpAndSettle();
  return engine;
}

void main() {
  group('the model', () {
    test('reads {tier, until}; anything else is no badge', () {
      expect(
        rechargeBadgeFromJson({'tier': 3, 'until': '2026-10-31T12:00:00.000Z'}),
        RechargeBadge(tier: 3, until: DateTime.utc(2026, 10, 31, 12)),
      );
      for (final bad in [
        null,
        'x',
        {'tier': 0, 'until': '2026-10-31T12:00:00.000Z'},
        {'tier': 6, 'until': '2026-10-31T12:00:00.000Z'},
        {'tier': 2, 'until': 'soon'},
        {'tier': 2},
      ]) {
        expect(rechargeBadgeFromJson(bad), isNull, reason: '$bad');
      }
      final user = UserSummary.fromJson({
        'id': 'u',
        'username': 'u',
        'displayName': 'U',
        'avatarUrl': null,
        'rechargeBadge': {'tier': 5, 'until': '2026-10-31T12:00:00.000Z'},
      });
      expect(user.rechargeBadge?.tier, 5);
      expect(user.toJson()['rechargeBadge'], {
        'tier': 5,
        'until': '2026-10-31T12:00:00.000Z',
      });
      expect(_user('a', 'A').toJson().containsKey('rechargeBadge'), isFalse);
    });
  });

  group('in the live room', () {
    for (final language in AppLanguage.values) {
      testWidgets('next to the name in chat lines, the tier art, gone when '
          'until passes (${language.name})', (tester) async {
        final engine = await _room(tester, language: language);
        engine.chat
          ..add(LiveChatReceived(_entry('m1', 'hello', _user('p', 'Lina'))))
          ..add(
            LiveChatReceived(
              _entry('m2', 'hi all', _user('b', 'Omar', badge: _badge(3))),
            ),
          );
        await tester.pumpAndSettle();
        final badged = find.byKey(LiveRoomChatLines.lineKey('m:m2'));
        final plain = find.byKey(LiveRoomChatLines.lineKey('m:m1'));
        expect(find.descendant(of: badged, matching: _badges), findsOneWidget);
        expect(_asset(tester, badged), 'assets/recharge_badges/tier_3.webp');
        expect(find.descendant(of: plain, matching: _badges), findsNothing);

        await tester.pump(const Duration(minutes: 11));
        expect(find.descendant(of: badged, matching: _badges), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('on the join line, then gone (${language.name})', (
        tester,
      ) async {
        final engine = await _room(tester, language: language);
        engine.chat.add(
          LiveChatJoined(
            _user(
              'j',
              'Huda',
              badge: _badge(5, left: const Duration(minutes: 1)),
            ),
          ),
        );
        for (var i = 0; i < 3; i++) {
          await tester.pump();
        }
        await tester.pump(const Duration(milliseconds: 500));
        expect(_badges, findsWidgets);
        expect(
          _asset(tester, find.byType(LiveRoomScreen)),
          'assets/recharge_badges/tier_5.webp',
        );
        await tester.pump(const Duration(minutes: 2));
        expect(_badges, findsNothing);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('on the host pill', (tester) async {
      await _room(tester, hostBadge: _badge(2), language: AppLanguage.ar);
      expect(
        find.descendant(of: find.byType(KHostPill), matching: _badges),
        findsOneWidget,
      );
      expect(
        _asset(tester, find.byType(KHostPill)),
        'assets/recharge_badges/tier_2.webp',
      );
    });

    testWidgets('an expired badge never draws, in the badge row either', (
      tester,
    ) async {
      final expired = RechargeBadge(
        tier: 4,
        until: clock.now().toUtc().subtract(const Duration(seconds: 1)),
      );
      final live = _badge(4);
      expect(
        LiveChatBadgeRow(
          role: null,
          badges: null,
          rechargeBadge: expired,
        ).isNotEmpty,
        isFalse,
      );
      expect(
        LiveChatBadgeRow(
          role: null,
          badges: null,
          rechargeBadge: live,
        ).isNotEmpty,
        isTrue,
      );
      await pumpScreen(
        tester,
        Scaffold(
          body: Column(
            children: [
              RechargeTierBadge(badge: expired),
              LiveChatBadgeRow(role: null, badges: null, rechargeBadge: live),
            ],
          ),
        ),
      );
      expect(_badges, findsOneWidget);
    });

    testWidgets('in the viewers list', (tester) async {
      final repo = FakeLiveRepository()
        ..viewerList = [
          LiveViewer(
            kind: LiveViewerKind.user,
            user: _user('v', 'Huda', badge: _badge(1)),
            guestNumber: null,
            joinedAt: DateTime.utc(2026, 10, 30),
          ),
          LiveViewer(
            kind: LiveViewerKind.user,
            user: _user('w', 'Omar'),
            guestNumber: null,
            joinedAt: DateTime.utc(2026, 10, 30),
          ),
        ];
      await pumpScreen(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => showLiveViewers(context, roomId: 'room-0'),
                child: const Text('open'),
              ),
            ),
          ),
        ),
        language: AppLanguage.ar,
        overrides: [liveRepositoryProvider.overrideWithValue(repo)],
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(_badges, findsOneWidget);
      expect(
        (tester.widget<Image>(_badges).image as AssetImage).assetName,
        'assets/recharge_badges/tier_1.webp',
      );
    });

    testWidgets('on a seat, after the name', (tester) async {
      await pumpScreen(
        tester,
        Scaffold(
          body: SingleChildScrollView(
            child: AudioSeatRing(
              count: 10,
              host: const KAvatar(name: 'Layla', size: AudioSeatRing.picture),
              hostName: 'Layla',
              seats: [
                LiveSeat(
                  index: 1,
                  state: LiveSeatState.taken,
                  user: _user('s', 'Lina', badge: _badge(4)),
                ),
                LiveSeat(
                  index: 2,
                  state: LiveSeatState.taken,
                  user: _user('t', 'Omar'),
                ),
              ],
              onSeat: (_) {},
            ),
          ),
        ),
        language: AppLanguage.ar,
      );
      await tester.pumpAndSettle();
      final seat = find.byKey(AudioSeatRing.seatKey(1));
      expect(find.descendant(of: seat, matching: _badges), findsOneWidget);
      expect(_asset(tester, seat), 'assets/recharge_badges/tier_4.webp');
      expect(
        find.descendant(
          of: find.byKey(AudioSeatRing.seatKey(2)),
          matching: _badges,
        ),
        findsNothing,
      );
    });

    for (final language in AppLanguage.values) {
      testWidgets('on the person card while it shows (${language.name})', (
        tester,
      ) async {
        for (final badge in [_badge(3), null]) {
          setViewport(tester, GoldenViewport.android);
          await tester.pumpWidget(const SizedBox.shrink());
          await pumpBonds(
            tester,
            Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: TextButton(
                    onPressed: () => showHostSheet(context, 'host0'),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
            language: language,
            overrides: [
              profileRepositoryProvider.overrideWithValue(
                FakeProfileRepository(
                  apiProfile(ar: language == AppLanguage.ar)
                      .copyWith(liveRoomId: null, rechargeBadge: badge),
                ),
              ),
              safetyRepositoryProvider.overrideWithValue(
                FakeSafetyRepository(),
              ),
            ],
          );
          await tester.tap(find.text('open'));
          await tester.pumpAndSettle();
          expect(
            find.byKey(const Key('room.userCard.rechargeBadge')),
            badge != null ? findsOneWidget : findsNothing,
          );
          expect(tester.takeException(), isNull);
        }
      });
    }
  });

  group('profile and Me hub', () {
    for (final language in AppLanguage.values) {
      testWidgets('beside the name in the profile header, gone when until '
          'passes (${language.name})', (tester) async {
        await pumpScreen(
          tester,
          Scaffold(
            body: ProfileHeaderView(
              displayName: language == AppLanguage.ar ? 'ليلى' : 'Layla',
              followers: 5,
              following: 3,
              rechargeBadge: _badge(5, left: const Duration(minutes: 1)),
              actions: const SizedBox(height: 40),
            ),
          ),
          language: language,
        );
        await tester.pump();
        expect(find.byKey(ProfileHeaderView.rechargeBadgeKey), findsOneWidget);
        // Beside the name: same row, on the reading side after it.
        final name = tester.getRect(
          find.byKey(const Key('profile.displayName')),
        );
        final badge = tester.getRect(_badges);
        expect((badge.center.dy - name.center.dy).abs(), lessThan(16));
        if (language == AppLanguage.ar) {
          expect(badge.right, lessThanOrEqualTo(name.left));
        } else {
          expect(badge.left, greaterThanOrEqualTo(name.right));
        }
        await tester.pump(const Duration(minutes: 2));
        expect(_badges, findsNothing);
      });
    }

    testWidgets('beside the name on the Me hub card', (tester) async {
      setViewport(tester, GoldenViewport.phone);
      await pumpScreen(
        tester,
        const MeHubScreen(),
        language: AppLanguage.ar,
        overrides: [
          currentUserProvider.overrideWithValue(testUser()),
          meProvider.overrideWith((ref) => testUser()),
          profileStatsProvider.overrideWith(
            (ref, _) =>
                apiProfile(isSelf: true).copyWith(rechargeBadge: _badge(2)),
          ),
          profileLevelsProvider.overrideWith((ref, _) => const []),
          liveCoinsProvider.overrideWith(_Coins.new),
        ],
      );
      await tester.pumpAndSettle();
      expect(find.byKey(MeHubScreen.rechargeBadgeKey), findsOneWidget);
      expect(
        _asset(tester, find.byType(MeHubScreen)),
        'assets/recharge_badges/tier_2.webp',
      );
    });
  });
}

class _Coins extends LiveCoinsController {
  @override
  Future<int> build() async => 0;
}
