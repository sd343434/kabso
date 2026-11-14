import 'package:kabso_live/core/icons/app_icons.dart';
import 'package:kabso_live/core/models/profile_fields.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/profile/application/profile_grid_provider.dart';
import 'package:kabso_live/features/profile/domain/profile_models.dart';
import 'package:kabso_live/features/profile/profile_fields_view.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D386 (owner 2026-11-12: «أن يكون كل شخص تفاصيل صفحته حسب فئة الحساب»;
/// «الموثقة»; CONVENTIONS §10.175): the look of a profile page whose
/// category the Kabso Team verified — the family's accent
/// ([KCategoryAccents]), the category's icon (the app's icon set; the
/// missing ones drawn for Kabso in the set's style) and a background
/// pattern drawn in code. An unverified category, none, or a Kabso Team
/// account keeps the default look.

/// The background motif of a category, drawn by `CategoryPatternPainter`.
enum CategoryPattern {
  /// SINGER, MUSICIAN, DJ.
  notes,

  /// POET, CALLIGRAPHER, QURAN_RECITER, STORYTELLER: calligraphic flourishes.
  flourish,

  /// JOURNALIST, WRITER, BLOGGER: newspaper columns.
  lines,

  /// ARTIST, PHOTOGRAPHER, DESIGNER: picture frames.
  frames,

  /// CONTENT_CREATOR, ACTOR, COMEDIAN, PRESENTER: spotlights.
  sparkles,

  /// ATHLETE, GAMER.
  chevrons,

  /// CHEF, TRAVELER, TEACHER.
  waves,

  /// PUBLIC_FIGURE, OTHER.
  none;

  static CategoryPattern of(AccountCategory c) => switch (c) {
    AccountCategory.singer ||
    AccountCategory.musician ||
    AccountCategory.dj => notes,
    AccountCategory.poet ||
    AccountCategory.calligrapher ||
    AccountCategory.quranReciter ||
    AccountCategory.storyteller => flourish,
    AccountCategory.journalist ||
    AccountCategory.writer ||
    AccountCategory.blogger => lines,
    AccountCategory.artist ||
    AccountCategory.photographer ||
    AccountCategory.designer => frames,
    AccountCategory.contentCreator ||
    AccountCategory.actor ||
    AccountCategory.comedian ||
    AccountCategory.presenter => sparkles,
    AccountCategory.athlete || AccountCategory.gamer => chevrons,
    AccountCategory.chef ||
    AccountCategory.traveler ||
    AccountCategory.teacher => waves,
    AccountCategory.publicFigure || AccountCategory.other => none,
  };
}

/// The icon of each category (24-unit SVGs, `currentColor`).
String categoryIcon(AccountCategory c) => switch (c) {
  AccountCategory.singer => AppIcons.mic,
  AccountCategory.musician => AppIcons.musicNote,
  AccountCategory.dj => AppIcons.headphones,
  AccountCategory.quranReciter => AppIcons.book,
  AccountCategory.storyteller => AppIcons.book,
  AccountCategory.poet => AppIcons.pen,
  AccountCategory.writer => AppIcons.pen,
  AccountCategory.blogger => AppIcons.pen,
  AccountCategory.journalist => AppIcons.newspaper,
  AccountCategory.artist => AppIcons.palette,
  AccountCategory.photographer => AppIcons.camera,
  AccountCategory.designer => AppIcons.palette,
  AccountCategory.calligrapher => AppIcons.brush,
  AccountCategory.contentCreator => AppIcons.video,
  AccountCategory.actor => AppIcons.mask,
  AccountCategory.comedian => AppIcons.mask,
  AccountCategory.presenter => AppIcons.podcast,
  AccountCategory.athlete => AppIcons.trophy,
  AccountCategory.gamer => AppIcons.gamepad,
  AccountCategory.chef => AppIcons.chefHat,
  AccountCategory.traveler => AppIcons.compass,
  AccountCategory.teacher => AppIcons.graduation,
  AccountCategory.publicFigure => AppIcons.star,
  AccountCategory.other => AppIcons.star,
};

/// The accent of [family] in the current brightness.
Color categoryAccent(BuildContext context, CategoryFamily family) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  final a = dark ? KCategoryAccents.dark : KCategoryAccents.light;
  return switch (family) {
    CategoryFamily.music => a.music,
    CategoryFamily.reciter => a.reciter,
    CategoryFamily.word => a.word,
    CategoryFamily.visual => a.visual,
    CategoryFamily.performer => a.performer,
    CategoryFamily.sportsGames => a.sportsGames,
    CategoryFamily.lifestyle => a.lifestyle,
    CategoryFamily.public => a.public,
  };
}

String categoryFamilyLabel(AppLocalizations l10n, CategoryFamily f) =>
    switch (f) {
      CategoryFamily.music => l10n.categoryFamilyMusic,
      CategoryFamily.reciter => l10n.categoryFamilyReciter,
      CategoryFamily.word => l10n.categoryFamilyWord,
      CategoryFamily.visual => l10n.categoryFamilyVisual,
      CategoryFamily.performer => l10n.categoryFamilyPerformer,
      CategoryFamily.sportsGames => l10n.categoryFamilySportsGames,
      CategoryFamily.lifestyle => l10n.categoryFamilyLifestyle,
      CategoryFamily.public => l10n.categoryFamilyPublic,
    };

String featuredSectionTitle(AppLocalizations l10n, FeaturedSection s) =>
    switch (s) {
      FeaturedSection.works => l10n.featuredWorks,
      FeaturedSection.recitations => l10n.featuredRecitations,
      FeaturedSection.stories => l10n.featuredStories,
      FeaturedSection.poems => l10n.featuredPoems,
      FeaturedSection.articles => l10n.featuredArticles,
      FeaturedSection.reports => l10n.featuredReports,
      FeaturedSection.program => l10n.featuredProgram,
      FeaturedSection.games => l10n.featuredGames,
      FeaturedSection.achievements => l10n.featuredAchievements,
      FeaturedSection.gallery => l10n.featuredGallery,
      FeaturedSection.mostViewed => l10n.featuredMostViewed,
      FeaturedSection.highlights => l10n.featuredHighlights,
    };

/// The verified category's look of one profile page.
@immutable
class CategoryLook {
  const new({
    required this.category,
    required this.accent,
    required this.onAccent,
  });

  /// The look of [category] in [context]'s brightness.
  factory forCategory(BuildContext context, AccountCategory category) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return CategoryLook(
      category: category,
      accent: categoryAccent(context, category.family),
      onAccent: dark ? KCategoryAccents.onDark : KCategoryAccents.onLight,
    );
  }

  final AccountCategory category;
  final Color accent;
  final Color onAccent;

  CategoryFamily get family => category.family;
  CategoryPattern get pattern => CategoryPattern.of(category);
  String get icon => categoryIcon(category);

  /// The page's featured section, or null (PUBLIC_FIGURE, OTHER).
  FeaturedSection? get section => FeaturedSection.of(category);

  /// The primary buttons' gradient (start → end), like the Kabso-red one.
  List<Color> get gradient => [
    Color.lerp(accent, const Color(0xFFFFFFFF), 0.18)!,
    accent,
    Color.lerp(accent, const Color(0xFF000000), 0.22)!,
  ];

  /// The tab order (D386 §3): only the tabs that exist, moved — reels
  /// first for music, recitation and performance; posts first otherwise.
  List<ProfileTab> orderTabs(List<ProfileTab> tabs) {
    final reelsFirst = switch (family) {
      CategoryFamily.music ||
      CategoryFamily.reciter ||
      CategoryFamily.performer => true,
      _ => false,
    };
    if (!reelsFirst || !tabs.contains(ProfileTab.reels)) return tabs;
    return [ProfileTab.reels, ...tabs.where((t) => t != ProfileTab.reels)];
  }

  /// The look of [profile], or null: the default look unless the Kabso
  /// Team verified its category (and it is not a Kabso Team account, D367).
  static CategoryLook? ofProfile(BuildContext context, PublicProfile profile) {
    final category = profile.category;
    if (category == null || !profile.categoryVerified) return null;
    if (profileHidesCategory(
      kabsoTeam: profile.kabsoTeam,
      hasStaffIdentity: profile.staff != null,
      hasStaffId: profile.staffId != null,
      kabsoOwner: profile.kabsoOwner,
    )) {
      return null;
    }
    return CategoryLook.forCategory(context, category);
  }

  @override
  bool operator ==(Object other) =>
      other is CategoryLook &&
      other.category == category &&
      other.accent == accent &&
      other.onAccent == onAccent;

  @override
  int get hashCode => Object.hash(category, accent, onAccent);
}

/// Carries a page's [CategoryLook] to its header, buttons and sections.
class CategoryLookScope extends InheritedWidget {
  const new({required this.look, required super.child, super.key});

  final CategoryLook? look;

  static CategoryLook? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CategoryLookScope>()?.look;

  @override
  bool updateShouldNotify(CategoryLookScope oldWidget) =>
      oldWidget.look != look;
}
