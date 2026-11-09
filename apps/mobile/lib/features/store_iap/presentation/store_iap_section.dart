import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/icons/kabso_art.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/store_iap/application/store_iap_controller.dart';
import 'package:kabso_live/features/store_iap/data/store_billing.dart';
import 'package:kabso_live/features/store_iap/data/store_iap_repository.dart';
import 'package:kabso_live/features/wallet/presentation/wallet_parts.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// The store's name for the copy («Google Play» / «App Store»).
String storeName(StorePlatform platform) =>
    platform == StorePlatform.android ? 'Google Play' : 'App Store';

/// D345 (CONVENTIONS §10.144): «الشراء من المتجر» in the wallet's gold tab —
/// the store's packages at the store's own prices; tapping one opens the
/// no-refund consent sheet, then the store's sheet; the status of the
/// purchase underneath (confirming, pending, added, refused). Hidden when the
/// store is off on this server or phone; a banned device and the once rule
/// get a message instead of the packages.
class StoreIapSection extends ConsumerWidget {
  const new({super.key});

  static const sectionKey = Key('storeIap.section');
  static const bannedKey = Key('storeIap.banned');
  static const limitKey = Key('storeIap.limit');
  static const statusKey = Key('storeIap.status');

  static Key productKey(String id) => Key('storeIap.product.$id');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offer = ref.watch(storeOfferProvider).value;
    // Listening for the store's updates (and transactions delivered again)
    // while the wallet is open.
    final purchase = ref.watch(storePurchaseProvider);
    if (offer == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final unavailable = offer.catalog.unavailable;
    return Padding(
      key: sectionKey,
      padding: const EdgeInsets.only(top: KSpacing.md),
      child: WalletSection(
        title: l10n.storeIapTitle,
        children: [
          if (unavailable == StoreUnavailable.deviceBanned)
            _Notice(
              key: bannedKey,
              icon: Icons.block_rounded,
              text: l10n.storeIapDeviceBanned,
              danger: true,
            )
          else if (unavailable == StoreUnavailable.limitReached)
            _Notice(
              key: limitKey,
              icon: Icons.info_outline_rounded,
              text: l10n.storeIapLimitReached,
            )
          else
            _Products(offer: offer, purchase: purchase),
          if (purchase.phase != StorePhase.idle &&
              purchase.phase != StorePhase.buying)
            Padding(
              padding: const EdgeInsets.only(top: KSpacing.sm),
              child: StorePurchaseStatus(
                key: statusKey,
                state: purchase,
                onDismiss: () =>
                    ref.read(storePurchaseProvider.notifier).dismiss(),
              ),
            ),
        ],
      ),
    );
  }
}

class _Products extends ConsumerWidget {
  const new({required this.offer, required this.purchase});

  final StoreOffer offer;
  final StorePurchaseState purchase;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final platform = ref.watch(storePlatformProvider);
    final products = offer.products;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (platform != null)
          Padding(
            padding: const EdgeInsets.only(bottom: KSpacing.xs),
            child: Text(
              l10n.storeIapVia(storeName(platform)),
              style: t.caption.copyWith(color: p.textSecondary),
            ),
          ),
        for (final (i, product) in products.indexed) ...[
          if (i > 0) const SizedBox(height: KSpacing.xs),
          StoreProductTile(
            key: StoreIapSection.productKey(product.productId),
            coins: product.coins,
            storePrice: offer.prices[product.productId]!,
            enabled: !purchase.busy && platform != null,
            onTap: () => unawaited(
              _start(context, ref, product, offer.catalog, platform!),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _start(
    BuildContext context,
    WidgetRef ref,
    StoreCoinProduct product,
    StoreCatalog catalog,
    StorePlatform platform,
  ) async {
    final consent = await showStoreConsentSheet(
      context,
      platform: platform,
      coins: product.coins,
      storePrice: offer.prices[product.productId]!,
      consentVersion: catalog.consentVersion,
    );
    if (consent == null) return;
    await ref
        .read(storePurchaseProvider.notifier)
        .buy(product, catalog, consent);
  }
}

/// The platform of this phone's store (null: none).
final storePlatformProvider = Provider<StorePlatform?>(
  (ref) => ref.watch(storeBillingProvider).platform,
);

/// One store package: the coins and the store's price, one tap to buy.
class StoreProductTile extends StatelessWidget {
  const new({
    required this.coins,
    required this.storePrice,
    required this.enabled,
    required this.onTap,
    super.key,
  });

  final int coins;
  final String storePrice;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final amount = KFormat.grouped(coins);
    return Semantics(
      button: true,
      enabled: enabled,
      label: l10n.storeIapBuyLabel(amount, KFormat.bidiIsolate(storePrice)),
      excludeSemantics: true,
      child: Material(
        color: p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KRadius.sm),
          side: BorderSide(color: p.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: KSizes.minTouchTarget),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: KSpacing.md,
                vertical: KSpacing.sm,
              ),
              child: Row(
                children: [
                  const KabsoArtIcon(KabsoArt.coin, size: 22),
                  const SizedBox(width: KSpacing.sm),
                  Expanded(
                    child: Text(
                      l10n.storeIapCoins(amount),
                      style: t.bodyStrong.copyWith(color: p.textPrimary),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: enabled ? p.primary : p.surfaceRaised,
                      borderRadius: BorderRadius.circular(KRadius.pill),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: KSpacing.md,
                        vertical: KSpacing.xs,
                      ),
                      child: Text(
                        storePrice,
                        textDirection: TextDirection.ltr,
                        style: t.label.copyWith(
                          color: enabled ? p.onPrimary : p.textTertiary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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

class _Notice extends StatelessWidget {
  const new({
    required this.icon,
    required this.text,
    super.key,
    this.danger = false,
  });

  final IconData icon;
  final String text;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.textStyles;
    final color = danger ? p.error : p.textSecondary;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: KSpacing.sm),
          Expanded(
            child: Text(text, style: t.body.copyWith(color: color)),
          ),
        ],
      ),
    );
  }
}

/// The purchase's status line under the packages.
class StorePurchaseStatus extends StatelessWidget {
  const new({required this.state, required this.onDismiss, super.key});

  final StorePurchaseState state;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final failure = state.failure;
    final (icon, text, color, busy) = switch (state.phase) {
      StorePhase.verifying => (
        Icons.hourglass_top_rounded,
        l10n.storeIapVerifying,
        p.textSecondary,
        true,
      ),
      StorePhase.pending => (
        Icons.schedule_rounded,
        l10n.storeIapPending,
        p.textSecondary,
        false,
      ),
      StorePhase.success => (
        Icons.check_circle_rounded,
        l10n.storeIapSuccess(KFormat.grouped(state.coins ?? 0)),
        p.success,
        false,
      ),
      StorePhase.rejected => (
        Icons.info_outline_rounded,
        l10n.storeIapRejected,
        p.warning,
        false,
      ),
      StorePhase.failed => (
        Icons.error_outline_rounded,
        failure != null
            ? failureMessage(l10n, failure)
            : l10n.storeIapStoreError,
        p.error,
        false,
      ),
      StorePhase.idle || StorePhase.buying => (
        Icons.hourglass_top_rounded,
        l10n.storeIapVerifying,
        p.textSecondary,
        true,
      ),
    };
    return Semantics(
      container: true,
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(KRadius.sm),
        ),
        child: Padding(
          padding: const EdgeInsets.all(KSpacing.sm),
          child: Row(
            children: [
              if (busy)
                SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                  ),
                )
              else
                Icon(icon, size: 20, color: color),
              const SizedBox(width: KSpacing.sm),
              Expanded(
                child: Text(text, style: t.body.copyWith(color: color)),
              ),
              if (!busy && state.phase != StorePhase.pending)
                TextButton(
                  onPressed: onDismiss,
                  child: Text(l10n.storeIapDismiss),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// D345: the no-refund consent before every store purchase: what is bought,
/// immediate delivery, coins used up in use and not refundable, a store
/// refund treated as fraud (claw-back, account and device banned), and the
/// consumption data sent to the store on a refund request. The button stays
/// disabled until the box is ticked. Returns the consent, or null.
Future<StoreConsent?> showStoreConsentSheet(
  BuildContext context, {
  required StorePlatform platform,
  required int coins,
  required String storePrice,
  required String consentVersion,
}) => showModalBottomSheet<StoreConsent>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => StoreConsentSheet(
    platform: platform,
    coins: coins,
    storePrice: storePrice,
    consentVersion: consentVersion,
  ),
);

class StoreConsentSheet extends StatefulWidget {
  const new({
    required this.platform,
    required this.coins,
    required this.storePrice,
    required this.consentVersion,
    super.key,
  });

  final StorePlatform platform;
  final int coins;
  final String storePrice;
  final String consentVersion;

  static const checkKey = Key('storeIap.consent.check');
  static const continueKey = Key('storeIap.consent.continue');

  @override
  State<StoreConsentSheet> createState() => _StoreConsentSheetState();
}

class _StoreConsentSheetState extends State<StoreConsentSheet> {
  bool _agreed = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final store = storeName(widget.platform);
    Widget point(IconData icon, String text, {Color? color}) => Padding(
      padding: const EdgeInsets.only(bottom: KSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color ?? p.textSecondary),
          const SizedBox(width: KSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: t.body.copyWith(color: color ?? p.textPrimary),
            ),
          ),
        ],
      ),
    );
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          KSpacing.lg,
          0,
          KSpacing.lg,
          KSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.storeIapConsentTitle, style: t.title),
            const SizedBox(height: KSpacing.sm),
            Row(
              children: [
                const KabsoArtIcon(KabsoArt.coin, size: 22),
                const SizedBox(width: KSpacing.xs),
                Expanded(
                  child: Text(
                    l10n.storeIapConsentPrice(
                      KFormat.grouped(widget.coins),
                      KFormat.bidiIsolate(widget.storePrice),
                    ),
                    style: t.bodyStrong,
                  ),
                ),
              ],
            ),
            const SizedBox(height: KSpacing.md),
            point(Icons.bolt_rounded, l10n.storeIapConsentDelivery),
            point(
              Icons.gpp_bad_outlined,
              l10n.storeIapConsentFraud,
              color: p.error,
            ),
            point(Icons.share_outlined, l10n.storeIapConsentShare(store)),
            Text(
              l10n.storeIapConsentTerms,
              style: t.caption.copyWith(color: p.textSecondary),
            ),
            const SizedBox(height: KSpacing.sm),
            CheckboxListTile(
              key: StoreConsentSheet.checkKey,
              value: _agreed,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (v) => setState(() => _agreed = v ?? false),
              title: Text(l10n.storeIapConsentCheck, style: t.body),
            ),
            const SizedBox(height: KSpacing.sm),
            FilledButton(
              key: StoreConsentSheet.continueKey,
              onPressed: _agreed
                  ? () => Navigator.of(context).pop(
                      StoreConsent(
                        version: widget.consentVersion,
                        shareConsumptionData: true,
                      ),
                    )
                  : null,
              child: Text(l10n.storeIapConsentContinue(store)),
            ),
          ],
        ),
      ),
    );
  }
}
