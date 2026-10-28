import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/models/premium_tier.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/application/live_wallet_controller.dart';
import 'package:kabso_live/features/posts/application/compose_controller.dart'
    show newIdempotencyKey;
import 'package:kabso_live/features/premium/data/premium_repository.dart';
import 'package:kabso_live/features/premium/domain/premium_models.dart';
import 'package:kabso_live/features/premium/presentation/premium_labels.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Opens the rent (or renew) sheet for [status]; the rental when it went
/// through, else null. [current] is the person's own premium username when
/// renewing it.
Future<PremiumRental?> showPremiumRentSheet(
  BuildContext context, {
  required PremiumNameStatus status,
  MyPremiumUsername? current,
}) => showModalBottomSheet<PremiumRental>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => PremiumRentSheet(status: status, current: current),
);

/// D146: the badge as it will look, the tier, the price for the period,
/// the balance, what happens at the end, and one button. The price shown is
/// the one sent (`priceCoins`): if the owner changed it meanwhile the server
/// refuses and the sheet shows the new one.
class PremiumRentSheet extends ConsumerStatefulWidget {
  const new({required this.status, super.key, this.current});

  final PremiumNameStatus status;
  final MyPremiumUsername? current;

  static const confirmKey = Key('premium.sheet.confirm');
  static const balanceKey = Key('premium.sheet.balance');
  static const shortKey = Key('premium.sheet.short');
  static const errorKey = Key('premium.sheet.error');

  @override
  ConsumerState<PremiumRentSheet> createState() => _PremiumRentSheetState();
}

class _PremiumRentSheetState extends ConsumerState<PremiumRentSheet> {
  /// One key per sheet: a retry after a lost answer is not charged twice.
  final String _key = newIdempotencyKey();
  late PremiumNameStatus _status = widget.status;
  bool _busy = false;
  String? _error;

  Future<void> _confirm() async {
    final l10n = context.l10n;
    final price = _status.priceCoins;
    if (price == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final rental = await ref
          .read(premiumRepositoryProvider)
          .rent(
            username: _status.username,
            priceCoins: price,
            idempotencyKey: _key,
          );
      ref.read(liveCoinsProvider.notifier).set(rental.coins);
      // The username changed: the session and profile show the new one.
      final user = ref.read(currentUserProvider);
      if (user != null) {
        ref
            .read(sessionControllerProvider.notifier)
            .updateUser(
              user.copyWith(
                username: rental.premium.username,
                premiumTier: rental.premium.tier,
              ),
            );
      }
      if (!mounted) return;
      KSnack.info(
        context,
        widget.current == null
            ? l10n.premiumRented(rental.premium.username)
            : l10n.premiumRenewed(rental.premium.username),
      );
      Navigator.of(context).pop(rental);
    } on Object catch (e) {
      if (!mounted) return;
      final failure = toAppFailure(e);
      var message = failureMessage(l10n, failure);
      if (failure is ServerFailure &&
          (failure.code == ErrorCode.premiumUsernamePriceChanged ||
              failure.code == ErrorCode.premiumUsernameUnavailable)) {
        // Read the name again: a new price, or why it is gone.
        try {
          final fresh = await ref
              .read(premiumRepositoryProvider)
              .status(_status.username);
          if (mounted) setState(() => _status = fresh);
        } on Object {
          // Keep the message.
        }
      }
      if (failure is ServerFailure &&
          failure.code == ErrorCode.insufficientCoins) {
        ref.invalidate(liveCoinsProvider);
        message = l10n.premiumNotEnoughCoins;
      }
      if (mounted) setState(() => _error = message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final text = context.textStyles;
    final status = _status;
    final tier = status.tier ?? PremiumTier.silver;
    final price = status.priceCoins;
    final coins = ref.watch(liveCoinsProvider);
    final balance = coins.value;
    final short = price != null && balance != null && balance < price;
    final renew = widget.current != null;
    final now = clock.now();
    final base = renew && !widget.current!.grace
        ? (widget.current!.expiresAt ?? now)
        : now;
    final until = base.add(Duration(days: status.periodDays));
    final regular =
        widget.current?.regularUsername ??
        ref.watch(currentUserProvider.select((u) => u?.username)) ??
        '';
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
          Text(
            renew ? l10n.premiumRenewTitle : l10n.premiumRentTitle,
            textAlign: TextAlign.center,
            style: text.title,
          ),
          const SizedBox(height: KSpacing.lg),
          Center(
            child: KSpecialUsername(
              username: status.username,
              tier: tier,
              height: 30,
            ),
          ),
          const SizedBox(height: KSpacing.sm),
          Text(
            '${premiumTierName(l10n, tier)} · ${premiumTierRule(l10n, tier)}',
            textAlign: TextAlign.center,
            style: text.caption.copyWith(color: p.textSecondary),
          ),
          const SizedBox(height: KSpacing.lg),
          _Line(
            label: l10n.premiumSheetPrice,
            value: price == null
                ? premiumStateLine(l10n, status)
                : premiumPriceLabel(l10n, price, status.periodDays),
          ),
          _Line(
            key: PremiumRentSheet.balanceKey,
            label: l10n.premiumSheetBalance,
            value: balance == null
                ? '…'
                : l10n.premiumCoins(KFormat.grouped(balance)),
            warn: short,
          ),
          _Line(
            label: l10n.premiumSheetUntil,
            value: KFormat.date(until.toLocal(), l10n.localeName),
          ),
          const SizedBox(height: KSpacing.sm),
          Text(
            l10n.premiumSheetAfter(regular),
            style: text.caption.copyWith(color: p.textSecondary),
          ),
          if (short) ...[
            const SizedBox(height: KSpacing.sm),
            Text(
              l10n.premiumNotEnoughCoins,
              key: PremiumRentSheet.shortKey,
              style: text.caption.copyWith(color: p.error),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: KSpacing.sm),
            Text(
              _error!,
              key: PremiumRentSheet.errorKey,
              style: text.caption.copyWith(color: p.error),
            ),
          ],
          const SizedBox(height: KSpacing.lg),
          KButton(
            key: PremiumRentSheet.confirmKey,
            loading: _busy,
            label: price == null
                ? l10n.premiumStateNotForSale
                : (renew
                      ? l10n.premiumRenewFor(KFormat.grouped(price))
                      : l10n.premiumRentFor(KFormat.grouped(price))),
            onPressed: price == null || short || !status.state.purchasable
                ? null
                : _confirm,
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const new({
    required this.label,
    required this.value,
    super.key,
    this.warn = false,
  });

  final String label;
  final String value;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = context.textStyles;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: KSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: text.body.copyWith(color: p.textSecondary),
            ),
          ),
          Text(
            value,
            style: text.bodyStrong.copyWith(color: warn ? p.error : null),
          ),
        ],
      ),
    );
  }
}
