// KL-056: conversation list preview and first-time conversation (labelled
// test data, debug only).

import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/debug/conversations_preview_screen.dart';
import 'package:kabso_live/features/debug/messages_preview_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';

final _now = DateTime(2026, 10, 18, 12);

void _phone(WidgetTester tester, {double width = 417, double height = 904}) {
  tester.view
    ..physicalSize = Size(width * 3, height * 3)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<void> _pump(
  WidgetTester tester, {
  AppLanguage language = AppLanguage.en,
  ConversationsPreviewState state = ConversationsPreviewState.populated,
}) => withClock(
  Clock.fixed(_now),
  () => pumpScreen(
    tester,
    // A key per state: a new initial state builds a new screen state.
    ConversationsPreviewScreen(key: ValueKey(state), initialState: state),
    language: language,
  ),
);

// A row of the list (the "active now" row also names online people).
Finder _row(String peer) => find.byKey(ConversationsPreviewScreen.rowKey(peer));

void main() {
  testWidgets('populated: labelled rows with preview lines and times', (
    tester,
  ) async {
    _phone(tester);
    await _pump(tester);
    final l10n = l10nFor(AppLanguage.en);
    expect(find.byKey(ConversationsPreviewScreen.testDataKey), findsOneWidget);
    expect(find.text(l10n.conversationsTitle), findsOneWidget);
    expect(find.text('Nour (test)'), findsOneWidget);
    expect(find.text(l10n.conversationsSharedVideo), findsOneWidget);
    expect(find.text('A test message'), findsOneWidget);
    expect(find.text(l10n.relativeMinutesAgo(5)), findsOneWidget);
    expect(find.text(l10n.relativeHoursAgo(3)), findsOneWidget);
    expect(find.text(l10n.relativeDaysAgo(2)), findsOneWidget);
    // Older than a week: an absolute date.
    expect(find.text('6 Oct 2026'), findsOneWidget);
  });

  testWidgets('measured rows: 73 high, unread 81; avatar 57', (tester) async {
    _phone(tester);
    await _pump(tester);
    final l10n = l10nFor(AppLanguage.en);
    expect(
      tester
          .getSize(
            find.bySemanticsLabel(l10n.conversationsUnread('Nour (test)')),
          )
          .height,
      KConversations.unreadRowHeight,
    );
    expect(
      tester.getSize(_row('Sami (test)')).height,
      KConversations.rowHeight,
    );
    final avatar = tester.getSize(
      find.descendant(of: _row('Sami (test)'), matching: find.byType(KAvatar)),
    );
    expect(avatar.width, KConversations.avatar);
  });

  for (final language in AppLanguage.values) {
    testWidgets('avatar at the start, time at the end (${language.name})', (
      tester,
    ) async {
      _phone(tester);
      await _pump(tester, language: language);
      final ar = language == AppLanguage.ar;
      final l10n = l10nFor(language);
      final row = _row(ar ? 'سامي (تجربة)' : 'Sami (test)');
      final avatar = tester.getCenter(
        find.descendant(of: row, matching: find.byType(KAvatar)),
      );
      final time = tester.getCenter(find.text(l10n.relativeHoursAgo(3)));
      if (ar) {
        expect(avatar.dx, greaterThan(time.dx));
      } else {
        expect(avatar.dx, lessThan(time.dx));
      }
    });
  }

  testWidgets('a conversation with messages opens its thread', (tester) async {
    _phone(tester);
    await _pump(tester);
    await tester.tap(_row('Sami (test)'));
    await tester.pumpAndSettle();
    expect(find.byType(MessagesPreviewScreen), findsOneWidget);
    expect(find.text('Sami (test)'), findsOneWidget);
    expect(find.byKey(MessagesPreviewScreen.greetingKey), findsNothing);
    expect(find.text('Hi! This is a test message'), findsOneWidget);
  });

  testWidgets('an empty conversation shows the greeting; a tile sends it', (
    tester,
  ) async {
    _phone(tester);
    await _pump(tester);
    final l10n = l10nFor(AppLanguage.en);
    await tester.tap(_row('Hind (test)'));
    await tester.pumpAndSettle();
    expect(find.byKey(MessagesPreviewScreen.greetingKey), findsOneWidget);
    expect(
      find.text(l10n.conversationsSayHi(KFormat.bidiIsolate('Hind (test)'))),
      findsOneWidget,
    );
    await tester.tap(find.bySemanticsLabel(l10n.messagesGreetingHi));
    await tester.pumpAndSettle();
    expect(find.byKey(MessagesPreviewScreen.greetingKey), findsNothing);
    expect(find.text(l10n.messagesGreetingHi), findsOneWidget);
  });

  testWidgets('the greeting can be dismissed without sending', (tester) async {
    _phone(tester);
    await _pump(tester);
    await tester.tap(_row('Omar (test)'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(MessagesPreviewScreen.greetingCloseKey));
    await tester.pumpAndSettle();
    expect(find.byKey(MessagesPreviewScreen.greetingKey), findsNothing);
  });

  testWidgets('loading, error, unavailable and empty states', (tester) async {
    _phone(tester);
    final l10n = l10nFor(AppLanguage.en);
    await _pump(tester, state: ConversationsPreviewState.loading);
    expect(find.byType(KSkeleton), findsWidgets);

    await _pump(tester, state: ConversationsPreviewState.error);
    expect(find.text(l10n.errorTitle), findsOneWidget);
    await tester.tap(find.text(l10n.actionRetry));
    await tester.pump();
    expect(find.byType(KSkeleton), findsWidgets);

    await _pump(tester, state: ConversationsPreviewState.unavailable);
    expect(find.text(l10n.conversationsUnavailableTitle), findsOneWidget);

    await _pump(tester, state: ConversationsPreviewState.empty);
    expect(find.text(l10n.conversationsEmptyTitle), findsOneWidget);
    expect(find.byKey(ConversationsPreviewScreen.listKey), findsNothing);
  });

  testWidgets('no state switcher on screen (owner, D68)', (tester) async {
    _phone(tester);
    await _pump(tester);
    final l10n = l10nFor(AppLanguage.en);
    expect(find.text(l10n.previewStateLoading), findsNothing);
    expect(find.text(l10n.previewStateError), findsNothing);
  });

  for (final language in AppLanguage.values) {
    testWidgets('360x800 at text scale 1.3 does not overflow '
        '(${language.name})', (tester) async {
      _phone(tester, width: 360, height: 800);
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _pump(tester, language: language);
      expect(tester.takeException(), isNull);
      // The greeting also fits.
      await tester.tap(
        _row(language == AppLanguage.ar ? 'هند (تجربة)' : 'Hind (test)'),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(MessagesPreviewScreen.greetingKey), findsOneWidget);
    });
  }

  test('the preview route is only registered outside release mode', () {
    final router = File('lib/app/router/app_router.dart').readAsStringSync();
    expect(
      router,
      contains(
        'if (!kReleaseMode)\n'
        '        GoRoute(\n'
        '          path: AppRoutes.debugConversationsPreview,',
      ),
    );
    final users = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where(
          (f) =>
              f.readAsStringSync().contains('ConversationsPreviewScreen') ||
              f.readAsStringSync().contains(
                'AppRoutes.debugConversationsPreview',
              ),
        )
        .map((f) => f.path.replaceAll(r'\', '/'))
        .toSet();
    expect(users, {
      'lib/app/router/app_router.dart',
      'lib/features/debug/conversations_preview_screen.dart',
      'lib/features/debug/previews_hub_screen.dart',
    });
  });
}
