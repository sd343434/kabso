import 'package:kabso_live/features/profile/category/category_models.dart';
import 'package:kabso_live/features/profile/category/category_repository.dart';

/// D386: an in-memory `CategoryProfileRepository` — a fixed featured
/// section, the person's pins and their verification request.
class FakeCategoryProfileRepository implements CategoryProfileRepository {
  new({
    this.section = ProfileFeatured.empty,
    List<String> pins = const [],
    this.state = const CategoryVerification(),
  }) : pinned = [...pins];

  ProfileFeatured section;
  final List<String> pinned;
  CategoryVerification state;

  /// Calls, in order (`featured:<username>`, `pin:<id>`, `unpin:<id>`,
  /// `setPins:<ids>`, `request`, `cancel`).
  final List<String> calls = [];

  @override
  Future<ProfileFeatured> featured(String username) async {
    calls.add('featured:$username');
    return section;
  }

  @override
  Future<FeaturedPinList> pins() async => FeaturedPinList([...pinned]);

  @override
  Future<FeaturedPinList> setPins(List<String> postIds) async {
    calls.add('setPins:${postIds.join(',')}');
    pinned
      ..clear()
      ..addAll(postIds);
    return FeaturedPinList([...pinned]);
  }

  @override
  Future<FeaturedPinList> setPinned(
    String postId, {
    required bool pinned,
  }) async {
    calls.add('${pinned ? 'pin' : 'unpin'}:$postId');
    if (pinned && !this.pinned.contains(postId)) this.pinned.add(postId);
    if (!pinned) this.pinned.remove(postId);
    return FeaturedPinList([...this.pinned]);
  }

  @override
  Future<CategoryVerification> verification() async => state;

  @override
  Future<CategoryVerification> requestVerification() async {
    calls.add('request');
    return state = CategoryVerification(
      category: state.category,
      locked: state.locked,
      request: const CategoryRequest(
        id: 'req-1',
        status: CategoryRequestStatus.pending,
      ),
    );
  }

  @override
  Future<CategoryVerification> cancelVerification() async {
    calls.add('cancel');
    return state = CategoryVerification(
      category: state.category,
      locked: state.locked,
      request: const CategoryRequest(
        id: 'req-1',
        status: CategoryRequestStatus.cancelled,
      ),
    );
  }
}
