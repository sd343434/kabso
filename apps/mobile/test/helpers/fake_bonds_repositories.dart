// In-memory CP-018 repositories (tests only). Every call is recorded in
// `calls`; a failure set in `failNext[method]` is thrown once by it.

import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/features/cp/data/cp_repository.dart';
import 'package:kabso_live/features/cp/domain/cp_models.dart';
import 'package:kabso_live/features/families/data/families_repository.dart';
import 'package:kabso_live/features/families/domain/family_models.dart';
import 'package:kabso_live/features/medals/data/medals_repository.dart';
import 'package:kabso_live/features/medals/domain/medal_models.dart';

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
  Future<FamilyMemberPage> members(String familyId, {String? cursor}) async {
    record('members:$familyId');
    return FamilyMemberPage(data: memberList, page: _page);
  }

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
