import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/auth/data/auth_repository_impl.dart';
import 'package:kabso_live/features/auth/domain/entities.dart';
import 'package:kabso_live/features/settings/settings_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/fakes.dart';
import '../helpers/pump_app.dart';

class _Repo extends FakeAuthRepository {
  new(this.sessions, {this.revokeFailure});

  List<Session> sessions;
  AppFailure? revokeFailure;

  @override
  Future<List<Session>> listSessions() async => List.of(sessions);

  @override
  Future<void> revokeSession(String sessionId) async {
    sessions = sessions.where((s) => s.id != sessionId).toList();
    final failure = revokeFailure;
    if (failure != null) throw failure;
  }
}

const _current = 's-current';
const _other = 's-other';

List<Session> _sessions(DateTime now) => [
  Session(
    id: _current,
    current: true,
    deviceName: 'A rather long device name for layout testing purposes',
    platform: SessionPlatform.android,
    appVersion: '1.0.0',
    createdAt: DateTime.utc(2026, 10),
    lastUsedAt: now.subtract(const Duration(seconds: 10)),
  ),
  Session(
    id: _other,
    current: false,
    platform: SessionPlatform.ios,
    createdAt: DateTime.utc(2026, 9),
    lastUsedAt: now.subtract(const Duration(hours: 3)),
  ),
];

void main() {
  testWidgets('rows show relative "last active" and the sign-in date', (
    tester,
  ) async {
    final l10n = l10nFor(AppLanguage.en);
    await pumpScreen(
      tester,
      const SettingsScreen(),
      overrides: [
        authRepositoryProvider.overrideWithValue(_Repo(_sessions(clock.now()))),
      ],
    );
    await tester.pumpAndSettle();

    final current = find.byKey(const Key('session.$_current'));
    final other = find.byKey(const Key('session.$_other'));
    await tester.scrollUntilVisible(other, 100);

    expect(
      find.descendant(
        of: current,
        matching: find.textContaining(l10n.sessionsActiveNow),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: other,
        matching: find.textContaining(
          l10n.sessionsLastActive(l10n.relativeHoursAgo(3)),
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: other,
        matching: find.text(l10n.sessionsSignedIn('1 Sep 2026')),
      ),
      findsOneWidget,
    );
  });

  testWidgets('revoke → NOT_FOUND says "already ended" and refreshes', (
    tester,
  ) async {
    final l10n = l10nFor(AppLanguage.en);
    await pumpScreen(
      tester,
      const SettingsScreen(),
      overrides: [
        authRepositoryProvider.overrideWithValue(
          _Repo(
            _sessions(clock.now()),
            revokeFailure: const ServerFailure(
              code: ErrorCode.notFound,
              rawCode: 'NOT_FOUND',
              debugMessage: 'gone',
              statusCode: 404,
            ),
          ),
        ),
      ],
    );
    await tester.pumpAndSettle();
    final other = find.byKey(const Key('session.$_other'));
    await tester.scrollUntilVisible(other, 100);
    await tester.tap(
      find.descendant(of: other, matching: find.text(l10n.sessionsRevoke)),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(l10n.sessionsRevoke),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(l10n.sessionsAlreadyEnded), findsOneWidget);
    expect(other, findsNothing);
  });

  group('adaptive row (QA-004): no layout error at 360×640', () {
    for (final language in AppLanguage.values) {
      for (final scale in [1.0, 1.3, 2.0]) {
        testWidgets('${language.name} x$scale', (tester) async {
          tester.view
            ..physicalSize = const Size(360, 640)
            ..devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

          await pumpScreen(
            tester,
            const SettingsScreen(),
            language: language,
            overrides: [
              authRepositoryProvider.overrideWithValue(
                _Repo(_sessions(clock.now())),
              ),
            ],
          );
          await tester.pumpAndSettle();
          final other = find.byKey(const Key('session.$_other'));
          await tester.scrollUntilVisible(other, 100);
          expect(tester.takeException(), isNull);

          final revoke = find.descendant(
            of: other,
            matching: find.byType(TextButton),
          );
          expect(revoke, findsOneWidget);
          final size = tester.getSize(revoke);
          expect(size.height, greaterThanOrEqualTo(48));
          expect(size.width, greaterThanOrEqualTo(48));
        });
      }
    }
  });
}
