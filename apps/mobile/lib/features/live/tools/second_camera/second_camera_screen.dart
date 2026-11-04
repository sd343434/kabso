import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/application/live_background.dart';
import 'package:kabso_live/features/live/application/live_fx_engine_providers.dart';
import 'package:kabso_live/features/live/data/beauty/live_ar_effect.dart';
import 'package:kabso_live/features/live/data/beauty/live_beauty.dart';
import 'package:kabso_live/features/live/data/beauty/live_fx_engine.dart';
import 'package:kabso_live/features/live/data/live_media_engine.dart';
import 'package:kabso_live/features/live/data/live_media_extras.dart';
import 'package:kabso_live/features/live/data/live_screen_awake.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/presentation/go_live/go_live_parts.dart'
    show showLiveFilterSheet;
import 'package:kabso_live/features/live/tools/live_tool_parts.dart';
import 'package:kabso_live/features/live/tools/live_tools_repository.dart';
import 'package:kabso_live/features/live/tools/second_camera/second_camera_log.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D201 «الانضمام ككاميرا ثانية» (`/live/second-camera`): on the host's
/// second phone or tablet, signed in to the same account. The code from the
/// main device's «كاميرتان» → a minimal camera screen: the picture, flip, the
/// filters, the microphone (off at first) and leave. No chat, no viewers'
/// things: this device only publishes its camera into the host's live.
///
/// D243 (owner: «الكاميرا الثانية تقف»): this device usually sits untouched,
/// so while it joins and is on air the screen stays on ([LiveScreenAwake]);
/// it holds the live's foreground service like a seated guest; leaving the
/// app tells the others the camera is off and coming back turns it on again.
/// A reconnect (network blip) is never an end: only the session closing for
/// good ([LiveSessionLink]) or a removal ends this screen.
///
/// D251 (owner: «تشبك، لكن أوّل ما تفتح تعلق ولا تعود تستجيب»): the app
/// hang. Every platform call here is time-limited ([guardCall]) and none of
/// them can hold the camera or the screen: a keep-screen-on or foreground
/// service that fails or never answers leaves a note, never a frozen screen.
/// The away/back of the app no longer stops and reopens the camera
/// ([LiveSoftVideoPause]: flutter_webrtc waits for a camera to close / open on
/// Android's main thread without a limit — the hang), is debounced (a quick
/// system dialog changes nothing) and is applied one at a time with the
/// latest wish winning (no mute/unmute thrash). The foreground service starts
/// after the camera is on air and settled, and never asks the notification
/// permission over the camera. A state log (no personal data) is copied with
/// «نسخ سجل التشخيص». The host's filters (D143/D144/D228 «الفلاتر»: colour
/// filters, the free engine's or DeepAR's effects as the admin's
/// `cameraFxEngine` says) are offered here too, local to this device, «بدون
/// فلتر» by default.
class SecondCameraScreen extends ConsumerStatefulWidget {
  const new({super.key});

  static const codeKey = Key('cam2b.code');
  static const joinKey = Key('cam2b.join');
  static const errorKey = Key('cam2b.error');
  static const cameraKey = Key('cam2b.camera');
  static const flipKey = Key('cam2b.flip');
  static const micKey = Key('cam2b.mic');
  static const leaveKey = Key('cam2b.leave');
  static const endedKey = Key('cam2b.ended');
  static const onAirKey = Key('cam2b.onAir');
  static const keepOpenKey = Key('cam2b.keepOpen');

  /// D251: the filters button (the go-live's «الفلاتر» sheet).
  static const filtersKey = Key('cam2b.filters');

  /// D251: copies the state log.
  static const copyLogKey = Key('cam2b.copyLog');

  /// D251: the notes when something degraded.
  static Key noteKey(SecondCameraNote note) => Key('cam2b.note.${note.name}');

  /// D251: the time limits of this screen's calls (tests shorten them).
  /// Keep-screen-on and the clipboard: a window flag, answered at once.
  @visibleForTesting
  static Duration platformLimit = const Duration(seconds: 3);

  /// A camera call (away/back, flip, microphone, filters).
  @visibleForTesting
  static Duration cameraLimit = const Duration(seconds: 6);

  /// Opening the camera and microphone (their permission dialogs included)
  /// and publishing them.
  @visibleForTesting
  static Duration joinLimit = const Duration(seconds: 60);

  /// Leaving the media session and telling the server.
  @visibleForTesting
  static Duration leaveLimit = const Duration(seconds: 6);

  /// How long after going on air the live foreground service starts (its
  /// start builds a second Flutter engine on Android's main thread: not
  /// while the camera opens and publishes).
  @visibleForTesting
  static Duration backgroundDelay = const Duration(milliseconds: 1500);

  /// How long the app must stay away before the camera is told off (a
  /// system dialog or a quick switch changes nothing).
  @visibleForTesting
  static Duration awayDebounce = const Duration(milliseconds: 800);

  @override
  ConsumerState<SecondCameraScreen> createState() => _SecondCameraScreenState();
}

/// D251: what degraded on this device (each a note on the camera screen).
enum SecondCameraNote {
  /// The screen could not be kept on.
  keepAwake,

  /// The live foreground service could not start.
  background,

  /// A camera call failed or did not answer in time.
  camera,

  /// The filters could not be applied.
  filters,
}

enum _Phase { code, joining, live, ended }

class _SecondCameraScreenState extends ConsumerState<SecondCameraScreen> {
  final _code = TextEditingController();
  final _log = SecondCameraLog();
  _Phase _phase = _Phase.code;
  String? _error;
  LiveMediaEngine? _engine;
  SecondCameraAccess? _access;
  bool _wasConnected = false;
  bool _leaving = false;

  late final LiveBackgroundKeeper _keeper;
  late final LiveScreenAwake _awake;
  bool _awakeOn = false;
  Timer? _backgroundTimer;

  // D251: the app away/back, applied one at a time (latest wish wins).
  bool _wantAway = false;
  bool _appliedAway = false;
  bool _applyingAway = false;
  Timer? _awayTimer;

  bool _flipping = false;
  bool _micBusy = false;
  final Set<SecondCameraNote> _notes = {};

  // D251: the filters, local to this device («بدون فلتر» at first).
  LiveBeauty _beauty = const LiveBeauty();
  ProviderSubscription<LiveFxEngine>? _fxEngineSub;

  LiveToolsRepository get _repo => ref.read(liveToolsRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _keeper = ref.read(liveBackgroundKeeperProvider);
    _awake = ref.read(liveScreenAwakeProvider);
    _code.addListener(() => setState(() {}));
    _log.add('open');
  }

  @override
  void dispose() {
    _log.add('dispose', _phase.name);
    _code.dispose();
    _offAir();
    final engine = _engine;
    _engine = null;
    engine?.changes.removeListener(_changed);
    if (engine != null) {
      unawaited(
        guardCall(_log, 'stop', SecondCameraScreen.leaveLimit, engine.stop),
      );
    }
    super.dispose();
  }

  void _note(SecondCameraNote note) {
    if (!mounted || _notes.contains(note)) return;
    setState(() => _notes.add(note));
  }

  void _keepAwake({required bool on}) {
    if (_awakeOn == on) return;
    _awakeOn = on;
    unawaited(() async {
      final call = await guardCall<void>(
        _log,
        on ? 'keep-on' : 'keep-off',
        SecondCameraScreen.platformLimit,
        () => _awake.keepOn(on: on),
      );
      if (!call.ok && on && _awakeOn) _note(SecondCameraNote.keepAwake);
    }());
  }

  /// The screen may time out again and the foreground service stops.
  void _offAir() {
    _backgroundTimer?.cancel();
    _backgroundTimer = null;
    _awayTimer?.cancel();
    _awayTimer = null;
    _fxEngineSub?.close();
    _fxEngineSub = null;
    _keepAwake(on: false);
    if (_keeper.holds(this)) _log.add('fgs', 'release');
    _keeper.release(this);
  }

  /// D243: whether the session is over (not a reconnect).
  bool _ended(LiveMediaEngine engine) {
    if (engine.removed) return true;
    if (engine is LiveSessionLink) {
      return (engine as LiveSessionLink).sessionClosed;
    }
    return _wasConnected && !engine.connected;
  }

  bool? _lastConnected;

  void _changed() {
    final engine = _engine;
    if (!mounted || engine == null) return;
    if (engine.connected) _wasConnected = true;
    if (_lastConnected != engine.connected) {
      _lastConnected = engine.connected;
      _log.add('media', engine.connected ? 'connected' : 'not-connected');
    }
    if (_phase == _Phase.live && _ended(engine)) {
      _log.add('ended', engine.removed ? 'removed' : 'closed');
      _offAir();
      setState(() => _phase = _Phase.ended);
      unawaited(
        guardCall(_log, 'stop', SecondCameraScreen.leaveLimit, engine.stop),
      );
      return;
    }
    setState(() {});
  }

  /// D243: the live's foreground service while on air (type microphone, as
  /// a seated guest), the notification's button leaves. D251: started once
  /// the camera is on air and settled, never asking the notification
  /// permission; a failure is a note.
  void _scheduleBackground(AppLocalizations l10n) {
    _backgroundTimer?.cancel();
    _backgroundTimer = Timer(SecondCameraScreen.backgroundDelay, () {
      _backgroundTimer = null;
      if (!mounted || _phase != _Phase.live) return;
      _log.add('fgs', 'hold');
      try {
        _holdService(l10n);
      } on Object catch (e) {
        _log.add('fgs', 'failed ${e.runtimeType}');
        _note(SecondCameraNote.background);
        return;
      }
      // Away already (the app left while it settled).
      if (_keeper.away) _setAway(away: true);
    });
  }

  void _holdService(AppLocalizations l10n) {
    _keeper.hold(
      this,
      LiveBackgroundSpec(
        role: LiveBackgroundRole.guest,
        title: l10n.liveCam2OnAir,
        body: l10n.liveBgBody,
        actionLabel: l10n.liveCam2Leave,
        channelName: l10n.liveBgChannel,
        askNotifications: false,
      ),
      onEnd: () {
        _log.add('fgs', 'leave-action');
        unawaited(_leave());
      },
      onBackground: () => _setAway(away: true),
      onForeground: () => _setAway(away: false),
      onUnavailable: () {
        _log.add('fgs', 'unavailable');
        _note(SecondCameraNote.background);
      },
    );
  }

  /// D251: the app left ([away]) or came back. Leaving is applied after
  /// [SecondCameraScreen.awayDebounce] (a system dialog or a quick switch
  /// changes nothing); coming back at once.
  void _setAway({required bool away}) {
    _log.add('app', away ? 'away' : 'back');
    _wantAway = away;
    _awayTimer?.cancel();
    _awayTimer = null;
    if (away) {
      _awayTimer = Timer(SecondCameraScreen.awayDebounce, () {
        _awayTimer = null;
        unawaited(_applyAway());
      });
    } else {
      unawaited(_applyAway());
    }
  }

  /// One away/back call at a time; the latest wish wins; a failure is a
  /// note and is not retried until the wish changes again.
  Future<void> _applyAway() async {
    if (_applyingAway) return;
    _applyingAway = true;
    try {
      while (mounted && _phase == _Phase.live) {
        final want = _wantAway;
        final engine = _engine;
        if (engine == null || want == _appliedAway) break;
        final call = await guardCall<void>(
          _log,
          want ? 'camera-away' : 'camera-back',
          SecondCameraScreen.cameraLimit,
          () => engine is LiveSoftVideoPause
              ? (engine as LiveSoftVideoPause).setVideoAway(away: want)
              : engine.setVideoPaused(paused: want),
        );
        _appliedAway = want;
        if (!call.ok) {
          _note(SecondCameraNote.camera);
          break;
        }
      }
    } finally {
      _applyingAway = false;
    }
  }

  Future<void> _join() async {
    final l10n = context.l10n;
    final code = _code.text.trim();
    if (code.length != 6 || _phase != _Phase.code) return;
    _log.add('join');
    setState(() {
      _phase = _Phase.joining;
      _error = null;
    });
    _keepAwake(on: true);
    SecondCameraAccess access;
    try {
      access = await _repo.redeem(code);
      _log.add('redeem', 'ok');
    } on Object catch (e) {
      _log.add(
        'redeem',
        'failed ${e is ServerFailure ? e.rawCode : e.runtimeType}',
      );
      if (!mounted) return;
      _keepAwake(on: false);
      setState(() {
        _phase = _Phase.code;
        _error = switch (e) {
          ServerFailure(rawCode: 'SECOND_CAMERA_CODE_INVALID') ||
          ServerFailure(
            rawCode: 'VALIDATION_FAILED',
          ) => l10n.liveCam2CodeInvalid,
          ServerFailure(rawCode: 'SECOND_CAMERA_UNAVAILABLE') =>
            l10n.liveCam2Unavailable,
          ServerFailure(rawCode: 'SECOND_CAMERA_BUSY') => l10n.liveCam2Busy,
          ServerFailure(rawCode: 'RATE_LIMITED') => l10n.liveCam2TooMany,
          _ => l10n.liveCam2Failed,
        };
      });
      return;
    }
    if (!mounted) return;
    final engine = ref.read(liveMediaEngineProvider)();
    _engine = engine;
    _access = access;
    engine.changes.addListener(_changed);
    try {
      await _step('preview', () async {
        // The microphone starts off; the host turns it on here if wanted.
        await engine.setMicEnabled(enabled: false);
        await engine.startPreview();
      });
      await _step(
        'publish',
        () => engine.publish(
          LiveMediaAccess(
            url: access.url,
            token: access.token,
            expiresAt: access.expiresAt,
            role: LiveMediaRole.speaker,
            identity: access.identity,
          ),
        ),
      );
      if (!mounted || !identical(_engine, engine)) return;
      _log.add('on-air');
      setState(() => _phase = _Phase.live);
      _watchFxEngine();
      _scheduleBackground(l10n);
    } on LiveCaptureException catch (e) {
      await _abandon();
      if (!mounted) return;
      setState(() {
        _phase = _Phase.code;
        _error = e.problem == LiveCaptureProblem.unavailable
            ? l10n.liveCam2Failed
            : l10n.liveCam2PermissionDenied;
      });
    } on Object {
      await _abandon();
      if (!mounted) return;
      setState(() {
        _phase = _Phase.code;
        _error = l10n.liveCam2Failed;
      });
    }
  }

  /// One step of joining, logged and time-limited (its errors go on to the
  /// caller; a step that does not answer is a [TimeoutException]).
  Future<void> _step(String name, Future<void> Function() op) async {
    final watch = Stopwatch()..start();
    try {
      await Future<void>.sync(op).timeout(SecondCameraScreen.joinLimit);
      _log.add(name, 'ok ${watch.elapsedMilliseconds}ms');
    } on TimeoutException {
      _log.add(name, 'timeout');
      rethrow;
    } on LiveCaptureException catch (e) {
      _log.add(name, 'failed capture-${e.problem.name}');
      rethrow;
    } on Object catch (e) {
      _log.add(name, 'failed ${e.runtimeType}');
      rethrow;
    }
  }

  /// Leaves the media room and tells the server (the main device's state).
  /// Never waits longer than [SecondCameraScreen.leaveLimit] per step.
  Future<void> _abandon() async {
    _offAir();
    final engine = _engine;
    _engine = null;
    engine?.changes.removeListener(_changed);
    if (engine != null) {
      await guardCall(_log, 'stop', SecondCameraScreen.leaveLimit, engine.stop);
    }
    final access = _access;
    _access = null;
    if (access != null) {
      // The server also ends it when the device leaves the media room.
      await guardCall(
        _log,
        'end-camera',
        SecondCameraScreen.leaveLimit,
        () => _repo.endSecondCamera(access.roomId),
      );
    }
  }

  Future<void> _leave() async {
    if (_leaving) return;
    _leaving = true;
    _log.add('leave');
    try {
      await _abandon();
    } finally {
      _leaving = false;
    }
    if (!mounted) return;
    final router = GoRouter.maybeOf(context);
    if (router != null && !router.canPop()) {
      router.go('/');
    } else {
      await Navigator.of(context).maybePop();
    }
  }

  Future<void> _flip() async {
    final engine = _engine;
    if (engine == null || _flipping) return;
    setState(() => _flipping = true);
    final call = await guardCall<void>(
      _log,
      'flip',
      SecondCameraScreen.cameraLimit,
      engine.flipCamera,
    );
    // D251c: which path flipped (`switch`, `restart state=…`, `helper`).
    final path = LiveKitMediaEngine.lastFlipPath;
    if (call.ok && path != null) _log.add('flip-path', path);
    if (!mounted) return;
    if (!call.ok) _note(SecondCameraNote.camera);
    setState(() => _flipping = false);
  }

  Future<void> _toggleMic() async {
    final engine = _engine;
    if (engine == null || _micBusy) return;
    final on = !engine.micEnabled;
    setState(() => _micBusy = true);
    final call = await guardCall<void>(
      _log,
      on ? 'mic-on' : 'mic-off',
      SecondCameraScreen.cameraLimit,
      () => engine.setMicEnabled(enabled: on),
    );
    if (!mounted) return;
    if (!call.ok) _note(SecondCameraNote.camera);
    setState(() => _micBusy = false);
  }

  // ---- D251 filters ---------------------------------------------------------

  /// The host's effects engine (the admin's `cameraFxEngine`, or the
  /// debug override) on this device's camera too.
  void _watchFxEngine() {
    _fxEngineSub?.close();
    try {
      _fxEngineSub = ref.listenManual<LiveFxEngine>(
        liveFxEngineProvider,
        (_, next) => unawaited(_setFxEngine(next)),
        fireImmediately: true,
      );
    } on Object catch (e) {
      _log.add('fx-engine', 'failed ${e.runtimeType}');
    }
  }

  Future<void> _setFxEngine(LiveFxEngine next) async {
    final engine = _engine;
    if (engine == null || engine.fxEngine == next) return;
    final call = await guardCall<void>(
      _log,
      'fx-engine-${next.wire}',
      SecondCameraScreen.cameraLimit,
      () => engine.setFxEngine(next),
    );
    if (!mounted) return;
    if (!call.ok) _note(SecondCameraNote.filters);
    setState(() {});
  }

  Future<void> _setBeauty(LiveBeauty next) async {
    final engine = _engine;
    if (engine == null) return;
    setState(() => _beauty = next);
    final call = await guardCall<void>(
      _log,
      'fx filter=${next.filter.name} effect=${next.effect.name} '
      'beauty=${next.free.on}',
      SecondCameraScreen.cameraLimit,
      () => engine.setBeauty(next),
    );
    if (call.ok || !mounted) return;
    // Back to «بدون فلتر»; the picture goes on.
    _note(SecondCameraNote.filters);
    setState(() => _beauty = const LiveBeauty());
    unawaited(
      guardCall<void>(
        _log,
        'fx-reset',
        SecondCameraScreen.cameraLimit,
        () => engine.setBeauty(const LiveBeauty()),
      ),
    );
  }

  bool _filtersOn(LiveMediaEngine engine) =>
      !_beauty.filter.isNatural ||
      _beauty.effect != LiveArEffect.none ||
      (engine.fxEngine == LiveFxEngine.free && _beauty.free.on);

  void _openFilters() {
    final engine = _engine;
    if (engine == null) return;
    _log.add(
      'fx-sheet',
      'engine=${engine.fxEngine.wire} filters=${engine.filtersSupported} '
          'effects=${engine.arEffects.name}',
    );
    unawaited(
      showLiveFilterSheet(
        context,
        selected: _beauty.filter,
        supported: engine.filtersSupported,
        accent: LiveToolColors.accent,
        onChanged: (f) => unawaited(_setBeauty(_beauty.copyWith(filter: f))),
        effects: engine.arEffects,
        effect: _beauty.effect,
        onEffect: (e) => unawaited(_setBeauty(_beauty.copyWith(effect: e))),
        effectStatus: engine.arStatus,
        fxEngine: engine.fxEngine,
        freeBeauty: _beauty.free,
        onFreeBeauty: (b) => unawaited(_setBeauty(_beauty.copyWith(free: b))),
      ),
    );
  }

  // ---- D251 diagnostics -----------------------------------------------------

  String _report() {
    final engine = _engine;
    return _log.report({
      'phase': _phase.name,
      'connected': '${engine?.connected}',
      'closed': switch (engine) {
        final LiveSessionLink link => '${link.sessionClosed}',
        _ => 'n/a',
      },
      'removed': '${engine?.removed}',
      'mic': '${engine?.micEnabled}',
      'videoPaused': '${engine?.videoPaused}',
      'away': 'want=$_wantAway applied=$_appliedAway',
      'keepOn': '$_awakeOn',
      'fgs': 'held=${_keeper.holds(this)} shown=${_keeper.shown != null}',
      'fx':
          'engine=${engine?.fxEngine.wire} filters=${engine?.filtersSupported} '
          'effects=${engine?.arEffects.name} '
          'filter=${_beauty.filter.name} effect=${_beauty.effect.name}',
      'notes': _notes.map((n) => n.name).join(','),
    });
  }

  Future<void> _copyLog() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final call = await guardCall<void>(
      _log,
      'copy-log',
      SecondCameraScreen.platformLimit,
      () => Clipboard.setData(ClipboardData(text: _report())),
    );
    messenger?.showSnackBar(
      SnackBar(
        content: Text(call.ok ? l10n.liveCam2LogCopied : l10n.liveCam2Failed),
      ),
    );
  }

  Widget _copyLogButton({required Color color}) {
    final l10n = context.l10n;
    return TextButton.icon(
      key: SecondCameraScreen.copyLogKey,
      onPressed: () => unawaited(_copyLog()),
      style: TextButton.styleFrom(foregroundColor: color),
      icon: const Icon(Icons.receipt_long_rounded, size: 18),
      label: Text(l10n.liveCam2CopyLog),
    );
  }

  @override
  Widget build(BuildContext context) => switch (_phase) {
    _Phase.code || _Phase.joining => _codeView(context),
    _Phase.live => _cameraView(context),
    _Phase.ended => _endedView(context),
  };

  Widget _codeView(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final joining = _phase == _Phase.joining;
    return LiveToolLightTheme(
      child: Scaffold(
        backgroundColor: const Color(0xFFFFFFFF),
        appBar: AppBar(
          backgroundColor: const Color(0xFFFFFFFF),
          foregroundColor: LiveToolColors.ink,
          title: Text(l10n.liveSecondCameraJoin),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(KSpacing.lg),
            children: [
              const Icon(
                Icons.video_camera_front_rounded,
                size: 56,
                color: LiveToolColors.accent,
              ),
              const SizedBox(height: KSpacing.md),
              Text(
                l10n.liveCam2JoinIntro,
                textAlign: TextAlign.center,
                style: t.body.copyWith(color: LiveToolColors.ink, height: 1.5),
              ),
              const SizedBox(height: KSpacing.lg),
              Directionality(
                textDirection: TextDirection.ltr,
                child: TextField(
                  key: SecondCameraScreen.codeKey,
                  controller: _code,
                  enabled: !joining,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  style: t.display.copyWith(
                    letterSpacing: 8,
                    color: LiveToolColors.ink,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '000000',
                    labelText: l10n.liveCam2CodeLabel,
                    errorText: _error,
                    errorMaxLines: 3,
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => unawaited(_join()),
                ),
              ),
              if (_error != null)
                Semantics(
                  liveRegion: true,
                  child: const SizedBox(
                    key: SecondCameraScreen.errorKey,
                    height: 0,
                  ),
                ),
              const SizedBox(height: KSpacing.md),
              KButton(
                key: SecondCameraScreen.joinKey,
                label: l10n.liveCam2JoinButton,
                loading: joining,
                onPressed: _code.text.trim().length == 6 && !joining
                    ? () => unawaited(_join())
                    : null,
              ),
              const SizedBox(height: KSpacing.lg),
              LiveToolNote(
                icon: Icons.privacy_tip_outlined,
                text: l10n.liveCam2JoinPermissions,
              ),
              // D251: after a failed join, the log can be sent.
              if (_error != null) ...[
                const SizedBox(height: KSpacing.md),
                Center(child: _copyLogButton(color: LiveToolColors.soft)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _noteText(AppLocalizations l10n, SecondCameraNote note) =>
      switch (note) {
        SecondCameraNote.keepAwake => l10n.liveCam2AwakeFailed,
        SecondCameraNote.background => l10n.liveCam2BackgroundFailed,
        SecondCameraNote.camera => l10n.liveCam2CameraSlow,
        SecondCameraNote.filters => l10n.liveCam2FilterFailed,
      };

  Widget _cameraView(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final engine = _engine;
    final mic = engine?.micEnabled ?? false;
    final filtersOn = engine != null && _filtersOn(engine);
    Widget control({
      required Key key,
      required IconData icon,
      required String label,
      required VoidCallback? onTap,
      Color color = const Color(0x66000000),
      bool badge = false,
    }) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              key: key,
              tooltip: label,
              iconSize: 28,
              style: IconButton.styleFrom(
                backgroundColor: color,
                disabledBackgroundColor: color,
                foregroundColor: const Color(0xFFFFFFFF),
                disabledForegroundColor: const Color(0x99FFFFFF),
                minimumSize: const Size(56, 56),
              ),
              onPressed: onTap,
              icon: Icon(icon),
            ),
            if (badge)
              const PositionedDirectional(
                top: 4,
                end: 4,
                child: SizedBox.square(
                  dimension: 10,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: LiveToolColors.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: t.caption.copyWith(color: const Color(0xFFFFFFFF)),
        ),
      ],
    );
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: Stack(
        fit: StackFit.expand,
        children: [
          KeyedSubtree(
            key: SecondCameraScreen.cameraKey,
            child:
                engine?.preview() ?? const ColoredBox(color: Color(0xFF000000)),
          ),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: KSpacing.sm),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
                  child: Row(
                    children: [
                      Flexible(
                        child: Container(
                          key: SecondCameraScreen.onAirKey,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0x99000000),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: engine?.connected ?? false
                                      ? LiveToolColors.rec
                                      : const Color(0xFFB0B0B8),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              // D243: large text never overflows the pill.
                              Flexible(
                                child: Text(
                                  engine?.connected ?? false
                                      ? l10n.liveCam2OnAir
                                      : l10n.liveCam2Connecting,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: t.label.copyWith(
                                    color: const Color(0xFFFFFFFF),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      // D251: the state log for support.
                      IconButton(
                        key: SecondCameraScreen.copyLogKey,
                        tooltip: l10n.liveCam2CopyLog,
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0x66000000),
                          foregroundColor: const Color(0xFFFFFFFF),
                        ),
                        onPressed: () => unawaited(_copyLog()),
                        icon: const Icon(Icons.receipt_long_rounded),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Padding(
                  key: SecondCameraScreen.keepOpenKey,
                  padding: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x99000000),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.liveCam2KeepOpen,
                          textAlign: TextAlign.center,
                          style: t.caption.copyWith(
                            color: const Color(0xFFFFFFFF),
                            height: 1.4,
                          ),
                        ),
                        // D251: what degraded (the camera goes on).
                        for (final note in SecondCameraNote.values)
                          if (_notes.contains(note))
                            Padding(
                              key: SecondCameraScreen.noteKey(note),
                              padding: const EdgeInsets.only(top: 6),
                              child: Semantics(
                                liveRegion: true,
                                child: Text(
                                  _noteText(l10n, note),
                                  textAlign: TextAlign.center,
                                  style: t.caption.copyWith(
                                    color: const Color(0xFFFFD9A8),
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: KSpacing.md),
                Padding(
                  padding: const EdgeInsets.only(bottom: KSpacing.lg),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Flexible(
                        child: control(
                          key: SecondCameraScreen.flipKey,
                          icon: Icons.flip_camera_ios_rounded,
                          label: l10n.liveCam2Flip,
                          onTap: _flipping ? null : () => unawaited(_flip()),
                        ),
                      ),
                      Flexible(
                        child: control(
                          key: SecondCameraScreen.filtersKey,
                          icon: Icons.auto_awesome_rounded,
                          label: l10n.liveToolMagic,
                          badge: filtersOn,
                          onTap: _openFilters,
                        ),
                      ),
                      Flexible(
                        child: control(
                          key: SecondCameraScreen.micKey,
                          icon: mic ? Icons.mic_rounded : Icons.mic_off_rounded,
                          label: mic ? l10n.liveCam2MicOff : l10n.liveCam2MicOn,
                          onTap: _micBusy
                              ? null
                              : () => unawaited(_toggleMic()),
                        ),
                      ),
                      Flexible(
                        child: control(
                          key: SecondCameraScreen.leaveKey,
                          icon: Icons.call_end_rounded,
                          label: l10n.liveCam2Leave,
                          color: LiveToolColors.rec,
                          onTap: () => unawaited(_leave()),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _endedView(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(KSpacing.lg),
            child: Column(
              key: SecondCameraScreen.endedKey,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.videocam_off_outlined,
                  size: 56,
                  color: LiveToolColors.soft,
                ),
                const SizedBox(height: KSpacing.md),
                Text(
                  l10n.liveCam2Ended,
                  textAlign: TextAlign.center,
                  style: t.body.copyWith(color: LiveToolColors.ink),
                ),
                const SizedBox(height: KSpacing.lg),
                KButton(
                  label: l10n.liveToolsClose,
                  onPressed: () => unawaited(_leave()),
                ),
                const SizedBox(height: KSpacing.sm),
                _copyLogButton(color: LiveToolColors.soft),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
