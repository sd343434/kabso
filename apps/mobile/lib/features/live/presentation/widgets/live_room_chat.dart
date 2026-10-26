import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/emoji/kabi_emoji.dart';
import 'package:kabso_live/features/levels/domain/level_models.dart';
import 'package:kabso_live/features/levels/presentation/level_badge.dart';
import 'package:kabso_live/features/live/application/live_chat_controller.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_audio_room.dart';
import 'package:kabso_live/features/live/presentation/widgets/charm_level_badge.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_chat_media.dart';
import 'package:kabso_live/features/posts/presentation/report_sheet.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// The caller's role in the room, for what a chat line offers.
enum LiveChatViewerRole { host, moderator, member, guest }

/// The room chat (CP-013): the newest lines at the bottom of a bounded box
/// at the start side. Tapping a message opens its actions; a line that
/// failed to send offers a retry.
class LiveRoomChatLines extends ConsumerWidget {
  const new({
    required this.roomId,
    required this.role,
    required this.onProfile,
    super.key,
    this.bubble = KAudioRoom.bubble,
  });

  final String roomId;
  final LiveChatViewerRole role;

  /// Opens a user's profile card.
  final void Function(String username) onProfile;

  /// The bubble colour (the audio room's purple, or the video scrim).
  final Color bubble;

  static const listKey = Key('liveChat.lines');

  /// Lines on screen at once (the newest).
  static const maxVisibleLines = 8;
  static Key lineKey(String key) => Key('liveChat.line.$key');

  /// D118: the room's rules line.
  static const noticeKey = Key('liveChat.notice');

  /// CP-021: the heart at the start of a CP bubble line.
  static const cpHeartKey = Key('liveChat.cpHeart');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final chat = ref.watch(liveChatProvider(roomId));
    final items = chat.items;
    // D119: taller lines (picture, name, badges, bubble), so a little more
    // room than the 240 pt of one-line bubbles: about three messages.
    final maxHeight = math
        .min(300, MediaQuery.sizeOf(context).height * 0.35)
        .toDouble();
    final empty = _Bubble(
      color: bubble,
      child: _plain(context, l10n.liveChatEmpty),
    );
    // D119: the latest join, pinned under the newest message.
    final strip = LiveChatJoinStrip(join: chat.latestJoin, color: bubble);
    if (items.isEmpty) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [if (chat.loaded) empty, strip],
      );
    }
    // The newest lines that fit; older ones fade out at the top. Not a
    // lazy list: the audio room measures the chat's height.
    final visible = items.length > maxVisibleLines
        ? items.sublist(items.length - maxVisibleLines)
        : items;
    // Only the rules line so far (D118): the empty hint still follows it.
    final nothingSaid =
        chat.loaded && items.every((i) => i is LiveChatNoticeLine);
    final lines = ConstrainedBox(
      key: listKey,
      // D119: wider than before (300 pt) for the picture, name and badges.
      constraints: BoxConstraints(
        maxHeight: maxHeight,
        maxWidth: LiveChatAuthoredLine.chatMaxWidth(context),
      ),
      child: ClipRect(
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x00000000), Color(0xFF000000)],
            stops: [0, 0.18],
          ).createShader(bounds),
          child: Semantics(
            container: true,
            liveRegion: true,
            child: OverflowBox(
              alignment: AlignmentDirectional.bottomStart,
              minHeight: 0,
              maxHeight: double.infinity,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final item in visible)
                    Padding(
                      key: lineKey(item.key),
                      // D119: messages 8 pt apart (the reference's ~7 pt
                      // at this scale); system lines stay compact.
                      padding: EdgeInsets.only(
                        top: item is LiveChatPosted || item is LiveChatPending
                            ? 8
                            : 4,
                      ),
                      child: _line(context, ref, item),
                    ),
                  if (nothingSaid)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: empty,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    // The strip keeps its room: when the place is bounded (the video
    // live) the lines give way; in the audio room's scroll view they do
    // not need to.
    return LayoutBuilder(
      builder: (context, box) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (box.hasBoundedHeight) Flexible(child: lines) else lines,
          strip,
        ],
      ),
    );
  }

  Widget _line(BuildContext context, WidgetRef ref, LiveChatItem item) {
    final l10n = context.l10n;
    final boxMax = LiveChatAuthoredLine.chatMaxWidth(context);
    return switch (item) {
      // CP-017: a voice clip or a picture (the controller drops them at
      // `expiresAt` and when the media is gone).
      LiveChatPosted(:final entry)
          when entry.kind != LiveChatKind.text && entry.media != null =>
        _mediaLine(context, ref, entry, entry.media!, boxMax),
      LiveChatPosted(:final entry) => LiveChatAuthoredLine(
        name: entry.author.displayName,
        avatarUrl: entry.author.avatarUrl,
        role: entry.authorRole,
        badges: entry.authorBadges,
        maxWidth: boxMax,
        label: l10n.liveChatLineLabel(
          entry.author.displayName,
          kabiSpokenText(entry.text, l10n),
        ),
        onProfile: () => onProfile(entry.author.username),
        onActions: () => unawaited(
          showLiveChatActions(
            context,
            ref,
            roomId: roomId,
            entry: entry,
            role: role,
            onProfile: onProfile,
          ),
        ),
        color: _messageBubble,
        cp: entry.cpBubble,
        message: _message(context, entry.text, cp: entry.cpBubble),
      ),
      // This person's own line on its way: their picture and name, no
      // badges until the server stored it (D119: no badge without data).
      LiveChatPending(:final failed, :final text, :final authorName) => Opacity(
        opacity: failed ? 1 : 0.6,
        child: LiveChatAuthoredLine(
          name: authorName,
          avatarUrl: ref.watch(currentUserProvider)?.avatarUrl,
          maxWidth: boxMax,
          color: _messageBubble,
          label: [
            l10n.liveChatLineLabel(authorName, kabiSpokenText(text, l10n)),
            if (failed) l10n.liveChatFailed,
          ].join('. '),
          onActions: failed
              ? () => unawaited(_failedActions(context, ref, item))
              : null,
          message: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _message(context, text),
              if (failed)
                Text(
                  l10n.liveChatFailed,
                  style: context.textStyles.caption.copyWith(
                    color: const Color(0xFFFF8A9A),
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ),
      ),
      // CP-017 (owner, 2026-10-26): a public message, in a box of its own.
      LiveChatBulletLine(:final bullet) => LiveChatBulletBox(
        bullet: bullet,
        onTap: () => onProfile(bullet.sender.username),
      ),
      // D118: the room's rules, a red system line (not tappable).
      LiveChatNoticeLine() => LiveRoomRulesNotice(
        key: LiveRoomChatLines.noticeKey,
        text: l10n.liveRoomRulesNotice,
        label: l10n.liveRoomRulesLabel,
      ),
    };
  }

  /// D119: message boxes in the audio room take the reference's grey
  /// glass; on video they keep the caller's scrim (camera behind).
  Color get _messageBubble =>
      bubble == KAudioRoom.bubble ? LiveChatAuthoredLine.audioBubble : bubble;

  Widget _mediaLine(
    BuildContext context,
    WidgetRef ref,
    LiveChatEntry entry,
    LiveChatMedia media,
    double boxMax,
  ) {
    final l10n = context.l10n;
    final name = entry.author.displayName;
    final voice = entry.kind == LiveChatKind.voice;
    return LiveChatAuthoredLine(
      name: name,
      avatarUrl: entry.author.avatarUrl,
      role: entry.authorRole,
      badges: entry.authorBadges,
      maxWidth: boxMax,
      // The clip plays (or the picture opens) on a tap; a long press opens
      // the message's actions.
      mediaInside: true,
      label: voice
          ? l10n.liveChatVoiceLine(
              name,
              KFormat.countdown(Duration(milliseconds: media.durationMs ?? 0)),
            )
          : l10n.liveChatPictureLine(name),
      onProfile: () => onProfile(entry.author.username),
      onActions: () => unawaited(
        showLiveChatActions(
          context,
          ref,
          roomId: roomId,
          entry: entry,
          role: role,
          onProfile: onProfile,
        ),
      ),
      color: _messageBubble,
      cp: entry.cpBubble,
      message: voice
          ? LiveVoiceClipPill(key: ValueKey(media.id), media: media)
          : LiveChatPictureThumb(media: media),
    );
  }

  Widget _plain(BuildContext context, String text) => Text(
    text,
    style: context.textStyles.caption.copyWith(
      fontSize: 12.5,
      color: KAudioRoom.text,
      fontWeight: FontWeight.w600,
    ),
  );

  /// The message text in its line's box (D119: the name and badges sit
  /// above it).
  Widget _message(BuildContext context, String text, {bool cp = false}) {
    final styles = context.textStyles;
    const size = LiveChatAuthoredLine.textSize;
    return Text.rich(
      TextSpan(
        children: [
          // CP-021: the Exclusive Chat Bubble starts with a small heart.
          if (cp)
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              // Placed no taller than the text, so the line keeps its
              // height; the heart overflows its slot a little.
              child: Padding(
                padding: const EdgeInsetsDirectional.only(end: 4),
                child: SizedBox(
                  key: LiveRoomChatLines.cpHeartKey,
                  width: 15,
                  height: 11,
                  child: OverflowBox(
                    maxWidth: 15,
                    maxHeight: 15,
                    child: Image.asset(
                      LiveCpChatBubble.heart,
                      width: 15,
                      height: 15,
                      excludeFromSemantics: true,
                    ),
                  ),
                ),
              ),
            ),
          // Kabi emoji tokens (D66) show as the animated emoji, inline; the
          // text is isolated so a mixed-direction message keeps its order.
          TextSpan(
            style: styles.body.copyWith(
              fontSize: size,
              height: 1.3,
              color: KAudioRoom.text,
              fontWeight: FontWeight.w500,
            ),
            children: [
              const TextSpan(text: '\u2068'),
              ...kabiInlineSpans(text, size: size * KKabiEmoji.inlineScale),
              const TextSpan(text: '\u2069'),
            ],
          ),
        ],
      ),
      textScaler: MediaQuery.textScalerOf(context)
          .clamp(maxScaleFactor: KMetrics.overlayMaxTextScale),
    );
  }

  Future<void> _failedActions(
    BuildContext context,
    WidgetRef ref,
    LiveChatPending line,
  ) async {
    final l10n = context.l10n;
    final chat = ref.read(liveChatProvider(roomId).notifier);
    final choice = await showModalBottomSheet<bool>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('liveChat.retry'),
              leading: const Icon(Icons.refresh_rounded),
              title: Text(l10n.liveChatRetry),
              onTap: () => Navigator.of(sheet).pop(true),
            ),
            ListTile(
              key: const Key('liveChat.discard'),
              leading: const Icon(Icons.delete_outline_rounded),
              title: Text(l10n.liveChatDiscard),
              onTap: () => Navigator.of(sheet).pop(false),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return;
    if (!choice) {
      chat.discard(line);
      return;
    }
    final failure = await chat.retry(line);
    if (failure != null && context.mounted) {
      KSnack.error(context, failureMessage(l10n, failure));
    }
  }
}

/// A compact system bubble (the empty hint).
class _Bubble extends StatelessWidget {
  const new({required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(8),
    ),
    child: child,
  );
}

/// The Exclusive Chat Bubble (CP-021, D112, §10.24; `LiveChatMessage.
/// cpBubble`): a pink box with a gold edge in the mood of the owner's
/// privilege art (`assets/cp_space/privilege_bubble.webp`). D119: it is the
/// whole line's box (picture, name, badges and message), the same size as
/// a plain line's glass so the chat never jumps; the text starts with a
/// small glossy heart (`assets/cp_space/heart.webp`).
class LiveCpChatBubble extends StatelessWidget {
  const new({required this.child, super.key});

  final Widget child;

  static const bubbleKey = Key('liveChat.cpBubble');
  static const heart = 'assets/cp_space/heart.webp';

  /// The author's name on the pink (a warm cream, like the art's gold).
  static const name = Color(0xFFFFF0B8);

  /// Pink to violet, sampled from the bubble art's deeper tones so white
  /// text stays readable (≥ 4.5 : 1 at 14 pt).
  static const colors = [Color(0xFFD62F7E), Color(0xFFA22BB0)];
  static const edge = Color(0xFFFFC96B);

  @override
  Widget build(BuildContext context) => Container(
    key: bubbleKey,
    // The 1 pt edge sits inside the plain box's padding.
    padding: LiveChatAuthoredLine.boxPadding.subtract(
      const EdgeInsetsDirectional.all(1),
    ),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: AlignmentDirectional.centerStart,
        end: AlignmentDirectional.centerEnd,
        colors: colors,
      ),
      borderRadius: BorderRadius.all(
        Radius.circular(LiveChatAuthoredLine.radius),
      ),
      border: Border.fromBorderSide(BorderSide(color: edge)),
      boxShadow: [BoxShadow(color: Color(0x55FF4FA0), blurRadius: 6)],
    ),
    child: child,
  );
}

/// D119 (owner: "make the chat text like this", reference look only; then
/// "the box must cover the whole person together with what they sent"):
/// one chat message in one rounded see-through box — the author's round
/// picture at the reading start, then a column with the name (muted, one
/// line), a row of small badges (role, charm and support levels, family —
/// only those the data has) and the message (text, voice clip or picture).
/// The box hugs its content, up to [maxWidth]; a CP line (D112) draws it
/// pink. A tap on the picture or the name opens the person card
/// ([onProfile]); a tap anywhere else in the box, or a long press, opens
/// the message's actions ([onActions]). With [mediaInside] the clip's or
/// picture's own tap plays or opens it.
class LiveChatAuthoredLine extends StatelessWidget {
  const new({
    required this.name,
    required this.avatarUrl,
    required this.label,
    required this.message,
    required this.maxWidth,
    required this.color,
    super.key,
    this.role,
    this.badges,
    this.cp = false,
    this.onProfile,
    this.onActions,
    this.mediaInside = false,
  });

  final String name;
  final String? avatarUrl;
  final LiveChatRole? role;
  final LiveChatAuthorBadges? badges;

  /// What a screen reader says for the line (badges are added to it).
  final String label;

  /// The text, or the voice clip / picture.
  final Widget message;
  final double maxWidth;

  /// The box's glass (ignored for a [cp] line).
  final Color color;
  final bool cp;
  final VoidCallback? onProfile;
  final VoidCallback? onActions;
  final bool mediaInside;

  /// Geometry from the owner's reference, scaled to a 32 pt picture
  /// (measured 46 px there, so × 0.70), then the owner's one-box change:
  /// the box 14 pt corners and 8 pt padding (12 at the end); the column
  /// 8 pt after the picture; the name 2 pt down (12.5 pt), 18 pt badges and
  /// the message stacked 4 and 5 pt apart; 14 pt text (measured 14.6).
  static const double avatar = 32;
  static const double gap = 8;
  static const double nameTop = 2;
  static const double nameSize = 12.5;
  static const double textSize = 14;
  static const double radius = 14;
  static const double badgeRowHeight = 18;
  static const EdgeInsetsDirectional boxPadding =
      EdgeInsetsDirectional.fromSTEB(8, 8, 12, 8);

  /// The reference's glass: a half-see-through grey over the room.
  static const audioBubble = Color(0x8C4A4754);

  /// The name: muted white.
  static const nameColor = Color(0xB3FFFFFF);

  static const boxKey = Key('liveChat.box');
  static const avatarKey = Key('liveChat.avatar');
  static const nameKey = Key('liveChat.name');

  /// The message (text, clip or picture) inside the box.
  static const bubbleKey = Key('liveChat.bubble');

  /// The chat's width, and the widest a box gets: 80 % of the screen, at
  /// most 340 pt.
  static double chatMaxWidth(BuildContext context) =>
      math.min(MediaQuery.sizeOf(context).width * 0.8, 340);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final badges = this.badges;
    final spoken = [
      label,
      if (badges?.charmLevel case final level?) l10n.liveChatCharmLabel(level),
      if (badges?.supportLevel case final level?)
        l10n.liveChatSupportLabel(level),
      if (badges?.family case final family?)
        l10n.liveChatFamilyLabel(
          KFormat.bidiIsolate(family.name),
          family.level,
        ),
    ].join('. ');
    final scaler = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: KMetrics.overlayMaxTextScale);
    final row = LiveChatBadgeRow(role: role, badges: badges);
    final profile = onProfile;
    // The picture and the name are in the line's label already.
    Widget tapProfile(Widget child) => ExcludeSemantics(
      child: profile == null
          ? child
          : GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: profile,
              child: child,
            ),
    );
    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        tapProfile(
          KAvatar(
            key: avatarKey,
            name: name,
            imageUrl: avatarUrl,
            size: avatar,
          ),
        ),
        const SizedBox(width: gap),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              tapProfile(
                Padding(
                  padding: const EdgeInsets.only(top: nameTop),
                  child: Text(
                    KFormat.bidiIsolate(name),
                    key: nameKey,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textScaler: scaler,
                    style: context.textStyles.caption.copyWith(
                      fontSize: nameSize,
                      height: 1.25,
                      color: cp ? LiveCpChatBubble.name : nameColor,
                      fontWeight: FontWeight.w500,
                      shadows: const [
                        Shadow(color: Color(0x66000000), blurRadius: 2),
                      ],
                    ),
                  ),
                ),
              ),
              if (row.isNotEmpty) ...[const SizedBox(height: 4), row],
              const SizedBox(height: 5),
              KeyedSubtree(key: bubbleKey, child: message),
            ],
          ),
        ),
      ],
    );
    final box = ConstrainedBox(
      key: boxKey,
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: cp
          ? LiveCpChatBubble(child: content)
          : Container(
              padding: boxPadding,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(radius),
              ),
              child: content,
            ),
    );
    final line = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onActions,
      onLongPress: onActions,
      child: box,
    );
    // A media line keeps its player's own button for screen readers.
    return mediaInside
        ? Semantics(
            container: true,
            label: spoken,
            onTap: onActions,
            onLongPress: onActions,
            child: line,
          )
        : Semantics(
            container: true,
            button: onActions != null,
            label: spoken,
            onTap: onActions,
            onLongPress: onActions,
            excludeSemantics: true,
            child: line,
          );
  }
}

/// D119: the small badges under a chat author's name, at the reading start:
/// the host or moderator tag, the charm level (the charm pack's creature,
/// D101), the support level (the level pack's emblem, D72) and the family
/// chip — only what [badges] carries. Fixed-size art: the text scale does
/// not grow it (the line's label says it).
class LiveChatBadgeRow extends StatelessWidget {
  const new({required this.role, required this.badges, super.key});

  final LiveChatRole? role;
  final LiveChatAuthorBadges? badges;

  static const roleKey = Key('liveChat.badge.role');
  static const charmKey = Key('liveChat.badge.charm');
  static const supportKey = Key('liveChat.badge.support');
  static const familyKey = Key('liveChat.badge.family');

  static const double _space = 5;

  bool get isNotEmpty =>
      role == LiveChatRole.host ||
      role == LiveChatRole.moderator ||
      badges?.charmLevel != null ||
      badges?.supportLevel != null ||
      badges?.family != null;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final badges = this.badges;
    final tag = switch (role) {
      LiveChatRole.host => l10n.liveChatHostBadge,
      LiveChatRole.moderator => l10n.liveChatModeratorBadge,
      _ => null,
    };
    const h = LiveChatAuthoredLine.badgeRowHeight;
    return ExcludeSemantics(
      child: MediaQuery.withNoTextScaling(
        // A row (not a wrap): each badge takes its own width; the family
        // chip gives way first (its name ends with an ellipsis).
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (tag != null)
              Container(
                key: roleKey,
                height: h - 2,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: role == LiveChatRole.host
                      ? KAudioRoom.hostTag
                      : const Color(0xFFFFB13B),
                  borderRadius: BorderRadius.circular(KRadius.pill),
                ),
                child: Text(
                  tag,
                  style: context.textStyles.caption.copyWith(
                    fontSize: 10.5,
                    height: 1.1,
                    color: const Color(0xFF14123A),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            if (tag != null) const SizedBox(width: _space),
            if (badges?.charmLevel case final level?) ...[
              SizedBox(
                key: charmKey,
                height: h,
                child: Center(
                  widthFactor: 1,
                  child: CharmLevelBadge(level: level),
                ),
              ),
              const SizedBox(width: _space),
            ],
            if (badges?.supportLevel case final level?) ...[
              SizedBox(
                key: supportKey,
                height: h,
                child: Center(
                  widthFactor: 1,
                  child: KLevelBadge(
                    category: LevelCategory.support,
                    levelNumber: level,
                    height: h / 1.5,
                  ),
                ),
              ),
              const SizedBox(width: _space),
            ],
            if (badges?.family case final family?)
              Flexible(
                child: LiveChatFamilyChip(
                  key: familyKey,
                  name: family.name,
                  level: family.level,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// D119: the author's family under their name in the chat — a small blue
/// to violet pill with the family level in a ring and the family's name
/// (Kabso's own look; one line, cut with an ellipsis).
class LiveChatFamilyChip extends StatelessWidget {
  const new({required this.name, required this.level, super.key});

  final String name;
  final int level;

  static const colors = [Color(0xFF2E5BFF), Color(0xFF7B5CFF)];

  @override
  Widget build(BuildContext context) {
    const h = LiveChatAuthoredLine.badgeRowHeight;
    return Container(
      height: h,
      constraints: const BoxConstraints(maxWidth: 132),
      padding: const EdgeInsetsDirectional.only(start: 1.5, end: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(KRadius.pill),
        gradient: const LinearGradient(
          begin: AlignmentDirectional.centerStart,
          end: AlignmentDirectional.centerEnd,
          colors: colors,
        ),
        border: Border.all(color: const Color(0x59FFFFFF), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: h - 3.5,
            height: h - 3.5,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF1A2F8F),
              border: Border.all(color: const Color(0xFFDDE6FF)),
            ),
            child: Text(
              '$level',
              textDirection: TextDirection.ltr,
              style: const TextStyle(
                fontFamily: KFonts.latin,
                fontSize: 9,
                height: 1,
                fontWeight: FontWeight.w800,
                color: Color(0xFFFFFFFF),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              KFormat.bidiIsolate(name),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textStyles.caption.copyWith(
                fontSize: 11,
                height: 1.1,
                color: const Color(0xFFFFFFFF),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// What a chat message offers to the caller ([role]): the author's profile,
/// delete (the author, the host, a moderator — not on the host's or another
/// moderator's), mute in chat (the host and moderators, same limits), and
/// report (anyone signed in but the author). The server has the last word.
Future<void> showLiveChatActions(
  BuildContext context,
  WidgetRef ref, {
  required String roomId,
  required LiveChatEntry entry,
  required LiveChatViewerRole role,
  required void Function(String username) onProfile,
}) async {
  final l10n = context.l10n;
  final me = ref.read(currentUserProvider);
  final mine = me != null && entry.author.id == me.id;
  final protected =
      entry.authorRole == LiveChatRole.host ||
      (role == LiveChatViewerRole.moderator &&
          entry.authorRole == LiveChatRole.moderator);
  final moderates =
      role == LiveChatViewerRole.host || role == LiveChatViewerRole.moderator;
  final canDelete = mine || (moderates && !protected);
  final canMute = moderates && !mine && !protected;
  final canReport = me != null && !mine;
  final chat = ref.read(liveChatProvider(roomId).notifier);
  final name = entry.author.displayName;
  final handle = '@${entry.author.username}';

  // Whether the author is muted now (only the host and moderators ask).
  var muted = false;
  if (canMute) {
    try {
      final mutes = await ref.read(liveChatProvider(roomId).notifier).mutes();
      muted = mutes.any((m) => m.user.id == entry.author.id);
    } on Object {
      // Offer muting; the server answers either way (idempotent).
    }
    if (!context.mounted) return;
  }

  final action = await showModalBottomSheet<String>(
    context: context,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(
              KFormat.bidiIsolate(switch (entry.kind) {
                LiveChatKind.voice => l10n.liveVoiceRecord,
                LiveChatKind.image => l10n.liveChatPicture,
                LiveChatKind.text => kabiSpokenText(entry.text, l10n),
              }),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(handle),
          ),
          ListTile(
            key: const Key('liveChat.action.profile'),
            leading: const Icon(Icons.person_outline_rounded),
            title: Text(l10n.liveChatViewProfile),
            onTap: () => Navigator.of(sheet).pop('profile'),
          ),
          if (canDelete)
            ListTile(
              key: const Key('liveChat.action.delete'),
              leading: const Icon(Icons.delete_outline_rounded),
              title: Text(l10n.liveChatDelete),
              onTap: () => Navigator.of(sheet).pop('delete'),
            ),
          if (canMute)
            ListTile(
              key: const Key('liveChat.action.mute'),
              leading: Icon(
                muted ? Icons.chat_bubble_outline : Icons.speaker_notes_off,
              ),
              title: Text(
                muted
                    ? l10n.liveChatUnmuteUser(KFormat.bidiIsolate(name))
                    : l10n.liveChatMuteUser(KFormat.bidiIsolate(name)),
              ),
              onTap: () => Navigator.of(sheet).pop(muted ? 'unmute' : 'mute'),
            ),
          if (canReport)
            ListTile(
              key: const Key('liveChat.action.report'),
              leading: const Icon(Icons.flag_outlined),
              title: Text(l10n.liveChatReport),
              onTap: () => Navigator.of(sheet).pop('report'),
            ),
        ],
      ),
    ),
  );
  if (action == null || !context.mounted) return;
  try {
    switch (action) {
      case 'profile':
        onProfile(entry.author.username);
      case 'delete':
        await chat.delete(entry);
        if (context.mounted) KSnack.success(context, l10n.liveChatDeleted);
      case 'mute' || 'unmute':
        await chat.setMuted(entry.author.username, muted: action == 'mute');
        if (context.mounted) {
          KSnack.success(
            context,
            action == 'mute'
                ? l10n.liveChatUserMuted(KFormat.bidiIsolate(name))
                : l10n.liveChatUserUnmuted(KFormat.bidiIsolate(name)),
          );
        }
      case 'report':
        final reason = await pickReportReason(
          context,
          l10n.liveChatReportTitle,
        );
        if (reason == null) return;
        await chat.report(entry, reason);
        if (context.mounted) KSnack.success(context, l10n.feedPostReported);
    }
  } on Object catch (e) {
    if (context.mounted) {
      KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
    }
  }
}

/// The composer's state for the caller: who may write and, if not, why.
({bool canWrite, String hint}) liveChatComposerHint(
  AppLocalizations l10n, {
  required LiveChatState chat,
  required LiveChatViewerRole role,
}) {
  if (role == LiveChatViewerRole.guest) {
    return (canWrite: false, hint: l10n.liveChatSignIn);
  }
  // Chat off says more than a mute (and outlives it).
  if (!chat.enabled && role != LiveChatViewerRole.host) {
    return (canWrite: false, hint: l10n.liveChatOff);
  }
  if (chat.muted) return (canWrite: false, hint: l10n.liveChatMutedPill);
  return (canWrite: true, hint: l10n.goLiveChatPill);
}

/// Sends the composer's text; the field empties at once (the line shows
/// as sending). A refusal is said in a snack.
Future<void> sendLiveChatFrom(
  BuildContext context,
  WidgetRef ref, {
  required String roomId,
  required TextEditingController field,
}) async {
  final text = field.text;
  if (text.trim().isEmpty) return;
  field.clear();
  await sendLiveChatText(context, ref, roomId: roomId, text: text);
}

/// Sends [text] (e.g. a Kabi emoji's token); a refusal shows as a snack.
Future<void> sendLiveChatText(
  BuildContext context,
  WidgetRef ref, {
  required String roomId,
  required String text,
}) async {
  final l10n = context.l10n;
  final failure = await ref.read(liveChatProvider(roomId).notifier).send(text);
  if (failure != null && context.mounted) {
    KSnack.error(context, failureMessage(l10n, failure));
  }
}

/// Owner (2026-10-26, D119): "pin the join line at the bottom of the chat,
/// each join replaces it". One compact strip under the newest message
/// shows only the latest "X joined" (with "+N" when others joined within
/// the second before); a new join swaps it with a short fade and slide
/// (none with reduced motion). CTO choice (the owner may change it): it
/// hides 4 s after the last join.
class LiveChatJoinStrip extends StatefulWidget {
  const new({required this.join, required this.color, super.key});

  final LiveChatJoinLine? join;
  final Color color;

  static const stripKey = Key('liveChat.joinStrip');
  static const hideAfter = Duration(seconds: 4);
  static const swap = Duration(milliseconds: 220);

  @override
  State<LiveChatJoinStrip> createState() => _LiveChatJoinStripState();
}

class _LiveChatJoinStripState extends State<LiveChatJoinStrip> {
  LiveChatJoinLine? _shown;
  Timer? _hide;

  @override
  void initState() {
    super.initState();
    _show(widget.join);
  }

  @override
  void didUpdateWidget(LiveChatJoinStrip old) {
    super.didUpdateWidget(old);
    if (widget.join?.serial != old.join?.serial) _show(widget.join);
  }

  void _show(LiveChatJoinLine? join) {
    if (join == null) return;
    _shown = join;
    _hide?.cancel();
    _hide = Timer(LiveChatJoinStrip.hideAfter, () {
      if (mounted) setState(() => _shown = null);
    });
  }

  @override
  void dispose() {
    _hide?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final shown = _shown;
    final still = MediaQuery.disableAnimationsOf(context);
    final Widget child;
    if (shown == null) {
      child = const SizedBox.shrink(key: ValueKey('liveChat.join.none'));
    } else {
      final text = l10n.chatJoined(KFormat.bidiIsolate(shown.user.displayName));
      final style = context.textStyles.caption.copyWith(
        fontSize: 12.5,
        color: KAudioRoom.text,
        fontWeight: FontWeight.w600,
      );
      child = Padding(
        key: ValueKey('liveChat.join.${shown.serial}'),
        padding: const EdgeInsets.only(top: 6),
        child: Semantics(
          container: true,
          liveRegion: true,
          label: shown.burst > 0 ? '$text +${shown.burst}' : text,
          excludeSemantics: true,
          child: Opacity(
            opacity: 0.85,
            child: Container(
              key: LiveChatJoinStrip.stripKey,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: style,
                    ),
                  ),
                  if (shown.burst > 0) ...[
                    const SizedBox(width: 6),
                    Text(
                      '+${shown.burst}',
                      textDirection: TextDirection.ltr,
                      style: style.copyWith(color: KAudioRoom.textSoft),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }
    return AnimatedSwitcher(
      duration: still ? Duration.zero : LiveChatJoinStrip.swap,
      layoutBuilder: (current, previous) => Stack(
        alignment: AlignmentDirectional.bottomStart,
        children: [...previous, ?current],
      ),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.5),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// A bullet ("public message", CP-017) in the room chat (owner,
/// 2026-10-26): a rounded purple-to-pink card with a gold rim and a soft
/// glow, a megaphone and the "Public message" tag, the sender's picture and
/// name, and the text. It grows in once (still with reduced motion) and
/// then stays like a message. A tap opens the sender's card.
class LiveChatBulletBox extends StatelessWidget {
  const new({required this.bullet, this.onTap, super.key});

  final LiveBullet bullet;
  final VoidCallback? onTap;

  static Key keyFor(String id) => Key('liveChat.bullet.$id');

  static const _gold = Color(0xFFFFD66B);
  static const _white = Color(0xFFFFFFFF);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final styles = context.textStyles;
    final name = bullet.sender.displayName;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final scaler = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: KMetrics.overlayMaxTextScale);
    final box = Container(
      key: keyFor(bullet.id),
      padding: const EdgeInsetsDirectional.fromSTEB(8, 7, 12, 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [Color(0xF27B4DFF), Color(0xF2C04BEA), Color(0xF2FF5FA2)],
        ),
        border: Border.all(color: _gold.withValues(alpha: 0.85), width: 1.2),
        boxShadow: const [
          BoxShadow(color: Color(0x66C04BEA), blurRadius: 14),
          BoxShadow(color: Color(0x33FFD66B), blurRadius: 4, spreadRadius: 1),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsetsDirectional.fromSTEB(5, 2, 7, 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(KRadius.pill),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFE28A), Color(0xFFF2B544)],
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.campaign_rounded,
                      size: 13,
                      color: Color(0xFF6A3A00),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      l10n.liveBulletTag,
                      textScaler: scaler,
                      style: styles.caption.copyWith(
                        fontSize: 10.5,
                        height: 1.2,
                        color: const Color(0xFF6A3A00),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(1.5),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: _gold,
                ),
                child: KAvatar(
                  name: name,
                  imageUrl: bullet.sender.avatarUrl,
                  size: 30,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      KFormat.bidiIsolate(name),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textScaler: scaler,
                      style: styles.caption.copyWith(
                        fontSize: 12,
                        height: 1.25,
                        color: _gold,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      KFormat.bidiIsolate(bullet.text),
                      textScaler: scaler,
                      style: styles.bodyStrong.copyWith(
                        fontSize: 14,
                        height: 1.3,
                        color: _white,
                        fontWeight: FontWeight.w700,
                        shadows: const [
                          Shadow(color: Color(0x55000000), blurRadius: 2),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
    return Semantics(
      button: onTap != null,
      label: l10n.liveBulletLabel(name, bullet.text),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: reduced ? 1 : 0, end: 1),
          duration: reduced ? Duration.zero : const Duration(milliseconds: 380),
          curve: Curves.easeOutBack,
          builder: (context, t, child) => Opacity(
            opacity: t.clamp(0, 1),
            child: Transform.scale(
              scale: 0.85 + 0.15 * t,
              alignment: AlignmentDirectional.centerStart,
              child: child,
            ),
          ),
          child: box,
        ),
      ),
    );
  }
}

/// Owner (2026-10-26, D118): the system line with the room's rules when a
/// live opens — a very see-through red pill with red text and a red shield,
/// distinct from every message (Kabso's wording, l10n). [label] names it for
/// screen readers.
class LiveRoomRulesNotice extends StatelessWidget {
  const new({required this.text, required this.label, super.key});

  final String text;
  final String label;

  /// Owner: a red box with high transparency and red text.
  static const fill = Color(0x2EFF3B4E);
  static const edge = Color(0xFFFF5A6E);
  static const icon = Color(0xFFFF4D5E);
  static const textColor = Color(0xFFFF4D5E);

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: '$label. $text',
    excludeSemantics: true,
    child: Container(
      padding: const EdgeInsetsDirectional.fromSTEB(8, 6, 10, 6),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: edge.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.shield_rounded, size: 15, color: icon),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: context.textStyles.caption.copyWith(
                fontSize: 12,
                height: 1.35,
                color: textColor,
                fontWeight: FontWeight.w700,
                shadows: const [
                  Shadow(color: Color(0x99000000), blurRadius: 3),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
