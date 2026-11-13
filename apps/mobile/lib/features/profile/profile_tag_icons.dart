// D292 (owner, option 1: the person picks an icon for each profile tag;
// contract v1.91-social, CONVENTIONS §10.106): the closed set of tag icons
// (`ProfileTagIcon`), how the app draws each — its own icons, never emoji
// glyphs; a country's flag from the bundled flag art (`assets/flags/`,
// OFL) — their names for screen readers, and the picker sheet.

import 'package:kabso_live/core/countries/countries.dart';
import 'package:kabso_live/core/icons/app_icons.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/country_picker.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// The kinds of `ProfileTagIcon`, in the picker's order.
enum ProfileTagIconKind {
  none('default'),
  crown('crown'),
  flag('flag'),
  fire('fire'),
  trophy('trophy'),
  gamepad('gamepad'),
  music('music'),
  mic('mic'),
  moon('moon'),
  heart('heart'),
  star('star'),
  gem('gem'),
  camera('camera'),
  book('book'),
  sport('sport'),
  palette('palette'),
  globe('globe');

  new(this.wire);

  /// The key on the wire (`flag` alone is never sent: `flag:SA`).
  final String wire;
}

/// One tag's icon: a [kind] and, for a flag, its [country] (ISO 3166-1
/// alpha-2, upper case).
@immutable
class ProfileTagIcon {
  const new(this.kind, {this.country});

  /// [wire] as the server sends it; anything unknown (a newer server, a
  /// flag of a country this app does not list) is [none].
  factory parse(String? wire) {
    if (wire == null) return none;
    if (wire.startsWith('flag:')) {
      final code = wire.substring(5).toUpperCase();
      return KCountries.byCode(code) == null
          ? none
          : ProfileTagIcon(ProfileTagIconKind.flag, country: code);
    }
    for (final k in ProfileTagIconKind.values) {
      if (k != ProfileTagIconKind.flag && k.wire == wire) {
        return ProfileTagIcon(k);
      }
    }
    return none;
  }

  static const none = ProfileTagIcon(ProfileTagIconKind.none);

  final ProfileTagIconKind kind;
  final String? country;

  /// The icon of each of [tags] from `tagIcons` (one per tag; missing
  /// entries — an older server — are [none]).
  static List<ProfileTagIcon> listFor(List<String> tags, List<String> wires) =>
      [
        for (var i = 0; i < tags.length; i++)
          ProfileTagIcon.parse(i < wires.length ? wires[i] : null),
      ];

  /// The key to send (`PATCH /me` `tagIcons`).
  String get wire => kind == ProfileTagIconKind.flag && country != null
      ? 'flag:$country'
      : (kind == ProfileTagIconKind.flag ? 'default' : kind.wire);

  bool get isNone => kind == ProfileTagIconKind.none;

  /// The icon's name for screen readers and the picker.
  String label(AppLocalizations l10n, {required bool arabic}) => switch (kind) {
    ProfileTagIconKind.none => l10n.profileTagIconDefault,
    ProfileTagIconKind.crown => l10n.profileTagIconCrown,
    ProfileTagIconKind.flag => switch (KCountries.byCode(country)) {
      final c? => l10n.profileTagIconFlagOf(KCountries.name(c, arabic: arabic)),
      null => l10n.profileTagIconFlag,
    },
    ProfileTagIconKind.fire => l10n.profileTagIconFire,
    ProfileTagIconKind.trophy => l10n.profileTagIconTrophy,
    ProfileTagIconKind.gamepad => l10n.profileTagIconGamepad,
    ProfileTagIconKind.music => l10n.profileTagIconMusic,
    ProfileTagIconKind.mic => l10n.profileTagIconMic,
    ProfileTagIconKind.moon => l10n.profileTagIconMoon,
    ProfileTagIconKind.heart => l10n.profileTagIconHeart,
    ProfileTagIconKind.star => l10n.profileTagIconStar,
    ProfileTagIconKind.gem => l10n.profileTagIconGem,
    ProfileTagIconKind.camera => l10n.profileTagIconCamera,
    ProfileTagIconKind.book => l10n.profileTagIconBook,
    ProfileTagIconKind.sport => l10n.profileTagIconSport,
    ProfileTagIconKind.palette => l10n.profileTagIconPalette,
    ProfileTagIconKind.globe => l10n.profileTagIconGlobe,
  };

  @override
  bool operator ==(Object other) =>
      other is ProfileTagIcon && other.kind == kind && other.country == country;

  @override
  int get hashCode => Object.hash(kind, country);
}

/// Draws a [ProfileTagIcon] [size] dp square: a Material icon in its own
/// tint (the mock's gold / violet / warm accents, a deeper shade on light),
/// the app's crown, or a country's flag art. [ProfileTagIconKind.none]
/// draws [noneIcon] when given (the picker), else nothing.
class ProfileTagIconView extends StatelessWidget {
  const new({
    required this.icon,
    super.key,
    this.size = 16,
    this.noneIcon = false,
  });

  final ProfileTagIcon icon;
  final double size;
  final bool noneIcon;

  static const _gold = (Color(0xFFF5C451), Color(0xFFB7860B));
  static const _violet = (Color(0xFFB794FF), Color(0xFF7C3AED));
  static const _orange = (Color(0xFFFF8A3D), Color(0xFFD9480F));
  static const _red = (Color(0xFFFF5C6C), Color(0xFFE50914));
  static const _blue = (Color(0xFF6FB6FF), Color(0xFF1D6FD8));
  static const _teal = (Color(0xFF4FD1C5), Color(0xFF0F8A7E));
  static const _green = (Color(0xFF6BD48F), Color(0xFF1F8F4A));

  /// The Material icon and tint (dark, light) of each kind.
  static (IconData, (Color, Color))? _material(ProfileTagIconKind kind) =>
      switch (kind) {
        ProfileTagIconKind.fire => (
          Icons.local_fire_department_rounded,
          _orange,
        ),
        ProfileTagIconKind.trophy => (Icons.emoji_events_rounded, _gold),
        ProfileTagIconKind.gamepad => (Icons.sports_esports_rounded, _violet),
        ProfileTagIconKind.music => (Icons.music_note_rounded, _blue),
        ProfileTagIconKind.mic => (Icons.mic_rounded, _violet),
        ProfileTagIconKind.moon => (Icons.nightlight_round, _gold),
        ProfileTagIconKind.heart => (Icons.favorite_rounded, _red),
        ProfileTagIconKind.star => (Icons.star_rounded, _gold),
        ProfileTagIconKind.gem => (Icons.diamond_rounded, _violet),
        ProfileTagIconKind.camera => (Icons.photo_camera_rounded, _blue),
        ProfileTagIconKind.book => (Icons.menu_book_rounded, _teal),
        ProfileTagIconKind.sport => (Icons.sports_soccer_rounded, _green),
        ProfileTagIconKind.palette => (Icons.palette_rounded, _orange),
        ProfileTagIconKind.globe => (Icons.public_rounded, _teal),
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    Color tint((Color, Color) pair) => dark ? pair.$1 : pair.$2;
    final material = _material(icon.kind);
    if (material != null) {
      return Icon(material.$1, size: size, color: tint(material.$2));
    }
    return switch (icon.kind) {
      ProfileTagIconKind.crown => AppIcon(
        AppIcons.crownFilled,
        size: size,
        color: tint(_gold),
      ),
      ProfileTagIconKind.flag when icon.country != null => SizedBox(
        width: size,
        height: size,
        child: Image.asset(
          'assets/flags/${icon.country!.toLowerCase()}.webp',
          fit: BoxFit.contain,
          excludeFromSemantics: true,
          errorBuilder: (_, _, _) => Icon(
            Icons.flag_rounded,
            size: size,
            color: context.palette.textSecondary,
          ),
        ),
      ),
      ProfileTagIconKind.flag => Icon(
        Icons.flag_rounded,
        size: size,
        color: context.palette.textSecondary,
      ),
      _ =>
        noneIcon
            ? Icon(
                Icons.label_off_outlined,
                size: size,
                color: context.palette.textSecondary,
              )
            : SizedBox.square(dimension: size),
    };
  }
}

/// The icon picker «أيقونة الوسم»: a grid of every icon (the flag asks for
/// its country from the app's country list). Returns the chosen icon, or
/// null when dismissed.
Future<ProfileTagIcon?> showProfileTagIconPicker(
  BuildContext context, {
  required ProfileTagIcon current,
}) async {
  final picked = await showModalBottomSheet<ProfileTagIcon>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => ProfileTagIconPickerSheet(current: current),
  );
  if (picked == null || !context.mounted) return picked;
  if (picked.kind != ProfileTagIconKind.flag) return picked;
  String? country;
  await showLiveCountryPicker(
    context,
    selected: current.country,
    onChoose: (code) => country = code,
  );
  return country == null
      ? null
      : ProfileTagIcon(ProfileTagIconKind.flag, country: country);
}

/// The grid of [showProfileTagIconPicker] (public for tests).
class ProfileTagIconPickerSheet extends StatelessWidget {
  const new({required this.current, super.key});

  final ProfileTagIcon current;

  static const sheetKey = Key('profile.tagIcon.sheet');
  static Key optionKey(ProfileTagIconKind kind) =>
      Key('profile.tagIcon.${kind.wire}');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    return Padding(
      key: sheetKey,
      padding: const EdgeInsets.fromLTRB(
        KSpacing.lg,
        0,
        KSpacing.lg,
        KSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.profileTagIconPick,
            textAlign: TextAlign.center,
            style: t.title.copyWith(color: p.textPrimary),
          ),
          const SizedBox(height: KSpacing.md),
          Flexible(
            child: GridView.count(
              shrinkWrap: true,
              crossAxisCount: 4,
              mainAxisSpacing: KSpacing.sm,
              crossAxisSpacing: KSpacing.sm,
              childAspectRatio: 0.95,
              children: [
                for (final kind in ProfileTagIconKind.values)
                  _option(context, kind, arabic: arabic),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _option(
    BuildContext context,
    ProfileTagIconKind kind, {
    required bool arabic,
  }) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final icon = kind == ProfileTagIconKind.flag
        ? (current.kind == kind
              ? current
              : const ProfileTagIcon(ProfileTagIconKind.flag))
        : ProfileTagIcon(kind);
    final selected = current.kind == kind;
    final name = kind == ProfileTagIconKind.flag
        ? l10n.profileTagIconFlag
        : icon.label(l10n, arabic: arabic);
    return Semantics(
      button: true,
      selected: selected,
      label: name,
      excludeSemantics: true,
      child: InkWell(
        key: optionKey(kind),
        borderRadius: BorderRadius.circular(KRadius.md),
        onTap: () => Navigator.of(context).pop(icon),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(KRadius.md),
            border: Border.all(
              color: selected ? KBrandColors.red500 : p.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(KSpacing.xs),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ProfileTagIconView(icon: icon, size: 26, noneIcon: true),
                const SizedBox(height: KSpacing.xs),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    name,
                    maxLines: 1,
                    style: t.caption.copyWith(color: p.textSecondary),
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
