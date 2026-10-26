// KL-038: LiveRepository and ProfileRepository against a mocked Dio adapter,
// with JSON copied from the docs/contracts/openapi.yaml v1.3 examples.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/config/app_config.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/network/auth_tokens.dart';
import 'package:kabso_live/core/network/network_providers.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:kabso_live/features/profile/domain/profile_models.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../helpers/contract_fixtures.dart';
import '../../helpers/fake_http_adapter.dart';
import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

const _base = '/api/v1';

void main() {
  late FakeHttpAdapter http;
  late ProviderContainer container;
  late LiveRepository live;
  late ProfileRepository profiles;

  Future<void> build({String language = 'ar'}) async {
    http = FakeHttpAdapter();
    final prefs = await testPrefs(language: language);
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
    live = container.read(liveRepositoryProvider);
    profiles = container.read(profileRepositoryProvider);
  }

  setUp(build);

  group('LiveRepository', () {
    test('getConfig: GET /live/config with bearer + Accept-Language', () async {
      http.on(
        'GET',
        '$_base/live/config',
        (_) => FakeResponse(200, body: liveConfigJson()),
      );
      final config = await live.getConfig();
      expect(config.hostingEnabled, isFalse);
      expect(config.heartbeatIntervalSeconds, 15);
      expect(config.heartbeatStaleAfterSeconds, 45);
      final req = http.requests.single;
      expect(req.headers['Authorization'], 'Bearer acc');
      expect(req.headers['Accept-Language'], 'ar');
    });

    test('Accept-Language follows the app language', () async {
      http.on(
        'GET',
        '$_base/live/categories',
        (_) => FakeResponse(200, body: liveCategoriesJson()),
      );
      await live.listCategories();
      expect(http.requests.last.headers['Accept-Language'], 'ar');
      await container
          .read(languageControllerProvider.notifier)
          .select(AppLanguage.en);
      await live.listCategories();
      expect(http.requests.last.headers['Accept-Language'], 'en');
    });

    test('listCategories: empty (production) and populated', () async {
      http.on(
        'GET',
        '$_base/live/categories',
        (_) => FakeResponse(200, body: liveCategoriesJson()),
      );
      expect(await live.listCategories(), isEmpty);
      http.on(
        'GET',
        '$_base/live/categories',
        (_) => FakeResponse(
          200,
          body: liveCategoriesJson([
            {'slug': 'music', 'name': 'موسيقى'},
            {'slug': 'chat', 'name': 'دردشة'},
          ]),
        ),
      );
      expect(await live.listCategories(), [
        const LiveCategory(slug: 'music', name: 'موسيقى'),
        const LiveCategory(slug: 'chat', name: 'دردشة'),
      ]);
    });

    test('listRooms: query and the onePage example', () async {
      http.on(
        'GET',
        '$_base/live/rooms',
        (_) => FakeResponse(200, body: liveRoomPageJson()),
      );
      final page = await live.listRooms(
        tab: LiveRoomsTab.popular,
        category: 'music',
        cursor: 'abc',
      );
      final query = http.requests.single.uri.queryParameters;
      expect(query, {
        'tab': 'popular',
        'category': 'music',
        'cursor': 'abc',
        'limit': '20',
      });
      final room = page.data.single;
      expect(room.id, '0192f1d0-1111-7aaa-8bbb-0c0d0e0f1011');
      expect(room.title, 'سهرة طرب');
      expect(room.mode, LiveRoomMode.solo);
      expect(room.viewerCount, 0);
      expect(room.startedAt, DateTime.utc(2026, 10, 16, 19));
      expect(room.coverUrl, isNull);
      expect(room.category, isNull);
      expect(room.host.username, 'layla.k');
      expect(room.host.displayName, 'ليلى');
      expect(room.host.avatarUrl, isNull);
      expect(page.page.hasMore, isTrue);
      expect(page.page.nextCursor, startsWith('eyJ2'));
    });

    test(
      'listRooms: tab "new", no category / cursor on the first page',
      () async {
        http.on(
          'GET',
          '$_base/live/rooms',
          (_) => FakeResponse(
            200,
            body: liveRoomPageJson(data: [], nextCursor: null, hasMore: false),
          ),
        );
        final page = await live.listRooms(tab: LiveRoomsTab.latest);
        expect(http.requests.single.uri.queryParameters, {
          'tab': 'new',
          'limit': '20',
        });
        expect(page.data, isEmpty);
        expect(page.page.nextCursor, isNull);
      },
    );

    test('an unknown future mode is rendered as SOLO', () async {
      http.on(
        'GET',
        '$_base/live/rooms',
        (_) => FakeResponse(
          200,
          body: liveRoomPageJson(data: [liveRoomSummaryJson(mode: 'PARTY')]),
        ),
      );
      final page = await live.listRooms(tab: LiveRoomsTab.popular);
      expect(page.data.single.mode, LiveRoomMode.solo);
    });

    test('getRoom: the ended example', () async {
      http.on(
        'GET',
        '$_base/live/rooms/0192f1d0-1111-7aaa-8bbb-0c0d0e0f1011',
        (_) => FakeResponse(200, body: endedLiveRoomJson()),
      );
      final room = await live.getRoom('0192f1d0-1111-7aaa-8bbb-0c0d0e0f1011');
      expect(room.status, LiveRoomStatus.ended);
      expect(room.endReason, LiveRoomEndReason.hostEnded);
      expect(room.endedAt, DateTime.utc(2026, 10, 16, 20, 12, 45, 120));
      expect(room.category, const LiveCategory(slug: 'music', name: 'موسيقى'));
    });

    test("v1.20-live: kick, list, undo and one person's standing", () async {
      const sara = {
        'id': '0192f1d0-5555-7000-8000-000000000006',
        'username': 'sara',
        'displayName': 'سارة',
        'avatarUrl': null,
      };
      http
        ..on(
          'POST',
          '$_base/live/rooms/r1/kicks',
          (_) => const FakeResponse(
            201,
            body: {'user': sara, 'kickedAt': '2026-10-26T18:30:00.000Z'},
          ),
        )
        ..on(
          'GET',
          '$_base/live/rooms/r1/kicks',
          (_) => const FakeResponse(
            200,
            body: {
              'data': [
                {'user': sara, 'kickedAt': '2026-10-26T18:30:00.000Z'},
              ],
            },
          ),
        )
        ..on(
          'DELETE',
          '$_base/live/rooms/r1/kicks/sara',
          (_) => const FakeResponse(204),
        )
        ..on(
          'GET',
          '$_base/live/rooms/r1/contributors/sara',
          (_) => const FakeResponse(
            200,
            body: {'user': sara, 'points': 1240, 'rank': 3},
          ),
        )
        ..on(
          'GET',
          '$_base/live/rooms/r1/contributors/omar',
          (_) => const FakeResponse(
            200,
            body: {
              'user': {
                'id': '0192f1d0-5555-7000-8000-000000000007',
                'username': 'omar',
                'displayName': 'عمر',
                'avatarUrl': null,
              },
              'points': 0,
              'rank': null,
            },
          ),
        );
      final kick = await live.kick('r1', 'sara');
      expect(kick.user.username, 'sara');
      expect(kick.kickedAt, DateTime.utc(2026, 10, 26, 18, 30));
      expect(http.requests.last.data, {'username': 'sara'});
      expect((await live.kicks('r1')).single.user.displayName, 'سارة');
      await live.unkick('r1', 'sara');
      expect(http.requests.last.method, 'DELETE');
      final standing = await live.contributor('r1', 'sara');
      expect((standing.points, standing.rank), (1240, 3));
      final none = await live.contributor('r1', 'omar');
      expect((none.points, none.rank), (0, null));
    });

    test('v1.20-live: LiveRoom.kicked and LIVE_KICKED', () async {
      http
        ..on(
          'GET',
          '$_base/live/rooms/r1',
          (_) =>
              FakeResponse(200, body: {...endedLiveRoomJson(), 'kicked': true}),
        )
        ..on(
          'POST',
          '$_base/live/rooms/r1/media-token',
          (_) =>
              FakeResponse(403, body: errorEnvelope('LIVE_KICKED', 'dev text')),
        );
      expect((await live.getRoom('r1')).kicked, isTrue);
      // Older payloads without the field: not kicked.
      expect(LiveRoom.fromJson(endedLiveRoomJson()).kicked, isFalse);
      await expectLater(
        live.mediaToken('r1'),
        throwsA(
          isA<ServerFailure>().having(
            (f) => f.code,
            'code',
            ErrorCode.liveKicked,
          ),
        ),
      );
    });

    test('a bad cursor maps to VALIDATION_FAILED on field "cursor"', () async {
      http.on(
        'GET',
        '$_base/live/rooms',
        (_) => FakeResponse(
          400,
          body: errorEnvelope(
            'VALIDATION_FAILED',
            'bad cursor',
            details: [
              {'field': 'cursor', 'issue': 'invalid_value'},
            ],
          ),
        ),
      );
      await expectLater(
        live.listRooms(tab: LiveRoomsTab.popular, cursor: 'x'),
        throwsA(
          isA<ServerFailure>()
              .having((f) => f.code, 'code', ErrorCode.validationFailed)
              .having((f) => f.details, 'details', [
                const FieldIssue(field: 'cursor', issue: 'invalid_value'),
              ]),
        ),
      );
    });

    test('429 carries Retry-After; 5xx and bad bodies are failures', () async {
      http.on(
        'GET',
        '$_base/live/rooms',
        (_) => FakeResponse(
          429,
          body: errorEnvelope('RATE_LIMITED', 'slow down'),
          headers: {
            'retry-after': ['30'],
          },
        ),
      );
      await expectLater(
        live.listRooms(tab: LiveRoomsTab.popular),
        throwsA(
          isA<ServerFailure>()
              .having((f) => f.code, 'code', ErrorCode.rateLimited)
              .having(
                (f) => f.retryAfter,
                'retryAfter',
                const Duration(seconds: 30),
              ),
        ),
      );
      http.on(
        'GET',
        '$_base/live/config',
        (_) => const FakeResponse(502, body: 'Bad gateway'),
      );
      await expectLater(
        live.getConfig(),
        throwsA(
          isA<ServerFailure>().having(
            (f) => f.code,
            'code',
            ErrorCode.internalError,
          ),
        ),
      );
      http.on(
        'GET',
        '$_base/live/categories',
        (_) => const FakeResponse(200, body: {'unexpected': true}),
      );
      await expectLater(
        live.listCategories(),
        throwsA(isA<UnexpectedFailure>()),
      );
    });

    for (final (code, status) in const [
      ('LIVE_HOSTING_UNAVAILABLE', 503),
      ('LIVE_ROOM_ALREADY_ACTIVE', 409),
      ('LIVE_ROOM_ENDED', 409),
    ]) {
      test('maps the v1.3 code $code', () async {
        http.on(
          'GET',
          '$_base/live/rooms/r1',
          (_) => FakeResponse(status, body: errorEnvelope(code, 'dev text')),
        );
        await expectLater(
          live.getRoom('r1'),
          throwsA(
            isA<ServerFailure>().having(
              (f) => f.code,
              'code',
              ErrorCode.fromWire(code),
            ),
          ),
        );
        expect(ErrorCode.fromWire(code), isNot(ErrorCode.unknown));
      });
    }
  });

  group('ProfileRepository', () {
    test('getProfile: the otherUserLive example, username encoded', () async {
      http.on(
        'GET',
        '$_base/users/layla.k',
        (_) => FakeResponse(200, body: publicProfileJson()),
      );
      final profile = await profiles.getProfile('layla.k');
      expect(profile.username, 'layla.k');
      expect(profile.displayName, 'ليلى');
      expect(profile.followerCount, 12);
      expect(profile.followingCount, 40);
      expect(profile.isFollowing, isTrue);
      expect(profile.isSelf, isFalse);
      expect(profile.isPrivate, isFalse);
      expect(profile.liveRoomId, '0192f1d0-1111-7aaa-8bbb-0c0d0e0f1011');
      expect(profile.canFollow, isTrue);
    });

    test('getProfile: 404 NOT_FOUND', () async {
      await expectLater(
        profiles.getProfile('nobody'),
        throwsA(
          isA<ServerFailure>().having(
            (f) => f.code,
            'code',
            ErrorCode.notFound,
          ),
        ),
      );
    });

    test('follow: PUT, unfollow: DELETE, both return FollowState', () async {
      http
        ..on(
          'PUT',
          '$_base/users/layla.k/follow',
          (_) => const FakeResponse(
            200,
            body: {'isFollowing': true, 'followerCount': 13},
          ),
        )
        ..on(
          'DELETE',
          '$_base/users/layla.k/follow',
          (_) => const FakeResponse(
            200,
            body: {'isFollowing': false, 'followerCount': 12},
          ),
        );
      final followed = await profiles.follow('layla.k');
      expect(followed.isFollowing, isTrue);
      expect(followed.followerCount, 13);
      final unfollowed = await profiles.unfollow('layla.k');
      expect(unfollowed.isFollowing, isFalse);
      expect(unfollowed.followerCount, 12);
      expect(http.requests.map((r) => r.headers['Authorization']).toSet(), {
        'Bearer acc',
      });
    });

    test('canFollow: never for yourself or a new follow of a private user', () {
      expect(_profile(isSelf: true).canFollow, isFalse);
      expect(_profile(isPrivate: true).canFollow, isFalse);
      expect(_profile(isPrivate: true, isFollowing: true).canFollow, isTrue);
      expect(_profile().canFollow, isTrue);
    });
  });
}

PublicProfile _profile({
  bool isSelf = false,
  bool isPrivate = false,
  bool isFollowing = false,
}) => PublicProfile.fromJson(
  publicProfileJson(
    isSelf: isSelf,
    isPrivate: isPrivate,
    isFollowing: isFollowing,
  ),
);
