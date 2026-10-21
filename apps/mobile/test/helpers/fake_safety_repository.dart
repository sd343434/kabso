import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/features/posts/domain/post_models.dart';
import 'package:kabso_live/features/safety/safety_repository.dart';

/// An in-memory [SafetyRepository] (tests only): [blockedUsers] and
/// [muted] usernames, [privacySettings]; [failWith] makes the next call throw;
/// every call is recorded in [calls].
class FakeSafetyRepository implements SafetyRepository {
  new({List<UserSummary>? blockedUsers, this.pageSize = 20})
    : blockedUsers = blockedUsers ?? [];

  final List<UserSummary> blockedUsers;
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
    muted ? this.muted.add(username) : this.muted.remove(username);
    return muted;
  }

  @override
  Future<PageOf<UserSummary>> blocks({String? cursor}) async {
    _step('blocks:${cursor ?? ''}');
    final start = cursor == null ? 0 : int.parse(cursor);
    final end = (start + pageSize).clamp(0, blockedUsers.length);
    final more = end < blockedUsers.length;
    return PageOf(
      blockedUsers.sublist(start, end),
      PageInfo(nextCursor: more ? '$end' : null, hasMore: more),
    );
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
  }) async {
    _step(
      'updatePrivacy:${whoCanMention?.wire ?? ''}:'
      '${defaultWhoCanComment?.wire ?? ''}',
    );
    return privacySettings = PrivacySettings(
      whoCanMention: whoCanMention ?? privacySettings.whoCanMention,
      defaultWhoCanComment:
          defaultWhoCanComment ?? privacySettings.defaultWhoCanComment,
    );
  }
}
