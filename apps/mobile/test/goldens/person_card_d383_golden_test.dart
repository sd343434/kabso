// D383 (owner 2026-11-12: no box or frame around the person card; the
// earlier layout kept, «ارى ان شكل البطاقة السابقة اجمل»; the VIP
// PROFILE_CARD perk is its background): the person card over the real audio
// room at 393×852 (insets 59 / 34), the clock pinned, Arabic and English,
// light and dark:
//
//   person_card_d383.plain        the earlier card (everyone without the perk)
//   person_card_d383.vip_color    a VIP whose PROFILE_CARD is a colour
//   person_card_d383.vip_art      a VIP whose PROFILE_CARD is an art (its
//                                 still: tests never animate), under a scrim
//
// Regenerate on Linux with the pinned Flutter:
//   flutter test --update-goldens test/goldens/person_card_d383_golden_test.dart
@Tags(['golden'])
library;

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_person_card.dart';
import 'package:kabso_live/features/vip/application/vip_look.dart';
import 'package:kabso_live/features/vip/data/vip_repository.dart';
import 'package:kabso_live/features/vip/presentation/vip_parts.dart';
import 'package:material_ui/material_ui.dart';

import '../features/live/person_card_d383_test.dart' show cardCatalog;
import 'live_person_card_golden_test.dart'
    show personCardProfile, pumpPersonCardRoom;

final _now = DateTime.utc(2026, 11, 12, 12);

const _vip = UserVip(tier: 'VIP_1', rank: 1, color: 0xFF2E8B3D);

void main() {
  setUp(() {
    // The hosted art's stand-in: Kabso's own theme art (bundled).
    vipImageFor = (_) => const AssetImage('assets/live_themes/galaxy.webp');
  });
  tearDown(() => vipImageFor = NetworkImage.new);

  final variants = <String, VipTierList?>{
    'plain': null,
    'vip_color': cardCatalog(value: '#1E2A44'),
    'vip_art': cardCatalog(
      value: '#1E2A44',
      still: 'https://cdn.test/vip/card_bg.png',
      animation: 'https://cdn.test/vip/card_bg.svga',
    ),
  };

  for (final MapEntry(key: variant, value: catalog) in variants.entries) {
    for (final language in AppLanguage.values) {
      for (final brightness in Brightness.values) {
        testWidgets('person_card_d383.$variant ${language.name} '
            '${brightness.name}', (tester) async {
          await withClock(Clock.fixed(_now), () async {
            final ar = language == AppLanguage.ar;
            await pumpPersonCardRoom(
              tester,
              language: language,
              brightness: brightness,
              profile: personCardProfile(ar: ar)
                  .copyWith(vip: catalog == null ? null : _vip),
              extraOverrides: [
                vipCatalogProvider.overrideWith((ref) async => catalog),
              ],
            );
            expect(
              find.byKey(LivePersonSheet.vipCardKey),
              variant == 'vip_art' ? findsOneWidget : findsNothing,
            );
            await expectLater(
              find.byType(MaterialApp),
              matchesGoldenFile(
                'png/person_card_d383.$variant.${language.name}'
                '.${brightness.name}.phone.png',
              ),
            );
          });
        });
      }
    }
  }
}
