import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/icons/kabso_art.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/store/data/store_repository.dart';
import 'package:kabso_live/features/store/presentation/store_item_sheet.dart';
import 'package:kabso_live/features/store/presentation/store_preview.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D270: the store's items for the session's language and person.
final FutureProvider<StoreItemList> storeItemsProvider =
    FutureProvider.autoDispose((ref) {
      ref
        ..watch(languageControllerProvider)
        ..watch(currentUserProvider.select((u) => u?.id));
      return ref.watch(storeRepositoryProvider).items();
    });

/// «المتجر» (D270, owner; CONVENTIONS §10.98.3), Bigo-style: the balances,
/// tabs by kind, and a grid of items — the animated preview, the name,
/// «جديد», the lowest price (coins first); a tap opens the item's sheet.
class StoreScreen extends ConsumerStatefulWidget {
  const new({super.key});

  static const gridKey = Key('store.grid');
  static const tabsKey = Key('store.tabs');
  static const emptyKey = Key('store.empty');
  static const coinsKey = Key('store.balance.coins');
  static const cherriesKey = Key('store.balance.cherries');
  static Key itemKey(String code) => Key('store.item.$code');
  static Key newKey(String code) => Key('store.item.$code.new');
  static Key ownedKey(String code) => Key('store.item.$code.owned');

  @override
  ConsumerState<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends ConsumerState<StoreScreen> {
  StoreKind? _kind;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final list = ref.watch(storeItemsProvider);
    return Scaffold(
      backgroundColor: p.background,
      appBar: KAppBar(
        title: Text(l10n.storeTitle),
        actions: [
          IconButton(
            tooltip: l10n.bagTitle,
            icon: const Icon(Icons.backpack_rounded),
            onPressed: () => unawaited(context.push(AppRoutes.bag)),
          ),
        ],
      ),
      body: switch (list) {
        AsyncData(:final value) => _body(value),
        AsyncError(:final error) => KErrorState(
          title: l10n.storeTitle,
          message: failureMessage(l10n, toAppFailure(error)),
          retryLabel: l10n.actionRetry,
          onRetry: () => ref.invalidate(storeItemsProvider),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Widget _body(StoreItemList list) {
    final l10n = context.l10n;
    if (list.kinds.isEmpty) {
      return KEmptyState(
        key: StoreScreen.emptyKey,
        icon: Icons.storefront_rounded,
        title: l10n.storeTitle,
        message: l10n.storeEmpty,
      );
    }
    final kind = list.kinds.contains(_kind) ? _kind! : list.kinds.first;
    final items = list.of(kind);
    return Column(
      children: [
        _Balances(balances: list.balances),
        KScrollableTabs(
          key: StoreScreen.tabsKey,
          labels: [for (final k in list.kinds) storeKindLabel(l10n, k)],
          selectedIndex: list.kinds.indexOf(kind),
          onSelected: (i) => setState(() => _kind = list.kinds[i]),
        ),
        Expanded(
          child: GridView.builder(
            key: StoreScreen.gridKey,
            padding: EdgeInsets.fromLTRB(
              KSpacing.lg,
              KSpacing.md,
              KSpacing.lg,
              KSpacing.lg + MediaQuery.paddingOf(context).bottom,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: KSpacing.md,
              crossAxisSpacing: KSpacing.md,
              childAspectRatio: 0.72,
            ),
            itemCount: items.length,
            itemBuilder: (context, i) => StoreItemTile(
              item: items[i],
              onTap: () => unawaited(_open(items[i], list.balances)),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _open(StoreItem item, StoreBalances balances) async {
    await showStoreItemSheet(context, item: item, balances: balances);
  }
}

class _Balances extends StatelessWidget {
  const new({required this.balances});

  final StoreBalances balances;

  @override
  Widget build(BuildContext context) {
    final t = context.textStyles;
    final p = context.palette;
    Widget pill(Key key, Widget icon, int amount) => Container(
      key: key,
      padding: const EdgeInsets.symmetric(
        horizontal: KSpacing.md,
        vertical: KSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(KRadius.pill),
        border: Border.all(color: p.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(width: KSpacing.xs),
          Text(
            KFormat.grouped(amount),
            textDirection: TextDirection.ltr,
            style: t.label.copyWith(color: p.textPrimary),
          ),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        KSpacing.lg,
        KSpacing.sm,
        KSpacing.lg,
        KSpacing.xs,
      ),
      child: Row(
        children: [
          pill(
            StoreScreen.coinsKey,
            const KabsoArtIcon(KabsoArt.coin, size: 18),
            balances.coins,
          ),
          const SizedBox(width: KSpacing.sm),
          pill(
            StoreScreen.cherriesKey,
            const KCherryIcon(size: 18),
            balances.cherries,
          ),
        ],
      ),
    );
  }
}

/// One item of the grid: the art on a soft tile, «جديد» at the top start,
/// «تملكه» at the top end, the name and the lowest price.
class StoreItemTile extends StatelessWidget {
  const new({required this.item, required this.onTap, super.key});

  final StoreItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final from = item.from;
    return Semantics(
      button: true,
      label: item.name,
      child: Material(
        key: StoreScreen.itemKey(item.code),
        color: p.surface,
        borderRadius: BorderRadius.circular(KRadius.md),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(KSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.all(KSpacing.xs),
                          child: StoreArtView(art: item.art, kind: item.kind),
                        ),
                      ),
                      if (item.isNew)
                        PositionedDirectional(
                          top: 0,
                          start: 0,
                          child: _Tag(
                            key: StoreScreen.newKey(item.code),
                            text: l10n.storeNew,
                            color: p.primary,
                            ink: p.onPrimary,
                          ),
                        ),
                      if (item.ownedUntil != null)
                        PositionedDirectional(
                          top: 0,
                          end: 0,
                          child: _Tag(
                            key: StoreScreen.ownedKey(item.code),
                            text: l10n.storeOwned,
                            color: p.surfaceOverlay,
                            ink: p.textPrimary,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: KSpacing.xs),
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: t.label.copyWith(color: p.textPrimary),
                ),
                const SizedBox(height: KSpacing.xxs),
                if (from != null) StorePriceText(value: from, compact: true),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const new({
    required this.text,
    required this.color,
    required this.ink,
    super.key,
  });

  final String text;
  final Color color;
  final Color ink;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(KRadius.pill),
    ),
    child: Text(
      text,
      textScaler: TextScaler.noScaling,
      style: context.textStyles.caption.copyWith(
        color: ink,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        height: 1.3,
      ),
    ),
  );
}

/// A price with its currency's icon (the coin or the cherry), centred.
class StorePriceText extends StatelessWidget {
  const new({required this.value, super.key, this.compact = false});

  final StorePrice value;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.textStyles;
    final size = compact ? 14.0 : 20.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (value.currency == StoreCurrency.coins)
          KabsoArtIcon(KabsoArt.coin, size: size)
        else
          KCherryIcon(size: size),
        const SizedBox(width: KSpacing.xxs),
        Flexible(
          child: Text(
            KFormat.grouped(value.amount),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textDirection: TextDirection.ltr,
            style: (compact ? t.caption : t.title).copyWith(
              color: p.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
