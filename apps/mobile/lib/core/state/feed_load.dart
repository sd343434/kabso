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
/// [FeedUnavailable] is the honest production state while the backing API
/// does not exist (D35): the screen shows its structure and a compact
/// unavailable state, never invented content. Loading and failures are the
/// surrounding `AsyncValue`'s loading and error states.
@immutable
sealed class FeedLoad<T> {
  const new();
}

/// The API for this tab does not exist yet.
final class FeedUnavailable<T> extends FeedLoad<T> {
  const new();
}

/// A page of items; empty means "nothing right now".
final class FeedItems<T> extends FeedLoad<T> {
  const new(this.items);

  final List<T> items;
}
