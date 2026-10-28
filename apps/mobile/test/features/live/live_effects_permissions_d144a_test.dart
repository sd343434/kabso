// D144a: DeepAR switches an effect off by itself instead of freezing the
// picture, Magic says why, the non-release diagnostics overlay, and the
// camera/microphone permission flow (rationale first, the system prompt
// once, «فتح الإعدادات» when refused for good, microphone only for audio).

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_camera_fx/kabso_camera_fx.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/application/live_host_controller.dart';
import 'package:kabso_live/features/live/data/beauty/live_ar_effect.dart';
import 'package:kabso_live/features/live/data/live_blocked_words_repository.dart';
import 'package:kabso_live/features/live/data/live_media_engine.dart';
import 'package:kabso_live/features/live/data/live_permissions.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/data/live_schedule_repository.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/go_live_screen.dart';
import 'package:kabso_live/features/live/presentation/go_live/go_live_parts.dart';
import 'package:kabso_live/features/live/presentation/live_fx_diagnostics.dart';
import 'package:kabso_live/features/live/presentation/live_permission_sheet.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_live_blocked_words_repository.dart';
import '../../helpers/fake_live_media_engine.dart';
import '../../helpers/fake_live_permissions.dart';
import '../../helpers/fake_live_repository.dart';
import '../../helpers/fake_live_schedule_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

Future<FakeLiveMediaEngine> _pump(
  WidgetTester tester, {
  FakeLiveMediaEngine? engine,
  FakeLivePermissions? permissions,
  bool settle = true,
}) async {
  final camera = engine ?? FakeLiveMediaEngine();
  setViewport(tester, GoldenViewport.phone);
  await tester.pumpWidget(const SizedBox.shrink());
  await pumpScreen(
    tester,
    const GoLiveScreen(),
    liveMediaEngine: camera,
    overrides: [
      liveRepositoryProvider.overrideWithValue(FakeLiveRepository()),
      currentUserProvider.overrideWithValue(testUser().copyWith(canHost: true)),
      liveBlockedWordsRepositoryProvider.overrideWithValue(
        FakeLiveBlockedWordsRepository(),
      ),
      liveScheduleRepositoryProvider.overrideWithValue(
        FakeLiveScheduleRepository(),
      ),
      if (permissions != null)
        livePermissionsProvider.overrideWithValue(permissions),
    ],
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    // The rationale sheet is up over the preparing spinner (which spins).
    await _sheetUp(tester);
  }
  return camera;
}

/// The sheet opens after an asynchronous check, then animates in.
Future<void> _sheetUp(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
}

Future<void> _leave(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(GoLiveScreen)));

GoLiveState _host(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(GoLiveScreen)))
        .read(liveHostControllerProvider);

FakeLiveMediaEngine _arEngine() => FakeLiveMediaEngine()
  ..supportsBeauty = false
  ..supportsFilters = true
  ..arSupport = LiveArSupport.ready;

bool _selected(WidgetTester tester, Finder chip) =>
    tester
        .widget<Semantics>(
          find.descendant(of: chip, matching: find.byType(Semantics)).first,
        )
        .properties
        .selected ??
    false;

void main() {
  group('D144a DeepAR status', () {
    testWidgets('DeepAR stops giving new pictures: the effect turns off, '
        'Magic shows None and says why; picking it again retries', (
      tester,
    ) async {
      final camera = await _pump(tester, engine: _arEngine());
      final l10n = _l10n(tester);
      await tester.tap(find.byKey(GoLiveKeys.tool('magic')));
      await tester.pumpAndSettle();
      final blur = find.byKey(GoLiveKeys.effect(LiveArEffect.backgroundBlur));
      final none = find.byKey(GoLiveKeys.effect(LiveArEffect.none));
      await tester.ensureVisible(blur);
      await tester.tap(blur);
      camera.arStatusValue.value = const LiveArStatus(LiveArState.starting);
      await tester.pumpAndSettle();
      expect(find.text(l10n.liveEffectStarting), findsOneWidget);

      // The native side gave up (no fresh picture): it says so.
      camera.arStatusValue.value = const LiveArStatus(
        LiveArState.unavailable,
        problem: LiveArProblem.stopped,
        code: 'no_output',
      );
      await tester.pumpAndSettle();
      expect(_host(tester).beauty.effect, LiveArEffect.none);
      expect(camera.beauty.effect, LiveArEffect.none);
      expect(find.byKey(GoLiveKeys.effectStatus), findsOneWidget);
      expect(find.text(l10n.liveEffectUnavailableStopped), findsOneWidget);
      expect(l10n.liveEffectUnavailableStopped, startsWith('The effect'));
      expect(_selected(tester, none), isTrue);
      expect(_selected(tester, blur), isFalse);

      // Picked again: DeepAR starts over.
      await tester.tap(blur);
      camera.arStatusValue.value = const LiveArStatus(LiveArState.starting);
      await tester.pumpAndSettle();
      expect(camera.beauty.effect, LiveArEffect.backgroundBlur);
      expect(find.text(l10n.liveEffectUnavailableStopped), findsNothing);
      expect(_selected(tester, blur), isTrue);
      camera.arStatusValue.value = const LiveArStatus(LiveArState.running);
      await tester.pumpAndSettle();
      expect(find.byKey(GoLiveKeys.effectStatus), findsNothing);
      await _leave(tester);
    });

    testWidgets('a refused licence and a start failure each say so (Arabic)', (
      tester,
    ) async {
      final camera = _arEngine();
      setViewport(tester, GoldenViewport.phone);
      await pumpScreen(
        tester,
        const GoLiveScreen(),
        language: AppLanguage.ar,
        liveMediaEngine: camera,
        overrides: [
          liveRepositoryProvider.overrideWithValue(FakeLiveRepository()),
          currentUserProvider.overrideWithValue(
            testUser().copyWith(canHost: true),
          ),
        ],
      );
      await tester.pumpAndSettle();
      final l10n = _l10n(tester);
      await tester.tap(find.byKey(GoLiveKeys.tool('magic')));
      await tester.pumpAndSettle();
      final blur = find.byKey(GoLiveKeys.effect(LiveArEffect.backgroundBlur));
      await tester.ensureVisible(blur);
      await tester.tap(blur);
      camera.arStatusValue.value = const LiveArStatus(
        LiveArState.unavailable,
        problem: LiveArProblem.licence,
      );
      await tester.pumpAndSettle();
      expect(find.text(l10n.liveEffectUnavailableLicence), findsOneWidget);
      expect(
        l10n.liveEffectUnavailableLicence,
        startsWith('المؤثر غير متاح الآن:'),
      );
      await tester.tap(blur);
      camera.arStatusValue.value = const LiveArStatus(LiveArState.starting);
      await tester.pump();
      camera.arStatusValue.value = const LiveArStatus(
        LiveArState.unavailable,
        problem: LiveArProblem.failed,
        code: 'init_timeout',
      );
      await tester.pumpAndSettle();
      expect(find.text(l10n.liveEffectUnavailableFailed), findsOneWidget);
      expect(_host(tester).beauty.effect, LiveArEffect.none);
      await _leave(tester);
    });

    test('native states map to the app status', () {
      expect(
        LiveArStatus.from(const KabsoCameraFxStatus(KabsoCameraFxState.ready)),
        const LiveArStatus(LiveArState.running),
      );
      expect(
        LiveArStatus.from(
          const KabsoCameraFxStatus(KabsoCameraFxState.disabled, 'stalled'),
        ),
        const LiveArStatus(
          LiveArState.unavailable,
          problem: LiveArProblem.stopped,
          code: 'stalled',
        ),
      );
      expect(
        LiveArStatus.from(
          const KabsoCameraFxStatus(KabsoCameraFxState.licenceFailed),
        ).problem,
        LiveArProblem.licence,
      );
      expect(LiveArStatus.from(KabsoCameraFxStatus.off), LiveArStatus.off);
    });
  });

  group('D144a diagnostics overlay (non-release)', () {
    const diagnostics = KabsoCameraFxDiagnostics(
      status: KabsoCameraFxStatus(KabsoCameraFxState.ready),
      licencePresent: true,
      attached: true,
      initialized: true,
      framesIn: 300,
      fed: 280,
      busySkips: 20,
      rendered: 600,
      delivered: 590,
      staleDropped: 300,
      framesOut: 290,
      timeouts: 10,
      avgWaitMs: 12.5,
      avgPackMs: 4,
      instances: 1,
      input: '1280x720@270',
      sdkVersion: '5.6.22',
    );

    testWidgets('state, frames in/out, average ms, timeouts and whether a '
        'licence is present; folds on tap', (tester) async {
      expect(LiveFxDiagnostics.enabled, isTrue, reason: 'tests run in debug');
      final camera = _arEngine()..diagnostics = diagnostics;
      await _pump(tester, engine: camera);
      await tester.pump(const Duration(seconds: 1));
      final overlay = find.byKey(LiveFxDiagnostics.overlayKey);
      expect(overlay, findsOneWidget);
      final text = tester
          .widget<Text>(
            find.descendant(of: overlay, matching: find.byType(Text)),
          )
          .data!;
      expect(text, contains('DeepAR  ready  licence yes'));
      expect(text, contains('in 300  fed 280  out 290  raw 10'));
      expect(text, contains('wait 12.5 ms  pack 4.0 ms'));
      expect(text, contains('input 1280x720@270'));
      await tester.tap(overlay);
      await tester.pump();
      expect(find.text('FX ▸'), findsOneWidget);
      await _leave(tester);
    });

    testWidgets('not without the processor, not in an audio room', (
      tester,
    ) async {
      await _pump(tester);
      expect(find.byKey(LiveFxDiagnostics.overlayKey), findsNothing);
      await _leave(tester);

      final camera = _arEngine()..diagnostics = diagnostics;
      await _pump(tester, engine: camera);
      expect(find.byKey(LiveFxDiagnostics.overlayKey), findsOneWidget);
      await tester.tap(find.byKey(GoLiveKeys.mode(LiveRoomMode.audio)));
      await tester.pumpAndSettle();
      expect(find.byKey(LiveFxDiagnostics.overlayKey), findsNothing);
      await _leave(tester);
    });

    test(
      'lines: no processor; an error line; never more than the key flag',
      () {
        expect(
          liveFxDiagnosticsLines(null, LiveArStatus.off).first,
          'DeepAR  no processor',
        );
        final lines = liveFxDiagnosticsLines(
          const KabsoCameraFxDiagnostics(
            status: KabsoCameraFxStatus(
              KabsoCameraFxState.disabled,
              'no_output',
            ),
            licencePresent: false,
            lastError: 'ERROR: something',
          ),
          LiveArStatus.off,
        );
        expect(lines.first, 'DeepAR  disabled (no_output)  licence no');
        expect(lines.last, 'err ERROR: something');
      },
    );
  });

  group('D144a camera and microphone permissions', () {
    testWidgets('first time: the rationale shows before the system prompt; '
        'Not now asks nothing; Continue asks once and the camera starts', (
      tester,
    ) async {
      final permissions = FakeLivePermissions(
        state: LivePermission.notAsked,
        afterRequest: LivePermission.granted,
      );
      final camera = await _pump(
        tester,
        permissions: permissions,
        settle: false,
      );
      final l10n = _l10n(tester);
      expect(find.byKey(LivePermissionKeys.sheet), findsOneWidget);
      expect(find.text(l10n.livePermissionTitleVideo), findsOneWidget);
      expect(find.text(l10n.livePermissionBodyVideo), findsOneWidget);
      expect(permissions.requests, isEmpty);
      expect(camera.previewStarts, 0);

      await tester.tap(find.byKey(LivePermissionKeys.notNow));
      await tester.pumpAndSettle();
      expect(permissions.requests, isEmpty);
      expect(camera.previewStarts, 0);
      expect(find.byKey(GoLiveScreen.captureFailedKey), findsOneWidget);
      expect(find.byKey(GoLiveScreen.settingsKey), findsNothing);

      await tester.tap(find.byKey(GoLiveScreen.retryKey));
      await _sheetUp(tester);
      await tester.tap(find.byKey(LivePermissionKeys.go));
      await tester.pumpAndSettle();
      expect(permissions.requests, [true]);
      expect(camera.previewStarts, 1);
      expect(_host(tester).phase, GoLivePhase.preview);
      await _leave(tester);
    });

    testWidgets('granted already: no sheet, no prompt', (tester) async {
      final permissions = FakeLivePermissions();
      final camera = await _pump(tester, permissions: permissions);
      expect(find.byKey(LivePermissionKeys.sheet), findsNothing);
      expect(permissions.checks, [true]);
      expect(permissions.requests, isEmpty);
      expect(camera.previewStarts, 1);
      await _leave(tester);
    });

    testWidgets('refused at the prompt: the notice, and the system is not '
        'asked again until the person retries', (tester) async {
      final permissions = FakeLivePermissions(
        state: LivePermission.notAsked,
        afterRequest: LivePermission.denied,
      );
      final camera = await _pump(
        tester,
        permissions: permissions,
        settle: false,
      );
      await tester.tap(find.byKey(LivePermissionKeys.go));
      await tester.pumpAndSettle();
      expect(permissions.requests, [true]);
      expect(camera.previewStarts, 0);
      expect(find.byKey(GoLiveScreen.captureFailedKey), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(permissions.requests, [true]);
      await _leave(tester);
    });

    testWidgets('refused for good: «Open settings», no sheet, no prompt; back '
        'from the settings with access, the camera starts', (tester) async {
      final permissions = FakeLivePermissions(state: LivePermission.blocked);
      final camera = await _pump(tester, permissions: permissions);
      final l10n = _l10n(tester);
      expect(find.byKey(LivePermissionKeys.sheet), findsNothing);
      expect(permissions.requests, isEmpty);
      expect(find.byKey(GoLiveScreen.captureFailedKey), findsOneWidget);
      expect(find.text(l10n.livePermissionBlockedVideo), findsOneWidget);
      expect(find.text(l10n.livePermissionOpenSettings), findsOneWidget);

      await tester.tap(find.byKey(GoLiveScreen.settingsKey));
      await tester.pumpAndSettle();
      expect(permissions.settingsOpened, 1);

      permissions.state = LivePermission.granted;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(camera.previewStarts, 1);
      expect(_host(tester).phase, GoLivePhase.preview);
      expect(permissions.requests, isEmpty);
      await _leave(tester);
    });

    testWidgets('the audio-room rationale in Arabic at 360 × 800, text 1.3: '
        'microphone only, nothing cut', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      setViewport(tester, GoldenViewport.android);
      await pumpScreen(
        tester,
        Builder(
          builder: (context) => Center(
            child: TextButton(
              key: const Key('open'),
              onPressed: () => showLivePermissionSheet(context, camera: false),
              child: const Text('open'),
            ),
          ),
        ),
        language: AppLanguage.ar,
      );
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(
        tester.element(find.byKey(LivePermissionKeys.sheet)),
      );
      expect(find.text(l10n.livePermissionTitleAudio), findsOneWidget);
      expect(find.text(l10n.livePermissionBodyAudio), findsOneWidget);
      expect(find.byIcon(Icons.videocam_rounded), findsNothing);
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
      final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
      expect(
        tester.getRect(find.byKey(LivePermissionKeys.notNow)).bottom,
        lessThanOrEqualTo(screen.height),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(LivePermissionKeys.go));
      await tester.pumpAndSettle();
      expect(find.byKey(LivePermissionKeys.sheet), findsNothing);
    });

    testWidgets('«فتح الإعدادات» in Arabic', (tester) async {
      setViewport(tester, GoldenViewport.phone);
      await pumpScreen(
        tester,
        const GoLiveScreen(),
        language: AppLanguage.ar,
        liveMediaEngine: FakeLiveMediaEngine(),
        overrides: [
          liveRepositoryProvider.overrideWithValue(FakeLiveRepository()),
          currentUserProvider.overrideWithValue(
            testUser().copyWith(canHost: true),
          ),
          livePermissionsProvider.overrideWithValue(
            FakeLivePermissions(state: LivePermission.blocked),
          ),
        ],
      );
      await tester.pumpAndSettle();
      expect(find.text('فتح الإعدادات'), findsOneWidget);
      await _leave(tester);
    });

    test('an audio room asks for the microphone only; a video room for '
        'both', () async {
      final permissions = FakeLivePermissions(
        state: LivePermission.notAsked,
        afterRequest: LivePermission.granted,
      );
      final engine = FakeLiveMediaEngine();
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          liveRepositoryProvider.overrideWithValue(FakeLiveRepository()),
          liveMediaEngineProvider.overrideWithValue(() => engine),
          livePermissionsProvider.overrideWithValue(permissions),
          currentUserProvider.overrideWithValue(
            testUser().copyWith(canHost: true),
          ),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(liveHostControllerProvider, (_, _) {});
      addTearDown(sub.close);
      final host = container.read(liveHostControllerProvider.notifier);
      final explained = <bool>[];
      Future<bool> explain({required bool camera}) async {
        explained.add(camera);
        return true;
      }

      await host.setMode(LiveRoomMode.audio);
      await host.startPreview(explain: explain);
      expect(explained, [false]);
      expect(permissions.checks, [false]);
      expect(permissions.requests, [false]);
      expect(engine.previewModes, [false]);

      // To a video room: the camera is asked for now.
      permissions.state = LivePermission.notAsked;
      await host.setMode(LiveRoomMode.solo, explain: explain);
      expect(explained, [false, true]);
      expect(permissions.requests, [false, true]);
      expect(engine.previewModes, [false, true]);
    });

    test('the device permissions combine to the worst state', () {
      expect(
        DeviceLivePermissions.combine([
          KabsoPermissionStatus.granted,
          KabsoPermissionStatus.blocked,
        ]),
        LivePermission.blocked,
      );
      expect(
        DeviceLivePermissions.combine([
          KabsoPermissionStatus.notAsked,
          KabsoPermissionStatus.granted,
        ]),
        LivePermission.notAsked,
      );
      expect(
        DeviceLivePermissions.combine([KabsoPermissionStatus.granted]),
        LivePermission.granted,
      );
      expect(
        DeviceLivePermissions.combine([KabsoPermissionStatus.unknown]),
        LivePermission.unknown,
      );
      expect(LivePermission.unknown.canStart, isTrue);
      expect(LivePermission.denied.canStart, isFalse);
    });
  });

  test('kReleaseMode is false here (the overlay is debug/profile only)', () {
    expect(kReleaseMode, isFalse);
  });
}
