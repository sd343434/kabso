import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/data/live_blocked_words_repository.dart';
import 'package:kabso_live/features/live/data/live_schedule_repository.dart';
import 'package:kabso_live/features/live/data/streamer/live_streamer_platform.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/presentation/go_live/go_live_parts.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_audio_room.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_blocked_words_sheet.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_cover_picture.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_glass.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_podcast_room.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_podcast_sheets.dart';
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
    this.mode = LiveRoomMode.audio,
    this.podcast = const PodcastSetup(topic: PodcastTopic.business),
    this.onPodcast,
    this.podcastConfig = const LivePodcastConfig(),
    this.podcastGuests = const [],
    this.preview,
    this.onGuests,
    this.schedule = false,
    this.onSchedule,
  });

  /// D212: AUDIO or PODCAST (the podcast's own setup).
  final LiveRoomMode mode;

  /// D212: the podcast's topic, hands and question time.
  final PodcastSetup podcast;
  final ValueChanged<PodcastSetup>? onPodcast;
  final LivePodcastConfig podcastConfig;

  /// D212: the picked guests (up to 3) and the picker.
  final List<UserSummary> podcastGuests;
  final VoidCallback? onGuests;

  /// D212: «جدولة» chosen instead of «الآن» (the start button schedules).
  final bool schedule;
  final ValueChanged<bool>? onSchedule;

  bool get _podcast => mode == LiveRoomMode.podcast;

  static Key topicKey(PodcastTopic t) => Key('goLive.podcast.topic.${t.name}');
  static const questionsKey = Key('goLive.podcast.questions');

  /// D363: the podcast's «صوت / فيديو» chips.
  static const audioFormatKey = Key('goLive.podcast.format.audio');
  static const videoFormatKey = Key('goLive.podcast.format.video');

  /// D363 scope extension: a video podcast's segments editor.
  static const segmentsKey = Key('goLive.podcast.segments');
  static const guestsPickKey = Key('goLive.podcast.guests');
  static const nowKey = Key('goLive.podcast.now');
  static const scheduleKey = Key('goLive.podcast.schedule');
  static const podcastPanelKey = Key('goLive.podcast.panel');

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

  /// A mode tab: switch to another mode (LIVE, podcast, …).
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

  /// D363 (§10.157): the camera preview behind a video podcast's setup (null:
  /// the room's theme, as for audio rooms and audio podcasts).
  final Widget? preview;

  /// D363: over the camera, the podcast settings sit on Kabso's frosted
  /// glass (the camera blurred behind them); over a theme, as before.
  Widget _framed(Widget panel) => preview == null
      ? panel
      : Padding(
          padding: const EdgeInsets.fromLTRB(14.9, 14, 14.9, 8),
          child: LiveGlass(radius: 14, child: panel),
        );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // The reference darkens the room's look at the top and the bottom.
    final background = Stack(
      fit: StackFit.expand,
      children: [
        // D363: a video podcast's setup shows the camera.
        if (preview case final camera?) ...[
          camera,
          // The camera stays visible but dimmed, so the settings read.
          const ColoredBox(color: Color(0x730A0820)),
        ] else if (theme == LiveThemes.classic)
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
                  // D212: a podcast has a topic, not a category.
                  categories: _podcast ? const [] : categories,
                  category: category,
                  onCategory: onCategory,
                ),
              ),
              if (_podcast)
                Expanded(
                  child: _framed(
                    SingleChildScrollView(
                      padding: preview == null
                          ? const EdgeInsets.fromLTRB(14.9, 14, 14.9, 8)
                          : const EdgeInsets.fromLTRB(12, 12, 12, 10),
                      child: _PodcastPanel(
                        key: podcastPanelKey,
                        setup: podcast,
                        config: podcastConfig,
                        onSetup: enabled ? onPodcast : null,
                        guests: podcastGuests,
                        onGuests: enabled ? onGuests : null,
                        schedule: schedule,
                        onSchedule: enabled ? onSchedule : null,
                      ),
                    ),
                  ),
                )
              else ...[
                const SizedBox(height: _seatsGap),
                _SeatsPreview(count: seatCount),
                const Spacer(),
              ],
              _Tools(
                children: [
                  if (!_podcast)
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
                  label: busy
                      ? l10n.goLiveStarting
                      : _podcast && schedule
                      ? l10n.podcastSetupScheduleAction
                      : l10n.goLiveStart,
                  busy: busy,
                  onPressed: onStart,
                ),
              ),
              const SizedBox(height: 29.1),
              _ModeTabs(selected: mode, onSelect: onMode),
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

/// LIVE · Audio LIVE · Podcast (ref 65; D369: no multi-guest mode): the
/// chosen mode centred, larger, with a dot under it; the others run off the
/// start edge.
class _ModeTabs extends StatelessWidget {
  const new({required this.selected, required this.onSelect});

  final LiveRoomMode selected;
  final ValueChanged<LiveRoomMode>? onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.textStyles;
    final modes = [
      (LiveRoomMode.solo, l10n.goLiveModeSolo),
      (LiveRoomMode.audio, l10n.goLiveModeAudio),
      // D212: the podcast (the streamer tab follows, «قريباً»; D213: a
      // mode on Android).
      (LiveRoomMode.podcast, l10n.goLiveModePodcast),
      if (streamerSupportHere() == StreamerSupport.supported)
        (LiveRoomMode.streamer, l10n.goLiveModeStreamer),
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

    // D224 (owner): the row scrolls sideways; the chosen one comes to the
    // middle (as the cut-off sides of D212 showed it).
    // The chosen label (18 sp, 1.2 lines) grows with the text size: the
    // row with it (34 pt at 1×), so a large text never overflows.
    final grow = MediaQuery.textScalerOf(context).scale(18) - 18;
    return GoLiveModeScroller(
      height: 34 + (grow * 1.2).ceilToDouble(),
      selected: at,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final m in modes) tab(m),
        if (streamerSupportHere() != StreamerSupport.supported)
          const GoLiveStreamerTab(fontSize: 15),
      ],
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
  VoidCallback? onWishList,
  int? wishCount,
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
            // D136: the host's wish list (up to 4 gifts).
            if (onWishList != null)
              LiveSettingsRow(
                key: LiveSettingsRow.wishKey,
                label: l10n.liveWishTitle,
                trailing: wishCount == null ? null : '$wishCount/4',
                onTap: () {
                  Navigator.of(sheet).pop();
                  onWishList();
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

  /// D136: the wish list row.
  static const wishKey = Key('liveSettings.wishList');
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

/// D212: the podcast's setup under the title card — the topic chips, the
/// guests (up to 3), questions open or closed with the question time, and
/// now or a scheduled episode (the CP-016 C schedule and its reminder).
class _PodcastPanel extends StatelessWidget {
  const new({
    required this.setup,
    required this.config,
    required this.onSetup,
    required this.guests,
    required this.onGuests,
    required this.schedule,
    required this.onSchedule,
    super.key,
  });

  final PodcastSetup setup;
  final LivePodcastConfig config;
  final ValueChanged<PodcastSetup>? onSetup;
  final List<UserSummary> guests;
  final VoidCallback? onGuests;
  final bool schedule;
  final ValueChanged<bool>? onSchedule;

  static const _white = Color(0xFFFFFFFF);
  static const _glass = Color(0x33000000);
  static const _on = Color(0xFFE50914);

  PodcastSetup _with({
    PodcastTopic? topic,
    bool? open,
    int? Function()? s,
    bool? video,
  }) => setup.copyWith(
    topic: topic,
    questionsOpen: open,
    questionSeconds: s,
    video: video,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.textStyles;
    final label = text.bodyStrong.copyWith(color: _white, fontSize: 14);
    Widget chip(
      String text0,
      VoidCallback? onTap, {
      required bool on,
      Key? key,
    }) => Semantics(
      button: true,
      selected: on,
      label: text0,
      excludeSemantics: true,
      child: GestureDetector(
        key: key,
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: KSizes.minTouchTarget),
          child: Center(
            widthFactor: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: on ? _on : _glass,
                borderRadius: BorderRadius.circular(KRadius.pill),
                border: Border.all(
                  color: on ? _on : _white.withValues(alpha: 0.35),
                ),
              ),
              child: Text(
                text0,
                style: text.label.copyWith(
                  color: _white,
                  fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final set = onSetup;
    final topics = config.topics.isEmpty ? PodcastTopic.values : config.topics;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // D363 (§10.157): «صوت / فيديو» — audio by default (D212's podcast).
        Row(
          children: [
            Expanded(child: Text(l10n.podcastFormat, style: label)),
            chip(
              l10n.podcastFormatAudio,
              set == null ? null : () => set(_with(video: false)),
              on: !setup.video,
              key: GoLiveAudioSetup.audioFormatKey,
            ),
            const SizedBox(width: 6),
            chip(
              l10n.podcastFormatVideo,
              set == null ? null : () => set(_with(video: true)),
              on: setup.video,
              key: GoLiveAudioSetup.videoFormatKey,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(l10n.podcastSetupTopic, style: label),
        Wrap(
          spacing: 8,
          children: [
            for (final t in topics)
              chip(
                podcastTopicLabel(l10n, t),
                set == null ? null : () => set(_with(topic: t)),
                on: t == setup.topic,
                key: GoLiveAudioSetup.topicKey(t),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: Text(l10n.podcastSetupGuests, style: label)),
            for (final g in guests)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 4),
                child: PodcastAvatar(
                  name: g.displayName,
                  url: g.avatarUrl,
                  size: 30,
                ),
              ),
            IconButton(
              key: GoLiveAudioSetup.guestsPickKey,
              tooltip: l10n.podcastSetupAddGuest,
              onPressed: onGuests,
              icon: const Icon(Icons.person_add_alt_1_rounded, color: _white),
            ),
          ],
        ),
        // D363 scope extension: a video podcast's segments «فقرات الحلقة».
        if (setup.video)
          Row(
            children: [
              Expanded(child: Text(l10n.podcastSegments, style: label)),
              if (setup.segments.isNotEmpty)
                Text(
                  l10n.podcastSegmentsCount(setup.segments.length),
                  style: label.copyWith(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              IconButton(
                key: GoLiveAudioSetup.segmentsKey,
                tooltip: l10n.podcastSegments,
                onPressed: set == null
                    ? null
                    : () async {
                        final segments = await showPodcastSegmentsSheet(
                          context,
                          segments: setup.segments,
                        );
                        if (segments != null) {
                          set(setup.copyWith(segments: segments));
                        }
                      },
                icon: const Icon(Icons.view_agenda_rounded, color: _white),
              ),
            ],
          ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(child: Text(l10n.podcastSetupQuestions, style: label)),
            chip(
              l10n.podcastSetupOpen,
              set == null ? null : () => set(_with(open: true)),
              on: setup.questionsOpen,
              key: GoLiveAudioSetup.questionsKey,
            ),
            const SizedBox(width: 6),
            chip(
              l10n.podcastSetupClosed,
              set == null ? null : () => set(_with(open: false)),
              on: !setup.questionsOpen,
            ),
          ],
        ),
        if (setup.questionsOpen) ...[
          Text(
            l10n.podcastQuestionTime,
            style: label.copyWith(fontSize: 12.5, fontWeight: FontWeight.w500),
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final sec in podcastQuestionChoices(config))
                chip(
                  podcastQuestionLabel(l10n, sec),
                  set == null ? null : () => set(_with(s: () => sec)),
                  on: sec == setup.questionSeconds,
                  key: PodcastHandsSheet.secondsKey(sec),
                ),
            ],
          ),
        ],
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(child: Text(l10n.podcastSetupWhen, style: label)),
            chip(
              l10n.podcastSetupNow,
              onSchedule == null ? null : () => onSchedule!(false),
              on: !schedule,
              key: GoLiveAudioSetup.nowKey,
            ),
            const SizedBox(width: 6),
            chip(
              l10n.podcastSetupSchedule,
              onSchedule == null ? null : () => onSchedule!(true),
              on: schedule,
              key: GoLiveAudioSetup.scheduleKey,
            ),
          ],
        ),
      ],
    );
  }
}
