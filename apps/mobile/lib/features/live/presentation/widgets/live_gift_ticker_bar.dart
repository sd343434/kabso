import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/application/live_gift_providers.dart';
import 'package:kabso_live/features/live/application/live_gift_ticker.dart';
import 'package:kabso_live/features/live/domain/live_gift_models.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_gift_art.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D178: the global gift strip — «فلان أرسل … ×3 في غرفة …» with the
/// gift's picture — under the room's header, for [LiveGiftTickers.showTime].
/// A tap opens that live ([onOpenRoom]; none: not a button), as the lucky
/// ticker (D148).
class LiveGiftTickerBar extends ConsumerWidget {
  const new({required this.roomId, super.key, this.onOpenRoom});

  final String roomId;
  final ValueChanged<String>? onOpenRoom;

  static const tickerKey = Key('gift.global.ticker');

  /// The bar's widest.
  static const double maxWidth = 340;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticker = ref.watch(liveGiftTickersProvider(roomId));
    final still = MediaQuery.disableAnimationsOf(context);
    return AnimatedSwitcher(
      duration: still ? Duration.zero : const Duration(milliseconds: 280),
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

  Widget _bar(BuildContext context, WidgetRef ref, GiftTicker ticker) {
    final l10n = context.l10n;
    final gift = ticker.gift;
    final name =
        ref.watch(giftCatalogueProvider).value?.byCode(gift.giftCode)?.name ??
        gift.giftCode;
    final scaler = MediaQuery.textScalerOf(context)
        .clamp(minScaleFactor: 1, maxScaleFactor: 1.3);
    final open = onOpenRoom;
    final text = l10n.liveGiftTicker(
      KFormat.bidiIsolate(gift.sender.displayName),
      KFormat.bidiIsolate(name),
      gift.quantity,
      KFormat.bidiIsolate(ticker.room.title),
    );
    final bar = Container(
      constraints: const BoxConstraints(maxWidth: maxWidth, minHeight: 34),
      padding: const EdgeInsetsDirectional.fromSTEB(4, 3, KSpacing.md, 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(KRadius.pill),
        gradient: const LinearGradient(
          colors: [Color(0xE6FF4D7A), Color(0xE66C4CF1)],
        ),
        border: Border.all(color: const Color(0x99FFFFFF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          KGiftImage(gift.assetKey, imageUrl: gift.imageUrl, size: 26),
          const SizedBox(width: KSpacing.sm),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textScaler: scaler,
              style: context.textStyles.label.copyWith(
                color: const Color(0xFFFFFFFF),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (open != null) ...[
            const SizedBox(width: KSpacing.xs),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: Color(0xFFFFFFFF),
            ),
          ],
        ],
      ),
    );
    void tap() {
      ref.read(liveGiftTickersProvider(roomId).notifier).dismiss();
      open!(ticker.room.id);
    }

    return Semantics(
      key: ValueKey('giftTicker.${gift.id}'),
      container: true,
      liveRegion: true,
      button: open != null,
      label: text,
      excludeSemantics: true,
      onTap: open == null ? null : tap,
      child: KeyedSubtree(
        key: tickerKey,
        child: open == null
            ? bar
            : GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: tap,
                child: bar,
              ),
      ),
    );
  }
}
