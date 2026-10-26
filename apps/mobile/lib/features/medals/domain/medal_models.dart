// Wire models of the medals API (docs/contracts/openapi.yaml v1.21-live
// DRAFT, tag `medals`, CP-018; CONVENTIONS §10.21).

import 'package:freezed_annotation/freezed_annotation.dart';

part 'medal_models.freezed.dart';
part 'medal_models.g.dart';

/// The most medals a profile shows (owner, D106 amendment).
const int maxShowcaseMedals = 6;

/// `Medal`: one medal of the catalogue with the caller's [awardedAt] (null
/// while locked). Name and description follow the app language.
@freezed
abstract class Medal with _$Medal {
  const factory({
    required String code,
    required String name,
    required String description,
    required String iconKey,
    required int sortOrder,
    required DateTime? awardedAt,
  }) = _Medal;

  const new _();

  factory fromJson(Map<String, dynamic> json) => _$MedalFromJson(json);

  bool get unlocked => awardedAt != null;
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

/// `ProfileMedal`: a medal as a profile shows it.
@freezed
abstract class ProfileMedal with _$ProfileMedal {
  const factory({
    required String code,
    required String name,
    required String iconKey,
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
