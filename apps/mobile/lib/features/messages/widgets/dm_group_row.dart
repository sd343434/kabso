import 'package:clock/clock.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/messages/domain/dm_models.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D339: a group's picture — its photo, or a people disc in Kabso's red
/// tint when it has none (never another product's art).
class DmGroupAvatar extends StatelessWidget {
  const new({required this.name, required this.size, super.key, this.photoUrl});

  final String name;
  final String? photoUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final url = photoUrl;
    if (url != null) return KAvatar(name: name, imageUrl: url, size: size);
    return Semantics(
      label: context.l10n.dmGroupPhoto,
      excludeSemantics: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: p.primary.withValues(alpha: 0.12),
        ),
        alignment: Alignment.center,
        child: Icon(Icons.groups_rounded, size: size * 0.5, color: p.primary),
      ),
    );
  }
}

/// The preview line of a group: «sender: message», «أنت: …» for one's
/// own, or the member count before the first message.
String dmGroupPreview(AppLocalizations l10n, DmGroup g) {
  final m = g.lastMessage;
  if (m == null) {
    return l10n.dmGroupMembersCount(KFormat.compact(g.memberCount, l10n));
  }
  final body = switch (m.kind) {
    DmMessageKind.text => m.text ?? '',
    DmMessageKind.image => l10n.dmLastPhoto,
    DmMessageKind.voice => l10n.dmPreviewVoice,
    DmMessageKind.emoji => l10n.dmPreviewSticker,
    DmMessageKind.gift || DmMessageKind.unknown => l10n.dmPreviewUnsupported,
  };
  final line = body.replaceAll(RegExp(r'\s+'), ' ');
  if (m.mine) return l10n.dmPreviewYou(line);
  final name = m.sender?.displayName ?? l10n.dmGroupUnknownSender;
  return l10n.dmPreviewSender(KFormat.bidiIsolate(name), line);
}

/// One group in «الدردشات» / «المؤرشفة» (D339): the D336 row geometry — the
/// group's picture, its name with the people glyph, the newest message with
/// its sender, the compact time and the red unread count (grey when muted).
class DmGroupRow extends StatelessWidget {
  const new({
    required this.group,
    required this.geometry,
    super.key,
    this.onLongPress,
  });

  final DmGroup group;

  /// The list's measured geometry (row height, picture, insets, sizes).
  final DmRowGeometry geometry;
  final VoidCallback? onLongPress;

  static Key rowKey(String groupId) => Key('dm.group.$groupId');

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l10n = context.l10n;
    final t = context.textStyles;
    final g = geometry;
    final unread = group.unreadCount > 0;
    final preview = dmGroupPreview(l10n, group);
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final now = clock.now();
    final time =
        KFormat.relativeShort(group.lastActivityAt, now, l10n, localeTag) ??
        l10n.feedPostJustNow;
    final timeSpoken =
        KFormat.relative(group.lastActivityAt, now, l10n, localeTag) ??
        l10n.feedPostJustNow;
    return Semantics(
      key: rowKey(group.id),
      button: true,
      label: unread ? l10n.conversationsUnread(group.name) : group.name,
      value: [
        preview,
        timeSpoken,
        if (unread) l10n.conversationsUnreadCount(group.unreadCount),
        if (group.muted) l10n.conversationsMuted,
      ].join(', '),
      excludeSemantics: true,
      onLongPressHint: onLongPress == null ? null : l10n.dmConversationActions,
      child: Material(
        color: p.background,
        child: InkWell(
          onLongPress: onLongPress,
          onTap: () =>
              context.push(AppRoutes.groupChat(group.id), extra: group.name),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: g.rowHeight),
            child: Padding(
              padding: EdgeInsetsDirectional.only(
                start: g.startInset,
                end: g.endInset,
                top: (g.rowHeight - g.avatar) / 2,
                bottom: (g.rowHeight - g.avatar) / 2,
              ),
              child: Row(
                children: [
                  DmGroupAvatar(
                    name: group.name,
                    photoUrl: group.photoUrl,
                    size: g.avatar,
                  ),
                  SizedBox(width: g.avatarGap),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                group.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: t.bodyStrong.copyWith(
                                  fontSize: g.nameSize,
                                  height: 1.3,
                                  fontWeight: unread
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: p.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: KSpacing.xs),
                            Icon(
                              Icons.group_outlined,
                              size: g.mutedIcon + 2,
                              color: p.textTertiary,
                            ),
                            if (group.muted) ...[
                              const SizedBox(width: KSpacing.xs),
                              Icon(
                                Icons.volume_off_rounded,
                                size: g.mutedIcon,
                                color: p.textTertiary,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: KSpacing.xs),
                        Text(
                          preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.body.copyWith(
                            fontSize: g.previewSize,
                            height: 1.35,
                            color: p.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: KSpacing.md),
                  Padding(
                    padding: EdgeInsets.only(top: g.timeTop),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: g.timeMaxWidth),
                          child: Text(
                            time,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.caption.copyWith(
                              fontSize: g.timeSize,
                              color: p.textTertiary,
                            ),
                          ),
                        ),
                        SizedBox(height: g.timeToBadge),
                        if (unread)
                          Container(
                            constraints: BoxConstraints(
                              minWidth: g.unreadBadge,
                            ),
                            height: g.unreadBadge,
                            padding: const EdgeInsets.symmetric(
                              horizontal: KSpacing.xs + 2,
                            ),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: group.muted ? p.textTertiary : p.primary,
                              borderRadius: BorderRadius.circular(KRadius.pill),
                            ),
                            child: Text(
                              group.unreadCount >= 99
                                  ? '99+'
                                  : KFormat.compact(group.unreadCount, l10n),
                              style: t.caption.copyWith(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                height: 1,
                                color: p.onPrimary,
                              ),
                            ),
                          )
                        else
                          SizedBox(height: g.unreadBadge),
                      ],
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

/// The Messages list's row geometry (D336's `KDmList`, passed in so this
/// widget does not depend on the tab).
@immutable
class DmRowGeometry {
  const new({
    required this.rowHeight,
    required this.avatar,
    required this.startInset,
    required this.avatarGap,
    required this.endInset,
    required this.nameSize,
    required this.previewSize,
    required this.timeSize,
    required this.timeMaxWidth,
    required this.unreadBadge,
    required this.timeToBadge,
    required this.timeTop,
    required this.mutedIcon,
  });

  final double rowHeight;
  final double avatar;
  final double startInset;
  final double avatarGap;
  final double endInset;
  final double nameSize;
  final double previewSize;
  final double timeSize;
  final double timeMaxWidth;
  final double unreadBadge;
  final double timeToBadge;
  final double timeTop;
  final double mutedIcon;
}
