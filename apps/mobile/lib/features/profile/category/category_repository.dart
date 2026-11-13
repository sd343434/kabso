import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;
import 'package:kabso_live/core/demo/demo_mode.dart';
import 'package:kabso_live/core/network/api_call.dart';
import 'package:kabso_live/core/network/network_providers.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/profile/category/category_models.dart';

/// D386 (v1.138-social, CONVENTIONS §10.175): the featured section, the
/// caller's featured pins and «طلب توثيق الفئة». Every method throws an
/// `AppFailure`.
abstract interface class CategoryProfileRepository {
  /// `GET /users/{username}/featured` (404 like the grid).
  Future<ProfileFeatured> featured(String username);

  /// `GET /me/featured-pins`.
  Future<FeaturedPinList> pins();

  /// `PUT /me/featured-pins {postIds}` — reorder, replace or clear.
  Future<FeaturedPinList> setPins(List<String> postIds);

  /// `PUT` / `DELETE /me/featured-pins/{postId}` (a 7th → 409
  /// `FEATURED_PIN_LIMIT`).
  Future<FeaturedPinList> setPinned(String postId, {required bool pinned});

  /// `GET /me/category-verification`.
  Future<CategoryVerification> verification();

  /// `POST /me/category-verification` (409
  /// `CATEGORY_VERIFICATION_PENDING` when one is open).
  Future<CategoryVerification> requestVerification();

  /// `DELETE /me/category-verification` (idempotent).
  Future<CategoryVerification> cancelVerification();
}

class ApiCategoryProfileRepository implements CategoryProfileRepository {
  new(this._dio);

  final Dio _dio;

  @override
  Future<ProfileFeatured> featured(String username) => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/users/${pathSegment(username)}/featured',
    );
    return ProfileFeatured.fromJson(res.data!);
  });

  @override
  Future<FeaturedPinList> pins() => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>('/me/featured-pins');
    return FeaturedPinList.fromJson(res.data!);
  });

  @override
  Future<FeaturedPinList> setPins(List<String> postIds) =>
      guardApiCall(() async {
        final res = await _dio.put<Map<String, dynamic>>(
          '/me/featured-pins',
          data: {'postIds': postIds},
        );
        return FeaturedPinList.fromJson(res.data!);
      });

  @override
  Future<FeaturedPinList> setPinned(String postId, {required bool pinned}) =>
      guardApiCall(() async {
        final path = '/me/featured-pins/${pathSegment(postId)}';
        final res = pinned
            ? await _dio.put<Map<String, dynamic>>(path)
            : await _dio.delete<Map<String, dynamic>>(path);
        return FeaturedPinList.fromJson(res.data!);
      });

  @override
  Future<CategoryVerification> verification() => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/me/category-verification',
    );
    return CategoryVerification.fromJson(res.data!);
  });

  @override
  Future<CategoryVerification> requestVerification() => guardApiCall(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/me/category-verification',
      data: const <String, dynamic>{},
    );
    return CategoryVerification.fromJson(res.data!);
  });

  @override
  Future<CategoryVerification> cancelVerification() => guardApiCall(() async {
    final res = await _dio.delete<Map<String, dynamic>>(
      '/me/category-verification',
    );
    return CategoryVerification.fromJson(res.data!);
  });
}

/// The demo account (D86) has no server: nothing featured, nothing pinned.
class _DemoCategoryProfileRepository implements CategoryProfileRepository {
  const new();

  @override
  Future<ProfileFeatured> featured(String username) async =>
      ProfileFeatured.empty;

  @override
  Future<FeaturedPinList> pins() async => const FeaturedPinList([]);

  @override
  Future<FeaturedPinList> setPins(List<String> postIds) async =>
      FeaturedPinList(postIds);

  @override
  Future<FeaturedPinList> setPinned(
    String postId, {
    required bool pinned,
  }) async => FeaturedPinList(pinned ? [postId] : const []);

  @override
  Future<CategoryVerification> verification() async =>
      const CategoryVerification();

  @override
  Future<CategoryVerification> requestVerification() async =>
      const CategoryVerification();

  @override
  Future<CategoryVerification> cancelVerification() async =>
      const CategoryVerification();
}

final categoryProfileRepositoryProvider = Provider<CategoryProfileRepository>((
  ref,
) {
  if (watchDemo(ref)) return const _DemoCategoryProfileRepository();
  return ApiCategoryProfileRepository(ref.watch(apiDioProvider));
});

/// The featured section of `username`'s page.
final FutureProviderFamily<ProfileFeatured, String> profileFeaturedProvider =
    FutureProvider.autoDispose.family(
      (ref, username) =>
          ref.watch(categoryProfileRepositoryProvider).featured(username),
    );

/// The caller's featured pins (the post menu's «تثبيت في …» reads it). A
/// failed read keeps the last list.
class FeaturedPinsController extends Notifier<FeaturedPinList> {
  @override
  FeaturedPinList build() {
    final signedIn = ref.watch(currentUserProvider.select((u) => u?.id));
    if (signedIn == null) return const FeaturedPinList([]);
    unawaited(_load());
    return const FeaturedPinList([]);
  }

  Future<void> _load() async {
    try {
      final next = await ref.read(categoryProfileRepositoryProvider).pins();
      if (ref.mounted) state = next;
    } on Object {
      // Keep the last list.
    }
  }

  /// Pins or unpins [postId]; throws the server's failure (409
  /// `FEATURED_PIN_LIMIT` for a 7th) and keeps the list.
  Future<void> setPinned(String postId, {required bool pinned}) async {
    final next = await ref
        .read(categoryProfileRepositoryProvider)
        .setPinned(postId, pinned: pinned);
    if (ref.mounted) state = next;
  }

  /// Saves a new order (or set) of pins.
  Future<void> setAll(List<String> postIds) async {
    final next = await ref
        .read(categoryProfileRepositoryProvider)
        .setPins(postIds);
    if (ref.mounted) state = next;
  }
}

final NotifierProvider<FeaturedPinsController, FeaturedPinList>
myFeaturedPinsProvider = NotifierProvider.autoDispose(
  FeaturedPinsController.new,
);

/// The caller's category verification and latest request (Edit profile).
final FutureProvider<CategoryVerification> myCategoryVerificationProvider =
    FutureProvider.autoDispose(
      (ref) => ref.watch(categoryProfileRepositoryProvider).verification(),
    );
