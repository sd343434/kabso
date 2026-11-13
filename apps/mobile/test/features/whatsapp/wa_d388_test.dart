// D388 (CONVENTIONS §10.177.4; owner «اللغة تظهر للموظفين»): the customer's
// language on the staff's WhatsApp inbox — the wire shape (AR / EN, null
// until answered, missing from an older server, an unknown value → null),
// the «عربي» / «English» pill on each inbox row and in the chat's status
// strip, nothing while the customer has not answered, and no overflow on a
// small phone with a larger text size.
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/staff/application/staff_providers.dart';
import 'package:kabso_live/features/whatsapp/data/wa_repository.dart';
import 'package:kabso_live/features/whatsapp/domain/wa_models.dart';
import 'package:kabso_live/features/whatsapp/presentation/wa_screens.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_whatsapp.dart';
import '../../helpers/pump_app.dart';
import 'wa_d360_test.dart' show FixedStaffStatus, d360Reply, d360Status;

Future<void> _pump(
  WidgetTester tester,
  Widget screen,
  FakeWaRepository repo, {
  AppLanguage language = AppLanguage.ar,
  Size size = const Size(800, 1600),
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await pumpScreen(
    tester,
    screen,
    language: language,
    overrides: [
      waRepositoryProvider.overrideWithValue(repo),
      staffStatusProvider.overrideWith(
        () => FixedStaffStatus(d360Status(d360Reply)),
      ),
    ],
  );
  await tester.pumpAndSettle();
}

Future<void> _end(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

Finder _textIn(Finder of, String text) =>
    find.descendant(of: of, matching: find.text(text));

Map<String, dynamic> _json([Map<String, dynamic> extra = const {}]) => {
  'id': 'c1',
  'phone': '+966500001001',
  'status': 'OPEN',
  'window': {'open': true},
  ...extra,
};

void main() {
  group('the wire', () {
    test('AR, EN, null, missing (an older server) and unknown', () {
      expect(
        WaConversation.fromJson(_json({'language': 'AR'})).language,
        WaLanguage.ar,
      );
      expect(
        WaConversation.fromJson(_json({'language': 'EN'})).language,
        WaLanguage.en,
      );
      expect(
        WaConversation.fromJson(_json({'language': null})).language,
        isNull,
      );
      expect(WaConversation.fromJson(_json()).language, isNull);
      expect(
        WaConversation.fromJson(_json({'language': 'FR'})).language,
        isNull,
      );
      expect(WaLanguage.ar.wire, 'AR');
      expect(WaLanguage.en.wire, 'EN');
      expect(WaLanguage.fromWire('ar'), isNull);
      expect(WaLanguage.fromWire(1), isNull);
    });
  });

  group('the inbox row', () {
    testWidgets('AR in Arabic: «عربي» next to the department', (tester) async {
      final repo = FakeWaRepository(
        list: [
          waConversation(language: WaLanguage.ar),
          waConversation(id: 'c2', name: 'نورة'),
        ],
      );
      await _pump(tester, const WaInboxScreen(), repo);
      final pill = find.byKey(WaInboxScreen.languageKey('c1'));
      expect(pill, findsOneWidget);
      expect(_textIn(pill, 'عربي'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(WaInboxScreen.row('c1')),
          matching: pill,
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(WaInboxScreen.row('c1')),
          matching: find.byType(WaDepartmentPill),
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Semantics>(
              find.descendant(of: pill, matching: find.byType(Semantics)).first,
            )
            .properties
            .label,
        'لغة العميل: عربي',
      );
      // c2 has not answered: no pill.
      expect(find.byKey(WaInboxScreen.languageKey('c2')), findsNothing);
      expect(find.byType(WaLanguagePill), findsOneWidget);
      await _end(tester);
    });

    testWidgets('EN in English: "English"; AR in English: "Arabic"', (
      tester,
    ) async {
      final repo = FakeWaRepository(
        list: [
          waConversation(language: WaLanguage.en),
          waConversation(id: 'c2', name: 'Noura', language: WaLanguage.ar),
        ],
      );
      await _pump(
        tester,
        const WaInboxScreen(),
        repo,
        language: AppLanguage.en,
      );
      expect(
        _textIn(find.byKey(WaInboxScreen.languageKey('c1')), 'English'),
        findsOneWidget,
      );
      expect(
        _textIn(find.byKey(WaInboxScreen.languageKey('c2')), 'Arabic'),
        findsOneWidget,
      );
      await _end(tester);
    });

    testWidgets('null: no language pill anywhere', (tester) async {
      await _pump(tester, const WaInboxScreen(), FakeWaRepository());
      expect(find.byKey(WaInboxScreen.row('c1')), findsOneWidget);
      expect(find.byKey(WaInboxScreen.languageKey('c1')), findsNothing);
      expect(find.byType(WaLanguagePill), findsNothing);
      await _end(tester);
    });
  });

  group('the chat', () {
    testWidgets('AR in Arabic: «عربي» in the status strip', (tester) async {
      final repo = FakeWaRepository(
        conversation: waConversation(language: WaLanguage.ar),
      );
      await _pump(tester, const WaChatScreen(conversationId: 'c1'), repo);
      final pill = find.byKey(WaChatScreen.languageKey);
      expect(pill, findsOneWidget);
      expect(_textIn(pill, 'عربي'), findsOneWidget);
      expect(
        find.descendant(of: find.byType(WaWindowBanner), matching: pill),
        findsOneWidget,
      );
      await _end(tester);
    });

    testWidgets('EN in English: "English"', (tester) async {
      final repo = FakeWaRepository(
        conversation: waConversation(name: 'Sara', language: WaLanguage.en),
        messages: waMessages(ar: false),
      );
      await _pump(
        tester,
        const WaChatScreen(conversationId: 'c1'),
        repo,
        language: AppLanguage.en,
      );
      expect(
        _textIn(find.byKey(WaChatScreen.languageKey), 'English'),
        findsOneWidget,
      );
      await _end(tester);
    });

    testWidgets('null: no language pill', (tester) async {
      await _pump(
        tester,
        const WaChatScreen(conversationId: 'c1'),
        FakeWaRepository(),
      );
      expect(find.byType(WaWindowBanner), findsOneWidget);
      expect(find.byKey(WaChatScreen.languageKey), findsNothing);
      expect(find.byType(WaLanguagePill), findsNothing);
      await _end(tester);
    });
  });

  testWidgets('360×800, text ×1.3, Arabic: the row and the strip fit', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final c = waConversation(
      name: 'عبدالرحمن بن عبدالعزيز الشهري',
      preview: 'السلام عليكم، لم يصلني الشحن بعد الدفع منذ ساعتين تقريباً',
      unread: 128,
      assignedTo: waMona,
      department: WaDepartment.payments,
      language: WaLanguage.ar,
    );
    final repo = FakeWaRepository(list: [c], conversation: c);
    await _pump(
      tester,
      const WaInboxScreen(),
      repo,
      size: const Size(360, 800),
    );
    expect(tester.takeException(), isNull);
    expect(find.byKey(WaInboxScreen.languageKey('c1')), findsOneWidget);
    await _end(tester);
    await _pump(
      tester,
      const WaChatScreen(conversationId: 'c1'),
      repo,
      size: const Size(360, 800),
    );
    expect(tester.takeException(), isNull);
    expect(find.byKey(WaChatScreen.languageKey), findsOneWidget);
    await _end(tester);
  });
}
