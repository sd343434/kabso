import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/icons/kabso_art.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/application/live_gift_providers.dart';
import 'package:kabso_live/features/live/application/live_lucky_combo.dart';
import 'package:kabso_live/features/live/application/live_wallet_controller.dart';
import 'package:kabso_live/features/live/application/max_x.dart';
import 'package:kabso_live/features/live/domain/live_gift_models.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_gift_art.dart';
import 'package:kabso_live/features/live/presentation/widgets/max_x_art.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D145/D145a: the lucky combo's button and its chips, placed by the room
/// in a slot of its own at the bottom end, over the bar near the gift
/// button (mirrored in Arabic): the audio room's end slot (where the promo
/// box sits, which steps aside meanwhile) or the video live's chat end
/// (the chat narrows to make room). So it never covers the chat, the
/// seats or the quick replies.
///
/// From the top: the streak's winnings (compact: the coin and "+N", the
/// best ×), the round button and the balance.
///
/// D145d: the button is the owner's animated MAX X design ([MaxXOrb]): a
/// heat orb that turns red → pink → purple → gold as the streak grows
/// (x1, x10, x30, x100), the countdown ring of [LuckyComboController
/// .ringTime] (urgent in its last second), the gift and «ماكس x12» /
/// «MAX x12» — the number is the one ×N of the room (the gifts per
/// recipient in the server's combo, `combo.quantity`, plus the taps on
/// their way), so the separate ×N badge is gone. Each accepted tap buzzes,
/// pops (the owner's tap sound, when sound effects are on: [MaxXSounds]),
/// squashes the orb and flies the gift up ([LuckyComboLayer]). A send the
/// server answers with a win celebrates over the room ([MaxXCelebration]).
/// Nothing when no combo shows.
class LuckyComboCluster extends ConsumerStatefulWidget {
  const new({required this.roomId, super.key});

  final String roomId;

  static const buttonKey = Key('combo.button');
  static const ringKey = Key('combo.ring');
  static const countKey = Key('combo.count');
  static const balanceKey = Key('combo.balance');
  static const resultKey = Key('combo.result');

  /// The button's outer size (ring included); a 48 pt target and more.
  /// The orb's glow and sparks draw past it.
  static const double size = 84;

  /// The cluster's width (the button and its badge; the chips scale down
  /// to it).
  static const double width = 96;

  static final _anchors = <String, GlobalKey>{};

  /// The button of [roomId]'s combo (where flights start).
  static GlobalKey anchorFor(String roomId) =>
      _anchors.putIfAbsent(roomId, GlobalKey.new);

  /// Whether [roomId]'s combo shows now (the room gives it its slot).
  static bool shows(WidgetRef ref, String roomId) =>
      ref.watch(liveLuckyComboProvider(roomId).select((s) => s.visible));

  @override
  ConsumerState<LuckyComboCluster> createState() => _LuckyComboClusterState();
}

class _LuckyComboClusterState extends ConsumerState<LuckyComboCluster>
    with TickerProviderStateMixin {
  // The ring is the time left, not decoration: it runs at its real speed
  // with reduced motion too.
  late final AnimationController _ring = AnimationController(
    vsync: this,
    duration: LuckyComboController.ringTime,
    animationBehavior: AnimationBehavior.preserve,
  );

  @override
  void dispose() {
    _ring.dispose();
    super.dispose();
  }

  void _onTap() {
    final ok = ref.read(liveLuckyComboProvider(widget.roomId).notifier).tap();
    if (!ok) return;
    unawaited(HapticFeedback.mediumImpact());
    ref.read(maxXSoundsProvider).tap();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final provider = liveLuckyComboProvider(widget.roomId);
    ref.listen(provider, (previous, next) {
      if (next.ring != previous?.ring && next.visible) {
        _ring.forward(from: 0);
      }
    });
    final combo = ref.watch(provider);
    final gift = combo.gift;
    if (!combo.visible || gift == null) return const SizedBox.shrink();
    // The balance is kept read while the combo shows (its answers set it).
    final coins = ref.watch(liveCoinsProvider).value;
    if (!_ring.isAnimating && _ring.value == 0) _ring.forward(from: 0);
    final catalogue = ref.watch(giftCatalogueProvider).value;
    final name = catalogue?.byCode(gift.code)?.name;
    final scaler = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: KMetrics.overlayMaxTextScale);
    return SizedBox(
      width: LuckyComboCluster.width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (combo.last case final last?)
            _ResultChip(
              key: LuckyComboCluster.resultKey,
              id: combo.lastId,
              coinsWon: combo.coinsWon,
              topMultiplier: combo.topMultiplier,
              lastWon: last.coinsWon,
              scaler: scaler,
            ),
          const SizedBox(height: KSpacing.xxs),
          SizedBox(
            width: LuckyComboCluster.width,
            height: LuckyComboCluster.size,
            child: Align(
              alignment: AlignmentDirectional.bottomEnd,
              child: Semantics(
                button: true,
                label: l10n.liveComboSemantics(
                  KFormat.bidiIsolate(name ?? l10n.liveGiftGeneric),
                  combo.displayCount,
                ),
                excludeSemantics: true,
                child: GestureDetector(
                  key: LuckyComboCluster.buttonKey,
                  behavior: HitTestBehavior.opaque,
                  onTap: _onTap,
                  child: KeyedSubtree(
                    key: LuckyComboCluster.anchorFor(widget.roomId),
                    child: MaxXOrb(
                      ring: _ring,
                      streak: combo.streak,
                      count: combo.displayCount,
                      taps: combo.taps,
                      word: l10n.liveComboLabel,
                      assetKey: gift.assetKey,
                      imageUrl: gift.imageUrl,
                      countKey: LuckyComboCluster.countKey,
                      ringKey: LuckyComboCluster.ringKey,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (coins != null) ...[
            const SizedBox(height: 2),
            // A six-digit balance scales down to the cluster's width.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: _Balance(coins: coins, scaler: scaler),
            ),
          ],
        ],
      ),
    );
  }
}

/// D145: what the combo shows over the room besides its button: the gift
/// flying from the button up to who receives it on every accepted tap
/// (none with reduced motion), and, when the combo stops on a refusal, the
/// reason over the bar for [messageTime]. Takes no taps.
class LuckyComboLayer extends ConsumerStatefulWidget {
  const new({
    required this.roomId,
    super.key,
    this.bottom = audioBottom,
    this.hostUsername,
  });

  final String roomId;

  /// The message's distance from the bottom safe edge (over the bar).
  final double bottom;

  /// The host: a combo to the host alone flies to the host's pill at the
  /// top start; any other flies toward the seats in the upper middle.
  final String? hostUsername;

  /// [bottom] in an audio room (over its bar) and in a video live (over
  /// the quick replies above its bar).
  static const double audioBottom = 60;
  static const double videoBottom = 100;

  /// D145e: wins waiting for their celebration behind the one on screen.
  static const maxWaitingWins = 3;

  static const messageKey = Key('combo.message');
  static const flightKey = Key('combo.flight');
  static const messageTime = Duration(seconds: 3);
  static const flightTime = Duration(milliseconds: 700);

  @override
  ConsumerState<LuckyComboLayer> createState() => _LuckyComboLayerState();
}

class _LuckyComboLayerState extends ConsumerState<LuckyComboLayer> {
  String? _message;
  Timer? _messageTimer;

  /// Flights: id → where it starts (the button's centre then).
  final _flights = <int, Offset>{};

  /// D145d: the win celebration on screen and where it plays. D145e (owner:
  /// two wins' banners overlapped each other and the orb): one at a time,
  /// the others wait in [_winQueue] ([LuckyComboLayer.maxWaitingWins]; when
  /// full, a bigger win takes the smallest one's place).
  MaxXWin? _win;
  Offset? _winAt;
  Offset? _lastAt;
  final _winQueue = <MaxXWin>[];

  @override
  void dispose() {
    _messageTimer?.cancel();
    super.dispose();
  }

  void _showMessage(String text) {
    _messageTimer?.cancel();
    _messageTimer = Timer(LuckyComboLayer.messageTime, () {
      if (mounted) setState(() => _message = null);
    });
    setState(() => _message = text);
  }

  /// Queues [win]'s celebration; it plays when the one on screen is done.
  void _enqueue(MaxXWin win) {
    if (_win == null) {
      _celebrate(win);
      return;
    }
    if (_winQueue.length < LuckyComboLayer.maxWaitingWins) {
      _winQueue.add(win);
      return;
    }
    var smallest = 0;
    for (var i = 1; i < _winQueue.length; i++) {
      if (_winQueue[i].multiplier < _winQueue[smallest].multiplier) {
        smallest = i;
      }
    }
    if (win.multiplier > _winQueue[smallest].multiplier) {
      _winQueue
        ..removeAt(smallest)
        ..add(win);
    }
  }

  /// Plays [win]'s celebration (and its jingle) at the button — after this
  /// frame when the button is not laid out yet: the panel's own send starts
  /// the combo.
  void _celebrate(MaxXWin win, {bool retry = true}) {
    // A queued win may come after the combo's button went: it plays where
    // the button last was.
    final at = _buttonCentre() ?? (retry ? null : _lastAt);
    if (at != null) {
      _lastAt = at;
      ref.read(maxXSoundsProvider).win(win.multiplier);
      setState(() {
        _win = win;
        _winAt = at;
      });
    } else if (retry) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _celebrate(win, retry: false);
      });
    } else {
      _next();
    }
  }

  void _next() {
    if (!mounted) return;
    setState(() {
      _win = null;
      _winAt = null;
    });
    if (_winQueue.isNotEmpty) _celebrate(_winQueue.removeAt(0));
  }

  Offset? _buttonCentre() {
    final anchor = LuckyComboCluster.anchorFor(widget.roomId).currentContext;
    final mine = context.findRenderObject();
    final box = anchor?.findRenderObject();
    if (box is! RenderBox || mine is! RenderBox || !box.attached) return null;
    return mine.globalToLocal(box.localToGlobal(box.size.center(Offset.zero)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final provider = liveLuckyComboProvider(widget.roomId);
    ref.listen(provider, (previous, next) {
      if (next.taps != (previous?.taps ?? 0) &&
          !MediaQuery.disableAnimationsOf(context)) {
        final from = _buttonCentre();
        if (from != null) setState(() => _flights[next.taps] = from);
      }
      // D145d: a send the server answered with a win celebrates (and plays
      // its jingle) once, at the button.
      final win = next.win;
      if (win != null && win.id != previous?.win?.id) _enqueue(win);
      final stop = next.stop;
      if (stop != null && stop.id != previous?.stop?.id) {
        _showMessage(
          stop.notEnoughCoins || stop.failure == null
              ? l10n.liveGiftNotEnoughCoins
              : failureMessage(l10n, stop.failure!),
        );
      }
    });
    final gift = ref.watch(provider.select((s) => s.gift));
    final scaler = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: KMetrics.overlayMaxTextScale);
    final media = MediaQuery.of(context);
    final children = <Widget>[];
    if (_message case final text?) {
      children.add(
        Positioned(
          left: KSpacing.lg,
          right: KSpacing.lg,
          bottom: media.padding.bottom + widget.bottom,
          child: Center(
            child: Semantics(
              liveRegion: true,
              child: Container(
                key: LuckyComboLayer.messageKey,
                padding: const EdgeInsets.symmetric(
                  horizontal: KSpacing.md,
                  vertical: KSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xE6000000),
                  borderRadius: BorderRadius.circular(KRadius.pill),
                ),
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  textScaler: scaler,
                  style: context.textStyles.label.copyWith(
                    color: const Color(0xFFFFFFFF),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    if (gift != null) {
      final toHost =
          gift.recipients.length == 1 &&
          gift.recipients.first == widget.hostUsername;
      for (final MapEntry(key: id, value: from) in _flights.entries) {
        children.add(
          _Flight(
            key: ValueKey('flight.$id'),
            from: from,
            to: toHost
                ? Offset(
                    Directionality.of(context) == TextDirection.rtl
                        ? media.size.width - 40
                        : 40,
                    media.padding.top + 24,
                  )
                : Offset(media.size.width / 2, media.size.height * 0.28),
            assetKey: gift.assetKey,
            imageUrl: gift.imageUrl,
            onDone: () {
              if (mounted) setState(() => _flights.remove(id));
            },
          ),
        );
      }
    }
    if ((_win, _winAt) case (final win?, final at?)) {
      children.add(
        MaxXCelebration(
          key: ValueKey('maxx.win.${win.id}'),
          win: win,
          centre: at,
          radius: MaxXOrb.radiusOf(LuckyComboCluster.size),
          onDone: _next,
        ),
      );
    }
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: children,
      ),
    );
  }
}

/// The streak's lucky winnings, compact for the cluster's width: the coin,
/// "+N" (gold) and the best × (or "0" while nothing was won); it pops on
/// every answer. Screen readers hear the whole sentence.
class _ResultChip extends StatelessWidget {
  const new({
    required this.id,
    required this.coinsWon,
    required this.topMultiplier,
    required this.lastWon,
    required this.scaler,
    super.key,
  });

  final int id;
  final int coinsWon;
  final int? topMultiplier;
  final int lastWon;
  final TextScaler scaler;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spoken = coinsWon > 0
        ? l10n.liveLuckyWon(
            KFormat.bidiIsolate(KFormat.grouped(coinsWon)),
            KFormat.grouped(topMultiplier ?? 0),
          )
        : l10n.liveLuckyNoWin;
    final won = coinsWon > 0;
    final style = context.textStyles.caption.copyWith(
      color: won ? KBrandColors.gold : const Color(0xFFFFFFFF),
      fontWeight: FontWeight.w800,
      height: 1.2,
    );
    final chip = Container(
      padding: const EdgeInsetsDirectional.fromSTEB(3, 2, 7, 2),
      decoration: BoxDecoration(
        color: KLiveColors.chatScrim,
        borderRadius: BorderRadius.circular(KRadius.pill),
        border: Border.all(
          color: lastWon > 0 ? KBrandColors.gold : const Color(0x33FFFFFF),
          width: KMetrics.thinStroke,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const KabsoArtIcon(KabsoArt.coin, size: 14),
          const SizedBox(width: 3),
          Text(
            // Digits and signs read left to right in both languages.
            won ? '+${KFormat.grouped(coinsWon)}' : '0',
            textDirection: TextDirection.ltr,
            textScaler: scaler,
            style: style,
          ),
          if (won && topMultiplier != null) ...[
            const SizedBox(width: 4),
            Text(
              l10n.giftCombo(topMultiplier!),
              textScaler: scaler,
              style: style.copyWith(color: const Color(0xFFFFFFFF)),
            ),
          ],
        ],
      ),
    );
    final pop = KMotion.of(context, KMotion.giftComboBump);
    return Semantics(
      liveRegion: true,
      label: spoken,
      excludeSemantics: true,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: pop == Duration.zero
            ? chip
            : TweenAnimationBuilder<double>(
                key: ValueKey('result.$id'),
                tween: Tween(begin: lastWon > 0 ? 1.15 : 1, end: 1),
                duration: pop * 2,
                curve: KMotion.standard,
                builder: (context, s, child) =>
                    Transform.scale(scale: s, child: child),
                child: chip,
              ),
      ),
    );
  }
}

class _Balance extends StatelessWidget {
  const new({required this.coins, required this.scaler});

  final int coins;
  final TextScaler scaler;

  @override
  Widget build(BuildContext context) => Semantics(
    label: context.l10n.liveComboBalance(KFormat.grouped(coins)),
    excludeSemantics: true,
    child: Container(
      key: LuckyComboCluster.balanceKey,
      padding: const EdgeInsets.symmetric(horizontal: KSpacing.xs, vertical: 2),
      decoration: BoxDecoration(
        color: KLiveColors.chatScrim,
        borderRadius: BorderRadius.circular(KRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const KabsoArtIcon(KabsoArt.coin, size: 14),
          const SizedBox(width: 3),
          Text(
            KFormat.grouped(coins),
            textScaler: scaler,
            style: context.textStyles.caption.copyWith(
              color: const Color(0xFFFFFFFF),
              fontWeight: FontWeight.w700,
              shadows: KLiveColors.glassShadow,
            ),
          ),
        ],
      ),
    ),
  );
}

/// One gift flying from the button up to [to], shrinking and fading at the
/// end (never with reduced motion: no flight is started then).
class _Flight extends StatefulWidget {
  const new({
    required this.from,
    required this.to,
    required this.assetKey,
    required this.imageUrl,
    required this.onDone,
    super.key,
  });

  final Offset from;
  final Offset to;
  final String assetKey;
  final String? imageUrl;
  final VoidCallback onDone;

  @override
  State<_Flight> createState() => _FlightState();
}

class _FlightState extends State<_Flight> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: LuckyComboLayer.flightTime,
  );

  @override
  void initState() {
    super.initState();
    unawaited(_c.forward().whenComplete(widget.onDone));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Positioned(
    left: 0,
    top: 0,
    child: IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          final t = Curves.easeInOutCubic.transform(_c.value);
          // A slight arc: up first, then across.
          final x = widget.from.dx + (widget.to.dx - widget.from.dx) * t * t;
          final y = widget.from.dy + (widget.to.dy - widget.from.dy) * t;
          final scale = 1.2 - 0.6 * t;
          final opacity = _c.value > 0.8 ? (1 - _c.value) / 0.2 : 1.0;
          return Transform.translate(
            offset: Offset(x - _size / 2, y - _size / 2),
            child: Opacity(
              opacity: opacity.clamp(0, 1),
              child: Transform.scale(scale: scale, child: child),
            ),
          );
        },
        child: KGiftImage(
          widget.assetKey,
          key: LuckyComboLayer.flightKey,
          imageUrl: widget.imageUrl,
          size: _size,
        ),
      ),
    ),
  );

  static const _size = 40.0;
}
