import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/live/presentation/widgets/kabso_team_badge.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D269 (owner): the role tags a chat line opens with, each in its own fixed
/// colour — the host «المضيف» red, a room moderator «مشرف» orange; the
/// Kabso Team (D260's / D273's staff) wears its badge instead (D282,
/// [KabsoTeamBadge]).
enum LiveChatTagKind {
  host,
  moderator,
  team;

  /// The tag of a chat author's [role] (null: no tag).
  static LiveChatTagKind? of(LiveChatRole? role) => switch (role) {
    LiveChatRole.host => host,
    LiveChatRole.moderator => moderator,
    _ => null,
  };

  /// A chat line's tag: D273's Kabso Team line ([LiveChatAuthorBadges]
  /// `kabsoTeam`) wears the team's, else the author's [role]'s.
  static LiveChatTagKind? ofLine(LiveChatRole? role, LiveChatAuthorBadges? b) =>
      (b?.kabsoTeam ?? false) ? team : of(role);
}

/// D269 (owner: the role tag BEFORE the name — «[role tag] → name → VIP badge
/// → «جديد» and other tags → levels»): one pill [height] tall, white bold
/// text on the kind's colour (≥ 4.5 : 1). Shared by every chat mode and,
/// with [LiveChatTagKind.team], by the staff lines (D273) — whose tag is
/// the Kabso Team badge (D282) at the line's [emblemHeight].
class LiveChatRoleTag extends StatelessWidget {
  const new({
    required this.kind,
    required this.height,
    this.emblemHeight,
    super.key,
  });

  final LiveChatTagKind kind;

  /// The pill's height (host, moderator).
  final double height;

  /// D282: the Kabso Team badge's height ([height] when unset) — D282b:
  /// in a chat line taller than the other emblems, so its name reads
  /// ([KabsoTeamBadge.chatHeight]).
  final double? emblemHeight;

  /// Host red, moderator orange (white text ≥ 4.5 : 1 on each).
  static const host = Color(0xFFD32F2F);
  static const moderator = Color(0xFFC2410C);

  /// The pill's colour (null: the team's badge, not a pill).
  static Color? colorOf(LiveChatTagKind kind) => switch (kind) {
    LiveChatTagKind.host => host,
    LiveChatTagKind.moderator => moderator,
    LiveChatTagKind.team => null,
  };

  /// The tag's words in the app's language.
  static String labelOf(BuildContext context, LiveChatTagKind kind) =>
      switch (kind) {
        LiveChatTagKind.host => context.l10n.liveChatHostBadge,
        LiveChatTagKind.moderator => context.l10n.liveChatModeratorBadge,
        LiveChatTagKind.team => context.l10n.liveKabsoTeam,
      };

  @override
  Widget build(BuildContext context) => kind == LiveChatTagKind.team
      ? KabsoTeamBadge(height: emblemHeight ?? height)
      : Container(
          height: height,
          padding: EdgeInsets.symmetric(horizontal: height * 0.38),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colorOf(kind),
            borderRadius: BorderRadius.circular(KRadius.pill),
          ),
          child: Text(
            labelOf(context, kind),
            maxLines: 1,
            textScaler: TextScaler.noScaling,
            style: context.textStyles.caption.copyWith(
              fontSize: height * 0.62,
              height: 1.1,
              color: const Color(0xFFFFFFFF),
              fontWeight: FontWeight.w800,
              shadows: const [],
            ),
          ),
        );
}
