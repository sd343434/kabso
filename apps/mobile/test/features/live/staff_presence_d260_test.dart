import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_audio_room.dart';
import 'package:kabso_live/features/live/presentation/go_live/seat_controls.dart';
import 'package:kabso_live/features/live/presentation/widgets/kabso_team_badge.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_live_repository.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

/// D260 (owner: staff who watch a live are shown with a «فريق كابسو» badge,
/// so the host knows the live is watched; v1.64-live, CONVENTIONS §10.96):
/// the viewer list shows the Kabso staff first with the badge — not counted
/// in the tab's number, no person card (a tap says who the team is) — and
/// the top viewers show the team's shield, never one of the ranked faces.

const _huda = UserSummary(
  id: 'u-huda',
  username: 'huda',
  displayName: 'Huda',
  avatarUrl: null,
);
const _omar = UserSummary(
  id: 'u-omar',
  username: 'omar',
  displayName: 'عمر',
  avatarUrl: null,
);

final _staff = [
  LiveStaffWatcher(
    displayName: 'سارة',
    avatarUrl: null,
    since: DateTime.utc(2026, 11, 4, 10),
  ),
];

FakeLiveRepository _repo() => FakeLiveRepository()
  ..viewerList = [
    for (final u in [_huda, _omar])
      LiveViewer(
        kind: LiveViewerKind.user,
        user: u,
        guestNumber: null,
        joinedAt: DateTime.utc(2026, 11, 4),
      ),
  ]
  ..staffList = _staff;

Widget _opener(List<String> opened) => Builder(
  builder: (context) => Center(
    child: TextButton(
      onPressed: () => showLiveViewers(
        context,
        roomId: 'room-0',
        onPerson: (u) => opened.add(u.username),
      ),
      child: const Text('open'),
    ),
  ),
);

void main() {
  test('LiveStaffWatcher reads the page entry; an older server has none', () {
    final s = LiveStaffWatcher.fromJson({
      'displayName': 'سارة',
      'avatarUrl': null,
      'since': '2026-11-04T10:00:00.000Z',
    });
    expect(s, _staff.single);
    expect(
      LiveStaffWatcher.fromJson(const {'displayName': 'X'}).avatarUrl,
      isNull,
    );
  });

  for (final language in AppLanguage.values) {
    testWidgets('D260 (${language.name}): the Kabso staff first with the '
        'badge, not counted; a tap shows who the team is, no person card', (
      tester,
    ) async {
      final l = l10nFor(language);
      final opened = <String>[];
      await pumpScreen(
        tester,
        Scaffold(body: _opener(opened)),
        overrides: [liveRepositoryProvider.overrideWithValue(_repo())],
        language: language,
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Two viewers counted; the staff member is listed but not counted.
      expect(find.text(l.liveViewersTab('2')), findsOneWidget);
      expect(find.byKey(SeatControlKeys.staffRow(0)), findsOneWidget);
      expect(find.byKey(KabsoTeamBadge.badgeKey), findsOneWidget);
      expect(find.text(l.liveKabsoTeam), findsOneWidget);
      // First in the list, above the viewers.
      final staffY = tester
          .getTopLeft(find.byKey(SeatControlKeys.staffRow(0)))
          .dy;
      final hudaY = tester
          .getTopLeft(find.byKey(SeatControlKeys.moderatorUser('huda')))
          .dy;
      expect(staffY, lessThan(hudaY));

      await tester.tap(find.byKey(SeatControlKeys.staffRow(0)));
      await tester.pumpAndSettle();
      expect(find.text(l.liveKabsoTeamInfo), findsOneWidget);
      expect(opened, isEmpty);
      await tester.tap(find.byType(TextButton).last);
      await tester.pumpAndSettle();
      expect(find.text(l.liveKabsoTeamInfo), findsNothing);

      // A viewer still opens their card.
      await tester.tap(find.byKey(SeatControlKeys.moderatorUser('huda')));
      await tester.pumpAndSettle();
      expect(opened, ['huda']);
    });
  }

  testWidgets('D260: with only the team watching the list is not empty', (
    tester,
  ) async {
    final l = l10nFor(AppLanguage.en);
    final repo = FakeLiveRepository()..staffList = _staff;
    await pumpScreen(
      tester,
      Scaffold(body: _opener([])),
      overrides: [liveRepositoryProvider.overrideWithValue(repo)],
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text(l.liveSeatInviteEmpty), findsNothing);
    expect(find.byKey(SeatControlKeys.staffRow(0)), findsOneWidget);
    expect(find.text(l.liveViewersTab('0')), findsOneWidget);
  });

  testWidgets('D260: the top viewers show the team shield — not a ranked '
      'face, not counted', (tester) async {
    final l = l10nFor(AppLanguage.ar);
    await pumpScreen(
      tester,
      const Scaffold(
        body: Center(
          child: LiveViewersStack(
            avatars: [
              CircleAvatar(child: Text('A')),
              CircleAvatar(child: Text('B')),
            ],
            ranks: [1, null],
            count: '2',
            label: '2 watching',
            team: KabsoTeamShield(size: LiveViewersStack.size),
          ),
        ),
      ),
      language: AppLanguage.ar,
    );
    expect(find.byKey(KabsoTeamShield.shieldKey), findsOneWidget);
    expect(find.byKey(LiveViewersStack.frameKey(1)), findsOneWidget);
    expect(find.byKey(LiveViewersStack.frameKey(2)), findsNothing);
    expect(find.text('2'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp(l.liveKabsoTeamHere)),
      findsOneWidget,
    );
  });

  group('goldens', () {
    for (final language in AppLanguage.values) {
      testWidgets('live_viewers_staff (${language.name})', (tester) async {
        // The sheet needs the repository above the navigator: the app's
        // own scope (pumpScreen), with the golden fonts and viewport.
        await loadAppFonts();
        setViewport(tester, GoldenViewport.phone);
        await pumpScreen(
          tester,
          Scaffold(body: _opener([])),
          overrides: [liveRepositoryProvider.overrideWithValue(_repo())],
          language: language,
          brightness: Brightness.light,
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            '../../goldens/png/live_viewers_staff.${language.name}.phone.png',
          ),
        );
      }, tags: goldenTag);
    }
  });
}
