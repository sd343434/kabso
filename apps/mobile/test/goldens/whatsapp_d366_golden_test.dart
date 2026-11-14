// D366 (owner «نعم موافق»): WhatsApp departments and the transfer.
//
//   whatsapp.transfer_sheet  the sheet opened from the header's «تحويل»: the
//                            department chips (PAYMENTS picked), «أول متاح في
//                            القسم» first, the department's agents with the
//                            on-shift dot and their open conversations, one
//                            picked, the note and «تحويل»
//   whatsapp.transferred     the chat after a transfer to the PAYMENTS queue:
//                            «قائمة الشحن والمدفوعات» and the department chip
//                            in the status strip
//
// The header's transfer button and the inbox's department chips and filter
// are in the D355 goldens (whatsapp.chat, whatsapp.inbox).
//
// Arabic and English, dark and light, on the phone (393 × 852). A fixed clock;
// synthetic customers and staff. Regenerate on Linux with the pinned Flutter:
//   flutter test --update-goldens test/goldens/whatsapp_d366_golden_test.dart
@Tags(['golden'])
library;

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/whatsapp/data/wa_repository.dart';
import 'package:kabso_live/features/whatsapp/domain/wa_models.dart';
import 'package:kabso_live/features/whatsapp/presentation/wa_screens.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/fake_whatsapp.dart';
import '../helpers/golden.dart';
import '../helpers/pump_app.dart';

void main() {
  setUpAll(loadAppFonts);

  forEachLanguage((language) {
    final ar = language == AppLanguage.ar;
    final name = language.name;
    for (final (label, brightness) in [
      ('phone', Brightness.dark),
      ('phone.light', Brightness.light),
    ]) {
      Future<void> pump(WidgetTester tester, FakeWaRepository repo) async {
        await loadAppFonts();
        setViewport(tester, GoldenViewport.phone);
        await withClock(Clock.fixed(d355Now), () async {
          await pumpScreen(
            tester,
            const WaChatScreen(conversationId: 'c1'),
            language: language,
            brightness: brightness,
            overrides: [waRepositoryProvider.overrideWithValue(repo)],
          );
          await tester.pumpAndSettle();
          await precacheImages(tester);
        });
      }

      Future<void> end(WidgetTester tester) async {
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      }

      testWidgets('whatsapp.transfer_sheet $name $label', (tester) async {
        final repo = FakeWaRepository(
          conversation: waConversation(
            assignedTo: waMe,
            assignedToMe: true,
            unread: 0,
          ),
          messages: waMessages(ar: ar, reaction: false),
        );
        await pump(tester, repo);
        await withClock(Clock.fixed(d355Now), () async {
          await tester.tap(find.byKey(WaChatScreen.transferKey));
          await tester.pumpAndSettle();
          await tester.tap(
            find.byKey(WaTransferSheet.departmentKey(WaDepartment.payments)),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(WaTransferSheet.agentKey('s3')));
          await tester.enterText(
            find.byKey(WaTransferSheet.noteKey),
            ar ? 'دفع للوكيل ولم يصل الشحن' : 'Paid the agent, no top-up yet',
          );
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pumpAndSettle();
          await precacheImages(tester);
        });
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('png/whatsapp.transfer_sheet.$name.$label.png'),
        );
        await end(tester);
      });

      testWidgets('whatsapp.transferred $name $label', (tester) async {
        final repo = FakeWaRepository(
          conversation: waConversation(
            unread: 0,
            department: WaDepartment.payments,
          ),
          messages: waMessages(ar: ar, reaction: false),
        );
        await pump(tester, repo);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('png/whatsapp.transferred.$name.$label.png'),
        );
        await end(tester);
      });
    }
  });
}
