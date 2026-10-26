// In-memory CP-018 repositories (tests only). Every call is recorded in
// `calls`; a failure set in `failNext[method]` is thrown once by it.

import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/features/cp/data/cp_repository.dart';
import 'package:kabso_live/features/cp/domain/cp_models.dart';
import 'package:kabso_live/features/cp/domain/cp_space_models.dart';
import 'package:kabso_live/features/families/data/families_repository.dart';
import 'package:kabso_live/features/families/domain/family_models.dart';
import 'package:kabso_live/features/medals/data/medals_repository.dart';
import 'package:kabso_live/features/medals/domain/medal_models.dart';
import 'package:kabso_live/features/posts/domain/post_models.dart';

import '../fixtures/bonds/bonds_api_fixtures.dart';

/// A server failure with [code] (409 unless given).
ServerFailure bondFailure(ErrorCode code, {int status = 409}) => ServerFailure(
  code: code,
  rawCode: code.wire,
  debugMessage: 'test',
  statusCode: status,
);

const _page = PageInfo(nextCursor: null, hasMore: false);

mixin _Recorder {
  final List<String> calls = [];
  final Map<String, AppFailure> failNext = {};

  void record(String call) {
    calls.add(call);
    final name = call.split(':').first;
    if (failNext.remove(name) case final failure?) throw failure;
  }
}

class FakeFamiliesRepository with _Recorder implements FamiliesRepository {
  FamilyConfig configValue = FamilyConfig.fromJson(familyConfigJson());
  List<FamilyCard> families = [FamilyCard.fromJson(familyCardJson())];
  Family? myFamily;
  FamilyJoinRequest? myJoinRequest;
  Map<String, Family> byId = {};
  List<FamilyMember> memberList = [];
  List<FamilyJoinRequest> requests = [];
  int coinsAfterCreate = 0;

  /// v1.25-live (CP-022): the boards, standing, contributions and chat.
  Map<FamilyRankingBoard, FamilyRankings> boards = {};
  FamilyStanding? standingValue;
  List<FamilyContribution> contributionList = [];
  List<FamilyChatMessage> chatMessages = [];
  bool chatMuted = false;
  bool chatCanModerate = false;
  int chatSends = 0;

  @override
  Future<FamilyConfig> config() async {
    record('config');
    return configValue;
  }

  @override
  Future<FamilyCardPage> search({String? query, String? cursor}) async {
    record('search:${query ?? ''}');
    return FamilyCardPage(
      data: [
        for (final f in families)
          if (query == null || query.isEmpty || f.name.contains(query)) f,
      ],
      page: _page,
    );
  }

  @override
  Future<({Family family, int coins})> create({
    required String name,
    required String clientId,
    String? emblemMediaId,
  }) async {
    record('create:$name:$clientId:${emblemMediaId ?? ''}');
    final family = Family.fromJson(familyJson(name: name));
    myFamily = family;
    byId[family.id] = family;
    return (family: family, coins: coinsAfterCreate);
  }

  @override
  Future<Family?> mine() async {
    record('mine');
    return myFamily;
  }

  @override
  Future<Family> get(String familyId) async {
    record('get:$familyId');
    return byId[familyId] ??
        (throw bondFailure(ErrorCode.notFound, status: 404));
  }

  @override
  Future<Family> byNumber(String number) async {
    record('byNumber:$number');
    return byId.values.firstWhere(
      (f) => '${f.number}' == number,
      orElse: () => throw bondFailure(ErrorCode.notFound, status: 404),
    );
  }

  @override
  Future<Family> setEmblem(String familyId, String? emblemMediaId) async {
    record('setEmblem:$familyId:$emblemMediaId');
    return byId[familyId]!;
  }

  @override
  Future<void> disband(String familyId) async => record('disband:$familyId');

  @override
  Future<FamilyMemberPage> members(
    String familyId, {
    String? cursor,
    bool byPoints = false,
    String? query,
  }) async {
    record(
      'members:$familyId${byPoints ? ':points' : ''}'
      '${query == null ? '' : ':q=$query'}',
    );
    return FamilyMemberPage(
      data: [
        for (final m in memberList)
          if (query == null ||
              m.user.username.contains(query) ||
              m.user.displayName.contains(query))
            m,
      ],
      page: _page,
    );
  }

  @override
  Future<Family> updateLook(
    String familyId, {
    String? coverMediaId,
    bool removeCover = false,
    String? tagline,
  }) async {
    record(
      'updateLook:$familyId:${removeCover ? 'null' : coverMediaId ?? ''}'
      ':${tagline ?? ''}',
    );
    final f = byId[familyId]!.copyWith(
      coverUrl: removeCover
          ? null
          : coverMediaId == null
          ? byId[familyId]!.coverUrl
          : 'https://media.example.test/media/$coverMediaId/1080.webp',
      tagline: tagline == null
          ? byId[familyId]!.tagline
          : tagline.isEmpty
          ? null
          : tagline,
    );
    byId[familyId] = f;
    return f;
  }

  @override
  Future<FamilyRankings> rankings(
    FamilyRankingBoard board, {
    String? cursor,
  }) async {
    record('rankings:${board.wire}');
    return boards[board] ??
        FamilyRankings(
          board: board,
          startsAt: DateTime.utc(2026, 10),
          endsAt: DateTime.utc(2026, 11),
          data: const [],
          page: _page,
          me: null,
        );
  }

  @override
  Future<FamilyStanding> standing(String familyId) async {
    record('standing:$familyId');
    return standingValue ??
        FamilyStanding.fromJson(familyStandingJson(familyId: familyId));
  }

  @override
  Future<FamilyContributions> contributions(
    String familyId, {
    String? cursor,
  }) async {
    record('contributions:$familyId');
    return FamilyContributions(
      startsAt: DateTime.utc(2026, 10),
      endsAt: DateTime.utc(2026, 11),
      data: contributionList,
      page: _page,
    );
  }

  @override
  Future<FamilyChatPage> chat(String familyId, {String? cursor}) async {
    record('chat:$familyId');
    return FamilyChatPage(
      data: chatMessages,
      page: _page,
      muted: chatMuted,
      canModerate: chatCanModerate,
    );
  }

  @override
  Future<FamilyChatMessage> sendChat(
    String familyId, {
    required String text,
    required String clientId,
  }) async {
    record('sendChat:$text');
    chatSends++;
    final m = FamilyChatMessage.fromJson(
      familyChatMessageJson(
        id: 'sent-$chatSends',
        text: text,
        author: bondUserJson(
          id: '0192f1c2-7c3a-7b2e-9a51-1d2c3b4a5e6f',
          username: 'layla.k',
          displayName: 'Layla',
        ),
      ),
    );
    chatMessages = [m, ...chatMessages];
    return m;
  }

  @override
  Future<void> deleteChat(String familyId, String messageId) async {
    record('deleteChat:$messageId');
    chatMessages = [...chatMessages]..removeWhere((m) => m.id == messageId);
  }

  @override
  Future<void> setChatMuted(
    String familyId,
    String username, {
    required bool muted,
  }) async => record('chatMute:$username:$muted');

  @override
  Future<void> reportChat(String messageId, ReportReason reason) async =>
      record('reportChat:$messageId:${reason.wire}');

  @override
  Future<void> removeMember(String familyId, String username) async =>
      record('remove:$username');

  @override
  Future<FamilyMember> setRole(
    String familyId,
    String username,
    FamilyRole role,
  ) async {
    record('role:$username:${role.wire}');
    return memberList.firstWhere((m) => m.user.username == username);
  }

  @override
  Future<Family> transfer(String familyId, String username) async {
    record('transfer:$username');
    return byId[familyId]!;
  }

  @override
  Future<void> leave(String familyId) async => record('leave:$familyId');

  @override
  Future<FamilyJoinRequest> requestToJoin(String familyId) async {
    record('join:$familyId');
    final f = byId[familyId]!;
    byId[familyId] = f.copyWith(myRequestId: 'req-1');
    final request = FamilyJoinRequest.fromJson(familyJoinRequestJson());
    myJoinRequest = request;
    return request;
  }

  @override
  Future<FamilyJoinRequestPage> joinRequests(
    String familyId, {
    String? cursor,
  }) async {
    record('requests:$familyId');
    return FamilyJoinRequestPage(data: requests, page: _page);
  }

  @override
  Future<FamilyMember> acceptRequest(String familyId, String requestId) async {
    record('accept:$requestId');
    final r = requests.firstWhere((x) => x.id == requestId);
    requests = [...requests]..remove(r);
    final m = FamilyMember(
      user: r.user,
      role: FamilyRole.member,
      joinedAt: DateTime.utc(2026, 10, 26),
      points: 0,
    );
    memberList = [...memberList, m];
    return m;
  }

  @override
  Future<void> declineRequest(String familyId, String requestId) async {
    record('decline:$requestId');
    requests = [...requests]..removeWhere((x) => x.id == requestId);
  }

  @override
  Future<FamilyJoinRequest?> myRequest() async {
    record('myRequest');
    return myJoinRequest;
  }

  @override
  Future<void> cancelMyRequest() async {
    record('cancelMyRequest');
    myJoinRequest = null;
    byId.updateAll((_, f) => f.copyWith(myRequestId: null));
  }
}

class FakeCpRepository with _Recorder implements CpRepository {
  CpConfig configValue = CpConfig.fromJson(cpConfigJson());
  CpCouple? couple;
  List<CpRequest> incoming = [];
  List<CpRequest> outgoing = [];
  int coins = 500;

  @override
  Future<CpConfig> config() async {
    record('config');
    return configValue;
  }

  @override
  Future<({CpRequest request, int coins})> sendRequest({
    required String username,
    required String clientId,
  }) async {
    record('send:$username:$clientId');
    final r = CpRequest.fromJson(cpRequestJson());
    outgoing = [...outgoing, r];
    coins -= configValue.requestCost;
    return (request: r, coins: coins);
  }

  @override
  Future<CpRequestPage> requests(
    CpDirection direction, {
    String? cursor,
  }) async {
    record('list:${direction.name}');
    return CpRequestPage(
      data: direction == CpDirection.incoming ? incoming : outgoing,
      page: _page,
    );
  }

  @override
  Future<void> cancelRequest(String requestId) async {
    record('cancel:$requestId');
    outgoing = [...outgoing]..removeWhere((r) => r.id == requestId);
  }

  @override
  Future<CpCouple> acceptRequest(String requestId) async {
    record('accept:$requestId');
    incoming = [...incoming]..removeWhere((r) => r.id == requestId);
    final c = CpCouple.fromJson(cpCoupleJson());
    couple = c;
    return c;
  }

  @override
  Future<void> declineRequest(String requestId) async {
    record('decline:$requestId');
    incoming = [...incoming]..removeWhere((r) => r.id == requestId);
  }

  @override
  Future<CpCouple?> mine() async {
    record('mine');
    return couple;
  }

  @override
  Future<void> end() async {
    record('end');
    couple = null;
  }

  @override
  Future<({CpGift gift, CpCouple cp, int coins})> sendGift({
    required int amount,
    required String clientId,
  }) async {
    record('gift:$amount:$clientId');
    coins -= amount;
    final c = couple!.copyWith(points: couple!.points + amount);
    couple = c;
    return (
      gift: CpGift(id: 'g', amount: amount, createdAt: DateTime.utc(2026)),
      cp: c,
      coins: coins,
    );
  }

  // ---- CP-021 ------------------------------------------------------------

  CpTasks tasksValue = CpTasks.fromJson(cpTasksJson());
  CpPrivileges privilegesValue = CpPrivileges.fromJson(cpPrivilegesJson());
  List<CpConfession> confessions = [];
  Map<CpRankingPeriod, CpRankings> rankingsValue = {
    for (final p in CpRankingPeriod.values)
      p: CpRankings.fromJson(cpRankingsJson(p.wire)),
  };
  Map<String, CpCouplePublic> couples = {};
  CpGiftWall giftWallValue = CpGiftWall.fromJson(cpGiftWallJson());

  /// The claim answers 200 (claimed already by the partner) when true.
  bool claimAlready = false;
  int _confessionSeq = 0;

  @override
  Future<CpTasks> tasks() async {
    record('tasks');
    return tasksValue;
  }

  @override
  Future<CpTasks> checkIn() async {
    record('checkIn');
    return tasksValue;
  }

  @override
  Future<CpTaskClaim> claimTask(String code) async {
    record('claim:$code');
    final task = tasksValue.tasks.firstWhere((t) => t.code == code);
    if (!task.completed) {
      throw bondFailure(ErrorCode.cpTaskNotCompleted);
    }
    final claimed = CpTask(
      code: task.code,
      name: task.name,
      description: task.description,
      reward: task.reward,
      progress: task.progress,
      target: task.target,
      completed: true,
      claimed: true,
    );
    tasksValue = tasksValue.withTask(claimed);
    final added = !task.claimed && !claimAlready;
    if (added) {
      couple = couple!.copyWith(points: couple!.points + task.reward);
    }
    return (task: claimed, cp: couple!, added: added);
  }

  @override
  Future<CpPrivileges> privileges() async {
    record('privileges');
    return privilegesValue;
  }

  @override
  Future<CpConfessionPage> myConfessions({String? cursor}) async {
    record('confessions');
    return CpConfessionPage(data: confessions, page: _page);
  }

  @override
  Future<CpConfession> createConfession({
    required String text,
    required String clientId,
  }) async {
    record('confess:$clientId');
    final c = CpConfession.fromJson(
      cpConfessionJson(
        id: 'new-${_confessionSeq++}',
        author: cpMeJson(),
        recipient: cpPartnerJson(),
        text: text,
      ),
    );
    confessions = [c, ...confessions];
    return c;
  }

  @override
  Future<void> deleteConfession(String confessionId) async {
    record('deleteConfession:$confessionId');
    confessions = [...confessions]..removeWhere((c) => c.id == confessionId);
  }

  @override
  Future<void> reportConfession(
    String confessionId,
    ReportReason reason,
  ) async {
    record('reportConfession:$confessionId:${reason.wire}');
  }

  @override
  Future<CpRankings> rankings(CpRankingPeriod period, {String? cursor}) async {
    record('rankings:${period.wire}');
    return rankingsValue[period]!;
  }

  @override
  Future<CpCouplePublic> publicCouple(String coupleId) async {
    record('couple:$coupleId');
    return couples[coupleId] ??
        (throw bondFailure(ErrorCode.notFound, status: 404));
  }

  @override
  Future<CpGiftWall> giftWall(String coupleId, {String? cursor}) async {
    record('giftWall:$coupleId');
    return giftWallValue;
  }

  @override
  Future<CpConfessionPage> coupleConfessions(
    String coupleId, {
    String? cursor,
  }) async {
    record('coupleConfessions:$coupleId');
    return CpConfessionPage(data: confessions, page: _page);
  }
}

class FakeMedalsRepository with _Recorder implements MedalsRepository {
  List<Medal> medals = [];
  List<ProfileMedal> chosen = [];
  UserMedalList? userList;

  @override
  Future<MedalCatalogue> catalogue() async {
    record('catalogue');
    return MedalCatalogue(
      data: medals,
      total: medals.length,
      owned: medals.where((m) => m.unlocked).length,
    );
  }

  @override
  Future<UserMedalList> userMedals(String username) async {
    record('user:$username');
    return userList ?? const UserMedalList(data: [], owned: 0, total: 9);
  }

  @override
  Future<List<ProfileMedal>> showcase() async {
    record('showcase');
    return chosen;
  }

  @override
  Future<List<ProfileMedal>> setShowcase(List<String> medalCodes) async {
    record('setShowcase:${medalCodes.join(',')}');
    return chosen = [
      for (final code in medalCodes)
        ProfileMedal(
          code: code,
          name: code,
          iconKey: medals.firstWhere((m) => m.code == code).iconKey,
        ),
    ];
  }
}

/// Medals of the catalogue: [owned] earned, the rest locked.
List<Medal> testMedals({required int owned, int total = 9}) => [
  for (var i = 0; i < total; i++)
    Medal.fromJson(
      medalJson(
        'M$i',
        name: 'Medal $i',
        sortOrder: i,
        awardedAt: i < owned ? '2026-10-26T18:30:00.000Z' : null,
      ),
    ),
];
