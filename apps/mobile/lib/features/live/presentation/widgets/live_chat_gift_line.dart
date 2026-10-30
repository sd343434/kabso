import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/application/live_chat_controller.dart';
import 'package:kabso_live/features/live/application/live_gift_providers.dart';
import 'package:kabso_live/features/live/domain/live_gift_models.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_gift_art.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D178 (owner: «الهدايا … تظهر في تكست البث الذي أُرسلت فيه الهدية»،
/// «لا يظهر المكسب في التكست»): a gift or a lucky win as a line of the
/// room's chat — the gift's picture, then «فلان أرسل وردة ×3 إلى سارة» or
/// «فلان ربح ×5 = 50 عملة من هدية الحظ» (the win in gold). A tap on the
/// line opens the sender's card ([onProfile]).
class LiveChatGiftLineView extends ConsumerWidget {
  const new({
    required this.item,
    required this.color,
    required this.maxWidth,
    required this.onProfile,
    super.key,
  }) : assert(
         item is LiveChatGiftLine || item is LiveChatLuckyLine,
         'a gift or a lucky win line',
       );

  final LiveChatItem item;
  final Color color;
  final double maxWidth;
  final ValueChanged<String> onProfile;

  static const gold = Color(0xFFFFD45C);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final catalogue = ref.watch(giftCatalogueProvider).value;
    final scaler = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: KMetrics.overlayMaxTextScale);
    final String text;
    final String sender;
    final String username;
    final Widget art;
    final bool win;
    switch (item) {
      case LiveChatGiftLine(:final gift, :final count):
        final name = catalogue?.byCode(gift.giftCode)?.name ?? gift.giftCode;
        final to = gift.recipients;
        final recipient = to.isEmpty
            ? ''
            : to.length == 1
            ? to.first.displayName
            : l10n.liveChatGiftRecipients(to.first.displayName, to.length - 1);
        sender = gift.sender.displayName;
        username = gift.sender.username;
        text = l10n.liveChatGiftLine(
          KFormat.bidiIsolate(sender),
          KFormat.bidiIsolate(name),
          count,
          KFormat.bidiIsolate(recipient),
        );
        art = KGiftImage(gift.assetKey, imageUrl: gift.imageUrl, size: 22);
        win = false;
      case LiveChatLuckyLine(win: final w):
        final g = catalogue?.byCode(w.giftCode);
        sender = w.sender.displayName;
        username = w.sender.username;
        text = l10n.liveChatLuckyLine(
          KFormat.bidiIsolate(sender),
          KFormat.grouped(w.multiplier),
          KFormat.grouped(w.coinsWon),
        );
        art = g == null
            ? const Icon(Icons.casino_rounded, size: 20, color: gold)
            : KGiftImage(g.assetKey, imageUrl: g.imageUrl, size: 22);
        win = true;
      default:
        return const SizedBox.shrink();
    }
    return Semantics(
      button: true,
      label: text,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onProfile(username),
        child: Container(
          constraints: BoxConstraints(maxWidth: maxWidth),
          padding: const EdgeInsetsDirectional.fromSTEB(6, 4, 10, 4),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(14),
            border: win ? Border.all(color: gold.withValues(alpha: .7)) : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              art,
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  text,
                  textScaler: scaler,
                  style: context.textStyles.caption.copyWith(
                    fontSize: 13,
                    height: 1.3,
                    color: win ? gold : const Color(0xFFFFFFFF),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
