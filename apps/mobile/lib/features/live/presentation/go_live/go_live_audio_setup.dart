import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/presentation/go_live/go_live_parts.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_room_style.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_theme_art.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Audio go-live (owner D94, laid out after their audio reference): the
/// top bar (the mode pill and ✕), the headline, the room's look, the title
/// with its counter, the categories, who can watch, the seats, the voice
/// settings and the glowing start button, on calm navy. Every control
/// works; what needs a contract (a room photo, tags, followers-only or
/// invitation-only rooms, hearing yourself) is not shown.
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
    required this.onModes,
    super.key,
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

  /// The mode pill: switch to multi-guest or LIVE.
  final VoidCallback? onModes;

  static const watchEveryoneKey = Key('goLive.audio.everyone');
  static const watchSignedInKey = Key('goLive.audio.signedIn');
  static const noiseKey = Key('goLive.audio.noise');
  static const enhanceKey = Key('goLive.audio.enhance');
  static const micKey = Key('goLive.audio.mic');
  static const themeKey = Key('goLive.audio.theme');
  static const modesKey = Key('goLive.audio.modes');
  static const allCategoriesKey = Key('goLive.audio.allCategories');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.textStyles;
    return Column(
      children: [
        // Top bar: the mode pill at the start, ✕ at the end.
        Padding(
          padding: const EdgeInsets.fromLTRB(
            KSpacing.lg,
            KSpacing.sm,
            KSpacing.sm,
            0,
          ),
          child: Row(
            children: [
              _ModePill(label: l10n.goLiveModeAudio, onTap: onModes),
              const Spacer(),
              IconButton(
                key: const Key('goLive.close'),
                tooltip: l10n.liveClose,
                onPressed: onClose,
                icon: const Icon(
                  Icons.close_rounded,
                  color: KLiveStyle.text,
                  size: 30,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              KSpacing.lg,
              KSpacing.md,
              KSpacing.lg,
              KSpacing.xl,
            ),
            children: [
              Semantics(
                header: true,
                child: Text(
                  l10n.goLiveAudioHeadline,
                  style: text.headline.copyWith(
                    color: KLiveStyle.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: KSpacing.xs),
              Text(
                l10n.goLiveAudioSubtitle,
                style: text.body.copyWith(color: KLiveStyle.textSecondary),
              ),
              const SizedBox(height: KSpacing.xl),
              _RoomLook(theme: theme, onTap: onTheme),
              const SizedBox(height: KSpacing.md),
              _TitleField(
                controller: controller,
                focusNode: focusNode,
                enabled: enabled,
              ),
              if (categories.isNotEmpty) ...[
                LiveSectionTitle(
                  l10n.goLiveChooseCategory,
                  action: l10n.goLiveAllCategories,
                  onAction: () => _showAll(context),
                ),
                SizedBox(
                  height: 84,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final c in [null, ...categories])
                        Padding(
                          padding: const EdgeInsetsDirectional.only(
                            end: KSpacing.sm,
                          ),
                          child: _CategoryTile(
                            slug: c?.slug,
                            label: c?.name ?? l10n.goLiveNoCategory,
                            icon: c == null
                                ? Icons.all_inclusive_rounded
                                : categoryIcon(c.slug),
                            selected: category == c?.slug,
                            onTap: enabled ? () => onCategory(c?.slug) : null,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              LiveSectionTitle(l10n.goLiveWhoCanWatch),
              Row(
                children: [
                  Expanded(
                    child: _Choice(
                      key: watchEveryoneKey,
                      icon: Icons.public_rounded,
                      title: l10n.goLiveWatchEveryone,
                      hint: l10n.goLiveWatchEveryoneHint,
                      selected: allowGuests,
                      onTap: onAllowGuests == null
                          ? null
                          : () => onAllowGuests!(true),
                    ),
                  ),
                  const SizedBox(width: KSpacing.sm),
                  Expanded(
                    child: _Choice(
                      key: watchSignedInKey,
                      icon: Icons.group_outlined,
                      title: l10n.goLiveWatchSignedIn,
                      hint: l10n.goLiveWatchSignedInHint,
                      selected: !allowGuests,
                      onTap: onAllowGuests == null
                          ? null
                          : () => onAllowGuests!(false),
                    ),
                  ),
                ],
              ),
              LiveSectionTitle(l10n.goLiveSeatsSection),
              Row(
                children: [
                  for (final c in seatCounts)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: KSpacing.xs,
                        ),
                        child: Semantics(
                          button: true,
                          selected: c == seatCount,
                          label: l10n.goLiveSeatCount(c),
                          excludeSemantics: true,
                          child: GestureDetector(
                            key: GoLiveKeys.seatCount(c),
                            onTap: onSeatCount == null
                                ? null
                                : () => onSeatCount!(c),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              height: 52,
                              decoration: KLiveStyle.cardDecoration(
                                selected: c == seatCount,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.weekend_outlined,
                                    size: 20,
                                    color: c == seatCount
                                        ? KLiveStyle.accent
                                        : KLiveStyle.text,
                                  ),
                                  const SizedBox(width: KSpacing.xs + 2),
                                  Text(
                                    KFormatSeat.of(c),
                                    style: text.bodyStrong.copyWith(
                                      color: c == seatCount
                                          ? KLiveStyle.accent
                                          : KLiveStyle.text,
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
              ),
              LiveSectionTitle(l10n.goLiveVoiceSettings),
              Container(
                decoration: KLiveStyle.cardDecoration(),
                child: Column(
                  children: [
                    _SwitchRow(
                      key: micKey,
                      icon: micEnabled
                          ? Icons.mic_none_rounded
                          : Icons.mic_off_rounded,
                      title: l10n.goLiveMicrophone,
                      hint: l10n.goLiveMicrophoneHint,
                      value: micEnabled,
                      onChanged: onMic == null ? null : (_) => onMic!(),
                    ),
                    const Divider(height: 1, color: KLiveStyle.edge),
                    _SwitchRow(
                      key: noiseKey,
                      icon: Icons.graphic_eq_rounded,
                      title: l10n.goLiveNoiseReduction,
                      hint: l10n.goLiveNoiseReductionHint,
                      value: noiseReduction,
                      onChanged: onVoice == null
                          ? null
                          : (v) => onVoice!(noiseReduction: v),
                    ),
                    const Divider(height: 1, color: KLiveStyle.edge),
                    _SwitchRow(
                      key: enhanceKey,
                      icon: Icons.hearing_rounded,
                      title: l10n.goLiveVoiceEnhance,
                      hint: l10n.goLiveVoiceEnhanceHint,
                      value: enhance,
                      onChanged: onVoice == null
                          ? null
                          : (v) => onVoice!(enhance: v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: KSpacing.xl),
              LiveGlowButton(
                label: busy ? l10n.goLiveStarting : l10n.goLiveStartAudio,
                busy: busy,
                onPressed: onStart,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showAll(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    backgroundColor: KLiveStyle.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(KRadius.xl)),
    ),
    builder: (sheet) => SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(KSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              sheet.l10n.goLiveChooseCategory,
              style: sheet.textStyles.title.copyWith(color: KLiveStyle.text),
            ),
            const SizedBox(height: KSpacing.lg),
            Wrap(
              spacing: KSpacing.sm,
              runSpacing: KSpacing.sm,
              children: [
                for (final c in [null, ...categories])
                  _CategoryTile(
                    slug: c?.slug,
                    label: c?.name ?? sheet.l10n.goLiveNoCategory,
                    icon: c == null
                        ? Icons.all_inclusive_rounded
                        : categoryIcon(c.slug),
                    selected: category == c?.slug,
                    onTap: enabled
                        ? () {
                            onCategory(c?.slug);
                            Navigator.of(sheet).pop();
                          }
                        : null,
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
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

class _ModePill extends StatelessWidget {
  const new({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: GestureDetector(
      key: GoLiveAudioSetup.modesKey,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: KSpacing.lg,
          vertical: KSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF0E2A44),
          borderRadius: BorderRadius.circular(KRadius.pill),
          border: Border.all(color: KLiveStyle.accent.withValues(alpha: 0.7)),
          boxShadow: [
            BoxShadow(
              color: KLiveStyle.accent.withValues(alpha: 0.3),
              blurRadius: 12,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.graphic_eq_rounded,
              color: KLiveStyle.accent,
              size: 20,
            ),
            const SizedBox(width: KSpacing.sm),
            Text(
              label,
              style: context.textStyles.bodyStrong.copyWith(
                color: KLiveStyle.accent,
              ),
            ),
            const SizedBox(width: KSpacing.xs),
            const Icon(
              Icons.expand_more_rounded,
              color: KLiveStyle.accent,
              size: 18,
            ),
          ],
        ),
      ),
    ),
  );
}

/// The room's look: the theme as a wide card with a microphone in the
/// middle and the change button (the reference's room-photo card; a photo
/// needs a contract).
class _RoomLook extends StatelessWidget {
  const new({required this.theme, required this.onTap});

  final String theme;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Semantics(
      button: true,
      label: l10n.goLiveChangeTheme,
      excludeSemantics: true,
      child: GestureDetector(
        key: GoLiveAudioSetup.themeKey,
        onTap: onTap,
        child: Container(
          height: 112,
          decoration: KLiveStyle.cardDecoration(),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(KRadius.lg - 1),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (theme == LiveThemes.classic)
                  const LiveNavyBackground()
                else
                  Opacity(
                    opacity: 0.55,
                    child: LiveThemeBackground(theme: theme),
                  ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.mic_none_rounded,
                        color: KLiveStyle.text,
                        size: 30,
                      ),
                      const SizedBox(height: KSpacing.xs),
                      Text(
                        l10n.goLiveRoomLook(LiveThemeArt.of(theme).name(l10n)),
                        style: context.textStyles.label.copyWith(
                          color: KLiveStyle.text,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                PositionedDirectional(
                  end: KSpacing.md,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: KLiveStyle.cardRaised,
                        border: Border.all(color: KLiveStyle.edge),
                      ),
                      child: const Icon(
                        Icons.palette_outlined,
                        color: KLiveStyle.text,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TitleField extends StatelessWidget {
  const new({
    required this.controller,
    required this.focusNode,
    required this.enabled,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final text = context.textStyles;
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
      decoration: KLiveStyle.cardDecoration(),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: GoLiveKeys.title,
              controller: controller,
              focusNode: focusNode,
              enabled: enabled,
              maxLength: GoLiveTitleCard.titleMaxLength,
              style: text.body.copyWith(color: KLiveStyle.text),
              cursorColor: KLiveStyle.accent,
              decoration: InputDecoration(
                isCollapsed: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                counterText: '',
                hintText: context.l10n.goLiveTitleHint,
                hintStyle: text.body.copyWith(color: KLiveStyle.textSecondary),
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) => Text(
              _counter(value.text.characters.length),
              textDirection: TextDirection.ltr,
              style: text.caption.copyWith(color: KLiveStyle.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// `12/80`.
String _counter(int length) => '$length/${GoLiveTitleCard.titleMaxLength}';

class _CategoryTile extends StatelessWidget {
  const new({
    required this.slug,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String? slug;
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: label,
    excludeSemantics: true,
    child: GestureDetector(
      key: GoLiveKeys.category(slug),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 80,
        height: 80,
        decoration: KLiveStyle.cardDecoration(selected: selected),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 26,
              color: selected ? KLiveStyle.accent : KLiveStyle.text,
            ),
            const SizedBox(height: KSpacing.xs + 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: KSpacing.xs),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textStyles.caption.copyWith(
                  color: selected ? KLiveStyle.accent : KLiveStyle.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Choice extends StatelessWidget {
  const new({
    required this.icon,
    required this.title,
    required this.hint,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String hint;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: title,
    hint: hint,
    excludeSemantics: true,
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(
          horizontal: KSpacing.sm,
          vertical: KSpacing.md,
        ),
        decoration: KLiveStyle.cardDecoration(selected: selected),
        child: Column(
          children: [
            Icon(
              icon,
              size: 26,
              color: selected ? KLiveStyle.accent : KLiveStyle.text,
            ),
            const SizedBox(height: KSpacing.xs + 2),
            Text(
              title,
              textAlign: TextAlign.center,
              style: context.textStyles.bodyStrong.copyWith(
                color: KLiveStyle.text,
              ),
            ),
            const SizedBox(height: KSpacing.xxs),
            Text(
              hint,
              textAlign: TextAlign.center,
              style: context.textStyles.caption.copyWith(
                color: KLiveStyle.textSecondary,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SwitchRow extends StatelessWidget {
  const new({
    required this.icon,
    required this.title,
    required this.hint,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final IconData icon;
  final String title;
  final String hint;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  // Its own transparent Material: the navy card would hide the ink.
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: SwitchListTile.adaptive(
      contentPadding: const EdgeInsets.symmetric(horizontal: KSpacing.md),
      value: value,
      onChanged: onChanged,
      activeTrackColor: KLiveStyle.accent,
      secondary: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: KLiveStyle.cardRaised,
          border: Border.all(color: KLiveStyle.edge),
        ),
        child: Icon(icon, color: KLiveStyle.accent, size: 22),
      ),
      title: Text(
        title,
        style: context.textStyles.bodyStrong.copyWith(color: KLiveStyle.text),
      ),
      subtitle: Text(
        hint,
        style: context.textStyles.caption.copyWith(
          color: KLiveStyle.textSecondary,
        ),
      ),
    ),
  );
}
