import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/posts/application/compose_controller.dart'
    show newIdempotencyKey;
import 'package:kabso_live/features/recharge/application/recharge_providers.dart';
import 'package:kabso_live/features/recharge/data/recharge_repository.dart';
import 'package:kabso_live/features/recharge/presentation/recharge_widgets.dart';
import 'package:kabso_live/features/wallet/presentation/me_page_parts.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// `/recharge/cherries` (D185, §10.48): cherry sales between hosts and
/// agents. A host offers withdrawable cherries to an agent (by code); an
/// agent asks a host (by username). The other side confirms after the cash
/// changed hands outside the app (the agent pays $1.10 per 1 000 000), or
/// declines; the creator may cancel; a request expires after 30 minutes.
/// Locked task cherries are never sold; the agent has a daily cap.
class RechargeCherryScreen extends ConsumerWidget {
  const new({super.key});

  static const newKey = Key('recharge.cherry.new');
  static const emptyKey = Key('recharge.cherry.empty');
  static Key rowKey(String id) => Key('recharge.cherry.$id');
  static Key confirmKey(String id) => Key('recharge.cherry.$id.confirm');
  static Key declineKey(String id) => Key('recharge.cherry.$id.decline');
  static Key cancelKey(String id) => Key('recharge.cherry.$id.cancel');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final me = ref.watch(myRechargeAgentProvider).value;
    final isAgent = me?.agent?.status == RechargeAgentStatus.active;
    final load = ref.watch(rechargeCherryRequestsProvider);
    return MePage(
      title: isAgent
          ? l10n.rechargeCherryBuyTitle
          : l10n.rechargeCherrySellTitle,
      onRefresh: () async {
        ref.invalidate(rechargeCherryRequestsProvider);
        try {
          await ref.read(rechargeCherryRequestsProvider.future);
        } on Object {
          // Shown with a retry.
        }
      },
      children: [
        if (me != null)
          RechargeNotice(
            icon: Icons.info_outline_rounded,
            text: [
              l10n.rechargeCherryRate(
                KFormat.grouped(me.rules.cherryUnit),
                KFormat.grouped(me.rules.coinsPerCherryUnit),
              ),
              l10n.rechargeCherryRules(
                KFormat.bidiIsolate(KFormat.grouped(me.rules.minCherries)),
                KFormat.bidiIsolate(KFormat.grouped(me.rules.stepCherries)),
              ),
              l10n.rechargeCherryLockedNote,
            ].join('\n'),
          ),
        const SizedBox(height: KSpacing.sm),
        KButton(
          key: newKey,
          label: isAgent ? l10n.rechargeCherryAsk : l10n.rechargeCherryOffer,
          icon: Icons.add_rounded,
          onPressed: me == null
              ? null
              : () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) =>
                      RechargeCherryNewSheet(rules: me.rules, asAgent: isAgent),
                ),
        ),
        const SizedBox(height: KSpacing.md),
        ...switch (load) {
          AsyncValue(value: FeedItems(:final items)) when items.isEmpty => [
            KEmptyState(
              key: emptyKey,
              icon: Icons.swap_horiz_rounded,
              title: l10n.rechargeCherryEmpty,
              message: l10n.rechargeCherryConfirmHint,
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
              for (final r in items) _RequestCard(request: r),
              if (hasMore)
                MeLoadMore(
                  failed: loadMoreError != null,
                  onLoad: ref
                      .read(rechargeCherryRequestsProvider.notifier)
                      .loadMore,
                  itemCount: items.length,
                ),
            ],
          AsyncValue(:final error?, isLoading: false) => [
            FailureErrorState(
              title: l10n.errorTitle,
              failure: toAppFailure(error),
              onRetry: () => ref.invalidate(rechargeCherryRequestsProvider),
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

class _RequestCard extends ConsumerStatefulWidget {
  const new({required this.request});

  final RechargeCherryRequest request;

  @override
  ConsumerState<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends ConsumerState<_RequestCard> {
  bool _busy = false;

  Future<void> _answer(String action) async {
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      await ref
          .read(rechargeRepositoryProvider)
          .answerCherryRequest(widget.request.id, action);
      ref
        ..invalidate(rechargeCherryRequestsProvider)
        ..invalidate(myRechargeAgentProvider);
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
    final t = context.textStyles;
    final r = widget.request;
    final me = ref.watch(currentUserProvider)?.id;
    final mine = (r.byHost ? r.host.id : r.agent.id) == me;
    final other = r.host.id == me ? r.agent : r.host;
    final pending = r.status == RechargeCherryStatus.pending;
    final money = l10n.rechargeMoney(
      KFormat.bidiIsolate(
        '${(r.payoutMinor / 100).toStringAsFixed(2)} ${r.currency}',
      ),
    );
    final status = switch (r.status) {
      RechargeCherryStatus.pending => l10n.rechargeCherryPending,
      RechargeCherryStatus.confirmed => l10n.rechargeCherryConfirmed,
      RechargeCherryStatus.declined => l10n.rechargeCherryDeclined,
      RechargeCherryStatus.cancelled => l10n.rechargeCherryCancelled,
      RechargeCherryStatus.expired => l10n.rechargeCherryExpired,
    };
    return Padding(
      key: RechargeCherryScreen.rowKey(r.id),
      padding: const EdgeInsets.only(bottom: KSpacing.sm),
      child: RechargeCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
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
                        l10n.rechargeIdLine(KFormat.bidiIsolate(r.agentCode)),
                        style: t.caption.copyWith(color: p.textSecondary),
                      ),
                    ],
                  ),
                ),
                Text(
                  status,
                  style: t.caption.copyWith(
                    color: pending ? p.primary : p.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: KSpacing.xs),
            Text(
              l10n.rechargeCherryLine(
                KFormat.bidiIsolate(KFormat.grouped(r.cherries)),
                KFormat.bidiIsolate(KFormat.grouped(r.coins)),
              ),
              style: t.body.copyWith(color: p.textPrimary),
            ),
            Text(money, style: t.caption.copyWith(color: p.textSecondary)),
            if (pending) ...[
              const SizedBox(height: KSpacing.xs),
              if (mine)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.rechargeCherryWaiting,
                        style: t.caption.copyWith(color: p.textSecondary),
                      ),
                    ),
                    TextButton(
                      key: RechargeCherryScreen.cancelKey(r.id),
                      onPressed: _busy
                          ? null
                          : () => unawaited(_answer('cancel')),
                      child: Text(l10n.rechargeCherryCancel),
                    ),
                  ],
                )
              else ...[
                Text(
                  l10n.rechargeCherryConfirmHint,
                  style: t.caption.copyWith(color: p.textSecondary),
                ),
                const SizedBox(height: KSpacing.xs),
                Row(
                  children: [
                    Expanded(
                      child: KButton(
                        key: RechargeCherryScreen.confirmKey(r.id),
                        label: l10n.rechargeConfirm,
                        loading: _busy,
                        onPressed: _busy
                            ? null
                            : () => unawaited(_answer('confirm')),
                      ),
                    ),
                    const SizedBox(width: KSpacing.sm),
                    Expanded(
                      child: KButton(
                        key: RechargeCherryScreen.declineKey(r.id),
                        label: l10n.rechargeDecline,
                        variant: KButtonVariant.secondary,
                        onPressed: _busy
                            ? null
                            : () => unawaited(_answer('decline')),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// A new request: the agent's code (a host) or the host's username (an
/// agent), and the cherries — with what the agent's stock receives and
/// what the host is paid.
class RechargeCherryNewSheet extends ConsumerStatefulWidget {
  const new({required this.rules, required this.asAgent, super.key});

  final RechargeRules rules;
  final bool asAgent;

  static const otherKey = Key('recharge.cherry.other');
  static const amountKey = Key('recharge.cherry.amount');
  static const sendKey = Key('recharge.cherry.send');

  @override
  ConsumerState<RechargeCherryNewSheet> createState() =>
      _RechargeCherryNewSheetState();
}

class _RechargeCherryNewSheetState
    extends ConsumerState<RechargeCherryNewSheet> {
  final _other = TextEditingController();
  final _amount = TextEditingController();
  final String _key = newIdempotencyKey();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _other.dispose();
    _amount.dispose();
    super.dispose();
  }

  int get _cherries => int.tryParse(_amount.text.trim()) ?? 0;

  Future<void> _send() async {
    final l10n = context.l10n;
    final r = widget.rules;
    final cherries = _cherries;
    if (cherries < r.minCherries || cherries % r.stepCherries != 0) {
      setState(
        () => _error = l10n.rechargeCherryRules(
          KFormat.bidiIsolate(KFormat.grouped(r.minCherries)),
          KFormat.bidiIsolate(KFormat.grouped(r.stepCherries)),
        ),
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(rechargeRepositoryProvider)
          .createCherryRequest(
            cherries: cherries,
            idempotencyKey: _key,
            agentCode: widget.asAgent ? null : _other.text,
            host: widget.asAgent ? _other.text : null,
          );
      if (!mounted) return;
      ref.invalidate(rechargeCherryRequestsProvider);
      Navigator.of(context).pop();
      KSnack.success(context, l10n.rechargeCherrySent);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = failureMessage(l10n, toAppFailure(e));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final r = widget.rules;
    final cherries = _cherries;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          KSpacing.lg,
          KSpacing.lg,
          KSpacing.lg,
          KSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.asAgent
                  ? l10n.rechargeCherryAsk
                  : l10n.rechargeCherryOffer,
              textAlign: TextAlign.center,
              style: t.title.copyWith(color: p.textPrimary),
            ),
            const SizedBox(height: KSpacing.md),
            KTextField(
              fieldKey: RechargeCherryNewSheet.otherKey,
              label: widget.asAgent
                  ? l10n.rechargeHostField
                  : l10n.rechargeAgentCodeField,
              controller: _other,
              textDirection: TextDirection.ltr,
            ),
            const SizedBox(height: KSpacing.sm),
            KTextField(
              fieldKey: RechargeCherryNewSheet.amountKey,
              label: l10n.rechargeCherryAmount,
              controller: _amount,
              keyboardType: TextInputType.number,
              textDirection: TextDirection.ltr,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(13),
              ],
              errorText: _error,
              onChanged: (_) => setState(() => _error = null),
            ),
            const SizedBox(height: KSpacing.sm),
            if (cherries > 0)
              RechargeNotice(
                icon: Icons.calculate_rounded,
                text: l10n.rechargeCherryPreview(
                  KFormat.bidiIsolate(KFormat.grouped(r.coinsFor(cherries))),
                  KFormat.bidiIsolate(
                    '${(r.payoutMinorFor(cherries) / 100).toStringAsFixed(2)}'
                    ' ${r.currency}',
                  ),
                ),
              ),
            const SizedBox(height: KSpacing.md),
            KButton(
              key: RechargeCherryNewSheet.sendKey,
              label: l10n.rechargeCherrySend,
              loading: _busy,
              onPressed: _busy ? null : () => unawaited(_send()),
            ),
          ],
        ),
      ),
    );
  }
}
