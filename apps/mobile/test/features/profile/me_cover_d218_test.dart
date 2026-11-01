// D218 (v1.76-social): `Me.coverUrl` and the public profile's `coverUrl`,
// `country`, `joinedMonth`, `blockedByMe` parse from the contract's shapes
// (and from older servers without them). Guards the own profile, which
// reads `GET /me`, against a parsing regression.

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/features/auth/data/dtos.dart';
import 'package:kabso_live/features/profile/domain/profile_models.dart';

Map<String, dynamic> _me({Object? cover = 'absent'}) => {
  'id': '0192f1c2-7a10-7c3e-9d2a-3b4c5d6e7f80',
  'email': 'a@example.test',
  'emailVerified': true,
  'username': 'layla.k',
  'displayName': 'Layla',
  'bio': null,
  'avatarUrl': null,
  'locale': 'ar',
  'role': 'USER',
  'isPrivate': false,
  'createdAt': '2026-10-01T09:00:00.000Z',
  'canHost': false,
  'liveCoverUrl': null,
  'country': 'JO',
  'gender': null,
  'showGender': false,
  'category': null,
  'links': <Object>[],
  if (cover != 'absent') 'coverUrl': cover,
};

Map<String, dynamic> _profile({bool d218 = true}) => {
  'id': '0192f1c2-7a10-7c3e-9d2a-3b4c5d6e7f81',
  'username': 'host0',
  'displayName': 'Sara',
  'avatarUrl': null,
  'bio': null,
  'isPrivate': false,
  'followerCount': 3,
  'followingCount': 4,
  'isFollowing': false,
  'followRequested': false,
  'isMuted': false,
  'isSelf': false,
  'liveRoomId': null,
  'family': null,
  'cp': null,
  'medals': {
    'owned': 0,
    'total': 0,
    'latest': <Object>[],
    'showcase': <Object>[],
  },
  'profileCard': null,
  'gender': null,
  'category': null,
  'links': <Object>[],
  'rechargeAgent': null,
  'hostAgent': null,
  'avatarFrame': null,
  if (d218) ...{
    'coverUrl': 'https://media.example.test/media/c/1080.webp',
    'country': 'JO',
    'joinedMonth': '2025-04',
    'blockedByMe': true,
  },
};

void main() {
  test('Me: coverUrl set, null or absent (an older server)', () {
    expect(
      MeDto.fromJson(_me(cover: 'https://media.example.test/media/c/1080.webp'))
          .toEntity()
          .coverUrl,
      'https://media.example.test/media/c/1080.webp',
    );
    expect(MeDto.fromJson(_me(cover: null)).toEntity().coverUrl, isNull);
    final old = MeDto.fromJson(_me()).toEntity();
    expect(old.coverUrl, isNull);
    expect(old.country, 'JO');
  });

  test('PublicProfile: the D218 fields, and an older server without them', () {
    final p = PublicProfile.fromJson(_profile());
    expect(p.coverUrl, 'https://media.example.test/media/c/1080.webp');
    expect(p.country, 'JO');
    expect(p.joinedMonth, '2025-04');
    expect(p.blockedByMe, isTrue);
    final old = PublicProfile.fromJson(_profile(d218: false));
    expect(old.coverUrl, isNull);
    expect(old.joinedMonth, isNull);
    expect(old.blockedByMe, isFalse);
  });
}
