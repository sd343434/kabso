// D189 (v1.58-social, CONVENTIONS §10.52): a host agent «وكيل مضيفين»
// (`hostAgent.code`) gets the perks a recharge agent has — the badge beside
// the name (profile, person card) and inline next to the name in the live
// room, the blue entrance bar «دخل وكيل المضيفين Salma» (the display name; the
// recharge bar's size, place and timing), and the host-agent frame (photo in
// the measured circle, no name). With both roles: both badges, the
// recharge-agent frame and bar win (owner proposals D189 c/d). Arabic and
// English.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/models/special_username.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/agency/data/agency_repository.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/bag/presentation/avatar_frame_art.dart';
import 'package:kabso_live/features/cp/data/cp_repository.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/live/live_room_screen.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_chat.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:kabso_live/features/profile/domain/profile_models.dart';
import 'package:kabso_live/features/profile/profile_screen.dart';
import 'package:kabso_live/features/recharge/presentation/live_recharge_entrance.dart';
import 'package:kabso_live/features/recharge/presentation/recharge_perks.dart';
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

const _hostAgent = UserSummary(
  id: 'u-hagent',
  username: 'host03',
  displayName: 'Salma',
  avatarUrl: null,
  hostAgentCode: 'host03',
);
const _both = UserSummary(
  id: 'u-both',
  username: 'coin0007',
  displayName: 'Nour',
  avatarUrl: null,
  rechargeAgentCode: 'coin0007',
  hostAgentCode: 'host04',
);
const _plain = UserSummary(
  id: 'u-lina',
  username: 'lina',
  displayName: 'Lina',
  avatarUrl: null,
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

Future<FakeLiveMediaEngine> _room(
  WidgetTester tester, {
  AppLanguage language = AppLanguage.en,
  GoldenViewport viewport = GoldenViewport.android,
}) async {
  final engine = FakeLiveMediaEngine()..present.add('user-0');
  setViewport(tester, viewport);
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

Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.pump();
  }
}

void main() {
  setUp(() => LiveRechargeEntranceLayer.animate = true);

  group('wire', () {
    const base = {
      'id': 'u-1',
      'username': 'host01',
      'displayName': 'A',
      'avatarUrl': null,
    };

    test(
      'hostAgent on UserSummary is the code; absent or malformed → null',
      () {
        expect(
          UserSummary.fromJson({
            ...base,
            'hostAgent': {'code': 'host01'},
          }).hostAgentCode,
          'host01',
        );
        expect(UserSummary.fromJson(base).hostAgentCode, isNull);
        expect(
          UserSummary.fromJson({...base, 'hostAgent': 'x'}).hostAgentCode,
          isNull,
        );
        expect(
          UserSummary.fromJson(base).toJson().containsKey('hostAgent'),
          isFalse,
        );
      },
    );

    test('PublicProfile.hostAgent, the HOST_AGENT source and the dashboard '
        'part', () {
      final json =
          jsonDecode(jsonEncode(apiProfile().toJson())) as Map<String, dynamic>
            ..['hostAgent'] = {'code': 'host12'};
      expect(PublicProfile.fromJson(json).hostAgentCode, 'host12');
      expect(
        PublicProfile.fromJson(json..['hostAgent'] = null).hostAgentCode,
        isNull,
      );
      expect(
        SpecialUsernameSource.fromWire('HOST_AGENT'),
        SpecialUsernameSource.hostAgent,
      );
      Map<String, dynamic> own(Object? hostAgent) => {
        'inviteCode': 'KAB5Q7XZ',
        'rank': 'LAPSED',
        'month': '2026-10',
        'commissionRateBps': 1500,
        'progress': <String, dynamic>{},
        'commission': {'thisMonth': 0, 'lastMonth': 0, 'total': 0},
        'parentCommission': {'thisMonth': 0, 'lastMonth': 0, 'total': 0},
        'subAgencies': <Object>[],
        'parent': null,
        'hostAgent': hostAgent,
      };
      final a = OwnAgency.fromJson(
        own({'code': 'host07', 'active': true, 'usernameShown': false}),
      );
      expect(a.hostAgentCode, 'host07');
      expect(a.hostAgentActive, isTrue);
      expect(a.hostAgentUsernameShown, isFalse);
      // An older server: no host-agent part.
      expect(OwnAgency.fromJson(own(null)).hostAgentCode, isNull);
    });

    test('frame precedence (D189 d): recharge > host > none', () {
      expect(
        agentFrameKindFor(rechargeCode: 'coin0007', hostCode: 'host04'),
        AgentFrameKind.recharge,
      );
      expect(agentFrameKindFor(hostCode: 'host04'), AgentFrameKind.host);
      expect(agentFrameKindFor(), isNull);
    });
  });

  group('perks', () {
    for (final language in AppLanguage.values) {
      final l10n = l10nFor(language);
      testWidgets('the frame (no name), the badge and the blue entrance bar '
          'with the display name (${language.name})', (tester) async {
        await pumpScreen(
          tester,
          const Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  HostAgentFrame(width: 200, name: 'Salma'),
                  SizedBox(
                    width: 360,
                    child: RechargeEntranceBar(
                      name: 'Salma',
                      style: AgentEntranceStyle.host,
                    ),
                  ),
                  HostAgentBadge(code: 'host03', height: 22),
                ],
              ),
            ),
          ),
          language: language,
        );
        // No name written: the art has no plate (the only text is the
        // photo's initial when there is no picture).
        final frameTexts = find.descendant(
          of: find.byKey(HostAgentFrame.frameKey),
          matching: find.byType(Text),
        );
        final photoTexts = find.descendant(
          of: find.byType(KAvatar),
          matching: find.byType(Text),
        );
        expect(frameTexts.evaluate().length, photoTexts.evaluate().length);
        expect(
          find.descendant(
            of: find.byKey(HostAgentFrame.frameKey),
            matching: find.textContaining('Salma'),
          ),
          findsNothing,
        );
        final frame = tester.getRect(find.byKey(HostAgentFrame.frameKey));
        expect(frame.width, 200);
        expect(frame.height, 200);
        // The photo sits in the measured circle (centre 0.4995 / 0.4815,
        // radius 0.2645, drawn 4 % larger).
        final photo = tester.getRect(
          find.descendant(
            of: find.byKey(HostAgentFrame.frameKey),
            matching: find.byType(KAvatar),
          ),
        );
        expect(photo.center.dx, closeTo(frame.left + 200 * 0.4995, 0.5));
        expect(photo.center.dy, closeTo(frame.top + 200 * 0.4815, 0.5));
        expect(photo.width, closeTo(200 * 2 * 0.2645 * 1.04, 0.5));
        expect(
          find.bySemanticsLabel(
            l10n.hostAgentFrameLabel(KFormat.bidiIsolate('Salma')),
          ),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel(
            l10n.hostAgentEntranceJoined(KFormat.bidiIsolate('Salma')),
          ),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel(
            l10n.hostAgentBadgeLabel(KFormat.bidiIsolate('host03')),
          ),
          findsOneWidget,
        );
        // The art is the host agent's.
        final art = tester
            .widgetList<Image>(find.byType(Image))
            .map((i) => (i.image as AssetImage).assetName)
            .toSet();
        expect(
          art,
          containsAll([
            HostAgentArt.frame,
            HostAgentArt.badge,
            HostAgentArt.entrance,
          ]),
        );
        expect(tester.takeException(), isNull);
      });
    }

    test('the owner text: the display name', () {
      expect(
        l10nFor(AppLanguage.ar).hostAgentEntranceJoined('سارة'),
        'دخل وكيل المضيفين سارة',
      );
      expect(
        l10nFor(AppLanguage.en).hostAgentEntranceJoined('Sara'),
        'Host agent Sara joined',
      );
      expect(
        l10nFor(AppLanguage.ar).rechargeEntranceJoined('سارة'),
        'دخل وكيل الشحن سارة',
      );
      expect(
        l10nFor(AppLanguage.en).rechargeEntranceJoined('Sara'),
        'Top-up agent Sara joined',
      );
    });
  });

  group('live room', () {
    for (final language in AppLanguage.values) {
      final l10n = l10nFor(language);
      testWidgets('a host agent join plays the host bar with the display '
          "name, the recharge bar's size and place (${language.name}, "
          '393×852)', (tester) async {
        LiveRechargeEntranceLayer.animate = false;
        addTearDown(() => LiveRechargeEntranceLayer.animate = true);
        final engine = await _room(
          tester,
          language: language,
          viewport: GoldenViewport.phone,
        );
        engine.chat.add(const LiveChatJoined(_hostAgent));
        await _frames(tester);
        await tester.pump(const Duration(milliseconds: 300));
        final barFinder = find.byKey(LiveRechargeEntranceLayer.barKey);
        expect(barFinder, findsOneWidget);
        expect(
          find.bySemanticsLabel(
            l10n.hostAgentEntranceJoined(KFormat.bidiIsolate('Salma')),
          ),
          findsOneWidget,
        );
        final bar = tester.getRect(barFinder);
        // Owner feedback: 85 % of the screen, the art's aspect, fully on
        // screen 16 lp from the edges.
        expect(bar.width, closeTo(393 * 0.85, 0.5));
        expect(
          bar.height,
          closeTo(bar.width / HostAgentArt.entranceAspect, 0.5),
        );
        expect(bar.left, greaterThanOrEqualTo(16 - 0.01));
        expect(bar.right, lessThanOrEqualTo(393 - 16 + 0.01));
        if (language == AppLanguage.ar) {
          expect(bar.right, closeTo(393 - 16, 0.5));
        } else {
          expect(bar.left, closeTo(16, 0.5));
        }
        for (final t in tester.widgetList<Text>(
          find.descendant(of: barFinder, matching: find.byType(Text)),
        )) {
          expect(t.style!.fontSize, greaterThanOrEqualTo(11));
        }
        // The display name, not the username.
        expect(
          find.descendant(
            of: barFinder,
            matching: find.textContaining('Salma'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: barFinder,
            matching: find.textContaining('host03'),
          ),
          findsNothing,
        );
        // The join line carries the host-agent badge.
        expect(find.byType(HostAgentBadge), findsWidgets);
        await tester.pump(LiveRechargeEntranceLayer.duration);
        await tester.pump();
        expect(barFinder, findsNothing);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a very long display name: on screen, ≥ 11, the name ends '
        'with an ellipsis (ar, 393×852)', (tester) async {
      LiveRechargeEntranceLayer.animate = false;
      addTearDown(() => LiveRechargeEntranceLayer.animate = true);
      const longName = 'سارة عبد الرحمن محمد الخطيب الهاشمي القرشي الأنصاري';
      final engine = await _room(
        tester,
        language: AppLanguage.ar,
        viewport: GoldenViewport.phone,
      );
      engine.chat.add(
        const LiveChatJoined(
          UserSummary(
            id: 'u-long',
            username: 'host09',
            displayName: longName,
            avatarUrl: null,
            hostAgentCode: 'host09',
          ),
        ),
      );
      await _frames(tester);
      await tester.pump(const Duration(milliseconds: 300));
      final barFinder = find.byKey(LiveRechargeEntranceLayer.barKey);
      final bar = tester.getRect(barFinder);
      expect(bar.left, greaterThanOrEqualTo(16 - 0.01));
      expect(bar.right, lessThanOrEqualTo(393 - 16 + 0.01));
      final texts = tester.widgetList<Text>(
        find.descendant(of: barFinder, matching: find.byType(Text)),
      );
      for (final t in texts) {
        expect(t.style!.fontSize, greaterThanOrEqualTo(11));
        expect(t.maxLines, 1);
      }
      final named = texts.where((t) => (t.data ?? '').contains(longName));
      expect(named, hasLength(1));
      expect(named.single.overflow, TextOverflow.ellipsis);
      expect(tester.takeException(), isNull);
      await tester.pump(LiveRechargeEntranceLayer.duration);
      await tester.pump();
    });

    testWidgets('both roles: the recharge bar; a plain join: nothing', (
      tester,
    ) async {
      final en = l10nFor(AppLanguage.en);
      final engine = await _room(tester);
      engine.chat.add(const LiveChatJoined(_plain));
      await _frames(tester);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(LiveRechargeEntranceLayer.barKey), findsNothing);
      engine.chat.add(const LiveChatJoined(_both));
      await _frames(tester);
      await tester.pump(const Duration(milliseconds: 800));
      expect(
        find.bySemanticsLabel(
          en.rechargeEntranceJoined(KFormat.bidiIsolate('Nour')),
        ),
        findsOneWidget,
      );
      await tester.pump(LiveRechargeEntranceLayer.duration);
      await tester.pump();
    });

    for (final language in AppLanguage.values) {
      testWidgets("the inline badge next to a host agent's name in the chat; "
          'both badges for both roles (${language.name})', (tester) async {
        final engine = await _room(tester, language: language);
        engine.chat
          ..add(LiveChatReceived(_entry('m1', 'hello', _plain)))
          ..add(LiveChatReceived(_entry('m2', 'hosts here', _hostAgent)))
          ..add(LiveChatReceived(_entry('m3', 'both', _both)));
        await tester.pumpAndSettle();
        Finder inLine(String id, Type type) => find.descendant(
          of: find.byKey(LiveRoomChatLines.lineKey(id)),
          matching: find.byType(type),
        );
        expect(inLine('m:m2', HostAgentBadge), findsOneWidget);
        expect(inLine('m:m2', RechargeAgentBadge), findsNothing);
        expect(inLine('m:m1', HostAgentBadge), findsNothing);
        expect(inLine('m:m3', HostAgentBadge), findsOneWidget);
        expect(inLine('m:m3', RechargeAgentBadge), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('the badge row and the inline row (viewers, seats)', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        const Scaffold(
          backgroundColor: Color(0xFF222222),
          body: Column(
            children: [
              LiveChatBadgeRow(role: null, badges: null, hostAgentCode: 'h'),
              RechargeAgentInlineBadge(code: null, hostCode: 'host03'),
              RechargeAgentInlineBadge(code: 'coin0007', hostCode: 'host04'),
            ],
          ),
        ),
      );
      expect(find.byType(HostAgentBadge), findsNWidgets(3));
      expect(find.byType(RechargeAgentBadge), findsOneWidget);
      expect(
        const LiveChatBadgeRow(
          role: null,
          badges: null,
          hostAgentCode: 'host03',
        ).isNotEmpty,
        isTrue,
      );
    });

    for (final language in AppLanguage.values) {
      testWidgets('the person card: host frame, badge and ID line; both '
          'roles wear the recharge frame and both badges (${language.name}, '
          '360×800)', (tester) async {
        for (final (recharge, host) in [
          (null, 'host03'),
          ('coin0007', 'host04'),
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
                  apiProfile(ar: language == AppLanguage.ar).copyWith(
                    liveRoomId: null,
                    rechargeAgentCode: recharge,
                    hostAgentCode: host,
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
          expect(
            find.byKey(const Key('room.userCard.agentFrame')),
            findsOneWidget,
          );
          expect(
            find.byType(HostAgentFrame),
            recharge == null ? findsOneWidget : findsNothing,
          );
          expect(
            find.byType(RechargeAgentFrame),
            recharge == null ? findsNothing : findsOneWidget,
          );
          expect(
            find.byKey(const Key('room.userCard.hostAgentBadge')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('room.userCard.hostAgentCode')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('room.userCard.agentBadge')),
            recharge == null ? findsNothing : findsOneWidget,
          );
          final rect = tester.getRect(
            find.byKey(const Key('room.userCard.agentFrame')),
          );
          expect(rect.top, greaterThanOrEqualTo(0));
          expect(tester.takeException(), isNull);
        }
      });
    }
  });

  group('profile header', () {
    for (final language in AppLanguage.values) {
      testWidgets('host frame and badge; the recharge frame wins with both '
          '(${language.name})', (tester) async {
        for (final (recharge, host) in [
          (null, 'host03'),
          ('coin0007', 'host04'),
          (null, null),
        ]) {
          await pumpScreen(
            tester,
            Scaffold(
              body: ProfileHeaderView(
                displayName: 'Salma',
                followers: 5,
                following: 3,
                agentCode: recharge,
                hostAgentCode: host,
                actions: const SizedBox(height: 40),
              ),
            ),
            language: language,
          );
          expect(
            find.byKey(ProfileHeaderView.agentFrameKey),
            host == null ? findsNothing : findsOneWidget,
          );
          expect(
            find.byType(HostAgentFrame),
            host != null && recharge == null ? findsOneWidget : findsNothing,
          );
          expect(
            find.byKey(ProfileHeaderView.hostAgentBadgeKey),
            host == null ? findsNothing : findsOneWidget,
          );
          expect(
            find.byKey(ProfileHeaderView.agentBadgeKey),
            recharge == null ? findsNothing : findsOneWidget,
          );
          // Owner (after D189): the host-agent frame is drawn in the
          // recharge frame's box — as high as it, no larger — and the photo
          // fills its measured circle.
          if (host != null && recharge == null) {
            final box = AvatarFrameBox.aroundAvatar(KProfile.avatar);
            final frame = tester.getRect(find.byType(HostAgentFrame));
            expect(frame.height, closeTo(box.height, 0.5));
            expect(frame.width, lessThanOrEqualTo(box.width + 0.5));
            final photo = tester.getRect(
              find.descendant(
                of: find.byType(HostAgentFrame),
                matching: find.byType(KAvatar),
              ),
            );
            expect(photo.width, closeTo(box.height * 2 * 0.2645 * 1.04, 0.5));
          }
          expect(tester.takeException(), isNull);
        }
      });
    }
  });
}
