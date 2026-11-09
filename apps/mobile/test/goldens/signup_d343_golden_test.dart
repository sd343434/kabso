// D343 (owner): «تصميم صفحة انشاء الحساب بشكل ابسط وازالة كابي من الصفحة».
//
//   signup.empty      the simpler sign-up page (no Kabi), the code field
//                     collapsed under «لديك رمز دعوة؟»
//   signup.prefilled  the code from the invite link (Play install referrer):
//                     «رمز المشرف Kabso07», the note and «إزالة الرمز»
//   signup.error      the 400 `not_found` after «إنشاء الحساب» on the field
//   recruits.signup_link  the supervisor's «رابطك الشخصي» card
//
// Each in Arabic and English, dark and light; 393 × 852 @3x with the status
// bar 59 and the home indicator 34. Regenerate on Linux with the pinned
// Flutter:
//   flutter test --update-goldens test/goldens/signup_d343_golden_test.dart
@Tags(['golden'])
library;

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/auth/presentation/register_screen.dart';
import 'package:kabso_live/features/recruits/data/recruits_repository.dart';
import 'package:kabso_live/features/recruits/presentation/staff_recruits_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../features/auth/signup_code_d343_test.dart';
import '../features/recruits/recruits_d285_test.dart';
import '../helpers/fakes.dart';
import '../helpers/golden.dart';
import '../helpers/pump_app.dart';

Future<void> _phone(WidgetTester tester) async {
  await loadAppFonts();
  setViewport(tester, GoldenViewport.phone);
  tester.view.padding = const FakeViewPadding(
    top: 59 * GoldenViewport.pixelRatio,
    bottom: 34 * GoldenViewport.pixelRatio,
  );
  addTearDown(tester.view.resetPadding);
}

void main() {
  setUpAll(loadAppFonts);

  forEachLanguage((language) {
    final name = language.name;
    final ar = language == AppLanguage.ar;
    for (final brightness in Brightness.values) {
      final theme = brightness.name;

      testWidgets('signup.empty $name $theme', (tester) async {
        await _phone(tester);
        await pumpSignup(tester, language: language, brightness: brightness);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('png/signup.empty.$name.$theme.phone.png'),
        );
      });

      testWidgets('signup.prefilled $name $theme', (tester) async {
        await _phone(tester);
        await pumpSignup(
          tester,
          language: language,
          brightness: brightness,
          referrer: 'kabso_code=Kabso07',
        );
        await tester.ensureVisible(find.byKey(RegisterScreen.referralKey));
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('png/signup.prefilled.$name.$theme.phone.png'),
        );
      });

      testWidgets('signup.error $name $theme', (tester) async {
        await _phone(tester);
        final repo = FakeAuthRepository()
          ..registerFailure = const ServerFailure(
            code: ErrorCode.validationFailed,
            rawCode: 'VALIDATION_FAILED',
            debugMessage: 'not found',
            details: [FieldIssue(field: 'referralCode', issue: 'not_found')],
          );
        await pumpSignup(
          tester,
          repo: repo,
          language: language,
          brightness: brightness,
          codes: FakeSignupCodeRepository(fail: true),
        );
        await tester.enterText(
          find.byKey(RegisterScreen.emailKey),
          'layla@example.com',
        );
        await tester.enterText(
          find.byKey(RegisterScreen.usernameKey),
          'layla_22',
        );
        await tester.enterText(
          find.byKey(RegisterScreen.displayNameKey),
          ar ? 'ليلى' : 'Layla',
        );
        await tester.enterText(
          find.byKey(RegisterScreen.passwordKey),
          'pa55word!long',
        );
        await chooseGender(tester);
        await tapVisible(tester, find.byKey(RegisterScreen.referralToggleKey));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(RegisterScreen.referralKey),
          'Kabso77',
        );
        await tester.pump(const Duration(milliseconds: 350));
        await tapVisible(tester, find.byKey(RegisterScreen.submitKey));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(RegisterScreen.referralKey));
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('png/signup.error.$name.$theme.phone.png'),
        );
      });
    }

    testWidgets('recruits.signup_link $name', (tester) async {
      await _phone(tester);
      final base = recruitsFixture(ar: ar);
      await withClock(Clock.fixed(d285Now), () async {
        await pumpScreen(
          tester,
          const StaffRecruitsScreen(),
          language: language,
          overrides: [
            recruitsRepositoryProvider.overrideWithValue(
              FakeRecruitsRepository(
                recruits: StaffRecruitList(
                  counts: base.counts,
                  recruits: base.recruits,
                  signupCode: 'Kabso07',
                  signupLink: 'https://kabsolive.com/i/Kabso07',
                  signupsGranted: 12,
                  signupsWithheld: 3,
                ),
              ),
            ),
          ],
        );
        await precacheImages(tester);
        await tester.pumpAndSettle();
      });
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('png/recruits.signup_link.$name.phone.png'),
      );
    });
  });
}
