import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/icons/kabso_art.dart';
import 'package:kabso_live/core/ids/client_id.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/application/live_wallet_controller.dart';
import 'package:kabso_live/features/live/data/live_boost_repository.dart';
import 'package:kabso_live/features/live/domain/live_boost_models.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D154b («بطاقة الزيارات», CONVENTIONS §10.34): puts this live in one of
/// the few paid «مميز» slots at the top of the live list. The host opens it
/// from Room Tools; a viewer from the host's card, as a gift to the host
/// ([hostName] set: the host earns nothing from it, owner 15c). It shows
/// the lengths with their prices and savings, when a new card would start
/// (honest: the server's «at the latest»), the live's own card running or
/// waiting, and the caller's reward cards; buying asks once to confirm.
Future<void> showLiveBoostSheet(
  BuildContext context, {
  required String roomId,
  String? hostName,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: const Color(0xFF1F1D24),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(19)),
  ),
  builder: (_) => LiveBoostSheet(roomId: roomId, hostName: hostName),
);

class LiveBoostSheet extends ConsumerStatefulWidget {
  const new({required this.roomId, super.key, this.hostName});

  final String roomId;

  /// A viewer gifting the host (their name); null: the host's own live.
  final String? hostName;

  static const sheetKey = Key('boost.sheet');
  static const buyKey = Key('boost.buy');
  static const cardKey = Key('boost.useCard');
  static const stateKey = Key('boost.state');
  static const etaKey = Key('boost.eta');
  static const messageKey = Key('boost.message');
  static const confirmKey = Key('boost.confirm');
  static Key optionKey(int minutes) => Key('boost.option.$minutes');

  @override
  ConsumerState<LiveBoostSheet> createState() => _LiveBoostSheetState();
}

class _LiveBoostSheetState extends ConsumerState<LiveBoostSheet> {
  LiveBoostOffers? _offers;
  Object? _loadError;
  int? _minutes;
  bool _useCard = false;
  bool _busy = false;
  String? _message;
  bool _error = false;

  /// A lost answer is sent again with the same id (never charged twice).
  ({String key, String clientId})? _pending;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final offers = await ref
          .read(liveBoostRepositoryProvider)
          .offers(roomId: widget.roomId);
      if (!mounted) return;
      setState(() {
        _offers = offers;
        _loadError = null;
        _minutes ??= offers.options.isEmpty
            ? null
            : offers.options.first.minutes;
      });
    } on Object catch (e) {
      if (mounted) setState(() => _loadError = e);
    }
  }

  int _held(LiveBoostOffers offers, int minutes) =>
      offers.cards.where((c) => c.minutes == minutes).firstOrNull?.quantity ??
      0;

  Future<void> _buy(LiveBoostOffers offers, LiveBoostOption option) async {
    final l10n = context.l10n;
    final card = _useCard && _held(offers, option.minutes) > 0;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l10n.liveBoostConfirmTitle),
        content: Text(
          card
              ? l10n.liveBoostConfirmCard(option.minutes)
              : l10n.liveBoostConfirmCoins(
                  option.minutes,
                  KFormat.grouped(option.priceCoins),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            key: LiveBoostSheet.confirmKey,
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(l10n.liveBoostConfirmAction),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final source = card ? LiveBoostSource.card : LiveBoostSource.coins;
    final key = '${source.wire}|${option.minutes}';
    final clientId = _pending?.key == key ? _pending!.clientId : newClientId();
    _pending = (key: key, clientId: clientId);
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final result = await ref
          .read(liveBoostRepositoryProvider)
          .buy(
            widget.roomId,
            minutes: option.minutes,
            source: source,
            clientId: clientId,
          );
      _pending = null;
      if (ref.exists(liveCoinsProvider)) {
        ref.read(liveCoinsProvider.notifier).set(result.coins);
      }
      ref.invalidate(liveBoostedRoomsProvider);
      if (!mounted) return;
      setState(() {
        _offers = offers.copyWith(cards: result.cards, roomBoost: result.boost);
        _error = false;
        _message = result.boost.state == LiveBoostState.running
            ? l10n.liveBoostDoneNow
            : l10n.liveBoostDoneWaiting(_minutesFromNow(result.boost.startsAt));
      });
    } on Object catch (e) {
      final failure = toAppFailure(e);
      if (failure is ServerFailure) _pending = null;
      if (!mounted) return;
      if (failure.code == ErrorCode.insufficientCoins) {
        ref.invalidate(liveCoinsProvider);
      }
      if (failure.code == ErrorCode.boostRoomBusy ||
          failure.code == ErrorCode.boostCardInsufficient) {
        unawaited(_load());
      }
      setState(() {
        _error = true;
        _message = failureMessage(l10n, failure);
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static int _minutesFromNow(DateTime at) {
    final ms = at.difference(DateTime.now()).inMilliseconds;
    return ms <= 0 ? 0 : (ms / 60000).ceil();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    const ink = Color(0xFFFFFFFF);
    const soft = Color(0xFFB9B6C2);
    const gold = Color(0xFFFFD36E);
    final offers = _offers;
    Widget body;
    if (offers == null) {
      body = Padding(
        padding: const EdgeInsets.symmetric(vertical: KSpacing.xl),
        child: Center(
          child: _loadError == null
              ? const CircularProgressIndicator()
              : KErrorState(
                  title: l10n.liveBoostLoadError,
                  message: failureMessage(l10n, toAppFailure(_loadError!)),
                  retryLabel: l10n.actionRetry,
                  onRetry: () {
                    setState(() => _loadError = null);
                    unawaited(_load());
                  },
                  compact: true,
                ),
        ),
      );
    } else {
      final own = offers.roomBoost;
      final option =
          offers.options.where((o) => o.minutes == _minutes).firstOrNull ??
          offers.options.firstOrNull;
      final held = option == null ? 0 : _held(offers, option.minutes);
      final eta = _minutesFromNow(offers.nextStartAt);
      body = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (own != null)
            Container(
              key: LiveBoostSheet.stateKey,
              margin: const EdgeInsets.only(bottom: KSpacing.sm),
              padding: const EdgeInsets.all(KSpacing.sm),
              decoration: BoxDecoration(
                color: const Color(0x26FFD36E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                own.state == LiveBoostState.running
                    ? l10n.liveBoostRunning(_minutesFromNow(own.endsAt))
                    : l10n.liveBoostWaiting(_minutesFromNow(own.startsAt)),
                style: t.body.copyWith(color: gold),
              ),
            ),
          Wrap(
            spacing: KSpacing.sm,
            runSpacing: KSpacing.sm,
            children: [
              for (final o in offers.options)
                _Option(
                  key: LiveBoostSheet.optionKey(o.minutes),
                  option: o,
                  held: _held(offers, o.minutes),
                  selected: o.minutes == option?.minutes,
                  onTap: () => setState(() {
                    _minutes = o.minutes;
                    _message = null;
                  }),
                ),
            ],
          ),
          const SizedBox(height: KSpacing.sm),
          Text(
            eta <= 0 ? l10n.liveBoostStartsNow : l10n.liveBoostStartsIn(eta),
            key: LiveBoostSheet.etaKey,
            style: t.caption.copyWith(color: soft),
          ),
          if (held > 0)
            SwitchListTile(
              key: LiveBoostSheet.cardKey,
              contentPadding: EdgeInsets.zero,
              value: _useCard,
              onChanged: (on) => setState(() => _useCard = on),
              title: Text(
                l10n.liveBoostUseCard(held),
                style: t.body.copyWith(color: ink),
              ),
            ),
          const SizedBox(height: KSpacing.sm),
          FilledButton(
            key: LiveBoostSheet.buyKey,
            onPressed: option == null || own != null || _busy
                ? null
                : () => unawaited(_buy(offers, option)),
            child: _busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    option == null
                        ? l10n.liveBoostTitle
                        : _useCard && held > 0
                        ? l10n.liveBoostUseCardAction
                        : l10n.liveBoostBuy(KFormat.grouped(option.priceCoins)),
                  ),
          ),
          if (_message case final message?) ...[
            const SizedBox(height: KSpacing.sm),
            Semantics(
              liveRegion: true,
              child: Text(
                message,
                key: LiveBoostSheet.messageKey,
                textAlign: TextAlign.center,
                style: t.caption.copyWith(
                  color: _error ? const Color(0xFFFF8A8A) : gold,
                ),
              ),
            ),
          ],
        ],
      );
    }
    final host = widget.hostName;
    return SafeArea(
      top: false,
      child: Semantics(
        key: LiveBoostSheet.sheetKey,
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        label: l10n.liveBoostTitle,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            KSpacing.md,
            14,
            KSpacing.md,
            KSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  l10n.liveBoostTitle,
                  style: t.title.copyWith(color: ink),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                host == null
                    ? l10n.liveBoostHint(offers?.slots ?? 3)
                    : l10n.liveBoostGiftHint(KFormat.bidiIsolate(host)),
                style: t.caption.copyWith(color: soft),
              ),
              const SizedBox(height: KSpacing.md),
              body,
            ],
          ),
        ),
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const new({
    required this.option,
    required this.held,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final LiveBoostOption option;
  final int held;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    return Semantics(
      button: true,
      selected: selected,
      label: [
        l10n.liveBoostMinutes(option.minutes),
        l10n.liveBoostPrice(KFormat.grouped(option.priceCoins)),
        if (option.savePercent > 0) l10n.liveBoostSave(option.savePercent),
        if (held > 0) l10n.liveBoostHeld(held),
      ].join(', '),
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: KMotion.of(context, KMotion.fast),
          width: 74,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: selected ? const Color(0x33FFD36E) : const Color(0x14FFFFFF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? const Color(0xFFFFD36E)
                  : const Color(0x00000000),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.liveBoostMinutes(option.minutes),
                maxLines: 1,
                style: t.bodyStrong.copyWith(color: const Color(0xFFFFFFFF)),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const KabsoArtIcon(KabsoArt.coin, size: 12),
                    const SizedBox(width: 3),
                    Text(
                      KFormat.grouped(option.priceCoins),
                      style: t.caption.copyWith(
                        color: const Color(0xFFD8C79A),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (option.savePercent > 0) ...[
                const SizedBox(height: 2),
                Text(
                  l10n.liveBoostSave(option.savePercent),
                  maxLines: 1,
                  style: t.caption.copyWith(
                    color: const Color(0xFF7FE3C8),
                    fontSize: 10,
                  ),
                ),
              ],
              if (held > 0) ...[
                const SizedBox(height: 2),
                Text(
                  l10n.liveBoostHeld(held),
                  maxLines: 1,
                  style: t.caption.copyWith(
                    color: const Color(0xFFFFD36E),
                    fontSize: 10,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
