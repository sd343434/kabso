import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/application/live_host_controller.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/go_live_screen.dart';
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(liveMinimizedProvider)) return const SizedBox.shrink();
    final state = ref.watch(liveHostControllerProvider);
    if (state.phase != GoLivePhase.live && state.phase != GoLivePhase.ending) {
      // Over (ended elsewhere, e.g. by the server): nothing to float.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(liveMinimizedProvider.notifier).restore();
      });
      return const SizedBox.shrink();
    }
    return _Floating(
      onOpen: () {
        ref.read(liveMinimizedProvider.notifier).restore();
        unawaited(router.push(AppRoutes.goLive));
      },
      child: _Picture(state: state),
    );
  }
}

class _Floating extends StatefulWidget {
  const new({required this.child, required this.onOpen});

  final Widget child;
  final VoidCallback onOpen;

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
              label: context.l10n.goLiveBackToLive,
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
