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

/// The gifts sent in a live, over the room (CP-020, §10.23): a banner per
/// combo (sender → recipients, the gift, ×quantity and the combo count)
/// and a large centred effect for an animated or big gift. Names come from
/// the cached catalogue by `giftCode`.
///
/// D145 (owner: «the room only shows the gift's picture, no strip»): the
/// strips slide in at the reading start, above the middle (clear of the
/// open gift panel, which normal gifts keep open), up to
/// [LiveGiftEffects.maxBanners] at once with the newest on top, each for
/// [LiveGiftEffects.bannerTime] after its combo's last send, drawn over the
/// large effect so a full-screen animation never hides them. A tap on a
/// strip opens the sender's card ([onSender]); nothing else takes taps.
///
/// D145a (owner review): the strips never hide the seats or the wish
/// column — an audio room draws them itself between its seats and its chat
/// ([showStrips] false here, [LiveGiftStrips] in its layout); a video live
/// places them at [stripsAt] (beside the wish / promo column).
class LiveGiftEffectsLayer extends ConsumerWidget {
  const new({
    required this.roomId,
    super.key,
    this.onSender,
    this.showStrips = true,
    this.stripsAt,
  });

  final String roomId;

  /// Opens the sender's card (D145); null: the strips take no taps.
  final ValueChanged<UserSummary>? onSender;

  /// False when the room draws [LiveGiftStrips] in its own layout.
  final bool showStrips;

  /// The strips' top start corner (from the screen's top start); null: at
  /// [bannerAlignment].
  final EdgeInsetsDirectional? stripsAt;

  /// Where the strips sit without [stripsAt]: the reading start, above the
  /// middle, so three strips still end above the open gift panel.
  static const bannerAlignment = AlignmentDirectional(-1, -0.3);

  /// D145a: where a video live's strips start — under the header rows, at
  /// the reading start, or beside the wish / promo column when it shows
  /// ([sideColumn]) so they never hide it.
  static EdgeInsetsDirectional videoStripsAt(
    BuildContext context, {
    required bool sideColumn,
  }) => EdgeInsetsDirectional.only(
    top: MediaQuery.paddingOf(context).top + KLiveSideCards.promoTop + 6,
    start: sideColumn
        ? KLiveSideCards.wishStart + LiveWishCard.width + KSpacing.xs
        : KSpacing.sm,
    end: KSpacing.sm,
  );

  static Key bannerKey(String comboId) => Key('gift.banner.$comboId');
  static const effectKey = Key('gift.effect');

  /// D132: the big lucky win banner.
  static const luckyKey = Key('gift.lucky');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effects = ref.watch(liveGiftEffectsProvider(roomId));
    final catalogue = ref.watch(giftCatalogueProvider).value;
    final big = effects.big;
    final at = stripsAt;
    final strips = LiveGiftStrips(roomId: roomId, onSender: onSender);
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
                    assetKey: big.assetKey,
                    animationKey: big.animationKey,
                    imageUrl: big.imageUrl ?? _art(catalogue, big)?.imageUrl,
                    animationUrl:
                        big.animationUrl ?? _art(catalogue, big)?.animationUrl,
                    duration: LiveGiftEffects.bigTime,
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
        if (showStrips)
          if (at != null)
            PositionedDirectional(
              top: at.top,
              start: at.start,
              end: at.end,
              child: Align(
                alignment: AlignmentDirectional.topStart,
                child: strips,
              ),
            )
          else
            Align(
              alignment: bannerAlignment,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(start: KSpacing.sm),
                child: strips,
              ),
            ),
      ],
    );
  }
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
      alignment: AlignmentDirectional.bottomStart.resolve(
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
