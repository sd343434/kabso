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
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// The gifts sent in a live, over the room (CP-020, §10.23): a banner per
/// combo (sender → recipients, the gift, ×quantity and the combo count)
/// and a large centred effect for an animated or big gift. Names come from
/// the cached catalogue by `giftCode`. Never takes taps.
class LiveGiftEffectsLayer extends ConsumerWidget {
  const new({required this.roomId, super.key});

  final String roomId;

  static Key bannerKey(String comboId) => Key('gift.banner.$comboId');
  static const effectKey = Key('gift.effect');

  /// D132: the big lucky win banner.
  static const luckyKey = Key('gift.lucky');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effects = ref.watch(liveGiftEffectsProvider(roomId));
    final catalogue = ref.watch(giftCatalogueProvider).value;
    final big = effects.big;
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Align(
            alignment: const AlignmentDirectional(-1, -0.4),
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: KSpacing.sm),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final gift in effects.banners)
                    Padding(
                      padding: const EdgeInsets.only(bottom: KSpacing.xs),
                      child: LiveGiftBanner(
                        key: bannerKey(gift.combo.id),
                        gift: gift,
                        name: catalogue?.byCode(gift.giftCode)?.name,
                        imageUrl:
                            gift.imageUrl ?? _art(catalogue, gift)?.imageUrl,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (effects.lucky case final win?)
            Align(
              alignment: const Alignment(0, -0.62),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
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
    );
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
/// the gift, ×quantity and, from the second send of a combo, ×count.
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
    final quantity = l10n.giftCombo(gift.quantity);
    final scaler = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: KMetrics.overlayMaxTextScale);
    final duration = KMotion.of(context, KMotion.base);
    final banner = Container(
      constraints: const BoxConstraints(maxWidth: 300),
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
            size: 34,
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
          KGiftImage(gift.assetKey, imageUrl: imageUrl, size: 40),
          const SizedBox(width: KSpacing.xxs),
          Text(
            quantity,
            textScaler: scaler,
            style: text.label.copyWith(
              color: KBrandColors.gold,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (gift.combo.count > 1) ...[
            const SizedBox(width: KSpacing.xs),
            KGiftComboCounter(count: gift.combo.count),
          ],
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
