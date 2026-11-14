// CP-016 B (D99): the host's blocked words sheet — add, remove, the count,
// the full list and an honest error.

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/features/live/data/live_blocked_words_repository.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_blocked_words_sheet.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_live_blocked_words_repository.dart';
import '../../helpers/pump_app.dart';

Future<FakeLiveBlockedWordsRepository> _open(
  WidgetTester tester, [
  List<String> words = const [],
]) async {
  final repo = FakeLiveBlockedWordsRepository(words);
  await pumpScreen(
    tester,
    Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () => showLiveBlockedWords(context),
            child: const Text('open'),
          ),
        ),
      ),
    ),
    overrides: [liveBlockedWordsRepositoryProvider.overrideWithValue(repo)],
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return repo;
}

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byKey(LiveBlockedWordsKeys.count)));

void main() {
  testWidgets('add and remove words; each change is saved at once', (
    tester,
  ) async {
    final repo = await _open(tester);
    final l10n = _l10n(tester);
    expect(find.text(l10n.liveBlockedWordsEmpty), findsOneWidget);
    expect(find.text('0/100'), findsOneWidget);

    await tester.enterText(find.byKey(LiveBlockedWordsKeys.field), ' spam ');
    await tester.pump();
    await tester.tap(find.byKey(LiveBlockedWordsKeys.add));
    await tester.pumpAndSettle();
    expect(repo.saves.last, ['spam']);
    expect(find.text('spam'), findsOneWidget);
    expect(find.text('1/100'), findsOneWidget);

    // The same word again (any case) is not sent.
    await tester.enterText(find.byKey(LiveBlockedWordsKeys.field), 'SPAM');
    await tester.pump();
    await tester.tap(find.byKey(LiveBlockedWordsKeys.add));
    await tester.pumpAndSettle();
    expect(repo.saves, hasLength(1));

    await tester.tap(find.byKey(LiveBlockedWordsKeys.remove('spam')));
    await tester.pumpAndSettle();
    expect(repo.saves.last, isEmpty);
    expect(find.text('0/100'), findsOneWidget);
  });

  testWidgets('100 words: the field says the list is full', (tester) async {
    await _open(tester, [for (var i = 0; i < 100; i++) 'w$i']);
    final l10n = _l10n(tester);
    expect(find.text('100/100'), findsOneWidget);
    final field = tester.widget<TextField>(
      find.byKey(LiveBlockedWordsKeys.field),
    );
    expect(field.enabled, isFalse);
    expect(field.decoration?.hintText, l10n.liveBlockedWordsFull);
  });

  testWidgets('a failed save says why and keeps the list', (tester) async {
    final repo = await _open(tester, ['spam']);
    repo.failure = const ServerFailure(
      code: ErrorCode.liveHostingNotAllowed,
      rawCode: 'LIVE_HOSTING_NOT_ALLOWED',
      debugMessage: 'x',
      statusCode: 403,
    );
    await tester.tap(find.byKey(LiveBlockedWordsKeys.remove('spam')));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('spam'), findsOneWidget);
  });
}
