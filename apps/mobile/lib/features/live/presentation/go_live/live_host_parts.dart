import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_viewer_parts.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D131 (owner's recording, §11c): the host's bar on a video live — chat,
/// beauty and ≡ (the room tools) at the start; guest connection, PK and
/// gifts at the end. Flip and the microphone live in ≡. The circles keep
/// the viewer's 34.8 pt size; each has a 48 pt target, so the pitch is
/// 48 pt (the recording's ≈ 42.5 pt would overlap the targets).
class KHostBar extends StatelessWidget {
  const new({
    required this.onChat,
    required this.onBeauty,
    required this.onTools,
    required this.onGuests,
    required this.onPk,
    required this.onGift,
    super.key,
    this.beautyOn = false,
    this.requests = 0,
    this.chatKey = defaultChatKey,
  });

  final VoidCallback? onChat;
  final VoidCallback? onBeauty;
  final VoidCallback? onTools;
  final VoidCallback? onGuests;
  final VoidCallback? onPk;
  final VoidCallback? onGift;
  final bool beautyOn;

  /// Seat requests waiting (a dot on the guests button).
  final int requests;
  final Key chatKey;

  static const defaultChatKey = Key('hostBar.chat');
  static const beautyKey = Key('hostBar.beauty');
  static const toolsKey = Key('hostBar.tools');
  static const guestsKey = Key('hostBar.guests');
  static const pkKey = Key('hostBar.pk');
  static const giftKey = Key('hostBar.gift');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      children: [
        KViewerBarButton(
          key: chatKey,
          asset: 'assets/live_bar/chat.png',
          label: l10n.goLiveChatPill,
          onTap: onChat,
        ),
        KViewerBarButton(
          key: beautyKey,
          icon: Icons.auto_fix_high_rounded,
          label: l10n.liveBeautyToolsTitle,
          badge: beautyOn,
          onTap: onBeauty,
        ),
        KViewerBarButton(
          key: toolsKey,
          asset: 'assets/live_bar/menu.png',
          label: l10n.liveHostTools,
          onTap: onTools,
        ),
        const Spacer(),
        KViewerBarButton(
          key: guestsKey,
          icon: Icons.all_inclusive_rounded,
          label: l10n.liveHostGuests,
          badge: requests > 0,
          onTap: onGuests,
        ),
        KViewerBarButton(
          key: pkKey,
          // D135: the owner's colourful PK art (boxing gloves).
          asset: 'assets/live_bar/bar_pk.png',
          art: true,
          label: l10n.goLivePk,
          onTap: onPk,
        ),
        KViewerBarButton(
          key: giftKey,
          // D135: the owner's colourful gift box.
          asset: 'assets/live_bar/bar_gift.png',
          art: true,
          label: l10n.liveGifts,
          onTap: onGift,
        ),
      ],
    );
  }
}

/// Keys of the User management sheet.
abstract final class LiveManageKeys {
  static const muted = Key('manage.muted');
  static const kicked = Key('manage.kicked');
  static const moderators = Key('manage.moderators');
  static const signedInOnly = Key('manage.signedInOnly');
  static const back = Key('manage.back');
  static Key action(String username) => Key('manage.action.$username');
}

/// D131 (recording f_012): the host's User management — who is muted in
/// the chat, who was removed from the live, the moderators (seat rooms
/// list them; a SOLO live cannot read them, so the row says how to add
/// one), and "Signed-in viewers only" (`allowGuests` inverted, CP-010).
Future<void> showLiveUserManagement(
  BuildContext context, {
  required String roomId,
  required bool hasSeats,
  required bool allowGuests,
  required Future<void> Function({required bool allow}) onAllowGuests,
  VoidCallback? onChanged,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: const Color(0xFFFFFFFF),
  barrierColor: const Color(0x00000000),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
  ),
  builder: (_) => _ManageSheet(
    roomId: roomId,
    hasSeats: hasSeats,
    allowGuests: allowGuests,
    onAllowGuests: onAllowGuests,
    onChanged: onChanged,
  ),
);

enum _ManagePage { muted, kicked, moderators }

class _ManageSheet extends ConsumerStatefulWidget {
  const new({
    required this.roomId,
    required this.hasSeats,
    required this.allowGuests,
    required this.onAllowGuests,
    this.onChanged,
  });

  final String roomId;
  final bool hasSeats;
  final bool allowGuests;
  final Future<void> Function({required bool allow}) onAllowGuests;
  final VoidCallback? onChanged;

  @override
  ConsumerState<_ManageSheet> createState() => _ManageSheetState();
}

class _ManageSheetState extends ConsumerState<_ManageSheet> {
  static const _ink = Color(0xFF1C1B1F);
  static const _soft = Color(0xFF7A7B8C);

  late bool _allowGuests = widget.allowGuests;
  bool _savingGuests = false;
  _ManagePage? _page;
  List<UserSummary>? _muted;
  List<UserSummary>? _kicked;
  List<UserSummary>? _moderators;
  Object? _error;
  final _busy = <String>{};

  LiveRepository get _repo => ref.read(liveRepositoryProvider);

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait<List<UserSummary>>([
        _repo.chatMutes(widget.roomId).then((l) => [for (final m in l) m.user]),
        _repo.kicks(widget.roomId).then((l) => [for (final k in l) k.user]),
        if (widget.hasSeats)
          _repo.seats(widget.roomId).then((s) => s.moderators),
      ]);
      if (!mounted) return;
      setState(() {
        _error = null;
        _muted = results[0];
        _kicked = results[1];
        _moderators = widget.hasSeats ? results[2] : null;
      });
    } on Object catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _act(String username, Future<void> Function() action) async {
    setState(() => _busy.add(username));
    try {
      await action();
      widget.onChanged?.call();
      await _load();
    } on Object catch (e) {
      if (mounted) {
        KSnack.error(context, failureMessage(context.l10n, toAppFailure(e)));
      }
    } finally {
      if (mounted) setState(() => _busy.remove(username));
    }
  }

  Future<void> _setSignedInOnly(bool on) async {
    setState(() {
      _savingGuests = true;
      _allowGuests = !on;
    });
    try {
      await widget.onAllowGuests(allow: !on);
    } on Object catch (e) {
      if (mounted) {
        setState(() => _allowGuests = on);
        KSnack.error(context, failureMessage(context.l10n, toAppFailure(e)));
      }
    } finally {
      if (mounted) setState(() => _savingGuests = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final page = _page;
    final title = switch (page) {
      null => l10n.liveManageTitle,
      _ManagePage.muted => l10n.liveManageMuted,
      _ManagePage.kicked => l10n.liveManageKicked,
      _ManagePage.moderators => l10n.liveManageModerators,
    };
    return Theme(
      data: Theme.of(context).copyWith(
        listTileTheme: const ListTileThemeData(
          textColor: _ink,
          iconColor: _soft,
        ),
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: KSizes.minTouchTarget + 8,
                child: Row(
                  children: [
                    if (page != null)
                      IconButton(
                        key: LiveManageKeys.back,
                        tooltip: MaterialLocalizations.of(context)
                            .backButtonTooltip,
                        onPressed: () => setState(() => _page = null),
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 18,
                          color: _ink,
                        ),
                      )
                    else
                      const SizedBox(width: KSizes.minTouchTarget),
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          title,
                          textAlign: TextAlign.center,
                          style: t.bodyStrong.copyWith(
                            color: _ink,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.liveClose,
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, color: _ink),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: page == null ? _menu(context) : _list(context, page),
              ),
              const SizedBox(height: KSpacing.md),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menu(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    String count(List<UserSummary>? list) =>
        list == null ? '' : KFormat.grouped(list.length);
    Widget row(Key key, String label, _ManagePage page, String trailing) =>
        ListTile(
          key: key,
          title: Text(label, style: t.body.copyWith(color: _ink)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(trailing, style: t.caption.copyWith(color: _soft)),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
          onTap: () => setState(() => _page = page),
        );
    return ListView(
      shrinkWrap: true,
      children: [
        if (_error case final e?)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
            child: Text(
              failureMessage(l10n, toAppFailure(e)),
              style: t.caption.copyWith(color: const Color(0xFFD93A4A)),
            ),
          ),
        row(
          LiveManageKeys.muted,
          l10n.liveManageMuted,
          _ManagePage.muted,
          count(_muted),
        ),
        row(
          LiveManageKeys.kicked,
          l10n.liveManageKicked,
          _ManagePage.kicked,
          count(_kicked),
        ),
        if (widget.hasSeats)
          row(
            LiveManageKeys.moderators,
            l10n.liveManageModerators,
            _ManagePage.moderators,
            count(_moderators),
          )
        else
          ListTile(
            key: LiveManageKeys.moderators,
            title: Text(
              l10n.liveManageModerators,
              style: t.body.copyWith(color: _ink),
            ),
            subtitle: Text(
              l10n.liveManageModeratorsHint,
              style: t.caption.copyWith(color: _soft),
            ),
          ),
        SwitchListTile(
          key: LiveManageKeys.signedInOnly,
          title: Text(
            l10n.liveManageSignedInOnly,
            style: t.body.copyWith(color: _ink),
          ),
          subtitle: Text(
            l10n.liveManageSignedInOnlyBody,
            style: t.caption.copyWith(color: _soft),
          ),
          value: !_allowGuests,
          onChanged: _savingGuests
              ? null
              : (on) => unawaited(_setSignedInOnly(on)),
        ),
      ],
    );
  }

  Widget _list(BuildContext context, _ManagePage page) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final people = switch (page) {
      _ManagePage.muted => _muted,
      _ManagePage.kicked => _kicked,
      _ManagePage.moderators => _moderators,
    };
    if (people == null) {
      return const Padding(
        padding: EdgeInsets.all(KSpacing.xl),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (people.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(KSpacing.xl),
        child: Text(
          l10n.liveManageEmpty,
          textAlign: TextAlign.center,
          style: t.body.copyWith(color: _soft),
        ),
      );
    }
    final (label, run) = switch (page) {
      _ManagePage.muted => (
        l10n.liveManageUnmute,
        (String u) => _repo.setChatMuted(widget.roomId, u, muted: false),
      ),
      _ManagePage.kicked => (
        l10n.liveManageLetBack,
        (String u) => _repo.unkick(widget.roomId, u),
      ),
      _ManagePage.moderators => (
        l10n.liveManageRemove,
        (String u) async {
          await _repo.removeModerator(widget.roomId, u);
        },
      ),
    };
    return ListView(
      shrinkWrap: true,
      children: [
        for (final u in people)
          ListTile(
            leading: KAvatar(name: u.displayName, imageUrl: u.avatarUrl),
            title: Text(
              u.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.body.copyWith(color: _ink),
            ),
            subtitle: Text(
              '@${u.username}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textDirection: TextDirection.ltr,
              style: t.caption.copyWith(color: _soft),
            ),
            trailing: OutlinedButton(
              key: LiveManageKeys.action(u.username),
              onPressed: _busy.contains(u.username)
                  ? null
                  : () => unawaited(_act(u.username, () => run(u.username))),
              child: Text(label),
            ),
          ),
      ],
    );
  }
}
