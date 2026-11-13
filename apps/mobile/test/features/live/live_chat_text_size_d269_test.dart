// D269 (owner: «ووحد حجم الخط في جميع البثوث سواء بث حي او صوتي او ستريمير
// او اي كان»): one chat text size, [KChat.textSize], in every live type —
// the viewer's rooms of each mode and the host's flat lines alike.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/live_room_screen.dart';
import 'package:kabso_live/features/live/presentation/widgets/kabso_team_badge.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_chat_flat_line.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_chat_role_tag.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_chat_text.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_chat.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../helpers/fake_live_media_engine.dart';
import '../../helpers/fake_live_repository.dart';
import '../../helpers/fake_profile_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

const _marker = 'd269-size-check';

/// The font size the [marker] text is drawn at (its span's own or inherited
/// style), in any RichText on screen; null when not found.
double? _sizeOf(WidgetTester tester, String marker) {
  double? walk(InlineSpan span, double? inherited) {
    final size = span.style?.fontSize ?? inherited;
    if (span is TextSpan) {
      if (span.text?.contains(marker) ?? false) return size;
      for (final child in span.children ?? const <InlineSpan>[]) {
        final found = walk(child, size);
        if (found != null) return found;
      }
    }
    return null;
  }

  // (KBidiRichText draws through a RichText subclass.)
  final riches = tester.widgetList<RichText>(
    find.byWidgetPredicate((w) => w is RichText),
  );
  for (final rich in riches) {
    final found = walk(rich.text, null);
    if (found != null) return found;
  }
  return null;
}

void main() {
  test('one token: the message and the name sizes', () {
    expect(KChat.textSize, 14.5);
    expect(KChat.nameSize, 14);
  });

  for (final (mode, staff) in [
    (LiveRoomMode.solo, false),
    (LiveRoomMode.multi, false),
    (LiveRoomMode.pk, false),
    (LiveRoomMode.audio, false),
    (LiveRoomMode.podcast, false),
    (LiveRoomMode.streamer, false),
    // D269c (owner's phone, audio room: «حجم الخط هنا لم يتغير»): a Kabso
    // Team line (D273) in the audio room and in the video live.
    (LiveRoomMode.audio, true),
    (LiveRoomMode.solo, true),
  ]) {
    testWidgets("a ${staff ? 'Kabso Team' : "viewer's"} chat line in a "
        '${mode.name} live is KChat.textSize', (tester) async {
      final engine = FakeLiveMediaEngine()..present.add('user-0');
      setViewport(tester, GoldenViewport.phone);
      final repo = FakeLiveRepository(
        room: (id) => apiRoom(id: id).copyWith(
          mode: mode,
          seatCount: switch (mode) {
            LiveRoomMode.audio => 10,
            LiveRoomMode.podcast || LiveRoomMode.multi => 4,
            _ => null,
          },
        ),
      );
      await pumpScreen(
        tester,
        const LiveRoomScreen(roomId: 'room-0'),
        liveMediaEngine: engine,
        overrides: [
          liveRepositoryProvider.overrideWithValue(repo),
          profileRepositoryProvider.overrideWithValue(
            FakeProfileRepository(apiProfile()),
          ),
          currentUserProvider.overrideWithValue(testUser()),
        ],
      );
      await tester.pumpAndSettle();
      engine.chat.add(
        LiveChatReceived(
          LiveChatEntry(
            id: 'm-$mode',
            roomId: 'room-0',
            author: const UserSummary(
              id: 'u-1',
              username: 'huda',
              displayName: 'Huda',
              avatarUrl: null,
            ),
            authorRole: LiveChatRole.viewer,
            text: _marker,
            createdAt: DateTime.utc(2026, 11, 4, 20),
            authorStaff: staff,
            // (What `fromJson` makes of a staff line, D273.)
            authorBadges: staff
                ? const LiveChatAuthorBadges(kabsoTeam: true)
                : null,
          ),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(_sizeOf(tester, _marker), KChat.textSize, reason: mode.name);
      // The name at the one name size too (whichever line draws it).
      expect(_sizeOf(tester, 'Huda'), KChat.nameSize, reason: mode.name);
      if (staff) {
        expect(
          tester
              .widget<LiveChatRoleTag>(
                find.byWidgetPredicate((w) => w is LiveChatRoleTag),
              )
              .kind,
          LiveChatTagKind.team,
        );
      }
      // D269c: the audio room's boxed line is the compact one.
      final avatar = find.byKey(LiveChatAuthoredLine.avatarKey);
      if (avatar.evaluate().isNotEmpty) {
        expect(tester.getSize(avatar.first).width, LiveChatAuthoredLine.avatar);
        expect(LiveChatAuthoredLine.avatar, 26);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }

  testWidgets("the host's flat line (and its role tag before the name)", (
    tester,
  ) async {
    await pumpGolden(
      tester,
      const ProviderScope(
        child: Align(
          child: LiveChatFlatLine(
            name: 'nabb',
            text: _marker,
            label: 'line',
            role: LiveChatRole.host,
          ),
        ),
      ),
      language: AppLanguage.en,
      bare: true,
    );
    expect(_sizeOf(tester, _marker), KChat.textSize);
    final tag = tester.getRect(find.byKey(LiveChatFlatLine.tagKey));
    final name = tester.getRect(find.byKey(LiveChatFlatLine.nameKey));
    expect(tag.right, lessThanOrEqualTo(name.left));
    expect(
      tester.widget<LiveChatRoleTag>(find.byKey(LiveChatFlatLine.tagKey)).kind,
      LiveChatTagKind.host,
    );
  });

  testWidgets("a Kabso Team line (D273) opens with the team's badge (D282)", (
    tester,
  ) async {
    await pumpGolden(
      tester,
      const ProviderScope(
        child: Align(
          child: LiveChatFlatLine(
            name: 'Kabso',
            text: _marker,
            label: 'line',
            role: LiveChatRole.viewer,
            badges: LiveChatAuthorBadges(kabsoTeam: true),
          ),
        ),
      ),
      language: AppLanguage.en,
      bare: true,
    );
    final tag = tester.widget<LiveChatRoleTag>(
      find.byKey(LiveChatFlatLine.tagKey),
    );
    expect(tag.kind, LiveChatTagKind.team);
    expect(
      tester.getRect(find.byKey(LiveChatFlatLine.tagKey)).right,
      lessThanOrEqualTo(
        tester.getRect(find.byKey(LiveChatFlatLine.nameKey)).left,
      ),
    );
    // D282: the tag is the team's badge, at the line's emblem height —
    // and not a second time among the badges.
    expect(find.byKey(KabsoTeamBadge.badgeKey), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(LiveChatFlatLine.tagKey),
        matching: find.byKey(KabsoTeamBadge.badgeKey),
      ),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.byKey(KabsoTeamBadge.badgeKey)).height,
      KabsoTeamBadge.flatChatHeight,
    );
  });

  test('the tags keep their fixed colours', () {
    expect(LiveChatRoleTag.colorOf(LiveChatTagKind.host), LiveChatRoleTag.host);
    expect(
      LiveChatRoleTag.colorOf(LiveChatTagKind.moderator),
      LiveChatRoleTag.moderator,
    );
    // D282: the team wears its badge, not a coloured pill.
    expect(LiveChatRoleTag.colorOf(LiveChatTagKind.team), isNull);
    expect(LiveChatTagKind.of(LiveChatRole.viewer), isNull);
  });
}
