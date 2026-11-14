// D290 (owner): «طلب رفع ليفيل» in the staff Me tab.
//
//   level_raise.list   «طلبات رفع الليفيل»: pending, approved (the level) and
//                      rejected (the reason; "other" with its typed name)
//   level_raise.form   the form filled in: the checked supporter (recharge,
//                      levels, "not approvable yet"), Zafa with «مؤكد», the
//                      ID and level (the top of the form, as it opens)
//   level_raise.form_suggest    "other" with «زفه» / "zafa" typed: «هل تقصد:
//                               زفة؟ · مؤكد» (the follow-up, phone, dark)
//   level_raise.form_duplicate  sending a source account already approved:
//                               409 LEVEL_RAISE_DUPLICATE worded with the
//                               status, date and staff member (phone, dark)
//
// Each in Arabic and English, dark and light, on the phone (393 × 852 with
// the status bar 59 and the home indicator 34), and on the Android check
// size (360 × 800) at text scale 1.3. A fixed clock. Regenerate on Linux
// with the pinned Flutter:
//   flutter test --update-goldens test/goldens/level_raise_d290_golden_test.dart
@Tags(['golden'])
library;

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/level_raise/data/level_raise_repository.dart';
import 'package:kabso_live/features/level_raise/presentation/level_raise_screens.dart';
import 'package:kabso_live/features/posts/data/media_repository.dart';
import 'package:kabso_live/features/posts/data/video_source.dart';
import 'package:material_ui/material_ui.dart';

import '../features/level_raise/level_raise_d290_test.dart';
import '../helpers/fake_media_repository.dart';
import '../helpers/golden.dart';
import '../helpers/pump_app.dart';

Future<void> _view(WidgetTester tester, GoldenViewport viewport) async {
  await loadAppFonts();
  setViewport(tester, viewport);
  tester.view.padding = const FakeViewPadding(
    top: 59 * GoldenViewport.pixelRatio,
    bottom: 34 * GoldenViewport.pixelRatio,
  );
  addTearDown(tester.view.resetPadding);
}

/// [child] at text scale [scale].
class _Scaled extends StatelessWidget {
  const new({required this.scale, required this.child});

  final double scale;
  final Widget child;

  @override
  Widget build(BuildContext context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child,
  );
}

void main() {
  setUpAll(loadAppFonts);

  const variants = [
    ('phone', GoldenViewport.phone, Brightness.dark, 1.0),
    ('phone.light', GoldenViewport.phone, Brightness.light, 1.0),
    ('android.x1_3', GoldenViewport.android, Brightness.dark, 1.3),
  ];

  forEachLanguage((language) {
    final ar = language == AppLanguage.ar;
    final name = language.name;

    for (final (label, viewport, brightness, scale) in variants) {
      testWidgets('level_raise.list $name $label', (tester) async {
        await _view(tester, viewport);
        await withClock(Clock.fixed(d290Now), () async {
          await pumpScreen(
            tester,
            _Scaled(scale: scale, child: const StaffLevelRaisesScreen()),
            language: language,
            brightness: brightness,
            overrides: [
              levelRaiseRepositoryProvider.overrideWithValue(
                FakeLevelRaiseRepository(requests: requestsFixture(ar: ar)),
              ),
            ],
          );
          await tester.pumpAndSettle();
        });
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('png/level_raise.list.$name.$label.png'),
        );
      });

      testWidgets('level_raise.form $name $label', (tester) async {
        await _view(tester, viewport);
        await withClock(Clock.fixed(d290Now), () async {
          await pumpScreen(
            tester,
            _Scaled(scale: scale, child: const LevelRaiseFormScreen()),
            language: language,
            brightness: brightness,
            overrides: [
              levelRaiseRepositoryProvider.overrideWithValue(
                FakeLevelRaiseRepository(checkResult: checkFixture(ar: ar)),
              ),
              mediaRepositoryProvider.overrideWithValue(FakeMediaRepository()),
              videoPickerProvider.overrideWithValue(
                FakeVideoPicker(testVideo(seconds: 25)),
              ),
            ],
          );
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byKey(LevelRaiseFormScreen.usernameKey),
            'abu.fahad',
          );
          await tester.pump();
          await tester.tap(find.byKey(LevelRaiseFormScreen.checkKey));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(LevelRaiseFormScreen.appKey));
          await tester.pumpAndSettle();
          await tester.tap(
            find.text(ar ? 'زفة · مؤكد' : 'Zafa · Confirmed').last,
          );
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byKey(LevelRaiseFormScreen.accountKey),
            '88123456',
          );
          await tester.enterText(
            find.byKey(LevelRaiseFormScreen.levelKey),
            '32',
          );
          await tester.pumpAndSettle();
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pumpAndSettle();
        });
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('png/level_raise.form.$name.$label.png'),
        );
      });
    }

    testWidgets('level_raise.form_suggest $name', (tester) async {
      await _view(tester, GoldenViewport.phone);
      await withClock(Clock.fixed(d290Now), () async {
        await pumpScreen(
          tester,
          const LevelRaiseFormScreen(),
          language: language,
          overrides: [
            levelRaiseRepositoryProvider.overrideWithValue(
              FakeLevelRaiseRepository(checkResult: checkFixture(ar: ar)),
            ),
          ],
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(LevelRaiseFormScreen.appKey));
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(ar ? 'تطبيق آخر · تقدير' : 'Other app · Estimate').last,
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(LevelRaiseFormScreen.otherNameKey),
          ar ? 'زفه' : 'zafa',
        );
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
      });
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('png/level_raise.form_suggest.$name.phone.png'),
      );
    });

    testWidgets('level_raise.form_duplicate $name', (tester) async {
      await _view(tester, GoldenViewport.phone);
      await withClock(Clock.fixed(d290Now), () async {
        await pumpScreen(
          tester,
          const LevelRaiseFormScreen(),
          language: language,
          overrides: [
            levelRaiseRepositoryProvider.overrideWithValue(
              FakeLevelRaiseRepository(
                checkResult: checkFixture(ar: ar, eligible: true),
                createError: duplicateFailure,
              ),
            ),
            mediaRepositoryProvider.overrideWithValue(FakeMediaRepository()),
            videoPickerProvider.overrideWithValue(
              FakeVideoPicker(testVideo(seconds: 25)),
            ),
          ],
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(LevelRaiseFormScreen.usernameKey),
          'abu.fahad',
        );
        await tester.pump();
        await tester.tap(find.byKey(LevelRaiseFormScreen.checkKey));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(LevelRaiseFormScreen.appKey));
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(ar ? 'زفة · مؤكد' : 'Zafa · Confirmed').last,
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(LevelRaiseFormScreen.accountKey),
          '88123456',
        );
        await tester.enterText(find.byKey(LevelRaiseFormScreen.levelKey), '32');
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(LevelRaiseFormScreen.videoKey));
        await tester.tap(find.byKey(LevelRaiseFormScreen.videoKey));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(LevelRaiseFormScreen.sendKey));
        await tester.tap(find.byKey(LevelRaiseFormScreen.sendKey));
        await tester.pumpAndSettle();
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
      });
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('png/level_raise.form_duplicate.$name.phone.png'),
      );
    });
  });
}
