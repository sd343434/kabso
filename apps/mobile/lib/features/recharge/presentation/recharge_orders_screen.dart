import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/recharge/application/recharge_orders_providers.dart';
import 'package:kabso_live/features/recharge/application/recharge_providers.dart';
import 'package:kabso_live/features/recharge/data/recharge_orders_repository.dart';
import 'package:kabso_live/features/recharge/presentation/recharge_order_screen.dart'
    show rechargeOrderStatusColor, rechargeOrderStatusText, rechargePriceText;
import 'package:kabso_live/features/wallet/presentation/me_page_parts.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// `/recharge/orders` «طلبات الشحن» (D204): the caller's orders — as buyer,
/// and, for an agent or an employee, the incoming ones — newest first; a tap
/// opens the order's chat.
class RechargeOrdersScreen extends ConsumerStatefulWidget {
  const new({super.key, this.incoming = false});

  /// Open on the incoming orders (an agent's notification or dashboard).
  final bool incoming;

  static const emptyKey = Key('recharge.orders.empty');
  static const mineKey = Key('recharge.orders.mine');
  static const incomingKey = Key('recharge.orders.incoming');
  static Key rowKey(String id) => Key('recharge.orders.$id');

  @override
  ConsumerState<RechargeOrdersScreen> createState() =>
      _RechargeOrdersScreenState();
}

class _RechargeOrdersScreenState extends ConsumerState<RechargeOrdersScreen> {
  late bool _incoming = widget.incoming;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final me = ref.watch(myRechargeAgentProvider).value;
    final serves = me?.agent != null || me?.employment != null;
    final asAgent = serves && _incoming;
    final load = ref.watch(rechargeOrdersProvider(asAgent));
    return MePage(
      title: l10n.rechargeOrdersTitle,
      onRefresh: () async {
        ref.invalidate(rechargeOrdersProvider(asAgent));
        try {
          await ref.read(rechargeOrdersProvider(asAgent).future);
        } on Object {
          // Shown with a retry.
        }
      },
      children: [
        if (serves) ...[
          Row(
            children: [
              KChip(
                key: RechargeOrdersScreen.mineKey,
                label: l10n.rechargeOrdersMine,
                selected: !_incoming,
                onSelected: () => setState(() => _incoming = false),
              ),
              const SizedBox(width: KSpacing.xs),
              KChip(
                key: RechargeOrdersScreen.incomingKey,
                label: l10n.rechargeOrdersIncoming,
                selected: _incoming,
                onSelected: () => setState(() => _incoming = true),
              ),
            ],
          ),
          const SizedBox(height: KSpacing.sm),
        ],
        ...switch (load) {
          AsyncValue(value: FeedItems(:final items)) when items.isEmpty => [
            KEmptyState(
              key: RechargeOrdersScreen.emptyKey,
              icon: Icons.receipt_long_outlined,
              title: l10n.rechargeOrdersEmpty,
              message: asAgent
                  ? l10n.rechargeOrdersHint
                  : l10n.rechargeOrdersEmptyBody,
              compact: true,
            ),
          ],
          AsyncValue(
            value: FeedItems(
              :final items,
              :final hasMore,
              :final loadMoreError,
            ),
          ) =>
            [
              for (final o in items) _OrderRow(order: o),
              if (hasMore)
                MeLoadMore(
                  failed: loadMoreError != null,
                  onLoad: ref
                      .read(rechargeOrdersProvider(asAgent).notifier)
                      .loadMore,
                  itemCount: items.length,
                ),
            ],
          AsyncValue(:final error?, isLoading: false) => [
            FailureErrorState(
              title: l10n.errorTitle,
              failure: toAppFailure(error),
              onRetry: () => ref.invalidate(rechargeOrdersProvider(asAgent)),
              compact: true,
            ),
          ],
          _ => [
            const Padding(
              padding: EdgeInsets.all(KSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
        },
      ],
    );
  }
}

class _OrderRow extends StatelessWidget {
  const new({required this.order});

  final RechargeOrder order;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final o = order;
    final other = o.other;
    final color = rechargeOrderStatusColor(p, o.status);
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final coins = KFormat.bidiIsolate(KFormat.grouped(o.coins));
    return Padding(
      key: RechargeOrdersScreen.rowKey(o.id),
      padding: const EdgeInsets.only(bottom: KSpacing.xs),
      child: Material(
        color: p.surfaceRaised,
        borderRadius: BorderRadius.circular(KRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(KRadius.md),
          onTap: () => context.push(AppRoutes.rechargeOrder(o.id)),
          child: Padding(
            padding: const EdgeInsets.all(KSpacing.md),
            child: Row(
              children: [
                KAvatar(
                  name: other.displayName,
                  imageUrl: other.avatarUrl,
                  size: 40,
                ),
                const SizedBox(width: KSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        other.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.bodyStrong.copyWith(color: p.textPrimary),
                      ),
                      Text(
                        '${l10n.rechargeOrderCoinsLine(coins)} · '
                        '${rechargePriceText(l10n, o.price)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.caption.copyWith(color: p.textSecondary),
                      ),
                      Text(
                        rechargeOrderStatusText(l10n, o.status),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.caption.copyWith(
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: KSpacing.sm),
                Text(
                  KFormat.date(o.createdAt, localeTag),
                  style: t.caption.copyWith(color: p.textTertiary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
