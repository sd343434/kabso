import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/data/live_blocked_words_repository.dart';
import 'package:kabso_live/features/live/data/live_schedule_repository.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/presentation/go_live/go_live_parts.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_audio_room.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_blocked_words_sheet.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_cover_picture.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_room_tools.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_schedule_sheet.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_theme_art.dart';
import 'package:kabso_live/features/live/presentation/go_live/seat_controls.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Audio go-live, laid out after the owner's references (refs 65, 66, 68,
/// iPhone 15 Pro Max, 430 pt): the room's own look behind everything, ✕
/// at the top, the room card (the host's picture, the title and its
/// counter, the categories), the empty seats, then the tools (seats,
/// theme, voice, settings), Go LIVE and the mode tabs.
///
/// Every control works. What the reference has without a contract or a
/// feature here is left out: a room photo ("Edit"), the announcement, the
/// academy, Game LIVE.
class GoLiveAudioSetup extends StatelessWidget {
  const new({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.theme,
    required this.onTheme,
    required this.categories,
    required this.category,
    required this.onCategory,
    required this.allowGuests,
    required this.onAllowGuests,
    required this.micEnabled,
    required this.onMic,
    required this.noiseReduction,
    required this.enhance,
    required this.onVoice,
    required this.seatCounts,
    required this.seatCount,
    required this.onSeatCount,
    required this.busy,
    required this.onStart,
    required this.onClose,
    required this.onMode,
    required this.hostName,
    required this.hostAvatarUrl,
    super.key,
    this.onShare,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final String theme;
  final VoidCallback? onTheme;
  final List<LiveCategory> categories;
  final String? category;
  final ValueChanged<String?> onCategory;
  final bool allowGuests;
  final ValueChanged<bool>? onAllowGuests;

  /// Settings → Share (ref 71): copies the live's invitation.
  final VoidCallback? onShare;
  final bool micEnabled;
  final VoidCallback? onMic;
  final bool noiseReduction;
  final bool enhance;
  final void Function({bool? noiseReduction, bool? enhance})? onVoice;
  final List<int> seatCounts;
  final int seatCount;
  final ValueChanged<int>? onSeatCount;
  final bool busy;
  final VoidCallback? onStart;
  final VoidCallback? onClose;

  /// A mode tab: switch to multi-guest or LIVE.
  final ValueChanged<LiveRoomMode>? onMode;
  final String hostName;
  final String? hostAvatarUrl;

  static const guestsKey = Key('goLive.audio.guests');
  static const noiseKey = Key('goLive.audio.noise');
  static const enhanceKey = Key('goLive.audio.enhance');
  static const micKey = Key('goLive.audio.mic');
  static const themeKey = Key('goLive.audio.theme');
  static const seatsKey = Key('goLive.audio.seats');
  static const voiceKey = Key('goLive.audio.voice');
  static const settingsKey = Key('goLive.audio.settings');
  static const Key startKey = GoLiveKeys.start;

  /// Measured on the owner's reference (430 pt; y from the safe area).
  static const _cardTop = 56.1;
  static const _seatsGap = 31.2;
  static const _seat = 55.2;
  static const _seatPitch = 84.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // The reference darkens the room's look at the top and the bottom.
    final background = Stack(
      fit: StackFit.expand,
      children: [
        if (theme == LiveThemes.classic)
          const LiveAudioRoomBackground()
        else
          LiveThemeBackground(theme: theme, waves: true),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x66000000),
                Color(0x00000000),
                Color(0x00000000),
                Color(0xD90A0820),
              ],
              stops: [0, 0.14, 0.62, 1],
            ),
          ),
        ),
      ],
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        background,
        SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ✕ centred 21.8 pt down, 21.2 pt from the end (ref 65).
              SizedBox(
                height: _cardTop,
                child: Align(
                  alignment: AlignmentDirectional.topEnd,
                  child: Transform.translate(
                    offset: Offset(
                      Directionality.of(context) == TextDirection.rtl
                          ? -2.8
                          : 2.8,
                      -2.1,
                    ),
                    child: IconButton(
                      key: const Key('goLive.close'),
                      tooltip: l10n.liveClose,
                      onPressed: onClose,
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Color(0xFFFFFFFF),
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14.9),
                child: _RoomCard(
                  controller: controller,
                  focusNode: focusNode,
                  enabled: enabled,
                  hostName: hostName,
                  hostAvatarUrl: hostAvatarUrl,
                  categories: categories,
                  category: category,
                  onCategory: onCategory,
                ),
              ),
              const SizedBox(height: _seatsGap),
              _SeatsPreview(count: seatCount),
              const Spacer(),
              _Tools(
                children: [
                  _Tool(
                    key: seatsKey,
                    icon: SvgPicture.asset(
                      'assets/live_room_icons/seat_outline.svg',
                      width: 23.6,
                    ),
                    label: l10n.liveSeats,
                    onTap: onSeatCount == null
                        ? null
                        : () => showLiveSeatCountPicker(
                            context,
                            counts: seatCounts,
                            selected: seatCount,
                            onSelect: onSeatCount!,
                          ),
                  ),
                  _Tool(
                    key: themeKey,
                    icon: const Icon(
                      Icons.checkroom_rounded,
                      color: Color(0xFFFFFFFF),
                      size: 26,
                    ),
                    label: l10n.goLiveTheme,
                    onTap: onTheme,
                  ),
                  _Tool(
                    key: voiceKey,
                    icon: const Icon(
                      Icons.tune_rounded,
                      color: Color(0xFFFFFFFF),
                      size: 26,
                    ),
                    label: l10n.liveToolsVoice,
                    onTap: onVoice == null
                        ? null
                        : () => showLiveVoiceSheet(
                            context,
                            noiseReduction: noiseReduction,
                            enhance: enhance,
                            onChanged: ({noiseReduction, enhance}) async =>
                                onVoice!(
                                  noiseReduction: noiseReduction,
                                  enhance: enhance,
                                ),
                            micEnabled: micEnabled,
                            onMic: onMic,
                            micKey: micKey,
                            noiseKey: noiseKey,
                            enhanceKey: enhanceKey,
                          ),
                  ),
                  _Tool(
                    key: settingsKey,
                    icon: const Icon(
                      Icons.settings_outlined,
                      color: Color(0xFFFFFFFF),
                      size: 26,
                    ),
                    label: l10n.settingsTitle,
                    onTap: onAllowGuests == null
                        ? null
                        : () => showLiveSetupSettings(
                            context,
                            allowGuests: allowGuests,
                            onAllowGuests: onAllowGuests!,
                            onShare: onShare,
                            guestsKey: guestsKey,
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 26.9),
              Center(
                child: _GoLiveButton(
                  label: busy ? l10n.goLiveStarting : l10n.goLiveStart,
                  busy: busy,
                  onPressed: onStart,
                ),
              ),
              const SizedBox(height: 29.1),
              _ModeTabs(selected: LiveRoomMode.audio, onSelect: onMode),
              const SizedBox(height: 24.9),
            ],
          ),
        ),
      ],
    );
  }
}

/// Digits for a seat count.
abstract final class KFormatSeat {
  static String of(int count) => count.toString();
}

/// An icon for a category slug (server categories carry no icon).
IconData categoryIcon(String slug) => switch (slug) {
  'chat' => Icons.chat_bubble_outline_rounded,
  'music' => Icons.music_note_outlined,
  'games' || 'gaming' => Icons.sports_esports_outlined,
  'friends' || 'dating' => Icons.favorite_border_rounded,
  'talent' || 'talents' => Icons.star_outline_rounded,
  'stories' => Icons.menu_book_outlined,
  'advice' || 'consult' => Icons.school_outlined,
  'voice' || 'voices' => Icons.graphic_eq_rounded,
  _ => Icons.tag_rounded,
};

/// The owner's picture for a category slug, or null (then [categoryIcon]).
String? categoryArt(String slug) => switch (slug) {
  'chat' => 'assets/category_icons/chat.png',
  'dating' || 'friends' => 'assets/category_icons/dating.png',
  'games' || 'gaming' => 'assets/category_icons/games.png',
  'interests' || 'hobbies' => 'assets/category_icons/interests.png',
  'emotional' || 'feelings' => 'assets/category_icons/emotional.png',
  _ => null,
};

/// The glass room card (ref 65): 134.2 pt tall, a 1 pt light edge.
class _RoomCard extends StatelessWidget {
  const new({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.hostName,
    required this.hostAvatarUrl,
    required this.categories,
    required this.category,
    required this.onCategory,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final String hostName;
  final String? hostAvatarUrl;
  final List<LiveCategory> categories;
  final String? category;
  final ValueChanged<String?> onCategory;

  static const _white = Color(0xFFFFFFFF);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.textStyles;
    return Container(
      constraints: const BoxConstraints(minHeight: 134.2),
      decoration: BoxDecoration(
        color: const Color(0x1AFFFFFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x80D7C6FF)),
      ),
      padding: const EdgeInsetsDirectional.fromSTEB(10.3, 8.4, 10.3, 6.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The live cover with Edit (CP-015), else the host's picture.
              LiveCoverPicture(
                hostName: hostName,
                hostAvatarUrl: hostAvatarUrl,
                enabled: enabled,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      key: GoLiveKeys.title,
                      controller: controller,
                      focusNode: focusNode,
                      enabled: enabled,
                      maxLength: GoLiveTitleCard.titleMaxLength,
                      cursorColor: _white,
                      style: text.title.copyWith(
                        color: _white,
                        fontSize: 18,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                      ),
                      decoration: InputDecoration(
                        isCollapsed: true,
                        contentPadding: const EdgeInsets.only(top: 1),
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        counterText: '',
                        hintText: l10n.goLiveTitleHint,
                        hintStyle: text.title.copyWith(
                          color: _white.withValues(alpha: 0.6),
                          fontSize: 18,
                          height: 1.2,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // In place of the reference's announcement: the title
                    // counter (there is no announcement yet).
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: controller,
                      builder: (context, value, _) => Row(
                        children: [
                          Icon(
                            Icons.edit_outlined,
                            size: 14,
                            color: _white.withValues(alpha: 0.75),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${value.text.characters.length}/'
                            '${GoLiveTitleCard.titleMaxLength}',
                            textDirection: TextDirection.ltr,
                            style: text.body.copyWith(
                              color: _white.withValues(alpha: 0.75),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (categories.isNotEmpty) ...[
            const SizedBox(height: 10.3),
            SizedBox(
              height: 53.6,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final c in categories)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 10.3),
                      child: _CategoryTile(
                        slug: c.slug,
                        label: c.name,
                        icon: categoryIcon(c.slug),
                        selected: category == c.slug,
                        // Tapping the chosen one again: no category.
                        onTap: enabled
                            ? () =>
                                  onCategory(category == c.slug ? null : c.slug)
                            : null,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A category (ref 65): a 59.6 x 35 pt tile with its label 6.5 pt below.
class _CategoryTile extends StatelessWidget {
  const new({
    required this.slug,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String slug;
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: label,
    onTap: onTap,
    excludeSemantics: true,
    child: GestureDetector(
      key: GoLiveKeys.category(slug),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 59.6,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              height: 35,
              decoration: BoxDecoration(
                color: const Color(0x1FFFFFFF),
                borderRadius: BorderRadius.circular(6.5),
                border: Border.all(
                  color: selected
                      ? const Color(0xFFD4BDF5)
                      : const Color(0x00000000),
                  width: 1.4,
                ),
              ),
              alignment: Alignment.center,
              // The owner's picture (about 19.6 x 17.2 pt on ref 65), else
              // a plain icon.
              child: switch (categoryArt(slug)) {
                final art? => Image.asset(art, width: 23, height: 23),
                null => Icon(icon, size: 19.6, color: const Color(0xFFFFFFFF)),
              },
            ),
            const SizedBox(height: 3.6),
            // Like the reference, a long name may run past the tile
            // (e.g. "Emotional"); the gap to the next tile is 10.3 pt.
            SizedBox(
              height: 14.4,
              child: OverflowBox(
                maxWidth: 59.6 + 10,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: context.textStyles.caption.copyWith(
                    color: const Color(0xFFFFFFFF),
                    fontSize: 12,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// The room's empty seats (ref 65): 55.2 pt circles every 84 pt, five a
/// row, 19.2 pt from the edges; narrower screens shrink the pitch.
class _SeatsPreview extends StatelessWidget {
  const new({required this.count});

  final int count;

  static const _edge = 19.2;

  @override
  Widget build(BuildContext context) {
    const perRow = 5;
    const seat = GoLiveAudioSetup._seat;
    final rows = (count / perRow).ceil();
    return ExcludeSemantics(
      child: LayoutBuilder(
        builder: (context, box) {
          final pitch = ((box.maxWidth - 2 * _edge - seat) / (perRow - 1))
              .clamp(seat + 4, GoLiveAudioSetup._seatPitch);
          return Padding(
            padding: const EdgeInsetsDirectional.only(start: _edge),
            child: Column(
              children: [
                for (var r = 0; r < rows; r++)
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: r < rows - 1 ? pitch - seat : 0,
                    ),
                    child: Row(
                      children: [
                        for (
                          var i = r * perRow;
                          i < count && i < (r + 1) * perRow;
                          i++
                        ) ...[
                          if (i > r * perRow) SizedBox(width: pitch - seat),
                          const _EmptySeat(),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EmptySeat extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => Container(
    width: GoLiveAudioSetup._seat,
    height: GoLiveAudioSetup._seat,
    decoration: const BoxDecoration(
      color: Color(0x38FFFFFF),
      shape: BoxShape.circle,
    ),
    alignment: Alignment.center,
    child: Opacity(
      opacity: 0.65,
      child: SvgPicture.asset(
        'assets/live_room_icons/seat_outline.svg',
        width: 16.8,
      ),
    ),
  );
}

/// The tools row (ref 65): one every 62 pt, centred.
class _Tools extends StatelessWidget {
  const new({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [for (final c in children) SizedBox(width: 62, child: c)],
  );
}

class _Tool extends StatelessWidget {
  const new({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });

  final Widget icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onTap != null,
    label: label,
    onTap: onTap,
    excludeSemantics: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.4 : 1,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 26, child: Center(child: icon)),
            const SizedBox(height: 4.5),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.visible,
              softWrap: false,
              style: context.textStyles.caption.copyWith(
                color: const Color(0xFFFFFFFF),
                fontSize: 11.5,
                height: 1.2,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Go LIVE: the reference's 300.5 x 48.5 pt pill in Kabso's colours (the
/// owner asked for the brand's live gradient instead of the reference's
/// teal).
class _GoLiveButton extends StatelessWidget {
  const new({required this.label, required this.busy, required this.onPressed});

  final String label;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onPressed != null,
    label: label,
    onTap: onPressed,
    excludeSemantics: true,
    child: GestureDetector(
      key: GoLiveAudioSetup.startKey,
      onTap: onPressed,
      child: Opacity(
        opacity: onPressed == null && !busy ? 0.5 : 1,
        child: Container(
          width: 300.5,
          height: 48.5,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [KBrandColors.red400, KBrandColors.red500],
            ),
            borderRadius: BorderRadius.circular(24.25),
            boxShadow: [
              BoxShadow(
                color: KBrandColors.red500.withValues(alpha: 0.45),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: busy
              ? const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Color(0xFFFFFFFF),
                  ),
                )
              : Text(
                  label,
                  style: context.textStyles.bodyStrong.copyWith(
                    color: const Color(0xFFFFFFFF),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    ),
  );
}

/// Multi-guest · LIVE · Audio LIVE (ref 65): the chosen mode centred,
/// larger, with a dot under it; the others run off the start edge.
class _ModeTabs extends StatelessWidget {
  const new({required this.selected, required this.onSelect});

  final LiveRoomMode selected;
  final ValueChanged<LiveRoomMode>? onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.textStyles;
    final modes = [
      (LiveRoomMode.multi, l10n.goLiveModeMulti),
      (LiveRoomMode.solo, l10n.goLiveModeSolo),
      (LiveRoomMode.audio, l10n.goLiveModeAudio),
    ];
    final at = modes.indexWhere((m) => m.$1 == selected);
    Widget tab((LiveRoomMode, String) m) {
      final on = m.$1 == selected;
      return Semantics(
        button: true,
        selected: on,
        label: m.$2,
        onTap: on || onSelect == null ? null : () => onSelect!(m.$1),
        excludeSemantics: true,
        child: GestureDetector(
          key: GoLiveKeys.mode(m.$1),
          behavior: HitTestBehavior.opaque,
          onTap: on || onSelect == null ? null : () => onSelect!(m.$1),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7.5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  m.$2,
                  maxLines: 1,
                  softWrap: false,
                  style: text.title.copyWith(
                    color: on
                        ? const Color(0xFFFFFFFF)
                        : const Color(0xFFFFFFFF).withValues(alpha: 0.7),
                    fontSize: on ? 18 : 15,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6.1),
                Container(
                  width: 5.1,
                  height: 5.1,
                  decoration: BoxDecoration(
                    color: on
                        ? const Color(0xFFFFFFFF)
                        : const Color(0x00000000),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    Widget side(List<(LiveRoomMode, String)> items, {required bool before}) =>
        ClipRect(
          child: OverflowBox(
            maxWidth: double.infinity,
            alignment: before
                ? AlignmentDirectional.centerEnd
                : AlignmentDirectional.centerStart,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [for (final m in items) tab(m)],
            ),
          ),
        );
    return SizedBox(
      height: 34,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: side(modes.sublist(0, at), before: true)),
          tab(modes[at]),
          Expanded(child: side(modes.sublist(at + 1), before: false)),
        ],
      ),
    );
  }
}

/// Settings before going live (owner ref 71): Share, then the room's tools
/// that have no server yet (shown greyed with "Soon", never as working),
/// and who can watch (guests, CP-010). Rows 56 pt, an 11.4 pt grey band
/// between the two groups, labels 17 pt, chevrons #888A8F.
Future<void> showLiveSetupSettings(
  BuildContext context, {
  required bool allowGuests,
  required ValueChanged<bool> onAllowGuests,
  VoidCallback? onShare,
  Key? guestsKey,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: const Color(0xFFFFFFFF),
  barrierColor: const Color(0x00000000),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
  ),
  builder: (sheet) {
    var allow = allowGuests;
    final l10n = sheet.l10n;
    final text = sheet.textStyles;
    return StatefulBuilder(
      builder: (context, setState) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LiveWhiteSheetHeader(
              title: l10n.settingsTitle,
              centred: true,
              titleTop: 15.6,
            ),
            const SizedBox(height: 7),
            LiveSettingsRow(
              key: LiveSettingsRow.shareKey,
              label: l10n.liveSettingsShare,
              onTap: onShare == null
                  ? null
                  : () {
                      Navigator.of(sheet).pop();
                      onShare();
                    },
            ),
            // CP-016 B: the count, then the editor.
            Consumer(
              builder: (context, ref, _) => LiveSettingsRow(
                key: LiveSettingsRow.blockedWordsKey,
                label: l10n.liveSettingsBlockedWords,
                trailing: ref
                    .watch(liveBlockedWordsProvider)
                    .value
                    ?.length
                    .toString(),
                onTap: () => unawaited(showLiveBlockedWords(context)),
              ),
            ),
            // CP-016 C: the number of upcoming lives, then the schedule.
            Consumer(
              builder: (context, ref, _) => LiveSettingsRow(
                key: LiveSettingsRow.scheduleKey,
                label: l10n.liveSettingsSchedule,
                trailing: ref
                    .watch(liveScheduleProvider)
                    .value
                    ?.length
                    .toString(),
                onTap: () => unawaited(showLiveSchedule(context)),
              ),
            ),
            SwitchListTile(
              key: guestsKey,
              contentPadding: const EdgeInsetsDirectional.fromSTEB(
                17.5,
                0,
                12,
                0,
              ),
              title: Text(
                l10n.goLiveGuests,
                style: text.title.copyWith(
                  color: LiveSettingsRow.ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                allow
                    ? l10n.goLiveWatchEveryoneHint
                    : l10n.goLiveWatchSignedInHint,
                style: text.caption.copyWith(color: const Color(0xFF7A7B8C)),
              ),
              value: allow,
              onChanged: (v) {
                setState(() => allow = v);
                onAllowGuests(v);
              },
            ),
            const SizedBox(height: 4),
            const ColoredBox(
              color: Color(0xFFF3F3F3),
              child: SizedBox(height: 11.4, width: double.infinity),
            ),
            LiveSettingsRow(label: l10n.liveSettingsEventCenter),
            LiveSettingsRow(label: l10n.liveSettingsCreatorCenter),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  },
);

/// A row of a white live settings sheet (ref 71): the label, then a chevron
/// when it opens something ([onTap]); without [onTap] the feature has no
/// server yet, so it is greyed with "Soon" and does nothing.
class LiveSettingsRow extends StatelessWidget {
  const new({required this.label, super.key, this.onTap, this.trailing});

  static const shareKey = Key('liveSettings.share');
  static const blockedWordsKey = Key('liveSettings.blockedWords');
  static const scheduleKey = Key('liveSettings.schedule');
  static const ink = Color(0xFF000000);

  final String label;
  final VoidCallback? onTap;

  /// A value before the chevron (a count, the current choice).
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.textStyles;
    final soon = onTap == null;
    const grey = Color(0xFF888A8F);
    return Semantics(
      button: !soon,
      enabled: !soon,
      label: soon ? '$label, ${l10n.liveSoon}' : label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 56,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(17.5, 0, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.title.copyWith(
                      color: soon ? const Color(0xFFB4B6BB) : ink,
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (soon)
                  Text(
                    l10n.liveSoon,
                    style: text.caption.copyWith(
                      color: const Color(0xFFB4B6BB),
                      fontSize: 13,
                    ),
                  )
                else ...[
                  if (trailing case final t?)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: Text(
                        t,
                        style: text.body.copyWith(
                          color: const Color(0xFFA4A9AC),
                          fontSize: 15,
                        ),
                      ),
                    ),
                  Icon(
                    Directionality.of(context) == TextDirection.rtl
                        ? Icons.chevron_left_rounded
                        : Icons.chevron_right_rounded,
                    color: grey,
                    size: 26,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
