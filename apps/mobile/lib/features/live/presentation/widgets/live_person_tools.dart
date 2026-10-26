import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/application/live_chat_controller.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/safety/safety_actions.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Someone's part in a live: the host, a moderator of this live, or anyone
/// else (viewers, seated guests, guests without an account).
enum LivePersonRole { host, moderator, viewer }

/// What a person's card in a live knows about the room (owner, 2026-10-26):
/// the room, the role of the one looking ([viewer]) and of the person shown
/// ([target]), and what the host and moderators can do from it.
@immutable
class LivePersonScope {
  const new({
    required this.roomId,
    this.viewer = LivePersonRole.viewer,
    this.target = LivePersonRole.viewer,
    this.onModerator,
    this.onKicked,
    this.seat,
    this.onSeatMute,
  });

  final String roomId;
  final LivePersonRole viewer;
  final LivePersonRole target;

  /// The host: makes or removes a moderator (throws an AppFailure).
  final Future<void> Function(String username, {required bool moderator})?
  onModerator;

  /// After a kick: the seats and lists are read again.
  final VoidCallback? onKicked;

  /// The person's seat when they sit on the mic (audio) or are a guest
  /// (video); null otherwise.
  final LiveSeat? seat;

  /// Mutes or unmutes that seat's microphone (`POST …/seats/{index}/mute`,
  /// CP-011; throws an AppFailure).
  final Future<void> Function(int index, {required bool muted})? onSeatMute;

  /// Kicking and chat muting (§10.20, §10.11): the host acts on anyone but
  /// themselves; a moderator never on the host or another moderator.
  bool canModerate(LivePersonRole target) => switch (viewer) {
    LivePersonRole.host => target != LivePersonRole.host,
    LivePersonRole.moderator => target == LivePersonRole.viewer,
    LivePersonRole.viewer => false,
  };
}

abstract final class LivePersonToolKeys {
  static const points = Key('room.userCard.points');
  static const kick = Key('room.userCard.kick');
  static const kickConfirm = Key('room.userCard.kickConfirm');
  static const mute = Key('room.userCard.mute');
  static const micMute = Key('room.userCard.micMute');
  static const admin = Key('room.userCard.admin');
  static const more = Key('room.userCard.more');
  static const report = Key('room.userCard.report');
  static const block = Key('room.userCard.block');
  static const pointsPopover = Key('room.userCard.pointsPopover');
}

/// The person on the card.
typedef LivePersonTarget = ({String id, String username, String name});

/// The card's top row (owner's reference): small outline buttons at the
/// start — points (everyone), kick (the host and moderators, when the person
/// may be acted on), make or remove moderator (the host) — and at the end,
/// next to ⋯ (report, block), the two mutes (owner, 2026-10-26): the mic of
/// a seated person or guest, and writing in the chat. On your own card:
/// points only.
/// [middle] keeps the picture's place free between the two groups.
class LivePersonTools extends ConsumerStatefulWidget {
  const new({
    required this.scope,
    required this.person,
    required this.self,
    required this.middle,
    super.key,
  });

  final LivePersonScope scope;
  final LivePersonTarget person;
  final bool self;
  final double middle;

  @override
  ConsumerState<LivePersonTools> createState() => _LivePersonToolsState();
}

class _LivePersonToolsState extends ConsumerState<LivePersonTools> {
  static const _ink = Color(0xFF5B5E66);
  static const _danger = Color(0xFFE5484D);
  static const _on = Color(0xFFD9922E);

  late LivePersonRole _target = widget.scope.target;

  /// Whether the person is muted in this live's chat; null until known.
  bool? _muted;
  late bool _micMuted = widget.scope.seat?.mutedByHost ?? false;
  bool _busy = false;

  LivePersonScope get _scope => widget.scope;

  bool get _moderates => !widget.self && _scope.canModerate(_target);

  bool get _canAdmin =>
      !widget.self &&
      _scope.viewer == LivePersonRole.host &&
      _target != LivePersonRole.host &&
      _scope.onModerator != null;

  bool get _canMuteSeat =>
      _moderates && _scope.seat != null && _scope.onSeatMute != null;

  bool get _signedIn => ref.read(currentUserProvider) != null;

  @override
  void initState() {
    super.initState();
    if (_moderates) unawaited(_loadMuted());
  }

  Future<void> _loadMuted() async {
    try {
      final mutes = await ref
          .read(liveChatProvider(_scope.roomId).notifier)
          .mutes();
      if (!mounted) return;
      setState(() => _muted = mutes.any((m) => m.user.id == widget.person.id));
    } on Object {
      // Offer muting; the server answers either way (idempotent).
      if (mounted) setState(() => _muted = false);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } on Object catch (e) {
      if (mounted) {
        KSnack.error(context, failureMessage(context.l10n, toAppFailure(e)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _closeCard() {
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _kick() async {
    final l10n = context.l10n;
    final name = KFormat.bidiIsolate(widget.person.name);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l10n.liveUserKickTitle(name)),
        content: Text(l10n.liveUserKickBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            key: LivePersonToolKeys.kickConfirm,
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(
              l10n.liveUserKickConfirm,
              style: const TextStyle(color: _danger),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _run(() async {
      await ref
          .read(liveRepositoryProvider)
          .kick(_scope.roomId, widget.person.username);
      if (!mounted) return;
      KSnack.success(context, l10n.liveUserKicked(name));
      _scope.onKicked?.call();
      _closeCard();
    });
  }

  Future<void> _toggleMute() async {
    final l10n = context.l10n;
    final mute = !(_muted ?? false);
    final name = KFormat.bidiIsolate(widget.person.name);
    await _run(() async {
      await ref
          .read(liveChatProvider(_scope.roomId).notifier)
          .setMuted(widget.person.username, muted: mute);
      if (!mounted) return;
      setState(() => _muted = mute);
      KSnack.success(
        context,
        mute ? l10n.liveChatUserMuted(name) : l10n.liveChatUserUnmuted(name),
      );
    });
  }

  Future<void> _toggleMic() async {
    final l10n = context.l10n;
    final seat = _scope.seat;
    final onSeatMute = _scope.onSeatMute;
    if (seat == null || onSeatMute == null) return;
    final mute = !_micMuted;
    final name = KFormat.bidiIsolate(widget.person.name);
    await _run(() async {
      await onSeatMute(seat.index, muted: mute);
      if (!mounted) return;
      setState(() => _micMuted = mute);
      KSnack.success(
        context,
        mute ? l10n.liveSeatUserMuted(name) : l10n.liveSeatUserUnmuted(name),
      );
    });
  }

  Future<void> _toggleAdmin() async {
    final l10n = context.l10n;
    final onModerator = _scope.onModerator;
    if (onModerator == null) return;
    final make = _target != LivePersonRole.moderator;
    final name = KFormat.bidiIsolate(widget.person.name);
    await _run(() async {
      await onModerator(widget.person.username, moderator: make);
      if (!mounted) return;
      setState(
        () => _target = make ? LivePersonRole.moderator : LivePersonRole.viewer,
      );
      KSnack.success(
        context,
        make
            ? l10n.liveUserModeratorAdded(name)
            : l10n.liveUserModeratorRemoved(name),
      );
    });
  }

  Future<void> _more() async {
    final l10n = context.l10n;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: LivePersonToolKeys.report,
              leading: const Icon(Icons.flag_outlined),
              title: Text(l10n.safetyReportUser),
              onTap: () => Navigator.of(sheet).pop('report'),
            ),
            ListTile(
              key: LivePersonToolKeys.block,
              leading: Icon(Icons.block_rounded, color: sheet.palette.error),
              title: Text(
                l10n.safetyBlockUser(KFormat.bidiIsolate(widget.person.name)),
                style: TextStyle(color: sheet.palette.error),
              ),
              onTap: () => Navigator.of(sheet).pop('block'),
            ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    if (action == 'report') {
      await reportUser(context, ref, userId: widget.person.id);
      return;
    }
    final blocked = await confirmBlock(
      context,
      ref,
      username: widget.person.username,
      name: widget.person.name,
    );
    if (blocked) _closeCard();
  }

  Widget _button({
    required Key key,
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color color = _ink,
    bool active = false,
  }) => Semantics(
    button: true,
    toggled: active ? true : null,
    label: tooltip,
    excludeSemantics: true,
    child: Tooltip(
      message: tooltip,
      child: InkResponse(
        key: key,
        radius: 20,
        onTap: _busy ? null : onTap,
        child: SizedBox.square(
          dimension: 36,
          child: Center(
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active ? color.withValues(alpha: 0.12) : null,
                border: Border.all(
                  color: color.withValues(alpha: active ? 0.55 : 0.28),
                ),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 17, color: color),
            ),
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final name = KFormat.bidiIsolate(widget.person.name);
    final muted = _muted ?? false;
    final moderator = _target == LivePersonRole.moderator;
    final start = [
      _button(
        key: LivePersonToolKeys.points,
        icon: Icons.bar_chart_rounded,
        tooltip: l10n.liveUserPoints,
        onTap: () => unawaited(
          showLivePointsPopover(
            context,
            roomId: _scope.roomId,
            username: widget.person.username,
            name: widget.person.name,
          ),
        ),
      ),
      if (_moderates)
        _button(
          key: LivePersonToolKeys.kick,
          icon: Icons.logout_rounded,
          tooltip: l10n.liveUserKick,
          color: _danger,
          onTap: () => unawaited(_kick()),
        ),
      if (_canAdmin)
        _button(
          key: LivePersonToolKeys.admin,
          icon: moderator
              ? Icons.remove_moderator_outlined
              : Icons.add_moderator_outlined,
          tooltip: moderator
              ? l10n.liveSeatRemoveModerator
              : l10n.liveSeatMakeModerator,
          color: moderator ? _on : _ink,
          active: moderator,
          onTap: () => unawaited(_toggleAdmin()),
        ),
    ];
    final end = [
      if (_canMuteSeat)
        _button(
          key: LivePersonToolKeys.micMute,
          icon: _micMuted ? Icons.mic_off_rounded : Icons.mic_none_rounded,
          tooltip: _micMuted
              ? l10n.liveSeatUnmuteUser(name)
              : l10n.liveSeatMuteUser(name),
          color: _micMuted ? _danger : _ink,
          active: _micMuted,
          onTap: () => unawaited(_toggleMic()),
        ),
      if (_moderates)
        _button(
          key: LivePersonToolKeys.mute,
          icon: muted
              ? Icons.speaker_notes_off_rounded
              : Icons.speaker_notes_outlined,
          tooltip: muted
              ? l10n.liveChatUnmuteUser(name)
              : l10n.liveChatMuteUser(name),
          color: muted ? _danger : _ink,
          active: muted,
          onTap: () => unawaited(_toggleMute()),
        ),
      if (!widget.self && _signedIn)
        _button(
          key: LivePersonToolKeys.more,
          icon: Icons.more_horiz_rounded,
          tooltip: l10n.liveUserMore,
          onTap: () => unawaited(_more()),
        ),
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Many buttons on a narrow phone shrink instead of reaching the
        // picture.
        Expanded(
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Row(mainAxisSize: MainAxisSize.min, children: start),
            ),
          ),
        ),
        SizedBox(width: widget.middle),
        Expanded(
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerEnd,
              child: Row(mainAxisSize: MainAxisSize.min, children: end),
            ),
          ),
        ),
      ],
    );
  }
}

/// A person's points in this live and their rank (`GET …/contributors/
/// {username}`, D105): a small card over the room.
Future<void> showLivePointsPopover(
  BuildContext context, {
  required String roomId,
  required String username,
  required String name,
}) => showDialog<void>(
  context: context,
  barrierColor: const Color(0x33000000),
  builder: (_) =>
      _PointsPopover(roomId: roomId, username: username, name: name),
);

class _PointsPopover extends ConsumerStatefulWidget {
  const new({required this.roomId, required this.username, required this.name});

  final String roomId;
  final String username;
  final String name;

  @override
  ConsumerState<_PointsPopover> createState() => _PointsPopoverState();
}

class _PointsPopoverState extends ConsumerState<_PointsPopover> {
  late final Future<LiveContributorStanding> _load = ref
      .read(liveRepositoryProvider)
      .contributor(widget.roomId, widget.username);

  static const _ink = Color(0xFF2E3130);
  static const _soft = Color(0xFF9A9BA5);
  static const _flame = Color(0xFFE07A12);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.textStyles;
    return Dialog(
      key: LivePersonToolKeys.pointsPopover,
      backgroundColor: const Color(0xFFFFFFFF),
      surfaceTintColor: const Color(0x00000000),
      insetPadding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: FutureBuilder<LiveContributorStanding>(
            future: _load,
            builder: (context, snap) {
              final standing = snap.data;
              final Widget body;
              if (standing != null) {
                final rank = standing.rank;
                body = standing.points <= 0
                    ? Text(
                        l10n.liveUserNoPoints,
                        textAlign: TextAlign.center,
                        style: text.body.copyWith(color: _soft),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const KPointsIcon(size: 26),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  l10n.liveScore(
                                    standing.points,
                                    KFormat.grouped(standing.points),
                                  ),
                                  textAlign: TextAlign.center,
                                  style: text.title.copyWith(
                                    color: _ink,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (rank != null) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF1DF),
                                borderRadius: BorderRadius.circular(
                                  KRadius.pill,
                                ),
                              ),
                              child: Text(
                                l10n.liveUserRank(KFormat.grouped(rank)),
                                textAlign: TextAlign.center,
                                style: text.bodyStrong.copyWith(
                                  color: _flame,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ],
                      );
              } else if (snap.hasError) {
                body = Text(
                  failureMessage(l10n, toAppFailure(snap.error!)),
                  textAlign: TextAlign.center,
                  style: text.body.copyWith(color: _soft),
                );
              } else {
                body = const Padding(
                  padding: EdgeInsets.all(8),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.bar_chart_rounded,
                        size: 18,
                        color: _flame,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          l10n.liveUserPoints,
                          style: text.bodyStrong.copyWith(color: _ink),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    KFormat.bidiIsolate(widget.name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.caption.copyWith(color: _soft),
                  ),
                  const SizedBox(height: 14),
                  body,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
