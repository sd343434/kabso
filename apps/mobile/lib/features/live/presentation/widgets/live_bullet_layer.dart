import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/application/live_chat_controller.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_audio_room.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Bullet messages over the live (CP-017, §10.19): each one flies once
/// across the upper part of the screen, from the end side to the start
/// side (right to left in English, left to right in Arabic), with the
/// sender's picture, name and text; several wait their turn. With reduced
/// motion it stands still for a few seconds instead. It never takes taps.
///
/// The bullets come from the room's chat ([liveChatProvider]), which drops
/// those from people this person blocked.
class LiveBulletLayer extends ConsumerStatefulWidget {
  const new({required this.roomId, super.key});

  final String roomId;

  static const bannerKey = Key('liveBullet.banner');

  /// One flight across the screen.
  static const flight = Duration(seconds: 7);

  /// How long a bullet stands still with reduced motion.
  static const still = Duration(seconds: 4);

  @override
  ConsumerState<LiveBulletLayer> createState() => _LiveBulletLayerState();
}

class _LiveBulletLayerState extends ConsumerState<LiveBulletLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: LiveBulletLayer.flight,
  );
  Timer? _still;
  String? _showing;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _still?.cancel();
    _motion.dispose();
    super.dispose();
  }

  void _done(String id) {
    if (_disposed || !mounted || _showing != id) return;
    _showing = null;
    _still?.cancel();
    _motion.stop();
    ref.read(liveChatProvider(widget.roomId).notifier).bulletShown(id);
  }

  void _start(LiveBullet bullet, {required bool reduced}) {
    _showing = bullet.id;
    _still?.cancel();
    // Started after this frame (never while building).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed || _showing != bullet.id) return;
      _run(bullet, reduced: reduced);
    });
  }

  void _run(LiveBullet bullet, {required bool reduced}) {
    if (reduced) {
      _still = Timer(LiveBulletLayer.still, () => _done(bullet.id));
    } else {
      _motion.forward(from: 0).whenCompleteOrCancel(() => _done(bullet.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bullets = ref.watch(
      liveChatProvider(widget.roomId).select((s) => s.bullets),
    );
    if (bullets.isEmpty) return const SizedBox.shrink();
    final bullet = bullets.first;
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (_showing != bullet.id) _start(bullet, reduced: reduced);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, box) {
          final width = box.maxWidth;
          return Stack(
            children: [
              PositionedDirectional(
                // The upper part: under the room bar, above the middle.
                top: box.maxHeight * 0.2,
                start: 0,
                end: 0,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: AnimatedBuilder(
                    animation: _motion,
                    builder: (context, child) {
                      if (reduced) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: child,
                        );
                      }
                      // From just past the end edge to just past the start
                      // edge (the banner is never wider than the screen).
                      final t = _motion.value;
                      final dx = width * (1 - 2 * t);
                      return Transform.translate(
                        offset: Offset(rtl ? -dx : dx, 0),
                        child: child,
                      );
                    },
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: width * 0.9),
                      child: _Banner(bullet: bullet),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const new({required this.bullet});

  final LiveBullet bullet;

  @override
  Widget build(BuildContext context) {
    final styles = context.textStyles;
    final name = bullet.sender.displayName;
    return Semantics(
      liveRegion: true,
      label: context.l10n.liveBulletLabel(name, bullet.text),
      excludeSemantics: true,
      child: Container(
        key: LiveBulletLayer.bannerKey,
        padding: const EdgeInsetsDirectional.only(
          start: 3,
          end: 14,
          top: 3,
          bottom: 3,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            colors: [Color(0xE66C4CF1), Color(0xE6FF5FA2)],
          ),
          border: Border.all(color: const Color(0x66FFFFFF)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            KAvatar(name: name, imageUrl: bullet.sender.avatarUrl, size: 32),
            const SizedBox(width: 8),
            Flexible(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: KFormat.bidiIsolate(name),
                      style: styles.caption.copyWith(
                        fontSize: 12.5,
                        color: const Color(0xFFFFE27A),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const TextSpan(text: '  '),
                    TextSpan(
                      text: KFormat.bidiIsolate(bullet.text),
                      style: styles.caption.copyWith(
                        fontSize: 13.5,
                        color: KAudioRoom.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textScaler: MediaQuery.textScalerOf(context)
                    .clamp(maxScaleFactor: KMetrics.overlayMaxTextScale),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
