import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/icons/kabso_art.dart';
import 'package:kabso_live/core/ids/client_id.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/application/live_gift_effects.dart';
import 'package:kabso_live/features/live/application/live_gift_providers.dart';
import 'package:kabso_live/features/live/application/live_wallet_controller.dart';
import 'package:kabso_live/features/live/data/live_gift_repository.dart';
import 'package:kabso_live/features/live/domain/live_gift_models.dart';
import 'package:kabso_live/features/live/presentation/widgets/gift_panel.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_gift_art.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_view_data.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// The live the gift panel sends in: the room, its host and who sits on
/// a seat now ([seated] is read with the panel's `ref`, so it follows the
/// seats). [onSeatsStale] reads the seats again after a
/// `LIVE_GIFT_RECIPIENT_UNAVAILABLE`.
class LiveGiftRoom {
  const new({
    required this.roomId,
    required this.host,
    required this.seated,
    this.onSeatsStale,
  });

  final String roomId;
  final UserSummary host;
  final List<UserSummary> Function(WidgetRef ref) seated;
  final VoidCallback? onSeatsStale;
}

/// The live gift panel (CP-020, §10.23; owner's reference: a dark bottom
/// sheet like big live apps, Kabso's own art): who receives (the host with
/// a Host chip and the people on the mic, several at once, "All"), the
/// tabs شائعة / مناسبات / مرح from the catalogue and الحقيبة (the gift
/// bag), a 4-column grid, then the coin balance, the quantity and Send.
///
/// Every send has its own `clientId`; a send whose answer was lost is sent
/// again with the same one (never charged twice). Quick taps on Send queue
/// more sends (the server counts the combo; the panel shows ×N). The
/// balance and the bag follow each answer. Nothing is invented: an empty
/// catalogue shows "No gifts yet".
class KLiveGiftSheet extends ConsumerStatefulWidget {
  const new({required this.room, super.key, this.preselect});

  final LiveGiftRoom room;

  /// The person whose card's Gifts button opened the panel (selected when
  /// they can receive).
  final LiveGiftPreselect? preselect;

  /// Opens the panel as a non-dimming room sheet (D36).
  static Future<void> show(
    BuildContext context, {
    required LiveGiftRoom room,
    LiveGiftPreselect? preselect,
  }) => KGiftPanel.show(
    context,
    builder: (_) => KLiveGiftSheet(room: room, preselect: preselect),
  );

  static const sheetKey = Key('gift.sheet');
  static const allKey = Key('gift.recipients.all');
  static const quantityKey = Key('gift.quantity');
  static const sendKey = Key('gift.send');
  static const balanceKey = Key('gift.balance');
  static const reasonKey = Key('gift.reason');
  static const comboKey = Key('gift.combo');
  static const emptyKey = Key('gift.empty');
  static Key tabKey(String id) => Key('gift.tab.$id');
  static Key cellKey(String code, {bool bag = false}) =>
      Key('gift.${bag ? 'bag' : 'cell'}.$code');
  static Key recipientKey(String username) => Key('gift.recipient.$username');
  static Key quantityOptionKey(int quantity) => Key('gift.quantity.$quantity');

  /// The id of the bag tab (the others are the category wire values).
  static const bagTab = 'BAG';

  @override
  ConsumerState<KLiveGiftSheet> createState() => _KLiveGiftSheetState();
}

/// The sheet's own dark colours (owner's reference: deeper than the room
/// surfaces, cells a step lighter).
abstract final class _Sheet {
  static const background = Color(0xFF121216);
  static const cell = Color(0xFF1C1C22);
  static const cellSelected = Color(0xFF2A2230);
  static const muted = Color(0xFF9A9AA6);
  static const white = Color(0xFFFFFFFF);
  static const Color eventPink = KLiveColors.pkLeft;
  static const double height = 0.56;
}

class _KLiveGiftSheetState extends ConsumerState<KLiveGiftSheet> {
  String? _tab;
  String? _selected;
  int? _quantity;

  /// The usernames chosen; null until the person picks (then the default
  /// applies: the host, or the preselected person).
  Set<String>? _chosen;

  /// Sends waiting behind the one in flight (quick taps).
  int _queued = 0;
  bool _busy = false;

  /// The send whose answer was lost: the same intent reuses its id.
  ({String intent, String clientId})? _pending;
  String? _error;

  /// The combo count of the last answer, shown from 2 while it lasts.
  int _combo = 0;
  Timer? _comboTimer;

  LiveGiftRoom get room => widget.room;

  @override
  void dispose() {
    _comboTimer?.cancel();
    super.dispose();
  }

  /// Who may receive: the host (not when the host sends) and the people on
  /// a seat, never the caller.
  List<UserSummary> _candidates(String? myId) {
    final seen = <String>{};
    return [
      for (final u in [room.host, ...room.seated(ref)])
        if (u.id != myId && seen.add(u.username)) u,
    ];
  }

  Set<String> _defaultChosen(List<UserSummary> candidates) {
    final names = {for (final c in candidates) c.username};
    final pre = widget.preselect?.username;
    if (pre != null && names.contains(pre)) return {pre};
    if (names.contains(room.host.username)) return {room.host.username};
    return {};
  }

  void _resetCombo() {
    _comboTimer?.cancel();
    _combo = 0;
  }

  void _toggle(String username, List<UserSummary> candidates, int max) {
    final chosen = {...(_chosen ?? _defaultChosen(candidates))};
    if (!chosen.remove(username) && chosen.length < max) chosen.add(username);
    setState(() {
      _chosen = chosen;
      _error = null;
      _resetCombo();
    });
  }

  void _toggleAll(List<UserSummary> candidates, bool allOn, int max) {
    setState(() {
      _chosen = allOn
          ? _defaultChosen(candidates)
          : {for (final c in candidates.take(max)) c.username};
      _error = null;
      _resetCombo();
    });
  }

  /// One tap on Send: queues a send; sends run one at a time.
  Future<void> _onSend(_Intent intent) async {
    _queued++;
    if (_busy) {
      setState(() {});
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    while (_queued > 0 && mounted) {
      _queued--;
      final ok = await _sendOnce(intent);
      if (!ok) _queued = 0;
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<bool> _sendOnce(_Intent intent) async {
    final l10n = context.l10n;
    final key = intent.key;
    final clientId = _pending?.intent == key
        ? _pending!.clientId
        : newClientId();
    _pending = (intent: key, clientId: clientId);
    try {
      final result = await ref
          .read(liveGiftRepositoryProvider)
          .send(
            room.roomId,
            giftCode: intent.code,
            quantity: intent.quantity,
            recipients: intent.recipients,
            source: intent.source,
            clientId: clientId,
          );
      _pending = null;
      if (ref.exists(liveCoinsProvider)) {
        ref.read(liveCoinsProvider.notifier).set(result.coins);
      }
      if (intent.source == LiveGiftSource.bag) {
        ref
            .read(giftBagProvider.notifier)
            .setQuantity(intent.code, result.bagQuantity);
      }
      // Shown at once; the room's message for it plays nothing more.
      ref.read(liveGiftEffectsProvider(room.roomId).notifier).show(result.gift);
      if (!mounted) return true;
      final window = ref.read(giftCatalogueProvider).value?.comboWindowSeconds;
      setState(() {
        _error = null;
        _combo = result.gift.combo.count;
        _comboTimer?.cancel();
        _comboTimer = Timer(Duration(seconds: window ?? 5), () {
          if (mounted) setState(() => _combo = 0);
        });
      });
      return true;
    } on Object catch (e) {
      final failure = toAppFailure(e);
      // Only a lost answer is sent again with the same id; a refusal
      // starts a new attempt.
      if (failure is ServerFailure) _pending = null;
      if (!mounted) return false;
      final code = failure.code;
      if (code == ErrorCode.insufficientCoins) {
        ref.invalidate(liveCoinsProvider);
      } else if (code == ErrorCode.giftUnavailable) {
        unawaited(ref.read(giftCatalogueProvider.notifier).reload());
        ref.invalidate(giftBagProvider);
      } else if (code == ErrorCode.giftBagInsufficient) {
        ref.invalidate(giftBagProvider);
      } else if (code == ErrorCode.liveGiftRecipientUnavailable) {
        room.onSeatsStale?.call();
      }
      final message = code == ErrorCode.insufficientCoins
          ? l10n.liveGiftNotEnoughCoins
          : failureMessage(l10n, failure);
      setState(() {
        _error = message;
        _resetCombo();
      });
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * _Sheet.height;
    // Dense room controls: text grows up to the live overlays' limit.
    final media = MediaQuery.of(context);
    return KLiveSurface(
      child: MediaQuery(
        data: media.copyWith(
          textScaler: media.textScaler.clamp(
            maxScaleFactor: KMetrics.overlayMaxTextScale,
          ),
        ),
        child: Semantics(
          key: KLiveGiftSheet.sheetKey,
          scopesRoute: true,
          namesRoute: true,
          explicitChildNodes: true,
          label: context.l10n.giftPanelTitle,
          child: Container(
            height: height,
            decoration: const BoxDecoration(
              color: _Sheet.background,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(KRadius.xl),
              ),
            ),
            child: SafeArea(top: false, child: _body(context)),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final l10n = context.l10n;
    final me = ref.watch(currentUserProvider);
    final handle = Center(
      child: Container(
        margin: const EdgeInsets.only(top: KSpacing.sm),
        width: KMetrics.sheetHandleWidth,
        height: KMetrics.sheetHandleHeight,
        decoration: BoxDecoration(
          color: const Color(0x40FFFFFF),
          borderRadius: BorderRadius.circular(KRadius.pill),
        ),
      ),
    );
    if (me == null) {
      return Column(
        children: [
          handle,
          Expanded(
            child: Center(
              child: KEmptyState(
                key: KLiveGiftSheet.emptyKey,
                icon: Icons.card_giftcard_rounded,
                title: l10n.liveGiftSignIn,
                message: l10n.liveGiftEmptyMessage,
                compact: true,
              ),
            ),
          ),
        ],
      );
    }
    final catalogueAsync = ref.watch(giftCatalogueProvider);
    final catalogue = catalogueAsync.value;
    final tabs = [
      for (final c in catalogue?.categories ?? GiftCategory.values) c.wire,
      KLiveGiftSheet.bagTab,
    ];
    final tab = tabs.contains(_tab) ? _tab! : tabs.first;
    final isBag = tab == KLiveGiftSheet.bagTab;
    final bagAsync = isBag ? ref.watch(giftBagProvider) : null;

    final candidates = _candidates(me.id);
    final max = catalogue?.maxRecipients ?? 25;
    final names = {for (final c in candidates) c.username};
    final chosen = (_chosen ?? _defaultChosen(candidates)).intersection(names);
    final allOn =
        candidates.length > 1 && chosen.length == candidates.take(max).length;

    // The gifts of this tab and the selected one.
    final cells = <_Cell>[
      if (isBag)
        for (final item in bagAsync?.value ?? const <GiftBagItem>[])
          _Cell(item.gift, bagQuantity: item.quantity)
      else if (catalogue != null)
        for (final g in catalogue.of(GiftCategory.fromWire(tab)!)) _Cell(g),
    ];
    final selected = cells.where((c) => c.gift.code == _selected).firstOrNull;
    final quantities = catalogue?.quantities ?? const [1];
    final quantity = quantities.contains(_quantity)
        ? _quantity!
        : quantities.first;

    final String? reason;
    if (catalogue != null && catalogue.data.isEmpty) {
      reason = l10n.liveGiftEmptyTitle;
    } else if (candidates.isEmpty) {
      reason = l10n.liveGiftNoRecipients;
    } else if (selected == null) {
      reason = l10n.liveGiftPickGift;
    } else if (chosen.isEmpty) {
      reason = l10n.liveGiftPickRecipient;
    } else {
      reason = null;
    }
    final intent = reason != null || selected == null
        ? null
        : _Intent(
            code: selected.gift.code,
            quantity: quantity,
            recipients: [
              for (final c in candidates)
                if (chosen.contains(c.username)) c.username,
            ],
            source: isBag ? LiveGiftSource.bag : LiveGiftSource.coins,
          );
    final pre = widget.preselect;
    final notOnMic = pre != null && !names.contains(pre.username)
        ? l10n.liveGiftNotOnMic(KFormat.bidiIsolate(pre.name))
        : null;

    Widget grid;
    final loading = isBag ? bagAsync! : catalogueAsync;
    if (loading.hasError && loading.value == null) {
      grid = Center(
        child: KErrorState(
          title: l10n.liveGiftLoadError,
          message: failureMessage(l10n, toAppFailure(loading.error!)),
          retryLabel: l10n.actionRetry,
          onRetry: () => isBag
              ? ref.invalidate(giftBagProvider)
              : ref.invalidate(giftCatalogueProvider),
          compact: true,
        ),
      );
    } else if (loading.value == null) {
      grid = const Center(child: CircularProgressIndicator());
    } else if (cells.isEmpty) {
      final noGifts = catalogue == null || catalogue.data.isEmpty;
      grid = Center(
        child: SingleChildScrollView(
          child: KEmptyState(
            key: KLiveGiftSheet.emptyKey,
            icon: isBag && !noGifts
                ? Icons.inventory_2_outlined
                : Icons.card_giftcard_rounded,
            title: isBag && !noGifts
                ? l10n.liveGiftBagEmptyTitle
                : l10n.liveGiftEmptyTitle,
            message: isBag && !noGifts
                ? l10n.liveGiftBagEmptyMessage
                : l10n.liveGiftEmptyMessage,
            compact: true,
          ),
        ),
      );
    } else {
      grid = GridView.builder(
        padding: const EdgeInsets.fromLTRB(
          KSpacing.md,
          KSpacing.xs,
          KSpacing.md,
          KSpacing.sm,
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: KSizes.giftGridColumns,
          mainAxisSpacing: KSpacing.sm,
          crossAxisSpacing: KSpacing.sm,
          childAspectRatio: 0.78,
        ),
        itemCount: cells.length,
        itemBuilder: (context, i) {
          final cell = cells[i];
          return _GiftTile(
            key: KLiveGiftSheet.cellKey(cell.gift.code, bag: isBag),
            cell: cell,
            selected: cell.gift.code == selected?.gift.code,
            onTap: () => setState(() {
              _selected = cell.gift.code;
              _error = null;
              _resetCombo();
            }),
          );
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        handle,
        const SizedBox(height: KSpacing.sm),
        _Recipients(
          candidates: candidates,
          host: room.host,
          chosen: chosen,
          allOn: allOn,
          showAll: candidates.length > 1,
          onTap: (u) => _toggle(u, candidates, max),
          onAll: () => _toggleAll(candidates, allOn, max),
        ),
        if (notOnMic != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              KSpacing.lg,
              KSpacing.xs,
              KSpacing.lg,
              0,
            ),
            child: Text(
              notOnMic,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.textStyles.caption.copyWith(color: _Sheet.muted),
            ),
          ),
        const SizedBox(height: KSpacing.xs),
        _Tabs(
          tabs: tabs,
          selected: tab,
          onTap: (id) => setState(() {
            _tab = id;
            _selected = null;
            _error = null;
            _resetCombo();
          }),
        ),
        const Divider(height: 1, thickness: 1, color: Color(0x14FFFFFF)),
        Expanded(child: grid),
        if (_error ?? (reason == l10n.liveGiftEmptyTitle ? null : reason)
            case final line?)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
            child: Text(
              line,
              key: KLiveGiftSheet.reasonKey,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.textStyles.caption.copyWith(
                color: _error != null ? KPalette.dark.error : _Sheet.muted,
              ),
            ),
          ),
        _BottomBar(
          quantities: quantities,
          quantity: quantity,
          onQuantity: (q) => setState(() {
            _quantity = q;
            _error = null;
            _resetCombo();
          }),
          combo: _combo,
          busy: _busy,
          onSend: intent == null ? null : () => unawaited(_onSend(intent)),
        ),
      ],
    );
  }
}

/// What one Send sends.
@immutable
class _Intent {
  const new({
    required this.code,
    required this.quantity,
    required this.recipients,
    required this.source,
  });

  final String code;
  final int quantity;
  final List<String> recipients;
  final LiveGiftSource source;

  /// Same key, same intent: a lost answer's retry reuses its `clientId`.
  String get key =>
      '${source.name}|$code|$quantity|${([...recipients]..sort()).join(',')}';
}

class _Cell {
  const new(this.gift, {this.bagQuantity});

  final Gift gift;

  /// How many the bag holds (bag tab only).
  final int? bagQuantity;
}

/// The recipients row: the host (Host chip) and the people on the mic,
/// each a picture that is selected with a gold ring and a check; "All" at
/// the end when there is more than one.
class _Recipients extends StatelessWidget {
  const new({
    required this.candidates,
    required this.host,
    required this.chosen,
    required this.allOn,
    required this.showAll,
    required this.onTap,
    required this.onAll,
  });

  final List<UserSummary> candidates;
  final UserSummary host;
  final Set<String> chosen;
  final bool allOn;
  final bool showAll;
  final ValueChanged<String> onTap;
  final VoidCallback onAll;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.textStyles;
    if (candidates.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 64,
      child: Row(
        children: [
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: KSpacing.md),
              children: [
                for (final u in candidates)
                  _Person(
                    key: KLiveGiftSheet.recipientKey(u.username),
                    user: u,
                    isHost: u.id == host.id,
                    selected: chosen.contains(u.username),
                    onTap: () => onTap(u.username),
                  ),
              ],
            ),
          ),
          if (showAll)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: KSpacing.md),
              child: Center(
                child: Semantics(
                  button: true,
                  toggled: allOn,
                  label: l10n.liveGiftAllOnMicSemantics,
                  excludeSemantics: true,
                  child: InkWell(
                    key: KLiveGiftSheet.allKey,
                    onTap: onAll,
                    borderRadius: BorderRadius.circular(KRadius.pill),
                    child: AnimatedContainer(
                      duration: KMotion.of(context, KMotion.fast),
                      constraints: const BoxConstraints(minHeight: 32),
                      padding: const EdgeInsets.symmetric(
                        horizontal: KSpacing.md,
                        vertical: KSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(KRadius.pill),
                        gradient: allOn
                            ? const LinearGradient(
                                colors: KBrandColors.gradientLive,
                              )
                            : null,
                        border: allOn
                            ? null
                            : Border.all(color: const Color(0x33FFFFFF)),
                      ),
                      child: Text(
                        l10n.liveGiftAllOnMic,
                        style: text.label.copyWith(color: _Sheet.white),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Person extends StatelessWidget {
  const new({
    required this.user,
    required this.isHost,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final UserSummary user;
  final bool isHost;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.textStyles;
    return Semantics(
      button: true,
      selected: selected,
      label: isHost
          ? '${user.displayName}, ${l10n.liveGiftHost}'
          : user.displayName,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 30,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: KSpacing.xs),
          child: SizedBox(
            width: 48,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                AnimatedContainer(
                  duration: KMotion.of(context, KMotion.fast),
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected
                          ? KBrandColors.gold
                          : const Color(0x00000000),
                      width: 2,
                    ),
                  ),
                  child: Opacity(
                    opacity: selected ? 1 : 0.55,
                    child: KAvatar(
                      name: user.displayName,
                      imageUrl: user.avatarUrl,
                      size: 40,
                    ),
                  ),
                ),
                if (selected)
                  const PositionedDirectional(
                    top: 0,
                    end: 0,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: KBrandColors.gold,
                        shape: BoxShape.circle,
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(1),
                        child: Icon(
                          Icons.check_rounded,
                          size: 12,
                          color: KStatusColors.onStatus,
                        ),
                      ),
                    ),
                  ),
                PositionedDirectional(
                  bottom: 0,
                  start: -KSpacing.xs,
                  end: -KSpacing.xs,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: KSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: isHost
                            ? KBrandColors.red500
                            : const Color(0xCC000000),
                        borderRadius: BorderRadius.circular(KRadius.pill),
                      ),
                      child: Text(
                        isHost ? l10n.liveGiftHost : user.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.caption.copyWith(
                          color: _Sheet.white,
                          fontSize: 9,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const new({required this.tabs, required this.selected, required this.onTap});

  final List<String> tabs;
  final String selected;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.textStyles;
    String label(String id) => switch (id) {
      KLiveGiftSheet.bagTab => l10n.liveGiftTabBag,
      _ => switch (GiftCategory.fromWire(id)) {
        GiftCategory.popular => l10n.liveGiftTabPopular,
        GiftCategory.event => l10n.liveGiftTabEvent,
        GiftCategory.fun => l10n.liveGiftTabFun,
        null => id,
      },
    };
    // The four tabs always fit (a long label shrinks), so none hides
    // off-screen.
    return SizedBox(
      height: 40,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: KSpacing.sm),
        child: Row(
          children: [
            for (final id in tabs)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: id == selected,
                  child: InkWell(
                    key: KLiveGiftSheet.tabKey(id),
                    onTap: () => onTap(id),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: KSpacing.xs,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              label(id),
                              maxLines: 1,
                              style: text.label.copyWith(
                                color: id == selected
                                    ? _Sheet.white
                                    : _Sheet.muted,
                                fontWeight: id == selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(height: KSpacing.xxs),
                          AnimatedContainer(
                            duration: KMotion.of(context, KMotion.fast),
                            width: id == selected ? 18 : 0,
                            height: 3,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(KRadius.pill),
                              gradient: const LinearGradient(
                                colors: KBrandColors.gradientLive,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GiftTile extends StatelessWidget {
  const new({
    required this.cell,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final _Cell cell;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.textStyles;
    final gift = cell.gift;
    final price = KFormat.grouped(gift.priceCoins);
    final bagQuantity = cell.bagQuantity;
    final badge = switch (gift.badge) {
      GiftBadge.isNew => (
        l10n.liveGiftBadgeNew,
        const [KBrandColors.red400, KBrandColors.red500],
      ),
      GiftBadge.event => (
        l10n.liveGiftBadgeEvent,
        const [_Sheet.eventPink, KBrandColors.red400],
      ),
      GiftBadge.none => null,
    };
    return Semantics(
      button: true,
      selected: selected,
      label: [
        l10n.giftCellSemantics(gift.name, price),
        if (badge != null) badge.$1,
        if (bagQuantity != null)
          l10n.liveGiftBagCount(KFormat.grouped(bagQuantity)),
      ].join(', '),
      excludeSemantics: true,
      child: AnimatedScale(
        scale: selected ? 1.04 : 1,
        duration: KMotion.of(context, KMotion.fast),
        child: Material(
          color: selected ? _Sheet.cellSelected : _Sheet.cell,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(KRadius.md),
            side: BorderSide(
              color: selected ? KBrandColors.gold : const Color(0x00000000),
              width: KMetrics.thinStroke,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      KSpacing.xxs,
                      KSpacing.md,
                      KSpacing.xxs,
                      KSpacing.xs,
                    ),
                    child: LayoutBuilder(
                      builder: (context, box) => FittedBox(
                        fit: BoxFit.scaleDown,
                        child: SizedBox(
                          width: box.maxWidth,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              KGiftImage(gift.assetKey, size: 44),
                              const SizedBox(height: KSpacing.xxs),
                              Text(
                                gift.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: text.caption.copyWith(
                                  color: _Sheet.white,
                                  fontSize: 11,
                                ),
                              ),
                              // A long price shrinks instead of
                              // overflowing (large text).
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const KabsoArtIcon(KabsoArt.coin, size: 11),
                                    const SizedBox(width: KSpacing.xxs),
                                    Text(
                                      price,
                                      style: text.caption.copyWith(
                                        color: KBrandColors.gold,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (badge != null)
                  PositionedDirectional(
                    top: KSpacing.xs,
                    end: KSpacing.xs,
                    child: _Pill(label: badge.$1, colors: badge.$2),
                  ),
                if (bagQuantity != null)
                  PositionedDirectional(
                    top: KSpacing.xs,
                    start: KSpacing.xs,
                    child: Text(
                      l10n.giftCombo(bagQuantity),
                      style: text.caption.copyWith(
                        color: _Sheet.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const new({required this.label, required this.colors});

  final String label;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: KSpacing.xs),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(KRadius.pill),
      gradient: LinearGradient(colors: colors),
    ),
    child: Text(
      label,
      style: context.textStyles.caption.copyWith(
        color: _Sheet.white,
        fontSize: 8,
        height: 1.4,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

/// The coin balance (tap: nothing yet, there is no store, B5), the
/// quantity and Send (gradient; a spinner while sending; ×N while a combo
/// goes on).
class _BottomBar extends ConsumerWidget {
  const new({
    required this.quantities,
    required this.quantity,
    required this.onQuantity,
    required this.combo,
    required this.busy,
    required this.onSend,
  });

  final List<int> quantities;
  final int quantity;
  final ValueChanged<int> onQuantity;
  final int combo;
  final bool busy;
  final VoidCallback? onSend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final text = context.textStyles;
    final coins = ref.watch(liveCoinsProvider).value;
    final balance = coins == null ? null : KFormat.grouped(coins);
    final enabled = onSend != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        KSpacing.md,
        KSpacing.sm,
        KSpacing.md,
        KSpacing.sm,
      ),
      child: Row(
        children: [
          Flexible(
            child: Semantics(
              label: balance == null ? null : l10n.liveGiftBalance(balance),
              excludeSemantics: true,
              child: Container(
                key: KLiveGiftSheet.balanceKey,
                padding: const EdgeInsetsDirectional.fromSTEB(
                  KSpacing.xs,
                  KSpacing.xxs,
                  KSpacing.sm,
                  KSpacing.xxs,
                ),
                decoration: BoxDecoration(
                  color: const Color(0x14FFFFFF),
                  borderRadius: BorderRadius.circular(KRadius.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const KabsoArtIcon(KabsoArt.coin, size: 20),
                    const SizedBox(width: KSpacing.xs),
                    if (balance != null)
                      Flexible(
                        child: Text(
                          balance,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.label.copyWith(color: KBrandColors.gold),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const Spacer(),
          if (combo > 1) ...[
            KGiftComboCounter(key: KLiveGiftSheet.comboKey, count: combo),
            const SizedBox(width: KSpacing.sm),
          ],
          Semantics(
            label: l10n.liveGiftQuantity(KFormat.grouped(quantity)),
            button: true,
            excludeSemantics: true,
            child: PopupMenuButton<int>(
              key: KLiveGiftSheet.quantityKey,
              initialValue: quantity,
              onSelected: onQuantity,
              color: _Sheet.cell,
              position: PopupMenuPosition.over,
              itemBuilder: (context) => [
                for (final q in quantities)
                  PopupMenuItem<int>(
                    key: KLiveGiftSheet.quantityOptionKey(q),
                    value: q,
                    child: Text(
                      l10n.giftCombo(q),
                      style: text.label.copyWith(
                        color: q == quantity ? KBrandColors.gold : _Sheet.white,
                      ),
                    ),
                  ),
              ],
              child: Container(
                height: 36,
                padding: const EdgeInsetsDirectional.only(
                  start: KSpacing.md,
                  end: KSpacing.xs,
                ),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadiusDirectional.horizontal(
                    start: Radius.circular(KRadius.pill),
                  ),
                  border: Border.all(color: const Color(0x33FFFFFF)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.giftCombo(quantity),
                      style: text.label.copyWith(color: _Sheet.white),
                    ),
                    const Icon(
                      Icons.arrow_drop_up_rounded,
                      color: _Sheet.white,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Semantics(
            button: true,
            enabled: enabled,
            label: l10n.giftSend,
            excludeSemantics: true,
            child: GestureDetector(
              key: KLiveGiftSheet.sendKey,
              onTap: onSend,
              behavior: HitTestBehavior.opaque,
              // 48 dp to tap, 36 dp to see.
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: AnimatedOpacity(
                  opacity: enabled ? 1 : 0.4,
                  duration: KMotion.of(context, KMotion.fast),
                  child: Container(
                    height: 36,
                    constraints: const BoxConstraints(minWidth: 76),
                    padding: const EdgeInsets.symmetric(
                      horizontal: KSpacing.md,
                    ),
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      borderRadius: BorderRadiusDirectional.horizontal(
                        end: Radius.circular(KRadius.pill),
                      ),
                      gradient: LinearGradient(
                        colors: KBrandColors.gradientLive,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (busy) ...[
                          const SizedBox.square(
                            dimension: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _Sheet.white,
                            ),
                          ),
                          const SizedBox(width: KSpacing.xs),
                        ],
                        Text(
                          l10n.giftSend,
                          style: text.label.copyWith(
                            color: _Sheet.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
