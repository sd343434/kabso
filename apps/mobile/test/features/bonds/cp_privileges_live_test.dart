// CP-021 (D112, CONVENTIONS §10.24): three CP privileges outside the CP
// space — the Special Frame on the profile header and the live person card
// (only with `SPECIAL_FRAME` in `PublicProfile.cp.privileges`), the
// Exclusive Chat Bubble (only on `LiveChatMessage.cpBubble`) and the
// Entrance Effect (only on a `join` with `cp`; queued; reduced motion).
// Arabic and English, 360×800.

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/cp/data/cp_repository.dart';
import 'package:kabso_live/features/cp/domain/cp_models.dart';
import 'package:kabso_live/features/cp/presentation/cp_special_frame.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/live/live_room_screen.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_cp_entrance.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_chat.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:kabso_live/features/profile/domain/profile_models.dart';
import 'package:kabso_live/features/profile/profile_screen.dart';
import 'package:kabso_live/features/profile/public_profile_screen.dart';
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
import 'bonds_harness.dart';

const _omar = UserSummary(
  id: 'u-omar',
  username: 'omar',
  displayName: 'Omar',
  avatarUrl: null,
);
const _lina = UserSummary(
  id: 'u-lina',
  username: 'lina',
  displayName: 'Lina',
  avatarUrl: null,
);
const _huda = UserSummary(
  id: 'u-huda',
  username: 'huda',
  displayName: 'Huda',
  avatarUrl: null,
);

/// The host's profile (not live, so the header shows the plain picture),
/// with a couple that unlocked [privileges] (no couple when null).
PublicProfile _profile({List<String>? privileges, bool ar = false}) =>
    apiProfile(ar: ar).copyWith(
      liveRoomId: null,
      cp: privileges == null
          ? null
          : ProfileCp(
              id: 'cp-1',
              partner: _omar,
              since: DateTime.utc(2026, 10, 2),
              level: 4,
              levelName: 'Diamond couple',
              points: 6000,
              privileges: privileges,
            ),
    );

LiveChatEntry _entry(
  String id,
  String text, {
  UserSummary author = _huda,
  bool cpBubble = false,
}) => LiveChatEntry(
  id: id,
  roomId: 'room-0',
  author: author,
  authorRole: LiveChatRole.viewer,
  text: text,
  createdAt: DateTime.utc(2026, 10, 26, 20),
  cpBubble: cpBubble,
);

LiveJoinCp _cp(UserSummary partner, {int level = 4}) =>
    LiveJoinCp(coupleId: 'cp-${partner.id}', partner: partner, level: level);

/// The live room (solo) with an in-memory media session.
Future<FakeLiveMediaEngine> _room(
  WidgetTester tester, {
  AppLanguage language = AppLanguage.en,
  bool reduceMotion = false,
}) async {
  final engine = FakeLiveMediaEngine()..present.add('user-0');
  setViewport(tester, GoldenViewport.android);
  if (reduceMotion) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }
  await pumpScreen(
    tester,
    const LiveRoomScreen(roomId: 'room-0'),
    language: language,
    liveMediaEngine: engine,
    overrides: [
      liveRepositoryProvider.overrideWithValue(
        FakeLiveRepository(room: (id) => apiRoom(id: id)),
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

/// A few frames: the data message, the chat line, the banner.
Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.pump();
  }
}

void main() {
  final en = l10nFor(AppLanguage.en);
  final ar = l10nFor(AppLanguage.ar);

  setUp(() => LiveCpEntranceLayer.animate = true);

  group('parsing (contract v1.24-live)', () {
    test('LiveChatMessage.cpBubble: read, false when missing', () {
      final json = {
        'id': 'm1',
        'roomId': 'room-0',
        'author': {
          'id': 'u-1',
          'username': 'a',
          'displayName': 'A',
          'avatarUrl': null,
        },
        'authorRole': 'VIEWER',
        'kind': 'TEXT',
        'text': 'hi',
        'media': null,
        'expiresAt': null,
        'createdAt': '2026-10-26T18:30:00.000Z',
      };
      expect(LiveChatEntry.fromJson(json).cpBubble, isFalse);
      expect(
        LiveChatEntry.fromJson({...json, 'cpBubble': true}).cpBubble,
        true,
      );
    });

    test('join: cp read; null, missing or malformed cp is a normal join', () {
      final user = {
        'id': 'u-1',
        'username': 'a',
        'displayName': 'A',
        'avatarUrl': null,
      };
      final withCp =
          LiveChatEvent.parse({
                'type': 'join',
                'user': user,
                'cp': {
                  'coupleId': 'c-1',
                  'partner': {...user, 'id': 'u-2', 'username': 'b'},
                  'level': 4,
                },
              })!
              as LiveChatJoined;
      expect(withCp.cp?.coupleId, 'c-1');
      expect(withCp.cp?.partner.username, 'b');
      expect(withCp.cp?.level, 4);
      for (final cp in [
        null,
        'x',
        <String, Object?>{'level': 4},
      ]) {
        final join =
            LiveChatEvent.parse({'type': 'join', 'user': user, 'cp': cp})!
                as LiveChatJoined;
        expect(join.cp, isNull);
      }
      final old =
          LiveChatEvent.parse({'type': 'join', 'user': user})!
              as LiveChatJoined;
      expect(old.cp, isNull);
    });
  });

  group('Special Frame', () {
    for (final language in AppLanguage.values) {
      testWidgets('profile header: only with SPECIAL_FRAME '
          '(${language.name}, 360×800)', (tester) async {
        final arabic = language == AppLanguage.ar;
        for (final (privileges, framed) in [
          (['SPECIAL_FRAME', 'CHAT_BUBBLE'], true),
          (<String>[], false),
          (null, false),
        ]) {
          setViewport(tester, GoldenViewport.android);
          await tester.pumpWidget(const SizedBox.shrink());
          await pumpBonds(
            tester,
            const PublicProfileScreen(username: 'host0'),
            language: language,
            overrides: [
              profileRepositoryProvider.overrideWithValue(
                FakeProfileRepository(
                  _profile(privileges: privileges, ar: arabic),
                ),
              ),
              safetyRepositoryProvider.overrideWithValue(
                FakeSafetyRepository(),
              ),
            ],
          );
          await tester.pumpAndSettle();
          expect(
            find.byKey(ProfileHeaderView.cpFrameKey),
            framed ? findsOneWidget : findsNothing,
            reason: '$privileges',
          );
          expect(tester.takeException(), isNull);
          if (!framed) continue;
          // The picture keeps its size inside the heart; the frame sits at
          // the reading start, inside the page.
          final box = tester.getRect(find.byKey(ProfileHeaderView.cpFrameKey));
          expect(box.left, greaterThanOrEqualTo(0));
          expect(box.right, lessThanOrEqualTo(360));
          expect(
            arabic ? box.right > 180 : box.left < 180,
            isTrue,
            reason: 'reading start',
          );
        }
      });
    }

    testWidgets('profile header: the live ring wins while live', (
      tester,
    ) async {
      setViewport(tester, GoldenViewport.android);
      await pumpBonds(
        tester,
        const PublicProfileScreen(username: 'host0'),
        overrides: [
          profileRepositoryProvider.overrideWithValue(
            FakeProfileRepository(
              _profile(privileges: ['SPECIAL_FRAME'])
                  .copyWith(liveRoomId: 'room-0'),
            ),
          ),
          safetyRepositoryProvider.overrideWithValue(FakeSafetyRepository()),
        ],
      );
      await tester.pumpAndSettle();
      expect(find.byKey(ProfileHeaderView.cpFrameKey), findsNothing);
    });

    for (final language in AppLanguage.values) {
      testWidgets('person card: only with SPECIAL_FRAME (${language.name})', (
        tester,
      ) async {
        for (final (privileges, framed) in [
          (['SPECIAL_FRAME'], true),
          (<String>[], false),
        ]) {
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
                  _profile(
                    privileges: privileges,
                    ar: language == AppLanguage.ar,
                  ),
                ),
              ),
              safetyRepositoryProvider.overrideWithValue(
                FakeSafetyRepository(),
              ),
            ],
          );
          await tester.tap(find.text('open'));
          await tester.pumpAndSettle();
          final frame = find.byKey(const Key('room.userCard.cpFrame'));
          expect(frame, framed ? findsOneWidget : findsNothing);
          expect(tester.takeException(), isNull);
          if (!framed) continue;
          expect(find.byType(CpSpecialFrameAvatar), findsOneWidget);
          // The frame is inside the screen and above the name.
          final rect = tester.getRect(frame);
          expect(rect.top, greaterThanOrEqualTo(0));
          final name = tester.getRect(
            find.text(language == AppLanguage.ar ? 'سارة' : 'Sara').last,
          );
          expect(name.top, greaterThanOrEqualTo(rect.bottom - 2));
          // The picture still opens the profile.
          expect(
            find.ancestor(
              of: frame,
              matching: find.byKey(const Key('room.userCard.profile')),
            ),
            findsOneWidget,
          );
        }
      });
    }
  });

  group('Exclusive Chat Bubble', () {
    for (final language in AppLanguage.values) {
      testWidgets('only cpBubble lines are pink, same height '
          '(${language.name})', (tester) async {
        final engine = await _room(tester, language: language);
        engine.chat
          ..add(LiveChatReceived(_entry('m1', 'hello')))
          ..add(LiveChatReceived(_entry('m2', 'hello', cpBubble: true)));
        await tester.pumpAndSettle();
        final cp = find.byKey(LiveCpChatBubble.bubbleKey);
        expect(cp, findsOneWidget);
        expect(find.byKey(LiveRoomChatLines.cpHeartKey), findsOneWidget);
        expect(
          find.descendant(
            of: cp,
            matching: find.textContaining('hello', findRichText: true),
          ),
          findsOneWidget,
        );
        // Same layout metrics: both lines have the same height.
        final plain = tester.getSize(
          find.byKey(LiveRoomChatLines.lineKey('m:m1')),
        );
        final pink = tester.getSize(
          find.byKey(LiveRoomChatLines.lineKey('m:m2')),
        );
        expect(pink.height, plain.height);
        // The heart is at the reading start of the line.
        final heart = tester.getCenter(
          find.byKey(LiveRoomChatLines.cpHeartKey),
        );
        final line = tester.getRect(cp);
        expect(
          language == AppLanguage.ar
              ? heart.dx > line.center.dx
              : heart.dx < line.center.dx,
          isTrue,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Entrance Effect', () {
    testWidgets('a normal join shows no banner; a cp join does, then leaves', (
      tester,
    ) async {
      final engine = await _room(tester);
      engine.chat.add(const LiveChatJoined(_lina));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(LiveCpEntranceLayer.bannerKey), findsNothing);
      // The chat line is unchanged.
      expect(
        find.textContaining(
          en.chatJoined(KFormat.bidiIsolate('Lina')),
          findRichText: true,
        ),
        findsOneWidget,
      );

      engine.chat.add(LiveChatJoined(_lina, cp: _cp(_omar)));
      await _frames(tester);
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.byKey(LiveCpEntranceLayer.bannerKey), findsOneWidget);
      expect(
        find.text(
          en.liveCpEntranceCouple(
            KFormat.bidiIsolate('Lina'),
            KFormat.bidiIsolate('Omar'),
          ),
        ),
        findsOneWidget,
      );
      // The level's name from the CP tiers.
      expect(
        find.text(en.liveCpEntranceLevel('Diamond couple')),
        findsOneWidget,
      );
      // Never takes taps.
      expect(
        find.ancestor(
          of: find.byKey(LiveCpEntranceLayer.bannerKey),
          matching: find.byType(IgnorePointer),
        ),
        findsWidgets,
      );
      await tester.pump(LiveCpEntranceLayer.duration);
      await tester.pump();
      expect(find.byKey(LiveCpEntranceLayer.bannerKey), findsNothing);
    });

    testWidgets('several entrances queue, one after another', (tester) async {
      final engine = await _room(tester);
      engine.chat
        ..add(LiveChatJoined(_lina, cp: _cp(_omar)))
        ..add(LiveChatJoined(_huda, cp: _cp(_lina, level: 5)));
      await _frames(tester);
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.byKey(LiveCpEntranceLayer.bannerKey), findsOneWidget);
      expect(find.textContaining('Lina'), findsWidgets);
      expect(
        find.text(en.liveCpEntranceLevel('Diamond couple')),
        findsOneWidget,
      );
      await tester.pump(LiveCpEntranceLayer.duration);
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.byKey(LiveCpEntranceLayer.bannerKey), findsOneWidget);
      expect(
        find.text(en.liveCpEntranceLevel('Legendary couple')),
        findsOneWidget,
      );
      await tester.pump(LiveCpEntranceLayer.duration);
      await tester.pump();
      expect(find.byKey(LiveCpEntranceLayer.bannerKey), findsNothing);
    });

    testWidgets('reduced motion: still and shorter', (tester) async {
      final engine = await _room(tester, reduceMotion: true);
      engine.chat.add(LiveChatJoined(_lina, cp: _cp(_omar)));
      await _frames(tester);
      // At once, in place (no slide).
      expect(find.byKey(LiveCpEntranceLayer.bannerKey), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(LiveCpEntranceLayer),
          matching: find.byType(FractionalTranslation),
        ),
        findsNothing,
      );
      await tester.pump(LiveCpEntranceLayer.stillDuration);
      await tester.pump();
      expect(find.byKey(LiveCpEntranceLayer.bannerKey), findsNothing);
    });

    testWidgets('Arabic: the banner reads right to left, inside 360 wide', (
      tester,
    ) async {
      LiveCpEntranceLayer.animate = false;
      final engine = await _room(tester, language: AppLanguage.ar);
      engine.chat.add(LiveChatJoined(_lina, cp: _cp(_omar, level: 9)));
      await _frames(tester);
      final banner = find.byKey(LiveCpEntranceLayer.bannerKey);
      expect(banner, findsOneWidget);
      expect(
        find.text(
          ar.liveCpEntranceCouple(
            KFormat.bidiIsolate('Lina'),
            KFormat.bidiIsolate('Omar'),
          ),
        ),
        findsOneWidget,
      );
      // An unknown level: "Lv.N".
      expect(
        find.text(ar.liveCpEntranceLevel(ar.cpSpaceLevel(9))),
        findsOneWidget,
      );
      final rect = tester.getRect(banner);
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(360));
      // The art at the reading start (right in Arabic).
      final art = tester.getCenter(
        find.descendant(of: banner, matching: find.byType(Image)).last,
      );
      expect(art.dx, greaterThan(rect.center.dx));
      expect(tester.takeException(), isNull);
      await tester.pump(LiveCpEntranceLayer.stillDuration);
      await tester.pump();
    });
  });
}
