/**
 * KL-060: the v1.5-social operations declared in openapi.yaml (CP-006 M1). KL-037's coverage test
 * leaves the four v1.5 paths under /users/{username} to this file, so both lists stay exact. The
 * CP-008 story operations (M3), including `/feed/stories`, have their own exact list in
 * kl061-stories.e2e-spec.ts.
 */
import { describe, expect, it } from 'vitest';
import { operations } from './helpers/openapi.js';

const V15_PATHS =
  /^\/api\/v1\/(media|posts|feed|views|comments|hashtags|search|reports|admin\/reports|me\/(posts|saved|blocks|privacy)|users\/\{username\}\/(posts|reposts|block|mute))(\/|$)/;

describe('KL-060 contract coverage', () => {
  it('openapi v1.5-social declares exactly the M1 operations', () => {
    expect(
      operations()
        .filter((o) => V15_PATHS.test(o.path))
        .filter((o) => !o.path.includes('stories'))
        .map((o) => o.operationId)
        .sort(),
    ).toEqual(
      [
        // Media (§11.1)
        'createMediaUpload',
        'completeMediaUpload',
        'getMedia',
        // Posts (§11.2)
        'createPost',
        'getPost',
        'updatePost',
        'deletePost',
        'listMyPosts',
        'pinPost',
        'unpinPost',
        'listUserPosts',
        'listUserReposts',
        'likePost',
        'unlikePost',
        'listPostLikes',
        'savePost',
        'unsavePost',
        'listSavedPosts',
        'repostPost',
        'unrepostPost',
        'countPostShare',
        // Feeds and views (§11.3, §11.4)
        'listFeedPosts',
        // v1.41-social (D162, §11.14): the reels feed of Moments.
        'listFeedReels',
        'recordViews',
        // Comments (§11.5)
        'listComments',
        'createComment',
        'listReplies',
        'deleteComment',
        'likeComment',
        'unlikeComment',
        'pinComment',
        'unpinComment',
        // Hashtags and search (§11.6)
        'getHashtag',
        'listHashtagPosts',
        'search',
        // v1.29-live (D147): search trends under /search (§11.11)
        'listTrendingSearches',
        'listTrendingHashtags',
        'recordSearchQuery',
        // Safety (§11.7)
        'blockUser',
        'unblockUser',
        'listBlocks',
        'muteUser',
        'unmuteUser',
        'hidePost',
        'unhidePost',
        'createReport',
        'getPrivacy',
        'updatePrivacy',
        'listAdminReports',
        'actOnReport',
      ].sort(),
    );
  });

  it('the v1.5 paths under /users/{username} are exactly the four KL-037 leaves out', () => {
    expect(
      operations()
        .filter((o) => /^\/api\/v1\/users\/\{username\}\/(posts|reposts|block|mute)$/.test(o.path))
        .map((o) => `${o.method} ${o.path}`)
        .sort(),
    ).toEqual(
      [
        'delete /api/v1/users/{username}/block',
        'delete /api/v1/users/{username}/mute',
        'get /api/v1/users/{username}/posts',
        'get /api/v1/users/{username}/reposts',
        'put /api/v1/users/{username}/block',
        'put /api/v1/users/{username}/mute',
      ].sort(),
    );
  });
});
