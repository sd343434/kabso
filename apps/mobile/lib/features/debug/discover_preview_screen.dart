import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/icons/app_icons.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/debug/preview_photo.dart';
import 'package:kabso_live/features/debug/preview_state_bar.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Geometry of the KL-056 Discover preview, measured from the owner's Figma
/// reference (UI kit "Discover Page", node 1347:5338, 418x904). Only geometry
/// and type sizes are taken from it: covers and the banner are generated
/// art, and the kit's scan button (a third-party feature) is left out.
abstract final class KDiscover {
  static const double searchHeight = 37;
  static const double searchRadius = 4;
  static const double searchIcon = 15;
  static const double searchHintSize = 14.2;
  static const double bannerHeight = 202;
  static const double dotsBottom = 11;
  static const double sectionHeight = 230;
  static const double hashtagIcon = 34;
  static const double hashtagStart = 15;
  static const double titleSize = 15;
  static const double subtitleSize = 12.3;
  static const double usesHeight = 20.5;
  static const double usesRadius = 3;
  static const double usesSize = 12.3;
  static const double usesIcon = 13;
  static const double coversTop = 70;
  static const double coversInset = 17;
  static const Size cover = Size(109, 148);
  static const double coverGap = 3;
  static const double separator = 8;
}

/// A trending hashtag of the preview (labelled test data, D46).
class HashtagPreview {
  const new(this.name, this.videos, this.seed);

  final String name;
  final int videos;

  /// First seed of its generated covers.
  final int seed;
}

List<HashtagPreview> hashtagsPreviewFixture({required bool ar}) => [
  HashtagPreview(ar ? 'بيانات_اختبار' : 'test_data', 12400, 1),
  HashtagPreview(ar ? 'كبسو_تجربة' : 'kabso_test', 3150, 5),
  HashtagPreview(ar ? 'بث_تجريبي' : 'live_test', 860, 9),
  HashtagPreview(ar ? 'موسيقى_تجربة' : 'music_test', 42, 13),
];

/// States of the Discover preview. Production Discover is still the
/// "coming soon" tab (no search or trending contract), so its honest state
/// today is [unavailable].
enum DiscoverPreviewState { loading, unavailable, populated }

/// `/debug/discover-preview` — KL-056 Discover: search bar, featured banner
/// and trending hashtag rows with video covers. Search filters the test
/// hashtags on the device; a cover opens the feed preview.
class DiscoverPreviewScreen extends StatefulWidget {
  const new({
    super.key,
    this.initialState = DiscoverPreviewState.populated,
    this.inApp = false,
  });

  final DiscoverPreviewState initialState;

  /// D86: shown as the app's Discover (Demo data): a back button, no state
  /// switcher, and a test-data label.
  final bool inApp;

  static const testDataKey = Key('discover-preview-test-data');
  static const searchKey = Key('discover-preview-search');
  static const bannerKey = Key('discover-preview-banner');
  static const listKey = Key('discover-preview-list');

  @override
  State<DiscoverPreviewScreen> createState() => _DiscoverPreviewScreenState();
}

class _DiscoverPreviewScreenState extends State<DiscoverPreviewScreen> {
  late DiscoverPreviewState _state = widget.initialState;
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  static String _stateLabel(AppLocalizations l10n, DiscoverPreviewState s) =>
      switch (s) {
        DiscoverPreviewState.loading => l10n.previewStateLoading,
        DiscoverPreviewState.unavailable => l10n.previewStateUnavailable,
        DiscoverPreviewState.populated => l10n.previewStatePopulated,
      };

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      backgroundColor: p.background,
      body: KTopSafeArea(
        child: Column(
          children: [
            if (widget.inApp)
              Row(
                children: [
                  const BackButton(),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: KSpacing.md),
                    child: Text(
                      context.l10n.feedPreviewTestData,
                      key: DiscoverPreviewScreen.testDataKey,
                      style: context.textStyles.caption.copyWith(
                        color: p.textSecondary,
                      ),
                    ),
                  ),
                ],
              )
            else
              PreviewStateBar<DiscoverPreviewState>(
                testDataKey: DiscoverPreviewScreen.testDataKey,
                values: DiscoverPreviewState.values,
                value: _state,
                label: (s) => _stateLabel(context.l10n, s),
                onChanged: (s) => setState(() => _state = s),
              ),
            _SearchBar(
              controller: _search,
              onChanged: (q) => setState(() => _query = q.trim()),
              enabled: _state == DiscoverPreviewState.populated,
            ),
            Expanded(child: _body(context)),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final l10n = context.l10n;
    switch (_state) {
      case DiscoverPreviewState.loading:
        return ListView(
          physics: const NeverScrollableScrollPhysics(),
          children: const [
            KSkeleton(height: KDiscover.bannerHeight, radius: 0),
            _SkeletonSection(),
            _SkeletonSection(),
          ],
        );
      case DiscoverPreviewState.unavailable:
        return KEmptyState(
          icon: Icons.explore_outlined,
          title: l10n.discoverComingTitle,
          message: l10n.discoverComingBody,
        );
      case DiscoverPreviewState.populated:
        final all = hashtagsPreviewFixture(
          ar: Directionality.of(context) == TextDirection.rtl,
        );
        final q = _query.toLowerCase();
        final tags = q.isEmpty
            ? all
            : all.where((h) => h.name.toLowerCase().contains(q)).toList();
        if (tags.isEmpty) {
          return KEmptyState(
            compact: true,
            icon: Icons.search_off_rounded,
            title: l10n.discoverNoResultsTitle,
            message: l10n.discoverNoResultsBody(KFormat.bidiIsolate(_query)),
            actionLabel: l10n.discoverClearSearch,
            onAction: () => setState(() {
              _search.clear();
              _query = '';
            }),
          );
        }
        return ListView.separated(
          key: DiscoverPreviewScreen.listKey,
          // The banner shows only on the unfiltered page, as in the kit.
          itemCount: tags.length + (q.isEmpty ? 1 : 0),
          separatorBuilder: (_, i) => i == 0 && q.isEmpty
              ? const SizedBox.shrink()
              : Container(
                  height: KDiscover.separator,
                  color: context.palette.surface,
                ),
          itemBuilder: (_, i) {
            if (q.isEmpty && i == 0) return const _Banner();
            return _HashtagSection(tag: tags[i - (q.isEmpty ? 1 : 0)]);
          },
        );
    }
  }
}

class _SearchBar extends StatelessWidget {
  const new({
    required this.controller,
    required this.onChanged,
    required this.enabled,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        KSpacing.lg,
        KSpacing.xxs,
        KSpacing.lg,
        KSpacing.sm,
      ),
      child: TextField(
        key: DiscoverPreviewScreen.searchKey,
        controller: controller,
        enabled: enabled,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: context.textStyles.body.copyWith(
          fontSize: KDiscover.searchHintSize,
          color: p.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: context.l10n.feedSearch,
          hintStyle: context.textStyles.body.copyWith(
            fontSize: KDiscover.searchHintSize,
            color: p.textTertiary,
          ),
          filled: true,
          fillColor: p.surfaceOverlay,
          isDense: true,
          constraints: const BoxConstraints(minHeight: KDiscover.searchHeight),
          // 8 + 21 (one line) + 8 = the measured 37.
          contentPadding: const EdgeInsets.symmetric(vertical: KSpacing.sm),
          prefixIcon: Padding(
            padding: const EdgeInsetsDirectional.only(
              start: KSpacing.md,
              end: KSpacing.sm,
            ),
            child: AppIcon(
              AppIcons.search,
              size: KDiscover.searchIcon,
              color: p.textTertiary,
            ),
          ),
          prefixIconConstraints: const BoxConstraints(),
          // No outline at rest (the theme's enabled border would add one); the
          // theme's focus border still shows while typing.
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(KDiscover.searchRadius),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(KDiscover.searchRadius),
            borderSide: BorderSide.none,
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(KDiscover.searchRadius),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

/// Featured banner: three pages of generated art with pagination dots.
class _Banner extends StatefulWidget {
  const new();

  @override
  State<_Banner> createState() => _BannerState();
}

class _BannerState extends State<_Banner> {
  static const _pages = [21, 22, 23];
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final white = KPalette.dark.textPrimary;
    final l10n = context.l10n;
    return SizedBox(
      key: DiscoverPreviewScreen.bannerKey,
      height: KDiscover.bannerHeight,
      child: Stack(
        children: [
          PageView.builder(
            itemCount: _pages.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) => Semantics(
              image: true,
              label: l10n.discoverBanner(i + 1, _pages.length),
              child: PreviewPhoto(_pages[i], kind: PreviewPhotoKind.landscape),
            ),
          ),
          PositionedDirectional(
            start: 0,
            end: 0,
            bottom: KDiscover.dotsBottom,
            child: ExcludeSemantics(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _pages.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      width: i == _page ? 14 : 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: white.withValues(alpha: i == _page ? 1 : 0.5),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HashtagSection extends StatelessWidget {
  const new({required this.tag});

  final HashtagPreview tag;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l10n = context.l10n;
    final t = context.textStyles;
    final count = KFormat.compact(tag.videos, l10n);
    return SizedBox(
      height: KDiscover.sectionHeight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              KDiscover.hashtagStart,
              KDiscover.hashtagStart,
              KDiscover.coversInset,
              0,
            ),
            child: Semantics(
              container: true,
              label: l10n.discoverHashtagVideos(tag.name, count),
              excludeSemantics: true,
              child: Row(
                children: [
                  Container(
                    width: KDiscover.hashtagIcon,
                    height: KDiscover.hashtagIcon,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: p.border),
                    ),
                    child: Icon(
                      Icons.tag_rounded,
                      size: KDiscover.hashtagIcon * 0.55,
                      color: p.textPrimary,
                    ),
                  ),
                  const SizedBox(width: KSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tag.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.bodyStrong.copyWith(
                            fontSize: KDiscover.titleSize,
                            fontWeight: FontWeight.w600,
                            color: p.textPrimary,
                          ),
                        ),
                        Text(
                          l10n.discoverTrendingHashtag,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.caption.copyWith(
                            fontSize: KDiscover.subtitleSize,
                            color: p.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: KSpacing.sm),
                  Container(
                    height: KDiscover.usesHeight,
                    padding: const EdgeInsetsDirectional.only(
                      start: KSpacing.xs + 2,
                      end: KSpacing.xxs,
                    ),
                    decoration: BoxDecoration(
                      color: p.surfaceOverlay,
                      borderRadius: BorderRadius.circular(KDiscover.usesRadius),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          count,
                          style: t.caption.copyWith(
                            fontSize: KDiscover.usesSize,
                            fontWeight: FontWeight.w600,
                            color: p.textPrimary,
                          ),
                        ),
                        // Chevron toward the reading end.
                        RotatedBox(
                          quarterTurns:
                              Directionality.of(context) == TextDirection.rtl
                              ? 1
                              : 3,
                          child: AppIcon(
                            AppIcons.chevronDown,
                            size: KDiscover.usesIcon,
                            color: p.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          SizedBox(
            height: KDiscover.cover.height,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: KDiscover.coversInset,
              ),
              itemCount: 6,
              separatorBuilder: (_, _) =>
                  const SizedBox(width: KDiscover.coverGap),
              itemBuilder: (context, i) => Semantics(
                button: true,
                label: l10n.discoverOpenVideo(i + 1, tag.name),
                excludeSemantics: true,
                child: InkWell(
                  onTap: () => context.push(AppRoutes.debugFeedPreview),
                  child: SizedBox.fromSize(
                    size: KDiscover.cover,
                    child: PreviewPhoto(tag.seed + i),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: KSpacing.md),
        ],
      ),
    );
  }
}

class _SkeletonSection extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => SizedBox(
    height: KDiscover.sectionHeight,
    child: Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        KDiscover.hashtagStart,
        KDiscover.hashtagStart,
        0,
        KSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              KSkeleton(
                width: KDiscover.hashtagIcon,
                height: KDiscover.hashtagIcon,
                circle: true,
              ),
              SizedBox(width: KSpacing.sm),
              KSkeleton(width: 120, height: 14),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: KDiscover.coverGap),
                KSkeleton(
                  width: KDiscover.cover.width,
                  height: KDiscover.cover.height,
                  radius: 0,
                ),
              ],
            ],
          ),
        ],
      ),
    ),
  );
}
