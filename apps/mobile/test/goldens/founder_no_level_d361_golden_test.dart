// D361 (owner: «المؤسس ليس له ليفيل»): the founder's own levels page —
// decision, the neutral state instead of his levels.
//
//   levels.founder  «المؤسس ليس له مستوى»
//
// Arabic and English, dark and light, on the phone (393 × 852). Regenerate:
//   flutter test --update-goldens test/goldens/founder_no_level_d361_golden_test.dart
@Tags(['golden'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/features/levels/data/levels_repository.dart';
import 'package:kabso_live/features/levels/presentation/levels_screen.dart';
import 'package:kabso_live/features/owner_profile/data/owner_profile_repository.dart';
import 'package:material_ui/material_ui.dart';

import '../features/levels/levels_test.dart' show FakeLevelsRepository;
import '../helpers/golden.dart';
import '../helpers/pump_app.dart';

void main() {
  setUpAll(loadAppFonts);

  forEachLanguage((language) {
    final name = language.name;
    for (final (label, brightness) in [
      ('phone', Brightness.dark),
      ('phone.light', Brightness.light),
    ]) {
      testWidgets('levels.founder $name $label', (tester) async {
        await loadAppFonts();
        setViewport(tester, GoldenViewport.phone);
        await pumpScreen(
          tester,
          const LevelsScreen(),
          language: language,
          brightness: brightness,
          overrides: [
            levelsRepositoryProvider.overrideWithValue(FakeLevelsRepository()),
            isKabsoOwnerProvider.overrideWithValue(true),
          ],
        );
        await tester.pumpAndSettle();
        expect(find.byKey(LevelsScreen.founderKey), findsOneWidget);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('png/levels.founder.$name.$label.png'),
        );
      });
    }
  });
}
