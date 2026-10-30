// D185 in the live room: an ACTIVE recharge agent (`UserSummary.
// rechargeAgent`) gets the entrance bar «دخل Nour البث» (3.2 s,
// queued, never takes taps; nothing for a normal join) and — owner addition —
// the small agent badge next to the name everywhere it shows in the room:
// chat messages, the join line, the viewers list, seats and the person card
// (with the agent frame and the recharge ID). Without the flag (a suspended
// agent) none of it shows. Arabic and English, 360×800.

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/cp/data/cp_repository.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/live/live_room_screen.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_chat.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
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

const _agent = UserSummary(
  id: 'u-agent',
  username: 'nour.store',
  displayName: 'Nour',
  avatarUrl: null,
  rechargeAgentCode: 'coin0007',
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
  final en = l10nFor(AppLanguage.en);
  final ar = l10nFor(AppLanguage.ar);

  setUp(() => LiveRechargeEntranceLayer.animate = true);

  group('entrance bar', () {
    for (final language in AppLanguage.values) {
      final l10n = language == AppLanguage.ar ? ar : en;
      testWidgets('an agent join plays the bar with the display name; a '
          'normal join '
          'does not (${language.name})', (tester) async {
        final engine = await _room(tester, language: language);
        engine.chat.add(const LiveChatJoined(_plain));
        await _frames(tester);
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byKey(LiveRechargeEntranceLayer.barKey), findsNothing);

        engine.chat.add(const LiveChatJoined(_agent));
        await _frames(tester);
        await tester.pump(const Duration(milliseconds: 800));
        expect(find.byKey(LiveRechargeEntranceLayer.barKey), findsOneWidget);
        expect(
          find.bySemanticsLabel(
            l10n.rechargeEntranceJoined(KFormat.bidiIsolate('Nour')),
          ),
          findsOneWidget,
        );
        // Never takes taps.
        expect(
          find.ancestor(
            of: find.byKey(LiveRechargeEntranceLayer.barKey),
            matching: find.byType(IgnorePointer),
          ),
          findsWidgets,
        );
        // The join line carries the badge next to the name.
        expect(find.byType(RechargeAgentBadge), findsWidgets);
        await tester.pump(LiveRechargeEntranceLayer.duration);
        await tester.pump();
        expect(find.byKey(LiveRechargeEntranceLayer.barKey), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }

    for (final language in AppLanguage.values) {
      testWidgets('owner size: 40 % of the screen, 16 lp from the edges, the '
          "art's aspect, at the leading side above the chat; one line ≥ 9 "
          'with the display name (${language.name}, 393×852)', (tester) async {
        LiveRechargeEntranceLayer.animate = false;
        addTearDown(() => LiveRechargeEntranceLayer.animate = true);
        final engine = await _room(tester, language: language);
        setViewport(tester, GoldenViewport.phone);
        await tester.pumpAndSettle();
        engine.chat.add(const LiveChatJoined(_agent));
        await _frames(tester);
        await tester.pump(const Duration(milliseconds: 300));
        final bar = tester.getRect(
          find.byKey(LiveRechargeEntranceLayer.barKey),
        );
        // Owner: 40 % of the screen, the height from the art's
        // aspect, fully on screen 16 lp from the leading edge.
        expect(bar.width, closeTo(393 * 0.40, 0.5));
        expect(
          bar.height,
          closeTo(bar.width / RechargeAgentArt.entranceAspect, 0.5),
        );
        expect(bar.left, greaterThanOrEqualTo(16 - 0.01));
        expect(bar.right, lessThanOrEqualTo(393 - 16 + 0.01));
        if (language == AppLanguage.ar) {
          expect(bar.right, closeTo(393 - 16, 0.5));
        } else {
          expect(bar.left, closeTo(16, 0.5));
        }
        // Above the chat area.
        final chat = tester.getRect(
          find
              .byWidgetPredicate(
                (w) =>
                    w.key is ValueKey<String> &&
                    (w.key! as ValueKey<String>).value.startsWith(
                      'liveChat.line.',
                    ),
              )
              .first,
        );
        expect(bar.bottom, lessThanOrEqualTo(chat.top));
        final texts = tester.widgetList<Text>(
          find.descendant(
            of: find.byKey(LiveRechargeEntranceLayer.barKey),
            matching: find.byType(Text),
          ),
        );
        for (final t in texts) {
          expect(t.style!.fontSize, greaterThanOrEqualTo(9));
        }
        // The display name (not the code or the username); one line when
        // it fits (the test font is wider than the app's, see the captures).
        expect(
          find.descendant(
            of: find.byKey(LiveRechargeEntranceLayer.barKey),
            matching: find.textContaining('Nour'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(LiveRechargeEntranceLayer.barKey),
            matching: find.textContaining('coin0007'),
          ),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
        await tester.pump(LiveRechargeEntranceLayer.duration);
        await tester.pump();
      });
    }

    testWidgets('two agents queue one after another', (tester) async {
      final engine = await _room(tester);
      engine.chat
        ..add(const LiveChatJoined(_agent))
        ..add(
          const LiveChatJoined(
            UserSummary(
              id: 'u-2',
              username: 'b',
              displayName: 'B',
              avatarUrl: null,
              rechargeAgentCode: 'coin0012',
            ),
          ),
        );
      await _frames(tester);
      await tester.pump(const Duration(milliseconds: 800));
      expect(
        find.bySemanticsLabel(
          en.rechargeEntranceJoined(KFormat.bidiIsolate('Nour')),
        ),
        findsOneWidget,
      );
      await tester.pump(LiveRechargeEntranceLayer.duration);
      await tester.pump(const Duration(milliseconds: 800));
      expect(
        find.bySemanticsLabel(
          en.rechargeEntranceJoined(KFormat.bidiIsolate('B')),
        ),
        findsOneWidget,
      );
      await tester.pump(LiveRechargeEntranceLayer.duration);
      await tester.pump();
    });
  });

  group('the inline badge', () {
    for (final language in AppLanguage.values) {
      testWidgets("next to an agent's name in the chat, not a plain one "
          '(${language.name})', (tester) async {
        final engine = await _room(tester, language: language);
        engine.chat
          ..add(LiveChatReceived(_entry('m1', 'hello', _plain)))
          ..add(LiveChatReceived(_entry('m2', 'coins here', _agent)));
        await tester.pumpAndSettle();
        final agentLine = find.byKey(LiveRoomChatLines.lineKey('m:m2'));
        final plainLine = find.byKey(LiveRoomChatLines.lineKey('m:m1'));
        expect(
          find.descendant(
            of: agentLine,
            matching: find.byType(RechargeAgentBadge),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: plainLine,
            matching: find.byType(RechargeAgentBadge),
          ),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('the badge row and the inline row carry it (viewers, seats)', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        const Scaffold(
          backgroundColor: Color(0xFF222222),
          body: Column(
            children: [
              LiveChatBadgeRow(role: null, badges: null, agentCode: 'coin0007'),
              LiveChatBadgeRow(role: null, badges: null),
              RechargeAgentInlineBadge(code: null),
            ],
          ),
        ),
      );
      expect(find.byType(RechargeAgentBadge), findsOneWidget);
      expect(
        const LiveChatBadgeRow(
          role: null,
          badges: null,
          agentCode: 'coin0007',
        ).isNotEmpty,
        isTrue,
      );
    });

    for (final language in AppLanguage.values) {
      testWidgets('the person card: frame, badge and the recharge ID '
          '(${language.name}, 360×800)', (tester) async {
        for (final code in ['coin0007', null]) {
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
                      .copyWith(liveRoomId: null, rechargeAgentCode: code),
                ),
              ),
              safetyRepositoryProvider.overrideWithValue(
                FakeSafetyRepository(),
              ),
            ],
          );
          await tester.tap(find.text('open'));
          await tester.pumpAndSettle();
          final framed = code != null;
          expect(
            find.byKey(const Key('room.userCard.agentFrame')),
            framed ? findsOneWidget : findsNothing,
          );
          expect(
            find.byKey(const Key('room.userCard.agentBadge')),
            framed ? findsOneWidget : findsNothing,
          );
          expect(
            find.byKey(const Key('room.userCard.agentCode')),
            framed ? findsOneWidget : findsNothing,
          );
          if (framed) {
            expect(
              tester.widget<Text>(find.byKey(RechargeAgentFrame.plateKey)).data,
              // Owner (D185, same day): the plate shows the display name.
              apiProfile(ar: language == AppLanguage.ar).displayName,
            );
            final rect = tester.getRect(
              find.byKey(const Key('room.userCard.agentFrame')),
            );
            expect(rect.top, greaterThanOrEqualTo(0));
          }
          expect(tester.takeException(), isNull);
        }
      });
    }
  });
}
