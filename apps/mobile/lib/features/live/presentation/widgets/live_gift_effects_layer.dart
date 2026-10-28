import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/icons/kabso_art.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/application/live_gift_effects.dart';
import 'package:kabso_live/features/live/application/live_gift_providers.dart';
import 'package:kabso_live/features/live/domain/live_gift_models.dart';
import 'package:kabso_live/features/live/presentation/widgets/gift_panel.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_gift_art.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_side_cards.dart';
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
  });

  final String roomId;

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

  /// D132: the big lucky win banner.
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
                Align(
                  alignment: const Alignment(0, -0.62),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: KSpacing.lg,
                    ),
                    child: LiveLuckyWinBanner(
                      key: luckyKey,
                      win: win,
                      name: catalogue?.byCode(win.giftCode)?.name,
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
      ],
    );
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

/// D132 (owner): a big lucky win (×100 or more) announced to the room, in
/// Kabso's own style: a gold pill with the coin, the sender, ×multiplier
/// and the coins won. Screen readers hear it once.
class LiveLuckyWinBanner extends StatelessWidget {
  const new({required this.win, super.key, this.name});

  final LuckyWin win;

  /// The gift's name from the catalogue, when known.
  final String? name;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = l10n.liveLuckyBanner(
      KFormat.bidiIsolate(win.sender.displayName),
      KFormat.grouped(win.multiplier),
      KFormat.bidiIsolate(KFormat.grouped(win.coinsWon)),
    );
    return Semantics(
      liveRegion: true,
      label: name == null ? text : '$text, $name',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: KSpacing.md,
          vertical: KSpacing.xs + 2,
        ),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFC94A), Color(0xFFFF8A3D)],
          ),
          borderRadius: BorderRadius.circular(KRadius.pill),
          boxShadow: const [
            BoxShadow(color: Color(0x66000000), blurRadius: 10),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const KabsoArtIcon(KabsoArt.coin, size: 20),
            const SizedBox(width: KSpacing.xs),
            Flexible(
              child: Text(
                text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.textStyles.label.copyWith(
                  color: const Color(0xFF3A1C00),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
