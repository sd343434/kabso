// D355 (owner): «واتساب» — the staff's WhatsApp inbox on the phone.
//
//   whatsapp.inbox          the list: unread, with me / with someone / closed
//   whatsapp.chat           a conversation inside the 24-hour window: bubbles,
//                           ticks (read / failed), a voice note, a refused
//                           file type, a reaction, the composer
//   whatsapp.window_closed  outside the window: the banner and only
//                           «إرسال قالب»
//
// Arabic and English, dark and light, on the phone (393 × 852). A fixed clock;
// synthetic customers. Regenerate on Linux with the pinned Flutter:
//   flutter test --update-goldens test/goldens/whatsapp_d355_golden_test.dart
@Tags(['golden'])
library;

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/whatsapp/data/wa_repository.dart';
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
      Future<void> shot(
        WidgetTester tester,
        Widget screen,
        FakeWaRepository repo,
        String file,
      ) async {
        await loadAppFonts();
        setViewport(tester, GoldenViewport.phone);
        await withClock(Clock.fixed(d355Now), () async {
          await pumpScreen(
            tester,
            screen,
            language: language,
            brightness: brightness,
            overrides: [waRepositoryProvider.overrideWithValue(repo)],
          );
          await tester.pumpAndSettle();
        });
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('png/$file.$name.$label.png'),
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      }

      testWidgets('whatsapp.inbox $name $label', (tester) async {
        await shot(
          tester,
          const WaInboxScreen(),
          FakeWaRepository(
            list: [
              waConversation(),
              waConversation(
                id: 'c2',
                name: null,
                unread: 0,
                assignedTo: waMe,
                assignedToMe: true,
                preview: ar ? 'شكراً لكم' : 'Thank you',
              ),
              waConversation(
                id: 'c3',
                name: ar ? 'ليلى' : 'Layla',
                unread: 1,
                assignedTo: waMona,
                preview: ar ? 'متى يصل الشحن؟' : 'When does the top-up arrive?',
              ),
              waConversation(
                id: 'c4',
                name: 'Omar',
                open: false,
                unread: 0,
                preview: ar ? 'رسالة صوتية' : 'Voice message',
              ),
            ],
          ),
          'whatsapp.inbox',
        );
      });

      testWidgets('whatsapp.chat $name $label', (tester) async {
        await shot(
          tester,
          const WaChatScreen(conversationId: 'c1'),
          FakeWaRepository(
            conversation: waConversation(
              assignedTo: waMe,
              assignedToMe: true,
              unread: 0,
            ),
            messages: waMessages(ar: ar, reaction: false),
          ),
          'whatsapp.chat',
        );
      });

      testWidgets('whatsapp.window_closed $name $label', (tester) async {
        await shot(
          tester,
          const WaChatScreen(conversationId: 'c1'),
          FakeWaRepository(
            conversation: waConversation(
              windowOpen: false,
              assignedTo: waMe,
              assignedToMe: true,
              unread: 0,
            ),
            messages: waMessages(ar: ar, reaction: false).sublist(2),
          ),
          'whatsapp.window_closed',
        );
      });
    }
  });
}
