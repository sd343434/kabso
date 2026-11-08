import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/network/api_call.dart';
import 'package:kabso_live/core/network/network_providers.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/owner_profile/domain/owner_models.dart';
import 'package:kabso_live/features/posts/data/media_repository.dart'
    show storageDioProvider;
import 'package:kabso_live/features/posts/domain/post_models.dart';
import 'package:kabso_live/features/profile/application/profile_grid_provider.dart';
import 'package:kabso_live/features/recharge/data/recharge_repository.dart'
    show uploadPrivateImage;

/// v1.95-social (D301, CONVENTIONS §10.112): the app owner's profile
/// «صفحة صاحب البرنامج». Every method throws an `AppFailure`; the owner-only
/// ones fail with `OWNER_ONLY` for anyone else.
abstract interface class OwnerProfileRepository {
  /// `GET /users/{username}/journey` — «رحلة Kabso» in order.
  Future<List<JourneyMilestone>> journey(String username);

  /// `POST /owner/journey` (owner).
  Future<JourneyMilestone> createMilestone(JourneyMilestone draft);

  /// `PATCH /owner/journey/{id}` with every field (owner).
  Future<JourneyMilestone> updateMilestone(JourneyMilestone milestone);

  /// `DELETE /owner/journey/{id}` (owner).
  Future<void> deleteMilestone(String id);

  /// `PUT /owner/journey/order` (owner): exactly the owner's ids.
  Future<List<JourneyMilestone>> reorder(List<String> ids);

  /// `GET /users/{username}/official-posts` — pinned first, then newest.
  Future<PageOf<Post>> officialPosts(
    String username, {
    String? cursor,
    int? limit,
  });

  /// `PUT` / `DELETE /posts/{id}/official` (owner, own post).
  Future<Post> setOfficial(String postId, {required bool official});

  /// `POST /owner/announcements` (owner, D301 follow-up): a bilingual
  /// official announcement with the same pictures; published at once.
  Future<Post> createAnnouncement({
    required String idempotencyKey,
    required String textAr,
    required String textEn,
    List<String> mediaIds = const [],
  });

  /// `PATCH /owner/announcements/{id}` (owner): either caption; no new
  /// notification.
  Future<Post> updateAnnouncement(
    String postId, {
    required String textAr,
    required String textEn,
  });

  /// `GET /owner/dashboard` (owner) — «لوحة المؤسس».
  Future<OwnerDashboard> dashboard();

  /// `GET /owner/profit?day=` (owner, §10.112.10) — «الربح» of the day
  /// (`YYYY-MM-DD`, default today) and its month.
  Future<OwnerProfit> profit({String? day});

  /// `/owner/fixed-costs` (owner): the fixed monthly costs «تكاليف ثابتة».
  Future<List<OwnerFixedCost>> fixedCosts();
  Future<OwnerFixedCost> createFixedCost({
    required String name,
    required int monthlyMinor,
    required String activeFrom,
    String? activeTo,
  });
  Future<OwnerFixedCost> updateFixedCost(
    String id, {
    required String name,
    required int monthlyMinor,
    required String activeFrom,
    String? activeTo,
  });
  Future<void> deleteFixedCost(String id);

  /// `GET /search/featured` (§10.112.9): the founder pinned in search, or
  /// null (no ACTIVE owner, or a block either way).
  Future<FeaturedFounder?> searchFeatured();

  /// `PUT` / `DELETE /me/cover-video/{lang}` (owner).
  Future<OwnerCoverVideo> setCoverVideo(String lang, String mediaId);
  Future<OwnerCoverVideo> removeCoverVideo(String lang);

  /// `GET /owner/feedback/staff?q=` — the Kabso Team accounts.
  Future<List<FeedbackStaff>> searchStaff(String query);

  /// A pending private `OWNER_FEEDBACK_IMAGE` upload; returns its id.
  Future<String> uploadFeedbackImage(Uint8List bytes, String contentType);

  /// `POST /owner/feedback`.
  Future<void> sendFeedback({
    required FeedbackKind kind,
    required String text,
    List<String> imageUploadIds = const [],
    String? staffUserId,
    FeedbackCategory? category,
  });
}

class OwnerProfileRepositoryImpl implements OwnerProfileRepository {
  new(this._dio, this._storage);

  final Dio _dio;
  final Dio _storage;

  List<JourneyMilestone> _list(Map<String, dynamic> body) => [
    for (final m in body['data']! as List<dynamic>)
      JourneyMilestone.fromJson(m as Map<String, dynamic>),
  ];

  @override
  Future<List<JourneyMilestone>> journey(String username) =>
      guardApiCall(() async {
        final res = await _dio.get<Map<String, dynamic>>(
          '/users/${pathSegment(username)}/journey',
        );
        return _list(res.data!);
      });

  @override
  Future<JourneyMilestone> createMilestone(JourneyMilestone draft) =>
      guardApiCall(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          '/owner/journey',
          data: draft.toBody(),
        );
        return JourneyMilestone.fromJson(res.data!);
      });

  @override
  Future<JourneyMilestone> updateMilestone(JourneyMilestone milestone) =>
      guardApiCall(() async {
        final res = await _dio.patch<Map<String, dynamic>>(
          '/owner/journey/${pathSegment(milestone.id)}',
          data: milestone.toBody(),
        );
        return JourneyMilestone.fromJson(res.data!);
      });

  @override
  Future<void> deleteMilestone(String id) => guardApiCall(() async {
    await _dio.delete<void>('/owner/journey/${pathSegment(id)}');
  });

  @override
  Future<List<JourneyMilestone>> reorder(List<String> ids) =>
      guardApiCall(() async {
        final res = await _dio.put<Map<String, dynamic>>(
          '/owner/journey/order',
          data: {'ids': ids},
        );
        return _list(res.data!);
      });

  @override
  Future<PageOf<Post>> officialPosts(
    String username, {
    String? cursor,
    int? limit,
  }) => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/users/${pathSegment(username)}/official-posts',
      queryParameters: {'cursor': ?cursor, 'limit': ?limit},
    );
    final body = res.data!;
    return PageOf([
      for (final p in body['data']! as List<dynamic>)
        Post.fromJson(p as Map<String, dynamic>),
    ], PageInfo.fromJson(body['page']! as Map<String, dynamic>));
  });

  @override
  Future<Post> setOfficial(String postId, {required bool official}) =>
      guardApiCall(() async {
        final path = '/posts/${pathSegment(postId)}/official';
        final res = official
            ? await _dio.put<Map<String, dynamic>>(path)
            : await _dio.delete<Map<String, dynamic>>(path);
        return Post.fromJson(res.data!);
      });

  @override
  Future<Post> createAnnouncement({
    required String idempotencyKey,
    required String textAr,
    required String textEn,
    List<String> mediaIds = const [],
  }) => guardApiCall(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/owner/announcements',
      data: {
        'textAr': textAr,
        'textEn': textEn,
        if (mediaIds.isNotEmpty) 'mediaIds': mediaIds,
      },
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
    return Post.fromJson(res.data!);
  });

  @override
  Future<Post> updateAnnouncement(
    String postId, {
    required String textAr,
    required String textEn,
  }) => guardApiCall(() async {
    final res = await _dio.patch<Map<String, dynamic>>(
      '/owner/announcements/${pathSegment(postId)}',
      data: {'textAr': textAr, 'textEn': textEn},
    );
    return Post.fromJson(res.data!);
  });

  @override
  Future<FeaturedFounder?> searchFeatured() => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>('/search/featured');
    return FeaturedFounder.fromSearchFeatured(res.data!);
  });

  @override
  Future<OwnerDashboard> dashboard() => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>('/owner/dashboard');
    return OwnerDashboard.fromJson(res.data!);
  });

  @override
  Future<OwnerProfit> profit({String? day}) => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/owner/profit',
      queryParameters: {'day': ?day},
    );
    return OwnerProfit.fromJson(res.data!);
  });

  @override
  Future<List<OwnerFixedCost>> fixedCosts() => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>('/owner/fixed-costs');
    return [
      for (final c in res.data!['items']! as List<dynamic>)
        OwnerFixedCost.fromJson(c as Map<String, dynamic>),
    ];
  });

  Map<String, Object?> _cost(
    String name,
    int monthlyMinor,
    String activeFrom,
    String? activeTo,
  ) => {
    'name': name,
    'monthlyMinor': monthlyMinor,
    'activeFrom': activeFrom,
    'activeTo': activeTo,
  };

  @override
  Future<OwnerFixedCost> createFixedCost({
    required String name,
    required int monthlyMinor,
    required String activeFrom,
    String? activeTo,
  }) => guardApiCall(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/owner/fixed-costs',
      data: _cost(name, monthlyMinor, activeFrom, activeTo),
    );
    return OwnerFixedCost.fromJson(res.data!);
  });

  @override
  Future<OwnerFixedCost> updateFixedCost(
    String id, {
    required String name,
    required int monthlyMinor,
    required String activeFrom,
    String? activeTo,
  }) => guardApiCall(() async {
    final res = await _dio.patch<Map<String, dynamic>>(
      '/owner/fixed-costs/${pathSegment(id)}',
      data: _cost(name, monthlyMinor, activeFrom, activeTo),
    );
    return OwnerFixedCost.fromJson(res.data!);
  });

  @override
  Future<void> deleteFixedCost(String id) => guardApiCall(() async {
    await _dio.delete<void>('/owner/fixed-costs/${pathSegment(id)}');
  });

  @override
  Future<OwnerCoverVideo> setCoverVideo(String lang, String mediaId) =>
      guardApiCall(() async {
        final res = await _dio.put<Map<String, dynamic>>(
          '/me/cover-video/${pathSegment(lang)}',
          data: {'mediaId': mediaId},
        );
        return OwnerCoverVideo.fromJson(res.data!);
      });

  @override
  Future<OwnerCoverVideo> removeCoverVideo(String lang) =>
      guardApiCall(() async {
        final res = await _dio.delete<Map<String, dynamic>>(
          '/me/cover-video/${pathSegment(lang)}',
        );
        return OwnerCoverVideo.fromJson(res.data!);
      });

  @override
  Future<List<FeedbackStaff>> searchStaff(String query) =>
      guardApiCall(() async {
        final res = await _dio.get<Map<String, dynamic>>(
          '/owner/feedback/staff',
          queryParameters: {if (query.trim().isNotEmpty) 'q': query.trim()},
        );
        return [
          for (final s in res.data!['data']! as List<dynamic>)
            FeedbackStaff.fromJson(s as Map<String, dynamic>),
        ];
      });

  @override
  Future<String> uploadFeedbackImage(Uint8List bytes, String contentType) =>
      guardApiCall(
        () => uploadPrivateImage(
          _dio,
          _storage,
          bytes,
          contentType,
          'OWNER_FEEDBACK_IMAGE',
        ),
      );

  @override
  Future<void> sendFeedback({
    required FeedbackKind kind,
    required String text,
    List<String> imageUploadIds = const [],
    String? staffUserId,
    FeedbackCategory? category,
  }) => guardApiCall(() async {
    await _dio.post<Map<String, dynamic>>(
      '/owner/feedback',
      data: {
        'kind': kind.wire,
        'text': text,
        if (imageUploadIds.isNotEmpty) 'imageUploadIds': imageUploadIds,
        'staffUserId': ?staffUserId,
        'category': ?category?.wire,
      },
    );
  });
}

final ownerProfileRepositoryProvider = Provider<OwnerProfileRepository>(
  (ref) => OwnerProfileRepositoryImpl(
    ref.watch(apiDioProvider),
    ref.watch(storageDioProvider),
  ),
);

/// «رحلة Kabso» of the username, in order.
final FutureProviderFamily<List<JourneyMilestone>, String>
ownerJourneyProvider = FutureProvider.autoDispose.family(
  (ref, username) =>
      ref.watch(ownerProfileRepositoryProvider).journey(username),
);

/// The first official announcements of the username (the profile card).
final FutureProviderFamily<List<Post>, String> ownerOfficialPostsProvider =
    FutureProvider.autoDispose.family(
      (ref, username) async =>
          (await ref
                  .watch(ownerProfileRepositoryProvider)
                  .officialPosts(username, limit: 3))
              .items,
    );

/// «لوحة المؤسس» (the owner's own profile only).
final FutureProvider<OwnerDashboard> ownerDashboardProvider =
    FutureProvider.autoDispose<OwnerDashboard>(
      (ref) => ref.watch(ownerProfileRepositoryProvider).dashboard(),
    );

/// «الربح» (§10.112.10) of a day (null: today) and its month.
final FutureProviderFamily<OwnerProfit, String?> ownerProfitProvider =
    FutureProvider.autoDispose.family(
      (ref, day) => ref.watch(ownerProfileRepositoryProvider).profit(day: day),
    );

/// The owner's fixed monthly costs «تكاليف ثابتة».
final FutureProvider<List<OwnerFixedCost>> ownerFixedCostsProvider =
    FutureProvider.autoDispose<List<OwnerFixedCost>>(
      (ref) => ref.watch(ownerProfileRepositoryProvider).fixedCosts(),
    );

/// §10.112.9: the founder pinned at the top of search (null: none to show).
final FutureProvider<FeaturedFounder?> searchFeaturedProvider =
    FutureProvider.autoDispose<FeaturedFounder?>(
      (ref) => ref.watch(ownerProfileRepositoryProvider).searchFeatured(),
    );

/// Whether the signed-in account is the app owner (from its own public
/// profile, `PublicProfile.kabsoOwner`); false while unknown.
final Provider<bool> isKabsoOwnerProvider = Provider.autoDispose<bool>((ref) {
  final username = ref.watch(currentUserProvider)?.username;
  if (username == null || username.isEmpty) return false;
  return ref.watch(profileStatsProvider(username)).value?.kabsoOwner ?? false;
});
