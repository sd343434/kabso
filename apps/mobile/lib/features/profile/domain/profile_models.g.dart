// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PublicProfile _$PublicProfileFromJson(Map<String, dynamic> json) =>
    _PublicProfile(
      id: json['id'] as String,
      username: json['username'] as String,
      displayName: json['displayName'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      bio: json['bio'] as String?,
      isPrivate: json['isPrivate'] as bool,
      followerCount: (json['followerCount'] as num).toInt(),
      followingCount: (json['followingCount'] as num).toInt(),
      isFollowing: json['isFollowing'] as bool,
      isSelf: json['isSelf'] as bool,
      liveRoomId: json['liveRoomId'] as String?,
      isMuted: json['isMuted'] as bool? ?? false,
      premiumTier: premiumTierFromJson(json['premiumTier']),
      family: json['family'] == null
          ? null
          : ProfileFamily.fromJson(json['family'] as Map<String, dynamic>),
      cp: json['cp'] == null
          ? null
          : ProfileCp.fromJson(json['cp'] as Map<String, dynamic>),
      medals: json['medals'] == null
          ? const ProfileMedals()
          : ProfileMedals.fromJson(json['medals'] as Map<String, dynamic>),
      profileCard: json['profileCard'] == null
          ? null
          : ProfileCard.fromJson(json['profileCard'] as Map<String, dynamic>),
      followRequested: json['followRequested'] as bool? ?? false,
      gender: genderFromJson(json['gender']),
      category: accountCategoryFromJson(json['category']),
      links: json['links'] == null
          ? const <ProfileLink>[]
          : profileLinksFromJson(json['links']),
      rechargeAgentCode: rechargeAgentCodeFromJson(json['rechargeAgent']),
      avatarFrame: avatarFrameFromJson(json['avatarFrame']),
    );

Map<String, dynamic> _$PublicProfileToJson(_PublicProfile instance) =>
    <String, dynamic>{
      'id': instance.id,
      'username': instance.username,
      'displayName': instance.displayName,
      'avatarUrl': instance.avatarUrl,
      'bio': instance.bio,
      'isPrivate': instance.isPrivate,
      'followerCount': instance.followerCount,
      'followingCount': instance.followingCount,
      'isFollowing': instance.isFollowing,
      'isSelf': instance.isSelf,
      'liveRoomId': instance.liveRoomId,
      'isMuted': instance.isMuted,
      'premiumTier': premiumTierToJson(instance.premiumTier),
      'family': instance.family,
      'cp': instance.cp,
      'medals': instance.medals,
      'profileCard': instance.profileCard,
      'followRequested': instance.followRequested,
      'gender': genderToJson(instance.gender),
      'category': accountCategoryToJson(instance.category),
      'links': profileLinksToJson(instance.links),
      'rechargeAgent': ?rechargeAgentCodeToJson(instance.rechargeAgentCode),
      'avatarFrame': ?avatarFrameToJson(instance.avatarFrame),
    };

_FollowState _$FollowStateFromJson(Map<String, dynamic> json) => _FollowState(
  isFollowing: json['isFollowing'] as bool,
  followerCount: (json['followerCount'] as num).toInt(),
  isRequested: json['isRequested'] as bool? ?? false,
);

Map<String, dynamic> _$FollowStateToJson(_FollowState instance) =>
    <String, dynamic>{
      'isFollowing': instance.isFollowing,
      'followerCount': instance.followerCount,
      'isRequested': instance.isRequested,
    };
