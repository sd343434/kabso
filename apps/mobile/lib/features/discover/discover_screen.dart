import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/core/icons/app_icons.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/discover/search_home.dart';
import 'package:kabso_live/features/posts/application/search_controller.dart';
import 'package:kabso_live/features/posts/data/posts_repository.dart';
import 'package:kabso_live/features/posts/domain/post_models.dart';
import 'package:kabso_live/features/profile/application/profile_grid_provider.dart';
import 'package:kabso_live/features/profile/profile_screen.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Search (D86: opened from the search buttons) on `GET /search`
/// (CONVENTIONS §11.6): one field and three kinds — accounts (open the
/// profile), hashtags (open the hashtag page) and posts (a grid; a cell
/// opens the post). Prefix match, case-insensitive; a leading `@` or `#`
/// is ignored. Results follow the typing after a short pause and page in
/// as the list scrolls.
///
/// D147 (owner's layout reference): a header of the field and Cancel, and
/// under an empty field the [SearchHome] (hot searches, hot hashtags, lives)
/// with the hint rotating through the trending terms. A submitted search,
/// or one whose result is opened, is counted for trends (§11.11).
class DiscoverScreen extends ConsumerStatefulWidget {
  const new({super.key});

  static const fieldKey = Key('search.field');
  static const clearKey = Key('search.clear');
  static const cancelKey = Key('search.cancel');
  static const promptKey = Key('search.prompt');
  static const emptyKey = Key('search.empty');
  static const resultsKey = Key('search.results');
  static Key typeKey(SearchType t) => Key('search.type.${t.name}');
  static Key userKey(String username) => Key('search.user.$username');
  static Key hashtagKey(String tag) => Key('search.hashtag.$tag');

  /// The pause after typing before searching.
  static const debounce = Duration(milliseconds: 350);

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  final _field = TextEditingController();
  Timer? _timer;
  Timer? _hintTimer;
  int _hintIndex = 0;
  String _query = '';
  SearchType _type = SearchType.users;

  /// D147: queries already counted for trends while this screen is open.
  final Set<String> _recorded = {};
  Animation<double>? _covered;

  @override
  void initState() {
    super.initState();
    _hintTimer = Timer.periodic(KSearchHome.hintPeriod, (_) {
      if (mounted && _field.text.isEmpty) setState(() => _hintIndex++);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // D147: opening a result (any page pushed over the search while it
    // shows results) counts the query for trends.
    final covered = ModalRoute.of(context)?.secondaryAnimation;
    if (covered != _covered) {
      _covered?.removeStatusListener(_coveredChanged);
      _covered = covered?..addStatusListener(_coveredChanged);
    }
  }

  void _coveredChanged(AnimationStatus status) {
    if (status == AnimationStatus.forward) _record(_query);
  }

  /// D147 `POST /search/queries`, once per query, never awaited: trends
  /// are best effort and a failure is not the person's concern.
  void _record(String query) {
    if (query.isEmpty || !_recorded.add(query)) return;
    unawaited(
      ref
          .read(postsRepositoryProvider)
          .recordSearch(query)
          .catchError((Object _) {}),
    );
  }

  @override
  void dispose() {
    _covered?.removeStatusListener(_coveredChanged);
    _timer?.cancel();
    _hintTimer?.cancel();
    _field.dispose();
    super.dispose();
  }

  void _changed(String raw) {
    _timer?.cancel();
    _timer = Timer(DiscoverScreen.debounce, () {
      if (mounted) setState(() => _query = normalizeSearchQuery(raw));
    });
    setState(() {});
  }

  void _clear() {
    _timer?.cancel();
    _field.clear();
    setState(() => _query = '');
  }

  /// D147: a hot search: into the field, searched at once.
  void _searchTerm(String term) {
    _timer?.cancel();
    _field.value = TextEditingValue(
      text: term,
      selection: TextSelection.collapsed(offset: term.length),
    );
    setState(() => _query = normalizeSearchQuery(term));
  }

  void _cancel() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  /// "Try searching: `term`" through the trending terms; the static hint
  /// without them.
  String _hint(List<TrendingSearch> terms) {
    final l10n = context.l10n;
    if (terms.isEmpty) return l10n.searchHint;
    return l10n.searchTryHint(terms[_hintIndex % terms.length].term);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final terms = ref.watch(trendingSearchesProvider).value ?? const [];
    // Sizes estimated from the reference's cap heights and widths (SF Pro
    // there, Inter here: slightly tighter tracking keeps the widths close).
    final fieldStyle = t.body.copyWith(
      fontSize: 15,
      height: 1.2,
      letterSpacing: -0.3,
    );
    return Scaffold(
      body: KTopSafeArea(
        child: Column(
          children: [
            // D147 header (owner's layout reference): the field where the
            // reference has its scan button (Kabso has no QR feature, so
            // its slot stays empty), then Cancel.
            SizedBox(
              height: KSizes.minTouchTarget,
              child: Row(
                children: [
                  const SizedBox(width: KSearchHome.fieldStart),
                  Expanded(
                    child: Container(
                      height: KSearchHome.fieldHeight,
                      decoration: BoxDecoration(
                        color: p.surface,
                        borderRadius: BorderRadius.circular(KRadius.pill),
                      ),
                      padding: const EdgeInsetsDirectional.only(
                        start: KSearchHome.searchIconStart,
                      ),
                      child: Row(
                        children: [
                          AppIcon(
                            AppIcons.search,
                            size: KSearchHome.searchIcon,
                            color: p.textTertiary,
                          ),
                          const SizedBox(width: KSearchHome.hintGap),
                          Expanded(
                            child: TextField(
                              key: DiscoverScreen.fieldKey,
                              controller: _field,
                              autofocus: true,
                              textInputAction: TextInputAction.search,
                              onChanged: _changed,
                              onSubmitted: (raw) {
                                _timer?.cancel();
                                final q = normalizeSearchQuery(raw);
                                setState(() => _query = q);
                                _record(q);
                              },
                              style: fieldStyle,
                              decoration: InputDecoration(
                                hintText: _hint(terms),
                                hintStyle: fieldStyle.copyWith(
                                  color: p.textTertiary,
                                  fontWeight: FontWeight.w500,
                                ),
                                hintMaxLines: 1,
                                isCollapsed: true,
                                filled: false,
                                contentPadding: EdgeInsets.zero,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                constraints: const BoxConstraints(),
                              ),
                            ),
                          ),
                          if (_field.text.isNotEmpty)
                            IconButton(
                              key: DiscoverScreen.clearKey,
                              tooltip: l10n.searchClear,
                              onPressed: _clear,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints.tightFor(
                                width: KSearchHome.fieldHeight,
                                height: KSearchHome.fieldHeight,
                              ),
                              icon: AppIcon(
                                AppIcons.close,
                                size: KMetrics.iconSm,
                                color: p.textSecondary,
                              ),
                            )
                          else
                            const SizedBox(width: KSpacing.md),
                        ],
                      ),
                    ),
                  ),
                  TextButton(
                    key: DiscoverScreen.cancelKey,
                    onPressed: _cancel,
                    style: TextButton.styleFrom(
                      foregroundColor: p.textPrimary,
                      padding: const EdgeInsetsDirectional.only(
                        start: KSearchHome.fieldToCancel,
                        end: KSearchHome.cancelEnd,
                      ),
                      minimumSize: const Size(
                        KSizes.minTouchTarget,
                        KSizes.minTouchTarget,
                      ),
                      shape: const RoundedRectangleBorder(),
                      textStyle: t.body.copyWith(
                        fontSize: 16,
                        height: 1.2,
                        letterSpacing: -0.3,
                      ),
                    ),
                    child: Text(l10n.searchCancel),
                  ),
                ],
              ),
            ),
            if (_query.isNotEmpty)
              // Scrolls sideways when the three kinds do not fit (large text).
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: KSpacing.md,
                  vertical: KSpacing.sm,
                ),
                child: Row(
                  children: [
                    for (final (t, label) in [
                      (SearchType.users, l10n.searchTabUsers),
                      (SearchType.hashtags, l10n.searchTabHashtags),
                      (SearchType.posts, l10n.searchTabPosts),
                    ])
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          end: KSpacing.sm,
                        ),
                        child: ChoiceChip(
                          key: DiscoverScreen.typeKey(t),
                          label: Text(label),
                          selected: _type == t,
                          showCheckmark: false,
                          selectedColor: p.primary.withValues(alpha: 0.12),
                          labelStyle: context.textStyles.label.copyWith(
                            color: _type == t ? p.primary : p.textSecondary,
                            fontWeight: _type == t ? FontWeight.w700 : null,
                          ),
                          onSelected: (_) => setState(() => _type = t),
                        ),
                      ),
                  ],
                ),
              ),
            Expanded(
              child: _query.isEmpty
                  ? (searchHomeHasContent(ref)
                        ? SearchHome(
                            key: DiscoverScreen.promptKey,
                            onSearchTerm: _searchTerm,
                          )
                        : KEmptyState(
                            key: DiscoverScreen.promptKey,
                            icon: Icons.search_rounded,
                            title: l10n.searchPromptTitle,
                            message: l10n.searchPromptBody,
                          ))
                  : _Results(
                      key: ValueKey((_type, _query)),
                      type: _type,
                      query: _query,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Results extends ConsumerWidget {
  const new({required this.type, required this.query, super.key});

  final SearchType type;
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final key = (type: type, query: query);
    final results = ref.watch(searchResultsProvider(key));
    void more() => ref.read(searchResultsProvider(key).notifier).loadMore();
    return switch (results) {
      AsyncValue(value: FeedItems(:final items)) when items.isEmpty =>
        KEmptyState(
          key: DiscoverScreen.emptyKey,
          icon: Icons.search_off_rounded,
          title: l10n.searchNoResults(query),
          message: l10n.searchPromptBody,
        ),
      AsyncValue(
        value: FeedItems(:final items, :final hasMore, :final loadMoreError),
      ) =>
        CustomScrollView(
          key: DiscoverScreen.resultsKey,
          slivers: [
            if (type == SearchType.posts)
              SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: KProfile.gridGap,
                  crossAxisSpacing: KProfile.gridGap,
                ),
                itemCount: items.length,
                itemBuilder: (_, i) =>
                    PostGridCell(item: items[i] as ProfileGridItem),
              )
            else
              SliverList.builder(
                itemCount: items.length,
                itemBuilder: (_, i) => switch (items[i]) {
                  final UserSummary u => _UserRow(user: u),
                  final Hashtag h => _HashtagRow(hashtag: h),
                  _ => const SizedBox.shrink(),
                },
              ),
            if (hasMore)
              SliverToBoxAdapter(
                child: loadMoreError == null
                    ? PostGridLoadMore(
                        key: ValueKey(items.length),
                        onVisible: more,
                      )
                    : Center(
                        child: TextButton(
                          onPressed: more,
                          child: Text(l10n.actionRetry),
                        ),
                      ),
              ),
          ],
        ),
      AsyncError(:final error) => FailureErrorState(
        title: l10n.errorTitle,
        failure: toAppFailure(error),
        onRetry: () => ref.invalidate(searchResultsProvider(key)),
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}

class _UserRow extends StatelessWidget {
  const new({required this.user});

  final UserSummary user;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final name = user.displayName.isEmpty ? user.username : user.displayName;
    return ListTile(
      key: DiscoverScreen.userKey(user.username),
      leading: ExcludeSemantics(
        child: KAvatar(name: name, imageUrl: user.avatarUrl),
      ),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      // D146: a premium username wears its special-ID badge.
      subtitle: switch (user.premiumTier) {
        final tier? => Align(
          alignment: AlignmentDirectional.centerStart,
          child: KSpecialUsername(
            username: user.username,
            tier: tier,
            height: 18,
            animate: false,
          ),
        ),
        null => Text(
          context.l10n.profileUsername(user.username),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textDirection: TextDirection.ltr,
          textAlign: Directionality.of(context) == TextDirection.rtl
              ? TextAlign.right
              : TextAlign.left,
          style: TextStyle(color: p.textSecondary),
        ),
      },
      onTap: () => context.push(AppRoutes.userProfile(user.username)),
    );
  }
}

class _HashtagRow extends StatelessWidget {
  const new({required this.hashtag});

  final Hashtag hashtag;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ListTile(
      key: DiscoverScreen.hashtagKey(hashtag.tag),
      leading: Container(
        width: KSizes.avatarMd,
        height: KSizes.avatarMd,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: p.primary.withValues(alpha: 0.09),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.tag_rounded, size: 22, color: p.primary),
      ),
      title: Text(context.l10n.hashtagLabel(hashtag.tag), maxLines: 1),
      subtitle: Text(
        context.l10n.hashtagPostCount(hashtag.postCount),
        style: TextStyle(color: p.textSecondary),
      ),
      onTap: () => context.push(AppRoutes.hashtag(hashtag.tag)),
    );
  }
}
