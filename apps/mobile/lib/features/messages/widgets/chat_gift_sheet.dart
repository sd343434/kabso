import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/presentation/widgets/gift_panel.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_view_data.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// A gift chosen in a conversation's gift box: [count] of [gift].
@immutable
class ChatGift {
  const new({required this.gift, required this.count});

  final GiftItemData gift;
  final int count;
}

/// Gift-box geometry (D69).
abstract final class KChatGift {
  static const List<int> counts = [1, 5, 10];
  static const double messageArt = 64;
}

/// Opens the gift box of a conversation with [peer] (D69); resolves to the
/// chosen gift and count, or null when closed. Unlike the live room's
/// always-dark panel it follows the app theme. The items are Kabso's own
/// placeholder art with no price ([KGiftPanel.preview]): there is no gift
/// catalogue, wallet or send API yet (B5).
Future<ChatGift?> showChatGiftSheet(BuildContext context, String peer) =>
    showModalBottomSheet<ChatGift>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => ChatGiftSheet(peer: peer),
    );

class ChatGiftSheet extends StatefulWidget {
  const new({required this.peer, super.key});

  final String peer;

  static Key giftKey(String id) => Key('chatGift.$id');
  static Key countKey(int n) => Key('chatGift.count.$n');
  static const sendKey = Key('chatGift.send');

  @override
  State<ChatGiftSheet> createState() => _ChatGiftSheetState();
}

class _ChatGiftSheetState extends State<ChatGiftSheet> {
  String? _selected;
  int _count = KChatGift.counts.first;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.textStyles;
    final l10n = context.l10n;
    final gifts = KGiftPanel.preview(l10n);
    final selected = gifts.where((g) => g.id == _selected).firstOrNull;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          KSpacing.lg,
          0,
          KSpacing.lg,
          KSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                l10n.chatGiftTitle(widget.peer),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: t.title.copyWith(color: p.textPrimary),
              ),
            ),
            const SizedBox(height: KSpacing.md),
            GridView.count(
              crossAxisCount: KSizes.giftGridColumns,
              mainAxisSpacing: KSpacing.sm,
              crossAxisSpacing: KSpacing.sm,
              childAspectRatio: 0.85,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (final g in gifts)
                  _GiftCell(
                    key: ChatGiftSheet.giftKey(g.id),
                    gift: g,
                    selected: g.id == _selected,
                    onTap: () => setState(() => _selected = g.id),
                  ),
              ],
            ),
            const SizedBox(height: KSpacing.md),
            Semantics(
              label: l10n.chatGiftQuantity,
              container: true,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final n in KChatGift.counts)
                    KChip(
                      key: ChatGiftSheet.countKey(n),
                      label: l10n.giftCombo(n),
                      selected: n == _count,
                      onSelected: () => setState(() => _count = n),
                    ),
                ],
              ),
            ),
            const SizedBox(height: KSpacing.md),
            KButton(
              key: ChatGiftSheet.sendKey,
              label: selected == null
                  ? l10n.chatGiftPick
                  : l10n.chatGiftSendNamed(selected.name),
              icon: Icons.card_giftcard_rounded,
              onPressed: selected == null
                  ? null
                  : () => Navigator.pop(
                      context,
                      ChatGift(gift: selected, count: _count),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GiftCell extends StatelessWidget {
  const new({
    required this.gift,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final GiftItemData gift;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      button: true,
      selected: selected,
      label: gift.name,
      excludeSemantics: true,
      child: Material(
        color: selected
            ? p.primary.withValues(alpha: 0.10)
            : Theme.of(context).brightness == Brightness.light
            ? p.surface
            : p.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KRadius.md),
          side: BorderSide(
            color: selected ? p.primary : p.border.withValues(alpha: 0),
            width: 1.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.all(KSpacing.xs),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedScale(
                    scale: selected ? 1.12 : 1,
                    duration: KMotion.of(context, KMotion.fast),
                    child: KGiftArt(shape: gift.shape),
                  ),
                  const SizedBox(height: KSpacing.xs),
                  Text(
                    gift.name,
                    maxLines: 1,
                    style: context.textStyles.caption.copyWith(
                      color: p.textPrimary,
                      fontWeight: selected ? FontWeight.w700 : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A gift inside a conversation (D69): the art, who sent what, and ×N.
/// Pops in once when [arrive] (a gift just sent); still with reduced
/// motion.
class ChatGiftCard extends StatelessWidget {
  const new({
    required this.gift,
    required this.mine,
    required this.peer,
    super.key,
    this.arrive = false,
    this.meta,
  });

  final ChatGift gift;
  final bool mine;
  final String peer;
  final bool arrive;

  /// Time and ticks, under the text.
  final Widget? meta;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.textStyles;
    final l10n = context.l10n;
    final title = mine
        ? l10n.chatGiftYours(gift.gift.name)
        : l10n.chatGiftFrom(peer, gift.gift.name);
    // On the red card the art sits on a light disc so it keeps contrast.
    final art = Container(
      padding: const EdgeInsets.all(KSpacing.sm),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: mine
            ? KPalette.light.surfaceRaised.withValues(alpha: 0.92)
            : KBrandColors.gold.withValues(alpha: 0.14),
      ),
      child: KGiftArt(shape: gift.gift.shape, size: KChatGift.messageArt),
    );
    final pop = KMotion.of(context, const Duration(milliseconds: 450));
    return Semantics(
      container: true,
      label: gift.count > 1 ? '$title ${l10n.giftCombo(gift.count)}' : title,
      child: Container(
        width: 210,
        padding: const EdgeInsets.all(KSpacing.md),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(KRadius.lg),
          gradient: LinearGradient(
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
            colors: mine
                ? [p.primary, Color.lerp(p.primary, KBrandColors.gold, 0.35)!]
                : [
                    p.surfaceRaised,
                    Color.lerp(p.surfaceRaised, KBrandColors.gold, 0.18)!,
                  ],
          ),
          border: mine ? null : Border.all(color: KBrandColors.gold),
          boxShadow: [
            BoxShadow(
              color: p.textPrimary.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ExcludeSemantics(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: AlignmentDirectional.bottomEnd,
                clipBehavior: Clip.none,
                children: [
                  if (arrive && pop != Duration.zero)
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.3, end: 1),
                      duration: pop,
                      curve: Curves.elasticOut,
                      builder: (_, s, child) =>
                          Transform.scale(scale: s, child: child),
                      child: art,
                    )
                  else
                    art,
                  if (gift.count > 1)
                    PositionedDirectional(
                      end: -KSpacing.lg,
                      bottom: -KSpacing.xs,
                      child: Text(
                        l10n.giftCombo(gift.count),
                        style: t.title.copyWith(
                          fontWeight: FontWeight.w800,
                          color: mine ? p.onPrimary : KBrandColors.gold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: KSpacing.sm),
              Text(
                gift.gift.name,
                textAlign: TextAlign.center,
                style: t.title.copyWith(
                  fontWeight: FontWeight.w800,
                  color: mine ? p.onPrimary : p.textPrimary,
                ),
              ),
              Text(
                mine
                    ? l10n.chatGiftYoursCaption
                    : l10n.chatGiftFromCaption(peer),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.caption.copyWith(
                  color: mine
                      ? p.onPrimary.withValues(alpha: 0.85)
                      : p.textSecondary,
                ),
              ),
              ?meta,
            ],
          ),
        ),
      ),
    );
  }
}
