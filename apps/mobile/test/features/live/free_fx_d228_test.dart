// D228: the free camera effects engine (ML Kit + MediaPipe) beside DeepAR —
// the engine switch (server `cameraFxEngine`, the debug override), what
// reaches the native processor, Magic per engine, the diagnostics overlay.
// The native stage itself is covered by the plugin's Kotlin tests
// (FreeFxRulesTest); fps, quality, memory and heat need a phone.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_camera_fx/kabso_camera_fx.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/application/live_fx_engine_providers.dart';
import 'package:kabso_live/features/live/application/live_host_controller.dart';
import 'package:kabso_live/features/live/data/beauty/live_ar_effect.dart';
import 'package:kabso_live/features/live/data/beauty/live_beauty.dart';
import 'package:kabso_live/features/live/data/beauty/live_camera_fx.dart';
import 'package:kabso_live/features/live/data/beauty/live_fx_engine.dart';
import 'package:kabso_live/features/live/data/live_blocked_words_repository.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/data/live_schedule_repository.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/go_live_screen.dart';
import 'package:kabso_live/features/live/presentation/go_live/go_live_parts.dart';
import 'package:kabso_live/features/live/presentation/live_fx_diagnostics.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_live_blocked_words_repository.dart';
import '../../helpers/fake_live_media_engine.dart';
import '../../helpers/fake_live_repository.dart';
import '../../helpers/fake_live_schedule_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

/// Records what reaches the native processor.
class _Bridge implements KabsoCameraFx {
  final List<String> calls = [];
  KabsoFreeFx? free;

  @override
  bool get isSupported => true;

  @override
  Future<bool> attach(String trackId) async {
    calls.add('attach:$trackId');
    return true;
  }

  @override
  Future<void> setColorMatrix(List<double>? matrix) async =>
      calls.add(matrix == null ? 'color:none' : 'color:${matrix.length}');

  @override
  Future<bool> setLicenseKey(String key) async {
    calls.add('licence');
    return true;
  }

  @override
  Future<void> setEffect(String? effect) async =>
      calls.add('effect:${effect ?? 'none'}');

  @override
  Future<void> setEngine(KabsoCameraFxEngine engine) async =>
      calls.add('engine:${engine.wire}');

  @override
  Future<void> setFreeFx(KabsoFreeFx fx) async {
    free = fx;
    calls.add('free');
  }

  @override
  Future<void> release({String? trackId}) async => calls.add('release');

  final StreamController<KabsoCameraFxStatus> native =
      StreamController.broadcast(sync: true);

  @override
  Stream<KabsoCameraFxStatus> get statusChanges => native.stream;

  @override
  Future<KabsoCameraFxDiagnostics?> diagnostics() async => null;
}

const _blur = LiveBeauty(effect: LiveArEffect.backgroundBlur);

Future<(FakeLiveRepository, FakeLiveMediaEngine)> _pumpGoLive(
  WidgetTester tester, {
  String serverEngine = 'DEEPAR',
  FakeLiveMediaEngine? engine,
  AppLanguage language = AppLanguage.en,
  GoldenViewport viewport = GoldenViewport.phone,
}) async {
  final repo = FakeLiveRepository()..cameraFxEngine = serverEngine;
  final camera =
      engine ??
      (FakeLiveMediaEngine()
        ..supportsFilters = true
        ..arSupport = LiveArSupport.ready);
  setViewport(tester, viewport);
  await tester.pumpWidget(const SizedBox.shrink());
  await pumpScreen(
    tester,
    const GoLiveScreen(),
    language: language,
    liveMediaEngine: camera,
    overrides: [
      liveRepositoryProvider.overrideWithValue(repo),
      currentUserProvider.overrideWithValue(testUser().copyWith(canHost: true)),
      liveBlockedWordsRepositoryProvider.overrideWithValue(
        FakeLiveBlockedWordsRepository(),
      ),
      liveScheduleRepositoryProvider.overrideWithValue(
        FakeLiveScheduleRepository(),
      ),
    ],
  );
  await tester.pumpAndSettle();
  return (repo, camera);
}

Future<void> _leave(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(GoLiveScreen)));

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(GoLiveScreen)));

/// Opens Magic and waits for the sheet.
Future<void> _openMagic(WidgetTester tester) async {
  await tester.tap(find.byKey(GoLiveKeys.tool('magic')));
  await tester.pumpAndSettle();
}

void main() {
  group('the engine setting', () {
    test('the server value: FREE, else DeepAR (unknown and missing too)', () {
      expect(LiveFxEngine.parse('FREE'), LiveFxEngine.free);
      expect(LiveFxEngine.parse('DEEPAR'), LiveFxEngine.deepAr);
      expect(LiveFxEngine.parse('free'), LiveFxEngine.deepAr);
      expect(LiveFxEngine.parse(null), LiveFxEngine.deepAr);
      final older = LiveConfig.fromJson({
        'hostingEnabled': true,
        'heartbeatIntervalSeconds': 15,
        'heartbeatStaleAfterSeconds': 45,
      });
      expect(older.cameraFxEngine, 'DEEPAR');
      final free = LiveConfig.fromJson({
        'hostingEnabled': true,
        'heartbeatIntervalSeconds': 15,
        'heartbeatStaleAfterSeconds': 45,
        'cameraFxEngine': 'FREE',
      });
      expect(LiveFxEngine.parse(free.cameraFxEngine), LiveFxEngine.free);
    });

    test('free beauty: 0 … 100 → 0 … 1, nothing while off, clamped', () {
      const off = LiveFreeBeauty();
      expect(off.on, isFalse);
      expect(off.smooth, LiveFreeBeauty.defaultStrength);
      expect(off.toNative(backgroundBlur: false).isNone, isTrue);
      final on = off.copyWith(on: true, eyes: 250, slim: -3);
      expect(on.eyes, 100);
      expect(on.slim, 0);
      expect(
        on.toNative(backgroundBlur: true),
        const KabsoFreeFx(
          backgroundBlur: true,
          smooth: 0.4,
          brighten: 0.4,
          eyes: 1,
        ),
      );
    });

    testWidgets('the go-live screen follows the server: FREE switches the '
        'camera to the free engine', (tester) async {
      final (_, camera) = await _pumpGoLive(tester, serverEngine: 'FREE');
      expect(camera.enginePicks, [LiveFxEngine.free]);
      expect(camera.fxEngine, LiveFxEngine.free);
      await _leave(tester);
    });

    testWidgets('DEEPAR (the default): nothing is switched', (tester) async {
      final (_, camera) = await _pumpGoLive(tester);
      expect(camera.enginePicks, isEmpty);
      expect(camera.fxEngine, LiveFxEngine.deepAr);
      await _leave(tester);
    });

    testWidgets('the developer override (debug/profile only) wins over the '
        'server, is kept on the phone and can be cleared', (tester) async {
      expect(LiveFxEngineOverride.available, isTrue, reason: 'a test build');
      final (_, camera) = await _pumpGoLive(tester);
      final container = _container(tester);
      await container
          .read(liveFxEngineOverrideProvider.notifier)
          .set(LiveFxEngine.free);
      await tester.pumpAndSettle();
      expect(camera.fxEngine, LiveFxEngine.free);
      final prefs = container.read(sharedPreferencesProvider);
      expect(prefs.getString(PreferenceKeys.debugCameraFxEngine), 'FREE');
      // A new go-live screen reads it back.
      container.invalidate(liveFxEngineOverrideProvider);
      expect(container.read(liveFxEngineOverrideProvider), LiveFxEngine.free);
      await container.read(liveFxEngineOverrideProvider.notifier).set(null);
      await tester.pumpAndSettle();
      expect(prefs.getString(PreferenceKeys.debugCameraFxEngine), isNull);
      expect(camera.fxEngine, LiveFxEngine.deepAr, reason: 'the server says');
      await _leave(tester);
    });
  });

  group('LiveCameraFx on the free engine', () {
    test('no licence needed; blur and beauty go to the free engine, DeepAR '
        'is never initialized', () async {
      final bridge = _Bridge();
      final fx = LiveCameraFx(bridge: bridge, licenseKey: '');
      expect(fx.effects, LiveArSupport.unlicensed);
      await fx.setEngine(LiveFxEngine.free);
      expect(fx.effects, LiveArSupport.ready);
      // The switch is sent at once (nothing picked yet: the free engine off).
      expect(bridge.calls, ['color:none', 'engine:free', 'free']);
      expect(bridge.free!.isNone, isTrue);
      await fx.update(_blur);
      await fx.attach('cam-1');
      expect(bridge.calls.skip(3), ['free', 'attach:cam-1']);
      expect(bridge.free, const KabsoFreeFx(backgroundBlur: true));

      await fx.update(
        _blur.copyWith(free: const LiveFreeBeauty(on: true, smooth: 70)),
      );
      expect(
        bridge.free,
        const KabsoFreeFx(
          backgroundBlur: true,
          smooth: 0.7,
          brighten: 0.4,
          slim: 0.4,
          eyes: 0.4,
        ),
      );
      // The same again: nothing sent.
      final sent = bridge.calls.length;
      await fx.update(
        _blur.copyWith(free: const LiveFreeBeauty(on: true, smooth: 70)),
      );
      expect(bridge.calls.length, sent);
      expect(bridge.calls, isNot(contains('licence')));
      expect(bridge.calls.where((c) => c.startsWith('effect:')), isEmpty);
    });

    test('back to DeepAR: the engine switches back and the effect goes to '
        'DeepAR again', () async {
      final bridge = _Bridge();
      final fx = LiveCameraFx(bridge: bridge, licenseKey: 'k');
      await fx.setEngine(LiveFxEngine.free);
      await fx.update(_blur);
      await fx.attach('cam-1');
      bridge.calls.clear();
      await fx.setEngine(LiveFxEngine.deepAr);
      expect(bridge.calls, [
        'engine:deepar',
        'licence',
        'effect:${KabsoCameraFxEffects.backgroundBlur}',
      ]);
    });

    test('release forgets the engine natively; the next attach sends it '
        'again', () async {
      final bridge = _Bridge();
      final fx = LiveCameraFx(bridge: bridge, licenseKey: '');
      await fx.setEngine(LiveFxEngine.free);
      await fx.update(_blur);
      await fx.attach('cam-1');
      await fx.release();
      bridge.calls.clear();
      await fx.attach('cam-2');
      expect(bridge.calls, [
        'attach:cam-2',
        'color:none',
        'engine:free',
        'free',
      ]);
    });

    test('DeepAR stays exactly as before: no engine call at all', () async {
      final bridge = _Bridge();
      final fx = LiveCameraFx(bridge: bridge, licenseKey: 'k');
      await fx.update(_blur);
      await fx.attach('cam-1');
      expect(bridge.calls, [
        'color:none',
        'licence',
        'effect:${KabsoCameraFxEffects.backgroundBlur}',
        'attach:cam-1',
      ]);
    });

    test('the free engine reports like DeepAR; too_slow and beauty '
        'unavailable have their own meaning', () async {
      final bridge = _Bridge();
      final fx = LiveCameraFx(bridge: bridge, licenseKey: '');
      await fx.setEngine(LiveFxEngine.free);
      await fx.update(_blur);
      await fx.attach('cam-1');
      bridge.native.add(
        const KabsoCameraFxStatus(
          KabsoCameraFxState.ready,
          'beauty_unavailable',
        ),
      );
      expect(fx.status.value.state, LiveArState.running);
      expect(fx.status.value.beautyUnavailable, isTrue);
      bridge.native.add(
        const KabsoCameraFxStatus(KabsoCameraFxState.disabled, 'too_slow'),
      );
      expect(fx.status.value.state, LiveArState.unavailable);
      expect(fx.status.value.problem, LiveArProblem.tooSlow);
      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(
        liveEffectStatusText(l10n, fx.status.value),
        l10n.liveEffectUnavailableSlow,
      );
    });

    test('the backstop waits longer for the free engine (the face model '
        'downloads on first use)', () {
      expect(
        LiveCameraFx.freeStartTimeout,
        greaterThan(LiveCameraFx.startTimeout),
      );
      expect(LiveCameraFx.freeStartTimeout.inSeconds, greaterThan(20));
    });
  });

  group('Magic per engine', () {
    testWidgets('DeepAR: the Effects section as before — no engine line, no '
        'Beauty', (tester) async {
      await _pumpGoLive(tester);
      await _openMagic(tester);
      final l10n = _l10n(tester);
      expect(find.text(l10n.liveEffectsTitle), findsOneWidget);
      expect(find.byKey(GoLiveKeys.effectsEngineFree), findsNothing);
      expect(find.byKey(GoLiveKeys.freeBeautyOn), findsNothing);
      await _leave(tester);
    });

    testWidgets('free: blur and Beauty; the sliders reach the camera', (
      tester,
    ) async {
      final (_, camera) = await _pumpGoLive(tester, serverEngine: 'FREE');
      await _openMagic(tester);
      final l10n = _l10n(tester);
      expect(find.byKey(GoLiveKeys.effectsEngineFree), findsOneWidget);
      expect(find.text(l10n.liveEffectsEngineFree), findsOneWidget);
      final blur = find.byKey(GoLiveKeys.effect(LiveArEffect.backgroundBlur));
      await tester.ensureVisible(blur);
      await tester.tap(blur);
      await tester.pumpAndSettle();
      expect(camera.beauty.effect, LiveArEffect.backgroundBlur);

      expect(find.byKey(GoLiveKeys.freeBeautySlider('smooth')), findsNothing);
      final on = find.byKey(GoLiveKeys.freeBeautyOn);
      await tester.ensureVisible(on);
      await tester.tap(on);
      await tester.pumpAndSettle();
      expect(camera.beauty.free.on, isTrue);
      expect(camera.beauty.free.smooth, 40, reason: 'default about 40');
      for (final kind in ['smooth', 'brighten', 'slim', 'eyes']) {
        expect(find.byKey(GoLiveKeys.freeBeautySlider(kind)), findsOneWidget);
      }
      // Drag «Bigger eyes» to the end: 100.
      final eyes = find.byKey(GoLiveKeys.freeBeautySlider('eyes'));
      await tester.ensureVisible(eyes);
      await tester.pumpAndSettle();
      await tester.drag(eyes, const Offset(600, 0));
      await tester.pumpAndSettle();
      expect(camera.beauty.free.eyes, 100);
      expect(camera.beauty.free.smooth, 40);
      // Magic's badge marks the beauty.
      expect(hostBadge(tester), isTrue);
      final off = find.byKey(GoLiveKeys.freeBeautyOff);
      await tester.ensureVisible(off);
      await tester.tap(off);
      await tester.pumpAndSettle();
      expect(camera.beauty.free.on, isFalse);
      expect(camera.beauty.free.eyes, 100, reason: 'kept for the next time');
      await _leave(tester);
    });

    testWidgets('free: the face model could not load — Beauty says why', (
      tester,
    ) async {
      final camera = FakeLiveMediaEngine()
        ..supportsFilters = true
        ..arSupport = LiveArSupport.ready;
      await _pumpGoLive(tester, serverEngine: 'FREE', engine: camera);
      camera.arStatusValue.value = const LiveArStatus(
        LiveArState.running,
        code: 'beauty_unavailable',
      );
      await _openMagic(tester);
      final l10n = _l10n(tester);
      final why = find.byKey(GoLiveKeys.freeBeautyUnavailable);
      await tester.ensureVisible(why);
      expect(why, findsOneWidget);
      expect(find.text(l10n.liveFreeBeautyUnavailable), findsOneWidget);
      await _leave(tester);
    });

    testWidgets('free: when the engine switches beauty off on the device, '
        'Magic shows it off', (tester) async {
      final (_, camera) = await _pumpGoLive(tester, serverEngine: 'FREE');
      final container = _container(tester);
      await container
          .read(liveHostControllerProvider.notifier)
          .setFreeBeauty(const LiveFreeBeauty(on: true));
      expect(camera.beauty.free.on, isTrue);
      camera.arStatusValue.value = const LiveArStatus(
        LiveArState.unavailable,
        problem: LiveArProblem.failed,
        code: 'model_unavailable',
      );
      await tester.pump();
      expect(
        container.read(liveHostControllerProvider).beauty.free.on,
        isFalse,
      );
      expect(camera.beauty.free.on, isFalse);
      await _leave(tester);
    });

    for (final language in [AppLanguage.ar, AppLanguage.en]) {
      testWidgets('free Magic in ${language.name} at 360 × 800, text 1.3: '
          'every slider reachable, nothing cut', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await _pumpGoLive(
          tester,
          serverEngine: 'FREE',
          language: language,
          viewport: GoldenViewport.android,
        );
        final container = _container(tester);
        await container
            .read(liveHostControllerProvider.notifier)
            .setFreeBeauty(const LiveFreeBeauty(on: true));
        await tester.pumpAndSettle();
        await _openMagic(tester);
        expect(tester.takeException(), isNull);
        final l10n = _l10n(tester);
        final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
        for (final kind in ['smooth', 'brighten', 'slim', 'eyes']) {
          final slider = find.byKey(GoLiveKeys.freeBeautySlider(kind));
          await tester.ensureVisible(slider);
          await tester.pumpAndSettle();
          final rect = tester.getRect(slider);
          expect(rect.bottom, lessThanOrEqualTo(screen.height));
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(screen.width));
          expect(rect.height, greaterThanOrEqualTo(40), reason: 'touch target');
        }
        for (final label in [
          l10n.liveFreeBeautySmooth,
          l10n.liveFreeBeautyBrighten,
          l10n.liveFreeBeautySlim,
          l10n.liveFreeBeautyEyes,
        ]) {
          expect(find.text(label), findsOneWidget);
        }
        // Reading order: the label at the start side, the value at the end.
        final label = tester.getRect(find.text(l10n.liveFreeBeautyEyes));
        final value = tester.getRect(
          find.descendant(
            of: find
                .ancestor(
                  of: find.text(l10n.liveFreeBeautyEyes),
                  matching: find.byType(Row),
                )
                .first,
            matching: find.text('40'),
          ),
        );
        if (language == AppLanguage.ar) {
          expect(label.center.dx, greaterThan(value.center.dx));
        } else {
          expect(label.center.dx, lessThan(value.center.dx));
        }
        expect(tester.takeException(), isNull);
        await _leave(tester);
      });
    }
  });

  group('the diagnostics overlay (debug/profile)', () {
    test("the free engine's lines: times against the budget, analysis, "
        'face and model', () {
      final lines = liveFxDiagnosticsLines(
        const KabsoCameraFxDiagnostics(
          status: KabsoCameraFxStatus(KabsoCameraFxState.ready),
          licencePresent: false,
          attached: true,
          fxEngine: 'free',
          framesIn: 300,
          framesOut: 288,
          timeouts: 12,
          frameMs: 14.25,
          lastFrameMs: 12,
          budgetMs: 40,
          slowFrames: 2,
          analysisMs: 22.5,
          segmentMs: 9,
          landmarkMs: 13.5,
          analyses: 150,
          facePresent: true,
          faceModel: 'ready',
          cameraFrames: 301,
          framePath: 'source',
        ),
        LiveArStatus.off,
      );
      expect(lines, [
        'FREE  ready',
        'in 300  out 288  raw 12',
        'frame 14.3 ms  last 12.0 ms  budget 40 ms',
        'slow 2  skip 0  backoff 0',
        'analysis 22.5 ms  seg 9.0 ms  face 13.5 ms  #150',
        'face yes  model ready  on track',
        'camera 301  path source',
      ]);
      // Never a licence line for the free engine; DeepAR's lines unchanged.
      expect(lines.join(), isNot(contains('licence')));
    });

    testWidgets('the override chips: server, DeepAR, Free', (tester) async {
      final picks = <LiveFxEngine?>[];
      await pumpScreen(
        tester,
        Align(
          alignment: Alignment.topLeft,
          child: LiveFxDiagnostics(
            load: () async => null,
            status: ValueNotifier(LiveArStatus.off),
            engineOverride: LiveFxEngine.free,
            onEngineOverride: picks.add,
          ),
        ),
      );
      await tester.pump();
      expect(
        find.byKey(LiveFxDiagnostics.overrideKey(LiveFxEngine.free)),
        findsOneWidget,
      );
      await tester.tap(find.byKey(LiveFxDiagnostics.overrideKey(null)));
      await tester.tap(
        find.byKey(LiveFxDiagnostics.overrideKey(LiveFxEngine.deepAr)),
      );
      expect(picks, [null, LiveFxEngine.deepAr]);
      // Folded: the chips go too.
      await tester.tap(find.byKey(LiveFxDiagnostics.overlayKey));
      await tester.pump();
      expect(find.byKey(LiveFxDiagnostics.overrideKey(null)), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}

/// Whether Magic's tool shows its badge (the dot on its icon).
bool hostBadge(WidgetTester tester) => find
    .descendant(
      of: find.byKey(GoLiveKeys.tool('magic')),
      matching: find.byType(PositionedDirectional),
    )
    .evaluate()
    .isNotEmpty;
