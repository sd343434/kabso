import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/features/home/presentation/widgets/feed_post_tile.dart';

/// Home feed items for one tab.
///
/// There is no feed API yet (following Phase 2, posts Phase 3, short video
/// Phase 5) and contracts are frozen for the design sprint (D34/D35), so
/// production returns [FeedUnavailable] for every tab — never sample posts.
/// Tests and the debug gallery supply fixtures by overriding this provider
/// (or by rendering `HomeFeedBody` directly).
final FutureProviderFamily<FeedLoad<FeedPostData>, FeedTab> homeFeedProvider =
    FutureProvider.family((ref, tab) => const FeedUnavailable<FeedPostData>());
