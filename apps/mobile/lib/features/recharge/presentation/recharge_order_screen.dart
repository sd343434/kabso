import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/icons/kabso_art.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/messages/widgets/chat_composer.dart';
import 'package:kabso_live/features/posts/data/media_repository.dart';
import 'package:kabso_live/features/profile/data/profile_edit_repository.dart';
import 'package:kabso_live/features/recharge/application/recharge_orders_providers.dart';
import 'package:kabso_live/features/recharge/application/recharge_providers.dart';
import 'package:kabso_live/features/recharge/data/recharge_orders_repository.dart';
import 'package:kabso_live/features/recharge/data/recharge_repository.dart';
import 'package:kabso_live/features/recharge/presentation/recharge_apply_screen.dart'
    show rechargePaymentTypeName;
import 'package:kabso_live/features/recharge/presentation/recharge_widgets.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// The status line of an order in the app language.
String rechargeOrderStatusText(AppLocalizations l10n, RechargeOrderStatus s) =>
    switch (s) {
      RechargeOrderStatus.requested => l10n.rechargeOrderStatusRequested,
      RechargeOrderStatus.awaitingPayment => l10n.rechargeOrderStatusAwaiting,
      RechargeOrderStatus.paid => l10n.rechargeOrderStatusPaid,
      RechargeOrderStatus.disputed => l10n.rechargeOrderStatusDisputed,
      RechargeOrderStatus.completed => l10n.rechargeOrderStatusCompleted,
      RechargeOrderStatus.completedByAdmin => l10n.rechargeOrderStatusByAdmin,
      RechargeOrderStatus.refundedToAgent => l10n.rechargeOrderStatusRefunded,
      RechargeOrderStatus.cancelled => l10n.rechargeOrderStatusCancelled,
      RechargeOrderStatus.expired => l10n.rechargeOrderStatusExpired,
      RechargeOrderStatus.unknown => l10n.rechargeOrderStatusUnknown,
    };

/// The status colour: waiting (warning), done (success), ended (muted),
/// disputed (error).
Color rechargeOrderStatusColor(KPalette p, RechargeOrderStatus s) =>
    switch (s) {
      RechargeOrderStatus.requested ||
      RechargeOrderStatus.awaitingPayment ||
      RechargeOrderStatus.paid => p.warning,
      RechargeOrderStatus.disputed => p.error,
      RechargeOrderStatus.completed ||
      RechargeOrderStatus.completedByAdmin => p.success,
      _ => p.textSecondary,
    };

/// `$12.50 · ≈ 631.25 EGP` — USD always, the local amount when there is one.
/// v1.87-social (D287, §10.100): who of the agent's side handles the order,
/// for the agent's side (never the buyer): «تم استلامه بواسطة موظف آخر»,
/// off shift / not allowed (read only), «أنت تتولى هذا الطلب», «يتولاه …».
/// Null when nobody took it and the viewer may act.
({String text, bool blocked})? rechargeOrderClaimText(
  AppLocalizations l10n,
  RechargeOrder o,
  String? meId,
) {
  if (o.isBuyer) return null;
  final by = o.claimedBy;
  final block = o.viewerBlock;
  if (block == null) {
    if (by == null) return null;
    return by.id == meId
        ? (text: l10n.rechargeOrderClaimedByYou, blocked: false)
        : (
            text: l10n.rechargeOrderClaimedBy(
              KFormat.bidiIsolate(by.displayName),
            ),
            blocked: false,
          );
  }
  return (
    text: switch (block) {
      RechargeAgentSideBlock.claimed =>
        by != null && by.id == o.agent.id
            ? l10n.rechargeOrderClaimedByAgent
            : l10n.rechargeOrderClaimedByOther,
      RechargeAgentSideBlock.offShift => l10n.rechargeBlockOffShift,
      RechargeAgentSideBlock.notPermitted => l10n.rechargeBlockNotPermitted,
      RechargeAgentSideBlock.staff => l10n.rechargeBlockStaff,
    },
    blocked: true,
  );
}

String rechargePriceText(AppLocalizations l10n, RechargePrice price) {
  final usd = l10n.rechargeOrderUsd(KFormat.bidiIsolate(price.usd));
  final local = price.local;
  if (local == null) return usd;
  final converted = l10n.rechargeOrderLocal(
    KFormat.bidiIsolate(local.amount),
    local.currency,
    KFormat.bidiIsolate(local.rate),
  );
  return '$usd · $converted';
}

/// A chat system line in the app language.
String rechargeOrderEventText(AppLocalizations l10n, String? event) =>
    switch (event) {
      'CREATED' => l10n.rechargeOrderEventCreated,
      'DETAILS_SENT' => l10n.rechargeOrderEventDetails,
      'NOTICE_ACKNOWLEDGED' => l10n.rechargeOrderEventNotice,
      'PAID' => l10n.rechargeOrderEventPaid,
      'COMPLETED' => l10n.rechargeOrderEventCompleted,
      'DISPUTED_BY_BUYER' => l10n.rechargeOrderEventDisputedBuyer,
      'DISPUTED_BY_AGENT' => l10n.rechargeOrderEventDisputedAgent,
      'CANCELLED_BY_BUYER' => l10n.rechargeOrderEventCancelledBuyer,
      'CANCELLED_BY_AGENT' => l10n.rechargeOrderEventCancelledAgent,
      'EXPIRED' => l10n.rechargeOrderEventExpired,
      'RESOLVED_FOR_BUYER' => l10n.rechargeOrderEventForBuyer,
      'RESOLVED_FOR_AGENT' => l10n.rechargeOrderEventForAgent,
      _ => l10n.rechargeOrderEventOther,
    };

/// `/recharge/orders/:id` «طلب شحن» (D204, CONVENTIONS §10.64): the order
/// (coins, the server's price, the frozen coins), its own chat (kept as
/// evidence) and what the caller may do now — the agent sends the payment
/// details (the coins are frozen), the buyer acknowledges the protection
/// notice and presses «قمت بالإرسال» with the transfer's screenshot, both
/// see the 15-minute wait, the agent confirms «استلمت» or either side opens
/// «نزاع». The server decides every step again; the page follows it (it
/// reads the order and the chat again every few seconds while open).
class RechargeOrderScreen extends ConsumerStatefulWidget {
  const new({required this.orderId, super.key});

  final String orderId;

  static const noticeKey = Key('recharge.order.notice');
  static const ackKey = Key('recharge.order.ack');
  static const sentKey = Key('recharge.order.sent');
  static const receivedKey = Key('recharge.order.received');
  static const disputeKey = Key('recharge.order.dispute');
  static const cancelKey = Key('recharge.order.cancel');
  static const detailsKey = Key('recharge.order.details');
  static const countdownKey = Key('recharge.order.countdown');
  static const frozenKey = Key('recharge.order.frozen');
  static const chatKey = Key('recharge.order.chat');
  static const closedKey = Key('recharge.order.closed');
  static const sendKey = Key('recharge.order.send');
  static const claimKey = Key('recharge.order.claim');

  /// How often an open order is read again.
  static const refreshEvery = Duration(seconds: 6);

  @override
  ConsumerState<RechargeOrderScreen> createState() =>
      _RechargeOrderScreenState();
}

class _RechargeOrderScreenState extends ConsumerState<RechargeOrderScreen> {
  final _text = TextEditingController();
  Timer? _tick;
  Duration _since = Duration.zero;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    // One tick a second: the countdown; the order and the chat are read
    // again every [refreshEvery] while the order is open.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _since += const Duration(seconds: 1);
      final open =
          ref
              .read(rechargeOrderProvider(widget.orderId))
              .value
              ?.status
              .isOpen ??
          false;
      if (open && _since >= RechargeOrderScreen.refreshEvery) {
        _since = Duration.zero;
        _refresh();
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _text.dispose();
    super.dispose();
  }

  void _refresh() {
    ref
      ..invalidate(rechargeOrderProvider(widget.orderId))
      ..invalidate(rechargeOrderMessagesProvider(widget.orderId));
  }

  RechargeOrdersRepository get _repo =>
      ref.read(rechargeOrdersRepositoryProvider);

  /// Runs [step]; a refusal is said in a snack; the page reads the order again.
  Future<bool> _run(Future<void> Function() step) async {
    if (_busy) return false;
    setState(() => _busy = true);
    final l10n = context.l10n;
    try {
      await step();
      return true;
    } on Object catch (e) {
      if (mounted) KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
      return false;
    } finally {
      _refresh();
      ref
        ..invalidate(myRechargeAgentProvider)
        ..invalidate(rechargeOrdersProvider(false))
        ..invalidate(rechargeOrdersProvider(true));
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    final text = _text.text.trim();
    if (text.isEmpty) return;
    if (await _run(() => _repo.sendText(widget.orderId, text))) _text.clear();
  }

  Future<void> _sendPicture(Uint8List bytes) async {
    if (sniffImageType(bytes) == null) {
      KSnack.error(context, context.l10n.rechargeOrderBadImage);
      return;
    }
    await _run(() => _repo.sendImage(widget.orderId, bytes));
  }

  Future<void> _details(RechargeOrder o) async {
    final details = await showRechargeOrderDetailsSheet(context, o);
    if (details == null || !mounted) return;
    await _run(() => _repo.sendDetails(widget.orderId, o.paymentType, details));
  }

  Future<void> _markPaid() async {
    final l10n = context.l10n;
    final bytes = await showModalBottomSheet<Uint8List>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _ProofSheet(),
    );
    if (bytes == null || !mounted) return;
    if (sniffImageType(bytes) == null) {
      KSnack.error(context, l10n.rechargeOrderBadImage);
      return;
    }
    await _run(() => _repo.markPaid(widget.orderId, bytes));
  }

  Future<void> _confirm(RechargeOrder o) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.rechargeOrderReceivedTitle),
        content: Text(
          l10n.rechargeOrderReceivedBody(
            KFormat.bidiIsolate(KFormat.grouped(o.coins)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.rechargeOrderKeep),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.rechargeOrderReceived),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _run(() => _repo.confirm(widget.orderId));
  }

  Future<void> _dispute() async {
    // Null: dismissed; empty: no reason given.
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _DisputeDialog(),
    );
    if (reason == null || !mounted) return;
    await _run(
      () =>
          _repo.dispute(widget.orderId, reason: reason.isEmpty ? null : reason),
    );
  }

  Future<void> _cancel() async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.rechargeOrderCancel),
        content: Text(l10n.rechargeOrderCancelBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.rechargeOrderKeep),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.rechargeOrderCancel),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _run(() => _repo.cancel(widget.orderId));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final load = ref.watch(rechargeOrderProvider(widget.orderId));
    final order = load.value;
    return Scaffold(
      backgroundColor: p.background,
      appBar: KAppBar(
        backgroundColor: p.background,
        centerTitle: true,
        title: Text(l10n.rechargeOrderTitle),
      ),
      body: switch ((order, load.error)) {
        (final o?, _) => _body(context, o),
        (null, final error?) when !load.isLoading => FailureErrorState(
          title: l10n.errorTitle,
          failure: toAppFailure(error),
          onRetry: _refresh,
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Widget _body(BuildContext context, RechargeOrder o) {
    final l10n = context.l10n;
    final p = context.palette;
    final messages =
        ref.watch(rechargeOrderMessagesProvider(widget.orderId)).value ??
        const <RechargeOrderMessage>[];
    final now = clock.now();
    final canWrite = o.can(RechargeOrderAction.message);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            KSpacing.lg,
            KSpacing.xs,
            KSpacing.lg,
            0,
          ),
          child: _OrderSummary(order: o),
        ),
        if (rechargeOrderClaimText(l10n, o, ref.watch(currentUserProvider)?.id)
            case final claim?)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              KSpacing.lg,
              KSpacing.sm,
              KSpacing.lg,
              0,
            ),
            child: RechargeNotice(
              key: RechargeOrderScreen.claimKey,
              icon: claim.blocked
                  ? Icons.lock_outline_rounded
                  : Icons.badge_rounded,
              text: claim.text,
              warning: claim.blocked,
            ),
          ),
        if (_banner(context, o, now) case final banner?)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              KSpacing.lg,
              KSpacing.sm,
              KSpacing.lg,
              0,
            ),
            child: banner,
          ),
        Expanded(
          child: ListView.builder(
            key: RechargeOrderScreen.chatKey,
            reverse: true,
            padding: const EdgeInsets.symmetric(
              horizontal: KSpacing.lg,
              vertical: KSpacing.sm,
            ),
            itemCount: messages.length,
            itemBuilder: (_, i) =>
                _Line(order: o, message: messages[messages.length - 1 - i]),
          ),
        ),
        ?_actions(context, o, now),
        if (canWrite)
          SafeArea(
            top: false,
            child: ChatComposer(
              controller: _text,
              sendKey: RechargeOrderScreen.sendKey,
              hintText: l10n.rechargeOrderChatHint,
              showGift: false,
              allowVideo: false,
              onSend: _busy ? null : () => unawaited(_send()),
              onMedia: (m) async {
                if (m.isVideo) return;
                final bytes = await XFile(m.path).readAsBytes();
                if (mounted) await _sendPicture(bytes);
              },
            ),
          )
        else
          SafeArea(
            top: false,
            child: Container(
              key: RechargeOrderScreen.closedKey,
              width: double.infinity,
              padding: const EdgeInsets.all(KSpacing.md),
              color: p.surface,
              child: Text(
                l10n.rechargeOrderChatClosed,
                textAlign: TextAlign.center,
                style: context.textStyles.caption.copyWith(
                  color: p.textSecondary,
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// The protection notice (the buyer, before «قمت بالإرسال») or the wait.
  Widget? _banner(BuildContext context, RechargeOrder o, DateTime now) {
    final l10n = context.l10n;
    if (o.status == RechargeOrderStatus.awaitingPayment &&
        o.isBuyer &&
        !o.noticeAcknowledged) {
      return _NoticeCard(
        onAck: _busy
            ? null
            : () => unawaited(
                _run(() => _repo.acknowledgeNotice(widget.orderId)),
              ),
      );
    }
    if (o.status == RechargeOrderStatus.paid && o.disputeOpensAt != null) {
      final left = o.disputeOpensAt!.difference(now);
      final over = left <= Duration.zero;
      final time = KFormat.bidiIsolate(KFormat.countdown(left));
      return _CountdownBar(
        key: RechargeOrderScreen.countdownKey,
        over: over,
        progress: over
            ? 1
            : 1 -
                  left.inSeconds /
                      o.disputeOpensAt!
                          .difference(o.paidAt ?? now)
                          .inSeconds
                          .clamp(1, 1 << 30),
        text: switch ((o.isBuyer, over)) {
          (true, false) => l10n.rechargeOrderCountdown(time),
          (true, true) => l10n.rechargeOrderWaitOver,
          (false, false) => l10n.rechargeOrderCountdownAgent(time),
          (false, true) => l10n.rechargeOrderWaitOverAgent,
        },
      );
    }
    return null;
  }

  /// The buttons of the caller's side now.
  Widget? _actions(BuildContext context, RechargeOrder o, DateTime now) {
    final l10n = context.l10n;
    final buttons = <Widget>[];
    final pill = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(KRadius.pill),
    );
    final busy = _busy;
    if (o.can(RechargeOrderAction.sendDetails)) {
      buttons.add(
        Expanded(
          child: FilledButton.icon(
            key: RechargeOrderScreen.detailsKey,
            style: FilledButton.styleFrom(shape: pill),
            onPressed: busy ? null : () => unawaited(_details(o)),
            icon: const Icon(Icons.payments_outlined, size: 18),
            label: Text(l10n.rechargeOrderSendDetails),
          ),
        ),
      );
    }
    if (o.can(RechargeOrderAction.confirm)) {
      buttons.add(
        Expanded(
          child: FilledButton.icon(
            key: RechargeOrderScreen.receivedKey,
            style: FilledButton.styleFrom(
              shape: pill,
              backgroundColor: context.palette.success,
              foregroundColor: context.palette.onPrimary,
            ),
            onPressed: busy ? null : () => unawaited(_confirm(o)),
            icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
            label: Text(l10n.rechargeOrderReceived),
          ),
        ),
      );
    }
    if (o.can(RechargeOrderAction.markPaid)) {
      buttons.add(
        // Owner: «زر صغير».
        FilledButton.icon(
          key: RechargeOrderScreen.sentKey,
          style: FilledButton.styleFrom(
            shape: pill,
            minimumSize: const Size(0, KSizes.minTouchTarget - 4),
            padding: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
          ),
          onPressed: busy ? null : () => unawaited(_markPaid()),
          icon: const Icon(Icons.send_rounded, size: 16),
          label: Text(l10n.rechargeOrderSent),
        ),
      );
    }
    // The buyer's «نزاع» is shown during the wait, enabled when it is over.
    final buyerWaiting =
        o.isBuyer &&
        o.status == RechargeOrderStatus.paid &&
        !o.can(RechargeOrderAction.dispute);
    if (o.can(RechargeOrderAction.dispute) || buyerWaiting) {
      buttons.add(
        Expanded(
          child: OutlinedButton.icon(
            key: RechargeOrderScreen.disputeKey,
            style: OutlinedButton.styleFrom(
              shape: pill,
              foregroundColor: context.palette.error,
              side: BorderSide(color: context.palette.error),
            ),
            onPressed: busy || buyerWaiting
                ? null
                : () => unawaited(_dispute()),
            icon: const Icon(Icons.gavel_rounded, size: 18),
            label: Text(l10n.rechargeOrderDispute),
          ),
        ),
      );
    }
    if (o.can(RechargeOrderAction.cancel)) {
      buttons.add(
        TextButton(
          key: RechargeOrderScreen.cancelKey,
          onPressed: busy ? null : () => unawaited(_cancel()),
          child: Text(l10n.rechargeOrderCancel),
        ),
      );
    }
    if (buttons.isEmpty) return null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        KSpacing.lg,
        KSpacing.xs,
        KSpacing.lg,
        KSpacing.xs,
      ),
      child: Row(
        children: [
          for (final (i, b) in buttons.indexed) ...[
            if (i > 0) const SizedBox(width: KSpacing.sm),
            b,
          ],
        ],
      ),
    );
  }
}

/// The order at a glance: the other side, the coins, the price (USD and
/// the local amount), the payment method, the status and the frozen coins.
class _OrderSummary extends StatelessWidget {
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
    return Container(
      padding: const EdgeInsets.all(KSpacing.md),
      decoration: BoxDecoration(
        color: p.surfaceRaised,
        borderRadius: BorderRadius.circular(KRadius.lg),
        border: Border.all(color: p.border),
      ),
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
                      o.isBuyer
                          ? l10n.rechargeIdLine(
                              KFormat.bidiIsolate(o.agentCode),
                            )
                          : KFormat.bidiIsolate('@${other.username}'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.caption.copyWith(color: p.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: KSpacing.sm),
              const KabsoArtIcon(KabsoArt.coin, size: 18),
              const SizedBox(width: KSpacing.xxs),
              Text(
                KFormat.grouped(o.coins),
                style: t.title.copyWith(
                  color: p.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: KSpacing.xs),
          // USD always; the local amount at the admin's rate when there is one.
          Text(
            rechargePriceText(l10n, o.price),
            style: t.caption.copyWith(
              color: p.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: KSpacing.sm),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  rechargeOrderStatusText(l10n, o.status),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: t.caption.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              RechargePill(label: rechargePaymentTypeName(l10n, o.paymentType)),
            ],
          ),
          if (o.heldCoins > 0) ...[
            const SizedBox(height: KSpacing.xs),
            Row(
              key: RechargeOrderScreen.frozenKey,
              children: [
                Icon(Icons.lock_clock_outlined, size: 16, color: p.info),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    l10n.rechargeOrderFrozen(
                      KFormat.bidiIsolate(KFormat.grouped(o.heldCoins)),
                    ),
                    style: t.caption.copyWith(color: p.info),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// The owner's protection notice: a prominent card that must be
/// acknowledged before «قمت بالإرسال» is enabled.
class _NoticeCard extends StatelessWidget {
  const new({required this.onAck});

  final VoidCallback? onAck;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    return Container(
      key: RechargeOrderScreen.noticeKey,
      padding: const EdgeInsets.all(KSpacing.md),
      decoration: BoxDecoration(
        color: Color.alphaBlend(p.warning.withValues(alpha: 0.12), p.surface),
        borderRadius: BorderRadius.circular(KRadius.lg),
        border: Border.all(color: p.warning, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.shield_outlined, color: p.warning, size: 22),
              const SizedBox(width: KSpacing.sm),
              Expanded(
                child: Text(
                  l10n.rechargeOrderNoticeTitle,
                  style: t.bodyStrong.copyWith(color: p.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: KSpacing.xs),
          Text(
            l10n.rechargeOrderNotice,
            style: t.body.copyWith(color: p.textPrimary, height: 1.5),
          ),
          const SizedBox(height: KSpacing.sm),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton(
              key: RechargeOrderScreen.ackKey,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(KRadius.pill),
                ),
              ),
              onPressed: onAck,
              child: Text(l10n.rechargeOrderNoticeAck),
            ),
          ),
        ],
      ),
    );
  }
}

/// The 15-minute wait after «قمت بالإرسال», seen by both sides.
class _CountdownBar extends StatelessWidget {
  const new({
    required this.over,
    required this.progress,
    required this.text,
    super.key,
  });

  final bool over;
  final double progress;
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.textStyles;
    final color = over ? p.error : p.info;
    return Container(
      padding: const EdgeInsets.all(KSpacing.sm),
      decoration: BoxDecoration(
        color: Color.alphaBlend(color.withValues(alpha: 0.10), p.surface),
        borderRadius: BorderRadius.circular(KRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                over ? Icons.timer_off_outlined : Icons.timer_outlined,
                color: color,
                size: 20,
              ),
              const SizedBox(width: KSpacing.sm),
              Expanded(
                child: Text(
                  text,
                  style: t.caption.copyWith(
                    color: p.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: KSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(KRadius.pill),
            child: LinearProgressIndicator(
              value: progress.clamp(0, 1),
              minHeight: 4,
              color: color,
              backgroundColor: p.border,
            ),
          ),
        ],
      ),
    );
  }
}

/// One line of the chat: a system line, «الإدارة», the payment details, a
/// picture (the transfer's screenshot) or text — the caller's on the end
/// side.
class _Line extends ConsumerWidget {
  const new({required this.order, required this.message});

  final RechargeOrder order;
  final RechargeOrderMessage message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final m = message;
    if (m.isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: KSpacing.xs),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: KSpacing.sm,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(KRadius.pill),
            ),
            child: Text(
              m.text == null
                  ? rechargeOrderEventText(l10n, m.event)
                  : '${rechargeOrderEventText(l10n, m.event)} — ${m.text}',
              textAlign: TextAlign.center,
              style: t.caption.copyWith(color: p.textSecondary),
            ),
          ),
        ),
      );
    }
    final admin = m.role == 'ADMIN';
    final mine = order.isBuyer
        ? m.role == 'BUYER'
        : m.role != 'BUYER' && !admin;
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.78,
      ),
      padding: const EdgeInsets.all(KSpacing.sm),
      decoration: BoxDecoration(
        color: admin
            ? p.surfaceRaised
            : mine
            ? Color.alphaBlend(p.primary.withValues(alpha: 0.12), p.surface)
            : p.surfaceRaised,
        borderRadius: BorderRadius.circular(KRadius.lg),
        border: Border.all(
          color: admin || m.kind == 'PAYMENT_DETAILS' ? p.primary : p.border,
          width: admin || m.kind == 'PAYMENT_DETAILS' ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (admin)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_user_rounded, size: 14, color: p.primary),
                const SizedBox(width: 4),
                Text(
                  l10n.rechargeOrderRoleAdmin,
                  style: t.caption.copyWith(
                    color: p.primaryText,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          if (m.kind == 'PAYMENT_DETAILS') ...[
            Text(
              l10n.rechargeOrderPaymentDetails(
                rechargePaymentTypeName(
                  l10n,
                  m.method ?? RechargePaymentType.other,
                ),
              ),
              style: t.caption.copyWith(
                color: p.primaryText,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
          ],
          if (m.kind == 'TRANSFER_PROOF')
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                l10n.rechargeOrderProof,
                style: t.caption.copyWith(
                  color: p.primaryText,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          if (m.hasImage) _PrivatePicture(order: order.id, message: m.id),
          if (m.text case final text?)
            SelectableText(text, style: t.body.copyWith(color: p.textPrimary)),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                KFormat.time(m.createdAt, localeTag),
                style: t.caption.copyWith(color: p.textTertiary, fontSize: 11),
              ),
              if (m.kind == 'PAYMENT_DETAILS' && m.text != null) ...[
                const SizedBox(width: KSpacing.sm),
                InkWell(
                  onTap: () {
                    unawaited(Clipboard.setData(ClipboardData(text: m.text!)));
                    KSnack.success(context, l10n.rechargeOrderCopied);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      Icons.copy_rounded,
                      size: 16,
                      color: p.textSecondary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: KSpacing.xxs + 1),
      child: Align(
        alignment: admin
            ? Alignment.center
            : mine
            ? AlignmentDirectional.centerEnd
            : AlignmentDirectional.centerStart,
        child: bubble,
      ),
    );
  }
}

/// A private picture of the chat: its bytes through the API (never a URL).
class _PrivatePicture extends ConsumerWidget {
  const new({required this.order, required this.message});

  final String order;
  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final bytes = ref.watch(
      rechargeOrderImageProvider((order: order, message: message)),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(KRadius.md),
        child: SizedBox(
          width: 180,
          height: 220,
          child: switch (bytes) {
            AsyncValue(value: final b?) => Image.memory(
              b,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => ColoredBox(
                color: p.surface,
                child: Icon(Icons.broken_image_outlined, color: p.textTertiary),
              ),
            ),
            AsyncValue(error: _?) => ColoredBox(
              color: p.surface,
              child: Icon(Icons.broken_image_outlined, color: p.textTertiary),
            ),
            _ => ColoredBox(
              color: p.surface,
              child: const Center(
                child: SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          },
        ),
      ),
    );
  }
}

/// «إرسال معلومات الدفع»: the agent's transfer details (the coins are frozen
/// when sent). Returns the details, or null when dismissed.
Future<String?> showRechargeOrderDetailsSheet(
  BuildContext context,
  RechargeOrder order,
) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _DetailsSheet(order: order),
);

class _DetailsSheet extends StatefulWidget {
  const new({required this.order});

  final RechargeOrder order;

  @override
  State<_DetailsSheet> createState() => _DetailsSheetState();
}

class _DetailsSheetState extends State<_DetailsSheet> {
  final _details = TextEditingController();

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final o = widget.order;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        KSpacing.lg,
        0,
        KSpacing.lg,
        KSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.rechargeOrderSendDetails, style: t.title),
          const SizedBox(height: KSpacing.sm),
          Row(
            children: [
              RechargePill(label: rechargePaymentTypeName(l10n, o.paymentType)),
              const Spacer(),
              Text(
                rechargePriceText(l10n, o.price),
                style: t.caption.copyWith(color: p.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: KSpacing.md),
          TextField(
            controller: _details,
            autofocus: true,
            minLines: 2,
            maxLines: 5,
            maxLength: 500,
            decoration: InputDecoration(
              labelText: l10n.rechargeOrderDetailsLabel,
              hintText: l10n.rechargeOrderDetailsHint,
            ),
            onChanged: (_) => setState(() {}),
          ),
          RechargeNotice(
            icon: Icons.lock_clock_outlined,
            text: l10n.rechargeOrderDetailsBody(
              KFormat.bidiIsolate(KFormat.grouped(o.coins)),
            ),
          ),
          const SizedBox(height: KSpacing.md),
          FilledButton(
            onPressed: _details.text.trim().isEmpty
                ? null
                : () => Navigator.pop(context, _details.text.trim()),
            child: Text(l10n.rechargeOrderSendDetails),
          ),
        ],
      ),
    );
  }
}

/// «قمت بالإرسال»: choose the transfer's screenshot, see it, send it.
class _ProofSheet extends ConsumerStatefulWidget {
  const new();

  @override
  ConsumerState<_ProofSheet> createState() => _ProofSheetState();
}

class _ProofSheetState extends ConsumerState<_ProofSheet> {
  Uint8List? _bytes;

  Future<void> _pick() async {
    final bytes = await ref
        .read(avatarPhotoPickerProvider)
        .pick(AvatarSource.library);
    if (bytes != null && mounted) setState(() => _bytes = bytes);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final p = context.palette;
    final bytes = _bytes;
    return Padding(
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
          Text(l10n.rechargeOrderSentTitle, style: t.title),
          const SizedBox(height: KSpacing.xs),
          Text(
            l10n.rechargeOrderSentBody,
            style: t.body.copyWith(color: p.textSecondary),
          ),
          const SizedBox(height: KSpacing.md),
          if (bytes != null)
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(KRadius.md),
                child: Image.memory(bytes, height: 220, fit: BoxFit.contain),
              ),
            ),
          const SizedBox(height: KSpacing.sm),
          OutlinedButton.icon(
            onPressed: () => unawaited(_pick()),
            icon: const Icon(Icons.photo_library_outlined),
            label: Text(l10n.rechargeOrderPickScreenshot),
          ),
          const SizedBox(height: KSpacing.sm),
          FilledButton.icon(
            onPressed: bytes == null
                ? null
                : () => Navigator.pop(context, bytes),
            icon: const Icon(Icons.send_rounded, size: 18),
            label: Text(l10n.rechargeOrderSent),
          ),
        ],
      ),
    );
  }
}

/// «فتح نزاع»: what happens and an optional reason (its own controller, so it
/// outlives the closing animation). Pops the reason ('' = none) or null.
class _DisputeDialog extends StatefulWidget {
  const new();

  @override
  State<_DisputeDialog> createState() => _DisputeDialogState();
}

class _DisputeDialogState extends State<_DisputeDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.rechargeOrderDisputeTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.rechargeOrderDisputeBody),
            const SizedBox(height: KSpacing.md),
            TextField(
              controller: _reason,
              maxLength: 500,
              maxLines: 3,
              minLines: 1,
              decoration: InputDecoration(
                labelText: l10n.rechargeOrderDisputeReason,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.rechargeOrderKeep),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _reason.text.trim()),
          child: Text(l10n.rechargeOrderDispute),
        ),
      ],
    );
  }
}
