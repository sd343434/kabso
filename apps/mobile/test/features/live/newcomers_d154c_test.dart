// D154c («الجدد», CONVENTIONS §10.35): the host's and moderators' Newcomers
// sheet (the list, the empty and failed states, «رحّب» sending the ready
// welcome line through the room chat once per person) and the «جديد 🌱»
// chat badge — Arabic RTL and English at 360×800.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_newcomers_sheet.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_chat.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_live_newcomers_repository.dart';
import '../../helpers/fake_live_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

const _open = Key('test.openNewcomers');

const _sara = UserSummary(
  id: 'user-sara',
  username: 'sara',
  displayName: 'Sara',
  avatarUrl: null,
);
const _omar = UserSummary(
  id: 'user-omar',
  username: 'omar',
  displayName: 'Omar',
  avatarUrl: null,
);

class _Opener extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        key: _open,
        onPressed: () =>
            unawaited(showLiveNewcomers(context, roomId: 'room-0')),
        child: const SizedBox.square(dimension: 40),
      ),
    ),
  );
}

Future<(FakeLiveNewcomersRepository, FakeLiveRepository)> _pump(
  WidgetTester tester, {
  required FakeLiveNewcomersRepository newcomers,
  AppLanguage language = AppLanguage.en,
}) async {
  setViewport(tester, GoldenViewport.android);
  final live = FakeLiveRepository();
  await pumpScreen(
    tester,
    const _Opener(),
    language: language,
    liveNewcomersRepository: newcomers,
    overrides: [
      liveRepositoryProvider.overrideWithValue(live),
      currentUserProvider.overrideWithValue(testUser()),
    ],
  );
  await tester.tap(find.byKey(_open));
  await tester.pumpAndSettle();
  return (newcomers, live);
}

void main() {
  for (final language in AppLanguage.values) {
    testWidgets('lists the newcomers; «رحّب» sends the ready line once '
        '(${language.name})', (tester) async {
      final (_, live) = await _pump(
        tester,
        newcomers: FakeLiveNewcomersRepository(people: [_sara, _omar]),
        language: language,
      );
      final ar = language == AppLanguage.ar;
      expect(find.text('Sara'), findsOneWidget);
      expect(find.text('Omar'), findsOneWidget);
      expect(
        find.text(
          ar
              ? 'حسابات عمرها أقل من 30 يوماً، موجودة في البث الآن.'
              : 'Accounts less than 30 days old, in this live now.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(LiveNewcomersSheet.welcomeKey('sara')));
      await tester.pumpAndSettle();
      final line = ar
          ? 'send:أهلاً @sara 🌱 نوّرت البث'
          : "send:Welcome @sara 🌱 glad you're here";
      expect(live.chatCalls, [line]);
      expect(find.byKey(LiveNewcomersSheet.welcomeKey('sara')), findsNothing);
      expect(find.text(ar ? 'تم الترحيب ✓' : 'Welcomed ✓'), findsOneWidget);
      expect(find.byKey(LiveNewcomersSheet.welcomeKey('omar')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('no newcomers: says so', (tester) async {
    await _pump(tester, newcomers: FakeLiveNewcomersRepository());
    expect(find.byKey(LiveNewcomersSheet.emptyKey), findsOneWidget);
  });

  testWidgets('a refused list (not a moderator) shows the reason and Retry', (
    tester,
  ) async {
    final (repo, _) = await _pump(
      tester,
      newcomers: FakeLiveNewcomersRepository(
        failure: const ServerFailure(
          code: ErrorCode.authForbidden,
          rawCode: 'AUTH_FORBIDDEN',
          debugMessage: 'x',
          statusCode: 403,
        ),
      ),
    );
    expect(find.text("Couldn't load the newcomers"), findsOneWidget);
    repo
      ..failure = null
      ..people = [_sara];
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Sara'), findsOneWidget);
  });

  testWidgets("the chat shows «جديد 🌱» after a newcomer's name", (
    tester,
  ) async {
    setViewport(tester, GoldenViewport.android);
    await pumpScreen(
      tester,
      const Scaffold(
        body: Center(
          child: LiveChatBadgeRow(
            role: LiveChatRole.viewer,
            badges: LiveChatAuthorBadges(newcomer: true),
          ),
        ),
      ),
      language: AppLanguage.ar,
    );
    expect(find.byKey(LiveChatBadgeRow.newcomerKey), findsOneWidget);
    expect(find.text('جديد 🌱'), findsOneWidget);
  });
}
