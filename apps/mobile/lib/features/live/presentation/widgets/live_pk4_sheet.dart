import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/app_failure.dart';
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
String pk4FailureMessage(AppLocalizations l10n, Object error) {
  final failure = toAppFailure(error);
  final code = failure is ServerFailure ? failure.rawCode : null;
  return switch (code) {
    'PK_LOBBY_CLOSED' => l10n.pk4ErrorLobbyClosed,
    'PK_SEAT_TAKEN' => l10n.pk4ErrorSeatTaken,
    _ => pkFailureMessage(l10n, error),
  };
}

/// The label of a place (1 organiser, 2 teammate, 3–4 opponents).
String pk4SeatLabel(AppLocalizations l10n, int seat) => switch (seat) {
  1 => l10n.pk4SeatOrganiser,
  2 => l10n.pk4SeatTeammate,
  _ => l10n.pk4SeatOpponent,
};

/// «PK رباعي» (v1.118-live, D391, §10.180): the host's lobby sheet, opened
/// from the PK sheet's «PK رباعي» card — the four places in two team columns
/// (this team on the reading start), each place's state (empty, invited with
/// its seconds, ready), the lobby's countdown, the candidates for the picked
/// place («الأصدقاء» or a search), and cancel / leave.
Future<void> showLivePk4Sheet(BuildContext context, {required String roomId}) {
  final container = ProviderScope.containerOf(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0x00000000),
    barrierColor: const Color(0x33000000),
    builder: (sheet) => UncontrolledProviderScope(
      container: container,
      child: Theme(
        data: buildAppTheme(
          brightness: Brightness.light,
          locale: Localizations.localeOf(sheet),
        ),
        child: LivePk4Sheet(roomId: roomId),
      ),
    ),
  );
}

class LivePk4Sheet extends ConsumerStatefulWidget {
  const new({required this.roomId, super.key});

  final String roomId;

  static const sheetKey = Key('pk4.sheet');
  static const openKey = Key('pk4.sheet.open');
  static const cancelKey = Key('pk4.sheet.cancel');
  static const leaveKey = Key('pk4.sheet.leave');
  static const searchKey = Key('pk4.sheet.search');
  static const countdownKey = Key('pk4.sheet.countdown');
  static const startKey = Key('pk4.sheet.start');
  static const endKey = Key('pk4.sheet.end');
  static const endConfirmKey = Key('pk4.end.confirm');
  static Key placeKey(int seat) => Key('pk4.sheet.place.$seat');
  static Key withdrawKey(int seat) => Key('pk4.sheet.withdraw.$seat');
  static Key candidateKey(String roomId) => Key('pk4.sheet.candidate.$roomId');

  @override
  ConsumerState<LivePk4Sheet> createState() => _LivePk4SheetState();
}

class _LivePk4SheetState extends ConsumerState<LivePk4Sheet> {
  String _query = '';
  int? _place;
  bool _busy = false;
  Timer? _debounce;
  Timer? _tick;
  List<PkCandidate>? _list;
  Object? _failure;
  int _reads = 0;

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
    final pk4 = ref.watch(livePk4Provider(widget.roomId));
    final controller = ref.read(livePk4Provider(widget.roomId).notifier);
    final lobby = pk4.lobby;
    final organiser = lobby?.organiserRoomId == widget.roomId;
    final height = MediaQuery.sizeOf(context).height * 0.75;
    final t = context.textStyles;
    // ignore: invalid_use_of_visible_for_testing_member, the goldens' clock pin (D231).
    final now = (LivePkStage.debugNow ?? pk4.now)();
    return Material(
      key: LivePk4Sheet.sheetKey,
      color: context.palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(PkSheetMetrics.radius),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: height,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: KSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.pk4Title,
                            style: t.title.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            l10n.pk4Subtitle,
                            style: t.caption.copyWith(
                              color: context.palette.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (lobby != null)
                      Container(
                        key: LivePk4Sheet.countdownKey,
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
                    IconButton(
                      tooltip: MaterialLocalizations.of(context)
                          .closeButtonLabel,
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: KSpacing.md),
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
                      key: LivePk4Sheet.startKey,
                      label: l10n.pkStart,
                      loading: _busy,
                      onPressed: () => unawaited(_run(controller.start)),
                    ),
                    const SizedBox(height: KSpacing.sm),
                  ],
                  KButton(
                    key: LivePk4Sheet.endKey,
                    label: l10n.pkEnd,
                    variant: KButtonVariant.secondary,
                    onPressed: () => unawaited(_confirmEnd(match, controller)),
                  ),
                  const Spacer(),
                ] else if (lobby == null) ...[
                  Text(l10n.pk4LobbyHint, style: t.body),
                  const SizedBox(height: KSpacing.lg),
                  KButton(
                    key: LivePk4Sheet.openKey,
                    label: l10n.pk4OpenLobby,
                    loading: _busy,
                    onPressed: () => unawaited(
                      _run(() async {
                        await controller.openLobby();
                        _place = 2;
                        unawaited(_load());
                      }),
                    ),
                  ),
                  const Spacer(),
                ] else ...[
                  _places(context, lobby, now, organiser, controller),
                  const SizedBox(height: KSpacing.md),
                  if (organiser)
                    Expanded(child: _candidates(context, lobby, controller))
                  else
                    const Spacer(),
                  const SizedBox(height: KSpacing.sm),
                  KButton(
                    key: organiser
                        ? LivePk4Sheet.cancelKey
                        : LivePk4Sheet.leaveKey,
                    label: organiser ? l10n.pk4CancelLobby : l10n.pk4LeaveLobby,
                    variant: KButtonVariant.secondary,
                    onPressed: () => unawaited(
                      _run(() async {
                        final navigator = Navigator.of(context);
                        await controller.closeLobby();
                        if (mounted) await navigator.maybePop();
                      }),
                    ),
                  ),
                  const SizedBox(height: KSpacing.sm),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// During the battle: «ستغادر المعركة ويكمل زميلك وحده» first.
  Future<void> _confirmEnd(Pk4Match match, LivePk4Controller controller) async {
    final l10n = context.l10n;
    if (match.status == PkMatchStatus.battle) {
      final ok = await showKLiveConfirm(
        context,
        title: l10n.pkEndConfirmTitle,
        message: l10n.pk4EndConfirmBody,
        confirmKey: LivePk4Sheet.endConfirmKey,
        confirmLabel: l10n.pkEnd,
        cancelLabel: l10n.pkCancel,
      );
      if (!ok) return;
    }
    await _run(controller.end);
    if (mounted) await Navigator.of(context).maybePop();
  }

  static Duration _left(DateTime until, DateTime now) {
    final d = until.difference(now);
    return d.isNegative ? Duration.zero : Duration(seconds: d.inSeconds);
  }

  /// The four places in two team columns: this host's team on the start.
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
    final ownTeam = mine?.team ?? Pk4Team.a;
    Widget column(Pk4Team team, List<Color> colors) => Column(
      children: [
        for (final s in lobby.seats.where((s) => s.team == team)) ...[
          _PlaceCard(
            key: LivePk4Sheet.placeKey(s.seat),
            seat: s,
            colors: colors,
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
        Expanded(child: column(ownTeam, KLivePk4.startTeam)),
        const SizedBox(width: KSpacing.sm),
        Expanded(child: column(ownTeam.other, KLivePk4.endTeam)),
      ],
    );
  }

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
        Text(
          open
              ? l10n.pk4InviteTo(pk4SeatLabel(l10n, place))
              : l10n.pk4PickPlace,
          style: t.label.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: KSpacing.xs),
        if (open) ...[
          TextField(
            key: LivePk4Sheet.searchKey,
            decoration: InputDecoration(
              isDense: true,
              hintText: l10n.pkSearchHint,
              prefixIcon: const Icon(Icons.search_rounded),
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
          const SizedBox(height: KSpacing.xs),
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
                children: [
                  for (final c in list)
                    ListTile(
                      key: LivePk4Sheet.candidateKey(c.roomId),
                      contentPadding: EdgeInsets.zero,
                      leading: KAvatar(
                        name: c.host.displayName,
                        imageUrl: c.host.avatarUrl,
                        size: 40,
                      ),
                      title: Text(
                        c.host.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        c.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: KButton(
                        label: l10n.pkInvite,
                        expand: false,
                        onPressed: _busy
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
    required this.colors,
    required this.selected,
    required this.now,
    super.key,
    this.onTap,
    this.onWithdraw,
  });

  final Pk4LobbySeat seat;
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
    return Semantics(
      button: onTap != null,
      selected: selected,
      label: [
        pk4SeatLabel(l10n, seat.seat),
        ?host?.displayName,
        status,
      ].join(' · '),
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(KRadius.md),
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
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
                  size: 36,
                )
              else
                Container(
                  width: 36,
                  height: 36,
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
                      pk4SeatLabel(l10n, seat.seat),
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
                  key: LivePk4Sheet.withdrawKey(seat.seat),
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
                          pk4SeatLabel(l10n, widget.invite.seat),
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
