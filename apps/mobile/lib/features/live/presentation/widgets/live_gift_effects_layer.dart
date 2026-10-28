import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/icons/kabso_art.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/application/live_gift_effects.dart';
import 'package:kabso_live/features/live/application/live_gift_providers.dart';
import 'package:kabso_live/features/live/application/live_lucky_ticker.dart';
import 'package:kabso_live/features/live/application/max_x.dart';
import 'package:kabso_live/features/live/domain/live_gift_models.dart';
import 'package:kabso_live/features/live/presentation/widgets/gift_panel.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_gift_art.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_quip_art.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_side_cards.dart';
import 'package:kabso_live/features/live/presentation/widgets/max_x_art.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// The gifts sent in a live, over the room (CP-020, §10.23): a strip per
/// combo (sender → recipients, the gift, ×N) and the full-screen effect of
/// an animated gift. Names come from the cached catalogue by `giftCode`.
///
/// D145c (owner, device: «no strip at all» after his own gift in his audio
/// room): the strips are drawn here, **over** the full-screen effect, in
/// audio rooms and video lives alike — vertically centred at the reading
/// start ([LiveGiftStripsSlot]), the same place in both; beside the
/// wish / promo column when a video live shows it ([stripsStart]); and
/// above the gift panel while it is open (normal gifts keep it open, so
/// the sender sees their own strip). D145a had moved the audio strips into
/// the room's layout, under the effect and under the open panel. A tap on
/// a strip opens the sender's card ([onSender]); nothing else takes taps.
class LiveGiftEffectsLayer extends ConsumerWidget {
  const new({
    required this.roomId,
    super.key,
    this.onSender,
    this.stripsStart = KSpacing.sm,
    this.onOpenRoom,
  });

  final String roomId;

  /// D148: opens the live of a gold ticker's win (a viewer moves there);
  /// null: the ticker takes no taps (the host on air stays in their live).
  final ValueChanged<String>? onOpenRoom;

  /// Opens the sender's card (D145); null: the strips take no taps.
  final ValueChanged<UserSummary>? onSender;

  /// The strips' distance from the reading-start edge.
  final double stripsStart;

  /// D145a/D145c: a video live's strips start beside the wish / promo
  /// column when it shows ([sideColumn]), so they never hide it.
  static double videoStripsStart({required bool sideColumn}) => sideColumn
      ? KLiveSideCards.wishStart + LiveWishCard.width + KSpacing.xs
      : KSpacing.sm;

  static Key bannerKey(String comboId) => Key('gift.banner.$comboId');
  static const effectKey = Key('gift.effect');

  /// D132: the big lucky win announcement (D145e: the centred card).
  static const luckyKey = Key('gift.lucky');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effects = ref.watch(liveGiftEffectsProvider(roomId));
    final catalogue = ref.watch(giftCatalogueProvider).value;
    final big = effects.big;
    return Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (effects.lucky case final win?)
                // D145e: centred, a little above the middle (the strips
                // sit at the middle's reading start).
                Align(
                  key: luckyKey,
                  alignment: const Alignment(0, -0.32),
                  child: LiveLuckyWinBanner(
                    key: ValueKey('lucky.${win.giftId}'),
                    win: win,
                    name: catalogue?.byCode(win.giftCode)?.name,
                  ),
                ),
              if (big != null)
                Positioned.fill(
                  key: effectKey,
                  child: KGiftEffect(
                    key: ValueKey(big.id),
                    animationKey:
                        big.animationKey ?? _art(catalogue, big)?.animationKey,
                    animationUrl:
                        big.animationUrl ?? _art(catalogue, big)?.animationUrl,
                    onHold: () => ref
                        .read(liveGiftEffectsProvider(roomId).notifier)
                        .bigHold(big.id),
                    onDone: () => ref
                        .read(liveGiftEffectsProvider(roomId).notifier)
                        .bigDone(big.id),
                  ),
                ),
            ],
          ),
        ),
        // Over the effect: a full-screen animation never hides them.
        LiveGiftStripsSlot(
          start: stripsStart,
          floor: ref.watch(liveChatTopProvider(roomId)),
          child: LiveGiftStrips(roomId: roomId, onSender: onSender),
        ),
        // D148: «لحظة الحظ» — a big win in another live, under the header.
        Positioned(
          top: LiveGiftStripsSlot.top,
          left: KSpacing.md,
          right: KSpacing.md,
          child: Align(
            alignment: Alignment.topCenter,
            child: LiveLuckyTickerBar(roomId: roomId, onOpenRoom: onOpenRoom),
          ),
        ),
        // D154: the quip playing now, as a bubble with its words.
        Positioned(
          top: MediaQuery.paddingOf(context).top + LiveQuipBubble.top,
          left: KSpacing.md,
          right: KSpacing.md,
          child: Align(
            alignment: Alignment.topCenter,
            child: LiveQuipBubble(roomId: roomId),
          ),
        ),
      ],
    );
  }
}

/// D148 («لحظة الحظ», owner): the compact gold ticker of a big lucky win
/// in another live — «فلان ربح ×500 في غرفة …» — under the room's header,
/// for [LiveLuckyTickers.showTime]. A tap opens that live ([onOpenRoom];
/// none: not a button). Slides down and fades in; with reduced motion it
/// just appears. Hidden while [luckyTickerHiddenProvider] says so (the
/// viewer's switch comes in D151).
class LiveLuckyTickerBar extends ConsumerWidget {
  const new({required this.roomId, super.key, this.onOpenRoom});

  final String roomId;
  final ValueChanged<String>? onOpenRoom;

  static const tickerKey = Key('gift.lucky.ticker');

  /// The bar's widest (narrower screens: their width less the margins).
  static const double maxWidth = 340;

  static const _gold = [
    Color(0xFFFFF3B0),
    Color(0xFFFFC93C),
    Color(0xFFFF9F1E),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Always watched (the controller keeps its subscription while hidden).
    final current = ref.watch(liveLuckyTickersProvider(roomId));
    final ticker = ref.watch(luckyTickerHiddenProvider) ? null : current;
    final still = MediaQuery.disableAnimationsOf(context);
    return AnimatedSwitcher(
      duration: still ? Duration.zero : const Duration(milliseconds: 320),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, -0.6),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: child,
        ),
      ),
      child: ticker == null
          ? const SizedBox.shrink()
          : _bar(context, ref, ticker),
    );
  }

  Widget _bar(BuildContext context, WidgetRef ref, LuckyTicker ticker) {
    final l10n = context.l10n;
    final styles = context.textStyles;
    final win = ticker.win;
    final scaler = MediaQuery.textScalerOf(context)
        .clamp(minScaleFactor: 1, maxScaleFactor: 1.3);
    final open = onOpenRoom;
    final text = l10n.liveLuckyTicker(
      KFormat.bidiIsolate(win.sender.displayName),
      KFormat.grouped(win.multiplier),
      KFormat.bidiIsolate(ticker.room.title),
    );
    final bar = Container(
      constraints: const BoxConstraints(maxWidth: maxWidth, minHeight: 36),
      padding: const EdgeInsetsDirectional.fromSTEB(3, 3, KSpacing.md, 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(KRadius.pill),
        gradient: const LinearGradient(
          colors: [Color(0xF24A2300), Color(0xF21C0A00)],
        ),
        border: Border.all(color: const Color(0xFFFFC93C), width: 1.5),
        boxShadow: const [BoxShadow(color: Color(0x80FFB020), blurRadius: 14)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(1.5),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: _gold),
            ),
            child: KAvatar(
              name: win.sender.displayName,
              imageUrl: win.sender.avatarUrl,
              size: 26,
            ),
          ),
          const SizedBox(width: KSpacing.sm),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textScaler: scaler,
              style: styles.label.copyWith(
                color: const Color(0xFFFFE27A),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (open != null) ...[
            const SizedBox(width: KSpacing.xs),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: Color(0xFFFFC93C),
            ),
          ],
        ],
      ),
    );
    return Semantics(
      key: ValueKey('ticker.${win.giftId}'),
      container: true,
      liveRegion: true,
      button: open != null,
      label: text,
      excludeSemantics: true,
      onTap: open == null ? null : () => _open(ref, ticker, open),
      child: KeyedSubtree(
        key: tickerKey,
        child: open == null
            ? bar
            : GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _open(ref, ticker, open),
                child: bar,
              ),
      ),
    );
  }

  void _open(WidgetRef ref, LuckyTicker ticker, ValueChanged<String> open) {
    ref.read(liveLuckyTickersProvider(roomId).notifier).dismiss();
    open(ticker.room.id);
  }
}

/// D145c (owner): where the gift strips sit, the same in every live — at
/// the reading start ([start] from the edge), the column's middle on the
/// screen's middle; it moves up just enough to end [gap] above the chat
/// text ([floor], the chat's top on the screen) and above the gift panel
/// while it is open ([liveGiftPanelHeightProvider]: normal gifts keep it
/// open), never above the header rows ([top] under the status bar). Fills
/// the room; only the strips take taps.
class LiveGiftStripsSlot extends ConsumerWidget {
  const new({
    required this.child,
    super.key,
    this.start = KSpacing.sm,
    this.floor,
  });

  final Widget child;
  final double start;

  /// The chat's top on the screen, or null.
  final double? floor;

  /// The strips keep this far under the status bar (the header rows).
  static const double top = 96;

  /// …and this far above the open gift panel.
  static const double gap = KSpacing.sm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final panel = ref.watch(liveGiftPanelHeightProvider);
    return CustomSingleChildLayout(
      delegate: _StripsLayout(
        start: start,
        end: KSpacing.sm,
        rtl: Directionality.of(context) == TextDirection.rtl,
        ceiling: MediaQuery.paddingOf(context).top + top,
        panel: panel,
        floor: floor,
        gap: gap,
      ),
      child: child,
    );
  }
}

class _StripsLayout extends SingleChildLayoutDelegate {
  new({
    required this.start,
    required this.end,
    required this.rtl,
    required this.ceiling,
    required this.panel,
    required this.floor,
    required this.gap,
  });

  final double start;
  final double end;
  final bool rtl;
  final double ceiling;

  /// The open panel's height, or null.
  final double? panel;

  /// The chat's top (from the screen's top), or null.
  final double? floor;
  final double gap;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(
        maxWidth: math.max(0, constraints.maxWidth - start - end),
        maxHeight: constraints.maxHeight,
      );

  @override
  Offset getPositionForChild(Size size, Size child) {
    var y = (size.height - child.height) / 2;
    if (panel case final p?) {
      y = math.min(y, size.height - p - gap - child.height);
    }
    if (floor case final f?) y = math.min(y, f - gap - child.height);
    y = math.max(y, ceiling);
    return Offset(rtl ? size.width - start - child.width : start, y);
  }

  @override
  bool shouldRelayout(_StripsLayout old) =>
      old.start != start ||
      old.end != end ||
      old.rtl != rtl ||
      old.ceiling != ceiling ||
      old.panel != panel ||
      old.floor != floor ||
      old.gap != gap;
}

/// D145/D145a: the gift strips of a live — up to
/// [LiveGiftEffects.maxBanners], the newest on top, each a [LiveGiftBanner]
/// that opens the sender's card on a tap ([onSender]). Nothing while no
/// gift is being shown; the column grows and shrinks smoothly.
class LiveGiftStrips extends ConsumerWidget {
  const new({required this.roomId, super.key, this.onSender});

  final String roomId;
  final ValueChanged<UserSummary>? onSender;

  static const stripsKey = Key('gift.strips');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final banners = ref.watch(
      liveGiftEffectsProvider(roomId).select((e) => e.banners),
    );
    final catalogue = ref.watch(giftCatalogueProvider).value;
    final onSender = this.onSender;
    final column = Column(
      key: stripsKey,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The newest on top.
        for (final gift in banners.reversed)
          Padding(
            key: ValueKey('strip.${gift.combo.id}'),
            padding: const EdgeInsets.only(bottom: KSpacing.xxs),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onSender == null ? null : () => onSender(gift.sender),
              child: LiveGiftBanner(
                key: LiveGiftEffectsLayer.bannerKey(gift.combo.id),
                gift: gift,
                name: catalogue?.byCode(gift.giftCode)?.name,
                imageUrl: gift.imageUrl ?? _art(catalogue, gift)?.imageUrl,
              ),
            ),
          ),
      ],
    );
    final strips = AnimatedSize(
      duration: KMotion.of(context, KMotion.base),
      curve: KMotion.standard,
      alignment: AlignmentDirectional.centerStart.resolve(
        Directionality.of(context),
      ),
      child: column,
    );
    return onSender == null ? IgnorePointer(child: strips) : strips;
  }
}

/// The catalogue's gift of [gift] (its hosted art when an older server's
/// message has none), or null.
Gift? _art(GiftCatalogue? catalogue, LiveGift gift) =>
    catalogue?.byCode(gift.giftCode);

/// [recipients] as a short phrase: one name, two names, or the first and
/// how many more.
String giftRecipientsText(AppLocalizations l10n, List<UserSummary> recipients) {
  String name(UserSummary u) => KFormat.bidiIsolate(u.displayName);
  return switch (recipients) {
    [] => '',
    [final one] => name(one),
    [final a, final b] => l10n.liveGiftRecipientsTwo(name(a), name(b)),
    [final first, ...final rest] => l10n.liveGiftRecipientsMore(
      name(first),
      rest.length,
    ),
  };
}

/// One gift banner: the sender's picture and name, "sent ‹gift› to ‹who›",
/// the gift and ONE count (D145a): ×N, the gifts each recipient got in this
/// combo so far (`combo.quantity`: 10 roses sent 7 times → ×70), the same
/// number the combo button shows. Compact: 36 pt tall.
class LiveGiftBanner extends StatelessWidget {
  const new({required this.gift, required this.name, super.key, this.imageUrl});

  final LiveGift gift;

  /// The gift's hosted image (D126), or null: the bundled one.
  final String? imageUrl;

  /// The gift's name from the catalogue; null: "a gift".
  final String? name;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.textStyles;
    final sender = KFormat.bidiIsolate(gift.sender.displayName);
    final line = l10n.liveGiftBannerSent(
      KFormat.bidiIsolate(name ?? l10n.liveGiftGeneric),
      giftRecipientsText(l10n, gift.recipients),
    );
    final count = gift.combo.quantity;
    final quantity = l10n.giftCombo(count);
    final scaler = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: KMetrics.overlayMaxTextScale);
    final duration = KMotion.of(context, KMotion.base);
    final banner = Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsetsDirectional.fromSTEB(
        KSpacing.xxs,
        KSpacing.xxs,
        KSpacing.sm,
        KSpacing.xxs,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(KRadius.pill),
        gradient: LinearGradient(
          begin: AlignmentDirectional.centerStart,
          end: AlignmentDirectional.centerEnd,
          colors: [
            KBrandColors.red600.withValues(alpha: 0.85),
            KLiveColors.chatScrim,
            KLiveColors.chatScrim.withValues(alpha: 0),
          ],
          stops: const [0, 0.7, 1],
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          KAvatar(
            name: gift.sender.displayName,
            imageUrl: gift.sender.avatarUrl,
            size: 30,
          ),
          const SizedBox(width: KSpacing.xs),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sender,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textScaler: scaler,
                  style: text.label.copyWith(color: const Color(0xFFFFFFFF)),
                ),
                Text(
                  line,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textScaler: scaler,
                  style: text.caption.copyWith(
                    color: const Color(0xD9FFFFFF),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: KSpacing.xs),
          KGiftImage(gift.assetKey, imageUrl: imageUrl, size: 32),
          const SizedBox(width: KSpacing.xxs),
          MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: scaler),
            child: KGiftComboCounter(count: count),
          ),
        ],
      ),
    );
    return Semantics(
      liveRegion: true,
      label: '$sender $line $quantity',
      excludeSemantics: true,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: duration,
        curve: KMotion.standard,
        builder: (context, t, child) => Opacity(
          opacity: t,
          child: FractionalTranslation(
            translation: Offset(
              (Directionality.of(context) == TextDirection.rtl ? 1 : -1) *
                  (1 - t) *
                  0.3,
              0,
            ),
            child: child,
          ),
        ),
        child: banner,
      ),
    );
  }
}

/// D132 (owner): a big lucky win (×100 or more) announced to the room.
///
/// D145e (owner: the small gold pill «Oz Nabulsi ربح ×100: 1,300 عملة» was
/// too small and looked bad): a centred gold card in the MAX X look (D145d)
/// — a burst of rays, rings and a coin fountain behind it ([MaxXWinPainter]
/// without its own banner), the winner's avatar and name, «×100» in big
/// gold type, and the coins won counting up. It springs in, a shine sweeps
/// across, and it fades out at the end of [LiveGiftEffects.luckyTime].
/// ×500 and ×1000 say «جاكبوت» / «سوبر جاكبوت». With reduced motion: the
/// card alone, still, for the same time. Screen readers hear it once.
class LiveLuckyWinBanner extends StatefulWidget {
  const new({required this.win, super.key, this.name});

  final LuckyWin win;

  /// The gift's name from the catalogue, when known.
  final String? name;

  /// The card's widest (narrower screens: their width less the margins).
  static const double maxWidth = 300;

  static const numberKey = Key('gift.lucky.number');
  static const coinsKey = Key('gift.lucky.coins');

  @override
  State<LiveLuckyWinBanner> createState() => _LiveLuckyWinBannerState();
}

class _LiveLuckyWinBannerState extends State<LiveLuckyWinBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: LiveGiftEffects.luckyTime,
    // With reduced motion the still card stays as long.
    animationBehavior: AnimationBehavior.preserve,
  )..forward();

  late final MaxXWinStyle _burst = MaxXWinStyle.of(
    MaxXTiers.winTierOf(widget.win.multiplier) ?? 100,
  ).lasting(LiveGiftEffects.luckyTime.inMilliseconds / 1000 - .2);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  static double _ease(double t) =>
      1 - math.pow(1 - t.clamp(0.0, 1.0), 3).toDouble();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final win = widget.win;
    final text = l10n.liveLuckyBanner(
      KFormat.bidiIsolate(win.sender.displayName),
      KFormat.grouped(win.multiplier),
      KFormat.bidiIsolate(KFormat.grouped(win.coinsWon)),
    );
    final title = win.multiplier >= 1000
        ? l10n.liveMaxXSuperJackpot
        : win.multiplier >= 500
        ? l10n.liveMaxXJackpot
        : l10n.liveLuckyBigWin;
    final still = MediaQuery.disableAnimationsOf(context);
    final scaler = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: KMetrics.overlayMaxTextScale);
    final width = math.min(
      LiveLuckyWinBanner.maxWidth,
      MediaQuery.sizeOf(context).width - 2 * KSpacing.lg,
    );
    final family = context.textStyles.label.fontFamily;
    return Semantics(
      liveRegion: true,
      label: widget.name == null ? text : '$text, ${widget.name}',
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final seconds =
              _c.value * LiveGiftEffects.luckyTime.inMilliseconds / 1000;
          final total = LiveGiftEffects.luckyTime.inMilliseconds / 1000;
          // In: a springy pop (0–0.45 s). Out: the last 0.35 s.
          final pop = still
              ? 1.0
              : seconds < .45
              ? .55 + .45 * _MaxXSpring.at(seconds / .45)
              : 1.0;
          final fade = still
              ? 1.0
              : (1 - (seconds - (total - .35)) / .35).clamp(0.0, 1.0);
          final count = still
              ? win.coinsWon
              : (win.coinsWon * _ease((seconds - .3) / .9)).round();
          final shine = still ? -1.0 : ((seconds - .5) / .8);
          return Opacity(
            opacity: fade,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                if (!still)
                  CustomPaint(
                    painter: MaxXWinPainter(
                      style: _burst,
                      multiplier: win.multiplier,
                      coins: win.coinsWon,
                      title: null,
                      t: seconds,
                      r: width * .2,
                      still: false,
                      fontFamily: family,
                      banner: false,
                    ),
                  ),
                Transform.scale(
                  scale: pop,
                  child: _BigWinCard(
                    width: width,
                    win: win,
                    title: title,
                    coins: count,
                    shine: shine,
                    scaler: scaler,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// An overshooting ease (0 → 1, peaks ~1.1).
abstract final class _MaxXSpring {
  static double at(double t) {
    final x = t.clamp(0.0, 1.0);
    const a = 1.70158;
    const b = a + 1;
    return 1 + b * math.pow(x - 1, 3) + a * math.pow(x - 1, 2);
  }
}

/// The card itself: dark amber glass in a gold frame.
class _BigWinCard extends StatelessWidget {
  const new({
    required this.width,
    required this.win,
    required this.title,
    required this.coins,
    required this.shine,
    required this.scaler,
  });

  final double width;
  final LuckyWin win;
  final String title;
  final int coins;

  /// The shine's place across the card (0–1; outside: none).
  final double shine;
  final TextScaler scaler;

  static const _gold = [
    Color(0xFFFFF3B0),
    Color(0xFFFFC93C),
    Color(0xFFFF9F1E),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final styles = context.textStyles;
    const outline = [
      Shadow(color: Color(0xCC3C0008), blurRadius: 6),
      Shadow(color: Color(0xCC3C0008), offset: Offset(0, 2)),
    ];
    final number = ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (rect) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFFFFFF), Color(0xFFFFE27A), Color(0xFFFF9F1E)],
      ).createShader(rect),
      // Room for the italic's overhang inside the gradient's box.
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: KSpacing.sm),
        child: Text(
          '×${KFormat.grouped(win.multiplier)}',
          key: LiveLuckyWinBanner.numberKey,
          maxLines: 1,
          textDirection: TextDirection.ltr,
          textScaler: scaler,
          style: styles.headline.copyWith(
            fontSize: 54,
            height: 1.05,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            color: const Color(0xFFFFFFFF),
          ),
        ),
      ),
    );
    final card = Container(
      width: width,
      padding: const EdgeInsets.fromLTRB(
        KSpacing.md,
        KSpacing.md,
        KSpacing.md,
        KSpacing.md,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(KRadius.xl),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xF24A2300), Color(0xF21C0A00)],
        ),
        border: Border.all(color: const Color(0xFFFFC93C), width: 2),
        boxShadow: const [
          BoxShadow(color: Color(0x99FFB020), blurRadius: 28),
          BoxShadow(
            color: Color(0x80000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The title ribbon: «فوز كبير» / «BIG WIN», JACKPOT, SUPER JACKPOT.
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: KSpacing.md,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(KRadius.pill),
              gradient: const LinearGradient(colors: _gold),
            ),
            child: Text(
              title,
              maxLines: 1,
              textScaler: scaler,
              style: styles.label.copyWith(
                color: const Color(0xFF3A1C00),
                fontWeight: FontWeight.w900,
                letterSpacing: .5,
              ),
            ),
          ),
          const SizedBox(height: KSpacing.sm),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: _gold),
                ),
                child: KAvatar(
                  name: win.sender.displayName,
                  imageUrl: win.sender.avatarUrl,
                  size: 40,
                ),
              ),
              const SizedBox(width: KSpacing.sm),
              Flexible(
                child: Text(
                  win.sender.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textScaler: scaler,
                  style: styles.title.copyWith(
                    color: const Color(0xFFFFFFFF),
                    fontWeight: FontWeight.w800,
                    shadows: outline,
                  ),
                ),
              ),
            ],
          ),
          FittedBox(fit: BoxFit.scaleDown, child: number),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const KabsoArtIcon(KabsoArt.coin),
              const SizedBox(width: KSpacing.xs),
              Flexible(
                child: Text(
                  l10n.liveLuckyBigWinCoins(
                    KFormat.bidiIsolate('+${KFormat.grouped(coins)}'),
                  ),
                  key: LiveLuckyWinBanner.coinsKey,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textScaler: scaler,
                  style: styles.title.copyWith(
                    color: const Color(0xFFFFE27A),
                    fontWeight: FontWeight.w900,
                    shadows: outline,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (shine < 0 || shine > 1) return card;
    return ClipRRect(
      borderRadius: BorderRadius.circular(KRadius.xl),
      child: Stack(
        children: [
          card,
          Positioned.fill(
            child: IgnorePointer(
              child: FractionalTranslation(
                translation: Offset(-1 + 2 * shine, 0),
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment(-1, -.3),
                      end: Alignment(1, .3),
                      colors: [
                        Color(0x00FFFFFF),
                        Color(0x55FFFFFF),
                        Color(0x00FFFFFF),
                      ],
                      stops: [.35, .5, .65],
                    ),
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
