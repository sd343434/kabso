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
import 'package:kabso_live/features/levels/application/levels_providers.dart';
import 'package:kabso_live/features/levels/domain/level_models.dart';
import 'package:kabso_live/features/levels/presentation/level_badge.dart';
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

  /// D135: a gift cell's picture.
  static Key giftImageKey(String code) => Key('gift.image.$code');
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

  /// D131: the Recent tab (gifts sent from this phone).
  static const recentTab = 'RECENT';
  static const priceSortKey = Key('gift.priceSort');
  static const wealthKey = Key('gift.wealth');

  /// D132: lucky gifts.
  static const luckyOddsKey = Key('gift.lucky.odds');
  static const luckyBlockedKey = Key('gift.lucky.blocked');
  static const oddsSheetKey = Key('gift.lucky.oddsSheet');
  static const ageDialogKey = Key('gift.lucky.age');
  static const ageConfirmKey = Key('gift.lucky.ageConfirm');
  static Key oddsRowKey(int multiplier) => Key('gift.lucky.odds.$multiplier');

  @override
  ConsumerState<KLiveGiftSheet> createState() => _KLiveGiftSheetState();
}

/// The panel's colours and sizes. D131: measured on ref 161 (393 pt,
/// third-party, outside git); "E" marks an estimate.
abstract final class _Sheet {
  /// Ref 161: `#2A282B` at the top → `#221F23` at the bottom.
  static const top = Color(0xFF2A282B);
  static const bottom = Color(0xFF221F23);
  static const white = Color(0xFFFFFFFF);

  /// Unselected tabs, carets and chip labels (`#858487`).
  static const muted = Color(0xFF858487);
  static const name = Color(0xFFAFAEB1);

  /// D135: the price in the bigger cells, a lighter gold-grey that reads
  /// at 10 sp on the panel (≥ 4.5:1 on `#2A282B`).
  static const priceText = Color(0xFFD8C79A);
  static const bagIcon = Color(0xFFBEBCC1);
  static const label = Color(0xFF47474C);
  static const chipOn = Color(0xFF3F4346);
  static const chipBorder = Color(0xFF3D3C3F);
  static const divider = Color(0xFF3D3C3F);
  static const pill = Color(0xFF404747);
  static const track = Color(0xFF47454A);
  static const trackFill = Color(0xFFCFCDD2);
  static const caption = Color(0xFF969699);

  /// The quantity pill: the options (`#A9A7AC`) and the chosen one (a white
  /// circle, teal number `#25C3C7`).
  static const count = Color(0xFFA9A7AC);
  static const countText = Color(0xFF25C3C7);

  /// Send: `#26E4DA` → `#0AD7E3`; dimmed (E) until a gift is picked.
  static const send = [Color(0xFF26E4DA), Color(0xFF0AD7E3)];
  static const sendOff = [Color(0xFF1B7F7C), Color(0xFF16767E)];
  static const sendTextOff = Color(0x8CFFFFFF);
  static const newBadge = Color(0xFFB23C5E);
  static const newText = Color(0xFF3D0A17);
  static const eventBadge = Color(0xFFBA345D);

  /// The selected cell: `#35393A` with a lighter top edge `#3C4345`.
  static const cellSelected = Color(0xFF35393A);
  static const cellEdge = Color(0xFF3C4345);

  /// Ref 161: the panel's top 482.2 pt down an 852 pt screen (369.8 pt
  /// tall); corners ≈ 17–20 pt (E).
  static const double height = 369.8 / 852;
  static const double radius = 18;

  /// 4 columns 95.7 pt apart on 393 pt; cells 91.5 pt tall (E ±1) in the
  /// reference. D135 (owner: "the gifts are small, make them bigger"):
  /// pictures 70 pt (was 54, +30 %), 10 sp names and prices, so cells
  /// 112 pt tall; the panel grows by the two rows' difference so two rows
  /// still show.
  static const double edge = 5.1;
  static const double refCellHeight = 91.5;
  static const double cellHeight = 112;
  static const double giftImage = 70;

  /// The bottom row: the quantity pill and Send 29.4 pt tall, Send
  /// 63.9 pt wide 11.5 pt from the end; 4.5 pt above the home inset.
  static const double barHeight = 29.4;
  static const double sendWidth = 63.9;
  static const double barEnd = 11.5;
  static const double barGap = 4.5;
}

/// D131: the order of the gift list (client-side, ref 161 "Price Sorting").
enum _PriceSort { none, up, down }

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
  bool _toastError = true;
  Timer? _toastTimer;

  /// D131: the price order of the list (client-side).
  _PriceSort _sort = _PriceSort.none;

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
  void _showToast(String message, {bool error = true}) {
    _toastTimer?.cancel();
    _toastTimer = Timer(KLiveGiftSheet.toastTime, () {
      if (mounted) setState(() => _toast = null);
    });
    setState(() {
      _toast = message;
      _toastError = error;
    });
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

  bool _askingAge = false;

  /// One tap on Send: queues a send; sends run one at a time.
  Future<void> _onSend(_Intent intent) async {
    // D132: the one-time 18+ statement before a first lucky gift (before
    // anything is queued; Cancel sends nothing).
    final caller = intent.lucky
        ? ref.read(luckyOddsProvider).value?.caller
        : null;
    if (caller != null && !caller.ageConfirmed) {
      if (_askingAge) return;
      _askingAge = true;
      final ok = await _askAge();
      _askingAge = false;
      if (!ok || !mounted) return;
    }
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

  Future<bool> _sendOnce(_Intent intent, {bool askedAge = false}) async {
    final l10n = context.l10n;
    final asked = askedAge;
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
      // D131: Recent (this phone).
      ref.read(recentGiftsProvider.notifier).add(intent.code);
      if (!mounted) return true;
      // D132: what the draws paid (the balance above already has it).
      if (result.luckyResult case final lucky?) {
        _showToast(
          lucky.coinsWon > 0
              ? l10n.liveLuckyWon(
                  KFormat.bidiIsolate(KFormat.grouped(lucky.coinsWon)),
                  KFormat.grouped(lucky.topMultiplier ?? 0),
                )
              : l10n.liveLuckyNoWin,
          error: false,
        );
      }
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
      // D132: the server asks for the 18+ statement: ask, then send again.
      if (code == ErrorCode.luckyGiftAgeUnconfirmed && !asked) {
        if (await _askAge()) return await _sendOnce(intent, askedAge: true);
        return false;
      }
      if (code == ErrorCode.luckyGiftRegionUnavailable) {
        ref.invalidate(luckyOddsProvider);
      }
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
      // D131: a refused recipient (e.g. a server without D128 refusing the
      // host's gift to themself) says so, not "check the fields".
      final recipientsRefused =
          code == ErrorCode.validationFailed &&
          failure is ServerFailure &&
          failure.details.any((d) => d.field == 'recipients');
      final message = code == ErrorCode.insufficientCoins
          ? l10n.liveGiftNotEnoughCoins
          : recipientsRefused
          ? l10n.liveGiftRecipientRefused
          : failureMessage(l10n, failure);
      setState(() {
        _error = message;
        _resetCombo();
      });
      _showToast(message);
      return false;
    }
  }

  /// D132: asks for the 18+ statement and saves it. True when confirmed.
  Future<bool> _askAge() async {
    if (!await _confirmLuckyAge(context)) return false;
    try {
      await ref.read(liveGiftRepositoryProvider).confirmLuckyAge();
      ref.invalidate(luckyOddsProvider);
      return true;
    } on Object catch (e) {
      if (mounted) {
        final message = failureMessage(context.l10n, toAppFailure(e));
        setState(() => _error = message);
        _showToast(message);
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    var height =
        media.size.height * _Sheet.height +
        2 * (_Sheet.cellHeight - _Sheet.refCellHeight);
    // Several people can receive: their row comes first (ref 161 is a
    // solo live and has none).
    if (_candidates().length > 1) height += _Person.size + 9;
    // Dense room controls: text grows up to the live overlays' limit.
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
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_Sheet.top, _Sheet.bottom],
              ),
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

  /// The ids of the tabs: the catalogue's categories in the reference's
  /// order with Recent after Popular, Lucky only when the catalogue has
  /// lucky gifts, and the bag.
  List<String> _tabsOf(GiftCatalogue? catalogue) {
    final categories = catalogue?.categories ?? GiftCategory.values;
    return [
      if (categories.contains(GiftCategory.popular)) GiftCategory.popular.wire,
      KLiveGiftSheet.recentTab,
      for (final c in categories)
        if (c != GiftCategory.popular &&
            (c != GiftCategory.lucky ||
                (catalogue?.of(GiftCategory.lucky).isNotEmpty ?? false)))
          c.wire,
      KLiveGiftSheet.bagTab,
    ];
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
    final tabs = _tabsOf(catalogue);
    // D131: until the person picks a tab, open on the first one with gifts
    // (staging had one FUN gift: the panel opened on an empty Popular).
    final tab = tabs.contains(_tab)
        ? _tab!
        : catalogue == null
        ? tabs.first
        : tabs.firstWhere(
            (id) => switch (GiftCategory.fromWire(id)) {
              final c? => catalogue.of(c).isNotEmpty,
              null => false,
            },
            orElse: () => tabs.first,
          );
    final isBag = tab == KLiveGiftSheet.bagTab;
    final isRecent = tab == KLiveGiftSheet.recentTab;
    final isLuckyTab = tab == GiftCategory.lucky.wire;
    final bagAsync = isBag ? ref.watch(giftBagProvider) : null;
    final recent = isRecent ? ref.watch(recentGiftsProvider) : const <String>[];

    final candidates = _candidates();
    final max = catalogue?.maxRecipients ?? 25;
    final names = {for (final c in candidates) c.username};
    final chosen = (_chosen ?? _defaultChosen(candidates)).intersection(names);
    final allOn =
        candidates.length > 1 && chosen.length == candidates.take(max).length;

    // The gifts of this tab, its sub-categories (D117), the price order
    // (D131) and the selected one.
    final List<_Cell> tabCells;
    if (isBag) {
      tabCells = [
        for (final item in bagAsync?.value ?? const <GiftBagItem>[])
          _Cell(item.gift, bagQuantity: item.quantity),
      ];
    } else if (isRecent) {
      // Gifts no longer in the catalogue drop out.
      tabCells = [
        for (final code in recent)
          if (catalogue?.byCode(code) case final g?) _Cell(g),
      ];
    } else {
      tabCells = [
        if (catalogue != null)
          for (final g in catalogue.of(GiftCategory.fromWire(tab)!)) _Cell(g),
      ];
    }
    final tags = isRecent
        ? const <GiftTag>[]
        : giftTags([for (final c in tabCells) c.gift]);
    final tag = tags.any((t) => t.code == _tag) ? _tag : null;
    final cells = [
      for (final c in tabCells)
        if (tag == null || c.gift.tag?.code == tag) c,
    ];
    if (_sort != _PriceSort.none) {
      // A stable sort: equal prices keep the catalogue's order.
      final order = {for (var i = 0; i < cells.length; i++) cells[i]: i};
      cells.sort((a, b) {
        final byPrice = a.gift.priceCoins.compareTo(b.gift.priceCoins);
        if (byPrice != 0) return _sort == _PriceSort.up ? byPrice : -byPrice;
        return order[a]!.compareTo(order[b]!);
      });
    }
    final selected = cells.where((c) => c.gift.code == _selected).firstOrNull;
    final quantities = catalogue?.quantities ?? const [1];
    final quantity = quantities.contains(_quantity)
        ? _quantity!
        : quantities.first;

    // D132: lucky gifts need the odds (who may send them now).
    final luckySelected = selected?.gift.category == GiftCategory.lucky;
    final odds = isLuckyTab || luckySelected
        ? ref.watch(luckyOddsProvider)
        : null;
    final caller = odds?.value?.caller;
    final luckyBlocked = switch (odds?.value) {
      null => null,
      final o when !o.enabled => l10n.liveLuckyOff,
      _ => switch (caller?.reason) {
        LuckyGiftIneligibility.regionUnavailable => l10n.liveLuckyRegion,
        LuckyGiftIneligibility.disabled ||
        LuckyGiftIneligibility.unknown => l10n.liveLuckyOff,
        LuckyGiftIneligibility.ageUnconfirmed || null => null,
      },
    };

    final String? reason;
    if (catalogue != null && catalogue.data.isEmpty) {
      reason = l10n.liveGiftEmptyTitle;
    } else if (candidates.isEmpty) {
      reason = l10n.liveGiftNoRecipients;
    } else if (selected == null) {
      reason = l10n.liveGiftPickGift;
    } else if (chosen.isEmpty) {
      reason = l10n.liveGiftPickRecipient;
    } else if (luckySelected && luckyBlocked != null) {
      reason = luckyBlocked;
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
            // A lucky gift is sent with coins only (§10.27).
            source: isBag && !luckySelected
                ? LiveGiftSource.bag
                : LiveGiftSource.coins,
            lucky: luckySelected,
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
    } else if (isLuckyTab && luckyBlocked != null) {
      // D132: the tab stays, says why, and keeps the odds one tap away.
      grid = Center(
        child: SingleChildScrollView(
          child: KEmptyState(
            key: KLiveGiftSheet.luckyBlockedKey,
            icon: Icons.casino_outlined,
            title: luckyBlocked,
            message: l10n.liveLuckyOddsAge,
            compact: true,
          ),
        ),
      );
    } else if (cells.isEmpty) {
      final noGifts = catalogue == null || catalogue.data.isEmpty;
      final (icon, title, message) = switch ((isBag, isRecent)) {
        _ when noGifts => (
          Icons.card_giftcard_rounded,
          l10n.liveGiftEmptyTitle,
          l10n.liveGiftEmptyMessage,
        ),
        (true, _) => (
          Icons.inventory_2_outlined,
          l10n.liveGiftBagEmptyTitle,
          l10n.liveGiftBagEmptyMessage,
        ),
        (_, true) => (
          Icons.history_rounded,
          l10n.liveGiftRecentEmptyTitle,
          l10n.liveGiftRecentEmptyMessage,
        ),
        _ => (
          Icons.card_giftcard_rounded,
          l10n.liveGiftEmptyTitle,
          l10n.liveGiftEmptyMessage,
        ),
      };
      grid = Center(
        child: SingleChildScrollView(
          child: KEmptyState(
            key: KLiveGiftSheet.emptyKey,
            icon: icon,
            title: title,
            message: message,
            compact: true,
          ),
        ),
      );
    } else {
      grid = GridView.builder(
        padding: const EdgeInsets.fromLTRB(
          _Sheet.edge,
          4,
          _Sheet.edge,
          // The bottom row lies over the grid's last row (ref 161).
          _Sheet.barHeight + KSpacing.sm,
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

    final showRecipients = candidates.length > 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 6.6),
        const _WealthStrip(),
        if (showRecipients) ...[
          const SizedBox(height: 9),
          _Recipients(
            candidates: candidates,
            host: room.host,
            chosen: chosen,
            allOn: allOn,
            showAll: true,
            onTap: (u) => _toggle(u, candidates, max),
            onAll: () => _toggleAll(candidates, allOn, max),
          ),
        ],
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
        const SizedBox(height: 4),
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
        const SizedBox(height: 3),
        _TagChips(
          tags: tags,
          selected: tag,
          sort: _sort,
          onTap: (code) => setState(() {
            _tag = code;
            _selected = null;
            _error = null;
            _resetCombo();
          }),
          onSort: () => setState(() {
            _sort = _PriceSort.values[(_sort.index + 1) % 3];
          }),
          onOdds: isLuckyTab ? () => unawaited(showLuckyOdds(context)) : null,
        ),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(child: grid),
              if (_toast case final toast?)
                PositionedDirectional(
                  start: KSpacing.md,
                  end: KSpacing.md,
                  bottom: _Sheet.barHeight + KSpacing.md,
                  child: _Toast(
                    key: KLiveGiftSheet.toastKey,
                    message: toast,
                    error: _toastError,
                  ),
                ),
              PositionedDirectional(
                start: 0,
                end: 0,
                bottom: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                            color: _error != null
                                ? KPalette.dark.error
                                : _Sheet.bagIcon,
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
                      reason: reason,
                      onSend: intent == null
                          ? null
                          : () => unawaited(_onSend(intent)),
                      // D128: a tap on a dimmed Send says why instead of
                      // doing nothing.
                      onBlocked: switch (reason) {
                        final why? => () => _showToast(why),
                        null => null,
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: bottomInset + _Sheet.barGap),
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
    this.lucky = false,
  });

  final String code;
  final int quantity;
  final List<String> recipients;
  final LiveGiftSource source;

  /// D132: a LUCKY gift (the 18+ statement first).
  final bool lucky;

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

/// The recipients row (48 high, D135; it scrolls when many): the host (a
/// "Host" label) and the people on the mic, each a picture, full with a
/// cyan ring when selected and dimmed when not; when there is more than
/// one, a divider and the "All" toggle at the end.
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
              separatorBuilder: (_, _) => const SizedBox(width: KSpacing.xs),
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

  /// D135 (owner: "with several people the pictures are too small to pick
  /// from"): a 48 pt square target (the row's height) around a 40 pt
  /// picture (D117's 29 pt was the reference's size).
  static const double size = 48;
  static const double avatar = 40;

  /// The selected ring (Send's cyan) and its check.
  static const ring = Color(0xFF26E4DA);

  final UserSummary user;
  final bool isHost;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.textStyles;
    final motion = KMotion.of(context, KMotion.fast);
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
        child: SizedBox.square(
          dimension: size,
          child: Center(
            child: SizedBox.square(
              dimension: avatar,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedOpacity(
                    duration: motion,
                    opacity: selected ? 1 : 0.5,
                    child: KAvatar(
                      name: user.displayName,
                      imageUrl: user.avatarUrl,
                      size: avatar,
                    ),
                  ),
                  // Selected: a cyan ring around the picture.
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedContainer(
                        duration: motion,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected ? ring : const Color(0x00000000),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (selected)
                    const PositionedDirectional(
                      top: -2,
                      end: -2,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: ring,
                          shape: BoxShape.circle,
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(1.5),
                          child: Icon(
                            Icons.check_rounded,
                            size: 10,
                            color: Color(0xFF0B2B2A),
                          ),
                        ),
                      ),
                    ),
                  PositionedDirectional(
                    start: 0,
                    end: 0,
                    bottom: -3,
                    child: Container(
                      height: 13,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 2),
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
      ),
    );
  }
}

/// The tabs (ref 161): the catalogue's tabs from the reading start (12.5 sp,
/// bold white when open, `#858487` otherwise, a caret when the tab has
/// sub-categories, a 7.2 × 1.7 pt white bar under the open one) and the bag
/// as an icon at the end. The row scrolls.
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

  static const double height = 34;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    String label(String id) => switch (GiftCategory.fromWire(id)) {
      GiftCategory.popular => l10n.liveGiftTabPopular,
      GiftCategory.event => l10n.liveGiftTabEvent,
      GiftCategory.fun => l10n.liveGiftTabFun,
      GiftCategory.lucky => l10n.liveGiftTabLucky,
      null when id == KLiveGiftSheet.recentTab => l10n.liveGiftTabRecent,
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
            // Every tab is built (a short list), so all are reachable.
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsetsDirectional.only(start: 15, end: 12),
              child: Row(
                children: [
                  for (final (i, id) in categories.indexed) ...[
                    if (i > 0) const SizedBox(width: 6),
                    _Tab(
                      key: KLiveGiftSheet.tabKey(id),
                      label: label(id),
                      selected: id == selected,
                      caret: hasTags(id),
                      onTap: () => onTap(id),
                    ),
                  ],
                ],
              ),
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
          const SizedBox(width: 4),
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
      content = Icon(icon, size: 16, color: color);
    } else {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            style: text.label.copyWith(
              color: color,
              fontSize: 12.5,
              height: 1.21,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          if (caret) ...[
            const SizedBox(width: 3),
            CustomPaint(
              size: const Size(5.5, 3.4),
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
        child: ConstrainedBox(
          // A wider target than the word (the row scrolls).
          constraints: const BoxConstraints(minWidth: 40),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Center(child: content),
                PositionedDirectional(
                  start: 0,
                  end: 0,
                  bottom: 4,
                  child: Center(
                    child: AnimatedContainer(
                      duration: KMotion.of(context, KMotion.fast),
                      width: selected ? 7.2 : 0,
                      height: 1.7,
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

/// The chips row (ref 161): "All" and the open tab's tags (22.1 pt, the
/// chosen one filled `#3F4346`, the others outlined), D132's "Odds" link on
/// the Lucky tab, and "Price ⇅" fixed at the end over a fade (client-side
/// order: off → low to high → high to low).
class _TagChips extends StatelessWidget {
  const new({
    required this.tags,
    required this.selected,
    required this.sort,
    required this.onTap,
    required this.onSort,
    this.onOdds,
  });

  final List<GiftTag> tags;
  final String? selected;
  final _PriceSort sort;
  final ValueChanged<String?> onTap;
  final VoidCallback onSort;
  final VoidCallback? onOdds;

  static const double height = 22.1;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.textStyles;
    Widget chip(Key key, String label, {required bool on, VoidCallback? tap}) =>
        GestureDetector(
          key: key,
          onTap: tap,
          behavior: HitTestBehavior.opaque,
          child: Semantics(
            button: true,
            selected: on,
            child: Padding(
              // A taller target than the 22 pt chip.
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: AnimatedContainer(
                duration: KMotion.of(context, KMotion.fast),
                height: height,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: on ? _Sheet.chipOn : null,
                  borderRadius: BorderRadius.circular(KRadius.pill),
                  border: on ? null : Border.all(color: _Sheet.chipBorder),
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  style: text.label.copyWith(
                    color: on ? _Sheet.white : _Sheet.muted,
                    fontSize: 11,
                    height: 1.2,
                    fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        );
    final sortLabel = switch (sort) {
      _PriceSort.none => l10n.liveGiftPriceSortOff,
      _PriceSort.up => l10n.liveGiftPriceSortUp,
      _PriceSort.down => l10n.liveGiftPriceSortDown,
    };
    final dir = Directionality.of(context);
    return SizedBox(
      height: height + 12,
      child: Stack(
        children: [
          Positioned.fill(
            child: Semantics(
              container: true,
              label: l10n.liveGiftTagsSemantics,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsetsDirectional.only(start: 11.5, end: 96),
                child: Row(
                  children: [
                    if (onOdds case final odds?) ...[
                      chip(
                        KLiveGiftSheet.luckyOddsKey,
                        l10n.liveLuckyOdds,
                        on: false,
                        tap: odds,
                      ),
                      const SizedBox(width: 10),
                    ],
                    if (tags.isNotEmpty) ...[
                      chip(
                        KLiveGiftSheet.tagKey(null),
                        l10n.liveGiftTagAll,
                        on: selected == null,
                        tap: () => onTap(null),
                      ),
                      for (final t in tags) ...[
                        const SizedBox(width: 10),
                        chip(
                          KLiveGiftSheet.tagKey(t.code),
                          t.name,
                          on: t.code == selected,
                          tap: () => onTap(t.code),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
          PositionedDirectional(
            top: 0,
            bottom: 0,
            end: 0,
            child: Semantics(
              button: true,
              label: sortLabel,
              excludeSemantics: true,
              child: GestureDetector(
                key: KLiveGiftSheet.priceSortKey,
                onTap: onSort,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsetsDirectional.only(
                    start: 28,
                    end: 11.5,
                  ),
                  alignment: AlignmentDirectional.centerEnd,
                  decoration: BoxDecoration(
                    // The fade that clips the chips under it.
                    gradient: LinearGradient(
                      begin: dir == TextDirection.rtl
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      end: dir == TextDirection.rtl
                          ? Alignment.centerLeft
                          : Alignment.centerRight,
                      stops: const [0, 0.35],
                      colors: [_Sheet.top.withValues(alpha: 0), _Sheet.top],
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.liveGiftPriceSort,
                        style: text.label.copyWith(
                          color: sort == _PriceSort.none
                              ? _Sheet.muted
                              : _Sheet.white,
                          fontSize: 11,
                          height: 1.2,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        switch (sort) {
                          _PriceSort.none => Icons.swap_vert_rounded,
                          _PriceSort.up => Icons.arrow_upward_rounded,
                          _PriceSort.down => Icons.arrow_downward_rounded,
                        },
                        size: 13,
                        color: sort == _PriceSort.none
                            ? _Sheet.muted
                            : _Sheet.white,
                      ),
                    ],
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

/// One gift (ref 161): no card unless selected (`#35393A`, a lighter top
/// edge, ≈ 6 pt corners); the art (54 pt), the name (8.5 sp, `#AFAEB1`,
/// white when selected) and the price (coin and number, 9 sp `#878988`)
/// centred; the badge in the top end corner.
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
          margin: const EdgeInsets.symmetric(horizontal: 1.6),
          decoration: BoxDecoration(
            color: selected ? _Sheet.cellSelected : null,
            borderRadius: BorderRadius.circular(6),
            border: Border(
              top: BorderSide(
                color: selected ? _Sheet.cellEdge : const Color(0x00000000),
              ),
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(2, 5, 2, 0),
                  child: Column(
                    children: [
                      KGiftImage(
                        key: KLiveGiftSheet.giftImageKey(gift.code),
                        gift.assetKey,
                        imageUrl: gift.imageUrl,
                        size: _Sheet.giftImage,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        gift.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: text.caption.copyWith(
                          color: selected ? _Sheet.white : _Sheet.name,
                          fontSize: 10,
                          height: 1.25,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      // A long price shrinks instead of overflowing.
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const KabsoArtIcon(KabsoArt.coin, size: 12),
                              const SizedBox(width: 3),
                              Text(
                                price,
                                style: text.caption.copyWith(
                                  color: _Sheet.priceText,
                                  fontSize: 10,
                                  height: 1.21,
                                  fontWeight: FontWeight.w600,
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
                  top: 3.4,
                  end: 3.4,
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

/// The message over the grid's bottom (D128): an icon and the text, on the
/// panel's pill colour; screen readers hear it at once. D132: a lucky
/// result shows here too (not an error).
class _Toast extends StatelessWidget {
  const new({required this.message, super.key, this.error = true});

  final String message;
  final bool error;

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
            child: error
                ? Icon(
                    Icons.error_outline,
                    size: 18,
                    color: KPalette.dark.error,
                  )
                : const KabsoArtIcon(KabsoArt.coin, size: 18),
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

/// D131 (ref 161's top strip): the sender's wealth level (SUPPORT, CP-005)
/// — the level badge, the progress to the next level and the points still
/// needed. Nothing when the level is unknown, switched off or not loaded.
class _WealthStrip extends ConsumerWidget {
  const new();

  static const double height = 26;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final support = ref
        .watch(myLevelsProvider)
        .value
        ?.where((l) => l.category == LevelCategory.support)
        .firstOrNull;
    final level = support?.level;
    if (support == null || !support.available || level == null) {
      return const SizedBox.shrink();
    }
    final percent = (support.progressPercent ?? 0) / 100;
    final toNext = support.pointsToNext;
    final caption = toNext == null || support.maxLevel
        ? null
        : l10n.liveGiftWealthToNext(
            KFormat.bidiIsolate(
              toNext.isValidInt
                  ? KFormat.grouped(toNext.toInt())
                  : toNext.toString(),
            ),
          );
    return Semantics(
      key: KLiveGiftSheet.wealthKey,
      container: true,
      label: [
        l10n.liveGiftWealthLevel(KFormat.grouped(level.levelNumber)),
        ?caption,
      ].join(', '),
      excludeSemantics: true,
      child: SizedBox(
        height: height,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(width: 11.5),
            KLevelBadge(
              category: LevelCategory.support,
              levelNumber: level.levelNumber,
              iconKey: level.iconKey,
              height: 14,
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 235,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 5.7),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(KRadius.pill),
                    child: SizedBox(
                      height: 2.6,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          const ColoredBox(color: _Sheet.track),
                          FractionallySizedBox(
                            alignment: AlignmentDirectional.centerStart,
                            widthFactor: percent.clamp(0, 1),
                            child: const ColoredBox(color: _Sheet.trackFill),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (caption != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textStyles.caption.copyWith(
                        color: _Sheet.caption,
                        fontSize: 8,
                        height: 1.2,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Over the grid's bottom (ref 161): the coin balance at the reading start;
/// the quantities in one `#404747` pill (the chosen one a white circle with
/// a teal number) running under Send (cyan gradient, 63.9 × 29.4 pt), a
/// spinner while sending and ×N while a combo goes on. There is no store
/// yet (B5), so the balance opens nothing.
class _BottomBar extends ConsumerWidget {
  const new({
    required this.quantities,
    required this.quantity,
    required this.onQuantity,
    required this.combo,
    required this.busy,
    required this.reason,
    required this.onSend,
    this.onBlocked,
  });

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

  /// The row's touch height around the 29.4 pt pill.
  static const double touch = 44;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final text = context.textStyles;
    final coins = ref.watch(liveCoinsProvider).value;
    final balance = coins == null ? null : KFormat.grouped(coins);
    final enabled = onSend != null;
    const h = _Sheet.barHeight;
    return SizedBox(
      height: touch,
      child: Row(
        children: [
          const SizedBox(width: 11),
          Semantics(
            label: balance == null ? null : l10n.liveGiftBalance(balance),
            excludeSemantics: true,
            child: Row(
              key: KLiveGiftSheet.balanceKey,
              mainAxisSize: MainAxisSize.min,
              children: [
                const KabsoArtIcon(KabsoArt.coin, size: 16.6),
                const SizedBox(width: 4),
                if (balance != null)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 52),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        balance,
                        maxLines: 1,
                        style: text.label.copyWith(
                          color: _Sheet.white,
                          fontSize: 12.5,
                          height: 1.21,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          if (combo > 1) ...[
            KGiftComboCounter(key: KLiveGiftSheet.comboKey, count: combo),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Stack(
              alignment: AlignmentDirectional.centerEnd,
              children: [
                // The pill runs under Send (ref 161); the quantities stay
                // in the part before it.
                Positioned.fill(
                  child: Center(
                    child: Container(
                      height: h,
                      decoration: BoxDecoration(
                        color: _Sheet.pill,
                        borderRadius: BorderRadius.circular(h / 2),
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        key: KLiveGiftSheet.quantityKey,
                        height: h,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsetsDirectional.only(
                            start: 4,
                            end: 4,
                          ),
                          child: Row(
                            children: [
                              for (final q in quantities)
                                _QuantityOption(
                                  key: KLiveGiftSheet.quantityOptionKey(q),
                                  quantity: q,
                                  selected: q == quantity,
                                  onTap: () => onQuantity(q),
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
                      hint: enabled ? null : reason,
                      excludeSemantics: true,
                      child: GestureDetector(
                        key: KLiveGiftSheet.sendKey,
                        onTap: onSend ?? onBlocked,
                        behavior: HitTestBehavior.opaque,
                        child: SizedBox(
                          height: touch,
                          child: Center(
                            child: AnimatedContainer(
                              duration: KMotion.of(context, KMotion.fast),
                              height: h,
                              constraints: const BoxConstraints(
                                minWidth: _Sheet.sendWidth,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: enabled
                                      ? _Sheet.send
                                      : _Sheet.sendOff,
                                ),
                                borderRadius: BorderRadius.circular(h / 2),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (busy) ...[
                                    const SizedBox.square(
                                      dimension: 11,
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
                                          fontSize: 12,
                                          height: 1.2,
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
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: _Sheet.barEnd),
        ],
      ),
    );
  }
}

/// One quantity in the pill: the number (12.5 sp `#A9A7AC`), or, chosen, a
/// 21.8 pt white circle with the number in teal.
class _QuantityOption extends StatelessWidget {
  const new({
    required this.quantity,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final int quantity;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final count = KFormat.grouped(quantity);
    return Semantics(
      button: true,
      selected: selected,
      label: l10n.liveGiftQuantity(count),
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Center(
            child: AnimatedContainer(
              duration: KMotion.of(context, KMotion.fast),
              height: 21.8,
              constraints: const BoxConstraints(minWidth: 30),
              padding: const EdgeInsets.symmetric(horizontal: 5),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? _Sheet.white : null,
                borderRadius: BorderRadius.circular(10.9),
              ),
              child: Text(
                count,
                maxLines: 1,
                textDirection: TextDirection.ltr,
                style: context.textStyles.label.copyWith(
                  color: selected ? _Sheet.countText : _Sheet.count,
                  fontSize: 12.5,
                  height: 1.2,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// D132: the published odds of lucky gifts (store disclosure): how a draw
/// works, each multiplier's chance, no win, the expected return, the host
/// share, the daily protection and the age limit. Read fresh each time.
Future<void> showLuckyOdds(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: _Sheet.top,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(_Sheet.radius)),
  ),
  builder: (_) => const _LuckyOddsSheet(),
);

class _LuckyOddsSheet extends ConsumerWidget {
  const new();

  static String _percent(double p) {
    final v = p * 100;
    final digits = v >= 10 ? 1 : (v >= 0.1 ? 2 : 4);
    return '${v.toStringAsFixed(digits)}%';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final odds = ref.watch(luckyOddsProvider);
    final body = switch (odds) {
      AsyncData(:final value) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.liveLuckyOddsIntro,
            style: t.body.copyWith(color: _Sheet.name),
          ),
          const SizedBox(height: KSpacing.md),
          for (final o in value.outcomes)
            _OddsRow(
              key: KLiveGiftSheet.oddsRowKey(o.multiplier),
              label: l10n.liveLuckyOddsRow(KFormat.grouped(o.multiplier)),
              value: _percent(o.probability),
            ),
          _OddsRow(
            label: l10n.liveLuckyOddsNoWin,
            value: _percent(value.noWinProbability),
          ),
          const SizedBox(height: KSpacing.md),
          for (final line in [
            l10n.liveLuckyOddsReturn(
              KFormat.bidiIsolate('${_trim(value.returnPercent)}%'),
            ),
            l10n.liveLuckyOddsHostShare(
              KFormat.bidiIsolate('${_trim(value.hostSharePercent)}%'),
            ),
            if (value.dailyProtection) l10n.liveLuckyOddsProtection,
            l10n.liveLuckyOddsAge,
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: KSpacing.xs),
              child: Text(line, style: t.caption.copyWith(color: _Sheet.name)),
            ),
        ],
      ),
      AsyncError(:final error) => KErrorState(
        title: l10n.liveLuckyOddsTitle,
        message: failureMessage(l10n, toAppFailure(error)),
        retryLabel: l10n.actionRetry,
        onRetry: () => ref.invalidate(luckyOddsProvider),
        compact: true,
      ),
      _ => const Padding(
        padding: EdgeInsets.all(KSpacing.xl),
        child: Center(child: CircularProgressIndicator()),
      ),
    };
    return KLiveSurface(
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.8,
          ),
          child: SingleChildScrollView(
            key: KLiveGiftSheet.oddsSheetKey,
            padding: const EdgeInsets.all(KSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    l10n.liveLuckyOddsTitle,
                    style: t.title.copyWith(color: _Sheet.white),
                  ),
                ),
                const SizedBox(height: KSpacing.md),
                body,
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _trim(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
}

class _OddsRow extends StatelessWidget {
  const new({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = context.textStyles;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: t.bodyStrong.copyWith(color: _Sheet.white),
            ),
          ),
          Text(
            value,
            textDirection: TextDirection.ltr,
            style: t.body.copyWith(color: _Sheet.white),
          ),
        ],
      ),
    );
  }
}

/// D132: the one-time 18+ statement before a first lucky gift. True when
/// the person confirmed.
Future<bool> _confirmLuckyAge(BuildContext context) async {
  final l10n = context.l10n;
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      key: KLiveGiftSheet.ageDialogKey,
      title: Text(l10n.liveLuckyAgeTitle),
      content: Text(l10n.liveLuckyAgeBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialog).pop(false),
          child: Text(MaterialLocalizations.of(dialog).cancelButtonLabel),
        ),
        TextButton(
          key: KLiveGiftSheet.ageConfirmKey,
          onPressed: () => Navigator.of(dialog).pop(true),
          child: Text(l10n.liveLuckyAgeConfirm),
        ),
      ],
    ),
  );
  return ok ?? false;
}
