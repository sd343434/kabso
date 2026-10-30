import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/posts/application/compose_controller.dart'
    show newIdempotencyKey;
import 'package:kabso_live/features/wallet/application/wallet_providers.dart';
import 'package:kabso_live/features/wallet/data/cherry_repository.dart';
import 'package:kabso_live/features/wallet/presentation/wallet_screen.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Opens the withdrawal request sheet for [wallet] (D179).
Future<CherryWithdrawal?> showCherryWithdrawSheet(
  BuildContext context,
  CherryWallet wallet,
) => showModalBottomSheet<CherryWithdrawal>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => CherryWithdrawSheet(wallet: wallet),
);

/// Parses a typed amount ("10", "12.5", "12,50") into minor units; null when
/// it is not an amount with at most two decimals.
int? parseAmountMinor(String raw) {
  final text = raw.trim().replaceAll(',', '.');
  final match = RegExp(r'^(\d{1,7})(?:\.(\d{1,2}))?$').firstMatch(text);
  if (match == null) return null;
  final whole = int.parse(match.group(1)!);
  final cents = (match.group(2) ?? '').padRight(2, '0');
  return whole * 100 + int.parse(cents);
}

/// D179 «سحب»: a withdrawal request — the amount (at least the minimum,
/// shown as cherries ↔ money at the payout rate), where to be paid (free
/// text) and the honest note: no payment provider yet, the team pays by
/// hand within N days; the cherries are held now and come back if the
/// request is refused. One Idempotency-Key per sheet.
class CherryWithdrawSheet extends ConsumerStatefulWidget {
  const new({required this.wallet, super.key});

  final CherryWallet wallet;

  static const amountKey = Key('withdraw.amount');
  static const detailsKey = Key('withdraw.details');
  static const submitKey = Key('withdraw.submit');
  static const errorKey = Key('withdraw.error');
  static const pendingKey = Key('withdraw.pending');

  @override
  ConsumerState<CherryWithdrawSheet> createState() =>
      _CherryWithdrawSheetState();
}

class _CherryWithdrawSheetState extends ConsumerState<CherryWithdrawSheet> {
  final String _key = newIdempotencyKey();
  final _amount = TextEditingController();
  final _details = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final rules = widget.wallet.payout;
    _amount.text = _plain(rules.minAmountMinor);
  }

  @override
  void dispose() {
    _amount.dispose();
    _details.dispose();
    super.dispose();
  }

  static String _plain(int minor) => minor % 100 == 0
      ? '${minor ~/ 100}'
      : '${minor ~/ 100}.${(minor % 100).toString().padLeft(2, '0')}';

  Future<void> _submit(int amountMinor) async {
    final l10n = context.l10n;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final request = await ref
          .read(cherryRepositoryProvider)
          .requestWithdrawal(
            amountMinor: amountMinor,
            payoutDetails: _details.text.trim(),
            idempotencyKey: _key,
          );
      ref
        ..invalidate(myCherriesProvider)
        ..invalidate(cherryLedgerProvider)
        ..invalidate(myWithdrawalsProvider);
      if (!mounted) return;
      KSnack.success(context, l10n.withdrawSent);
      Navigator.of(context).pop(request);
    } on Object catch (e) {
      if (!mounted) return;
      final failure = toAppFailure(e);
      setState(() {
        _busy = false;
        _error = failureMessage(l10n, failure);
      });
      if (failure.code == ErrorCode.withdrawalPending ||
          failure.code == ErrorCode.insufficientCherries) {
        ref.invalidate(myCherriesProvider);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final w = widget.wallet;
    final rules = w.payout;
    String money(int minor) =>
        KFormat.bidiIsolate(formatPrice(minor, rules.currency));
    final minor = parseAmountMinor(_amount.text);
    final need = minor == null ? null : rules.cherriesFor(minor);
    final maxMinor = rules.valueOf(w.cherries);
    final amountError = switch (minor) {
      null when _amount.text.trim().isNotEmpty => l10n.withdrawAmountInvalid,
      final m? when m < rules.minAmountMinor => l10n.withdrawAmountMin(
        money(rules.minAmountMinor),
      ),
      final m? when rules.cherriesFor(m) > w.cherries =>
        l10n.withdrawAmountShort(money(maxMinor)),
      _ => null,
    };
    final detailsOk = _details.text.trim().length >= 3;
    final pending = w.pendingWithdrawal;
    final canSend =
        pending == null &&
        minor != null &&
        amountError == null &&
        detailsOk &&
        !_busy;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          KSpacing.lg,
          0,
          KSpacing.lg,
          KSpacing.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              header: true,
              child: Text(
                l10n.withdrawTitle,
                textAlign: TextAlign.center,
                style: t.title.copyWith(
                  color: p.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: KSpacing.md),
            Row(
              children: [
                const KCherryIcon(size: 22),
                const SizedBox(width: KSpacing.xs),
                Expanded(
                  child: Text(
                    l10n.withdrawBalance(
                      KFormat.bidiIsolate(KFormat.grouped(w.cherries)),
                      money(w.valueMinor),
                    ),
                    style: t.bodyStrong.copyWith(color: p.textPrimary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: KSpacing.xxs),
            Text(
              l10n.withdrawRate(
                KFormat.bidiIsolate(KFormat.grouped(rules.rateCherries)),
                money(rules.rateMinor),
                money(rules.minAmountMinor),
              ),
              style: t.caption.copyWith(color: p.textSecondary),
            ),
            const SizedBox(height: KSpacing.lg),
            if (pending != null)
              Text(
                l10n.cherryPendingNote(
                  money(pending.amountMinor),
                  rules.payoutDays,
                ),
                key: CherryWithdrawSheet.pendingKey,
                style: t.body.copyWith(color: p.textPrimary),
              )
            else ...[
              KTextField(
                fieldKey: CherryWithdrawSheet.amountKey,
                label: l10n.withdrawAmountLabel(rules.currency),
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textDirection: TextDirection.ltr,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp('[0-9.,]')),
                ],
                errorText: amountError,
                helperText: need == null
                    ? null
                    : l10n.withdrawAmountHelper(
                        KFormat.bidiIsolate(KFormat.grouped(need)),
                      ),
                onChanged: (_) => setState(() => _error = null),
              ),
              const SizedBox(height: KSpacing.md),
              Text(
                l10n.withdrawDetailsLabel,
                style: t.label.copyWith(color: p.textSecondary),
              ),
              const SizedBox(height: KSpacing.xs),
              TextField(
                key: CherryWithdrawSheet.detailsKey,
                controller: _details,
                minLines: 2,
                maxLines: 4,
                maxLength: 500,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: l10n.withdrawDetailsHint,
                  border: const OutlineInputBorder(),
                  counterText: '',
                ),
                onChanged: (_) => setState(() => _error = null),
              ),
              const SizedBox(height: KSpacing.md),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: p.info.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(KRadius.md),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(KSpacing.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded, size: 18, color: p.info),
                      const SizedBox(width: KSpacing.sm),
                      Expanded(
                        child: Text(
                          l10n.withdrawManualNote(rules.payoutDays),
                          style: t.caption.copyWith(color: p.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_error case final error?) ...[
                const SizedBox(height: KSpacing.md),
                Text(
                  error,
                  key: CherryWithdrawSheet.errorKey,
                  style: t.label.copyWith(color: p.error),
                ),
              ],
              const SizedBox(height: KSpacing.lg),
              KButton(
                key: CherryWithdrawSheet.submitKey,
                label: minor == null
                    ? l10n.withdrawSubmit
                    : l10n.withdrawSubmitAmount(money(minor)),
                loading: _busy,
                onPressed: canSend ? () => _submit(minor) : null,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
