// D360 (owner approved): the WhatsApp level per staff member — VIEW.
//
//   whatsapp.view_only  a conversation read by a staff member whose WhatsApp
//                       level is VIEW: «مشاهدة فقط» in the app bar instead of
//                       the actions, the note instead of the composer
//
// Arabic and English, dark and light, on the phone (393 × 852). A fixed clock;
// synthetic customers. Regenerate on Linux with the pinned Flutter:
//   flutter test --update-goldens test/goldens/whatsapp_d360_golden_test.dart
@Tags(['golden'])
library;

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/staff/application/staff_providers.dart';
import 'package:kabso_live/features/whatsapp/data/wa_repository.dart';
import 'package:kabso_live/features/whatsapp/presentation/wa_screens.dart';
import 'package:material_ui/material_ui.dart';

import '../features/whatsapp/wa_d360_test.dart'
    show FixedStaffStatus, d360Status, d360View;
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
      testWidgets('whatsapp.view_only $name $label', (tester) async {
        await loadAppFonts();
        setViewport(tester, GoldenViewport.phone);
        await withClock(Clock.fixed(d355Now), () async {
          await pumpScreen(
            tester,
            const WaChatScreen(conversationId: 'c1'),
            language: language,
            brightness: brightness,
            overrides: [
              waRepositoryProvider.overrideWithValue(
                FakeWaRepository(
                  conversation: waConversation(assignedTo: waMona, unread: 1),
                  messages: waMessages(ar: ar, reaction: false),
                ),
              ),
              staffStatusProvider.overrideWith(
                () => FixedStaffStatus(d360Status(d360View)),
              ),
            ],
          );
          await tester.pumpAndSettle();
          // D365: the avatars' default picture decoded before the shot
          // (the first shot of a run had none).
          await precacheImages(tester);
        });
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('png/whatsapp.view_only.$name.$label.png'),
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      });
    }
  });
}
