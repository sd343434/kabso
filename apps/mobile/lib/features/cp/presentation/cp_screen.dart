import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/ids/client_id.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/cp/application/cp_providers.dart';
import 'package:kabso_live/features/cp/data/cp_repository.dart';
import 'package:kabso_live/features/cp/domain/cp_models.dart';
import 'package:kabso_live/features/families/application/families_providers.dart';
import 'package:kabso_live/features/families/presentation/bond_widgets.dart';
import 'package:kabso_live/features/live/application/live_wallet_controller.dart';
import 'package:kabso_live/features/profile/profile_screen.dart'
    show PostGridLoadMore;
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// `/cp` (CP-018, §10.21): your couple — the partner, the day count, the
/// tier and the points to the next one, CP gifts from the server's preset
/// amounts and End — or the empty state; then the requests received
/// (Accept, Decline) and sent (Cancel: the coins come back).
class CpScreen extends ConsumerStatefulWidget {
  const new({super.key, this.initial = CpDirection.incoming});

  final CpDirection initial;

  static const coupleKey = Key('cp.couple');
  static const noneKey = Key('cp.none');
  static const endKey = Key('cp.end');
  static const spaceKey = Key('cp.space');
  static const incomingKey = Key('cp.tab.incoming');
  static const outgoingKey = Key('cp.tab.outgoing');

  static Key giftKey(int amount) => Key('cp.gift.$amount');
  static Key acceptKey(String id) => Key('cp.request.$id.accept');
  static Key declineKey(String id) => Key('cp.request.$id.decline');
  static Key cancelKey(String id) => Key('cp.request.$id.cancel');

  @override
  ConsumerState<CpScreen> createState() => _CpScreenState();
}

class _CpScreenState extends ConsumerState<CpScreen> {
  late CpDirection _direction = widget.initial;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final mine = ref.watch(myCpProvider);
    final requests = ref.watch(cpRequestsProvider(_direction));
    final rows = <Widget>[
      switch (mine) {
        AsyncValue(value: final CpCouple cp) => _Couple(cp: cp),
        AsyncValue(hasValue: true) => Padding(
          key: CpScreen.noneKey,
          padding: const EdgeInsets.symmetric(vertical: KSpacing.lg),
          child: KEmptyState(
            icon: Icons.favorite_border_rounded,
            iconColor: const Color(0xFFD03468),
            title: l10n.cpNoneTitle,
            message: l10n.cpNoneBody,
            compact: true,
          ),
        ),
        AsyncValue(:final error?, isLoading: false) => FailureErrorState(
          title: l10n.cpLoadError,
          failure: toAppFailure(error),
          onRetry: () => ref.invalidate(myCpProvider),
          compact: true,
        ),
        _ => const Padding(
          padding: EdgeInsets.all(KSpacing.xl),
          child: Center(child: CircularProgressIndicator()),
        ),
      },
      BondSectionTitle(l10n.cpRequestsTitle),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
        child: Wrap(
          spacing: KSpacing.sm,
          runSpacing: KSpacing.xs,
          children: [
            for (final (d, key, label) in [
              (CpDirection.incoming, CpScreen.incomingKey, l10n.cpIncoming),
              (CpDirection.outgoing, CpScreen.outgoingKey, l10n.cpOutgoing),
            ])
              ChoiceChip(
                key: key,
                label: Text(label),
                selected: _direction == d,
                onSelected: (_) => setState(() => _direction = d),
              ),
          ],
        ),
      ),
    ];
    final notifier = ref.read(cpRequestsProvider(_direction).notifier);
    final Widget list = switch (requests) {
      AsyncValue(
        value: FeedItems(:final items, :final hasMore, :final loadMoreError),
      ) =>
        ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: KSpacing.xl),
          itemCount:
              rows.length +
              (items.isEmpty ? 1 : items.length) +
              (hasMore ? 1 : 0),
          itemBuilder: (context, i) {
            if (i < rows.length) return rows[i];
            final j = i - rows.length;
            if (items.isEmpty && j == 0) {
              return Padding(
                padding: const EdgeInsets.all(KSpacing.lg),
                child: Text(
                  _direction == CpDirection.incoming
                      ? l10n.cpIncomingEmpty
                      : l10n.cpOutgoingEmpty,
                  textAlign: TextAlign.center,
                  style: context.textStyles.caption.copyWith(
                    color: p.textSecondary,
                  ),
                ),
              );
            }
            if (j < items.length) {
              return _RequestTile(request: items[j], direction: _direction);
            }
            return loadMoreError == null
                ? PostGridLoadMore(
                    key: ValueKey(items.length),
                    onVisible: () => unawaited(notifier.loadMore()),
                  )
                : Center(
                    child: TextButton(
                      onPressed: () => unawaited(notifier.loadMore()),
                      child: Text(l10n.actionRetry),
                    ),
                  );
          },
        ),
      AsyncValue(:final error?, isLoading: false) => ListView(
        children: [
          ...rows,
          FailureErrorState(
            title: l10n.cpLoadError,
            failure: toAppFailure(error),
            onRetry: () => ref.invalidate(cpRequestsProvider(_direction)),
            compact: true,
          ),
        ],
      ),
      _ => ListView(
        children: [
          ...rows,
          const Padding(
            padding: EdgeInsets.all(KSpacing.xl),
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      ),
    };
    return Scaffold(
      backgroundColor: p.background,
      appBar: KAppBar(
        backgroundColor: p.background,
        centerTitle: true,
        title: Text(l10n.cpTitle),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          refreshCp(ref);
          await ref.read(myCpProvider.future);
        },
        child: list,
      ),
    );
  }
}

/// The couple: both pictures with a heart, the partner, days, tier and
/// progress, gifts and End.
class _Couple extends ConsumerStatefulWidget {
  const new({required this.cp});

  final CpCouple cp;

  @override
  ConsumerState<_Couple> createState() => _CoupleState();
}

class _CoupleState extends ConsumerState<_Couple> {
  /// The gift being sent and its `clientId` (kept for a retry).
  int? _sending;
  final Map<int, String> _clientIds = {};

  CpCouple get cp => widget.cp;

  Future<void> _gift(int amount) async {
    final l10n = context.l10n;
    final ok = await confirmBond(
      context,
      title: l10n.cpGiftConfirmTitle(l10n.bondsCoins(amount)),
      body: l10n.cpGiftBody,
      confirm: l10n.cpGiftTitle,
    );
    if (!ok || !mounted) return;
    setState(() => _sending = amount);
    final clientId = _clientIds.putIfAbsent(amount, newClientId);
    try {
      final result = await ref
          .read(cpRepositoryProvider)
          .sendGift(amount: amount, clientId: clientId);
      _clientIds.remove(amount);
      if (!mounted) return;
      showCoins(ref, result.coins);
      refreshCp(ref);
      KSnack.success(
        context,
        l10n.cpGiftSent(formatBondPoints(result.gift.amount)),
      );
    } on Object catch (e) {
      if (!mounted) return;
      final failure = toAppFailure(e);
      // Only a lost answer is retried with the same id; a refusal starts a
      // new attempt next time.
      if (failure is ServerFailure) _clientIds.remove(amount);
      if (failure.code == ErrorCode.insufficientCoins) {
        reloadCoins(ref);
        KSnack.error(context, l10n.cpGiftNotEnough);
      } else {
        if (failure.code == ErrorCode.cpNotPaired) refreshCp(ref);
        KSnack.error(context, failureMessage(l10n, failure));
      }
    } finally {
      if (mounted) setState(() => _sending = null);
    }
  }

  Future<void> _end(String name) async {
    final l10n = context.l10n;
    final ok = await confirmBond(
      context,
      title: l10n.cpEndTitle(name),
      body: l10n.cpEndBody,
      confirm: l10n.cpEnd,
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await ref.read(cpRepositoryProvider).end();
      if (!mounted) return;
      refreshCp(ref);
      KSnack.success(context, l10n.cpEnded);
    } on Object catch (e) {
      if (mounted) {
        KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final me = ref.watch(currentUserProvider);
    final config = ref.watch(cpConfigProvider).value;
    final coins = ref.watch(liveCoinsProvider).value;
    final partner = cp.partner;
    final name = partner.displayName.isEmpty
        ? partner.username
        : partner.displayName;
    final locale = Localizations.localeOf(context).toLanguageTag();
    // Progress inside the current tier, from the ladder when known.
    final tiers = config?.tiers ?? const <CpTier>[];
    final current = tiers.where((x) => x.level == cp.level).firstOrNull;
    final toNext = cp.pointsToNext;
    final progress = current == null || toNext == null
        ? null
        : (cp.points - current.minPoints) /
              (cp.points - current.minPoints + toNext)
                  .clamp(1, 1 << 52)
                  .toDouble();
    const rose = Color(0xFFD03468);
    return Padding(
      key: CpScreen.coupleKey,
      padding: const EdgeInsets.all(KSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              KAvatar(
                name: me?.displayName ?? '',
                imageUrl: me?.avatarUrl,
                size: 64,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: KSpacing.sm),
                child: Image.asset(
                  'assets/leaderboard/heart.webp',
                  width: 40,
                  height: 40,
                  excludeFromSemantics: true,
                ),
              ),
              GestureDetector(
                onTap: () =>
                    context.push(AppRoutes.userProfile(partner.username)),
                child: KAvatar(
                  name: name,
                  imageUrl: partner.avatarUrl,
                  size: 64,
                ),
              ),
            ],
          ),
          const SizedBox(height: KSpacing.sm),
          Text(
            name,
            textAlign: TextAlign.center,
            style: t.title.copyWith(color: p.textPrimary),
          ),
          Text(
            '${l10n.cpDay(cp.days)} · '
            '${l10n.cpSince(KFormat.date(cp.since, locale))}',
            textAlign: TextAlign.center,
            style: t.caption.copyWith(color: p.textSecondary),
          ),
          const SizedBox(height: KSpacing.md),
          Text(
            cp.levelName,
            textAlign: TextAlign.center,
            style: t.bodyStrong.copyWith(color: rose),
          ),
          const SizedBox(height: KSpacing.xs),
          if (progress != null) ...[
            BondProgress(value: progress, color: rose),
            const SizedBox(height: KSpacing.xs),
          ],
          Text(
            [
              l10n.cpPoints(formatBondPoints(cp.points)),
              switch ((toNext, cp.nextLevelName)) {
                (final int left, final String next) => l10n.cpToNext(
                  formatBondPoints(left),
                  next,
                ),
                _ => l10n.cpTopTier,
              },
            ].join(' · '),
            textAlign: TextAlign.center,
            style: t.caption.copyWith(color: p.textSecondary),
          ),
          const SizedBox(height: KSpacing.lg),
          Text(
            l10n.cpGiftTitle,
            style: t.bodyStrong.copyWith(color: p.textPrimary),
          ),
          Text(
            l10n.cpGiftBody,
            style: t.caption.copyWith(color: p.textSecondary),
          ),
          if (coins != null)
            Text(
              l10n.bondsBalance(l10n.bondsCoins(coins)),
              style: t.caption.copyWith(color: p.textSecondary),
            ),
          const SizedBox(height: KSpacing.sm),
          if (config != null)
            Wrap(
              spacing: KSpacing.sm,
              runSpacing: KSpacing.sm,
              children: [
                for (final amount in config.giftAmounts)
                  ActionChip(
                    key: CpScreen.giftKey(amount),
                    avatar: _sending == amount
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Image.asset(
                            'assets/currency/kabso_coin.png',
                            width: 18,
                            height: 18,
                            excludeFromSemantics: true,
                          ),
                    label: Text(KFormat.grouped(amount)),
                    tooltip: l10n.bondsCoins(amount),
                    onPressed: _sending != null
                        ? null
                        : () => unawaited(_gift(amount)),
                  ),
              ],
            ),
          const SizedBox(height: KSpacing.lg),
          // CP-021: the couple's CP space (tasks, privileges, confessions).
          KButton(
            key: CpScreen.spaceKey,
            label: l10n.cpSpaceOpen,
            onPressed: () => unawaited(context.push(AppRoutes.cpSpace)),
          ),
          const SizedBox(height: KSpacing.sm),
          KButton(
            key: CpScreen.endKey,
            label: l10n.cpEnd,
            variant: KButtonVariant.secondary,
            onPressed: () => unawaited(_end(name)),
          ),
        ],
      ),
    );
  }
}

class _RequestTile extends ConsumerStatefulWidget {
  const new({required this.request, required this.direction});

  final CpRequest request;
  final CpDirection direction;

  @override
  ConsumerState<_RequestTile> createState() => _RequestTileState();
}

class _RequestTileState extends ConsumerState<_RequestTile> {
  bool _busy = false;

  Future<void> _do(Future<String> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    final l10n = context.l10n;
    try {
      final message = await action();
      if (!mounted) return;
      refreshCp(ref);
      KSnack.success(context, message);
    } on Object catch (e) {
      if (!mounted) return;
      if (isErrorCode(e, ErrorCode.cpRequestNotPending)) {
        ref
            .read(cpRequestsProvider(widget.direction).notifier)
            .remove(widget.request.id);
      }
      KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _name(UserSummary u) =>
      u.displayName.isEmpty ? u.username : u.displayName;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final r = widget.request;
    final incoming = widget.direction == CpDirection.incoming;
    final other = incoming ? r.sender : r.receiver;
    final name = _name(other);
    final repo = ref.read(cpRepositoryProvider);
    final locale = Localizations.localeOf(context).toLanguageTag();
    return ListTile(
      leading: KAvatar(name: name, imageUrl: other.avatarUrl, size: 40),
      title: Text(
        incoming ? l10n.cpRequestFrom(name) : l10n.cpRequestTo(name),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        l10n.cpExpires(KFormat.date(r.expiresAt, locale)),
        style: context.textStyles.caption.copyWith(color: p.textSecondary),
      ),
      onTap: () => context.push(AppRoutes.userProfile(other.username)),
      trailing: _busy
          ? const SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : incoming
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  key: CpScreen.declineKey(r.id),
                  tooltip: l10n.cpDecline,
                  icon: Icon(Icons.close_rounded, color: p.textSecondary),
                  onPressed: () => unawaited(
                    _do(() async {
                      await repo.declineRequest(r.id);
                      return l10n.cpDeclined;
                    }),
                  ),
                ),
                IconButton(
                  key: CpScreen.acceptKey(r.id),
                  tooltip: l10n.cpAccept,
                  icon: const Icon(
                    Icons.favorite_rounded,
                    color: Color(0xFFD03468),
                  ),
                  onPressed: () => unawaited(
                    _do(() async {
                      await repo.acceptRequest(r.id);
                      return l10n.cpAccepted(name);
                    }),
                  ),
                ),
              ],
            )
          : TextButton(
              key: CpScreen.cancelKey(r.id),
              onPressed: () => unawaited(
                _do(() async {
                  await repo.cancelRequest(r.id);
                  reloadCoins(ref);
                  return l10n.cpCancelled;
                }),
              ),
              child: Text(l10n.cpCancel),
            ),
    );
  }
}
