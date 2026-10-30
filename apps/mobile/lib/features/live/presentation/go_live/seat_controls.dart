import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/format/k_handle.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/emoji/kabi_emoji.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/presentation/go_live/go_live_parts.dart';
import 'package:kabso_live/features/recharge/presentation/recharge_perks.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Seat controls for the host and moderators (CP-011, owner D94): a seat's
/// actions, the requests, inviting a viewer, and the seat count.
abstract final class SeatControlKeys {
  static const mute = Key('seat.action.mute');
  static const remove = Key('seat.action.remove');
  static const lock = Key('seat.action.lock');
  static const invite = Key('seat.action.invite');
  static const cancel = Key('seat.action.cancel');
  static const moderator = Key('seat.action.moderator');
  static Key accept(String id) => Key('seat.request.$id.accept');
  static Key decline(String id) => Key('seat.request.$id.decline');
  static Key inviteUser(String username) => Key('seat.invite.$username');
  static const viewersTab = Key('seat.viewers.tab');
  static const moderatorAction = Key('seat.moderator.action');
  static const guestsTab = Key('seat.guests.tab');
  static const contributionTab = Key('seat.contribution.tab');
  static Key contributor(String username) => Key('seat.contributor.$username');
  static Key moderatorUser(String username) => Key('seat.moderator.$username');
  static Key count(int count) => Key('seat.count.$count');
  static const inviteFriends = Key('seat.guests.inviteFriends');
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
  // Owner ref 72: a white action sheet, labels centred (17 pt, #29282B),
  // 60 pt rows, a hairline, then Cancel in grey.
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFFFFFFFF),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheet) {
      Widget row(Key? key, String label, Color color, VoidCallback onTap) =>
          InkWell(
            key: key,
            onTap: onTap,
            child: SizedBox(
              height: 60,
              child: Center(
                child: Text(
                  label,
                  style: sheet.textStyles.title.copyWith(
                    color: color,
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
      return SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 4.5),
            for (final a in actions)
              row(
                a.key,
                a.label,
                a.danger ? KPalette.light.error : const Color(0xFF29282B),
                () {
                  Navigator.of(sheet).pop();
                  unawaited(runSeatAction(context, a.onTap));
                },
              ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.3),
              child: Divider(height: 1, thickness: 1, color: Color(0xFFC7C7C7)),
            ),
            row(
              SeatControlKeys.cancel,
              l10n.actionCancel,
              const Color(0xFF868A8F),
              () => Navigator.of(sheet).pop(),
            ),
          ],
        ),
      );
    },
  );
}

/// Opens a person's card in a live: [moderator] is whether they moderate
/// this live, [onInvite] invites them to a seat (the host), and
/// [onModeratorChanged] tells the list when the card made or removed them.
typedef LivePersonCard = Future<void> Function(
  UserSummary user, {
  required bool moderator,
  VoidCallback? onInvite,
  ValueChanged<bool>? onModeratorChanged,
});

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
  int initialTab = 0,
  LivePersonCard? onPerson,
  Future<void> Function(LiveSeatRequest request)? onAccept,
  Future<void> Function(LiveSeatRequest request)? onDecline,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: const Color(0x00000000),
  // The reference leaves the room undimmed behind the sheet.
  barrierColor: const Color(0x00000000),
  builder: (sheet) => _ViewersPanel(
    roomId: roomId,
    moderators: moderators,
    onInvite: onInvite,
    onModerator: onModerator,
    initialTab: initialTab,
    onPerson: onPerson,
    onAccept: onAccept,
    onDecline: onDecline,
    seated: [
      for (final s in seated)
        if (s.state == LiveSeatState.taken && s.user != null) s,
    ],
  ),
);

/// D109 (v1.23.2-live): the same sheet for a viewer of the room, read-only —
/// who is watching now (people and guests), who is on a seat and the
/// Contribution list; no invite, no moderator choice and no seat requests.
/// Tapping a person opens their card ([onPerson]).
Future<void> showLiveViewers(
  BuildContext context, {
  required String roomId,
  List<UserSummary> moderators = const [],
  List<LiveSeat> seated = const [],
  int initialTab = 0,
  void Function(UserSummary user)? onPerson,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: const Color(0x00000000),
  barrierColor: const Color(0x00000000),
  builder: (sheet) => _ViewersPanel(
    roomId: roomId,
    moderators: moderators,
    onInvite: null,
    onModerator: null,
    initialTab: initialTab,
    onPerson: onPerson == null
        ? null
        : (u, {required moderator, onInvite, onModeratorChanged}) async =>
              onPerson(u),
    seated: [
      for (final s in seated)
        if (s.state == LiveSeatState.taken && s.user != null) s,
    ],
  ),
);

// Measured on the owner's reference (430 pt wide).
abstract final class _Panel {
  static const ink = Color(0xFF2E3130);
  static const soft = Color(0xFF9A9BA5);
  static const chip = Color(0xFFF5F7FB);
}

/// The selected tab's mark: a short rounded bar under the label's centre.
class _TabDot extends Decoration {
  const new();

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) => _TabDotPainter();
}

class _TabDotPainter extends BoxPainter {
  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size!;
    final rect = Rect.fromCenter(
      center: offset + Offset(size.width / 2, size.height - 3),
      width: 8,
      height: 3.3,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(2)),
      Paint()..color = _Panel.ink,
    );
  }
}

class _ViewersPanel extends ConsumerStatefulWidget {
  const new({
    required this.roomId,
    required this.moderators,
    required this.onInvite,
    required this.onModerator,
    required this.seated,
    this.initialTab = 0,
    this.onPerson,
    this.onAccept,
    this.onDecline,
  });

  /// Tapping a person: their card (kick, chat mute, make or remove
  /// moderator, …) with Invite to a seat when they are not on one.
  final LivePersonCard? onPerson;

  /// 0 viewers, 1 guests (the seat button), 2 contribution.
  final int initialTab;

  /// The host: the Guests tab lists the seat requests first, with Accept
  /// and Decline.
  final Future<void> Function(LiveSeatRequest request)? onAccept;
  final Future<void> Function(LiveSeatRequest request)? onDecline;
  final String roomId;
  final List<UserSummary> moderators;

  /// Null for a viewer (D109): the sheet is read-only.
  final Future<void> Function(String username)? onInvite;
  final Future<void> Function(String username, {required bool moderator})?
  onModerator;
  final List<LiveSeat> seated;

  /// A viewer's sheet (D109, [showLiveViewers]): nothing to invite or
  /// moderate.
  bool get readOnly => onInvite == null;

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
    final tabStyle = text.bodyStrong.copyWith(fontSize: 18, height: 1.2);
    return DefaultTabController(
      length: 3,
      initialIndex: widget.initialTab,
      child: Container(
        height: MediaQuery.sizeOf(context).height * 0.754,
        decoration: const BoxDecoration(
          color: Color(0xFFFFFFFF),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                // Measured on the reference: tab caps 21 pt below the top,
                // the mark 19.1 pt under them, ✕ centred 25.4 pt down and
                // 29.6 pt from the end; the first row 63.8 pt down.
                Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        21,
                        13.6,
                        60,
                        0,
                      ),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: TabBar(
                          isScrollable: true,
                          tabAlignment: TabAlignment.start,
                          padding: EdgeInsets.zero,
                          labelPadding: const EdgeInsetsDirectional.only(
                            end: 28.9,
                          ),
                          dividerColor: const Color(0x00000000),
                          labelColor: _Panel.ink,
                          unselectedLabelColor: _Panel.soft,
                          labelStyle: tabStyle.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                          unselectedLabelStyle: tabStyle.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                          indicatorSize: TabBarIndicatorSize.label,
                          indicator: const _TabDot(),
                          tabs: [
                            Tab(
                              key: SeatControlKeys.viewersTab,
                              height: 29.2,
                              text: l10n.liveViewersTab(count).trim(),
                            ),
                            Tab(
                              key: SeatControlKeys.guestsTab,
                              height: 29.2,
                              text: '${l10n.liveSeatGuestsTab} $guests',
                            ),
                            // CP-014: the live's top 50 by points (ref 75).
                            Tab(
                              key: SeatControlKeys.contributionTab,
                              height: 29.2,
                              text: l10n.liveContributionTab,
                            ),
                          ],
                        ),
                      ),
                    ),
                    PositionedDirectional(
                      top: 3.4,
                      end: 7.6,
                      child: IconButton(
                        tooltip: l10n.liveClose,
                        constraints: const BoxConstraints.tightFor(
                          width: 44,
                          height: 44,
                        ),
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: _Panel.ink,
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _viewers(context, snap),
                      _guests(context),
                      _contributors(context),
                    ],
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
              key: SeatControlKeys.moderatorUser(u.username),
              name: u.displayName,
              agentCode: u.rechargeAgentCode,
              handle: _moderators.contains(u.username)
                  ? '${KHandle.plain(u.username, premiumTier: u.premiumTier)}'
                        ' · ${l10n.liveSeatModeratorTag}'
                  : KHandle.plain(u.username, premiumTier: u.premiumTier),
              avatar: KAvatar(
                name: u.displayName,
                imageUrl: u.avatarUrl,
                size: 40,
              ),
              // Tapping the person: their card (the moderator choice is a
              // button there), else the moderator choice directly.
              onTap: switch ((widget.readOnly, widget.onPerson)) {
                (true, final card?) => () => unawaited(
                  card(u, moderator: _moderators.contains(u.username)),
                ),
                (true, null) => null,
                _ => () => unawaited(switch (widget.onPerson) {
                  final card? => card(
                    u,
                    moderator: _moderators.contains(u.username),
                    onModeratorChanged: (moderator) {
                      if (!mounted) return;
                      setState(
                        () => moderator
                            ? _moderators.add(u.username)
                            : _moderators.remove(u.username),
                      );
                    },
                    onInvite: seatedIds.contains(u.id)
                        ? null
                        : () => unawaited(
                            runSeatAction(
                              context,
                              () => widget.onInvite!(u.username),
                              success: context.l10n.liveSeatInvited,
                            ),
                          ),
                  ),
                  null => _moderatorMenu(context, u),
                }),
              },
              actions: [
                if (!widget.readOnly && !seatedIds.contains(u.id))
                  _round(
                    key: SeatControlKeys.inviteUser(u.username),
                    tooltip: l10n.liveSeatInviteSend,
                    // The owner's invite-to-seat icon (PROVENANCE.md).
                    // Drawn in the panel ink (#2E3130) in the file itself: a
                    // colour filter leaves seams where the strokes meet.
                    icon: SvgPicture.asset(
                      'assets/live_room_icons/seat_invite.svg',
                      width: 18.2,
                    ),
                    onTap: () => runSeatAction(
                      context,
                      () => widget.onInvite!(u.username),
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
                radius: 20,
                backgroundColor: _Panel.chip,
                child: Icon(Icons.person_outline_rounded, color: _Panel.soft),
              ),
            ),
      ],
    );
  }

  late Future<List<LiveSeatRequest>> _requests = _fetchRequests();

  Future<List<LiveSeatRequest>> _fetchRequests() async =>
      widget.onAccept == null
      ? const []
      : (await ref.read(liveRepositoryProvider).seatRequests(widget.roomId))
            .items;

  Future<void> _answer(Future<void> Function() action) async {
    await runSeatAction(context, action);
    if (!mounted) return;
    final next = _fetchRequests();
    setState(() {
      _requests = next;
    });
  }

  /// Nobody on a seat and no request: Kabi waves, and "Invite friends"
  /// opens the Viewers tab, where the host invites people onto a seat.
  Widget _noGuests(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(KSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Waves once (a looping animation never lets the sheet rest).
            KabiEmoji(KabsoEmoji.kabi('hi'), size: 96, repeat: false),
            const SizedBox(height: KSpacing.sm),
            Text(
              l10n.liveSeatGuestsEmpty,
              textAlign: TextAlign.center,
              style: context.textStyles.body.copyWith(color: _Panel.soft),
            ),
            if (!widget.readOnly) ...[
              const SizedBox(height: KSpacing.lg),
              FilledButton(
                key: SeatControlKeys.inviteFriends,
                style: FilledButton.styleFrom(
                  backgroundColor: KBrandColors.red500,
                  foregroundColor: _white,
                  minimumSize: const Size(180, 44),
                  shape: const StadiumBorder(),
                ),
                onPressed: () => DefaultTabController.of(context).animateTo(0),
                child: Text(l10n.liveSeatInviteFriends),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _guests(BuildContext context) {
    final l10n = context.l10n;
    return FutureBuilder<List<LiveSeatRequest>>(
      future: _requests,
      builder: (context, snap) {
        final requests = snap.data ?? const <LiveSeatRequest>[];
        if (snap.hasError) {
          return _empty(
            context,
            failureMessage(l10n, toAppFailure(snap.error!)),
          );
        }
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (requests.isEmpty && widget.seated.isEmpty) {
          return _noGuests(context);
        }
        return _guestList(context, requests);
      },
    );
  }

  Widget _guestList(BuildContext context, List<LiveSeatRequest> requests) {
    final l10n = context.l10n;
    final onAccept = widget.onAccept;
    final onDecline = widget.onDecline;
    return ListView(
      padding: const EdgeInsets.only(top: 6, bottom: 16),
      children: [
        for (final r in requests)
          _row(
            context,
            name: r.user.displayName,
            agentCode: r.user.rechargeAgentCode,
            handle: r.seatIndex == null
                ? KHandle.plain(
                    r.user.username,
                    premiumTier: r.user.premiumTier,
                  )
                : l10n.goLiveSeat(r.seatIndex! + 1),
            avatar: KAvatar(
              name: r.user.displayName,
              imageUrl: r.user.avatarUrl,
              size: 40,
            ),
            actions: [
              if (onDecline != null)
                TextButton(
                  key: SeatControlKeys.decline(r.id),
                  style: TextButton.styleFrom(foregroundColor: _Panel.soft),
                  onPressed: () => _answer(() => onDecline(r)),
                  child: Text(l10n.liveSeatDecline),
                ),
              if (onAccept != null)
                FilledButton(
                  key: SeatControlKeys.accept(r.id),
                  style: FilledButton.styleFrom(
                    backgroundColor: KBrandColors.red500,
                    foregroundColor: _white,
                    shape: const StadiumBorder(),
                  ),
                  onPressed: () => _answer(() => onAccept(r)),
                  child: Text(l10n.liveSeatAccept),
                ),
            ],
          ),
        for (final seat in widget.seated)
          _row(
            context,
            name: seat.user!.displayName,
            handle: l10n.liveSeatNumberLabel(seat.index),
            // D109: a viewer taps a seated person for their card.
            onTap: widget.readOnly && widget.onPerson != null
                ? () => unawaited(
                    widget.onPerson!(
                      seat.user!,
                      moderator: _moderators.contains(seat.user!.username),
                    ),
                  )
                : null,
            avatar: KAvatar(
              name: seat.user!.displayName,
              imageUrl: seat.user!.avatarUrl,
              size: 40,
            ),
          ),
      ],
    );
  }

  late final Future<List<LiveContributor>> _contribution = ref
      .read(liveRepositoryProvider)
      .contributors(widget.roomId);

  /// CP-014 (§10.12): up to 50 people by points given to this live.
  Widget _contributors(BuildContext context) {
    final l10n = context.l10n;
    return FutureBuilder<List<LiveContributor>>(
      future: _contribution,
      builder: (context, snap) {
        final list = snap.data;
        if (list == null) {
          return snap.hasError
              ? _empty(context, failureMessage(l10n, toAppFailure(snap.error!)))
              : const Center(child: CircularProgressIndicator());
        }
        if (list.isEmpty) return _empty(context, l10n.liveContributionEmpty);
        return ListView(
          padding: const EdgeInsets.only(top: 6, bottom: 16),
          children: [
            for (final (i, c) in list.indexed)
              Semantics(
                label: l10n.liveContributionRow(
                  i + 1,
                  c.user.displayName,
                  l10n.liveScore(c.points, KFormat.grouped(c.points)),
                ),
                excludeSemantics: true,
                child: _row(
                  context,
                  key: SeatControlKeys.contributor(c.user.username),
                  name: c.user.displayName,
                  handle: KHandle.plain(
                    c.user.username,
                    premiumTier: c.user.premiumTier,
                  ),
                  avatar: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 22,
                        child: Text(
                          '${i + 1}',
                          textAlign: TextAlign.center,
                          style: context.textStyles.bodyStrong.copyWith(
                            color: i < 3 ? KScoreChip.flame : _Panel.soft,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      KAvatar(
                        name: c.user.displayName,
                        imageUrl: c.user.avatarUrl,
                        size: 40,
                      ),
                    ],
                  ),
                  actions: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const KCherryIcon(size: 16),
                        const SizedBox(width: 3),
                        Text(
                          KFormat.compact(c.points, l10n),
                          style: context.textStyles.bodyStrong.copyWith(
                            color: _Panel.ink,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _moderatorMenu(BuildContext context, UserSummary u) async {
    final l10n = context.l10n;
    final isModerator = _moderators.contains(u.username);
    final go = await showModalBottomSheet<bool>(
      context: context,
      builder: (sheet) => SafeArea(
        child: ListTile(
          key: SeatControlKeys.moderatorAction,
          leading: Icon(
            isModerator ? Icons.remove_moderator_outlined : Icons.add_moderator,
          ),
          title: Text(
            isModerator
                ? l10n.liveSeatRemoveModerator
                : l10n.liveSeatMakeModerator,
          ),
          onTap: () => Navigator.of(sheet).pop(true),
        ),
      ),
    );
    if (go != true || !context.mounted) return;
    await runSeatAction(
      context,
      () => widget.onModerator!(u.username, moderator: !isModerator),
    );
    if (mounted) {
      setState(
        () => isModerator
            ? _moderators.remove(u.username)
            : _moderators.add(u.username),
      );
    }
  }

  Widget _row(
    BuildContext context, {
    required String name,
    required Widget avatar,
    Key? key,
    String? handle,
    String? agentCode,
    VoidCallback? onTap,
    List<Widget> actions = const [],
  }) {
    final text = context.textStyles;
    final row = Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 11.7, 16.2, 11.7),
      child: Row(
        children: [
          avatar,
          const SizedBox(width: 16.4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        KFormat.bidiIsolate(name),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodyStrong.copyWith(
                          color: _Panel.ink,
                          fontSize: 16.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    // D185 (owner): a recharge agent's badge after the name.
                    RechargeAgentInlineBadge(code: agentCode, height: 18),
                  ],
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
    if (onTap == null) return KeyedSubtree(key: key, child: row);
    return InkWell(key: key, onTap: onTap, child: row);
  }

  Widget _round({
    required Key key,
    required String tooltip,
    required Widget icon,
    required VoidCallback onTap,
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
        // 36 pt circle in a 44 pt target.
        child: SizedBox.square(
          dimension: 44,
          child: Center(
            child: Container(
              width: 36.3,
              height: 36.3,
              decoration: const BoxDecoration(
                color: _Panel.chip,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: icon,
            ),
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
}) => showLiveSeatCountPicker(
  context,
  counts: counts,
  selected: selected,
  onSelect: (c) => unawaited(runSeatAction(context, () => onSelect(c))),
);

/// Number of seats (owner ref 66): a white sheet, the title centred, one
/// pill per allowed count, the chosen one framed in teal. Closes on a pick.
Future<void> showLiveSeatCountPicker(
  BuildContext context, {
  required List<int> counts,
  required int selected,
  required ValueChanged<int> onSelect,
}) => showModalBottomSheet<void>(
  context: context,
  backgroundColor: const Color(0xFFFFFFFF),
  // The reference leaves the room undimmed behind the sheet.
  barrierColor: const Color(0x00000000),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
  ),
  builder: (sheet) {
    final l10n = sheet.l10n;
    final text = sheet.textStyles;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20.5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LiveWhiteSheetHeader(title: l10n.liveSeatsTitle, centred: true),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  for (final (i, c) in counts.indexed) ...[
                    // D100: five audio sizes share the row with a tighter gap.
                    if (i > 0) SizedBox(width: counts.length > 4 ? 8 : 13),
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: c == selected,
                        label: l10n.goLiveSeatCount(c),
                        excludeSemantics: true,
                        child: GestureDetector(
                          key: GoLiveKeys.seatCount(c),
                          onTap: () {
                            Navigator.of(sheet).pop();
                            onSelect(c);
                          },
                          child: Container(
                            height: 39.6,
                            decoration: BoxDecoration(
                              color: c == selected
                                  ? const Color(0xFFFFFFFF)
                                  : const Color(0xFFF4F6FA),
                              borderRadius: BorderRadius.circular(19.8),
                              border: Border.all(
                                color: c == selected
                                    ? const Color(0xFF34CAC0)
                                    : const Color(0x00000000),
                                width: 1.2,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SvgPicture.asset(
                                    'assets/live_room_icons/seat_outline.svg',
                                    width: 17.7,
                                    colorFilter: ColorFilter.mode(
                                      c == selected
                                          ? const Color(0xFF3B3B3B)
                                          : const Color(0xFF9A9BA5),
                                      BlendMode.srcIn,
                                    ),
                                  ),
                                  const SizedBox(width: 9),
                                  Text(
                                    '$c',
                                    style: text.title.copyWith(
                                      color: const Color(0xFF3B3B3B),
                                      fontSize: 17,
                                      fontWeight: FontWeight.w500,
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  },
);
