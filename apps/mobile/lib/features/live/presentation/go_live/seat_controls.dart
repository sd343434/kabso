import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
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
  static const viewersTab = Key('seat.viewers.tab');
  static const guestsTab = Key('seat.guests.tab');
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

/// Who is in the room (owner's reference): a white sheet with two tabs.
/// **Viewers**: everyone watching now (signed-in people and guests), with
/// make/remove moderator and an invite-to-seat button for signed-in people
/// not seated yet. **Guests**: who is on a seat. From
/// `GET /live/rooms/{roomId}/viewers` and the room's seats.
Future<void> showInviteViewers(
  BuildContext context, {
  required String roomId,
  required List<UserSummary> moderators,
  required Future<void> Function(String username) onInvite,
  required Future<void> Function(String username, {required bool moderator})
  onModerator,
  List<LiveSeat> seated = const [],
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: const Color(0x00000000),
  builder: (sheet) => _ViewersPanel(
    roomId: roomId,
    moderators: moderators,
    onInvite: onInvite,
    onModerator: onModerator,
    seated: [
      for (final s in seated)
        if (s.state == LiveSeatState.taken && s.user != null) s,
    ],
  ),
);

abstract final class _Panel {
  static const ink = Color(0xFF1C1B2E);
  static const soft = Color(0xFF8E8FA0);
  static const chip = Color(0xFFF2F3F7);
  static const accent = Color(0xFF6C4CF1);
}

class _ViewersPanel extends ConsumerStatefulWidget {
  const new({
    required this.roomId,
    required this.moderators,
    required this.onInvite,
    required this.onModerator,
    required this.seated,
  });

  final String roomId;
  final List<UserSummary> moderators;
  final Future<void> Function(String username) onInvite;
  final Future<void> Function(String username, {required bool moderator})
  onModerator;
  final List<LiveSeat> seated;

  @override
  ConsumerState<_ViewersPanel> createState() => _ViewersPanelState();
}

class _ViewersPanelState extends ConsumerState<_ViewersPanel> {
  late final Future<({List<LiveViewer> items, bool more})> _load = _fetch();
  late final Set<String> _moderators = {
    for (final m in widget.moderators) m.username,
  };

  /// Up to five pages of viewers.
  Future<({List<LiveViewer> items, bool more})> _fetch() async {
    final repo = ref.read(liveRepositoryProvider);
    final items = <LiveViewer>[];
    String? cursor;
    for (var page = 0; page < 5; page++) {
      final result = await repo.viewers(widget.roomId, cursor: cursor);
      items.addAll(result.items);
      cursor = result.next;
      if (cursor == null) break;
    }
    return (items: items, more: cursor != null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.textStyles;
    final tabStyle = text.bodyStrong.copyWith(fontSize: 17);
    return DefaultTabController(
      length: 2,
      child: Container(
        height: MediaQuery.sizeOf(context).height * 0.7,
        decoration: const BoxDecoration(
          color: Color(0xFFFFFFFF),
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: FutureBuilder<({List<LiveViewer> items, bool more})>(
          future: _load,
          builder: (context, snap) {
            final data = snap.data;
            final more = data != null && data.more ? '+' : '';
            final count = data == null
                ? ''
                : '${KFormat.grouped(data.items.length)}$more';
            final guests = '${widget.seated.length}';
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(8, 10, 4, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TabBar(
                          isScrollable: true,
                          tabAlignment: TabAlignment.start,
                          dividerColor: const Color(0x00000000),
                          labelColor: _Panel.ink,
                          unselectedLabelColor: _Panel.soft,
                          labelStyle: tabStyle.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                          unselectedLabelStyle: tabStyle,
                          indicatorSize: TabBarIndicatorSize.label,
                          indicator: const UnderlineTabIndicator(
                            borderSide: BorderSide(color: _Panel.ink, width: 3),
                            insets: EdgeInsets.symmetric(horizontal: 18),
                          ),
                          tabs: [
                            Tab(
                              key: SeatControlKeys.viewersTab,
                              text: l10n.liveViewersTab(count).trim(),
                            ),
                            Tab(
                              key: SeatControlKeys.guestsTab,
                              text: '${l10n.liveSeatGuestsTab} $guests',
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: l10n.liveClose,
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: _Panel.ink,
                          size: 28,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [_viewers(context, snap), _guests(context)],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _empty(BuildContext context, String message) => Center(
    child: Padding(
      padding: const EdgeInsets.all(KSpacing.xl),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: context.textStyles.body.copyWith(color: _Panel.soft),
      ),
    ),
  );

  Widget _viewers(
    BuildContext context,
    AsyncSnapshot<({List<LiveViewer> items, bool more})> snap,
  ) {
    final l10n = context.l10n;
    final data = snap.data;
    if (data == null) {
      return snap.hasError
          ? _empty(context, failureMessage(l10n, toAppFailure(snap.error!)))
          : const Center(child: CircularProgressIndicator());
    }
    if (data.items.isEmpty) return _empty(context, l10n.liveSeatInviteEmpty);
    final seatedIds = {for (final s in widget.seated) s.user!.id};
    return ListView(
      padding: const EdgeInsets.only(top: 6, bottom: 16),
      children: [
        for (final v in data.items)
          if (v.user case final u?)
            _row(
              context,
              name: u.displayName,
              handle: '@${u.username}',
              avatar: KAvatar(name: u.displayName, imageUrl: u.avatarUrl),
              actions: [
                _round(
                  key: SeatControlKeys.moderatorUser(u.username),
                  tooltip: _moderators.contains(u.username)
                      ? l10n.liveSeatRemoveModerator
                      : l10n.liveSeatMakeModerator,
                  icon: _moderators.contains(u.username)
                      ? Icons.shield_rounded
                      : Icons.add_moderator_outlined,
                  active: _moderators.contains(u.username),
                  onTap: () async {
                    final make = !_moderators.contains(u.username);
                    await runSeatAction(
                      context,
                      () => widget.onModerator(u.username, moderator: make),
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
                if (!seatedIds.contains(u.id))
                  _round(
                    key: SeatControlKeys.inviteUser(u.username),
                    tooltip: l10n.liveSeatInviteSend,
                    icon: Icons.chair_alt_outlined,
                    onTap: () => runSeatAction(
                      context,
                      () => widget.onInvite(u.username),
                      success: l10n.liveSeatInvited,
                    ),
                  ),
              ],
            )
          else
            _row(
              context,
              name: l10n.liveSeatGuestNumber(v.guestNumber ?? 0),
              avatar: const CircleAvatar(
                radius: 24,
                backgroundColor: _Panel.chip,
                child: Icon(Icons.person_outline_rounded, color: _Panel.soft),
              ),
            ),
      ],
    );
  }

  Widget _guests(BuildContext context) {
    final l10n = context.l10n;
    if (widget.seated.isEmpty) return _empty(context, l10n.liveSeatGuestsEmpty);
    return ListView(
      padding: const EdgeInsets.only(top: 6, bottom: 16),
      children: [
        for (final seat in widget.seated)
          _row(
            context,
            name: seat.user!.displayName,
            handle: l10n.liveSeatNumberLabel(seat.index),
            avatar: KAvatar(
              name: seat.user!.displayName,
              imageUrl: seat.user!.avatarUrl,
            ),
          ),
      ],
    );
  }

  Widget _row(
    BuildContext context, {
    required String name,
    required Widget avatar,
    String? handle,
    List<Widget> actions = const [],
  }) {
    final text = context.textStyles;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          avatar,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  KFormat.bidiIsolate(name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyStrong.copyWith(color: _Panel.ink),
                ),
                if (handle != null)
                  Text(
                    handle,
                    maxLines: 1,
                    style: text.caption.copyWith(color: _Panel.soft),
                  ),
              ],
            ),
          ),
          for (final a in actions) ...[const SizedBox(width: 8), a],
        ],
      ),
    );
  }

  Widget _round({
    required Key key,
    required String tooltip,
    required IconData icon,
    required VoidCallback onTap,
    bool active = false,
  }) => Semantics(
    button: true,
    label: tooltip,
    onTap: onTap,
    excludeSemantics: true,
    child: Tooltip(
      message: tooltip,
      child: GestureDetector(
        key: key,
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            color: _Panel.chip,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 22,
            color: active ? _Panel.accent : _Panel.ink,
          ),
        ),
      ),
    ),
  );
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
