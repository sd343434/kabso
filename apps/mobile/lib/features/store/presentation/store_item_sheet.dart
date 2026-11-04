import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/format/k_handle.dart';
import 'package:kabso_live/core/icons/kabso_art.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/bag/application/bag_providers.dart';
import 'package:kabso_live/features/bag/data/bag_repository.dart';
import 'package:kabso_live/features/live/application/live_wallet_controller.dart';
import 'package:kabso_live/features/posts/application/compose_controller.dart'
    show newIdempotencyKey;
import 'package:kabso_live/features/store/data/store_repository.dart';
import 'package:kabso_live/features/store/presentation/store_gift_picker.dart';
import 'package:kabso_live/features/store/presentation/store_preview.dart';
import 'package:kabso_live/features/store/presentation/store_screen.dart';
import 'package:kabso_live/features/wallet/application/wallet_providers.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D270: opens [item]'s sheet (the preview, the durations, the currency,
/// the price and the balance; «شراء» / «إهداء»).
Future<void> showStoreItemSheet(
  BuildContext context, {
  required StoreItem item,
  required StoreBalances balances,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  builder: (_) => StoreItemSheet(item: item, balances: balances),
);

/// The item's sheet (D270, owner; §10.98.3): a big preview of the person
/// wearing it, duration chips (only the durations priced), a currency
/// toggle (only the currencies priced), the price and the balance,
/// «شراء» (Kabso red) and «إهداء». Short coins → «شحن» (the wallet); short
/// cherries → why (they are earned from gifts). After buying for oneself:
/// «ارتدِ الآن».
class StoreItemSheet extends ConsumerStatefulWidget {
  const new({required this.item, required this.balances, super.key});

  final StoreItem item;
  final StoreBalances balances;

  static const buyKey = Key('store.sheet.buy');
  static const giftKey = Key('store.sheet.gift');
  static const rechargeKey = Key('store.sheet.recharge');
  static const shortKey = Key('store.sheet.short');
  static const priceKey = Key('store.sheet.price');
  static const balanceKey = Key('store.sheet.balance');
  static const ownedKey = Key('store.sheet.owned');
  static const wearKey = Key('store.sheet.wear');
  static const doneKey = Key('store.sheet.done');
  static const confirmKey = Key('store.sheet.confirm');
  static Key daysKey(int days) => Key('store.sheet.days.$days');
  static Key currencyKey(StoreCurrency c) =>
      Key('store.sheet.currency.${c.wire}');

  @override
  ConsumerState<StoreItemSheet> createState() => _StoreItemSheetState();
}

class _StoreItemSheetState extends ConsumerState<StoreItemSheet> {
  late StoreCurrency _currency;
  late int _days;
  late StoreBalances _balances;
  bool _busy = false;
  StorePurchase? _bought;
  bool _worn = false;

  StoreItem get _item => widget.item;

  @override
  void initState() {
    super.initState();
    _balances = widget.balances;
    _currency = _item.currencies.firstOrNull ?? StoreCurrency.coins;
    _days = _item.daysIn(_currency).firstOrNull ?? 7;
  }

  void _setCurrency(StoreCurrency c) {
    final days = _item.daysIn(c);
    setState(() {
      _currency = c;
      if (!days.contains(_days)) _days = days.firstOrNull ?? _days;
    });
  }

  int? get _price => _item.priceOf(_currency, _days);

  bool get _short {
    final price = _price;
    return price != null && _balances.of(_currency) < price;
  }

  String _priceText(AppLocalizations l10n, int price) {
    final unit = _currency == StoreCurrency.coins
        ? l10n.storeCoins
        : l10n.storeCherries;
    return '${KFormat.grouped(price)} $unit';
  }

  Future<bool> _confirm(String body, String action) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            key: StoreItemSheet.confirmKey,
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _buy({StoreGiftRecipient? to}) async {
    final l10n = context.l10n;
    final price = _price;
    if (price == null || _busy) return;
    final days = l10n.bagDays(_days);
    final name = KFormat.bidiIsolate(_item.name);
    final ok = await _confirm(
      to == null
          ? l10n.storeBuyConfirm(name, days, _priceText(l10n, price))
          : l10n.storeGiftConfirm(
              name,
              days,
              KHandle.text(l10n, to.username),
              _priceText(l10n, price),
            ),
      to == null ? l10n.storeBuy : l10n.storeGift,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      final result = await ref
          .read(storeRepositoryProvider)
          .buy(
            itemId: _item.id,
            currency: _currency,
            days: _days,
            amount: price,
            idempotencyKey: newIdempotencyKey(),
            recipient: to?.username,
          );
      ref.read(liveCoinsProvider.notifier).set(result.balances.coins);
      ref
        ..invalidate(storeItemsProvider)
        ..invalidate(myBagItemsProvider)
        ..invalidate(myCherriesProvider);
      if (!mounted) return;
      if (to != null) {
        Navigator.of(context).pop();
        KSnack.info(
          context,
          l10n.storeGiftSent(KHandle.text(l10n, to.username)),
        );
        return;
      }
      setState(() {
        _busy = false;
        _balances = result.balances;
        _bought = result;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      final failure = toAppFailure(e);
      if (failure is ServerFailure &&
          (failure.code == ErrorCode.storePriceChanged ||
              failure.code == ErrorCode.storeUnavailable)) {
        ref.invalidate(storeItemsProvider);
      }
      KSnack.error(context, failureMessage(l10n, failure));
    }
  }

  Future<void> _gift() async {
    final to = await showStoreGiftPicker(context);
    if (to == null || !mounted) return;
    await _buy(to: to);
  }

  Future<void> _wear() async {
    final bought = _bought;
    if (bought == null || _busy) return;
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      await ref
          .read(bagRepositoryProvider)
          .setEquipped(bought.kind.wire, bought.code);
      ref.invalidate(myBagItemsProvider);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _worn = true;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final me = ref.watch(currentUserProvider);
    final owned = _bought?.expiresAt ?? _item.ownedUntil;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        KSpacing.lg,
        0,
        KSpacing.lg,
        KSpacing.lg + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StoreItemPreview(
            item: _item,
            name: me?.displayName ?? '',
            avatarUrl: me?.avatarUrl,
          ),
          const SizedBox(height: KSpacing.md),
          Row(
            children: [
              Expanded(
                child: Text(
                  _item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.title.copyWith(color: p.textPrimary),
                ),
              ),
              if (_item.isNew)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: KSpacing.sm,
                    vertical: KSpacing.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: p.primary,
                    borderRadius: BorderRadius.circular(KRadius.pill),
                  ),
                  child: Text(
                    l10n.storeNew,
                    style: t.caption.copyWith(
                      color: p.onPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          Text(
            storeKindLabel(l10n, _item.kind),
            style: t.caption.copyWith(color: p.textSecondary),
          ),
          if (owned != null) ...[
            const SizedBox(height: KSpacing.xs),
            Text(
              l10n.storeOwnedUntil(KFormat.date(owned, l10n.localeName)),
              key: StoreItemSheet.ownedKey,
              style: t.caption.copyWith(color: p.textSecondary),
            ),
          ],
          const SizedBox(height: KSpacing.lg),
          if (_bought case final bought?)
            _done(l10n, bought)
          else
            ..._choices(l10n),
        ],
      ),
    );
  }

  Widget _done(AppLocalizations l10n, StorePurchase bought) {
    final p = context.palette;
    final t = context.textStyles;
    return Column(
      key: StoreItemSheet.doneKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.check_circle_rounded, color: p.success),
            const SizedBox(width: KSpacing.sm),
            Expanded(
              child: Text(
                l10n.storeBought(
                  KFormat.bidiIsolate(bought.name),
                  KFormat.date(bought.expiresAt, l10n.localeName),
                ),
                style: t.body.copyWith(color: p.textPrimary),
              ),
            ),
          ],
        ),
        const SizedBox(height: KSpacing.lg),
        KButton(
          key: StoreItemSheet.wearKey,
          label: _worn ? l10n.storeWorn : l10n.storeWearNow,
          icon: _worn ? Icons.check_rounded : Icons.checkroom_rounded,
          loading: _busy,
          onPressed: _worn ? null : () => unawaited(_wear()),
        ),
      ],
    );
  }

  List<Widget> _choices(AppLocalizations l10n) {
    final p = context.palette;
    final t = context.textStyles;
    final price = _price;
    final currencies = _item.currencies;
    final balance = _balances.of(_currency);
    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(bottom: KSpacing.xs),
      child: Text(text, style: t.label.copyWith(color: p.textSecondary)),
    );
    return [
      label(l10n.storeDuration),
      Row(
        children: [
          for (final d in const [7, 14, 30])
            if (_item.daysIn(_currency).contains(d))
              Padding(
                padding: const EdgeInsetsDirectional.only(end: KSpacing.sm),
                child: _Choice(
                  key: StoreItemSheet.daysKey(d),
                  text: l10n.bagDays(d),
                  selected: _days == d,
                  onTap: () => setState(() => _days = d),
                ),
              ),
        ],
      ),
      if (currencies.length > 1) ...[
        const SizedBox(height: KSpacing.md),
        label(l10n.storePayWith),
        Row(
          children: [
            for (final c in currencies)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: KSpacing.sm),
                child: _Choice(
                  key: StoreItemSheet.currencyKey(c),
                  text: c == StoreCurrency.coins
                      ? l10n.storeCoins
                      : l10n.storeCherries,
                  icon: c == StoreCurrency.coins
                      ? const KabsoArtIcon(KabsoArt.coin, size: 16)
                      : const KCherryIcon(size: 16),
                  selected: _currency == c,
                  onTap: () => _setCurrency(c),
                ),
              ),
          ],
        ),
      ],
      const SizedBox(height: KSpacing.lg),
      Container(
        padding: const EdgeInsets.all(KSpacing.md),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(KRadius.md),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.storePrice,
                    style: t.caption.copyWith(color: p.textSecondary),
                  ),
                  if (price != null)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: StorePriceText(
                        key: StoreItemSheet.priceKey,
                        value: StorePrice(
                          currency: _currency,
                          days: _days,
                          amount: price,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  l10n.storeBalance,
                  style: t.caption.copyWith(color: p.textSecondary),
                ),
                Text(
                  KFormat.grouped(balance),
                  key: StoreItemSheet.balanceKey,
                  textDirection: TextDirection.ltr,
                  style: t.bodyStrong.copyWith(
                    color: _short ? p.error : p.textPrimary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      if (_short) ...[
        const SizedBox(height: KSpacing.sm),
        Text(
          _currency == StoreCurrency.coins
              ? l10n.storeShortCoins
              : l10n.storeShortCherries,
          key: StoreItemSheet.shortKey,
          style: t.caption.copyWith(color: p.error),
        ),
        if (_currency == StoreCurrency.coins) ...[
          const SizedBox(height: KSpacing.sm),
          KButton(
            key: StoreItemSheet.rechargeKey,
            label: l10n.storeRecharge,
            icon: Icons.add_circle_outline_rounded,
            onPressed: () {
              Navigator.of(context).pop();
              unawaited(context.push(AppRoutes.wallet));
            },
          ),
        ],
      ],
      const SizedBox(height: KSpacing.lg),
      Row(
        children: [
          Expanded(
            child: KButton(
              key: StoreItemSheet.giftKey,
              label: l10n.storeGift,
              icon: Icons.card_giftcard_rounded,
              variant: KButtonVariant.secondary,
              onPressed: _short || price == null || _busy
                  ? null
                  : () => unawaited(_gift()),
            ),
          ),
          const SizedBox(width: KSpacing.md),
          Expanded(
            child: KButton(
              key: StoreItemSheet.buyKey,
              label: l10n.storeBuy,
              icon: Icons.shopping_bag_rounded,
              loading: _busy,
              onPressed: _short || price == null
                  ? null
                  : () => unawaited(_buy()),
            ),
          ),
        ],
      ),
    ];
  }
}

/// A selectable pill (a duration, a currency): Kabso red when selected.
class _Choice extends StatelessWidget {
  const new({
    required this.text,
    required this.selected,
    required this.onTap,
    super.key,
    this.icon,
  });

  final String text;
  final bool selected;
  final VoidCallback onTap;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.textStyles;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? p.primary.withValues(alpha: 0.14) : p.surface,
        shape: StadiumBorder(
          side: BorderSide(
            color: selected ? p.primary : p.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: KSpacing.md,
              vertical: KSpacing.sm,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon case final icon?) ...[
                  icon,
                  const SizedBox(width: KSpacing.xs),
                ],
                Text(
                  text,
                  style: t.label.copyWith(
                    color: selected ? p.primaryText : p.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
