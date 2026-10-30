// KL-038: public profile + optimistic follow / unfollow with rollback
// (CONVENTIONS §10.5–10.6).

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/features/profile/application/public_profile_controller.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:kabso_live/features/profile/domain/profile_models.dart';

import '../../fixtures/live/live_api_fixtures.dart';

class _FakeProfiles implements ProfileRepository {
  new(this.profile);

  PublicProfile profile;
  Completer<void>? gate;
  AppFailure? failure;
  final List<String> calls = [];

  @override
  Future<PublicProfile> getProfile(String username) async {
    calls.add('GET $username');
    return profile;
  }

  Future<FollowState> _edge(String verb, String username, bool to) async {
    calls.add('$verb $username');
    await gate?.future;
    if (failure case final f?) throw f;
    // D175: a private account answers a new follow with a request.
    if (to && profile.isPrivate && !profile.isFollowing) {
      profile = profile.copyWith(followRequested: true);
      return FollowState(
        isFollowing: false,
        isRequested: true,
        followerCount: profile.followerCount,
      );
    }
    if (!to && profile.followRequested) {
      profile = profile.copyWith(followRequested: false);
      return FollowState(
        isFollowing: false,
        followerCount: profile.followerCount,
      );
    }
    final was = profile.isFollowing;
    final count = profile.followerCount + (to == was ? 0 : (to ? 1 : -1));
    profile = profile.copyWith(isFollowing: to, followerCount: count);
    return FollowState(isFollowing: to, followerCount: count);
  }

  @override
  Future<FollowState> follow(String username) => _edge('PUT', username, true);

  @override
  Future<FollowState> unfollow(String username) =>
      _edge('DELETE', username, false);
}

PublicProfile _profile({
  bool isFollowing = false,
  int followerCount = 12,
  bool isSelf = false,
  bool isPrivate = false,
}) => PublicProfile.fromJson(
  publicProfileJson(
    isFollowing: isFollowing,
    followerCount: followerCount,
    isSelf: isSelf,
    isPrivate: isPrivate,
  ),
);

void main() {
  late _FakeProfiles repo;
  late ProviderContainer container;
  final provider = publicProfileProvider('layla.k');

  Future<void> start(PublicProfile profile) async {
    repo = _FakeProfiles(profile);
    container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [profileRepositoryProvider.overrideWithValue(repo)],
    )..listen(provider, (_, _) {});
    await container.read(provider.future);
  }

  PublicProfile current() => container.read(provider).requireValue;

  test('loads GET /users/{username}', () async {
    await start(_profile());
    expect(repo.calls, ['GET layla.k']);
    expect(current().displayName, 'ليلى');
  });

  test('follow is optimistic, then takes the server count', () async {
    await start(_profile());
    repo.gate = Completer<void>();
    final pending = container
        .read(provider.notifier)
        .setFollowing(follow: true);
    // Immediately: following, count + 1.
    expect(current().isFollowing, isTrue);
    expect(current().followerCount, 13);
    expect(container.read(provider.notifier).isBusy, isTrue);
    // The server says another follower arrived meanwhile.
    repo.profile = repo.profile.copyWith(followerCount: 20);
    repo.gate!.complete();
    await pending;
    expect(repo.calls.last, 'PUT layla.k');
    expect(current().isFollowing, isTrue);
    expect(current().followerCount, 21);
    expect(container.read(provider.notifier).isBusy, isFalse);
  });

  test('unfollow is optimistic too', () async {
    await start(_profile(isFollowing: true));
    final pending = container
        .read(provider.notifier)
        .setFollowing(follow: false);
    expect(current().isFollowing, isFalse);
    expect(current().followerCount, 11);
    await pending;
    expect(repo.calls.last, 'DELETE layla.k');
    expect(current().followerCount, 11);
  });

  test('a failure rolls back and rethrows', () async {
    await start(_profile());
    repo
      ..gate = Completer<void>()
      ..failure = const ServerFailure(
        code: ErrorCode.rateLimited,
        rawCode: 'RATE_LIMITED',
        debugMessage: 'x',
      );
    final pending = container
        .read(provider.notifier)
        .setFollowing(follow: true);
    expect(current().isFollowing, isTrue);
    repo.gate!.complete();
    await expectLater(pending, throwsA(isA<ServerFailure>()));
    expect(current().isFollowing, isFalse);
    expect(current().followerCount, 12);
    expect(container.read(provider.notifier).isBusy, isFalse);
  });

  test('ignored while a toggle is in flight or nothing changes', () async {
    await start(_profile());
    repo.gate = Completer<void>();
    final notifier = container.read(provider.notifier);
    final first = notifier.setFollowing(follow: true);
    await notifier.setFollowing(follow: false);
    repo.gate!.complete();
    await first;
    expect(repo.calls.where((c) => c != 'GET layla.k'), ['PUT layla.k']);
    await notifier.setFollowing(follow: true);
    expect(repo.calls.where((c) => c != 'GET layla.k'), ['PUT layla.k']);
  });

  // D175: a private account gets a follow request (until v1.47-social the
  // controller refused to follow one: no requests existed).
  test('never follows yourself; a private account gets a request (the count '
      'does not move) that can be cancelled', () async {
    await start(_profile(isSelf: true));
    await container.read(provider.notifier).setFollowing(follow: true);
    expect(repo.calls, ['GET layla.k']);
    expect(current().isFollowing, isFalse);

    await start(_profile(isPrivate: true));
    final before = current().followerCount;
    await container.read(provider.notifier).setFollowing(follow: true);
    expect(repo.calls, ['GET layla.k', 'PUT layla.k']);
    expect(current().isFollowing, isFalse);
    expect(current().followRequested, isTrue);
    expect(current().followerCount, before);
    await container.read(provider.notifier).setFollowing(follow: false);
    expect(repo.calls.last, 'DELETE layla.k');
    expect(current().followRequested, isFalse);

    // An existing follower of a private account can unfollow.
    await start(_profile(isPrivate: true, isFollowing: true));
    await container.read(provider.notifier).setFollowing(follow: false);
    expect(repo.calls.last, 'DELETE layla.k');
    expect(current().isFollowing, isFalse);
  });
}
