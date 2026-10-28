import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/home/presentation/widgets/feed_post_tile.dart';
import 'package:kabso_live/features/posts/application/posts_feed_controller.dart';
import 'package:kabso_live/features/posts/data/posts_repository.dart';
import 'package:kabso_live/features/posts/domain/post_models.dart';
import 'package:kabso_live/features/posts/presentation/comments_sheet.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// One post (`GET /posts/{postId}`).
final FutureProviderFamily<Post, String> postProvider = FutureProvider
    .autoDispose
    .family(
      (ref, postId) => ref.watch(postsRepositoryProvider).getPost(postId),
    );

/// `/posts/:postId` (KL-060): one post as in the feed — like, comments,
/// save and the "more" sheet — opened from a profile grid, search or a
/// hashtag. A post that is gone or not visible to the viewer (404) says so;
/// hiding or deleting it here goes back.
class PostScreen extends ConsumerStatefulWidget {
  const new({required this.postId, this.openComments = false, super.key});

  final String postId;

  /// Opens the comments sheet once the post has loaded (from a comment
  /// notification, CP-009).
  final bool openComments;

  static const unavailableKey = Key('post.unavailable');

  @override
  ConsumerState<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends ConsumerState<PostScreen> {
  bool _commentsOpened = false;

  String get postId => widget.postId;

  void _maybeOpenComments(Post post) {
    if (!widget.openComments || _commentsOpened) return;
    _commentsOpened = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final feed = feedPostOf(post);
      unawaited(
        showCommentsSheet(
          context,
          CommentsTarget(
            postId: post.id,
            commentCount: feed.comments ?? 0,
            authorId: feed.authorId,
            isSelf: feed.isSelf,
            commentsOpen: feed.commentsOpen,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    ref.listen(removedPostsProvider, (_, removed) {
      if (removed.contains(postId) && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });
    final post = ref.watch(postProvider(postId));
    final edited = ref.watch(postEditsProvider.select((e) => e[postId]));
    if (post case AsyncData(:final value)) _maybeOpenComments(value);
    return Scaffold(
      appBar: KAppBar(title: Text(l10n.postTitle)),
      body: switch (post) {
        AsyncData(:final value) => RefreshIndicator(
          onRefresh: () {
            ref.read(postEditsProvider.notifier).forget(postId);
            return ref.refresh(postProvider(postId).future);
          },
          child: ListView(
            padding: const EdgeInsets.only(bottom: KSpacing.xl),
            children: [FeedPostTile(post: feedPostOf(edited ?? value))],
          ),
        ),
        AsyncError(:final error) => switch (toAppFailure(error)) {
          ServerFailure(code: ErrorCode.notFound) => KEmptyState(
            key: PostScreen.unavailableKey,
            icon: Icons.visibility_off_outlined,
            title: l10n.postUnavailableTitle,
            message: l10n.postUnavailableBody,
          ),
          final failure => FailureErrorState(
            title: l10n.errorTitle,
            failure: failure,
            onRetry: () => ref.invalidate(postProvider(postId)),
          ),
        },
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}
