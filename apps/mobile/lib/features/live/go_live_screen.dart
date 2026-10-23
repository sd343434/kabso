import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/create/create_mode_bar.dart';
import 'package:kabso_live/features/live/application/live_host_controller.dart';
import 'package:kabso_live/features/live/data/live_media_engine.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_view_data.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// `/live/new` — go live (CP-010 L1), laid out after the owner's camera
/// reference with only the tools that work: the full camera preview, close
/// at the reading start, the title in the top pill, the side rail (flip,
/// microphone, guests), the categories above the big start button, and
/// Post · Story · LIVE at the bottom.
///
/// Gates, in order: `GET /live/config` `hostingEnabled`, then the account's
/// hosting permission (`Me.canHost`, agencies and identity in L1b); the
/// camera starts only when both pass. Then camera/microphone denied or
/// missing, starting, live (elapsed time, end with confirmation, guests
/// switch through `PATCH /live/rooms/{id}`) and ended.
class GoLiveScreen extends ConsumerStatefulWidget {
  const new({super.key});

  static const closeKey = Key('goLive.close');
  static const titleKey = Key('goLive.title');
  static const flipKey = Key('goLive.flip');
  static const micKey = Key('goLive.mic');
  static const guestsKey = Key('goLive.guests');
  static const startKey = Key('goLive.start');
  static const endKey = Key('goLive.end');
  static const endConfirmKey = Key('goLive.endConfirm');
  static const doneKey = Key('goLive.done');
  static const retryKey = Key('goLive.retry');
  static const elapsedKey = Key('goLive.elapsed');
  static const notAllowedKey = Key('goLive.notAllowed');
  static const unavailableKey = Key('goLive.unavailable');
  static const captureFailedKey = Key('goLive.captureFailed');
  static const endedKey = Key('goLive.ended');
  static Key categoryKey(String? slug) => Key('goLive.category.${slug ?? ''}');

  /// The title limit (CONVENTIONS §10.3: 1–80 grapheme clusters).
  static const titleMaxLength = 80;

  @override
  ConsumerState<GoLiveScreen> createState() => _GoLiveScreenState();
}

class _GoLiveScreenState extends ConsumerState<GoLiveScreen> {
  final _title = TextEditingController();
  final _titleFocus = FocusNode();
  String? _category;
  bool _previewRequested = false;
  Timer? _tick;

  @override
  void dispose() {
    _tick?.cancel();
    _title.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  LiveHostController get _host => ref.read(liveHostControllerProvider.notifier);

  void _close() {
    final router = GoRouter.maybeOf(context);
    if (router == null) {
      Navigator.of(context).maybePop();
    } else if (router.canPop()) {
      router.pop();
    } else {
      router.go(AppRoutes.home);
    }
  }

  void _requestPreview() {
    if (_previewRequested) return;
    _previewRequested = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_host.startPreview());
    });
  }

  Future<void> _start() async {
    final l10n = context.l10n;
    final title = _title.text.trim();
    if (title.isEmpty) {
      _titleFocus.requestFocus();
      KSnack.info(context, l10n.goLiveTitleRequired);
      return;
    }
    _titleFocus.unfocus();
    try {
      await _host.goLive(title: title, categorySlug: _category);
    } on Object catch (e) {
      if (mounted) KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
    }
  }

  Future<void> _confirmEnd() async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l10n.goLiveEndConfirmTitle),
        content: Text(l10n.goLiveEndConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(l10n.goLiveKeepGoing),
          ),
          TextButton(
            key: GoLiveScreen.endConfirmKey,
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(l10n.goLiveEndConfirm),
          ),
        ],
      ),
    );
    if (ok ?? false) await _host.end();
  }

  Future<void> _toggleGuests(GoLiveState state) async {
    final l10n = context.l10n;
    final allow = !state.allowGuests;
    try {
      await _host.setAllowGuests(allow: allow);
      if (mounted && state.phase == GoLivePhase.live) {
        KSnack.info(
          context,
          allow ? l10n.goLiveGuestsOn : l10n.goLiveGuestsOff,
        );
      }
    } on Object catch (e) {
      if (mounted) KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
    }
  }

  void _onMode(CreateMode mode) {
    final router = GoRouter.of(context);
    switch (mode) {
      case CreateMode.post:
        if (router.canPop()) {
          router.pop();
        } else {
          router.go(AppRoutes.create);
        }
      case CreateMode.story:
        unawaited(router.pushReplacement(AppRoutes.newStory));
      case CreateMode.live:
        break;
    }
  }

  void _syncTicker(GoLiveState state) {
    final live = state.phase == GoLivePhase.live;
    if (live && _tick == null) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!live && _tick != null) {
      _tick!.cancel();
      _tick = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final config = ref.watch(liveConfigProvider);
    final canHost = ref.watch(
      currentUserProvider.select((u) => u?.canHost ?? false),
    );
    final state = ref.watch(liveHostControllerProvider);
    _syncTicker(state);

    final Widget stage;
    var showTools = false;
    switch (config) {
      case AsyncData(:final value) when !value.hostingEnabled:
        stage = _Notice(
          key: GoLiveScreen.unavailableKey,
          icon: Icons.sensors_off_outlined,
          title: l10n.goLiveUnavailableTitle,
          body: l10n.errorLiveHostingUnavailable,
        );
      case AsyncData() when !canHost:
        stage = _Notice(
          key: GoLiveScreen.notAllowedKey,
          icon: Icons.verified_user_outlined,
          title: l10n.goLiveNotAllowedTitle,
          body: l10n.goLiveNotAllowedBody,
        );
      case AsyncData():
        _requestPreview();
        stage = _cameraStage(state);
        showTools = true;
      case AsyncError(:final error):
        stage = _Notice(
          icon: Icons.error_outline_rounded,
          title: l10n.liveRoomErrorTitle,
          body: failureMessage(l10n, toAppFailure(error)),
          onRetry: () => ref.invalidate(liveConfigProvider),
        );
      default:
        stage = const _Spinner();
    }

    final onAir =
        state.phase == GoLivePhase.live || state.phase == GoLivePhase.ending;
    final ended = state.phase == GoLivePhase.ended;
    final busy =
        state.phase == GoLivePhase.starting ||
        state.phase == GoLivePhase.ending;
    final previewing = showTools && state.phase == GoLivePhase.preview;
    const p = KPalette.dark;

    return PopScope(
      canPop: !onAir && !busy,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && state.phase == GoLivePhase.live) {
          unawaited(_confirmEnd());
        }
      },
      child: KLiveSurface(
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: Scaffold(
            backgroundColor: p.background,
            resizeToAvoidBottomInset: false,
            body: Column(
              children: [
                Expanded(
                  child: SafeArea(
                    bottom: onAir || ended,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(KRadius.lg),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ColoredBox(color: p.surface, child: stage),
                          const _TopShade(),
                          if (ended)
                            _Ended(state: state, onDone: _close)
                          else ...[
                            PositionedDirectional(
                              top: KSpacing.sm,
                              start: KSpacing.sm,
                              end: KSpacing.sm,
                              child: _TopBar(
                                onClose: onAir
                                    ? (state.phase == GoLivePhase.live
                                          ? () => unawaited(_confirmEnd())
                                          : null)
                                    : (busy ? null : _close),
                                center: onAir
                                    ? _LiveClock(
                                        since: state.liveSince,
                                        title: _title.text.trim(),
                                      )
                                    : showTools
                                    ? _TitlePill(
                                        controller: _title,
                                        focusNode: _titleFocus,
                                        enabled: previewing,
                                      )
                                    : null,
                              ),
                            ),
                            if (showTools && (previewing || onAir || busy))
                              PositionedDirectional(
                                top: KSpacing.xxxl + KSpacing.xl,
                                end: KSpacing.sm,
                                child: _Rail(
                                  state: state,
                                  enabled: !busy,
                                  onFlip: () => unawaited(_host.flipCamera()),
                                  onMic: () => unawaited(_host.toggleMic()),
                                  onGuests: () =>
                                      unawaited(_toggleGuests(state)),
                                ),
                              ),
                            if (showTools &&
                                state.phase != GoLivePhase.captureFailed &&
                                state.phase != GoLivePhase.preparing)
                              PositionedDirectional(
                                start: 0,
                                end: 0,
                                bottom: KSpacing.lg,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (!onAir)
                                      _Categories(
                                        selected: _category,
                                        enabled: previewing,
                                        onSelect: (slug) =>
                                            setState(() => _category = slug),
                                      ),
                                    const SizedBox(height: KSpacing.lg),
                                    if (onAir)
                                      _EndButton(
                                        onPressed:
                                            state.phase == GoLivePhase.live
                                            ? () => unawaited(_confirmEnd())
                                            : null,
                                      )
                                    else
                                      _StartButton(
                                        busy: busy,
                                        onPressed: previewing
                                            ? () => unawaited(_start())
                                            : null,
                                      ),
                                  ],
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                if (!onAir && !ended)
                  ColoredBox(
                    color: p.background,
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: KSpacing.xs,
                        ),
                        child: IgnorePointer(
                          ignoring: busy,
                          child: CreateModeBar(
                            selected: CreateMode.live,
                            onSelect: _onMode,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _cameraStage(GoLiveState state) {
    final l10n = context.l10n;
    switch (state.phase) {
      case GoLivePhase.preparing:
        return const _Spinner();
      case GoLivePhase.captureFailed:
        final denied = state.capture == LiveCaptureProblem.denied;
        return _Notice(
          key: GoLiveScreen.captureFailedKey,
          icon: denied
              ? Icons.no_photography_outlined
              : Icons.videocam_off_outlined,
          title: denied
              ? l10n.goLiveCameraDeniedTitle
              : l10n.goLiveCameraUnavailableTitle,
          body: denied
              ? l10n.goLiveCameraDeniedBody
              : l10n.goLiveCameraUnavailableBody,
          onRetry: () => unawaited(_host.startPreview()),
        );
      case GoLivePhase.preview ||
          GoLivePhase.starting ||
          GoLivePhase.live ||
          GoLivePhase.ending ||
          GoLivePhase.ended:
        final picture = _host.engine.preview();
        return picture == null
            ? const SizedBox.expand()
            : SizedBox.expand(key: ValueKey(state.frontCamera), child: picture);
    }
  }
}

class _Spinner extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => Center(
    child: CircularProgressIndicator(
      valueColor: AlwaysStoppedAnimation(KPalette.dark.textPrimary),
    ),
  );
}

/// A centred explanation over the empty stage (gates, camera problems).
class _Notice extends StatelessWidget {
  const new({
    required this.icon,
    required this.title,
    required this.body,
    super.key,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = context.textStyles;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: KSpacing.xxl,
          vertical: KSpacing.xxxl * 2,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: KSpacing.xxxl, color: p.textSecondary),
            const SizedBox(height: KSpacing.lg),
            Semantics(
              header: true,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: text.title,
              ),
            ),
            const SizedBox(height: KSpacing.sm),
            Text(
              body,
              textAlign: TextAlign.center,
              style: text.body.copyWith(color: p.textSecondary),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: KSpacing.xl),
              KButton(
                key: GoLiveScreen.retryKey,
                label: context.l10n.actionRetry,
                onPressed: onRetry,
                expand: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Keeps the top controls legible over a bright picture.
class _TopShade extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => const Align(
    alignment: Alignment.topCenter,
    child: IgnorePointer(
      child: SizedBox(
        height: KSpacing.xxxl * 3,
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [KLiveColors.chatScrim, Color(0x00000000)],
            ),
          ),
        ),
      ),
    ),
  );
}

class _TopBar extends StatelessWidget {
  const new({required this.onClose, required this.center});

  final VoidCallback? onClose;
  final Widget? center;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final center = this.center;
    return Row(
      children: [
        IconButton(
          key: GoLiveScreen.closeKey,
          tooltip: context.l10n.liveClose,
          onPressed: onClose,
          icon: Icon(Icons.close_rounded, color: p.textPrimary, size: 30),
        ),
        Expanded(
          child: center == null ? const SizedBox() : Center(child: center),
        ),
        // Balances the close button so the pill stays centred.
        const SizedBox(width: KSizes.minTouchTarget),
      ],
    );
  }
}

/// The title, where the reference has its sound pill.
class _TitlePill extends StatelessWidget {
  const new({
    required this.controller,
    required this.focusNode,
    required this.enabled,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = context.textStyles;
    return Container(
      constraints: const BoxConstraints(maxWidth: 240, minHeight: 36),
      padding: const EdgeInsetsDirectional.only(
        start: KSpacing.md,
        end: KSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: KLiveColors.chatScrim,
        borderRadius: BorderRadius.circular(KRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.edit_outlined, size: 18, color: p.textPrimary),
          const SizedBox(width: KSpacing.sm),
          Flexible(
            child: IntrinsicWidth(
              child: TextField(
                key: GoLiveScreen.titleKey,
                controller: controller,
                focusNode: focusNode,
                enabled: enabled,
                maxLength: GoLiveScreen.titleMaxLength,
                textInputAction: TextInputAction.done,
                style: text.label.copyWith(
                  color: p.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                cursorColor: p.primary,
                decoration: InputDecoration(
                  isCollapsed: true,
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  counterText: '',
                  hintText: context.l10n.goLiveTitleHint,
                  hintStyle: text.label.copyWith(
                    color: p.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: KSpacing.sm + KSpacing.xxs,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// LIVE · elapsed time and the title while on air.
class _LiveClock extends StatelessWidget {
  const new({required this.since, required this.title});

  final DateTime? since;
  final String title;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = context.textStyles;
    final elapsed = formatLiveDuration(
      since == null ? Duration.zero : clock.now().difference(since!),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          key: GoLiveScreen.elapsedKey,
          label: context.l10n.goLiveElapsed(elapsed),
          excludeSemantics: true,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const KBadge.live(),
              const SizedBox(width: KSpacing.sm),
              Text(
                elapsed,
                textDirection: TextDirection.ltr,
                style: text.label.copyWith(
                  color: p.textPrimary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
        if (title.isNotEmpty) ...[
          const SizedBox(height: KSpacing.xs),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.caption.copyWith(color: p.textPrimary),
          ),
        ],
      ],
    );
  }
}

/// `m:ss`, or `h:mm:ss` from an hour.
String formatLiveDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
}

/// Flip, microphone and guests, at the reading end like the reference.
class _Rail extends StatelessWidget {
  const new({
    required this.state,
    required this.enabled,
    required this.onFlip,
    required this.onMic,
    required this.onGuests,
  });

  final GoLiveState state;
  final bool enabled;
  final VoidCallback onFlip;
  final VoidCallback onMic;
  final VoidCallback onGuests;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final camera = state.phase != GoLivePhase.captureFailed;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (camera) ...[
          _RailButton(
            key: GoLiveScreen.flipKey,
            icon: Icons.flip_camera_ios_outlined,
            label: l10n.goLiveFlip,
            onPressed: enabled ? onFlip : null,
          ),
          _RailButton(
            key: GoLiveScreen.micKey,
            icon: state.micEnabled
                ? Icons.mic_none_rounded
                : Icons.mic_off_outlined,
            label: state.micEnabled ? l10n.goLiveMic : l10n.goLiveMicOff,
            toggled: state.micEnabled,
            onPressed: enabled ? onMic : null,
          ),
        ],
        _RailButton(
          key: GoLiveScreen.guestsKey,
          icon: state.allowGuests
              ? Icons.groups_outlined
              : Icons.no_accounts_outlined,
          label: l10n.goLiveGuests,
          hint: state.allowGuests
              ? l10n.goLiveGuestsOnHint
              : l10n.goLiveGuestsOffHint,
          toggled: state.allowGuests,
          onPressed: enabled ? onGuests : null,
        ),
      ],
    );
  }
}

class _RailButton extends StatelessWidget {
  const new({
    required this.icon,
    required this.label,
    required this.onPressed,
    super.key,
    this.toggled,
    this.hint,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool? toggled;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    const shadow = [Shadow(color: KLiveColors.chatScrim, blurRadius: 6)];
    return Semantics(
      button: true,
      toggled: toggled,
      hint: hint,
      enabled: onPressed != null,
      excludeSemantics: true,
      label: label,
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: KSizes.minTouchTarget + KSpacing.lg,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: KSpacing.sm),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 28, color: p.textPrimary, shadows: shadow),
                const SizedBox(height: KSpacing.xxs),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: context.textStyles.caption.copyWith(
                    color: p.textPrimary,
                    shadows: shadow,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// No category + the server's categories, where the reference has its
/// durations. Hidden while there are none.
class _Categories extends ConsumerWidget {
  const new({
    required this.selected,
    required this.enabled,
    required this.onSelect,
  });

  final String? selected;
  final bool enabled;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(liveCategoriesProvider).value ?? const [];
    if (categories.isEmpty) return const SizedBox.shrink();
    final p = context.palette;
    final text = context.textStyles;
    Widget chip(String? slug, String label) {
      final on = slug == selected;
      return Semantics(
        button: true,
        selected: on,
        child: InkWell(
          key: GoLiveScreen.categoryKey(slug),
          borderRadius: BorderRadius.circular(KRadius.pill),
          onTap: enabled ? () => onSelect(slug) : null,
          child: Container(
            constraints: const BoxConstraints(minHeight: KSpacing.xxl),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: KSpacing.md),
            decoration: BoxDecoration(
              color: on ? KLiveColors.chatScrim : null,
              borderRadius: BorderRadius.circular(KRadius.pill),
            ),
            child: Text(
              label,
              maxLines: 1,
              style: text.label.copyWith(
                color: on ? p.textPrimary : p.textSecondary,
                fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                shadows: const [
                  Shadow(color: KLiveColors.chatScrim, blurRadius: 6),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
      child: Row(
        children: [
          chip(null, context.l10n.goLiveNoCategory),
          for (final c in categories) chip(c.slug, c.name),
        ],
      ),
    );
  }
}

/// The big round button: a white ring around the brand red.
class _StartButton extends StatelessWidget {
  const new({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback? onPressed;

  static const _ring = 84.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: busy ? l10n.goLiveStarting : l10n.goLiveStart,
      excludeSemantics: true,
      child: GestureDetector(
        key: GoLiveScreen.startKey,
        onTap: onPressed,
        child: Container(
          width: _ring,
          height: _ring,
          padding: const EdgeInsets.all(KSpacing.xs + KSpacing.xxs),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: p.textPrimary.withValues(alpha: 0.9),
              width: KSpacing.xs + 1,
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: onPressed == null && !busy
                  ? p.primary.withValues(alpha: 0.5)
                  : p.primary,
            ),
            child: Center(
              child: busy
                  ? SizedBox.square(
                      dimension: KSpacing.xl,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation(p.onPrimary),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(KSpacing.xs),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          l10n.goLiveStart,
                          maxLines: 1,
                          style: context.textStyles.label.copyWith(
                            color: p.onPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// End, in place of the start button while on air.
class _EndButton extends StatelessWidget {
  const new({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: context.l10n.goLiveEndConfirm,
      excludeSemantics: true,
      child: GestureDetector(
        key: GoLiveScreen.endKey,
        onTap: onPressed,
        child: Container(
          width: _StartButton._ring,
          height: _StartButton._ring,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: KLiveColors.chatScrim,
            border: Border.all(color: p.primary, width: KSpacing.xs + 1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: KSpacing.lg + KSpacing.xs,
                height: KSpacing.lg + KSpacing.xs,
                decoration: BoxDecoration(
                  color: p.primary,
                  borderRadius: BorderRadius.circular(KRadius.xs),
                ),
              ),
              const SizedBox(height: KSpacing.xs),
              Text(
                context.l10n.goLiveEnd,
                style: context.textStyles.caption.copyWith(
                  color: p.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Over: the duration and Done.
class _Ended extends StatelessWidget {
  const new({required this.state, required this.onDone});

  final GoLiveState state;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final text = context.textStyles;
    final since = state.liveSince;
    final until = state.endedAt ?? clock.now();
    final duration = formatLiveDuration(
      since == null ? Duration.zero : until.difference(since),
    );
    return ColoredBox(
      key: GoLiveScreen.endedKey,
      color: p.background,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(KSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.sensors_off_outlined,
                size: KSpacing.xxxl,
                color: p.textSecondary,
              ),
              const SizedBox(height: KSpacing.lg),
              Semantics(
                header: true,
                child: Text(
                  l10n.goLiveEndedTitle,
                  textAlign: TextAlign.center,
                  style: text.title,
                ),
              ),
              const SizedBox(height: KSpacing.sm),
              Text(
                l10n.goLiveEndedDuration(duration),
                style: text.body.copyWith(color: p.textSecondary),
              ),
              const SizedBox(height: KSpacing.xl),
              KButton(
                key: GoLiveScreen.doneKey,
                label: l10n.goLiveDone,
                onPressed: onDone,
                expand: false,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
