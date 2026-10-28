import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/features/posts/domain/post_models.dart';
import 'package:kabso_live/features/safety/safety_repository.dart';

/// An in-memory [SafetyRepository] (tests only): [blockedUsers] and
/// [muted] usernames, [privacySettings]; [failWith] makes the next call throw;
/// every call is recorded in [calls].
class FakeSafetyRepository implements SafetyRepository {
  new({
    List<UserSummary>? blockedUsers,
    List<UserSummary>? mutedUsers,
    this.pageSize = 20,
  }) : blockedUsers = blockedUsers ?? [],
       mutedUsers = mutedUsers ?? [];

  final List<UserSummary> blockedUsers;

  /// What `GET /me/mutes` lists (newest first).
  final List<UserSummary> mutedUsers;
  final Set<String> muted = {};
  final int pageSize;
  final List<String> calls = [];
  Exception? failWith;
  PrivacySettings privacySettings = const PrivacySettings(
    whoCanMention: MentionPolicy.everyone,
    defaultWhoCanComment: WhoCanComment.everyone,
  );

  void _step(String call) {
    calls.add(call);
    if (failWith case final e?) {
      failWith = null;
      throw e;
    }
  }

  @override
  Future<bool> setBlocked(String username, {required bool blocked}) async {
    _step('block:$username:$blocked');
    if (!blocked) blockedUsers.removeWhere((u) => u.username == username);
    return blocked;
  }

  @override
  Future<bool> setMuted(String username, {required bool muted}) async {
    _step('mute:$username:$muted');
    if (muted) {
      this.muted.add(username);
    } else {
      this.muted.remove(username);
      mutedUsers.removeWhere((u) => u.username == username);
    }
    return muted;
  }

  PageOf<UserSummary> _slice(List<UserSummary> all, String? cursor) {
    final start = cursor == null ? 0 : int.parse(cursor);
    final end = (start + pageSize).clamp(0, all.length);
    final more = end < all.length;
    return PageOf(
      all.sublist(start, end),
      PageInfo(nextCursor: more ? '$end' : null, hasMore: more),
    );
  }

  @override
  Future<PageOf<UserSummary>> blocks({String? cursor}) async {
    _step('blocks:${cursor ?? ''}');
    return _slice(blockedUsers, cursor);
  }

  @override
  Future<PageOf<UserSummary>> mutes({String? cursor}) async {
    _step('mutes:${cursor ?? ''}');
    return _slice(mutedUsers, cursor);
  }

  @override
  Future<void> reportUser(String userId, ReportReason reason) async =>
      _step('reportUser:$userId:${reason.wire}');

  @override
  Future<PrivacySettings> privacy() async {
    _step('privacy');
    return privacySettings;
  }

  @override
  Future<PrivacySettings> updatePrivacy({
    MentionPolicy? whoCanMention,
    WhoCanComment? defaultWhoCanComment,
    bool? showActivityStatus,
    MentionPolicy? whoCanMessage,
  }) async {
    _step(
      'updatePrivacy:${whoCanMention?.wire ?? ''}:'
      '${defaultWhoCanComment?.wire ?? ''}'
      '${showActivityStatus == null ? '' : ':activity=$showActivityStatus'}'
      '${whoCanMessage == null ? '' : ':message=${whoCanMessage.wire}'}',
    );
    return privacySettings = PrivacySettings(
      whoCanMention: whoCanMention ?? privacySettings.whoCanMention,
      defaultWhoCanComment:
          defaultWhoCanComment ?? privacySettings.defaultWhoCanComment,
      showActivityStatus:
          showActivityStatus ?? privacySettings.showActivityStatus,
      whoCanMessage: whoCanMessage ?? privacySettings.whoCanMessage,
    );
  }
}
