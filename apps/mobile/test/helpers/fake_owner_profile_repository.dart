import 'dart:typed_data';

import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/features/owner_profile/data/owner_profile_repository.dart';
import 'package:kabso_live/features/owner_profile/domain/owner_models.dart';
import 'package:kabso_live/features/posts/domain/post_models.dart';

import 'fake_posts_repository.dart' show postJson;

/// D301: «صفحة صاحب البرنامج» without a server — keeps the journey, the
/// official posts and every call for assertions.
class FakeOwnerProfileRepository implements OwnerProfileRepository {
  new({
    List<JourneyMilestone> journey = const [],
    this.official = const [],
    this.dashboardData,
    this.staff = const [],
    this.dashboardFails = false,
    this.featured,
    this.profitData,
    List<OwnerFixedCost> costs = const [],
  }) : journeyItems = [...journey],
       costItems = [...costs];

  /// §10.112.10: what `GET /owner/profit` answers (null: it fails).
  OwnerProfit? profitData;

  /// The days `profit` was asked for (null: today).
  final List<String?> profitDays = [];

  /// The fixed costs, changed by the create / update / delete calls.
  List<OwnerFixedCost> costItems;

  @override
  Future<OwnerProfit> profit({String? day}) async {
    profitDays.add(day);
    final p = profitData;
    if (p == null) throw const NetworkFailure.offline();
    return p;
  }

  @override
  Future<List<OwnerFixedCost>> fixedCosts() async => [...costItems];

  @override
  Future<OwnerFixedCost> createFixedCost({
    required String name,
    required int monthlyMinor,
    required String activeFrom,
    String? activeTo,
  }) async {
    calls.add('cost:create:$name:$monthlyMinor:$activeFrom:${activeTo ?? ''}');
    final c = OwnerFixedCost(
      id: 'c${_nextId++}',
      name: name,
      monthlyMinor: monthlyMinor,
      activeFrom: activeFrom,
      activeTo: activeTo,
    );
    costItems = [...costItems, c];
    return c;
  }

  @override
  Future<OwnerFixedCost> updateFixedCost(
    String id, {
    required String name,
    required int monthlyMinor,
    required String activeFrom,
    String? activeTo,
  }) async {
    calls.add('cost:update:$id:$name:$monthlyMinor');
    final c = OwnerFixedCost(
      id: id,
      name: name,
      monthlyMinor: monthlyMinor,
      activeFrom: activeFrom,
      activeTo: activeTo,
    );
    costItems = [
      for (final x in costItems)
        if (x.id == id) c else x,
    ];
    return c;
  }

  @override
  Future<void> deleteFixedCost(String id) async {
    calls.add('cost:delete:$id');
    costItems = [
      for (final x in costItems)
        if (x.id != id) x,
    ];
  }

  /// §10.112.9: the founder `GET /search/featured` answers.
  FeaturedFounder? featured;

  @override
  Future<FeaturedFounder?> searchFeatured() async => featured;

  List<JourneyMilestone> journeyItems;
  List<Post> official;
  OwnerDashboard? dashboardData;
  bool dashboardFails;
  final List<FeedbackStaff> staff;

  final List<String> calls = [];
  final List<Map<String, Object?>> feedback = [];
  final List<String> staffQueries = [];
  int dashboardReads = 0;
  int _nextId = 100;

  @override
  Future<List<JourneyMilestone>> journey(String username) async {
    calls.add('journey:$username');
    return [...journeyItems];
  }

  @override
  Future<JourneyMilestone> createMilestone(JourneyMilestone draft) async {
    calls.add('create:${draft.titleAr}');
    final m = JourneyMilestone(
      id: 'n${_nextId++}',
      titleAr: draft.titleAr,
      titleEn: draft.titleEn,
      lineAr: draft.lineAr,
      lineEn: draft.lineEn,
      year: draft.year,
      month: draft.month,
      icon: draft.icon,
      latest: draft.latest,
      position: journeyItems.length,
    );
    journeyItems = [
      for (final x in journeyItems)
        if (draft.latest) _with(x, latest: false) else x,
      m,
    ];
    return m;
  }

  JourneyMilestone _with(JourneyMilestone m, {bool? latest, int? position}) =>
      JourneyMilestone(
        id: m.id,
        titleAr: m.titleAr,
        titleEn: m.titleEn,
        lineAr: m.lineAr,
        lineEn: m.lineEn,
        year: m.year,
        month: m.month,
        icon: m.icon,
        latest: latest ?? m.latest,
        position: position ?? m.position,
      );

  @override
  Future<JourneyMilestone> updateMilestone(JourneyMilestone milestone) async {
    calls.add('update:${milestone.id}');
    journeyItems = [
      for (final x in journeyItems)
        if (x.id == milestone.id)
          _with(milestone, position: x.position)
        else if (milestone.latest)
          _with(x, latest: false)
        else
          x,
    ];
    return journeyItems.firstWhere((x) => x.id == milestone.id);
  }

  @override
  Future<void> deleteMilestone(String id) async {
    calls.add('delete:$id');
    journeyItems = [
      for (final (i, x) in journeyItems.where((x) => x.id != id).indexed)
        _with(x, position: i),
    ];
  }

  @override
  Future<List<JourneyMilestone>> reorder(List<String> ids) async {
    calls.add('reorder:${ids.join(',')}');
    final byId = {for (final x in journeyItems) x.id: x};
    journeyItems = [
      for (final (i, id) in ids.indexed) _with(byId[id]!, position: i),
    ];
    return [...journeyItems];
  }

  @override
  Future<PageOf<Post>> officialPosts(
    String username, {
    String? cursor,
    int? limit,
  }) async {
    calls.add('official:$username:${limit ?? ''}');
    final items = limit == null ? official : official.take(limit).toList();
    return PageOf(items, const PageInfo(nextCursor: null, hasMore: false));
  }

  @override
  Future<Post> setOfficial(String postId, {required bool official}) async {
    calls.add('official:$postId:$official');
    if (!postId.startsWith('p')) {
      throw const ServerFailure(
        code: ErrorCode.notFound,
        rawCode: 'NOT_FOUND',
        debugMessage: 'not found',
        statusCode: 404,
      );
    }
    return Post.fromJson({...postJson(postId), 'official': official});
  }

  final List<Map<String, Object?>> announcements = [];

  @override
  Future<Post> createAnnouncement({
    required String idempotencyKey,
    required String textAr,
    required String textEn,
    List<String> mediaIds = const [],
  }) async {
    announcements.add({
      'key': idempotencyKey,
      'ar': textAr,
      'en': textEn,
      'media': mediaIds,
    });
    final post = Post.fromJson({
      ...postJson('pa${announcements.length}', text: textAr),
      'official': true,
      'texts': {'ar': textAr, 'en': textEn},
    });
    official = [post, ...official];
    return post;
  }

  @override
  Future<Post> updateAnnouncement(
    String postId, {
    required String textAr,
    required String textEn,
  }) async {
    calls.add('updateAnnouncement:$postId');
    announcements.add({'edit': postId, 'ar': textAr, 'en': textEn});
    return Post.fromJson({
      ...postJson(postId, text: textAr),
      'official': true,
      'texts': {'ar': textAr, 'en': textEn},
    });
  }

  @override
  Future<OwnerDashboard> dashboard() async {
    dashboardReads++;
    if (dashboardFails) {
      throw const ServerFailure(
        code: ErrorCode.ownerOnly,
        rawCode: 'OWNER_ONLY',
        debugMessage: 'owner only',
        statusCode: 403,
      );
    }
    return dashboardData!;
  }

  @override
  Future<OwnerCoverVideo> setCoverVideo(String lang, String mediaId) async {
    calls.add('setVideo:$lang:$mediaId');
    return const OwnerCoverVideo();
  }

  @override
  Future<OwnerCoverVideo> removeCoverVideo(String lang) async {
    calls.add('removeVideo:$lang');
    return const OwnerCoverVideo();
  }

  @override
  Future<List<FeedbackStaff>> searchStaff(String query) async {
    staffQueries.add(query);
    final q = query.toLowerCase().replaceFirst('@', '');
    return [
      for (final s in staff)
        if (q.isEmpty ||
            s.username.contains(q) ||
            (s.staffId ?? '').toLowerCase() == q)
          s,
    ];
  }

  @override
  Future<String> uploadFeedbackImage(
    Uint8List bytes,
    String contentType,
  ) async {
    calls.add('image:$contentType');
    return 'upload-${_nextId++}';
  }

  @override
  Future<void> sendFeedback({
    required FeedbackKind kind,
    required String text,
    List<String> imageUploadIds = const [],
    String? staffUserId,
    FeedbackCategory? category,
  }) async {
    feedback.add({
      'kind': kind.wire,
      'text': text,
      'images': imageUploadIds,
      'staff': staffUserId,
      'category': category?.wire,
    });
  }
}
