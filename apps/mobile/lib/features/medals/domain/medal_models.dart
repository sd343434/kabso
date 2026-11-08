// Wire models of the medals API (docs/contracts/openapi.yaml v1.21-live
// DRAFT, tag `medals`, CP-018; CONVENTIONS §10.21; levels and tabs
// v1.81-live, D291, §10.104; multi-requirement medals v1.83-live, D300,
// §10.111).

import 'package:freezed_annotation/freezed_annotation.dart';

part 'medal_models.freezed.dart';
part 'medal_models.g.dart';

/// The most medals a profile shows: 5 (owner D269 «حدها ٥»; 3 in D258,
/// 6 before).
const int maxShowcaseMedals = 5;

/// `MedalCategory` (v1.81-live, D291): the medals page's tabs; an unknown
/// value is [achievement].
enum MedalCategory {
  @JsonValue('ACHIEVEMENT')
  achievement,
  @JsonValue('ACTIVITY')
  activity,
}

/// D300 (§10.111): the requirement metrics of a multi-requirement medal
/// («مدرسة المحتوى»), in the order the app shows them.
const List<String> medalRequirementMetrics = [
  'CREATOR_FOLLOWERS',
  'CREATOR_LIKES',
  'CREATOR_VIEWS',
];

/// `MedalLevelRequirement` (v1.83-live, D300): one threshold of a
/// multi-requirement level — all of a level's requirements together reach
/// it.
@freezed
abstract class MedalLevelRequirement with _$MedalLevelRequirement {
  const factory({required String metric, required int threshold}) =
      _MedalLevelRequirement;

  factory fromJson(Map<String, dynamic> json) =>
      _$MedalLevelRequirementFromJson(json);
}

/// `MedalRequirementProgress` (v1.83-live, D300): the caller's value of one
/// requirement now and the next level's threshold of it (null at the top).
@freezed
abstract class MedalRequirementProgress with _$MedalRequirementProgress {
  const factory({required String metric, @Default(0) int value, int? next}) =
      _MedalRequirementProgress;

  factory fromJson(Map<String, dynamic> json) =>
      _$MedalRequirementProgressFromJson(json);
}

/// `MedalLevel` (v1.81-live, D291): reached when the medal's metric is at
/// least [threshold]. [name] and [iconUrl] are this level's own, or null
/// (the medal's name and art with the numeral).
@freezed
abstract class MedalLevel with _$MedalLevel {
  const factory({
    required int level,
    required int threshold,
    String? name,
    String? iconUrl,

    /// D291: this level's art bundled in the app (e.g. `medal_wealth_l1`).
    String? iconAsset,

    /// D300: a multi-requirement level's thresholds (empty otherwise).
    @Default(<MedalLevelRequirement>[])
    List<MedalLevelRequirement> requirements,
  }) = _MedalLevel;

  factory fromJson(Map<String, dynamic> json) => _$MedalLevelFromJson(json);
}

/// `MedalProgress` (v1.81-live, D291): the caller's metric now and the next
/// level's threshold (null at the top level).
@freezed
abstract class MedalProgress with _$MedalProgress {
  const factory({
    @Default(0) int value,
    int? next,

    /// D300: each requirement now against the next level's target (empty
    /// for a single-metric medal).
    @Default(<MedalRequirementProgress>[])
    List<MedalRequirementProgress> requirements,
  }) = _MedalProgress;

  factory fromJson(Map<String, dynamic> json) => _$MedalProgressFromJson(json);
}

/// `Medal`: one medal of the catalogue with the caller's [awardedAt] (null
/// while locked). Name and description follow the app language.
///
/// v1.81-live (D291): its tab, the caller's [level] (0 = not earned; an
/// older server sends none: 1 when earned), every level, the progress and
/// the worn position.
@freezed
abstract class Medal with _$Medal {
  const factory({
    required String code,
    required String name,
    required String description,
    required String iconKey,
    required int sortOrder,
    required DateTime? awardedAt,
    @JsonKey(unknownEnumValue: MedalCategory.achievement)
    @Default(MedalCategory.achievement)
    MedalCategory category,

    /// What the levels count (`MedalMetric`: LIVES_HOSTED, LIVE_HOURS,
    /// CHARM_LEVEL, FAMILY_JOINED, CP_FORMED, BULLETS_SENT); null = none or
    /// unknown — the thresholds are then shown as bare numbers.
    String? metric,
    int? level,
    @Default(1) int maxLevel,
    @Default(<MedalLevel>[]) List<MedalLevel> levels,
    @Default(MedalProgress()) MedalProgress progress,
    String? iconUrl,

    /// D291: the bundled art key of the level shown, or null.
    String? iconAsset,
    int? showcasePosition,

    /// D300: false when the medal is for content creators and the caller is
    /// not one now (no progress; a level reached is kept). Older servers:
    /// true.
    @Default(true) bool eligible,
  }) = _Medal;

  const new _();

  factory fromJson(Map<String, dynamic> json) => _$MedalFromJson(json);

  bool get unlocked => awardedAt != null;

  /// The caller's level (0 = not earned).
  int get currentLevel => unlocked ? (level ?? 1).clamp(1, 99) : 0;

  /// Worn (in the showcase).
  bool get worn => showcasePosition != null;

  /// The level shown on the art: the caller's, else 1.
  int get shownLevel => currentLevel == 0 ? 1 : currentLevel;

  /// The shown level's own name, else the medal's.
  String get shownName =>
      levels.where((l) => l.level == shownLevel).firstOrNull?.name ?? name;

  /// The shown level's bundled art key, else [iconAsset].
  String? get shownIconAsset =>
      levels.where((l) => l.level == shownLevel).firstOrNull?.iconAsset ??
      iconAsset;

  /// The shown level's own art, else [iconUrl].
  String? get shownIconUrl =>
      levels.where((l) => l.level == shownLevel).firstOrNull?.iconUrl ??
      iconUrl;
}

/// `MedalCatalogue` (`GET /medals`): every medal in catalogue order.
@freezed
abstract class MedalCatalogue with _$MedalCatalogue {
  const factory({
    required List<Medal> data,
    required int total,
    required int owned,
  }) = _MedalCatalogue;

  factory fromJson(Map<String, dynamic> json) => _$MedalCatalogueFromJson(json);
}

/// `UserMedal`: a medal a user earned.
@freezed
abstract class UserMedal with _$UserMedal {
  const factory({
    required String code,
    required String name,
    required String description,
    required String iconKey,
    required DateTime awardedAt,
    @JsonKey(unknownEnumValue: MedalCategory.achievement)
    @Default(MedalCategory.achievement)
    MedalCategory category,

    /// v1.81-live (D291): the user's level (older servers: 1).
    @Default(1) int level,
    @Default(1) int maxLevel,
    String? iconUrl,
    String? iconAsset,
  }) = _UserMedal;

  factory fromJson(Map<String, dynamic> json) => _$UserMedalFromJson(json);
}

/// `UserMedalList` (`GET /users/{username}/medals`, newest first).
@freezed
abstract class UserMedalList with _$UserMedalList {
  const factory({
    required List<UserMedal> data,
    required int owned,
    required int total,
  }) = _UserMedalList;

  factory fromJson(Map<String, dynamic> json) => _$UserMedalListFromJson(json);
}

/// `ProfileMedal`: a medal as a profile shows it; v1.81-live (D291) with
/// the holder's [level] (older servers: 1) drawn as a numeral on the art.
@freezed
abstract class ProfileMedal with _$ProfileMedal {
  const factory({
    required String code,
    required String name,
    required String iconKey,
    @Default(1) int level,
    String? iconUrl,
    String? iconAsset,
  }) = _ProfileMedal;

  factory fromJson(Map<String, dynamic> json) => _$ProfileMedalFromJson(json);
}

/// `ProfileMedals`: owned and total, the newest three and the chosen
/// [showcase] (empty until the user chooses; never filled automatically).
@freezed
abstract class ProfileMedals with _$ProfileMedals {
  const factory({
    @Default(0) int owned,
    @Default(0) int total,
    @Default(<ProfileMedal>[]) List<ProfileMedal> latest,
    @Default(<ProfileMedal>[]) List<ProfileMedal> showcase,
  }) = _ProfileMedals;

  factory fromJson(Map<String, dynamic> json) => _$ProfileMedalsFromJson(json);
}
