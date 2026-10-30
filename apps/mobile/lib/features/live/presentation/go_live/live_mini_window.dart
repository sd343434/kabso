import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/application/live_background.dart';
import 'package:kabso_live/features/live/application/live_host_controller.dart';
import 'package:kabso_live/features/live/application/live_room_session.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_audio_room.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_theme_art.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// The host's minimized live (owner D94): a small floating window over the
/// whole app while the live goes on. It can be dragged; a tap opens the
/// live full screen again. Ending stays on the live screen's ✕.
class LiveMiniWindow extends ConsumerWidget {
  const new({required this.router, super.key});

  final GoRouter router;

  static const windowKey = Key('liveMini.window');
  static const closeKey = Key('liveMini.close');

  void _open(WidgetRef ref) {
    ref.read(liveMinimizedProvider.notifier).restore();
    unawaited(router.push(AppRoutes.goLive));
  }

  /// D181: the viewer's room full screen again (its screen restores it).
  void _openViewer(WidgetRef ref) {
    final room = ref.read(liveViewerMinimizedProvider);
    if (room == null) return;
    unawaited(router.push(AppRoutes.liveRoom(room.id)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // D123: a tap on the ongoing notification opens the minimized live.
    ref.listen(liveBackgroundOpenRequestsProvider, (_, _) {
      if (ref.read(liveMinimizedProvider)) _open(ref);
    });
    // D123: a tap on a guest's or listener's notification too (D181).
    ref.listen(liveBackgroundOpenRequestsProvider, (_, _) {
      if (!ref.read(liveMinimizedProvider)) _openViewer(ref);
    });
    if (!ref.watch(liveMinimizedProvider)) {
      // D181: a viewer's (or seated guest's) minimized room.
      final room = ref.watch(liveViewerMinimizedProvider);
      if (room == null) return const SizedBox.shrink();
      return Material(
        type: MaterialType.transparency,
        child: _Floating(
          label: context.l10n.liveMiniOpen,
          onOpen: () => _openViewer(ref),
          onClose: () => ref.read(liveViewerMinimizedProvider.notifier).leave(),
          child: _ViewerPicture(room: room),
        ),
      );
    }
    final state = ref.watch(liveHostControllerProvider);
    if (state.phase != GoLivePhase.live && state.phase != GoLivePhase.ending) {
      // Over (ended elsewhere, e.g. by the server): nothing to float.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(liveMinimizedProvider.notifier).restore();
      });
      return const SizedBox.shrink();
    }
    // D123: it floats over the app's navigator (above any Material), so it
    // brings its own text style (no fallback underlined yellow text).
    return Material(
      type: MaterialType.transparency,
      child: _Floating(
        label: context.l10n.goLiveBackToLive,
        onOpen: () => _open(ref),
        child: _Picture(state: state),
      ),
    );
  }
}

class _Floating extends StatefulWidget {
  const new({
    required this.child,
    required this.onOpen,
    required this.label,
    this.onClose,
  });

  final Widget child;
  final VoidCallback onOpen;
  final String label;

  /// D181: a viewer's window has ✕ (leave the live); the host ends theirs
  /// on the live screen.
  final VoidCallback? onClose;

  static const size = Size(108, 156);

  @override
  State<_Floating> createState() => _FloatingState();
}

class _FloatingState extends State<_Floating> {
  /// The window's top-left corner; `null` until the first layout.
  Offset? _at;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final area = media.size;
    final pad = media.padding;
    const size = _Floating.size;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    // Starts at the reading end, above the bottom navigation.
    final start =
        _at ??
        Offset(
          rtl ? KSpacing.md : area.width - size.width - KSpacing.md,
          area.height -
              size.height -
              pad.bottom -
              KSizes.bottomNavHeight -
              KSpacing.lg,
        );
    Offset clamp(Offset o) => Offset(
      o.dx.clamp(KSpacing.xs, area.width - size.width - KSpacing.xs),
      o.dy.clamp(
        pad.top + KSpacing.xs,
        area.height - size.height - pad.bottom - KSpacing.xs,
      ),
    );
    return Stack(
      children: [
        Positioned(
          left: start.dx,
          top: start.dy,
          child: GestureDetector(
            key: LiveMiniWindow.windowKey,
            onTap: widget.onOpen,
            onPanUpdate: (d) => setState(() => _at = clamp(start + d.delta)),
            child: Semantics(
              button: true,
              label: widget.label,
              excludeSemantics: true,
              child: Container(
                width: size.width,
                height: size.height,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(KRadius.lg),
                  border: Border.all(color: KBrandColors.red400, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: KBrandColors.red500.withValues(alpha: 0.45),
                      blurRadius: 16,
                    ),
                    const BoxShadow(color: Color(0x66000000), blurRadius: 10),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(KRadius.lg - 1),
                  child: widget.child,
                ),
              ),
            ),
          ),
        ),
        if (widget.onClose case final close?)
          Positioned(
            // ✕ at the window's top end corner, a 32 pt target.
            left: rtl ? start.dx - 6 : start.dx + size.width - 26,
            top: start.dy - 6,
            child: Semantics(
              button: true,
              label: context.l10n.liveMiniLeave,
              excludeSemantics: true,
              child: GestureDetector(
                key: LiveMiniWindow.closeKey,
                behavior: HitTestBehavior.opaque,
                onTap: close,
                child: const SizedBox.square(
                  dimension: 32,
                  child: Center(
                    child: CircleAvatar(
                      radius: 11,
                      backgroundColor: Color(0xE6000000),
                      child: Icon(
                        Icons.close_rounded,
                        size: 14,
                        color: Color(0xFFFFFFFF),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Picture extends ConsumerStatefulWidget {
  const new({required this.state});

  final GoLiveState state;

  @override
  ConsumerState<_Picture> createState() => _PictureState();
}

class _PictureState extends ConsumerState<_Picture> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final user = ref.watch(currentUserProvider);
    final engine = ref.read(liveHostControllerProvider.notifier).engine;
    final camera = state.mode == LiveRoomMode.audio ? null : engine.preview();
    final since = state.liveSince;
    final elapsed = formatLiveDuration(
      since == null ? Duration.zero : clock.now().difference(since),
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        if (camera != null)
          camera
        else ...[
          LiveThemeBackground(
            theme: state.mode.hasSeats ? state.theme : LiveThemes.classic,
            waves: state.mode == LiveRoomMode.audio,
          ),
          Center(
            child: KAvatar(
              name: user?.displayName ?? '',
              imageUrl: user?.avatarUrl,
              size: 56,
            ),
          ),
        ],
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.center,
              colors: [Color(0x99000000), Color(0x00000000)],
            ),
          ),
        ),
        PositionedDirectional(
          top: KSpacing.xs + 2,
          start: KSpacing.xs + 2,
          end: KSpacing.xs + 2,
          child: Row(
            children: [
              const KBadge.live(),
              const SizedBox(width: KSpacing.xs),
              Flexible(
                child: Text(
                  elapsed,
                  maxLines: 1,
                  textDirection: TextDirection.ltr,
                  style: context.textStyles.caption.copyWith(
                    color: KPalette.dark.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!state.micEnabled)
          const PositionedDirectional(
            bottom: KSpacing.xs + 2,
            end: KSpacing.xs + 2,
            child: CircleAvatar(
              radius: 11,
              backgroundColor: Color(0xCC000000),
              child: Icon(
                Icons.mic_off_rounded,
                size: 14,
                color: Color(0xFFFFFFFF),
              ),
            ),
          ),
      ],
    );
  }
}

/// D181: a viewer's minimized room — the host's video (video rooms), or the
/// room's theme with the host's picture, ringing while they speak (audio).
class _ViewerPicture extends ConsumerWidget {
  const new({required this.room});

  final LiveRoom room;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(liveRoomSessionProvider(room.id));
    final current = session.room ?? room;
    if (session.kicked || current.status != LiveRoomStatus.live) {
      // Over or removed: nothing to float.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(liveViewerMinimizedProvider.notifier).leave();
      });
    }
    final engine = ref.read(liveRoomSessionProvider(room.id).notifier).engine;
    final host = current.host;
    return ListenableBuilder(
      listenable: engine.changes,
      builder: (context, _) {
        final video = current.mode == LiveRoomMode.audio
            ? null
            : engine.remoteVideo(host.id);
        return Stack(
          fit: StackFit.expand,
          children: [
            if (video != null)
              video
            else ...[
              LiveThemeBackground(
                theme: current.mode.hasSeats
                    ? current.theme
                    : LiveThemes.classic,
                waves: current.mode == LiveRoomMode.audio,
              ),
              Center(
                child: _SpeakingRing(
                  on: engine.speaking.contains(host.id),
                  child: KAvatar(
                    name: host.displayName,
                    imageUrl: host.avatarUrl,
                    size: 56,
                  ),
                ),
              ),
            ],
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.center,
                  colors: [Color(0x99000000), Color(0x00000000)],
                ),
              ),
            ),
            const PositionedDirectional(
              top: KSpacing.xs + 2,
              start: KSpacing.xs + 2,
              child: KBadge.live(),
            ),
            PositionedDirectional(
              bottom: KSpacing.xs + 2,
              start: KSpacing.xs + 2,
              end: KSpacing.xs + 2,
              child: Text(
                host.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textStyles.caption.copyWith(
                  color: KPalette.dark.textPrimary,
                  fontWeight: FontWeight.w700,
                  shadows: const [
                    Shadow(color: Color(0x99000000), blurRadius: 4),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// D181: the host's picture pulses while they speak.
class _SpeakingRing extends StatefulWidget {
  const new({required this.on, required this.child});

  final bool on;
  final Widget child;

  @override
  State<_SpeakingRing> createState() => _SpeakingRingState();
}

class _SpeakingRingState extends State<_SpeakingRing>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(_SpeakingRing old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.on && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.on && _pulse.isAnimating) {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _pulse,
    builder: (context, child) => DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: widget.on
            ? [
                BoxShadow(
                  color: const Color(0xFF34E0C8).withValues(alpha: 0.75),
                  spreadRadius: 2 + 4 * _pulse.value,
                  blurRadius: 8 + 6 * _pulse.value,
                ),
              ]
            : const [],
      ),
      child: child,
    ),
    child: widget.child,
  );
}
