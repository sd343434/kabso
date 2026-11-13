import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/format/k_handle.dart';
import 'package:kabso_live/core/models/premium_tier.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/auth_controller.dart';
import 'package:kabso_live/features/premium/application/premium_providers.dart';
import 'package:kabso_live/features/premium/data/premium_repository.dart';
import 'package:kabso_live/features/premium/domain/premium_models.dart';
import 'package:kabso_live/features/premium/presentation/premium_labels.dart';
import 'package:kabso_live/features/premium/presentation/premium_rent_sheet.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// `/premium` (D146): the premium usernames store (يوزر مميز). From the top:
/// the person's own premium username (renew, give back, the time left),
/// a search box that checks a name as it is typed, the tier filter, the
/// tier's price, then names that are free and on sale. Prices come from the
/// server only: a tier without a price says it is not on sale yet.
class PremiumStoreScreen extends ConsumerStatefulWidget {
  const new({super.key, this.initialQuery});

  /// A name to check at once (from the username change screen).
  final String? initialQuery;

  static const searchKey = Key('premium.search');
  static const resultKey = Key('premium.result');
  static const resultRentKey = Key('premium.result.rent');
  static const myCardKey = Key('premium.mine');
  static const renewKey = Key('premium.mine.renew');
  static const releaseKey = Key('premium.mine.release');
  static const notOnSaleKey = Key('premium.notOnSale');
  static const noSuggestionsKey = Key('premium.noSuggestions');
  static Key tierTabKey(PremiumTier? tier) =>
      Key('premium.tier.${tier?.wire ?? 'ALL'}');
  static Key suggestionKey(String username) =>
      Key('premium.suggestion.$username');

  @override
  ConsumerState<PremiumStoreScreen> createState() => _PremiumStoreScreenState();
}

class _PremiumStoreScreenState extends ConsumerState<PremiumStoreScreen> {
  late final TextEditingController _search = TextEditingController(
    text: widget.initialQuery ?? '',
  );
  PremiumTier? _tier;

  @override
  void initState() {
    super.initState();
    if ((widget.initialQuery ?? '').isNotEmpty) {
      unawaited(
        Future.microtask(() {
          if (mounted) {
            ref.read(premiumCheckProvider.notifier).onChanged(_search.text);
          }
        }),
      );
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    ref
      ..invalidate(premiumStoreProvider)
      ..invalidate(myPremiumProvider)
      ..invalidate(meProvider);
    await ref.read(premiumCheckProvider.notifier).refresh();
  }

  Future<void> _rent(PremiumNameStatus status) async {
    final rented = await showPremiumRentSheet(context, status: status);
    if (rented == null || !mounted) return;
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final store = ref.watch(premiumStoreProvider(_tier));
    final mine = ref.watch(myPremiumProvider);
    return Scaffold(
      backgroundColor: p.background,
      appBar: KAppBar(
        backgroundColor: p.background,
        centerTitle: true,
        title: Text(l10n.premiumTitle),
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            KSpacing.lg,
            KSpacing.sm,
            KSpacing.lg,
            KSpacing.xxl,
          ),
          children: [
            if (mine case AsyncData(value: final m?)) ...[
              _MyPremiumCard(premium: m, onChanged: _reload),
              const SizedBox(height: KSpacing.lg),
            ],
            _SearchBox(controller: _search),
            const SizedBox(height: KSpacing.sm),
            _CheckResult(onRent: _rent),
            const SizedBox(height: KSpacing.lg),
            _TierTabs(
              selected: _tier,
              onSelected: (t) => setState(() => _tier = t),
            ),
            const SizedBox(height: KSpacing.md),
            switch (store) {
              AsyncData(:final value) => _StoreBody(
                store: value,
                tier: _tier,
                onRent: _rent,
              ),
              AsyncError(:final error) => KErrorState(
                compact: true,
                title: l10n.premiumLoadError,
                message: failureMessage(l10n, toAppFailure(error)),
                retryLabel: l10n.actionRetry,
                onRetry: () => ref.invalidate(premiumStoreProvider(_tier)),
              ),
              _ => const Padding(
                padding: EdgeInsets.all(KSpacing.xl),
                child: Center(child: CircularProgressIndicator()),
              ),
            },
          ],
        ),
      ),
    );
  }
}

/// The search box: `@` then the name, Latin, lower case, checked as typed.
class _SearchBox extends ConsumerWidget {
  const new({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    return TextField(
      key: PremiumStoreScreen.searchKey,
      controller: controller,
      textDirection: TextDirection.ltr,
      autocorrect: false,
      enableSuggestions: false,
      keyboardType: TextInputType.visiblePassword,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9_.@]')),
        LengthLimitingTextInputFormatter(31),
      ],
      onChanged: ref.read(premiumCheckProvider.notifier).onChanged,
      decoration: InputDecoration(
        hintText: l10n.premiumSearchHint,
        prefixIcon: Icon(Icons.search_rounded, color: p.textSecondary),
        filled: true,
        fillColor: p.surfaceRaised,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KRadius.pill),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
      ),
    );
  }
}

/// The answer of the live check under the search box.
class _CheckResult extends ConsumerWidget {
  const new({required this.onRent});

  final ValueChanged<PremiumNameStatus> onRent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final text = context.textStyles;
    final check = ref.watch(premiumCheckProvider);
    final child = switch (check) {
      PremiumCheckIdle() => Text(
        l10n.premiumSearchHelp,
        style: text.caption.copyWith(color: p.textSecondary),
      ),
      PremiumCheckLoading() => Row(
        children: [
          const SizedBox.square(
            dimension: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: KSpacing.sm),
          Text(
            l10n.usernameChecking,
            style: text.caption.copyWith(color: p.textSecondary),
          ),
        ],
      ),
      PremiumCheckFailed(:final failure) => Text(
        failureMessage(l10n, failure),
        style: text.caption.copyWith(color: p.error),
      ),
      PremiumCheckResult(:final status) => _ResultCard(
        status: status,
        onRent: onRent,
      ),
    };
    return AnimatedSize(
      duration: const Duration(milliseconds: 150),
      alignment: AlignmentDirectional.topStart,
      child: KeyedSubtree(key: PremiumStoreScreen.resultKey, child: child),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const new({required this.status, required this.onRent});

  final PremiumNameStatus status;
  final ValueChanged<PremiumNameStatus> onRent;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final text = context.textStyles;
    final tier = status.tier;
    final good = status.state.purchasable;
    return Container(
      padding: const EdgeInsets.all(KSpacing.md),
      decoration: BoxDecoration(
        color: p.surfaceRaised,
        borderRadius: BorderRadius.circular(KRadius.lg),
        border: Border.all(color: good ? p.success : p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: tier == null
                    ? Text(
                        KHandle.isolated(status.username),
                        style: text.bodyStrong,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    : KSpecialUsername(
                        username: status.username,
                        tier: tier,
                        height: 24,
                      ),
              ),
              if (tier != null) ...[
                const SizedBox(width: KSpacing.sm),
                Text(
                  premiumTierName(l10n, tier),
                  style: text.caption.copyWith(color: p.textSecondary),
                ),
              ],
            ],
          ),
          const SizedBox(height: KSpacing.sm),
          Text(
            premiumStateLine(l10n, status),
            style: text.body.copyWith(
              color: good ? p.textPrimary : p.textSecondary,
            ),
          ),
          if (status.state == PremiumNameState.held && status.heldUntil != null)
            Text(
              l10n.premiumHeldUntil(
                KFormat.date(status.heldUntil!.toLocal(), l10n.localeName),
              ),
              style: text.caption.copyWith(color: p.textSecondary),
            ),
          if (good && status.priceCoins != null) ...[
            const SizedBox(height: KSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: Text(
                    premiumPriceLabel(
                      l10n,
                      status.priceCoins!,
                      status.periodDays,
                    ),
                    style: text.bodyStrong,
                  ),
                ),
                KButton(
                  key: PremiumStoreScreen.resultRentKey,
                  expand: false,
                  label: status.state == PremiumNameState.available
                      ? l10n.premiumRent
                      : l10n.premiumRenew,
                  onPressed: () => onRent(status),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// All · Diamond · Gold · Silver.
class _TierTabs extends StatelessWidget {
  const new({required this.selected, required this.onSelected});

  final PremiumTier? selected;
  final ValueChanged<PremiumTier?> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final tier in <PremiumTier?>[null, ...PremiumTier.values])
            Padding(
              padding: const EdgeInsetsDirectional.only(end: KSpacing.sm),
              child: ChoiceChip(
                key: PremiumStoreScreen.tierTabKey(tier),
                label: Text(
                  tier == null
                      ? l10n.premiumTierAll
                      : premiumTierName(l10n, tier),
                ),
                selected: selected == tier,
                onSelected: (_) => onSelected(tier),
              ),
            ),
        ],
      ),
    );
  }
}

class _StoreBody extends StatelessWidget {
  const new({required this.store, required this.tier, required this.onRent});

  final PremiumStore store;
  final PremiumTier? tier;
  final ValueChanged<PremiumNameStatus> onRent;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final text = context.textStyles;
    final tiers = tier == null ? PremiumTier.values : [tier!];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final t in tiers) _TierRow(tier: t, store: store),
        const SizedBox(height: KSpacing.md),
        if (store.nothingOnSale)
          KEmptyState(
            key: PremiumStoreScreen.notOnSaleKey,
            compact: true,
            icon: Icons.workspace_premium_outlined,
            title: l10n.premiumNotOnSaleTitle,
            message: l10n.premiumNotOnSaleMessage,
          )
        else if (store.suggestions.isEmpty)
          KEmptyState(
            key: PremiumStoreScreen.noSuggestionsKey,
            compact: true,
            icon: Icons.search_off_rounded,
            title: l10n.premiumNoSuggestionsTitle,
            message: l10n.premiumNoSuggestionsMessage,
          )
        else ...[
          Text(l10n.premiumSuggestions, style: text.title),
          const SizedBox(height: KSpacing.sm),
          // Two even columns (three on wide screens).
          LayoutBuilder(
            builder: (context, box) {
              final columns = box.maxWidth >= 480 ? 3 : 2;
              final width =
                  (box.maxWidth - KSpacing.sm * (columns - 1)) / columns;
              return Wrap(
                spacing: KSpacing.sm,
                runSpacing: KSpacing.sm,
                children: [
                  for (final s in store.suggestions)
                    SizedBox(
                      width: width,
                      child: _SuggestionTile(status: s, onTap: () => onRent(s)),
                    ),
                ],
              );
            },
          ),
        ],
        const SizedBox(height: KSpacing.xl),
        Text(
          l10n.premiumRules(store.periodDays, store.graceDays),
          style: text.caption.copyWith(color: p.textSecondary),
        ),
      ],
    );
  }
}

/// A tier's line: its badge sample, what names it holds, its price.
class _TierRow extends StatelessWidget {
  const new({required this.tier, required this.store});

  final PremiumTier tier;
  final PremiumStore store;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final text = context.textStyles;
    final price = store.priceOf(tier);
    return Padding(
      padding: const EdgeInsets.only(bottom: KSpacing.sm),
      child: Row(
        children: [
          Image.asset(
            kSpecialUsernameMedal(tier),
            width: 28,
            height: 28,
            excludeFromSemantics: true,
          ),
          const SizedBox(width: KSpacing.xs),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${premiumTierName(l10n, tier)}  ',
                    style: text.label.copyWith(color: p.textPrimary),
                  ),
                  TextSpan(
                    text: premiumTierRule(l10n, tier),
                    style: text.caption.copyWith(color: p.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          Text(
            price == null
                ? l10n.premiumTierNotOnSale
                : premiumPriceLabel(l10n, price, store.periodDays),
            style: text.caption.copyWith(
              color: price == null ? p.textTertiary : p.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  const new({required this.status, required this.onTap});

  final PremiumNameStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final text = context.textStyles;
    final tier = status.tier ?? PremiumTier.silver;
    return Material(
      color: p.surfaceRaised,
      borderRadius: BorderRadius.circular(KRadius.md),
      child: InkWell(
        key: PremiumStoreScreen.suggestionKey(status.username),
        borderRadius: BorderRadius.circular(KRadius.md),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: KSpacing.sm,
              vertical: KSpacing.sm,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: KSpecialUsername(
                    username: status.username,
                    tier: tier,
                    animate: false,
                  ),
                ),
                const SizedBox(height: KSpacing.xs),
                Text(
                  status.priceCoins == null
                      ? l10n.premiumTierNotOnSale
                      : l10n.premiumCoins(KFormat.grouped(status.priceCoins!)),
                  style: text.caption.copyWith(color: p.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The person's own premium username: its badge, the time left (or the
/// grace period), Renew and Give back.
class _MyPremiumCard extends ConsumerStatefulWidget {
  const new({required this.premium, required this.onChanged});

  final MyPremiumUsername premium;
  final Future<void> Function() onChanged;

  @override
  ConsumerState<_MyPremiumCard> createState() => _MyPremiumCardState();
}

class _MyPremiumCardState extends ConsumerState<_MyPremiumCard> {
  Timer? _tick;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // The countdown moves once a minute.
    _tick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _renew() async {
    final m = widget.premium;
    final price = m.renewPriceCoins;
    if (price == null) return;
    final rented = await showPremiumRentSheet(
      context,
      status: PremiumNameStatus(
        username: m.username,
        tier: m.tier,
        state: m.grace ? PremiumNameState.yoursGrace : PremiumNameState.yours,
        priceCoins: price,
        periodDays: m.periodDays,
        heldUntil: m.graceUntil,
      ),
      current: m,
    );
    if (rented != null && mounted) await widget.onChanged();
  }

  Future<void> _release() async {
    final l10n = context.l10n;
    final m = widget.premium;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.premiumReleaseTitle),
        content: Text(l10n.premiumReleaseBody(m.username, m.regularUsername)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.premiumRelease),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(premiumRepositoryProvider).release();
      if (!mounted) return;
      KSnack.info(context, l10n.premiumReleased(m.regularUsername));
      await widget.onChanged();
    } on Object catch (e) {
      if (mounted) KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final text = context.textStyles;
    final m = widget.premium;
    final now = clock.now();
    final String line;
    if (m.grace) {
      line = l10n.premiumMineGrace(
        m.regularUsername,
        premiumTimeLeft(l10n, (m.graceUntil ?? now).difference(now)),
      );
    } else if (m.expiresAt == null) {
      line = l10n.premiumMineNoEnd;
    } else {
      line = l10n.premiumMineLeft(
        premiumTimeLeft(l10n, m.expiresAt!.difference(now)),
      );
    }
    return Container(
      key: PremiumStoreScreen.myCardKey,
      padding: const EdgeInsets.all(KSpacing.lg),
      decoration: BoxDecoration(
        color: p.surfaceRaised,
        borderRadius: BorderRadius.circular(KRadius.lg),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            m.grace ? l10n.premiumMineGraceTitle : l10n.premiumMineTitle,
            style: text.caption.copyWith(color: p.textSecondary),
          ),
          const SizedBox(height: KSpacing.sm),
          KSpecialUsername(username: m.username, tier: m.tier, height: 28),
          const SizedBox(height: KSpacing.sm),
          Text(line, style: text.body),
          if (m.granted)
            Text(
              l10n.premiumMineGranted,
              style: text.caption.copyWith(color: p.textSecondary),
            ),
          const SizedBox(height: KSpacing.md),
          Row(
            children: [
              if (m.canRenew && m.renewPriceCoins != null)
                Expanded(
                  child: KButton(
                    key: PremiumStoreScreen.renewKey,
                    label: l10n.premiumRenewFor(
                      KFormat.grouped(m.renewPriceCoins!),
                    ),
                    onPressed: _busy ? null : _renew,
                  ),
                ),
              if (!m.grace) ...[
                const SizedBox(width: KSpacing.sm),
                KButton(
                  key: PremiumStoreScreen.releaseKey,
                  expand: false,
                  variant: KButtonVariant.ghost,
                  loading: _busy,
                  label: l10n.premiumRelease,
                  onPressed: _release,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
