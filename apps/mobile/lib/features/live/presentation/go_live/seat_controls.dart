import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/presentation/go_live/go_live_parts.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Seat controls for the host and moderators (CP-011, owner D94): a seat's
/// actions, the requests, inviting a viewer, and the seat count.
abstract final class SeatControlKeys {
  static const mute = Key('seat.action.mute');
  static const remove = Key('seat.action.remove');
  static const lock = Key('seat.action.lock');
  static const invite = Key('seat.action.invite');
  static const moderator = Key('seat.action.moderator');
  static Key accept(String id) => Key('seat.request.$id.accept');
  static Key decline(String id) => Key('seat.request.$id.decline');
  static Key inviteUser(String username) => Key('seat.invite.$username');
  static Key moderatorUser(String username) => Key('seat.moderator.$username');
  static Key count(int count) => Key('seat.count.$count');
}

const _white = Color(0xFFFFFFFF);

/// Runs [action]; a failure shows its message as a snack.
Future<void> runSeatAction(
  BuildContext context,
  Future<void> Function() action, {
  String? success,
}) async {
  final l10n = context.l10n;
  try {
    await action();
    if (success != null && context.mounted) KSnack.info(context, success);
  } on Object catch (e) {
    if (context.mounted) {
      KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
    }
  }
}

class _Action {
  const new(this.key, this.icon, this.label, this.onTap, {this.danger = false});

  final Key key;
  final IconData icon;
  final String label;
  final Future<void> Function() onTap;
  final bool danger;
}

/// The actions on seat [seat]: lock / unlock or invite (empty, host),
/// mute / unmute and take off (taken; a moderator never acts on another
/// moderator), make / remove moderator (host).
Future<void> showSeatActions(
  BuildContext context, {
  required LiveSeat seat,
  required bool isHost,
  required List<UserSummary> moderators,
  required Future<void> Function({required bool muted}) onMute,
  required Future<void> Function() onRemove,
  required Future<void> Function({required bool locked}) onLock,
  required Future<void> Function(String username, {required bool moderator})
  onModerator,
  Future<void> Function()? onInvite,
}) {
  final l10n = context.l10n;
  final user = seat.user;
  final targetIsModerator =
      user != null && moderators.any((m) => m.id == user.id);
  final actions = <_Action>[
    if (seat.state == LiveSeatState.taken && user != null) ...[
      if (isHost || !targetIsModerator) ...[
        _Action(
          SeatControlKeys.mute,
          seat.mutedByHost ? Icons.mic_rounded : Icons.mic_off_rounded,
          seat.mutedByHost ? l10n.liveSeatUnmute : l10n.liveSeatMute,
          () => onMute(muted: !seat.mutedByHost),
        ),
        _Action(
          SeatControlKeys.remove,
          Icons.event_seat_outlined,
          l10n.liveSeatRemove,
          onRemove,
          danger: true,
        ),
      ],
      if (isHost)
        _Action(
          SeatControlKeys.moderator,
          targetIsModerator
              ? Icons.remove_moderator_outlined
              : Icons.add_moderator_outlined,
          targetIsModerator
              ? l10n.liveSeatRemoveModerator
              : l10n.liveSeatMakeModerator,
          () => onModerator(user.username, moderator: !targetIsModerator),
        ),
    ],
    if (seat.state == LiveSeatState.empty && onInvite != null)
      _Action(
        SeatControlKeys.invite,
        Icons.person_add_alt_1_rounded,
        l10n.liveSeatInvite,
        onInvite,
      ),
    if (isHost && seat.state != LiveSeatState.taken)
      _Action(
        SeatControlKeys.lock,
        seat.state == LiveSeatState.locked
            ? Icons.lock_open_rounded
            : Icons.lock_rounded,
        seat.state == LiveSeatState.locked
            ? l10n.liveSeatUnlock
            : l10n.liveSeatLock,
        () => onLock(locked: seat.state != LiveSeatState.locked),
      ),
  ];
  if (actions.isEmpty) return Future.value();
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0x00000000),
    builder: (sheet) => LiveSheetFrame(
      title: user?.displayName ?? l10n.goLiveSeat(seat.index + 1),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final a in actions)
            ListTile(
              key: a.key,
              leading: Icon(
                a.icon,
                color: a.danger ? KPalette.dark.error : _white,
              ),
              title: Text(
                a.label,
                style: sheet.textStyles.bodyStrong.copyWith(
                  color: a.danger ? KPalette.dark.error : _white,
                ),
              ),
              onTap: () {
                Navigator.of(sheet).pop();
                unawaited(runSeatAction(context, a.onTap));
              },
            ),
        ],
      ),
    ),
  );
}

/// The pending requests, oldest first, with Accept and Decline.
Future<void> showSeatRequests(
  BuildContext context, {
  required String roomId,
  required Future<void> Function(LiveSeatRequest request) onAccept,
  required Future<void> Function(LiveSeatRequest request) onDecline,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: const Color(0x00000000),
  builder: (sheet) => LiveSheetFrame(
    title: sheet.l10n.liveSeatRequestsTitle,
    child: _RequestList(
      roomId: roomId,
      onAccept: onAccept,
      onDecline: onDecline,
    ),
  ),
);

class _RequestList extends ConsumerStatefulWidget {
  const new({
    required this.roomId,
    required this.onAccept,
    required this.onDecline,
  });

  final String roomId;
  final Future<void> Function(LiveSeatRequest request) onAccept;
  final Future<void> Function(LiveSeatRequest request) onDecline;

  @override
  ConsumerState<_RequestList> createState() => _RequestListState();
}

class _RequestListState extends ConsumerState<_RequestList> {
  late Future<List<LiveSeatRequest>> _load = _fetch();

  Future<List<LiveSeatRequest>> _fetch() async =>
      (await ref.read(liveRepositoryProvider).seatRequests(widget.roomId))
          .items;

  Future<void> _act(Future<void> Function() action) async {
    await runSeatAction(context, action);
    if (!mounted) return;
    final next = _fetch();
    setState(() {
      _load = next;
    });
    // The last request handled: nothing left to do here, the sheet closes.
    try {
      if ((await next).isEmpty && mounted) {
        await Navigator.of(context).maybePop();
      }
    } on Object {
      // The list shows the failure.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.textStyles;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.5,
      ),
      child: FutureBuilder<List<LiveSeatRequest>>(
        future: _load,
        builder: (context, snap) {
          final items = snap.data;
          if (items == null) {
            return snap.hasError
                ? Padding(
                    padding: const EdgeInsets.all(KSpacing.lg),
                    child: Text(
                      failureMessage(l10n, toAppFailure(snap.error!)),
                      style: text.body.copyWith(color: _white),
                    ),
                  )
                : const Padding(
                    padding: EdgeInsets.all(KSpacing.xl),
                    child: CircularProgressIndicator(),
                  );
          }
          if (items.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(KSpacing.xl),
              child: Text(
                l10n.liveSeatRequestsEmpty,
                style: text.body.copyWith(
                  color: _white.withValues(alpha: 0.75),
                ),
              ),
            );
          }
          return ListView(
            shrinkWrap: true,
            children: [
              for (final r in items)
                ListTile(
                  leading: KAvatar(
                    name: r.user.displayName,
                    imageUrl: r.user.avatarUrl,
                    size: 40,
                  ),
                  title: Text(
                    r.user.displayName,
                    style: text.bodyStrong.copyWith(color: _white),
                  ),
                  subtitle: r.seatIndex == null
                      ? null
                      : Text(
                          l10n.goLiveSeat(r.seatIndex! + 1),
                          style: text.caption.copyWith(
                            color: _white.withValues(alpha: 0.7),
                          ),
                        ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        key: SeatControlKeys.decline(r.id),
                        onPressed: () => _act(() => widget.onDecline(r)),
                        child: Text(l10n.liveSeatDecline),
                      ),
                      const SizedBox(width: KSpacing.xs),
                      FilledButton(
                        key: SeatControlKeys.accept(r.id),
                        onPressed: () => _act(() => widget.onAccept(r)),
                        child: Text(l10n.liveSeatAccept),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// The host's viewers (signed-in only; guests cannot sit): invite one onto
/// a seat, or make them a moderator.
Future<void> showInviteViewers(
  BuildContext context, {
  required String roomId,
  required List<UserSummary> moderators,
  required Future<void> Function(String username) onInvite,
  required Future<void> Function(String username, {required bool moderator})
  onModerator,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: const Color(0x00000000),
  builder: (sheet) => LiveSheetFrame(
    title: sheet.l10n.liveSeatInviteSheetTitle,
    child: _ViewerList(
      roomId: roomId,
      moderators: moderators,
      onInvite: onInvite,
      onModerator: onModerator,
    ),
  ),
);

class _ViewerList extends ConsumerStatefulWidget {
  const new({
    required this.roomId,
    required this.moderators,
    required this.onInvite,
    required this.onModerator,
  });

  final String roomId;
  final List<UserSummary> moderators;
  final Future<void> Function(String username) onInvite;
  final Future<void> Function(String username, {required bool moderator})
  onModerator;

  @override
  ConsumerState<_ViewerList> createState() => _ViewerListState();
}

class _ViewerListState extends ConsumerState<_ViewerList> {
  late final Future<List<UserSummary>> _load = _fetch();
  late final Set<String> _moderators = {
    for (final m in widget.moderators) m.username,
  };

  Future<List<UserSummary>> _fetch() async {
    final page = await ref.read(liveRepositoryProvider).viewers(widget.roomId);
    return [
      for (final v in page.items)
        if (v.kind == LiveViewerKind.user && v.user != null) v.user!,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.textStyles;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.5,
      ),
      child: FutureBuilder<List<UserSummary>>(
        future: _load,
        builder: (context, snap) {
          final users = snap.data;
          if (users == null) {
            return snap.hasError
                ? Padding(
                    padding: const EdgeInsets.all(KSpacing.lg),
                    child: Text(
                      failureMessage(l10n, toAppFailure(snap.error!)),
                      style: text.body.copyWith(color: _white),
                    ),
                  )
                : const Padding(
                    padding: EdgeInsets.all(KSpacing.xl),
                    child: CircularProgressIndicator(),
                  );
          }
          if (users.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(KSpacing.xl),
              child: Text(
                l10n.liveSeatInviteEmpty,
                style: text.body.copyWith(
                  color: _white.withValues(alpha: 0.75),
                ),
              ),
            );
          }
          return ListView(
            shrinkWrap: true,
            children: [
              for (final u in users)
                ListTile(
                  leading: KAvatar(
                    name: u.displayName,
                    imageUrl: u.avatarUrl,
                    size: 40,
                  ),
                  title: Text(
                    u.displayName,
                    style: text.bodyStrong.copyWith(color: _white),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        key: SeatControlKeys.moderatorUser(u.username),
                        tooltip: _moderators.contains(u.username)
                            ? l10n.liveSeatRemoveModerator
                            : l10n.liveSeatMakeModerator,
                        icon: Icon(
                          _moderators.contains(u.username)
                              ? Icons.shield_rounded
                              : Icons.add_moderator_outlined,
                          color: _white,
                        ),
                        onPressed: () async {
                          final make = !_moderators.contains(u.username);
                          await runSeatAction(
                            context,
                            () =>
                                widget.onModerator(u.username, moderator: make),
                          );
                          if (mounted) {
                            setState(
                              () => make
                                  ? _moderators.add(u.username)
                                  : _moderators.remove(u.username),
                            );
                          }
                        },
                      ),
                      FilledButton(
                        key: SeatControlKeys.inviteUser(u.username),
                        onPressed: () => runSeatAction(
                          context,
                          () => widget.onInvite(u.username),
                          success: l10n.liveSeatInvited,
                        ),
                        child: Text(l10n.liveSeatInviteSend),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// The seat count while live (host): smaller than an occupied seat is
/// refused by the server (`LIVE_SEAT_UNAVAILABLE`).
Future<void> showSeatCountSheet(
  BuildContext context, {
  required List<int> counts,
  required int selected,
  required Future<void> Function(int count) onSelect,
  required Color accent,
}) => showModalBottomSheet<void>(
  context: context,
  backgroundColor: const Color(0x00000000),
  builder: (sheet) => LiveSheetFrame(
    title: sheet.l10n.liveSeatsTitle,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: KSpacing.sm),
      child: GoLiveSeatCountPicker(
        counts: counts,
        selected: selected,
        accent: accent,
        onSelect: (c) {
          Navigator.of(sheet).pop();
          unawaited(runSeatAction(context, () => onSelect(c)));
        },
      ),
    ),
  ),
);
