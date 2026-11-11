// D372 «هدية الدعم» (owner 2026-11-11): contract-shaped payloads of
// docs/contracts/openapi.yaml v1.127-social (`sendContentGift`,
// `ContentGiftResult`, `Comment.kind` / `Comment.gift`, `Post.giftCherries` /
// `Post.giftable`). Test data only.

import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/features/posts/domain/post_models.dart';

/// The goldens' pinned clock.
final DateTime d372Now = DateTime.utc(2026, 11, 11, 9, 30);

/// The author: a host «مضيف» whose posts take gifts.
const d372Host = UserSummary(
  id: 'u-layla',
  username: 'layla.live',
  displayName: 'Layla',
  avatarUrl: null,
);

/// A gift line (`kind: GIFT`) as the API lists it.
Map<String, Object?> d372GiftCommentJson({
  String id = 'cg1',
  String sender = 'Omar',
  String gift = 'Rose',
  int quantity = 10,
  String code = 'rose',
}) => {
  'id': id,
  'postId': 'p1',
  'author': {
    'id': 'u-$id',
    'username': sender.toLowerCase(),
    'displayName': sender,
    'avatarUrl': null,
  },
  'text': '',
  'createdAt': '2026-11-11T09:20:00.000Z',
  'likeCount': 2,
  'viewerHasLiked': false,
  'viewerHasDisliked': false,
  'replyCount': 0,
  'parentId': null,
  'mentions': <Object>[],
  'pinned': false,
  'canDelete': false,
  'kind': 'GIFT',
  'gift': {
    'giftCode': code,
    'name': gift,
    'quantity': quantity,
    'assetKey': 'gift_$code',
    'imageUrl': null,
  },
};

/// The sheet's comments: two gift lines around a text comment (ar or en).
List<Comment> d372Comments({required bool ar}) => [
  Comment.fromJson(
    d372GiftCommentJson(
      sender: ar ? 'عمر' : 'Omar',
      gift: ar ? 'وردة' : 'Rose',
    ),
  ),
  Comment(
    id: 'ct1',
    postId: 'p1',
    author: UserSummary(
      id: 'u-mona',
      username: 'mona',
      displayName: ar ? 'منى' : 'Mona',
      avatarUrl: null,
    ),
    text: ar ? 'أداء رائع الليلة' : 'Great show tonight',
    createdAt: DateTime.utc(2026, 11, 11, 9, 10),
    likeCount: 5,
    viewerHasLiked: false,
    replyCount: 0,
    parentId: null,
    mentions: const [],
    pinned: false,
    canDelete: false,
  ),
  Comment.fromJson(
    d372GiftCommentJson(
      id: 'cg2',
      sender: ar ? 'سارة' : 'Sara',
      gift: ar ? 'تاج' : 'Crown',
      quantity: 1,
      code: 'crown',
    ),
  ),
];
