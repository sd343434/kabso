import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/icons/kabso_art.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/posts/application/compose_controller.dart'
    show newIdempotencyKey;
import 'package:kabso_live/features/recharge/application/recharge_orders_providers.dart';
import 'package:kabso_live/features/recharge/application/recharge_providers.dart';
import 'package:kabso_live/features/recharge/data/recharge_orders_repository.dart';
import 'package:kabso_live/features/recharge/data/recharge_repository.dart';
import 'package:kabso_live/features/recharge/presentation/recharge_apply_screen.dart'
    show rechargePaymentTypeName;
import 'package:kabso_live/features/recharge/presentation/recharge_directory_screen.dart'
    show rechargeCountryName;
import 'package:kabso_live/features/recharge/presentation/recharge_widgets.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// `/recharge/order-new?agent=coin0007&country=EG` «طلب شحن جديد» (D204,
/// §10.64.2): the buyer picked a country and an ACTIVE agent in the directory;
/// here they choose the coins (a few presets or any amount) and one of the
/// agent's payment methods there. The price is the **server's** (retail USD
/// and, when an admin set a rate, the local amount) — read again as the
/// amount changes. «إرسال الطلب» creates the order (one key per attempt) and
/// opens its chat.
class RechargeOrderNewScreen extends ConsumerStatefulWidget {
  const new({required this.agentCode, required this.country, super.key});

  final String agentCode;
  final String country;

  static const coinsKey = Key('recharge.orderNew.coins');
  static const submitKey = Key('recharge.orderNew.submit');
  static const priceKey = Key('recharge.orderNew.price');
  static Key presetKey(int coins) => Key('recharge.orderNew.preset.$coins');
  static Key typeKey(String t) => Key('recharge.orderNew.type.$t');

  /// The amounts offered first (any amount may be typed).
  static const presets = [1000000, 5000000, 10000000, 50000000];

  @override
  ConsumerState<RechargeOrderNewScreen> createState() =>
      _RechargeOrderNewScreenState();
}

class _RechargeOrderNewScreenState
    extends ConsumerState<RechargeOrderNewScreen> {
  final _coins = TextEditingController(
    text: KFormat.grouped(RechargeOrderNewScreen.presets.first),
  );
  int _quoted = RechargeOrderNewScreen.presets.first;
  RechargePaymentType? _type;
  Timer? _debounce;
  var _busy = false;
  String _key = newIdempotencyKey();

  @override
  void dispose() {
    _debounce?.cancel();
    _coins.dispose();
    super.dispose();
  }

  int get _typed =>
      int.tryParse(_coins.text.replaceAll(RegExp('[^0-9]'), '')) ?? 0;

  void _changed() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _quoted = _typed);
    });
    setState(() => _key = newIdempotencyKey());
  }

  void _preset(int coins) {
    _debounce?.cancel();
    _coins.text = KFormat.grouped(coins);
    setState(() {
      _quoted = coins;
      _key = newIdempotencyKey();
    });
  }

  Future<void> _submit(RechargeOrderQuote quote) async {
    final type = _type ?? quote.paymentTypes.firstOrNull;
    if (type == null || _busy) return;
    setState(() => _busy = true);
    final l10n = context.l10n;
    try {
      final order = await ref
          .read(rechargeOrdersRepositoryProvider)
          .create(
            agentCode: widget.agentCode,
            country: widget.country,
            coins: quote.coins,
            paymentType: type,
            idempotencyKey: _key,
          );
      ref.invalidate(rechargeOrdersProvider(false));
      if (mounted) context.pushReplacement(AppRoutes.rechargeOrder(order.id));
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
    final rules = ref.watch(myRechargeAgentProvider).value?.rules;
    final min = rules?.orderMinCoins ?? 1;
    final max = rules?.orderMaxCoins ?? 1000000000;
    final inRange = _quoted >= min && _quoted <= max;
    final quote = inRange
        ? ref.watch(
            rechargeOrderQuoteProvider((
              agentCode: widget.agentCode,
              country: widget.country,
              coins: _quoted,
            )),
          )
        : null;
    final q = quote?.value;
    final types = q?.paymentTypes ?? const <RechargePaymentType>[];
    final type = types.contains(_type) ? _type : types.firstOrNull;
    final settled = _typed == _quoted;
    String usdOf(RechargeOrderQuote v) =>
        l10n.rechargeOrderUsd(KFormat.bidiIsolate(v.price.usd));
    return Scaffold(
      backgroundColor: p.background,
      appBar: KAppBar(
        backgroundColor: p.background,
        centerTitle: true,
        title: Text(l10n.rechargeOrderNewTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          KSpacing.lg,
          KSpacing.sm,
          KSpacing.lg,
          KSpacing.xl,
        ),
        children: [
          RechargeCard(
            child: Row(
              children: [
                const RechargeIconTile(icon: Icons.storefront_rounded),
                const SizedBox(width: KSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.rechargeIdLine(
                          KFormat.bidiIsolate(widget.agentCode),
                        ),
                        style: t.bodyStrong.copyWith(color: p.textPrimary),
                      ),
                      Text(
                        KFormat.bidiIsolate(
                          rechargeCountryName(context, widget.country),
                        ),
                        style: t.caption.copyWith(color: p.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: KSpacing.md),
          Text(
            l10n.rechargeOrderCoins,
            style: t.bodyStrong.copyWith(color: p.textPrimary),
          ),
          const SizedBox(height: KSpacing.xs),
          Wrap(
            spacing: KSpacing.xs,
            runSpacing: KSpacing.xs,
            children: [
              for (final c in RechargeOrderNewScreen.presets)
                KChip(
                  key: RechargeOrderNewScreen.presetKey(c),
                  label: KFormat.bidiIsolate(KFormat.compact(c, l10n)),
                  selected: _quoted == c && settled,
                  onSelected: () => _preset(c),
                ),
            ],
          ),
          const SizedBox(height: KSpacing.sm),
          TextField(
            key: RechargeOrderNewScreen.coinsKey,
            controller: _coins,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              const RechargeGroupedDigitsFormatter(),
            ],
            onChanged: (_) => _changed(),
            decoration: InputDecoration(
              prefixIcon: const Padding(
                padding: EdgeInsets.all(KSpacing.sm),
                child: KabsoArtIcon(KabsoArt.coin, size: 22),
              ),
              helperText: l10n.rechargeOrderCoinsRange(
                KFormat.bidiIsolate(KFormat.grouped(min)),
                KFormat.bidiIsolate(KFormat.grouped(max)),
              ),
              errorText: _typed > 0 && !(_typed >= min && _typed <= max)
                  ? l10n.rechargeOrderCoinsRange(
                      KFormat.bidiIsolate(KFormat.grouped(min)),
                      KFormat.bidiIsolate(KFormat.grouped(max)),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: KSpacing.md),
          Container(
            key: RechargeOrderNewScreen.priceKey,
            padding: const EdgeInsets.all(KSpacing.md),
            decoration: BoxDecoration(
              color: p.surfaceRaised,
              borderRadius: BorderRadius.circular(KRadius.lg),
              border: Border.all(color: p.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.rechargeOrderPrice,
                  style: t.caption.copyWith(color: p.textSecondary),
                ),
                const SizedBox(height: KSpacing.xxs),
                switch (quote) {
                  AsyncValue(value: final v?) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.rechargeOrderUsd(KFormat.bidiIsolate(v.price.usd)),
                        style: t.title.copyWith(
                          color: p.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (v.price.local case final local?)
                        Text(
                          l10n.rechargeOrderLocal(
                            KFormat.bidiIsolate(local.amount),
                            local.currency,
                            KFormat.bidiIsolate(local.rate),
                          ),
                          style: t.bodyStrong.copyWith(color: p.primaryText),
                        )
                      else
                        Text(
                          l10n.rechargeOrderUsdOnly,
                          style: t.caption.copyWith(color: p.textSecondary),
                        ),
                    ],
                  ),
                  AsyncValue(:final error?, isLoading: false) => Text(
                    failureMessage(l10n, toAppFailure(error)),
                    style: t.caption.copyWith(color: p.error),
                  ),
                  null => Text(
                    '—',
                    style: t.title.copyWith(color: p.textTertiary),
                  ),
                  _ => const LinearProgressIndicator(minHeight: 2),
                },
                const SizedBox(height: KSpacing.xs),
                Text(
                  l10n.rechargeOrderPriceNote,
                  style: t.caption.copyWith(color: p.textTertiary),
                ),
              ],
            ),
          ),
          if (types.isNotEmpty) ...[
            const SizedBox(height: KSpacing.md),
            Text(
              l10n.rechargeOrderPaymentMethod,
              style: t.bodyStrong.copyWith(color: p.textPrimary),
            ),
            const SizedBox(height: KSpacing.xs),
            Wrap(
              spacing: KSpacing.xs,
              runSpacing: KSpacing.xs,
              children: [
                for (final ty in types)
                  KChip(
                    key: RechargeOrderNewScreen.typeKey(ty.wire),
                    label: rechargePaymentTypeName(l10n, ty),
                    selected: ty == type,
                    onSelected: () => setState(() => _type = ty),
                  ),
              ],
            ),
          ],
          const SizedBox(height: KSpacing.md),
          RechargeNotice(
            icon: Icons.shield_outlined,
            text: l10n.rechargeOrderOutsideNote,
          ),
          const SizedBox(height: KSpacing.lg),
          FilledButton(
            key: RechargeOrderNewScreen.submitKey,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(KSizes.minTouchTarget + 4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(KRadius.pill),
              ),
            ),
            onPressed: q == null || type == null || !settled || _busy
                ? null
                : () => unawaited(_submit(q)),
            child: Text(
              q == null
                  ? l10n.rechargeOrderSubmit
                  : '${l10n.rechargeOrderSubmit} · ${usdOf(q)}',
            ),
          ),
        ],
      ),
    );
  }
}
