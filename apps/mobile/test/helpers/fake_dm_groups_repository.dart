import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/features/messages/data/dm_groups_repository.dart';
import 'package:kabso_live/features/messages/domain/dm_models.dart';
import 'package:kabso_live/features/posts/domain/post_models.dart';

import 'fake_dm_repository.dart';

/// An in-memory [DmGroupsRepository] (tests only, D339): groups by id with
/// their members and messages (newest first); every call is recorded in
/// [calls] and [failNext] makes the named call throw once.
class FakeDmGroupsRepository implements DmGroupsRepository {
  final List<String> calls = [];
  final Map<String, Exception> failNext = {};

  /// The DM fake whose lists show the groups (archive, leave move them).
  FakeDmRepository? dm;

  /// The people the caller may add.
  final List<UserSummary> candidatesList = [];

  final Map<String, DmGroupDetail> details = {};
  final Map<String, List<DmGroupMessage>> messagesOf = {};

  DateTime now = DateTime.utc(2026, 11, 9, 12);
  int _seq = 0;

  /// The server's 404 (a group the caller is not in, or removed).
  static ServerFailure failureNotFound() => ServerFailure(
    code: ErrorCode.notFound,
    rawCode: ErrorCode.notFound.wire,
    debugMessage: 'NOT_FOUND',
    statusCode: 404,
  );

  void _step(String call) {
    calls.add(call);
    final name = call.split(':').first;
    if (failNext.remove(name) case final e?) throw e;
  }

  /// Adds a group with [members] (the caller first, as [role]).
  DmGroupDetail addGroup(
    String id,
    String name, {
    List<UserSummary> members = const [],
    DmGroupRole role = DmGroupRole.admin,
    List<DmGroupMessage> messages = const [],
    String? photoUrl,
    int maxMembers = 100,
  }) {
    final me = dmPerson('me', name: 'Me');
    final all = [
      DmGroupMember(
        user: me,
        role: role,
        creator: role == DmGroupRole.admin,
        joinedAt: now,
      ),
      for (final m in members)
        DmGroupMember(user: m, role: DmGroupRole.member, joinedAt: now),
    ];
    messagesOf[id] = [...messages];
    return details[id] = DmGroupDetail(
      group: DmGroup(
        id: id,
        name: name,
        photoUrl: photoUrl,
        memberCount: all.length,
        role: role,
        lastMessage: messages.isEmpty ? null : messages.first,
        lastActivityAt: messages.isEmpty ? now : messages.first.createdAt,
        createdAt: now,
      ),
      members: all,
      maxMembers: maxMembers,
    );
  }

  /// A message in group [groupId].
  DmGroupMessage message(
    String groupId, {
    required bool mine,
    UserSummary? sender,
    String text = 'hello',
    int readCount = 0,
    DateTime? at,
  }) {
    _seq++;
    final createdAt = at ?? now.subtract(Duration(minutes: 100 - _seq));
    return DmGroupMessage(
      id: 'gm$_seq',
      groupId: groupId,
      sender: mine ? dmPerson('me', name: 'Me') : sender,
      mine: mine,
      kind: DmMessageKind.text,
      text: text,
      readCount: readCount,
      createdAt: createdAt,
      expiresAt: createdAt.add(const Duration(hours: 24)),
    );
  }

  @override
  Future<DmCandidatePage> candidates({
    String? query,
    String? groupId,
    String? cursor,
  }) async {
    _step('candidates${query == null ? '' : ':q=$query'}');
    final q = query?.toLowerCase();
    return (
      data: [
        for (final u in candidatesList)
          if (q == null ||
              u.username.toLowerCase().startsWith(q) ||
              u.displayName.toLowerCase().startsWith(q))
            u,
      ],
      nextCursor: null,
    );
  }

  @override
  Future<DmGroupDetail> create({
    required String name,
    required List<String> members,
    required String clientId,
    String? photoMediaId,
  }) async {
    _step('create:$name:${members.join(',')}:${photoMediaId ?? '-'}');
    return addGroup(
      'g-new',
      name,
      members: [
        for (final m in members)
          candidatesList.firstWhere(
            (u) => u.username == m,
            orElse: () => dmPerson(m),
          ),
      ],
    );
  }

  @override
  Future<DmGroupDetail> detail(String groupId) async {
    _step('detail:$groupId');
    return details[groupId]!;
  }

  @override
  Future<DmGroupDetail> update(
    String groupId, {
    String? name,
    String? photoMediaId,
    bool removePhoto = false,
  }) async {
    final photo = removePhoto ? 'remove' : photoMediaId ?? '-';
    _step('update:$groupId:${name ?? '-'}:$photo');
    final d = details[groupId]!;
    return details[groupId] = DmGroupDetail(
      group: d.group.copyWith(name: name, clearPhoto: removePhoto),
      members: d.members,
      maxMembers: d.maxMembers,
    );
  }

  @override
  Future<DmGroupDetail> addMembers(
    String groupId,
    List<String> usernames,
  ) async {
    _step('add:$groupId:${usernames.join(',')}');
    return details[groupId]!;
  }

  @override
  Future<void> removeMember(String groupId, String username) async =>
      _step('remove:$groupId:$username');

  @override
  Future<void> setRole(
    String groupId,
    String username,
    DmGroupRole role,
  ) async => _step('role:$groupId:$username:${role.wire}');

  @override
  Future<void> leave(String groupId) async {
    _step('leave:$groupId');
    dm?.groups.remove(groupId);
  }

  @override
  Future<DmGroupMessagePage> messages(String groupId, {String? cursor}) async {
    _step('messages:$groupId');
    final d = details[groupId];
    if (d == null) throw failureNotFound();
    return DmGroupMessagePage(
      data: [...messagesOf[groupId] ?? const <DmGroupMessage>[]],
      nextCursor: null,
      group: d.group,
    );
  }

  @override
  Future<DmGroupSendResult> send(
    String groupId,
    DmOutgoing message, {
    required String clientId,
  }) async {
    final text = message is DmOutgoingText ? message.text : '';
    _step('send:$groupId:$text');
    _seq++;
    final at = now.add(Duration(seconds: _seq));
    final m = DmGroupMessage(
      id: 'sent-$_seq',
      groupId: groupId,
      sender: dmPerson('me', name: 'Me'),
      mine: true,
      kind: DmMessageKind.text,
      text: text,
      createdAt: at,
      expiresAt: at.add(const Duration(hours: 24)),
    );
    messagesOf[groupId] = [
      m,
      ...messagesOf[groupId] ?? const <DmGroupMessage>[],
    ];
    return DmGroupSendResult(message: m, group: details[groupId]!.group);
  }

  @override
  Future<void> markRead(String groupId, String lastMessageId) async =>
      _step('read:$groupId:$lastMessageId');

  @override
  Future<void> deleteMessage(String groupId, String messageId) async {
    _step('deleteMessage:$groupId:$messageId');
    messagesOf[groupId]?.removeWhere((m) => m.id == messageId);
  }

  @override
  Future<void> setMuted(String groupId, {required bool muted}) async =>
      _step('mute:$groupId:$muted');

  @override
  Future<void> setArchived(String groupId, {required bool archived}) async {
    _step('archive:$groupId:$archived');
    final g = dm?.groups[groupId];
    if (g != null) dm!.groups[groupId] = g.copyWith(archived: archived);
  }

  @override
  Future<void> report(String groupId, ReportReason reason) async =>
      _step('report:$groupId:${reason.wire}');
}
