// D311 (owner: «يمكنه حذف او حظر او تحذير اي شخص»; no code, no password — a
// confirmation only): «إجراءات المؤسس» — the four actions, the confirmation
// with the reason (red for a ban or a deletion), the timed ban's duration,
// the request (one clientId per intent), the honest refusal and the success.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/owner_profile/data/founder_moderation_repository.dart';
import 'package:kabso_live/features/owner_profile/data/owner_profile_repository.dart'
    show isKabsoOwnerProvider;
import 'package:kabso_live/features/owner_profile/presentation/founder_moderation.dart';
import 'package:kabso_live/l10n/gen/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/component_harness.dart';
import '../../helpers/pump_app.dart';

typedef _Call = ({
  String userId,
  FounderAction action,
  String reason,
  String clientId,
  int? days,
});

class _FakeFounderRepo implements FounderModerationRepository {
  final calls = <_Call>[];
  AppFailure? failWith;

  @override
  Future<FounderActionResult> act({
    required String userId,
    required FounderAction action,
    required String reason,
    required String clientId,
    int? days,
  }) async {
    calls.add((
      userId: userId,
      action: action,
      reason: reason,
      clientId: clientId,
      days: days,
    ));
    if (failWith case final e?) throw e;
    return FounderActionResult(
      id: 'action-${calls.length}',
      action: action,
      replayed: false,
    );
  }
}

const FounderTarget _target = (id: 'user-9', username: 'sami', name: 'Sami');

Future<_FakeFounderRepo> _pumpLauncher(
  WidgetTester tester, {
  AppLanguage language = AppLanguage.en,
  _FakeFounderRepo? repo,
  List<bool>? results,
}) async {
  final fake = repo ?? _FakeFounderRepo();
  await pumpScreen(
    tester,
    Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: TextButton(
            key: const Key('open'),
            onPressed: () async {
              final done = await showFounderActions(context, _target);
              results?.add(done);
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
    language: language,
    overrides: [founderModerationRepositoryProvider.overrideWithValue(fake)],
  );
  await tester.pumpAndSettle();
  return fake;
}

void main() {
  for (final language in AppLanguage.values) {
    testWidgets('the sheet lists the four actions, ${language.name}', (
      tester,
    ) async {
      await _pumpLauncher(tester, language: language);
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
      final l10n = lookupAppLocalizations(language.locale);
      expect(find.byKey(FounderActionKeys.sheet), findsOneWidget);
      expect(find.textContaining(l10n.founderActionsFor('')), findsOneWidget);
      for (final a in FounderAction.values) {
        expect(find.byKey(FounderActionKeys.action(a)), findsOneWidget);
        expect(find.text(founderActionLabel(l10n, a)), findsOneWidget);
      }
    });
  }

  testWidgets('a timed ban: the duration and a required reason; one request '
      'with the chosen days; success closes and tells', (tester) async {
    final results = <bool>[];
    final repo = await _pumpLauncher(tester, results: results);
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(FounderActionKeys.action(FounderAction.suspend)),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(FounderActionKeys.dialog), findsOneWidget);
    // No reason yet: «تأكيد» is off.
    final confirm = tester.widget<KButton>(
      find.byKey(FounderActionKeys.confirm),
    );
    expect(confirm.onPressed, isNull);
    expect(confirm.variant, KButtonVariant.destructive);
    for (final d in founderSuspendDays) {
      expect(find.byKey(FounderActionKeys.days(d)), findsOneWidget);
    }
    await tester.tap(find.byKey(FounderActionKeys.days(30)));
    await tester.enterText(find.byKey(FounderActionKeys.reason), '  spam  ');
    await tester.pump();
    await tester.tap(find.byKey(FounderActionKeys.confirm));
    await tester.pumpAndSettle();
    expect(repo.calls, hasLength(1));
    final call = repo.calls.single;
    expect(
      (call.userId, call.action, call.reason, call.days),
      ('user-9', FounderAction.suspend, 'spam', 30),
    );
    expect(call.clientId, matches(RegExp(r'^[0-9a-f-]{36}$')));
    expect(find.byKey(FounderActionKeys.dialog), findsNothing);
    expect(results, [true]);
    expect(find.text('Done: Temporary ban'), findsOneWidget);
  });

  testWidgets('a warning is not destructive and sends no days', (tester) async {
    final repo = await _pumpLauncher(tester);
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(FounderActionKeys.action(FounderAction.warn)));
    await tester.pumpAndSettle();
    expect(find.byKey(FounderActionKeys.days(7)), findsNothing);
    final confirm = tester.widget<KButton>(
      find.byKey(FounderActionKeys.confirm),
    );
    expect(confirm.variant, KButtonVariant.primary);
    await tester.enterText(find.byKey(FounderActionKeys.reason), 'abuse');
    await tester.pump();
    await tester.tap(find.byKey(FounderActionKeys.confirm));
    await tester.pumpAndSettle();
    expect(repo.calls.single.action, FounderAction.warn);
    expect(repo.calls.single.days, isNull);
  });

  testWidgets('a refusal stays in the dialog with its reason; a retry keeps '
      'the same clientId (never acts twice)', (tester) async {
    final repo = _FakeFounderRepo()
      ..failWith = const ServerFailure(
        code: ErrorCode.adminActionRefused,
        rawCode: 'ADMIN_ACTION_REFUSED',
        debugMessage: 'refused',
        statusCode: 409,
        details: [FieldIssue(field: 'rule', issue: 'owner_target')],
      );
    final results = <bool>[];
    await _pumpLauncher(tester, repo: repo, results: results);
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(FounderActionKeys.action(FounderAction.deleteAccount)),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(FounderActionKeys.reason), 'legal');
    await tester.pump();
    await tester.tap(find.byKey(FounderActionKeys.confirm));
    await tester.pumpAndSettle();
    final l10n = lookupAppLocalizations(AppLanguage.en.locale);
    expect(find.byKey(FounderActionKeys.dialog), findsOneWidget);
    expect(find.text(l10n.founderActionSelfOrOwner), findsOneWidget);
    // Not active / pending: the other message.
    repo.failWith = const ServerFailure(
      code: ErrorCode.adminActionRefused,
      rawCode: 'ADMIN_ACTION_REFUSED',
      debugMessage: 'refused',
      statusCode: 409,
    );
    await tester.tap(find.byKey(FounderActionKeys.confirm));
    await tester.pumpAndSettle();
    expect(find.text(l10n.founderActionNotActive), findsOneWidget);
    expect(repo.calls, hasLength(2));
    expect(repo.calls[0].clientId, repo.calls[1].clientId);
    await tester.tap(find.byKey(FounderActionKeys.cancel));
    await tester.pumpAndSettle();
    expect(results, [false]);
  });

  testWidgets('offered only to the app owner, never on himself or an owner', (
    tester,
  ) async {
    final seen = <bool>[];
    Future<void> pump({
      required bool owner,
      bool self = false,
      bool target = false,
    }) => pumpComponent(
      tester,
      ProviderScope(
        key: UniqueKey(),
        overrides: [isKabsoOwnerProvider.overrideWithValue(owner)],
        child: Consumer(
          builder: (context, ref, _) {
            seen.add(
              founderActionsOffered(
                ref,
                targetIsSelf: self,
                targetIsOwner: target,
              ),
            );
            return const SizedBox();
          },
        ),
      ),
    );
    await pump(owner: true);
    await pump(owner: false);
    await pump(owner: true, self: true);
    await pump(owner: true, target: true);
    expect(seen, [true, false, false, false]);
  });
}
