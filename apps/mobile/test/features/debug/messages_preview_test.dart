// KL-056: private conversation preview (labelled test data, debug only).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/debug/messages_preview_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';

Future<void> _pump(
  WidgetTester tester, {
  AppLanguage language = AppLanguage.en,
}) => pumpScreen(tester, const MessagesPreviewScreen(), language: language);

void _phone(WidgetTester tester, {double width = 414, double height = 896}) {
  tester.view
    ..physicalSize = Size(width * 3, height * 3)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('labelled test data: peer, bubbles, media and a reaction', (
    tester,
  ) async {
    _phone(tester);
    await _pump(tester);
    expect(find.byKey(MessagesPreviewScreen.testDataKey), findsOneWidget);
    expect(find.text('Nour (test)'), findsOneWidget);
    expect(find.text('Hi! This is a test message'), findsOneWidget);
    expect(find.text('Hey, got it'), findsOneWidget);
    expect(find.text('❤️'), findsOneWidget);
  });

  for (final language in AppLanguage.values) {
    testWidgets('received at the start, sent at the end (${language.name})', (
      tester,
    ) async {
      _phone(tester);
      await _pump(tester, language: language);
      final ar = language == AppLanguage.ar;
      final received = tester.getRect(
        find.text(
          ar ? 'مرحبًا! هذه رسالة تجريبية' : 'Hi! This is a test message',
        ),
      );
      final sent = tester.getRect(
        find.text(ar ? 'أهلًا، وصلت' : 'Hey, got it'),
      );
      const half = 414 / 2;
      if (ar) {
        expect(received.center.dx, greaterThan(half));
        expect(sent.center.dx, lessThan(half));
      } else {
        expect(received.center.dx, lessThan(half));
        expect(sent.center.dx, greaterThan(half));
      }
    });
  }

  testWidgets('measured media sizes: picture 180x238, video 168x297', (
    tester,
  ) async {
    _phone(tester);
    await _pump(tester);
    final sizes = tester
        .widgetList<SizedBox>(find.byType(SizedBox))
        .map((b) => Size(b.width ?? -1, b.height ?? -1))
        .toSet();
    expect(sizes, contains(KMessagePreview.picture));
    // The video bubble is further down the list.
    await tester.scrollUntilVisible(
      find.byIcon(Icons.play_arrow_rounded),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      tester
          .widgetList<SizedBox>(find.byType(SizedBox))
          .map((b) => Size(b.width ?? -1, b.height ?? -1)),
      contains(KMessagePreview.video),
    );
  });

  testWidgets('the composer appends a sent message and clears itself', (
    tester,
  ) async {
    _phone(tester);
    await _pump(tester);
    await tester.enterText(find.byKey(MessagesPreviewScreen.inputKey), 'Hello');
    await tester.tap(find.byKey(MessagesPreviewScreen.sendKey));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Hello'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Hello'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(MessagesPreviewScreen.inputKey))
          .controller!
          .text,
      isEmpty,
    );
    // Blank input sends nothing.
    await tester.tap(find.byKey(MessagesPreviewScreen.sendKey));
    await tester.pumpAndSettle();
    expect(find.text('Hello'), findsOneWidget);
  });

  for (final language in AppLanguage.values) {
    testWidgets('360x800 at text scale 1.3 does not overflow '
        '(${language.name})', (tester) async {
      _phone(tester, width: 360, height: 800);
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _pump(tester, language: language);
      expect(tester.takeException(), isNull);
    });
  }

  test('the preview route is only registered outside release mode', () {
    final router = File('lib/app/router/app_router.dart').readAsStringSync();
    expect(
      router,
      contains(
        'if (!kReleaseMode)\n'
        '        GoRoute(\n'
        '          path: AppRoutes.debugMessagesPreview,',
      ),
    );
    final users = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where(
          (f) =>
              f.readAsStringSync().contains('MessagesPreviewScreen') ||
              f.readAsStringSync().contains('AppRoutes.debugMessagesPreview'),
        )
        .map((f) => f.path.replaceAll(r'\', '/'))
        .toSet();
    expect(users, {
      'lib/app/router/app_router.dart',
      'lib/features/debug/messages_preview_screen.dart',
      // The conversation list opens threads in the messages preview.
      'lib/features/debug/conversations_preview_screen.dart',
      // The debug-only hub links to every preview.
      'lib/features/debug/previews_hub_screen.dart',
    });
  });
}
