import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/icons/app_icons.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/application/live_wallet_controller.dart';
import 'package:kabso_live/features/posts/application/compose_controller.dart';
import 'package:kabso_live/features/status/status_catalogue.dart';
import 'package:kabso_live/features/status/status_emoji_layer.dart';
import 'package:kabso_live/features/status/status_picker_sheet.dart';
import 'package:kabso_live/features/status/status_repository.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// «متجر الحالة» (D376; the owner's v2 pack, rewritten): a store pack —
/// «المميزة» — bought whole with coins for a time (the server's price,
/// owner: 100 000 coins for 30 days; a renewal adds the days to what is
/// left). A live preview of the person's picture with the tapped emoji, the
/// pack's emoji, the price, Buy / Renew; too few coins offers the wallet.
class StatusStoreScreen extends ConsumerStatefulWidget {
  const new({
    required this.packId,
    required this.displayName,
    super.key,
    this.avatarUrl,
    this.avatar,
    this.initialPreviewId,
  });

  final String packId;
  final String displayName;
  final String? avatarUrl;

  /// Tests and goldens: a memory image instead of [avatarUrl].
  final ImageProvider? avatar;
  final String? initialPreviewId;

  static const buyKey = Key('status.store.buy');
  static const shortKey = Key('status.store.short');
  static const rechargeKey = Key('status.store.recharge');
  static const activeKey = Key('status.store.active');
  static const useKey = Key('status.store.use');
  static const balanceKey = Key('status.store.balance');
  static Key optionKey(int days) => Key('status.store.option.$days');
  static Key itemKey(String id) => Key('status.store.item.$id');

  static const double previewRadius = 46;

  @override
  ConsumerState<StatusStoreScreen> createState() => _StatusStoreScreenState();
}

class _StatusStoreScreenState extends ConsumerState<StatusStoreScreen> {
  late StatusEmoji _preview;
  int? _days;
  bool _busy = false;
  bool _short = false;
  bool _bought = false;

  /// The coins after this screen's purchase (the listing's before it).
  int? _coins;

  StatusPack get _pack => StatusCatalogue.pack(widget.packId)!;

  @override
  void initState() {
    super.initState();
    _preview =
        StatusCatalogue.byId(widget.initialPreviewId) ?? _pack.emojis.first;
  }

  Future<bool> _confirm(String body) async {
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
          FilledButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(l10n.statusStoreConfirm),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _buy(StatusPackOption option, {required bool renew}) async {
    if (_busy) return;
    final l10n = context.l10n;
    final days = l10n.statusStoreDays(KFormat.grouped(option.days));
    final price = l10n.statusStorePrice(KFormat.grouped(option.coins));
    final ok = await _confirm(
      renew
          ? l10n.statusStoreConfirmRenew(days, price)
          : l10n.statusStoreConfirmBuy(days, price),
    );
    if (!ok || !mounted) return;
    setState(() {
      _busy = true;
      _short = false;
    });
    try {
      final result = await ref
          .read(statusRepositoryProvider)
          .buy(
            packId: widget.packId,
            days: option.days,
            price: option.coins,
            idempotencyKey: newIdempotencyKey(),
          );
      // The live rooms' balance reads again (if it was read).
      ref.invalidate(liveCoinsProvider);
      ref.invalidate(statusPacksProvider);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _bought = true;
        _coins = result.coins;
      });
      KSnack.success(
        context,
        result.extended ? l10n.statusStoreRenewed : l10n.statusStoreBought,
      );
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      final failure = toAppFailure(e);
      if (failure is ServerFailure) {
        if (failure.code == ErrorCode.insufficientCoins) {
          ref.invalidate(liveCoinsProvider);
          setState(() => _short = true);
          return;
        }
        if (failure.code == ErrorCode.storePriceChanged ||
            failure.code == ErrorCode.storeUnavailable) {
          ref.invalidate(statusPacksProvider);
        }
      }
      KSnack.error(context, failureMessage(l10n, failure));
    }
  }

  Future<void> _use() async {
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      await ref.read(saveStatusEmojiProvider)(_preview.id);
      if (!mounted) return;
      KSnack.success(context, l10n.statusSaved);
      Navigator.of(context).pop();
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
    final load = ref.watch(statusPacksProvider);
    final list = load.value;
    final offer = list?.pack(widget.packId);
    final now = DateTime.now();
    final held = offer?.heldAt(now) ?? false;
    final options = offer?.options ?? const <StatusPackOption>[];
    final option =
        options.where((o) => o.days == _days).firstOrNull ??
        options.firstOrNull;
    final coins = _coins ?? list?.coins;
    return Scaffold(
      backgroundColor: p.background,
      appBar: KAppBar(
        title: Text(l10n.statusStoreTitle),
        actions: [
          if (coins != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: KSpacing.lg),
              child: Center(
                child: Semantics(
                  key: StatusStoreScreen.balanceKey,
                  label: l10n.statusStoreBalance(KFormat.grouped(coins)),
                  excludeSemantics: true,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AppIcon(
                        AppIcons.coin,
                        size: 18,
                        color: KBrandColors.gold,
                      ),
                      const SizedBox(width: KSpacing.xs),
                      Text(
                        KFormat.grouped(coins),
                        style: context.textStyles.bodyStrong.copyWith(
                          color: p.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      body: load.hasError && list == null
          ? KErrorState(
              title: l10n.statusStoreLoadError,
              message: failureMessage(l10n, toAppFailure(load.error!)),
              retryLabel: l10n.actionRetry,
              onRetry: () => ref.invalidate(statusPacksProvider),
            )
          : _body(context, offer, held: held, option: option),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
          KSpacing.lg,
          KSpacing.sm,
          KSpacing.lg,
          KSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_short) ...[
              Text(
                l10n.statusStoreShort,
                key: StatusStoreScreen.shortKey,
                textAlign: TextAlign.center,
                style: context.textStyles.caption.copyWith(color: p.error),
              ),
              const SizedBox(height: KSpacing.sm),
              KButton(
                key: StatusStoreScreen.rechargeKey,
                label: l10n.statusStoreRecharge,
                variant: KButtonVariant.secondary,
                icon: Icons.add_circle_outline_rounded,
                onPressed: () => unawaited(
                  GoRouter.maybeOf(context)?.push(AppRoutes.wallet),
                ),
              ),
              const SizedBox(height: KSpacing.sm),
            ],
            if (_bought && held) ...[
              KButton(
                key: StatusStoreScreen.useKey,
                label: l10n.statusStoreUse,
                variant: KButtonVariant.secondary,
                onPressed: _busy ? null : () => unawaited(_use()),
              ),
              const SizedBox(height: KSpacing.sm),
            ],
            KButton(
              key: StatusStoreScreen.buyKey,
              loading: _busy,
              label: option == null
                  ? l10n.statusStoreNotSold
                  : (held ? l10n.statusStoreRenew : l10n.statusStoreBuy)(
                      l10n.statusStorePrice(KFormat.grouped(option.coins)),
                    ),
              onPressed: option == null || _busy
                  ? null
                  : () => unawaited(_buy(option, renew: held)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    StatusPackOffer? offer, {
    required bool held,
    required StatusPackOption? option,
  }) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final pack = _pack;
    const r = StatusStoreScreen.previewRadius;
    return ListView(
      padding: const EdgeInsets.all(KSpacing.lg),
      children: [
        SizedBox(
          height: r * 4.4,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox.square(
              dimension: r * 2,
              child: StatusAvatar(
                radius: r,
                statusEmojiId: _preview.id,
                child: KAvatar(
                  name: widget.displayName,
                  imageUrl: widget.avatarUrl,
                  image: widget.avatar,
                  size: r * 2,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: KSpacing.sm),
        Text(
          _preview.label(l10n),
          textAlign: TextAlign.center,
          style: t.bodyStrong.copyWith(color: p.textPrimary),
        ),
        const SizedBox(height: KSpacing.xxs),
        Text(
          l10n.statusStoreCount(KFormat.grouped(pack.emojis.length)),
          textAlign: TextAlign.center,
          style: t.caption.copyWith(color: p.textSecondary),
        ),
        if (held && offer?.expiresAt != null) ...[
          const SizedBox(height: KSpacing.md),
          Container(
            key: StatusStoreScreen.activeKey,
            padding: const EdgeInsets.all(KSpacing.md),
            decoration: BoxDecoration(
              color: p.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(KRadius.md),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle_outline_rounded, color: p.success),
                const SizedBox(width: KSpacing.sm),
                Expanded(
                  child: Text(
                    l10n.statusStoreActive(
                      KFormat.date(
                        offer!.expiresAt!.toLocal(),
                        l10n.localeName,
                      ),
                    ),
                    style: t.body.copyWith(color: p.textPrimary),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: KSpacing.lg),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 76,
            mainAxisSpacing: KSpacing.sm,
            crossAxisSpacing: KSpacing.sm,
            childAspectRatio: 0.82,
          ),
          itemCount: pack.emojis.length,
          itemBuilder: (context, i) {
            final e = pack.emojis[i];
            return StatusEmojiCell(
              key: StatusStoreScreen.itemKey(e.id),
              emoji: e,
              selected: e == _preview,
              label: e.label(l10n),
              onTap: () => setState(() => _preview = e),
            );
          },
        ),
        const SizedBox(height: KSpacing.lg),
        for (final o in offer?.options ?? const <StatusPackOption>[])
          Padding(
            padding: const EdgeInsets.only(bottom: KSpacing.sm),
            child: _OptionCard(
              key: StatusStoreScreen.optionKey(o.days),
              days: l10n.statusStoreDays(KFormat.grouped(o.days)),
              price: KFormat.grouped(o.coins),
              selected: o == option,
              onTap: () => setState(() => _days = o.days),
            ),
          ),
      ],
    );
  }
}

class _OptionCard extends StatelessWidget {
  const new({
    required this.days,
    required this.price,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String days;
  final String price;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.textStyles;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        borderRadius: BorderRadius.circular(KRadius.md),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: KSpacing.lg,
            vertical: KSpacing.md,
          ),
          decoration: BoxDecoration(
            color: selected ? p.primary.withValues(alpha: 0.12) : p.surface,
            borderRadius: BorderRadius.circular(KRadius.md),
            border: Border.all(color: selected ? p.primary : p.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  days,
                  style: t.bodyStrong.copyWith(color: p.textPrimary),
                ),
              ),
              const AppIcon(AppIcons.coin, size: 16, color: KBrandColors.gold),
              const SizedBox(width: KSpacing.xs),
              Text(price, style: t.bodyStrong.copyWith(color: p.textPrimary)),
            ],
          ),
        ),
      ),
    );
  }
}
