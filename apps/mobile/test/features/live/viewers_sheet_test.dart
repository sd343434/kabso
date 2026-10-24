import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/presentation/go_live/seat_controls.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_live_repository.dart';
import '../../helpers/pump_app.dart';

const _huda = UserSummary(
  id: 'u-huda',
  username: 'huda',
  displayName: 'Huda',
  avatarUrl: null,
);
const _omar = UserSummary(
  id: 'u-omar',
  username: 'omar',
  displayName: 'Omar',
  avatarUrl: null,
);

void main() {
  final l10n = l10nFor(AppLanguage.en);

  testWidgets('viewers sheet: real viewers (people and guests), invite only '
      'for people not seated; the Guests tab lists who is on a seat', (
    tester,
  ) async {
    final repo = FakeLiveRepository()
      ..viewerList = [
        LiveViewer(
          kind: LiveViewerKind.user,
          user: _huda,
          guestNumber: null,
          joinedAt: DateTime.utc(2026, 10, 24),
        ),
        LiveViewer(
          kind: LiveViewerKind.user,
          user: _omar,
          guestNumber: null,
          joinedAt: DateTime.utc(2026, 10, 24),
        ),
        LiveViewer(
          kind: LiveViewerKind.guest,
          user: null,
          guestNumber: 4821,
          joinedAt: DateTime.utc(2026, 10, 24),
        ),
      ];
    final invited = <String>[];
    await pumpScreen(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => showInviteViewers(
                context,
                roomId: 'room-0',
                moderators: const [],
                seated: const [
                  LiveSeat(index: 2, state: LiveSeatState.taken, user: _omar),
                  LiveSeat(index: 3, state: LiveSeatState.empty, user: null),
                ],
                onInvite: (username) async => invited.add(username),
                onModerator: (_, {required moderator}) async {},
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
      overrides: [liveRepositoryProvider.overrideWithValue(repo)],
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text(l10n.liveViewersTab('3')), findsOneWidget);
    expect(find.text('${l10n.liveSeatGuestsTab} 1'), findsOneWidget);
    expect(find.textContaining('Huda'), findsOneWidget);
    // Names are direction-isolated in the row.
    expect(find.textContaining('4821'), findsOneWidget);
    // Huda is watching: invite. Omar is seated: no invite. Guests: none.
    expect(find.byKey(SeatControlKeys.inviteUser('huda')), findsOneWidget);
    expect(find.byKey(SeatControlKeys.inviteUser('omar')), findsNothing);
    await tester.tap(find.byKey(SeatControlKeys.inviteUser('huda')));
    await tester.pumpAndSettle();
    expect(invited, ['huda']);
    expect(find.text(l10n.liveSeatInvited), findsOneWidget);

    await tester.tap(find.byKey(SeatControlKeys.guestsTab));
    await tester.pumpAndSettle();
    expect(find.textContaining('Omar'), findsOneWidget);
    expect(find.text(l10n.liveSeatNumberLabel(2)), findsOneWidget);
  });
}
