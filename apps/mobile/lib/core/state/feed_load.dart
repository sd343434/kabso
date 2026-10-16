import 'package:material_ui/material_ui.dart';

/// Primary segments shared by the Home feed and the Live hub (HL-H2, D36):
/// Following · Popular · New, in reading order. Popular is the default.
enum FeedTab {
  following,
  popular,
  latest;

  static const FeedTab initial = popular;
}

/// What a feed tab's data source returned.
///
/// [FeedUnavailable] is the honest state while the feature is not available
/// (no API yet, or switched off by the server, D35/D37): the screen shows its
/// structure and a compact unavailable state, never invented content.
/// Loading and failures are the surrounding `AsyncValue`'s loading and error
/// states.
@immutable
sealed class FeedLoad<T> {
  const new();
}

/// This tab's feature is not available yet.
final class FeedUnavailable<T> extends FeedLoad<T> {
  const new();
}

/// The items loaded so far; empty means "nothing right now".
///
/// Paginated sources (CONVENTIONS §5, HL-H5) also report the footer:
/// [hasMore] (another page exists), [loadingMore] (it is loading: footer
/// skeletons) and [loadMoreError] (it failed: inline footer error + retry).
/// With `hasMore == false` the list has ended.
final class FeedItems<T> extends FeedLoad<T> {
  const new(
    this.items, {
    this.hasMore = false,
    this.loadingMore = false,
    this.loadMoreError,
  });

  final List<T> items;
  final bool hasMore;
  final bool loadingMore;
  final Object? loadMoreError;
}
