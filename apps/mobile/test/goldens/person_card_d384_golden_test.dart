// D384 (owner 2026-11-12: «انتبه جيداً لطريقة الصورة شخصية»; CONVENTIONS
// §10.173): the VIP animated picture «صورة متحركة», 393×852 (insets 59 /
// 34), the clock pinned, Arabic and English, light and dark. Tests never
// animate: the cut-out shows its still. The picture is a synthetic drawn
// stand-in (test/fixtures/vip/cutout_d384_fixtures.dart; no real face).
//
//   person_card_d384.cutout          the person card over the real audio
//                                    room, the cut-out in the photo's circle
//                                    (owner: «بإطار دائري بنفس حجم الإطار
//                                    السابق»)
//   person_card_d384.cutout_vip_art  the same over the D383 VIP background
//   animated_avatar_d384.preview     «صورة متحركة» after recording: the
//                                    cut-out previewed over the checkerboard
//   animated_avatar_d384.trim        a video picked from the gallery: its
//                                    frame, the start slider at 0:04.2 and
//                                    the kept 3 s (owner: «both»)
//
// Regenerate on Linux with the pinned Flutter:
//   flutter test --update-goldens test/goldens/person_card_d384_golden_test.dart
@Tags(['golden'])
library;

import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_person_card.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:kabso_live/features/vip/animated_avatar/animated_avatar_repository.dart';
import 'package:kabso_live/features/vip/animated_avatar/animated_avatar_screen.dart';
import 'package:kabso_live/features/vip/animated_avatar/cutout_frames.dart';
import 'package:kabso_live/features/vip/animated_avatar/cutout_gallery.dart';
import 'package:kabso_live/features/vip/animated_avatar/cutout_recorder.dart';
import 'package:kabso_live/features/vip/application/vip_look.dart';
import 'package:kabso_live/features/vip/data/vip_repository.dart';
import 'package:kabso_live/features/vip/presentation/vip_cutout.dart';
import 'package:kabso_live/features/vip/presentation/vip_parts.dart';
import 'package:material_ui/material_ui.dart';

import '../features/live/person_card_d383_test.dart' show cardCatalog;
import '../features/vip/animated_avatar_screen_d384_test.dart'
    show
        FakeAnimatedAvatarRepository,
        FakeCutoutGallery,
        FakeCutoutRecorder,
        settleUntil;
import '../fixtures/live/live_api_fixtures.dart';
import '../fixtures/vip/cutout_d384_fixtures.dart';
import '../helpers/fake_profile_repository.dart';
import '../helpers/fakes.dart';
import '../helpers/golden.dart';
import '../helpers/pump_app.dart';
import 'live_person_card_golden_test.dart'
    show personCardProfile, pumpPersonCardRoom;

final _now = DateTime.utc(2026, 11, 12, 12);

const _vip = UserVip(tier: 'VIP_1', rank: 1, color: 0xFF2E8B3D);

void main() {
  Uint8List? png;

  setUp(() {
    vipImageFor = (_) => const AssetImage('assets/live_themes/galaxy.webp');
  });
  tearDown(() {
    vipImageFor = NetworkImage.new;
    animatedAvatarImageFor = NetworkImage.new;
  });

  Future<void> serve(WidgetTester tester) async {
    final bytes = png ??= (await tester.runAsync(syntheticCutoutPng))!;
    animatedAvatarImageFor = (_) => MemoryImage(bytes);
  }

  final variants = <String, VipTierList?>{
    'cutout': null,
    'cutout_vip_art': cardCatalog(
      value: '#1E2A44',
      still: 'https://cdn.test/vip/card_bg.png',
      animation: 'https://cdn.test/vip/card_bg.svga',
    ),
  };

  for (final MapEntry(key: variant, value: catalog) in variants.entries) {
    for (final language in AppLanguage.values) {
      for (final brightness in Brightness.values) {
        // The VIP background variant once (ar dark): the card the owner sees.
        if (catalog != null &&
            (language != AppLanguage.ar || brightness != Brightness.dark)) {
          continue;
        }
        testWidgets('person_card_d384.$variant ${language.name} '
            '${brightness.name}', (tester) async {
          await serve(tester);
          await withClock(Clock.fixed(_now), () async {
            await pumpPersonCardRoom(
              tester,
              language: language,
              brightness: brightness,
              profile: personCardProfile(ar: language == AppLanguage.ar)
                  .copyWith(vip: _vip, animatedAvatar: syntheticCutout),
              extraOverrides: [
                vipCatalogProvider.overrideWith((ref) async => catalog),
              ],
            );
            expect(find.byKey(LivePersonSheet.cutoutKey), findsOneWidget);
            expect(find.byKey(VipCutout.stillKey), findsOneWidget);
            expect(find.byKey(VipCutout.fallbackKey), findsNothing);
            await expectLater(
              find.byType(MaterialApp),
              matchesGoldenFile(
                'png/person_card_d384.$variant.${language.name}'
                '.${brightness.name}.phone.png',
              ),
            );
          });
        });
      }
    }
  }

  for (final language in AppLanguage.values) {
    for (final brightness in Brightness.values) {
      testWidgets('animated_avatar_d384.preview ${language.name} '
          '${brightness.name}', (tester) async {
        await withClock(Clock.fixed(_now), () async {
          await loadAppFonts();
          setViewport(tester, GoldenViewport.phone);
          tester.view.padding = const FakeViewPadding(
            top: 59 * GoldenViewport.pixelRatio,
            bottom: 34 * GoldenViewport.pixelRatio,
          );
          addTearDown(tester.view.resetPadding);
          await pumpScreen(
            tester,
            const AnimatedAvatarScreen(),
            language: language,
            brightness: brightness,
            disableAnimations: true,
            overrides: [
              currentUserProvider.overrideWithValue(testUser()),
              cutoutRecorderProvider.overrideWithValue(_BustRecorder()),
              animatedAvatarRepositoryProvider.overrideWithValue(
                FakeAnimatedAvatarRepository(),
              ),
              profileRepositoryProvider.overrideWithValue(
                FakeProfileRepository(apiProfile(isSelf: true)),
              ),
            ],
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(AnimatedAvatarScreen.recordKey));
          await settleUntil(
            tester,
            find.byKey(AnimatedAvatarScreen.previewKey),
          );
          await tester.pumpAndSettle();
          expect(find.byKey(AnimatedAvatarScreen.previewKey), findsOneWidget);
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
              'png/animated_avatar_d384.preview.${language.name}'
              '.${brightness.name}.phone.png',
            ),
          );
        });
      });
    }
  }

  for (final language in AppLanguage.values) {
    for (final brightness in Brightness.values) {
      testWidgets('animated_avatar_d384.trim ${language.name} '
          '${brightness.name}', (tester) async {
        final bytes = (await tester.runAsync(syntheticCutoutPng))!;
        await withClock(Clock.fixed(_now), () async {
          await loadAppFonts();
          setViewport(tester, GoldenViewport.phone);
          tester.view.padding = const FakeViewPadding(
            top: 59 * GoldenViewport.pixelRatio,
            bottom: 34 * GoldenViewport.pixelRatio,
          );
          addTearDown(tester.view.resetPadding);
          await pumpScreen(
            tester,
            const AnimatedAvatarScreen(),
            language: language,
            brightness: brightness,
            disableAnimations: true,
            overrides: [
              currentUserProvider.overrideWithValue(testUser()),
              cutoutRecorderProvider.overrideWithValue(FakeCutoutRecorder()),
              cutoutGalleryProvider.overrideWithValue(
                FakeCutoutGallery(poster: MemoryImage(bytes)),
              ),
              animatedAvatarRepositoryProvider.overrideWithValue(
                FakeAnimatedAvatarRepository(),
              ),
              profileRepositoryProvider.overrideWithValue(
                FakeProfileRepository(apiProfile(isSelf: true)),
              ),
            ],
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(AnimatedAvatarScreen.pickKey));
          await tester.pumpAndSettle();
          tester
              .widget<Slider>(find.byKey(AnimatedAvatarScreen.trimSliderKey))
              .onChanged!(4200);
          await tester.pumpAndSettle();
          await precacheImages(tester);
          expect(find.byKey(AnimatedAvatarScreen.trimKey), findsOneWidget);
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
              'png/animated_avatar_d384.trim.${language.name}'
              '.${brightness.name}.phone.png',
            ),
          );
        });
      });
    }
  }
}

/// The fake recorder's frames, drawn as the stand-in bust (so the preview
/// golden shows a person-like cut-out, still synthetic).
class _BustRecorder extends FakeCutoutRecorder {
  @override
  Future<List<CutoutFrame>> record({
    required void Function(double progress) onProgress,
  }) async => syntheticBustFrames();
}
