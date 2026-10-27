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
import 'package:kabso_live/features/live/data/gift_art_cache.dart';
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

/// The live gift panel (CP-020, §10.23). D117: the owner's reference
/// layout with its measured sizes (at 430 × 932; third-party, outside git)
/// and Kabso's own art: who receives (the host with a Host label and the
/// people on the mic, several at once; "All" after a divider), the tabs
/// شائعة / مناسبات / مرح from the catalogue (a caret when the tab has
/// sub-categories) and الحقيبة (the gift bag, an icon at the end), the
/// sub-category chips ("All" plus the open tab's tags, only when it has
/// some), a 4-column grid without cards, and over its bottom the coin
/// balance, the quantity and Send.
///
/// Every send has its own `clientId`; a send whose answer was lost is sent
/// again with the same one (never charged twice). Quick taps on Send queue
/// more sends (the server counts the combo; the panel shows ×N). The
/// balance and the bag follow each answer. Nothing is invented: an empty
/// catalogue shows "No gifts yet".
///
/// D128 (owner): the host, or someone seated, may send to themself (they
/// are among the recipients); Send is never silent — a tap while it is
/// dimmed, and every refused send, shows a message over the grid as well
/// as the line above the bar.
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

  /// The short message over the grid (D128): why Send did nothing, or why
  /// a send was refused. It goes by itself after [toastTime].
  static const toastKey = Key('gift.toast');
  static const toastTime = Duration(seconds: 3);
  static Key tabKey(String id) => Key('gift.tab.$id');
  static Key cellKey(String code, {bool bag = false}) =>
      Key('gift.${bag ? 'bag' : 'cell'}.$code');
  static Key recipientKey(String username) => Key('gift.recipient.$username');

  /// A sub-category chip (D117); null: "All".
  static Key tagKey(String? code) =>
      code == null ? const Key('gift.tags.all') : Key('gift.tag.$code');
  static Key quantityOptionKey(int quantity) => Key('gift.quantity.$quantity');

  /// The id of the bag tab (the others are the category wire values).
  static const bagTab = 'BAG';

  @override
  ConsumerState<KLiveGiftSheet> createState() => _KLiveGiftSheetState();
}

/// The panel's colours and sizes, measured on the owner's reference (D117;
/// logical px at 430 × 932). "Estimate" marks a value the reference does
/// not show (a state it is not in).
abstract final class _Sheet {
  static const background = Color(0xFF1A1621);
  static const white = Color(0xFFFFFFFF);

  /// Unselected tabs, carets and chip labels.
  static const muted = Color(0xFF78767E);
  static const name = Color(0xFFA8A5AC);
  static const price = Color(0xFF7B777F);
  static const bagIcon = Color(0xFFBEBCC1);
  static const label = Color(0xFF47474C);
  static const chipOn = Color(0xFF3B3D45);
  static const chipBorder = Color(0xFF36323E);
  static const divider = Color(0xFF342F3C);
  static const pill = Color(0xFF2A2834);
  static const countOff = Color(0xFF76747C);
  static const countTextOff = Color(0xFF1E5B60);
  static const sendOff = Color(0xFF1A7F7F);
  static const sendTextOff = Color(0x59FFFFFF);

  /// Estimates: the reference shows Send disabled only.
  static const count = Color(0xFFA9A7AC);
  static const countText = Color(0xFF167D7D);
  static const send = Color(0xFF0FB9B2);
  static const newBadge = Color(0xFFB23C5E);
  static const newText = Color(0xFF3D0A17);
  static const eventBadge = Color(0xFFBA345D);

  /// Estimate: the reference shows no selected gift.
  static const cellSelected = Color(0xFF2A2834);

  /// The panel is 48 % of the screen (447.5 of 932), corners 24.
  static const double height = 0.48;
  static const double radius = 24;
  static const double edge = 7;
  static const double cellHeight = 100;
}

class _KLiveGiftSheetState extends ConsumerState<KLiveGiftSheet> {
  String? _tab;
  String? _selected;

  /// The chosen sub-category of the open tab; null: All (D117).
  String? _tag;
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

  /// The message shown over the grid (D128: a Send never does nothing
  /// silently), and its timer.
  String? _toast;
  Timer? _toastTimer;

  /// The combo count of the last answer, shown from 2 while it lasts.
  int _combo = 0;
  Timer? _comboTimer;

  LiveGiftRoom get room => widget.room;

  /// The catalogue version whose small animations were prefetched (D126).
  String? _prefetched;

  @override
  void initState() {
    super.initState();
    // The panel opened: fetch the small hosted animations now, so they
    // play at once when sent; big ones wait until a gift is sent.
    ref.listenManual(giftCatalogueProvider, (_, next) {
      final catalogue = next.value;
      if (catalogue == null || catalogue.version == _prefetched) return;
      _prefetched = catalogue.version;
      GiftArtCache.instance.prefetchSmallAnimations(catalogue);
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _comboTimer?.cancel();
    _toastTimer?.cancel();
    super.dispose();
  }

  /// Who may receive: the host and the people on a seat — the caller too
  /// when they are one of them (D128, owner: "the host can support
  /// himself"; a seated guest likewise). A viewer off the mic is not listed.
  List<UserSummary> _candidates() {
    final seen = <String>{};
    return [
      for (final u in [room.host, ...room.seated(ref)])
        if (seen.add(u.username)) u,
    ];
  }

  /// Shows [message] over the grid for [KLiveGiftSheet.toastTime] (D128).
  void _showToast(String message) {
    _toastTimer?.cancel();
    _toastTimer = Timer(KLiveGiftSheet.toastTime, () {
      if (mounted) setState(() => _toast = null);
    });
    setState(() => _toast = message);
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
      _showToast(message);
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
            clipBehavior: Clip.antiAlias,
            decoration: const BoxDecoration(
              color: _Sheet.background,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(_Sheet.radius),
              ),
            ),
            child: _body(context),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final l10n = context.l10n;
    final me = ref.watch(currentUserProvider);
    if (me == null) {
      return SafeArea(
        top: false,
        child: Center(
          child: KEmptyState(
            key: KLiveGiftSheet.emptyKey,
            icon: Icons.card_giftcard_rounded,
            title: l10n.liveGiftSignIn,
            message: l10n.liveGiftEmptyMessage,
            compact: true,
          ),
        ),
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

    final candidates = _candidates();
    final max = catalogue?.maxRecipients ?? 25;
    final names = {for (final c in candidates) c.username};
    final chosen = (_chosen ?? _defaultChosen(candidates)).intersection(names);
    final allOn =
        candidates.length > 1 && chosen.length == candidates.take(max).length;

    // The gifts of this tab, its sub-categories (D117) and the selected one.
    final tabCells = <_Cell>[
      if (isBag)
        for (final item in bagAsync?.value ?? const <GiftBagItem>[])
          _Cell(item.gift, bagQuantity: item.quantity)
      else if (catalogue != null)
        for (final g in catalogue.of(GiftCategory.fromWire(tab)!)) _Cell(g),
    ];
    final tags = giftTags([for (final c in tabCells) c.gift]);
    final tag = tags.any((t) => t.code == _tag) ? _tag : null;
    final cells = [
      for (final c in tabCells)
        if (tag == null || c.gift.tag?.code == tag) c,
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
    // The reference's own state (nothing picked yet) shows no line: Send
    // is dimmed and says why to screen readers. Every other reason and
    // every error is shown.
    final line =
        _error ??
        (reason == l10n.liveGiftEmptyTitle || reason == l10n.liveGiftPickGift
            ? null
            : reason);

    final bottomInset = MediaQuery.paddingOf(context).bottom;
    // The grid ends at the bar (the reference cuts its third row there).
    const barHeight = 32.0;
    const barGap = 8.0;

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
          _Sheet.edge,
          8,
          _Sheet.edge,
          KSpacing.sm,
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: KSizes.giftGridColumns,
          mainAxisExtent: _Sheet.cellHeight,
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
        const SizedBox(height: 7.5),
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
              KSpacing.md,
              KSpacing.xxs,
              KSpacing.md,
              0,
            ),
            child: Text(
              notOnMic,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.textStyles.caption.copyWith(color: _Sheet.muted),
            ),
          ),
        const SizedBox(height: 9),
        _Tabs(
          tabs: tabs,
          selected: tab,
          hasTags: (id) => switch (GiftCategory.fromWire(id)) {
            final c? => catalogue?.tagsOf(c).isNotEmpty ?? false,
            null => false,
          },
          onTap: (id) => setState(() {
            _tab = id;
            _tag = null;
            _selected = null;
            _error = null;
            _resetCombo();
          }),
        ),
        if (tags.isNotEmpty) ...[
          const SizedBox(height: 5.9),
          _TagChips(
            tags: tags,
            selected: tag,
            onTap: (code) => setState(() {
              _tag = code;
              _selected = null;
              _error = null;
              _resetCombo();
            }),
          ),
        ],
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(child: grid),
              if (_toast case final toast?)
                PositionedDirectional(
                  start: KSpacing.md,
                  end: KSpacing.md,
                  bottom: KSpacing.sm,
                  child: _Toast(key: KLiveGiftSheet.toastKey, message: toast),
                ),
            ],
          ),
        ),
        if (line != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              KSpacing.md,
              0,
              KSpacing.md,
              KSpacing.xs,
            ),
            child: Text(
              line,
              key: KLiveGiftSheet.reasonKey,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.textStyles.caption.copyWith(
                color: _error != null ? KPalette.dark.error : _Sheet.bagIcon,
              ),
            ),
          ),
        _BottomBar(
          height: barHeight,
          quantities: quantities,
          quantity: quantity,
          onQuantity: (q) => setState(() {
            _quantity = q;
            _error = null;
            _resetCombo();
          }),
          combo: _combo,
          busy: _busy,
          reason: reason,
          onSend: intent == null ? null : () => unawaited(_onSend(intent)),
          // D128: a tap on a dimmed Send says why instead of doing nothing.
          onBlocked: switch (reason) {
            final why? => () => _showToast(why),
            null => null,
          },
        ),
        SizedBox(height: bottomInset + barGap),
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

/// The recipients row (29 high): the host (a "Host" label) and the people
/// on the mic, each a picture, full when selected and dimmed when not; when
/// there is more than one, a divider and the "All" toggle at the end.
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
    if (candidates.isEmpty) return const SizedBox(height: _Person.size);
    return SizedBox(
      height: _Person.size,
      child: Row(
        children: [
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsetsDirectional.only(start: 12.6),
              itemCount: candidates.length,
              separatorBuilder: (_, _) => const SizedBox(width: KSpacing.sm),
              itemBuilder: (context, i) {
                final u = candidates[i];
                return _Person(
                  key: KLiveGiftSheet.recipientKey(u.username),
                  user: u,
                  isHost: u.id == host.id,
                  selected: chosen.contains(u.username),
                  onTap: () => onTap(u.username),
                );
              },
            ),
          ),
          if (showAll) ...[
            const SizedBox(
              width: 0.5,
              height: 9.3,
              child: ColoredBox(color: _Sheet.divider),
            ),
            const SizedBox(width: 24.7),
            Semantics(
              button: true,
              toggled: allOn,
              label: l10n.liveGiftAllOnMicSemantics,
              excludeSemantics: true,
              child: GestureDetector(
                key: KLiveGiftSheet.allKey,
                onTap: onAll,
                behavior: HitTestBehavior.opaque,
                // The toggle is 16 high; the tap area is the row.
                child: SizedBox(
                  height: _Person.size,
                  child: Center(
                    child: AnimatedContainer(
                      duration: KMotion.of(context, KMotion.fast),
                      height: 16.3,
                      constraints: const BoxConstraints(minWidth: 39.1),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: allOn ? _Sheet.chipOn : null,
                        borderRadius: BorderRadius.circular(KRadius.pill),
                        border: allOn
                            ? null
                            : Border.all(color: _Sheet.chipBorder),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          l10n.liveGiftAllOnMic,
                          maxLines: 1,
                          style: text.caption.copyWith(
                            color: allOn ? _Sheet.white : _Sheet.muted,
                            fontSize: 10,
                            height: 1.2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 23.8),
          ],
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

  /// The picture: 29 (reference 28.9), the label its lowest 11.
  static const double size = 29;

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
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedOpacity(
          duration: KMotion.of(context, KMotion.fast),
          opacity: selected ? 1 : 0.45,
          child: SizedBox.square(
            dimension: size,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                KAvatar(
                  name: user.displayName,
                  imageUrl: user.avatarUrl,
                  size: size,
                ),
                PositionedDirectional(
                  start: 0,
                  end: 0,
                  bottom: 0,
                  child: Container(
                    height: 11.2,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 1.5),
                    decoration: BoxDecoration(
                      color: _Sheet.label,
                      borderRadius: BorderRadius.circular(KRadius.pill),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        isHost ? l10n.liveGiftHost : user.displayName,
                        maxLines: 1,
                        style: text.caption.copyWith(
                          color: _Sheet.white,
                          fontSize: 9.6,
                          height: 1.1,
                          fontWeight: FontWeight.w700,
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

/// The tabs: the catalogue's tabs from the reading start (14 bold white
/// when open, 13.5 grey otherwise, a caret when the tab has sub-categories,
/// a short white line under the open one) and the bag as an icon at the
/// end.
class _Tabs extends StatelessWidget {
  const new({
    required this.tabs,
    required this.selected,
    required this.hasTags,
    required this.onTap,
  });

  final List<String> tabs;
  final String selected;
  final bool Function(String id) hasTags;
  final ValueChanged<String> onTap;

  static const double height = 32;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    String label(String id) => switch (GiftCategory.fromWire(id)) {
      GiftCategory.popular => l10n.liveGiftTabPopular,
      GiftCategory.event => l10n.liveGiftTabEvent,
      GiftCategory.fun => l10n.liveGiftTabFun,
      null => id,
    };
    final categories = [
      for (final id in tabs)
        if (id != KLiveGiftSheet.bagTab) id,
    ];
    final bag = tabs.contains(KLiveGiftSheet.bagTab);
    return SizedBox(
      height: height,
      child: Row(
        children: [
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsetsDirectional.only(start: 24.7, end: 12),
              itemCount: categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 26),
              itemBuilder: (context, i) {
                final id = categories[i];
                return _Tab(
                  key: KLiveGiftSheet.tabKey(id),
                  label: label(id),
                  selected: id == selected,
                  caret: hasTags(id),
                  onTap: () => onTap(id),
                );
              },
            ),
          ),
          if (bag)
            _Tab(
              key: KLiveGiftSheet.tabKey(KLiveGiftSheet.bagTab),
              label: l10n.liveGiftTabBag,
              icon: Icons.inventory_2_outlined,
              selected: selected == KLiveGiftSheet.bagTab,
              onTap: () => onTap(KLiveGiftSheet.bagTab),
            ),
          const SizedBox(width: 14),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const new({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
    this.caret = false,
    this.icon,
  });

  final String label;
  final bool selected;
  final bool caret;

  /// Shown instead of the label (the bag), which stays for screen readers.
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = context.textStyles;
    final color = selected
        ? _Sheet.white
        : (icon != null ? _Sheet.bagIcon : _Sheet.muted);
    final Widget content;
    if (icon case final icon?) {
      content = Icon(icon, size: 19, color: color);
    } else {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            style: text.label.copyWith(
              color: color,
              fontSize: selected ? 14.4 : 13.5,
              height: 1.21,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
          if (caret) ...[
            const SizedBox(width: 4.7),
            CustomPaint(
              size: const Size(7, 4.2),
              painter: _CaretPainter(color: color, up: selected),
            ),
          ],
        ],
      );
    }
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Center(child: content),
            PositionedDirectional(
              start: 0,
              end: 0,
              bottom: 4.8,
              child: Center(
                child: AnimatedContainer(
                  duration: KMotion.of(context, KMotion.fast),
                  width: selected ? 8.9 : 0,
                  height: 2.3,
                  decoration: BoxDecoration(
                    color: _Sheet.white,
                    borderRadius: BorderRadius.circular(KRadius.pill),
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

/// A small filled triangle: up on the open tab, down otherwise.
class _CaretPainter extends CustomPainter {
  const new({required this.color, required this.up});

  final Color color;
  final bool up;

  @override
  void paint(Canvas canvas, Size size) {
    final path = up
        ? (Path()
            ..moveTo(0, size.height)
            ..lineTo(size.width / 2, 0)
            ..lineTo(size.width, size.height))
        : (Path()
            ..moveTo(0, 0)
            ..lineTo(size.width / 2, size.height)
            ..lineTo(size.width, 0));
    canvas.drawPath(
      path..close(),
      Paint()
        ..color = color
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CaretPainter old) => old.color != color || old.up != up;
}

/// The sub-category chips (D117): "All", then the open tab's tags; 24 high,
/// the chosen one filled, the others outlined.
class _TagChips extends StatelessWidget {
  const new({required this.tags, required this.selected, required this.onTap});

  final List<GiftTag> tags;
  final String? selected;
  final ValueChanged<String?> onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.textStyles;
    Widget chip(String? code, String label) {
      final on = code == selected;
      return GestureDetector(
        key: KLiveGiftSheet.tagKey(code),
        onTap: () => onTap(code),
        behavior: HitTestBehavior.opaque,
        child: Semantics(
          button: true,
          selected: on,
          child: AnimatedContainer(
            duration: KMotion.of(context, KMotion.fast),
            height: 24,
            padding: const EdgeInsets.symmetric(horizontal: 9),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on ? _Sheet.chipOn : null,
              borderRadius: BorderRadius.circular(KRadius.pill),
              border: Border.all(color: on ? _Sheet.chipOn : _Sheet.chipBorder),
            ),
            child: Text(
              label,
              maxLines: 1,
              style: text.label.copyWith(
                color: on ? _Sheet.white : _Sheet.muted,
                fontSize: 12.8,
                height: 1.21,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    }

    return Semantics(
      container: true,
      label: l10n.liveGiftTagsSemantics,
      child: SizedBox(
        height: 24,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsetsDirectional.only(start: 12.1, end: 12.1),
          children: [
            chip(null, l10n.liveGiftTagAll),
            for (final t in tags) ...[
              const SizedBox(width: 10),
              chip(t.code, t.name),
            ],
          ],
        ),
      ),
    );
  }
}

/// One gift: no card; the art (52), the name (grey, 9.6) and the price
/// (coin and number, 9.6) centred; the badge in the top end corner. The
/// selected gift gets a soft rounded background and a thin teal edge.
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
    // Digits without separators, as in the reference (D117).
    final price = gift.priceCoins.toString();
    final bagQuantity = cell.bagQuantity;
    final badge = switch (gift.badge) {
      GiftBadge.isNew => (
        l10n.liveGiftBadgeNew.toUpperCase(),
        _Sheet.newBadge,
        _Sheet.newText,
      ),
      GiftBadge.event => (
        l10n.liveGiftBadgeEvent,
        _Sheet.eventBadge,
        _Sheet.white,
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
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: KMotion.of(context, KMotion.fast),
          decoration: BoxDecoration(
            color: selected ? _Sheet.cellSelected : null,
            borderRadius: BorderRadius.circular(KRadius.md),
            border: Border.all(
              color: selected ? _Sheet.send : const Color(0x00000000),
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(2, 10, 2, 0),
                  child: Column(
                    children: [
                      KGiftImage(
                        gift.assetKey,
                        imageUrl: gift.imageUrl,
                        size: 52,
                      ),
                      const SizedBox(height: 3.7),
                      Text(
                        gift.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: text.caption.copyWith(
                          color: _Sheet.name,
                          fontSize: 9.6,
                          height: 1.21,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 1.4),
                      // A long price shrinks instead of overflowing.
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const KabsoArtIcon(KabsoArt.coin, size: 9),
                              const SizedBox(width: 3.8),
                              Text(
                                price,
                                style: text.caption.copyWith(
                                  color: _Sheet.price,
                                  fontSize: 9.6,
                                  height: 1.21,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (badge != null)
                PositionedDirectional(
                  top: 3.2,
                  end: 3.9,
                  child: _Badge(
                    label: badge.$1,
                    color: badge.$2,
                    textColor: badge.$3,
                  ),
                ),
              if (bagQuantity != null)
                PositionedDirectional(
                  top: 4.2,
                  start: 4.8,
                  child: Text(
                    l10n.giftCombo(bagQuantity),
                    style: text.caption.copyWith(
                      color: _Sheet.white,
                      fontSize: 9.6,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The message over the grid's bottom (D128): an error icon and the text,
/// on the panel's pill colour; screen readers hear it at once.
class _Toast extends StatelessWidget {
  const new({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    container: true,
    child: Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KSpacing.md,
        vertical: KSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: _Sheet.pill,
        borderRadius: BorderRadius.circular(KRadius.md),
        border: Border.all(color: _Sheet.chipBorder),
      ),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Icon(
              Icons.error_outline,
              size: 18,
              color: KPalette.dark.error,
            ),
          ),
          const SizedBox(width: KSpacing.sm),
          Expanded(
            child: Text(
              message,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: context.textStyles.label.copyWith(color: _Sheet.white),
            ),
          ),
        ],
      ),
    ),
  );
}

/// The corner badge: 11.2 high, radius 2, bold 6.8 (condensed).
class _Badge extends StatelessWidget {
  const new({
    required this.label,
    required this.color,
    required this.textColor,
  });

  final String label;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) => Container(
    height: 11.2,
    padding: const EdgeInsets.symmetric(horizontal: 1.5),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(2),
    ),
    child: Text(
      label,
      maxLines: 1,
      style: context.textStyles.caption.copyWith(
        color: textColor,
        fontSize: 6.8,
        height: 1.2,
        letterSpacing: -0.4,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

/// Over the grid's bottom: the coin balance at the reading start, then at
/// the end one dark pill with the quantity (a circle; tap: the quantities)
/// and Send (teal, dimmed until a gift and a recipient are picked; a
/// spinner while sending; ×N while a combo goes on, before the pill). There
/// is no store yet (B5), so the balance opens nothing.
class _BottomBar extends ConsumerWidget {
  const new({
    required this.height,
    required this.quantities,
    required this.quantity,
    required this.onQuantity,
    required this.combo,
    required this.busy,
    required this.reason,
    required this.onSend,
    this.onBlocked,
  });

  final double height;
  final List<int> quantities;
  final int quantity;
  final ValueChanged<int> onQuantity;
  final int combo;
  final bool busy;

  /// Why Send is off (screen readers), or null.
  final String? reason;
  final VoidCallback? onSend;

  /// A tap while Send is dimmed (says [reason]).
  final VoidCallback? onBlocked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final text = context.textStyles;
    final coins = ref.watch(liveCoinsProvider).value;
    final balance = coins == null ? null : KFormat.grouped(coins);
    final enabled = onSend != null;
    final count = KFormat.grouped(quantity);
    return SizedBox(
      height: height,
      child: Row(
        children: [
          const SizedBox(width: 12.1),
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Semantics(
                label: balance == null ? null : l10n.liveGiftBalance(balance),
                excludeSemantics: true,
                child: Row(
                  key: KLiveGiftSheet.balanceKey,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const KabsoArtIcon(KabsoArt.coin, size: 18.6),
                    const SizedBox(width: 4.7),
                    if (balance != null)
                      Flexible(
                        child: Text(
                          balance,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.label.copyWith(
                            color: _Sheet.white,
                            fontSize: 14.7,
                            height: 1.21,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (combo > 1) ...[
            KGiftComboCounter(key: KLiveGiftSheet.comboKey, count: combo),
            const SizedBox(width: KSpacing.sm),
          ],
          Container(
            height: height,
            padding: const EdgeInsetsDirectional.only(start: 6),
            decoration: BoxDecoration(
              color: _Sheet.pill,
              borderRadius: BorderRadius.circular(height / 2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  label: l10n.liveGiftQuantity(count),
                  button: true,
                  excludeSemantics: true,
                  child: PopupMenuButton<int>(
                    key: KLiveGiftSheet.quantityKey,
                    initialValue: quantity,
                    onSelected: onQuantity,
                    color: _Sheet.pill,
                    position: PopupMenuPosition.over,
                    padding: EdgeInsets.zero,
                    itemBuilder: (context) => [
                      for (final q in quantities)
                        PopupMenuItem<int>(
                          key: KLiveGiftSheet.quantityOptionKey(q),
                          value: q,
                          child: Text(
                            l10n.giftCombo(q),
                            style: text.label.copyWith(
                              color: q == quantity ? _Sheet.send : _Sheet.white,
                            ),
                          ),
                        ),
                    ],
                    child: AnimatedContainer(
                      duration: KMotion.of(context, KMotion.fast),
                      height: 22,
                      constraints: const BoxConstraints(minWidth: 22),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: enabled ? _Sheet.count : _Sheet.countOff,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          count,
                          maxLines: 1,
                          style: text.label.copyWith(
                            color: enabled
                                ? _Sheet.countText
                                : _Sheet.countTextOff,
                            fontSize: 14.7,
                            height: 1.21,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Semantics(
                  button: true,
                  enabled: enabled,
                  label: l10n.giftSend,
                  hint: enabled ? null : reason,
                  excludeSemantics: true,
                  child: GestureDetector(
                    key: KLiveGiftSheet.sendKey,
                    onTap: onSend ?? onBlocked,
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedContainer(
                      duration: KMotion.of(context, KMotion.fast),
                      height: height,
                      constraints: const BoxConstraints(minWidth: 70.4),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: enabled ? _Sheet.send : _Sheet.sendOff,
                        borderRadius: BorderRadius.circular(height / 2),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (busy) ...[
                            const SizedBox.square(
                              dimension: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _Sheet.white,
                              ),
                            ),
                            const SizedBox(width: KSpacing.xs),
                          ],
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                l10n.giftSend,
                                maxLines: 1,
                                style: text.label.copyWith(
                                  color: enabled
                                      ? _Sheet.white
                                      : _Sheet.sendTextOff,
                                  fontSize: 14.7,
                                  height: 1.21,
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
              ],
            ),
          ),
          const SizedBox(width: 11.6),
        ],
      ),
    );
  }
}
