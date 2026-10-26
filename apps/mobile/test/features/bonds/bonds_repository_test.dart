// CP-018: FamiliesRepository, CpRepository, MedalsRepository and the new
// PublicProfile fields against a mocked Dio adapter, with JSON shaped like
// docs/contracts/openapi.yaml v1.21-live.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/config/app_config.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/network/auth_tokens.dart';
import 'package:kabso_live/core/network/network_providers.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/features/cp/data/cp_repository.dart';
import 'package:kabso_live/features/cp/domain/cp_models.dart';
import 'package:kabso_live/features/families/data/families_repository.dart';
import 'package:kabso_live/features/families/domain/family_models.dart';
import 'package:kabso_live/features/medals/data/medals_repository.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';

import '../../fixtures/bonds/bonds_api_fixtures.dart';
import '../../fixtures/live/live_api_fixtures.dart';
import '../../helpers/contract_fixtures.dart';
import '../../helpers/fake_http_adapter.dart';
import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

const _base = '/api/v1';

void main() {
  late FakeHttpAdapter http;
  late ProviderContainer container;

  setUp(() async {
    http = FakeHttpAdapter();
    final prefs = await testPrefs(language: 'ar');
    container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(apiBaseUrl: 'http://test', appVersion: '1.2.3'),
        ),
        httpClientAdapterProvider.overrideWithValue(http),
        secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    await container
        .read(tokenManagerProvider)
        .saveTokens(AuthTokens.fromJson(tokenPairJson(accessToken: 'acc')));
  });

  group('FamiliesRepository', () {
    FamiliesRepository repo() => container.read(familiesRepositoryProvider);

    test('config and search (q, cursor)', () async {
      http
        ..on(
          'GET',
          '$_base/families/config',
          (_) => FakeResponse(200, body: familyConfigJson()),
        )
        ..on(
          'GET',
          '$_base/families',
          (_) => FakeResponse(
            200,
            body: pageJson([familyCardJson(level: 3)], nextCursor: 'c2'),
          ),
        );
      final config = await repo().config();
      expect(config.createCost, 500);
      expect(config.levels[1].minPoints, 1000);
      final page = await repo().search(query: 'نجوم', cursor: 'c1');
      expect(page.data.single.level, 3);
      expect(page.data.single.number, 48213907);
      expect(page.page.nextCursor, 'c2');
      final req = http.requestsTo('GET', '$_base/families').single;
      expect(req.uri.queryParameters, {'q': 'نجوم', 'cursor': 'c1'});
      expect(req.headers['Authorization'], 'Bearer acc');
    });

    test('create sends name and clientId; parses family and coins', () async {
      http.on(
        'POST',
        '$_base/families',
        (_) => FakeResponse(201, body: {'family': familyJson(), 'coins': 120}),
      );
      final result = await repo().create(name: 'عائلة النجوم', clientId: 'c-1');
      expect(result.coins, 120);
      expect(result.family.myRole, FamilyRole.leader);
      expect(result.family.nextLevelPoints, 1000);
      expect(result.family.leader?.username, 'sara');
      expect(http.requests.single.data, {
        'name': 'عائلة النجوم',
        'clientId': 'c-1',
      });
    });

    test('INSUFFICIENT_COINS and FAMILY_NAME_TAKEN map to codes', () async {
      var code = 'INSUFFICIENT_COINS';
      http.on(
        'POST',
        '$_base/families',
        (_) => FakeResponse(409, body: errorEnvelope(code, 'x')),
      );
      await expectLater(
        repo().create(name: 'abc', clientId: 'c'),
        throwsA(
          isA<ServerFailure>().having(
            (f) => f.code,
            'code',
            ErrorCode.insufficientCoins,
          ),
        ),
      );
      code = 'FAMILY_NAME_TAKEN';
      await expectLater(
        repo().create(name: 'abc', clientId: 'c'),
        throwsA(
          isA<ServerFailure>().having(
            (f) => f.code,
            'code',
            ErrorCode.familyNameTaken,
          ),
        ),
      );
    });

    test('mine, my request and by number read null and objects', () async {
      http
        ..on(
          'GET',
          '$_base/families/me',
          (_) => const FakeResponse(200, body: {'family': null}),
        )
        ..on(
          'GET',
          '$_base/me/family-join-request',
          (_) => FakeResponse(200, body: {'request': familyJoinRequestJson()}),
        )
        ..on(
          'GET',
          '$_base/family-numbers/48213907',
          (_) => FakeResponse(200, body: familyJson(myRole: null)),
        );
      expect(await repo().mine(), isNull);
      final request = await repo().myRequest();
      expect(request?.status, BondRequestStatus.pending);
      expect(request?.family.name, 'عائلة النجوم');
      final family = await repo().byNumber('48213907');
      expect(family.myRole, isNull);
    });

    test('members, roles, transfer, join requests and answers', () async {
      const id = '0192f1d0-8888-7000-8000-000000000002';
      http
        ..on(
          'GET',
          '$_base/families/$id/members',
          (_) => FakeResponse(
            200,
            body: pageJson([
              familyMemberJson(role: 'LEADER', points: 500),
              familyMemberJson(
                user: bondUserJson(id: 'u2', username: 'omar'),
                role: 'DEPUTY',
              ),
            ]),
          ),
        )
        ..on(
          'PUT',
          '$_base/families/$id/members/omar/role',
          (_) => FakeResponse(
            200,
            body: familyMemberJson(
              user: bondUserJson(id: 'u2', username: 'omar'),
            ),
          ),
        )
        ..on(
          'POST',
          '$_base/families/$id/transfer',
          (_) => FakeResponse(200, body: familyJson(myRole: 'DEPUTY')),
        )
        ..on(
          'POST',
          '$_base/families/$id/join-requests',
          (_) => FakeResponse(201, body: familyJoinRequestJson()),
        )
        ..on(
          'POST',
          '$_base/families/$id/join-requests/r1/accept',
          (_) => FakeResponse(200, body: familyMemberJson()),
        )
        ..on(
          'POST',
          '$_base/families/$id/join-requests/r1/decline',
          (_) => const FakeResponse.noContent(),
        )
        ..on(
          'POST',
          '$_base/families/$id/leave',
          (_) => const FakeResponse.noContent(),
        );
      final members = await repo().members(id);
      expect(members.data.map((m) => m.role), [
        FamilyRole.leader,
        FamilyRole.deputy,
      ]);
      final member = await repo().setRole(id, 'omar', FamilyRole.member);
      expect(member.role, FamilyRole.member);
      expect(
        http
            .requestsTo('PUT', '$_base/families/$id/members/omar/role')
            .single
            .data,
        {'role': 'MEMBER'},
      );
      expect((await repo().transfer(id, 'omar')).myRole, FamilyRole.deputy);
      expect((await repo().requestToJoin(id)).user.username, 'omar');
      await repo().acceptRequest(id, 'r1');
      await repo().declineRequest(id, 'r1');
      await repo().leave(id);
    });
  });

  group('CpRepository', () {
    CpRepository repo() => container.read(cpRepositoryProvider);

    test('config, send (clientId), list incoming and accept', () async {
      http
        ..on(
          'GET',
          '$_base/cp/config',
          (_) => FakeResponse(200, body: cpConfigJson()),
        )
        ..on(
          'POST',
          '$_base/cp/requests',
          (_) => FakeResponse(
            201,
            body: {'request': cpRequestJson(), 'coins': 401},
          ),
        )
        ..on(
          'GET',
          '$_base/cp/requests',
          (_) => FakeResponse(200, body: pageJson([cpRequestJson()])),
        )
        ..on(
          'POST',
          '$_base/cp/requests/r1/accept',
          (_) => FakeResponse(200, body: cpCoupleJson()),
        );
      final config = await repo().config();
      expect(config.requestCost, 99);
      expect(config.giftAmounts, [10, 52, 99, 520, 1314]);
      expect(config.tiers.last.name, 'Legendary couple');
      final sent = await repo().sendRequest(username: 'layla.k', clientId: 'k');
      expect(sent.coins, 401);
      expect(sent.request.cost, 99);
      expect(http.requestsTo('POST', '$_base/cp/requests').single.data, {
        'username': 'layla.k',
        'clientId': 'k',
      });
      final page = await repo().requests(CpDirection.incoming);
      expect(page.data.single.sender.username, 'sara');
      expect(
        http.requestsTo('GET', '$_base/cp/requests').single.uri.queryParameters,
        {'direction': 'incoming'},
      );
      final couple = await repo().acceptRequest('r1');
      expect(couple.days, 7);
      expect(couple.pointsToNext, 694);
    });

    test('mine null, gifts and errors', () async {
      http
        ..on(
          'GET',
          '$_base/cp/me',
          (_) => const FakeResponse(200, body: {'cp': null}),
        )
        ..on(
          'POST',
          '$_base/cp/me/gifts',
          (_) => FakeResponse(
            201,
            body: {
              'gift': {
                'id': 'g1',
                'amount': 520,
                'createdAt': '2026-10-26T18:30:00.000Z',
              },
              'cp': cpCoupleJson(points: 1140),
              'coins': 10,
            },
          ),
        )
        ..on(
          'DELETE',
          '$_base/cp/requests/r9',
          (_) => FakeResponse(
            409,
            body: errorEnvelope('CP_REQUEST_NOT_PENDING', 'x'),
          ),
        );
      expect(await repo().mine(), isNull);
      final gift = await repo().sendGift(amount: 520, clientId: 'g');
      expect(gift.gift.amount, 520);
      expect(gift.cp.points, 1140);
      expect(gift.coins, 10);
      await expectLater(
        repo().cancelRequest('r9'),
        throwsA(
          isA<ServerFailure>().having(
            (f) => f.code,
            'code',
            ErrorCode.cpRequestNotPending,
          ),
        ),
      );
    });
  });

  group('MedalsRepository', () {
    MedalsRepository repo() => container.read(medalsRepositoryProvider);

    test('catalogue (owned and locked), user medals, showcase', () async {
      http
        ..on(
          'GET',
          '$_base/medals',
          (_) => FakeResponse(
            200,
            body: {
              'data': [
                medalJson('FIRST_LIVE'),
                medalJson('CHARM_10', awardedAt: null),
              ],
              'total': 9,
              'owned': 1,
            },
          ),
        )
        ..on(
          'GET',
          '$_base/users/layla.k/medals',
          (_) => FakeResponse(
            200,
            body: {
              'data': [
                {...medalJson('FIRST_LIVE')}..remove('sortOrder'),
              ],
              'owned': 1,
              'total': 9,
            },
          ),
        )
        ..on(
          'PUT',
          '$_base/me/medals/showcase',
          (_) => FakeResponse(
            200,
            body: {
              'showcase': [
                profileMedalJson('FIRST_CP'),
                profileMedalJson('FIRST_LIVE'),
              ],
            },
          ),
        );
      final c = await repo().catalogue();
      expect(c.owned, 1);
      expect(c.data.first.unlocked, isTrue);
      expect(c.data.last.unlocked, isFalse);
      final user = await repo().userMedals('layla.k');
      expect(user.data.single.code, 'FIRST_LIVE');
      final saved = await repo().setShowcase(['FIRST_CP', 'FIRST_LIVE']);
      expect(saved.map((m) => m.code), ['FIRST_CP', 'FIRST_LIVE']);
      expect(http.requestsTo('PUT', '$_base/me/medals/showcase').single.data, {
        'medalCodes': ['FIRST_CP', 'FIRST_LIVE'],
      });
    });
  });

  group('PublicProfile v1.21-live', () {
    test('family, cp and medals parse; older payloads still parse', () async {
      http.on(
        'GET',
        '$_base/users/layla.k',
        (_) => FakeResponse(
          200,
          body: {
            ...publicProfileJson(),
            'family': {
              'id': 'f1',
              'number': 48213907,
              'name': 'عائلة النجوم',
              'level': 2,
              'emblemUrl': null,
              'role': 'DEPUTY',
            },
            'cp': {
              'partner': bondUserJson(),
              'since': '2026-10-20T18:30:00.000Z',
              'level': 2,
              'levelName': 'ثنائي فضّي',
              'points': 620,
            },
            'medals': {
              'owned': 2,
              'total': 9,
              'latest': [profileMedalJson('FIRST_CP')],
              'showcase': [
                profileMedalJson('FIRST_LIVE'),
                profileMedalJson('FIRST_CP'),
              ],
            },
          },
        ),
      );
      final p = await container
          .read(profileRepositoryProvider)
          .getProfile('layla.k');
      expect(p.family?.role, FamilyRole.deputy);
      expect(p.family?.level, 2);
      expect(p.cp?.partner.username, 'sara');
      expect(p.cp?.levelName, 'ثنائي فضّي');
      expect(p.medals.owned, 2);
      expect(p.medals.showcase.map((m) => m.code), ['FIRST_LIVE', 'FIRST_CP']);

      http.on(
        'GET',
        '$_base/users/old',
        (_) => FakeResponse(200, body: publicProfileJson()),
      );
      final old = await container
          .read(profileRepositoryProvider)
          .getProfile('old');
      expect(old.family, isNull);
      expect(old.cp, isNull);
      expect(old.medals.showcase, isEmpty);
    });
  });
}
