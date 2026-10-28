import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/application/live_gift_effects.dart';
import 'package:kabso_live/features/live/application/live_gift_providers.dart';
import 'package:kabso_live/features/live/application/live_lucky_ticker.dart';
import 'package:kabso_live/features/live/application/max_x.dart';
import 'package:kabso_live/features/live/domain/live_gift_models.dart';
import 'package:kabso_live/features/live/presentation/widgets/gift_panel.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_gift_art.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_program_card.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_quip_art.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_side_cards.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_win_banner.dart';
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

  /// D132: the lucky win announcement (D159: the owner's tier banner).
  static const luckyKey = Key('gift.lucky');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effects = ref.watch(liveGiftEffectsProvider(roomId));
    final catalogue = ref.watch(giftCatalogueProvider).value;
    final big = effects.big;
    final safeTop = MediaQuery.paddingOf(context).top;
    final bannerWidth = LiveWinBanner.widthOn(MediaQuery.sizeOf(context).width);
    return Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (effects.lucky case final win?)
                // D159: the owner's tier frame under the header, above an
                // audio room's first seats; it slides across the width.
                Positioned(
                  key: luckyKey,
                  top: safeTop + LiveWinBanner.top,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: LiveWinBanner(
                      key: ValueKey('lucky.${win.giftId}'),
                      win: win,
                      width: bannerWidth,
                    ),
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
        // D159: it steps aside (fades, no taps) while this live's own win
        // banner shows in the same place, and comes back after it.
        Positioned(
          top: safeTop + LiveGiftStripsSlot.top,
          left: KSpacing.md,
          right: KSpacing.md,
          child: IgnorePointer(
            ignoring: effects.lucky != null,
            child: ExcludeSemantics(
              excluding: effects.lucky != null,
              child: AnimatedOpacity(
                opacity: effects.lucky == null ? 1 : 0,
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 200),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: LiveLuckyTickerBar(
                    roomId: roomId,
                    onOpenRoom: onOpenRoom,
                  ),
                ),
              ),
            ),
          ),
        ),
        // D154e: the live's program, at the reading end under the header.
        PositionedDirectional(
          top: MediaQuery.paddingOf(context).top + LiveProgramCard.top,
          end: KSpacing.sm,
          child: LiveProgramCard(roomId: roomId),
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
    // D159: the line takes its win's tier colours (the frame's jewel and
    // glow) in the gold rim.
    final art = LuckyWinTierArt.of(LuckyWinTier.of(win.multiplier));
    final bar = Container(
      constraints: const BoxConstraints(maxWidth: maxWidth, minHeight: 36),
      padding: const EdgeInsetsDirectional.fromSTEB(3, 3, KSpacing.md, 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(KRadius.pill),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            art.panelTop.withValues(alpha: .95),
            art.panelBottom.withValues(alpha: .95),
          ],
        ),
        border: Border.all(color: const Color(0xFFFFC93C), width: 1.5),
        boxShadow: [
          BoxShadow(color: art.glow.withValues(alpha: .5), blurRadius: 14),
        ],
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
