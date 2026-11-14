import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/logging/app_logger.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/application/live_pk4_controller.dart';
import 'package:kabso_live/features/live/data/live_pk4_repository.dart';
import 'package:kabso_live/features/live/domain/live_pk.dart';
import 'package:kabso_live/features/live/domain/live_pk4.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_pk4_stage.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_pk_sheet.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_pk_stage.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// The message of a refused 4-way PK call (its two codes, else PK 1 v 1's).
///
/// D393: [opening] is the organiser's «افتح PK رباعي» — there the caller is
/// the one refused, so 409 `PK_UNAVAILABLE`, 409 `PK_HOST_BUSY` and 404 say
/// what the host must do (or that the server does not have it).
String pk4FailureMessage(
  AppLocalizations l10n,
  Object error, {
  bool opening = false,
}) {
  final failure = toAppFailure(error);
  final code = failure is ServerFailure ? failure.rawCode : null;
  return switch (code) {
    'PK_LOBBY_CLOSED' => l10n.pk4ErrorLobbyClosed,
    'PK_SEAT_TAKEN' => l10n.pk4ErrorSeatTaken,
    'PK_UNAVAILABLE' when opening => l10n.pk4ErrorOpenUnavailable,
    'PK_HOST_BUSY' when opening => l10n.pk4ErrorOpenBusy,
    'NOT_FOUND' when opening => l10n.pk4ErrorOpenNotOnServer,
    _ => pkFailureMessage(l10n, error),
  };
}

/// D393: the selectable line under a refusal — the server's code (and the
/// request id where §10 shows one), so a screenshot names the cause.
String? pk4FailureDetail(Object error) {
  final failure = toAppFailure(error);
  if (failure is! ServerFailure) return null;
  return [
    failure.rawCode,
    if (failure.statusCode case final status?) '$status',
    ?failureErrorId(failure),
  ].join(' · ');
}

/// The label of a place (1 organiser; TEAMS: 2 teammate, 3–4 opponents;
/// v1.119-live FREE_FOR_ALL: 2–4 players).
String pk4SeatLabel(
  AppLocalizations l10n,
  int seat, [
  Pk4Format format = Pk4Format.teams,
]) => switch (seat) {
  1 => l10n.pk4SeatOrganiser,
  _ when format == Pk4Format.freeForAll => l10n.pk4SeatPlayer,
  2 => l10n.pk4SeatTeammate,
  _ => l10n.pk4SeatOpponent,
};

/// The colours of a lobby place: TEAMS by team (this host's team red),
/// FREE_FOR_ALL one per place.
List<Color> _placeColors(Pk4Format format, int seat, Pk4Team ownTeam) {
  if (format == Pk4Format.freeForAll) {
    return KLivePk4.ffaSeat[(seat - 1).clamp(0, 3)];
  }
  return pk4TeamOfSeat(seat) == ownTeam ? KLivePk4.startTeam : KLivePk4.endTeam;
}

/// «PK رباعي» (v1.118-live, D391, §10.180; v1.119-live, D395, §10.181): the
/// host's 4-way panel. D393 (owner: «زر pk رباعي يفتح صفحة اخرى لماذا لا
/// ينتقل من نفس الشريط»): it is the «PK رباعي» segment of the PK sheet itself
/// ([LivePkSheet]), under the mode cards — never a sheet of its own. Before a
/// lobby: the format «٢ ضد ٢» / «الكل ضد الكل» and the type (normal / «PK
/// أحكام»), «افتح PK رباعي» and «مطابقة عشوائية رباعية» (four hosts only;
/// while waiting: its countdown and «إيقاف البحث»). In a lobby: the four
/// places in two columns (TEAMS: this team on the reading start; FREE_FOR_ALL:
/// one colour per place), each place's state, the lobby's countdown, «ابدأ
/// الآن» for the organiser once one invited host joined (D395, owner «أ»),
/// the friends for the picked place (D395: the smaller list, as the 1 v 1
/// tab) or a search, and cancel / leave; in a match: start / End. A refused
/// call is written in the panel (D393: a snack bar sat under the sheet).
class LivePk4Panel extends ConsumerStatefulWidget {
  const new({required this.roomId, super.key});

  final String roomId;

  static const panelKey = Key('pk4.panel');
  static const errorKey = Key('pk4.panel.error');
  static const openKey = Key('pk4.sheet.open');
  static const cancelKey = Key('pk4.sheet.cancel');
  static const leaveKey = Key('pk4.sheet.leave');
  static const searchKey = Key('pk4.sheet.search');
  static const countdownKey = Key('pk4.sheet.countdown');
  static const startKey = Key('pk4.sheet.start');
  static const endKey = Key('pk4.sheet.end');
  static const endConfirmKey = Key('pk4.end.confirm');

  /// v1.119-live (D395).
  static const startNowKey = Key('pk4.sheet.startNow');
  static const randomKey = Key('pk4.sheet.random');
  static const stopRandomKey = Key('pk4.sheet.random.stop');
  static const searchingKey = Key('pk4.sheet.searching');
  static const daresKey = Key('pk4.sheet.dares');
  static Key formatKey(Pk4Format f) => Key('pk4.sheet.format.${f.wire}');
  static Key placeKey(int seat) => Key('pk4.sheet.place.$seat');
  static Key withdrawKey(int seat) => Key('pk4.sheet.withdraw.$seat');
  static Key candidateKey(String roomId) => Key('pk4.sheet.candidate.$roomId');

  @override
  ConsumerState<LivePk4Panel> createState() => _LivePk4PanelState();
}

class _LivePk4PanelState extends ConsumerState<LivePk4Panel> {
  String _query = '';
  int? _place;
  bool _busy = false;
  Timer? _debounce;
  Timer? _tick;
  List<PkCandidate>? _list;
  Object? _failure;
  int _reads = 0;

  /// v1.119-live (D395): the format and the type a new lobby or wait uses.
  Pk4Format _format = Pk4Format.teams;
  PkType _type = PkType.normal;

  /// D393: the last refused action, shown in the panel until the next one.
  Object? _error;
  bool _errorOpening = false;

  @override
  void initState() {
    super.initState();
    if (LivePkStage.ticks) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final q = _query.trim();
    final read = ++_reads;
    try {
      final list = await ref
          .read(livePk4RepositoryProvider)
          .candidates(widget.roomId, query: q, friends: q.isEmpty);
      if (!mounted || read != _reads) return;
      setState(() {
        _list = list;
        _failure = null;
      });
    } on Object catch (e, stack) {
      AppLogger.error('live: PK4 candidates not read', e, stack);
      if (!mounted || read != _reads) return;
      setState(() {
        _list = null;
        _failure = e;
      });
    }
  }

  /// Runs a host action; a refusal is logged and written in the panel.
  Future<void> _run(
    Future<void> Function() action, {
    bool opening = false,
  }) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on Object catch (e, stack) {
      AppLogger.error('live: PK4 action refused', e, stack);
      if (mounted) {
        setState(() {
          _error = e;
          _errorOpening = opening;
        });
      }
      // A lobby this room already has (409 PK_HOST_BUSY on open) shows.
      if (opening) {
        unawaited(ref.read(livePk4Provider(widget.roomId).notifier).refresh());
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pk4 = ref.watch(livePk4Provider(widget.roomId));
    final controller = ref.read(livePk4Provider(widget.roomId).notifier);
    final lobby = pk4.lobby;
    final organiser = lobby?.organiserRoomId == widget.roomId;
    final t = context.textStyles;
    // ignore: invalid_use_of_visible_for_testing_member, the goldens' clock pin (D231).
    final now = (LivePkStage.debugNow ?? pk4.now)();
    final error = _error;
    final format = lobby?.format ?? pk4.queue?.format ?? _format;
    final queue = pk4.queue;
    final searching = queue != null && queue.expiresAt.isAfter(now);
    return Column(
      key: LivePk4Panel.panelKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                format == Pk4Format.freeForAll
                    ? l10n.pk4SubtitleFfa
                    : l10n.pk4Subtitle,
                style: t.caption.copyWith(color: PkSheetMetrics.grey),
              ),
            ),
            if (lobby != null)
              Container(
                key: LivePk4Panel.countdownKey,
                padding: const EdgeInsets.symmetric(
                  horizontal: KSpacing.sm,
                  vertical: KSpacing.xxs,
                ),
                decoration: BoxDecoration(
                  color: PkSheetMetrics.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(KRadius.pill),
                ),
                child: Text(
                  l10n.pk4LobbyEndsIn(
                    KFormat.countdown(_left(lobby.expiresAt, now)),
                  ),
                  style: t.label.copyWith(
                    color: PkSheetMetrics.red,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: KSpacing.sm),
        if (error != null) ...[
          KInlineMessage(
            key: LivePk4Panel.errorKey,
            message: pk4FailureMessage(l10n, error, opening: _errorOpening),
            detail: pk4FailureDetail(error),
          ),
          const SizedBox(height: KSpacing.sm),
        ],
        // In a match: start it (CONNECTED) or leave it (End).
        if (pk4.match case final match?) ...[
          Text(
            match.status == PkMatchStatus.connected
                ? l10n.pk4ConnectedHint
                : l10n.pk4EndConfirmBody,
            style: t.body,
          ),
          const SizedBox(height: KSpacing.lg),
          if (match.status == PkMatchStatus.connected) ...[
            KButton(
              key: LivePk4Panel.startKey,
              label: l10n.pkStart,
              loading: _busy,
              onPressed: () => unawaited(_run(controller.start)),
            ),
            const SizedBox(height: KSpacing.sm),
          ],
          KButton(
            key: LivePk4Panel.endKey,
            label: l10n.pkEnd,
            variant: KButtonVariant.secondary,
            onPressed: () => unawaited(_confirmEnd(match, controller)),
          ),
          const Spacer(),
        ] else if (searching) ...[
          // v1.119-live (D395): waiting for three more hosts (four only).
          const Spacer(),
          Center(
            key: LivePk4Panel.searchingKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.shuffle_rounded,
                  size: 44,
                  color: PkSheetMetrics.red,
                ),
                const SizedBox(height: KSpacing.sm),
                Text(
                  l10n.pk4RandomSearching(
                    KFormat.countdown(_left(queue.expiresAt, now)),
                  ),
                  textAlign: TextAlign.center,
                  style: t.body.copyWith(
                    color: PkSheetMetrics.ink,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: KSpacing.md),
                KButton(
                  key: LivePk4Panel.stopRandomKey,
                  label: l10n.pk4RandomStop,
                  variant: KButtonVariant.secondary,
                  expand: false,
                  loading: _busy,
                  onPressed: () => unawaited(_run(controller.leaveRandom)),
                ),
              ],
            ),
          ),
          const Spacer(),
        ] else if (lobby == null) ...[
          _choices(context),
          const SizedBox(height: KSpacing.sm),
          Text(l10n.pk4LobbyHintStart, style: t.caption),
          const SizedBox(height: KSpacing.md),
          KButton(
            key: LivePk4Panel.openKey,
            label: l10n.pk4OpenLobby,
            loading: _busy,
            onPressed: () => unawaited(
              _run(opening: true, () async {
                await controller.openLobby(format: _format, type: _type);
                _place = 2;
                unawaited(_load());
              }),
            ),
          ),
          const SizedBox(height: KSpacing.sm),
          KButton(
            key: LivePk4Panel.randomKey,
            label: l10n.pk4Random,
            icon: Icons.shuffle_rounded,
            variant: KButtonVariant.secondary,
            onPressed: _busy
                ? null
                : () => unawaited(
                    _run(
                      () => controller.joinRandom(format: _format, type: _type),
                    ),
                  ),
          ),
          const Spacer(),
        ] else ...[
          _places(context, lobby, now, organiser, controller),
          if (organiser && lobby.canStart) ...[
            const SizedBox(height: KSpacing.xs),
            _startNow(context, lobby, controller),
          ],
          const SizedBox(height: KSpacing.sm),
          if (organiser)
            Expanded(child: _candidates(context, lobby, controller))
          else
            const Spacer(),
          const SizedBox(height: KSpacing.sm),
          // D393: the lobby closes in place — the PK sheet stays open on
          // «PK رباعي» with «افتح PK رباعي» again.
          KButton(
            key: organiser ? LivePk4Panel.cancelKey : LivePk4Panel.leaveKey,
            label: organiser ? l10n.pk4CancelLobby : l10n.pk4LeaveLobby,
            variant: KButtonVariant.secondary,
            onPressed: () => unawaited(
              _run(() async {
                await controller.closeLobby();
                if (!mounted) return;
                setState(() {
                  _place = null;
                  _list = null;
                  _failure = null;
                  _query = '';
                });
              }),
            ),
          ),
          const SizedBox(height: KSpacing.sm),
        ],
      ],
    );
  }

  /// v1.119-live (D395): «٢ ضد ٢» / «الكل ضد الكل» (the 4-way panel's choice)
  /// and the type («PK أحكام»), in the 1 v 1 tab's pill style.
  Widget _choices(BuildContext context) {
    final l10n = context.l10n;
    Widget chip({
      required Key key,
      required bool selected,
      required String label,
      required IconData icon,
      required VoidCallback onTap,
    }) => Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        child: InkWell(
          key: key,
          borderRadius: BorderRadius.circular(KRadius.pill),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            constraints: const BoxConstraints(minHeight: 38),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: selected ? PkSheetMetrics.red : const Color(0xFFF3F3F6),
              borderRadius: BorderRadius.circular(KRadius.pill),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 17,
                  color: selected
                      ? const Color(0xFFFFFFFF)
                      : PkSheetMetrics.ink,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textStyles.label.copyWith(
                      fontWeight: FontWeight.w800,
                      color: selected
                          ? const Color(0xFFFFFFFF)
                          : PkSheetMetrics.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label: l10n.pk4FormatSemantics,
          container: true,
          child: Row(
            children: [
              chip(
                key: LivePk4Panel.formatKey(Pk4Format.teams),
                selected: _format == Pk4Format.teams,
                label: l10n.pk4FormatTeams,
                icon: Icons.groups_rounded,
                onTap: () => setState(() => _format = Pk4Format.teams),
              ),
              const SizedBox(width: KSpacing.sm),
              chip(
                key: LivePk4Panel.formatKey(Pk4Format.freeForAll),
                selected: _format == Pk4Format.freeForAll,
                label: l10n.pk4FormatFfa,
                icon: Icons.grid_view_rounded,
                onTap: () => setState(() => _format = Pk4Format.freeForAll),
              ),
            ],
          ),
        ),
        const SizedBox(height: KSpacing.xs),
        Row(
          children: [
            chip(
              key: LivePk4Panel.daresKey,
              selected: _type == PkType.dares,
              label: l10n.pk4DaresToggle,
              icon: Icons.gavel_rounded,
              onTap: () => setState(
                () => _type = _type == PkType.dares
                    ? PkType.normal
                    : PkType.dares,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// v1.119-live (D395, owner «أ»): «ابدأ الآن» once one invited host joined.
  Widget _startNow(
    BuildContext context,
    Pk4Lobby lobby,
    LivePk4Controller controller,
  ) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        KSpacing.sm,
        KSpacing.xs,
        KSpacing.xs,
        KSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(KRadius.md),
        border: Border.all(color: const Color(0xFFFFC266)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.pk4StartNowHint('${lobby.accepted}'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.textStyles.caption.copyWith(
                color: PkSheetMetrics.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: KSpacing.xs),
          KButton(
            key: LivePk4Panel.startNowKey,
            label: l10n.pk4StartNow,
            icon: Icons.play_arrow_rounded,
            expand: false,
            loading: _busy,
            onPressed: () => unawaited(_run(controller.startLobby)),
          ),
        ],
      ),
    );
  }

  /// During the battle: «ستغادر المعركة ويكمل زميلك وحده» first; then the
  /// PK sheet closes on the stage.
  Future<void> _confirmEnd(Pk4Match match, LivePk4Controller controller) async {
    final l10n = context.l10n;
    if (match.status == PkMatchStatus.battle) {
      final ok = await showKLiveConfirm(
        context,
        title: l10n.pkEndConfirmTitle,
        message: l10n.pk4EndConfirmBody,
        confirmKey: LivePk4Panel.endConfirmKey,
        confirmLabel: l10n.pkEnd,
        cancelLabel: l10n.pkCancel,
      );
      if (!ok) return;
    }
    await _run(controller.end);
    if (mounted && _error == null) await Navigator.of(context).maybePop();
  }

  static Duration _left(DateTime until, DateTime now) {
    final d = until.difference(now);
    return d.isNegative ? Duration.zero : Duration(seconds: d.inSeconds);
  }

  /// The four places in two columns: TEAMS this host's team on the start;
  /// FREE_FOR_ALL places 1–2 and 3–4 (one colour per place).
  Widget _places(
    BuildContext context,
    Pk4Lobby lobby,
    DateTime now,
    bool organiser,
    LivePk4Controller controller,
  ) {
    final mine = lobby.seats
        .where((s) => s.roomId == widget.roomId)
        .firstOrNull;
    final ownTeam = lobby.format == Pk4Format.freeForAll
        ? Pk4Team.a
        : mine?.team ?? Pk4Team.a;
    Widget column(Pk4Team team) => Column(
      children: [
        for (final s in lobby.seats.where((s) => s.team == team)) ...[
          _PlaceCard(
            key: LivePk4Panel.placeKey(s.seat),
            seat: s,
            format: lobby.format,
            colors: _placeColors(lobby.format, s.seat, ownTeam),
            selected: organiser && _place == s.seat,
            now: now,
            onTap: organiser && s.state == Pk4SeatState.empty
                ? () {
                    setState(() => _place = s.seat);
                    if (_list == null) unawaited(_load());
                  }
                : null,
            onWithdraw:
                organiser && s.state == Pk4SeatState.invited && s.invite != null
                ? () => unawaited(
                    _run(() => controller.cancelInvite(s.invite!.id)),
                  )
                : null,
          ),
          const SizedBox(height: KSpacing.xs),
        ],
      ],
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: column(ownTeam)),
        const SizedBox(width: KSpacing.sm),
        Expanded(child: column(ownTeam.other)),
      ],
    );
  }

  /// D395: the friends for the picked place — the same smaller list as the
  /// 1 v 1 tab ([PkFriendsHeader], [PkFriendRow]).
  Widget _candidates(
    BuildContext context,
    Pk4Lobby lobby,
    LivePk4Controller controller,
  ) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final place = _place;
    final open = place != null && lobby.seat(place).state == Pk4SeatState.empty;
    if (_list == null && _failure == null && open) unawaited(_load());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PkFriendsHeader(),
        const SizedBox(height: 2),
        Text(
          open
              ? l10n.pk4InviteTo(pk4SeatLabel(l10n, place, lobby.format))
              : l10n.pk4PickPlace,
          style: t.caption.copyWith(
            color: PkSheetMetrics.grey,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: KSpacing.xxs),
        if (open) ...[
          SizedBox(
            height: 36,
            child: TextField(
              key: LivePk4Panel.searchKey,
              textAlignVertical: TextAlignVertical.center,
              decoration: InputDecoration(
                isDense: true,
                hintText: l10n.pkSearchHint,
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                filled: true,
                fillColor: const Color(0xFFF3F3F6),
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(KRadius.pill),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) {
                _query = v;
                _debounce?.cancel();
                _debounce = Timer(
                  const Duration(milliseconds: 350),
                  () => unawaited(_load()),
                );
              },
            ),
          ),
          const SizedBox(height: KSpacing.xxs),
          Expanded(
            child: switch ((_list, _failure)) {
              (_, final Object _?) => Center(
                child: Text(l10n.pkNoCandidates, style: t.caption),
              ),
              (null, _) => const Center(child: CircularProgressIndicator()),
              (final list?, _) when list.isEmpty => Center(
                child: Text(
                  _query.isEmpty ? l10n.pkNoFriends : l10n.pkNoCandidates,
                  style: t.caption,
                  textAlign: TextAlign.center,
                ),
              ),
              (final list?, _) => ListView(
                padding: EdgeInsets.zero,
                children: [
                  for (final c in list)
                    PkFriendRow(
                      key: LivePk4Panel.candidateKey(c.roomId),
                      candidate: c,
                      onInvite: _busy
                          ? null
                          : () => unawaited(
                              _run(() async {
                                await controller.invite(c.roomId, place);
                                if (!mounted) return;
                                final next = ref
                                    .read(livePk4Provider(widget.roomId))
                                    .lobby;
                                setState(() {
                                  _place = next?.seats
                                      .where(
                                        (s) =>
                                            s.seat > 1 &&
                                            s.state == Pk4SeatState.empty,
                                      )
                                      .firstOrNull
                                      ?.seat;
                                });
                                unawaited(_load());
                              }),
                            ),
                    ),
                ],
              ),
            },
          ),
        ],
      ],
    );
  }
}

/// One place of the lobby: its role, the host (or «ادعُ مضيفاً»), its state.
class _PlaceCard extends StatelessWidget {
  const new({
    required this.seat,
    required this.format,
    required this.colors,
    required this.selected,
    required this.now,
    super.key,
    this.onTap,
    this.onWithdraw,
  });

  final Pk4LobbySeat seat;
  final Pk4Format format;
  final List<Color> colors;
  final bool selected;
  final DateTime now;
  final VoidCallback? onTap;
  final VoidCallback? onWithdraw;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final host = seat.host;
    final invite = seat.invite;
    final seconds = invite == null
        ? 0
        : invite.expiresAt.difference(now).inSeconds.clamp(0, 999);
    final status = switch (seat.state) {
      Pk4SeatState.accepted => l10n.pk4SeatReady,
      Pk4SeatState.invited => l10n.pk4SeatWaiting('$seconds'),
      Pk4SeatState.empty => l10n.pk4SeatInvite,
    };
    final role = pk4SeatLabel(l10n, seat.seat, format);
    return Semantics(
      button: onTap != null,
      selected: selected,
      label: [role, ?host?.displayName, status].join(' · '),
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(KRadius.md),
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.all(KSpacing.xs),
          decoration: BoxDecoration(
            color: colors[1].withValues(alpha: selected ? 0.16 : 0.07),
            borderRadius: BorderRadius.circular(KRadius.md),
            border: Border.all(
              color: selected ? colors[1] : colors[1].withValues(alpha: 0.35),
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              if (host != null)
                KAvatar(
                  name: host.displayName,
                  imageUrl: host.avatarUrl,
                  size: 34,
                )
              else
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: colors[1]),
                  ),
                  child: Icon(Icons.add_rounded, color: colors[1], size: 20),
                ),
              const SizedBox(width: KSpacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      role,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.caption.copyWith(
                        color: colors[2],
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      host?.displayName ?? status,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.label.copyWith(fontWeight: FontWeight.w700),
                    ),
                    if (host != null)
                      // Scaled down rather than cut, so the countdown of
                      // «بانتظار… 25» stays readable in a narrow place.
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          status,
                          maxLines: 1,
                          style: t.caption.copyWith(
                            color: seat.state == Pk4SeatState.accepted
                                ? context.palette.success
                                : context.palette.textSecondary,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (onWithdraw != null)
                IconButton(
                  key: LivePk4Panel.withdrawKey(seat.seat),
                  tooltip: l10n.pk4CancelInvite,
                  visualDensity: VisualDensity.compact,
                  onPressed: onWithdraw,
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// «{name} يدعوك إلى PK رباعي — {place}» over the invited host's room, with
/// the seconds left, «قبول» and «رفض».
class LivePk4IncomingInvite extends ConsumerStatefulWidget {
  const new({required this.roomId, required this.invite, super.key});

  final String roomId;
  final Pk4Invite invite;

  static const acceptKey = Key('pk4.incoming.accept');
  static const declineKey = Key('pk4.incoming.decline');

  @override
  ConsumerState<LivePk4IncomingInvite> createState() =>
      _LivePk4IncomingInviteState();
}

class _LivePk4IncomingInviteState extends ConsumerState<LivePk4IncomingInvite> {
  Timer? _tick;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (LivePkStage.ticks) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } on Object catch (e) {
      if (mounted) KSnack.error(context, pk4FailureMessage(context.l10n, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final controller = ref.read(livePk4Provider(widget.roomId).notifier);
    final now = ref.read(livePk4Provider(widget.roomId)).now();
    final seconds = widget.invite.expiresAt
        .difference(now)
        .inSeconds
        .clamp(0, 999);
    final white = KPalette.dark.textPrimary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
      child: Container(
        padding: const EdgeInsets.all(KSpacing.md),
        decoration: BoxDecoration(
          color: const Color(0xE61A0A06),
          borderRadius: BorderRadius.circular(KRadius.lg),
          border: Border.all(color: KLivePk4.endTeam[1].withValues(alpha: 0.6)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                KAvatar(
                  name: widget.invite.from.displayName,
                  imageUrl: widget.invite.from.avatarUrl,
                  size: 40,
                ),
                const SizedBox(width: KSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.pk4IncomingTitle,
                        style: t.label.copyWith(
                          color: white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        l10n.pk4IncomingBody(
                          KFormat.bidiIsolate(widget.invite.from.displayName),
                          pk4SeatLabel(
                            l10n,
                            widget.invite.seat,
                            widget.invite.format,
                          ),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: t.caption.copyWith(color: white),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: KSpacing.xs),
                Text(
                  '$seconds',
                  style: t.title.copyWith(
                    color: KLivePk4.endTeam[0],
                    fontWeight: FontWeight.w900,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: KSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: KButton(
                    key: LivePk4IncomingInvite.declineKey,
                    label: l10n.pkDecline,
                    variant: KButtonVariant.secondary,
                    onPressed: _busy
                        ? null
                        : () => unawaited(_run(controller.decline)),
                  ),
                ),
                const SizedBox(width: KSpacing.sm),
                Expanded(
                  child: KButton(
                    key: LivePk4IncomingInvite.acceptKey,
                    label: l10n.pkAccept,
                    loading: _busy,
                    onPressed: _busy
                        ? null
                        : () => unawaited(_run(controller.accept)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
