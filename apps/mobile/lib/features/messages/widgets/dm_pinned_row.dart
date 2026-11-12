import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/presentation/widgets/kabso_team_badge.dart';
import 'package:kabso_live/features/messages/chat_screen.dart' show ChatPeer;
import 'package:kabso_live/features/messages/domain/dm_models.dart';
import 'package:kabso_live/features/messages/widgets/dm_group_row.dart';
import 'package:kabso_live/features/support/application/support_providers.dart';
import 'package:kabso_live/features/support/domain/support_models.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Geometry of the pinned row at the top of «الرسائل» (D385, owner: «اجعل
/// شات الإدارة مثبت في الاعلى بنفس هذه الطريقة»): proportions after the
/// owner's reference (round pictures ≈ 58 dp with the name 12 dp under
/// each, a small online dot at the bottom-end, a coloured ring on the one
/// that wants attention); colours are Kabso's tokens.
abstract final class KDmPins {
  static const double circle = 58;

  /// Each circle's slot (the name may be as wide as this).
  static const double slot = 72;
  static const double nameGap = 6;
  static const double nameSize = 12;
  static const double ring = 2.5;

  /// Between the ring and the picture.
  static const double ringGap = 2;
  static const double dot = 13;
  static const double dotBorder = 2.5;
  static const double badge = 20;

  /// Above and below the row.
  static const double top = 4;
  static const double bottom = 12;
}

/// D385: the horizontal row of round pictures between «الرسائل» and the
/// chats: «دعم كابسو» always first (fixed — it cannot be unpinned, deleted
/// or blocked), then up to five chats the person pinned, first pinned
/// first. Scrolls sideways when it does not fit. A pinned chat stays in the
/// list below too (the row is a shortcut).
class DmPinnedRow extends ConsumerWidget {
  const new({super.key});

  static const rowKey = Key('dm.pins.row');
  static const supportKey = Key('dm.pins.support');
  static Key pinKey(String id) => Key('dm.pins.$id');
  static Key dotKey(String id) => Key('dm.pins.$id.online');
  static Key badgeKey(String id) => Key('dm.pins.$id.badge');
  static const supportBadgeKey = Key('dm.pins.support.badge');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final support = ref.watch(supportThreadProvider);
    final pins = ref.watch(dmPinsProvider);
    // The start of the first circle lines up with the title above it.
    const start = KDmListInsets.start - (KDmPins.slot - KDmPins.circle) / 2;
    return Padding(
      key: rowKey,
      padding: const EdgeInsets.only(top: KDmPins.top, bottom: KDmPins.bottom),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsetsDirectional.only(start: start, end: start),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PinCircle(
              key: supportKey,
              label: l10n.supportChatName,
              semantics: support.unreadCount > 0
                  ? l10n.supportUnread(support.unreadCount)
                  : l10n.supportChatName,
              unread: support.unreadCount,
              badgeKey: supportBadgeKey,
              ring: _Ring.team,
              picture: const KabsoTeamPicture(size: KDmPins.circle),
              onTap: () => context.push(AppRoutes.supportChat),
            ),
            for (final pin in pins.data) _pinned(context, ref, pin),
          ],
        ),
      ),
    );
  }

  Widget _pinned(BuildContext context, WidgetRef ref, DmPin pin) {
    final l10n = context.l10n;
    final chat = pin.chat;
    final group = chat.group;
    final conversation = chat.conversation;
    final name = group?.name ?? conversation!.peer.displayName;
    final unread = group?.unreadCount ?? conversation!.unreadCount;
    final marked = conversation?.markedUnread ?? false;
    final muted = group?.muted ?? conversation!.muted;
    return _PinCircle(
      key: pinKey(chat.id),
      label: name,
      semantics: [
        if (unread > 0) l10n.conversationsUnread(name) else name,
        if (pin.online ?? conversation?.online ?? false) l10n.dmPinOnline,
        l10n.dmPinnedLabel,
      ].join(', '),
      unread: unread,
      marked: marked,
      muted: muted,
      badgeKey: badgeKey(chat.id),
      online: pin.online ?? conversation?.online ?? false,
      dotKey: dotKey(chat.id),
      ring: unread > 0 || marked ? _Ring.unread : _Ring.none,
      picture: group != null
          ? DmGroupAvatar(
              name: group.name,
              photoUrl: group.photoUrl,
              size: KDmPins.circle,
            )
          : KAvatar(
              name: name,
              imageUrl: conversation!.peer.avatarUrl,
              size: KDmPins.circle,
            ),
      onTap: () => group != null
          ? context.push(AppRoutes.groupChat(group.id), extra: group.name)
          : context.push(
              AppRoutes.chat(conversation!.peer.username),
              extra: (
                displayName: conversation.peer.displayName,
                premiumTier: conversation.peer.premiumTier,
              ) as ChatPeer,
            ),
      onLongPress: () => unawaited(_unpinSheet(context, ref, chat, name)),
    );
  }
}

/// The start inset of the Messages list (`KDmList.startInset`, D336),
/// restated here so the row does not import the tab.
abstract final class KDmListInsets {
  static const double start = 23;
}

enum _Ring { none, unread, team }

class _PinCircle extends StatelessWidget {
  const new({
    required this.label,
    required this.semantics,
    required this.picture,
    required this.onTap,
    required this.badgeKey,
    required this.ring,
    super.key,
    this.unread = 0,
    this.marked = false,
    this.muted = false,
    this.online = false,
    this.dotKey,
    this.onLongPress,
  });

  final String label;
  final String semantics;
  final Widget picture;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Key badgeKey;
  final _Ring ring;
  final int unread;
  final bool marked;
  final bool muted;
  final bool online;
  final Key? dotKey;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.textStyles;
    final l10n = context.l10n;
    const outer = KDmPins.circle + 2 * (KDmPins.ring + KDmPins.ringGap);
    final decoration = switch (ring) {
      _Ring.none => null,
      _Ring.unread => BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: p.primary, width: KDmPins.ring),
      ),
      _Ring.team => const BoxDecoration(
        shape: BoxShape.circle,
        gradient: KabsoTeamColors.gradient,
      ),
    };
    return Semantics(
      button: true,
      label: semantics,
      excludeSemantics: true,
      onLongPressHint: onLongPress == null ? null : l10n.dmPinActions,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(KRadius.md),
        child: SizedBox(
          width: KDmPins.slot,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(
                dimension: outer,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    if (decoration != null)
                      Positioned.fill(
                        child: DecoratedBox(decoration: decoration),
                      ),
                    if (ring == _Ring.team)
                      // The gradient is a ring: the page shows between it
                      // and the picture.
                      Container(
                        width: KDmPins.circle + 2 * KDmPins.ringGap,
                        height: KDmPins.circle + 2 * KDmPins.ringGap,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: p.background,
                        ),
                      ),
                    picture,
                    if (online)
                      PositionedDirectional(
                        key: dotKey,
                        end: KDmPins.ring,
                        bottom: KDmPins.ring,
                        child: Container(
                          width: KDmPins.dot,
                          height: KDmPins.dot,
                          decoration: BoxDecoration(
                            color: p.success,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: p.background,
                              width: KDmPins.dotBorder,
                            ),
                          ),
                        ),
                      ),
                    if (unread > 0 || marked)
                      PositionedDirectional(
                        key: badgeKey,
                        top: -2,
                        end: -4,
                        child: Container(
                          constraints: const BoxConstraints(
                            minWidth: KDmPins.badge,
                          ),
                          height: KDmPins.badge,
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: muted ? p.textTertiary : p.primary,
                            borderRadius: BorderRadius.circular(KRadius.pill),
                            border: Border.all(color: p.background, width: 2),
                          ),
                          child: unread > 0
                              ? Text(
                                  unread >= 99
                                      ? '99+'
                                      : KFormat.compact(unread, l10n),
                                  textScaler: TextScaler.noScaling,
                                  style: t.caption.copyWith(
                                    fontSize: 11,
                                    height: 1,
                                    fontWeight: FontWeight.w700,
                                    color: p.onPrimary,
                                  ),
                                )
                              : const SizedBox(width: 6, height: 6),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: KDmPins.nameGap - KDmPins.ringGap),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: t.caption.copyWith(
                  fontSize: KDmPins.nameSize,
                  height: 1.25,
                  fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.w500,
                  color: unread > 0 ? p.textPrimary : p.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The long press on a pinned circle: unpin it.
Future<void> _unpinSheet(
  BuildContext context,
  WidgetRef ref,
  DmChat chat,
  String name,
) async {
  final l10n = context.l10n;
  final ok = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: sheet.textStyles.bodyStrong,
            ),
          ),
          ListTile(
            key: DmPinActions.unpinKey,
            leading: const Icon(Icons.push_pin_outlined),
            title: Text(l10n.dmUnpin),
            onTap: () => Navigator.of(sheet).pop(true),
          ),
        ],
      ),
    ),
  );
  if ((ok ?? false) && context.mounted) {
    await togglePin(context, ref, chat, pinned: true);
  }
}

/// D385: the pin actions' keys (the list's long press, the chat menus).
abstract final class DmPinActions {
  static const pinKey = Key('dm.action.pin');
  static const unpinKey = Key('dm.action.unpin');
}

/// Pins [chat] (or unpins it when [pinned]) and says so. A 6th pin is
/// refused with a clear message (the server's 409 `DM_PIN_LIMIT`, and
/// before asking it when the row is already full).
Future<void> togglePin(
  BuildContext context,
  WidgetRef ref,
  DmChat chat, {
  required bool pinned,
}) async {
  final l10n = context.l10n;
  final pins = ref.read(dmPinsProvider);
  if (!pinned && pins.full) {
    KSnack.error(context, l10n.dmPinLimit(pins.max));
    return;
  }
  try {
    await ref.read(dmPinsProvider.notifier).setPinned(chat, pinned: !pinned);
    if (context.mounted) {
      KSnack.success(context, pinned ? l10n.dmUnpinned : l10n.dmPinnedDone);
    }
  } on Object catch (e) {
    if (!context.mounted) return;
    final failure = toAppFailure(e);
    KSnack.error(
      context,
      failure.code == ErrorCode.dmPinLimit
          ? l10n.dmPinLimit(DmPinList.limit)
          : failureMessage(l10n, failure),
    );
  }
}
