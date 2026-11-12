// D384 (the VIP animated picture «صورة متحركة», CONVENTIONS §10.173): the
// record / preview / save screen with a fake recorder (synthetic frames, no
// camera, no real face) and a fake API, and its entry in «الخاص بي VIP»
// for holders only.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/live/application/live_wallet_controller.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:kabso_live/features/profile/domain/profile_models.dart';
import 'package:kabso_live/features/vip/animated_avatar/animated_avatar_repository.dart';
import 'package:kabso_live/features/vip/animated_avatar/animated_avatar_screen.dart';
import 'package:kabso_live/features/vip/animated_avatar/cutout_frames.dart';
import 'package:kabso_live/features/vip/animated_avatar/cutout_recorder.dart';
import 'package:kabso_live/features/vip/animated_avatar/cutout_strip_player.dart';
import 'package:kabso_live/features/vip/application/vip_look.dart';
import 'package:kabso_live/features/vip/data/vip_repository.dart';
import 'package:kabso_live/features/vip/domain/animated_avatar.dart';
import 'package:kabso_live/features/vip/presentation/vip_cutout.dart';
import 'package:kabso_live/features/vip/presentation/vip_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../fixtures/vip/cutout_d384_fixtures.dart';
import '../../helpers/fake_profile_repository.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';
import '../bonds/bonds_harness.dart';
import 'vip_points_harness.dart' show FakePointsVip, PointsCoins;

/// A recorder that hands back synthetic frames (or fails as told).
class FakeCutoutRecorder implements CutoutRecorder {
  new({this.person = true, this.cameraFails = false});

  final bool person;
  final bool cameraFails;
  int opened = 0;
  int recorded = 0;

  @override
  Future<void> open() async {
    opened++;
    if (cameraFails) throw const CutoutCameraException();
  }

  @override
  Widget preview(BuildContext context) =>
      const ColoredBox(color: Color(0xFF223344));

  @override
  Future<List<CutoutFrame>> record({
    required void Function(double progress) onProgress,
  }) async {
    recorded++;
    onProgress(0.25);
    onProgress(1);
    return syntheticCutoutFrames(count: 12, person: person);
  }

  @override
  Future<void> close() async {}
}

/// The API: saves record the strip; removes counted.
class FakeAnimatedAvatarRepository implements AnimatedAvatarRepository {
  final List<Uint8List> saved = [];
  int removed = 0;
  AppFailure? failSave;

  @override
  Future<AnimatedAvatar> save(
    Uint8List strip, {
    void Function(double progress)? onProgress,
  }) async {
    if (failSave case final f?) throw f;
    saved.add(strip);
    return syntheticCutout;
  }

  @override
  Future<void> remove() async => removed++;
}

/// Pumps until [finder] shows, letting the engine's image work finish.
Future<void> settleUntil(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 100 && finder.evaluate().isEmpty; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  await tester.pump();
}

Future<FakeAnimatedAvatarRepository> pumpAnimatedAvatarScreen(
  WidgetTester tester, {
  FakeCutoutRecorder? recorder,
  AnimatedAvatar? current,
  AppLanguage language = AppLanguage.en,
  Brightness brightness = Brightness.light,
  FakeAnimatedAvatarRepository? repo,
}) async {
  final api = repo ?? FakeAnimatedAvatarRepository();
  setViewport(tester, GoldenViewport.phone);
  await pumpBonds(
    tester,
    const AnimatedAvatarScreen(),
    language: language,
    brightness: brightness,
    overrides: [
      cutoutRecorderProvider.overrideWithValue(
        recorder ?? FakeCutoutRecorder(),
      ),
      animatedAvatarRepositoryProvider.overrideWithValue(api),
      profileRepositoryProvider.overrideWithValue(
        FakeProfileRepository(
          apiProfile(isSelf: true).copyWith(animatedAvatar: current),
        ),
      ),
    ],
  );
  return api;
}

void main() {
  Uint8List? png;
  Future<void> serve(WidgetTester tester) async {
    final bytes = png ??= (await tester.runAsync(syntheticCutoutPng))!;
    animatedAvatarImageFor = (_) => MemoryImage(bytes);
  }

  tearDown(() => animatedAvatarImageFor = NetworkImage.new);

  group('D384 «صورة متحركة»', () {
    testWidgets('record → the cut-out previews over the checkerboard → save '
        'uploads one PNG strip', (tester) async {
      final recorder = FakeCutoutRecorder();
      final api = await pumpAnimatedAvatarScreen(tester, recorder: recorder);
      final en = l10nFor(AppLanguage.en);
      expect(find.byKey(AnimatedAvatarScreen.emptyKey), findsOneWidget);
      expect(find.text(en.vipAnimatedAvatarRecord), findsOneWidget);
      expect(find.byKey(AnimatedAvatarScreen.removeKey), findsNothing);
      await tester.tap(find.byKey(AnimatedAvatarScreen.recordKey));
      await settleUntil(tester, find.byKey(AnimatedAvatarScreen.previewKey));
      expect(recorder.opened, 1);
      expect(recorder.recorded, 1);
      expect(find.byKey(AnimatedAvatarScreen.previewKey), findsOneWidget);
      expect(find.text(en.vipAnimatedAvatarPreview), findsOneWidget);
      final player = tester.widget<CutoutStripPlayer>(
        find.byKey(AnimatedAvatarScreen.previewKey),
      );
      expect(player.frames, 12);
      expect(player.playing, isTrue);
      expect(find.text(en.vipAnimatedAvatarRerecord), findsOneWidget);

      await tester.tap(find.byKey(AnimatedAvatarScreen.saveKey));
      await settleUntil(tester, find.text(en.vipAnimatedAvatarSaved));
      expect(api.saved, hasLength(1));
      expect(api.saved.single.sublist(0, 4), [137, 80, 78, 71]);
      expect(api.saved.single.length, lessThanOrEqualTo(CutoutLimits.maxBytes));
      expect(find.text(en.vipAnimatedAvatarSaved), findsOneWidget);
      expect(find.byKey(AnimatedAvatarScreen.previewKey), findsNothing);
    });

    testWidgets('nobody in the clip: refused on the phone, nothing uploaded', (
      tester,
    ) async {
      final api = await pumpAnimatedAvatarScreen(
        tester,
        recorder: FakeCutoutRecorder(person: false),
      );
      await tester.tap(find.byKey(AnimatedAvatarScreen.recordKey));
      await settleUntil(tester, find.byKey(AnimatedAvatarScreen.errorKey));
      expect(
        find.text(l10nFor(AppLanguage.en).vipAnimatedAvatarNoPerson),
        findsOneWidget,
      );
      expect(find.byKey(AnimatedAvatarScreen.saveKey), findsNothing);
      expect(api.saved, isEmpty);
    });

    testWidgets('no camera: an honest message', (tester) async {
      await pumpAnimatedAvatarScreen(
        tester,
        recorder: FakeCutoutRecorder(cameraFails: true),
      );
      await tester.tap(find.byKey(AnimatedAvatarScreen.recordKey));
      await settleUntil(tester, find.byKey(AnimatedAvatarScreen.errorKey));
      expect(
        find.text(l10nFor(AppLanguage.en).vipAnimatedAvatarCameraError),
        findsOneWidget,
      );
    });

    testWidgets('the saved clip shows; «إزالة» removes it', (tester) async {
      await serve(tester);
      final api = await pumpAnimatedAvatarScreen(
        tester,
        current: syntheticCutout,
      );
      expect(find.byKey(AnimatedAvatarScreen.currentKey), findsOneWidget);
      await tester.tap(find.byKey(AnimatedAvatarScreen.removeKey));
      await tester.pumpAndSettle();
      expect(api.removed, 1);
      expect(
        find.text(l10nFor(AppLanguage.en).vipAnimatedAvatarRemoved),
        findsOneWidget,
      );
    });

    testWidgets('the server refuses (no perk): its message, the preview kept', (
      tester,
    ) async {
      final repo = FakeAnimatedAvatarRepository()
        ..failSave = const ServerFailure(
          code: ErrorCode.vipUnavailable,
          rawCode: 'VIP_UNAVAILABLE',
          debugMessage: 'no_perk',
        );
      await pumpAnimatedAvatarScreen(tester, repo: repo);
      await tester.tap(find.byKey(AnimatedAvatarScreen.recordKey));
      await settleUntil(tester, find.byKey(AnimatedAvatarScreen.previewKey));
      await tester.tap(find.byKey(AnimatedAvatarScreen.saveKey));
      // The preview keeps playing: pump frames, not until settled.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(repo.saved, isEmpty);
      expect(
        find.text(l10nFor(AppLanguage.en).errorVipUnavailable),
        findsOneWidget,
      );
      expect(find.byKey(AnimatedAvatarScreen.previewKey), findsOneWidget);
    });

    testWidgets('reduced motion: the preview shows its first frame only', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await pumpAnimatedAvatarScreen(tester);
      await tester.tap(find.byKey(AnimatedAvatarScreen.recordKey));
      await settleUntil(tester, find.byKey(AnimatedAvatarScreen.previewKey));
      final player = tester.widget<CutoutStripPlayer>(
        find.byKey(AnimatedAvatarScreen.previewKey),
      );
      expect(player.playing, isFalse);
    });
  });

  group('D384 the entry in «الخاص بي VIP»', () {
    VipTierList list({required bool perk}) => VipTierList(
      tiers: [
        VipTier(
          id: 'id-VIP_1',
          code: 'VIP_1',
          name: 'VIP 1',
          level: 1,
          color: 0xFF2E8B3D,
          priceCoins: 1000000,
          durationDays: 30,
          perks: [
            const VipPerk(code: 'BADGE', title: 'Badge', available: true),
            if (perk)
              const VipPerk(
                code: VipPerks.animatedAvatar,
                title: 'Animated picture',
                available: true,
              ),
          ],
        ),
      ],
      maxAheadDays: 400,
    );
    final membership = VipMembership(
      tierId: 'id-VIP_1',
      tierCode: 'VIP_1',
      tierName: 'VIP 1',
      tierColor: 0xFF2E8B3D,
      onSale: true,
      startedAt: DateTime.now().subtract(const Duration(days: 3)),
      expiresAt: DateTime.now().add(const Duration(days: 27)),
      daysLeft: 27,
    );

    for (final perk in [true, false]) {
      testWidgets('holder: ${perk ? 'shown, opens the screen' : 'none'}', (
        tester,
      ) async {
        setViewport(tester, GoldenViewport.phone);
        final f = await pumpBonds(
          tester,
          const VipScreen(),
          overrides: [
            vipRepositoryProvider.overrideWithValue(
              FakePointsVip(
                list: list(perk: perk),
                membership: membership,
              ),
            ),
            liveCoinsProvider.overrideWith(() => PointsCoins(5000000)),
          ],
        );
        await tester.tap(find.byKey(VipScreen.statusKey));
        await tester.pumpAndSettle();
        expect(
          find.byKey(VipScreen.animatedAvatarKey),
          perk ? findsOneWidget : findsNothing,
        );
        if (perk) {
          await tester.tap(find.byKey(VipScreen.animatedAvatarKey));
          await tester.pumpAndSettle();
          expect(f.visited, contains('/vip/animated-avatar'));
        }
      });
    }
  });

  test('PublicProfile carries the clip only as the server sends it', () {
    final p = PublicProfile.fromJson({
      ...publicProfileJson(),
      'vip': {'tier': 'VIP_1', 'rank': 1, 'color': '#2E8B3D'},
      'animatedAvatar': syntheticCutout.toJson(),
    });
    expect(p.animatedAvatar?.url, syntheticCutoutUrl);
    expect(p.vip, const UserVip(tier: 'VIP_1', rank: 1, color: 0xFF2E8B3D));
  });
}
