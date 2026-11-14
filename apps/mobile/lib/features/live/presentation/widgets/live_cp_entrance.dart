import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/cp/application/cp_providers.dart';
import 'package:kabso_live/features/cp/domain/cp_models.dart';
import 'package:kabso_live/features/live/application/live_chat_controller.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// The Entrance Effect (CP-021, D112, CONVENTIONS §10.24): when a `join`
/// data message carries `cp` (the joiner's couple unlocked
/// `ENTRANCE_EFFECT`, CP level 4), a pink banner with the owner's entrance
/// art (`assets/cp_space/privilege_entrance.webp`) slides in over the room:
/// "joiner and partner" and the CP level's name, about 3 s. Several arrive
/// one after another (at most [maxQueued] waiting); normal joins show
/// nothing here (their chat line is unchanged). Never takes taps. With
/// reduced motion (`MediaQuery.disableAnimations`) or [animate] off it
/// stands still for a shorter time.
class LiveCpEntranceLayer extends ConsumerStatefulWidget {
  const new({required this.roomId, super.key});

  final String roomId;

  /// Tests and captures turn the slide off (the banner still shows and
  /// leaves on time).
  static bool animate = true;

  static const bannerKey = Key('live.cpEntrance');

  /// How long one entrance shows (slide in, stay, slide out).
  static const duration = Duration(milliseconds: 3200);

  /// How long one shows without motion.
  static const stillDuration = Duration(milliseconds: 2200);

  /// Entrances waiting behind the one on screen; more are dropped.
  static const maxQueued = 5;

  @override
  ConsumerState<LiveCpEntranceLayer> createState() =>
      _LiveCpEntranceLayerState();
}

class _LiveCpEntranceLayerState extends ConsumerState<LiveCpEntranceLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock;
  final _queue = Queue<LiveChatJoinLine>();
  LiveChatJoinLine? _current;

  /// Keeps the CP tiers (level names) loaded once a CP entrance came, so
  /// later ones show the name at once.
  ProviderSubscription<AsyncValue<CpConfig>>? _tiers;

  /// The newest join already looked at (the one already shown when this
  /// layer appears is not replayed). D119: joins are the chat's
  /// `latestJoin`, not lines.
  int _seen = -1;

  @override
  void initState() {
    super.initState();
    _clock = AnimationController(vsync: this)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _next();
      });
    _seen = ref.read(liveChatProvider(widget.roomId)).latestJoin?.serial ?? -1;
  }

  @override
  void dispose() {
    _tiers?.close();
    _clock.dispose();
    super.dispose();
  }

  void _onChat(LiveChatState next) {
    if (next.latestJoin case final line?) {
      if (line.serial <= _seen) return;
      _seen = line.serial;
      if (line.cp == null) return;
      _tiers ??= ref.listenManual(cpConfigProvider, (_, _) {});
      if (_current == null) {
        _show(line);
      } else if (_queue.length < LiveCpEntranceLayer.maxQueued) {
        _queue.add(line);
      }
    }
  }

  void _show(LiveChatJoinLine line) {
    final still =
        !LiveCpEntranceLayer.animate || MediaQuery.disableAnimationsOf(context);
    _clock.duration = still
        ? LiveCpEntranceLayer.stillDuration
        : LiveCpEntranceLayer.duration;
    setState(() => _current = line);
    _clock.forward(from: 0);
  }

  void _next() {
    if (!mounted) return;
    if (_queue.isEmpty) {
      setState(() => _current = null);
    } else {
      _show(_queue.removeFirst());
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(liveChatProvider(widget.roomId), (_, next) => _onChat(next));
    final current = _current;
    final cp = current?.cp;
    if (current == null || cp == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    // The level's name from the server's tiers (app language); "Lv.N"
    // until they are loaded or when they fail.
    final tiers = ref.watch(cpConfigProvider).value?.tiers;
    final levelName =
        tiers?.where((t) => t.level == cp.level).firstOrNull?.name ??
        l10n.cpSpaceLevel(cp.level);
    final moving =
        LiveCpEntranceLayer.animate && !MediaQuery.disableAnimationsOf(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final banner = _CpEntranceBanner(
      key: ValueKey('cpEntrance.${current.serial}'),
      name: _name(current.user.displayName, current.user.username),
      partner: _name(cp.partner.displayName, cp.partner.username),
      level: levelName,
    );
    return IgnorePointer(
      child: Align(
        // Between the seats (or the stage) and the chat, under the gift
        // banners.
        alignment: const Alignment(0, 0.3),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
          child: moving
              ? AnimatedBuilder(
                  animation: _clock,
                  builder: (context, child) {
                    final t = _clock.value;
                    // In from the reading end, a short stay, out to the
                    // reading start.
                    final double dx;
                    final double opacity;
                    if (t < 0.14) {
                      final k = Curves.easeOutCubic.transform(t / 0.14);
                      dx = 1.2 * (1 - k);
                      opacity = k;
                    } else if (t > 0.86) {
                      final k = Curves.easeInCubic.transform((t - 0.86) / 0.14);
                      dx = -1.2 * k;
                      opacity = 1 - k;
                    } else {
                      dx = 0;
                      opacity = 1;
                    }
                    return Opacity(
                      opacity: opacity.clamp(0, 1),
                      child: FractionalTranslation(
                        translation: Offset(rtl ? -dx : dx, 0),
                        child: child,
                      ),
                    );
                  },
                  child: banner,
                )
              : banner,
        ),
      ),
    );
  }

  static String _name(String displayName, String username) =>
      KFormat.bidiIsolate(displayName.isEmpty ? username : displayName);
}

/// The banner itself: the entrance art at the start (rising above the
/// pill), "joiner and partner" and the level under it.
class _CpEntranceBanner extends StatelessWidget {
  const new({
    required this.name,
    required this.partner,
    required this.level,
    super.key,
  });

  final String name;
  final String partner;
  final String level;

  static const art = 'assets/cp_space/privilege_entrance.webp';
  static const heart = 'assets/cp_space/heart.webp';

  /// Pink to violet from the entrance art's door and corridor; white text
  /// stays readable on both ends.
  static const colors = [Color(0xFFD12F7F), Color(0xFF9233C8)];
  static const edge = Color(0xFFFFD27A);
  static const subtitle = Color(0xFFFFF0B8);
  static const height = 54.0;
  static const artSize = 74.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final scaler = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: KMetrics.overlayMaxTextScale);
    final couple = l10n.liveCpEntranceCouple(name, partner);
    final line = l10n.liveCpEntranceLevel(level);
    return Semantics(
      liveRegion: true,
      label: '$couple. $line',
      excludeSemantics: true,
      child: ConstrainedBox(
        key: LiveCpEntranceLayer.bannerKey,
        constraints: const BoxConstraints(maxWidth: 340),
        child: SizedBox(
          height: artSize,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: AlignmentDirectional.bottomStart,
            children: [
              Container(
                height: height,
                padding: const EdgeInsetsDirectional.only(
                  start: artSize + 2,
                  end: KSpacing.md,
                ),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: AlignmentDirectional.centerStart,
                    end: AlignmentDirectional.centerEnd,
                    colors: colors,
                  ),
                  borderRadius: BorderRadius.all(Radius.circular(height / 2)),
                  border: Border.fromBorderSide(
                    BorderSide(color: edge, width: 1.5),
                  ),
                  boxShadow: [
                    BoxShadow(color: Color(0x88FF4FA0), blurRadius: 16),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            couple,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textScaler: scaler,
                            style: t.bodyStrong.copyWith(
                              color: const Color(0xFFFFFFFF),
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                            ),
                          ),
                          Text(
                            line,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textScaler: scaler,
                            style: t.caption.copyWith(
                              color: subtitle,
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: KSpacing.xs),
                    Image.asset(
                      heart,
                      width: 22,
                      height: 22,
                      excludeFromSemantics: true,
                    ),
                  ],
                ),
              ),
              PositionedDirectional(
                start: -4,
                bottom: 0,
                child: Image.asset(
                  art,
                  width: artSize,
                  height: artSize,
                  excludeFromSemantics: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
