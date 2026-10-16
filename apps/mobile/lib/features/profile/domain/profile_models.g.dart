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
    };

_FollowState _$FollowStateFromJson(Map<String, dynamic> json) => _FollowState(
  isFollowing: json['isFollowing'] as bool,
  followerCount: (json['followerCount'] as num).toInt(),
);

Map<String, dynamic> _$FollowStateToJson(_FollowState instance) =>
    <String, dynamic>{
      'isFollowing': instance.isFollowing,
      'followerCount': instance.followerCount,
    };
