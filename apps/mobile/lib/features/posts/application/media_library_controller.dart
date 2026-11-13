import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart'
    show AsyncNotifierProviderFamily, FutureProviderFamily;
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/posts/application/compose_controller.dart';
import 'package:kabso_live/features/posts/data/media_library.dart';
import 'package:material_ui/material_ui.dart';

/// The media step's view of the device library.
@immutable
class LibraryState {
  const new({
    required this.access,
    this.items = const [],
    this.done = false,
    this.loadingMore = false,
  });

  final LibraryAccess access;
  final List<LibraryItem> items;

  /// Every page has been read.
  final bool done;
  final bool loadingMore;

  LibraryState copyWith({
    List<LibraryItem>? items,
    bool? done,
    bool? loadingMore,
  }) => LibraryState(
    access: access,
    items: items ?? this.items,
    done: done ?? this.done,
    loadingMore: loadingMore ?? this.loadingMore,
  );
}

/// Asks for library access, then pages the items of [filter] in (newest
/// first; D162: photos, videos or both). A platform without a library, or a
/// refusal, is a state, not an error: the screen offers the system picker
/// instead.
class MediaLibraryController extends AsyncNotifier<LibraryState> {
  new(this.filter);

  final LibraryFilter filter;

  /// [MediaLibrary.page]'s default page size.
  static const pageSize = 60;
  int _page = 0;

  @override
  Future<LibraryState> build() async {
    _page = 0;
    final library = ref.watch(mediaLibraryProvider);
    final access = await library.requestAccess();
    if (!access.canBrowse) return LibraryState(access: access);
    final items = await library.page(0, filter: filter);
    return LibraryState(
      access: access,
      items: List.unmodifiable(items),
      done: items.length < pageSize,
    );
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || current.done || current.loadingMore) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final next = await ref
          .read(mediaLibraryProvider)
          .page(_page + 1, filter: filter);
      if (!ref.mounted) return;
      _page++;
      state = AsyncData(
        current.copyWith(
          items: List.unmodifiable([...current.items, ...next]),
          done: next.length < pageSize,
          loadingMore: false,
        ),
      );
    } on Object {
      if (!ref.mounted) return;
      state = AsyncData(current.copyWith(loadingMore: false));
    }
  }
}

final AsyncNotifierProviderFamily<
  MediaLibraryController,
  LibraryState,
  LibraryFilter
>
mediaLibraryControllerProvider = AsyncNotifierProvider.family(
  MediaLibraryController.new,
);

/// A library photo's grid thumbnail (kept while the screen shows it).
final FutureProviderFamily<Uint8List?, String> libraryThumbnailProvider =
    FutureProvider.autoDispose.family(
      (ref, id) => ref.watch(mediaLibraryProvider).thumbnail(id),
    );

/// The places this account used in its last posts on this device, newest
/// first. Kept per account so another account on the device never sees
/// them; they offer one tap to reuse a place (no place search API yet).
class RecentPlaces extends Notifier<List<String>> {
  static const max = 5;

  String? get _key {
    final id = ref.read(currentUserProvider)?.id;
    return id == null ? null : 'pref.recentPlaces.$id';
  }

  @override
  List<String> build() {
    ref.watch(currentUserProvider.select((u) => u?.id));
    final key = _key;
    if (key == null) return const [];
    return List.unmodifiable(
      ref.read(sharedPreferencesProvider).getStringList(key) ?? const [],
    );
  }

  Future<void> remember(String place) async {
    final key = _key;
    final value = place.trim();
    if (key == null || value.isEmpty) return;
    final next = [value, ...state.where((p) => p != value)].take(max).toList();
    state = List.unmodifiable(next);
    await ref.read(sharedPreferencesProvider).setStringList(key, next);
  }
}

final recentPlacesProvider = NotifierProvider<RecentPlaces, List<String>>(
  RecentPlaces.new,
);

/// Whether [photos] already holds the library photo [id], and where.
int librarySelectionIndex(List<ComposePhoto> photos, String id) =>
    photos.indexWhere((p) => p.sourceId == id);
