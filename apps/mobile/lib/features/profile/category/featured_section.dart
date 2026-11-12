import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/icons/app_icons.dart';
import 'package:kabso_live/core/models/profile_fields.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/posts/domain/post_models.dart';
import 'package:kabso_live/features/profile/category/category_models.dart';
import 'package:kabso_live/features/profile/category/category_repository.dart';
import 'package:kabso_live/features/profile/category/category_style.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D386 (CONVENTIONS §10.175.2): the featured section under a verified
/// category's header — «أعمالي», «تلاواتي», «قصائدي», «معرضي» … — from
/// `GET /users/{username}/featured`: the person's pins (up to 6, in their
/// order) or the newest matching posts. Each section has its own layout.
/// Nothing shows without a [CategoryLookScope] look with a section, while
/// loading, on a failure, or (someone else's page) when it is empty; the
/// person's own empty section shows how to pin.
class FeaturedSectionSliver extends ConsumerWidget {
  const new({required this.username, this.own = false, super.key});

  final String username;
  final bool own;

  static const sectionKey = Key('profile.featured');
  static const titleKey = Key('profile.featured.title');
  static const reorderKey = Key('profile.featured.reorder');
  static const emptyKey = Key('profile.featured.empty');
  static Key itemKey(String id) => Key('profile.featured.item.$id');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final look = CategoryLookScope.maybeOf(context);
    if (look == null || look.section == null) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    final featured = ref.watch(profileFeaturedProvider(username)).value;
    final section = featured?.section;
    if (featured == null || section == null) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    if (featured.isEmpty && !own) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    return SliverToBoxAdapter(
      child: FeaturedSectionView(
        key: sectionKey,
        featured: featured,
        section: section,
        look: look,
        own: own,
        onReorder: own && featured.source == FeaturedSource.pinned
            ? () => _reorder(context, ref, featured)
            : null,
      ),
    );
  }

  Future<void> _reorder(
    BuildContext context,
    WidgetRef ref,
    ProfileFeatured featured,
  ) async {
    final ids = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => FeaturedReorderSheet(items: featured.items),
    );
    if (ids == null || !context.mounted) return;
    try {
      await ref.read(myFeaturedPinsProvider.notifier).setAll(ids);
      ref.invalidate(profileFeaturedProvider(username));
    } on Object catch (e) {
      if (context.mounted) {
        KSnack.error(context, failureMessage(context.l10n, toAppFailure(e)));
      }
    }
  }
}

/// The section itself (title, then the section's layout).
class FeaturedSectionView extends StatelessWidget {
  const new({
    required this.featured,
    required this.section,
    required this.look,
    super.key,
    this.own = false,
    this.onReorder,
  });

  final ProfileFeatured featured;
  final FeaturedSection section;
  final CategoryLook look;
  final bool own;
  final VoidCallback? onReorder;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final reorder = onReorder;
    return Padding(
      padding: const EdgeInsets.only(top: KSpacing.sm, bottom: KSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                    color: look.accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: KSpacing.sm),
                AppIcon(look.icon, size: 18, color: look.accent),
                const SizedBox(width: KSpacing.xs),
                Expanded(
                  child: Text(
                    featuredSectionTitle(l10n, section),
                    key: FeaturedSectionSliver.titleKey,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.title.copyWith(color: p.textPrimary),
                  ),
                ),
                if (reorder != null && featured.items.length > 1)
                  TextButton(
                    key: FeaturedSectionSliver.reorderKey,
                    style: TextButton.styleFrom(
                      foregroundColor: look.accent,
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: reorder,
                    child: Text(l10n.featuredReorder),
                  ),
              ],
            ),
          ),
          if (own && featured.source == FeaturedSource.auto)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                KSpacing.lg,
                KSpacing.xxs,
                KSpacing.lg,
                0,
              ),
              child: Text(
                l10n.featuredAutoNote,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: t.caption.copyWith(color: p.textSecondary),
              ),
            ),
          const SizedBox(height: KSpacing.sm),
          if (featured.isEmpty) _EmptyOwn(look: look) else _body(context),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    final items = featured.items;
    return switch (section) {
      FeaturedSection.works => _HorizontalCards(
        items: items,
        look: look,
        builder: (post) => _MediaCard(post: post, look: look, play: true),
      ),
      FeaturedSection.mostViewed => _HorizontalCards(
        items: items,
        look: look,
        height: 196,
        builder: (post) => _ReelTile(post: post, look: look),
      ),
      FeaturedSection.recitations ||
      FeaturedSection.stories => _PlayerList(items: items, look: look),
      FeaturedSection.poems => _HorizontalCards(
        items: items,
        look: look,
        height: 176,
        builder: (post) => _PoemCard(post: post, look: look),
      ),
      FeaturedSection.articles => _ArticleList(items: items, look: look),
      FeaturedSection.reports => _NewsList(items: items, look: look),
      FeaturedSection.program => Column(
        children: [
          _ScheduleList(items: featured.schedule, look: look),
          if (items.isNotEmpty)
            _HorizontalCards(
              items: items,
              look: look,
              builder: (post) => _MediaCard(post: post, look: look),
            ),
        ],
      ),
      FeaturedSection.gallery => _Gallery(items: items, look: look),
      FeaturedSection.games ||
      FeaturedSection.achievements ||
      FeaturedSection.highlights => _HorizontalCards(
        items: items,
        look: look,
        builder: (post) => _MediaCard(
          post: post,
          look: look,
          badge: section == FeaturedSection.achievements
              ? AppIcons.trophy
              : null,
        ),
      ),
    };
  }
}

void _open(BuildContext context, Post post) =>
    context.push(AppRoutes.post(post.id));

/// The first line of a post's text (a title), and the rest (an excerpt).
(String, String) _titleAndRest(String text) {
  final trimmed = text.trim();
  final nl = trimmed.indexOf('\n');
  if (nl < 0) return (trimmed, '');
  return (trimmed.substring(0, nl).trim(), trimmed.substring(nl + 1).trim());
}

/// A picture of [post] (its first photo or a video's poster), or an
/// accent-tinted tile when it has none or the picture cannot load.
class _PostPicture extends StatelessWidget {
  const new({required this.post, required this.look});

  final Post post;
  final CategoryLook look;

  @override
  Widget build(BuildContext context) {
    final media = post.media.firstOrNull;
    final url = media?.posterUrl ?? media?.thumbUrl;
    final placeholder = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            look.accent.withValues(alpha: 0.55),
            look.accent.withValues(alpha: 0.18),
          ],
        ),
      ),
      child: Center(
        child: AppIcon(
          look.icon,
          size: 28,
          color: look.onAccent.withValues(alpha: 0.7),
        ),
      ),
    );
    if (url == null) return placeholder;
    return Image(
      image: NetworkImage(url),
      fit: BoxFit.cover,
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) => placeholder,
      frameBuilder: (_, child, frame, sync) =>
          frame == null && !sync ? placeholder : child,
    );
  }
}

class _HorizontalCards extends StatelessWidget {
  const new({
    required this.items,
    required this.look,
    required this.builder,
    this.height = 188,
  });

  final List<Post> items;
  final CategoryLook look;
  final Widget Function(Post) builder;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height * MediaQuery.textScalerOf(context).scale(1).clamp(1, 1.3),
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(width: KSpacing.sm),
      itemBuilder: (context, i) => KeyedSubtree(
        key: FeaturedSectionSliver.itemKey(items[i].id),
        child: builder(items[i]),
      ),
    ),
  );
}

/// WORKS, PROGRAM, GAMES, ACHIEVEMENTS, HIGHLIGHTS: a picture card with a
/// caption (a play button over a video).
class _MediaCard extends StatelessWidget {
  const new({
    required this.post,
    required this.look,
    this.play = false,
    this.badge,
  });

  final Post post;
  final CategoryLook look;
  final bool play;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.textStyles;
    final video = post.media.any((m) => m.type == MediaType.video);
    final (title, _) = _titleAndRest(post.text);
    return SizedBox(
      width: 132,
      child: Material(
        color: p.surface,
        borderRadius: BorderRadius.circular(KRadius.md),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _open(context, post),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _PostPicture(post: post, look: look),
                    if (play || video)
                      Center(
                        child: Semantics(
                          label: context.l10n.featuredPlay,
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: look.accent,
                            ),
                            child: Center(
                              child: AppIcon(
                                AppIcons.play,
                                size: 20,
                                color: look.onAccent,
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (badge case final icon?)
                      PositionedDirectional(
                        top: KSpacing.xs,
                        start: KSpacing.xs,
                        child: Container(
                          padding: const EdgeInsets.all(KSpacing.xs),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: look.accent,
                          ),
                          child: AppIcon(icon, size: 14, color: look.onAccent),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  KSpacing.sm,
                  KSpacing.xs,
                  KSpacing.sm,
                  KSpacing.sm,
                ),
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.label.copyWith(color: p.textPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// MOST_VIEWED: a 9:16 reel tile with its views.
class _ReelTile extends StatelessWidget {
  const new({required this.post, required this.look});

  final Post post;
  final CategoryLook look;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SizedBox(
      width: 110,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(KRadius.md),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: () => _open(context, post),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _PostPicture(post: post, look: look),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x00000000), Color(0x99000000)],
                      stops: [0.55, 1],
                    ),
                  ),
                ),
                PositionedDirectional(
                  start: KSpacing.sm,
                  end: KSpacing.sm,
                  bottom: KSpacing.sm,
                  child: Row(
                    children: [
                      const AppIcon(
                        AppIcons.play,
                        size: 14,
                        color: Color(0xFFFFFFFF),
                      ),
                      const SizedBox(width: KSpacing.xxs),
                      Flexible(
                        child: Text(
                          l10n.featuredViews(
                            KFormat.compact(post.viewCount, l10n),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.textStyles.caption.copyWith(
                            color: const Color(0xFFFFFFFF),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// RECITATIONS, STORIES: a list of play rows (the post's sound plays on
/// the post screen).
class _PlayerList extends StatelessWidget {
  const new({required this.items, required this.look});

  final List<Post> items;
  final CategoryLook look;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.textStyles;
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(KRadius.lg),
        ),
        child: Column(
          children: [
            for (final (i, post) in items.indexed) ...[
              if (i > 0)
                Divider(height: 1, indent: 64, color: p.border, thickness: 1),
              KeyedSubtree(
                key: FeaturedSectionSliver.itemKey(post.id),
                child: InkWell(
                  onTap: () => _open(context, post),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: KSpacing.md,
                      vertical: KSpacing.sm,
                    ),
                    child: Row(
                      children: [
                        Semantics(
                          label: l10n.featuredPlay,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: look.accent,
                            ),
                            child: Center(
                              child: AppIcon(
                                AppIcons.play,
                                size: 20,
                                color: look.onAccent,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: KSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _titleAndRest(post.text).$1,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: t.bodyStrong.copyWith(
                                  color: p.textPrimary,
                                ),
                              ),
                              const SizedBox(height: KSpacing.xxs),
                              // A still waveform in the accent.
                              _Wave(color: look.accent, seed: i),
                            ],
                          ),
                        ),
                        const SizedBox(width: KSpacing.sm),
                        Text(
                          KFormat.countdown(
                            Duration(
                              milliseconds:
                                  post.media.firstOrNull?.durationMs ?? 0,
                            ),
                          ),
                          style: t.caption.copyWith(color: p.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Wave extends StatelessWidget {
  const new({required this.color, required this.seed});

  final Color color;
  final int seed;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 12,
    child: CustomPaint(painter: _WavePainter(color, seed)),
  );
}

class _WavePainter extends CustomPainter {
  const new(this.color, this.seed);

  final Color color;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.55)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    const step = 5.0;
    var i = 0;
    for (var x = 1.0; x < size.width; x += step, i++) {
      final h = 3 + ((i * 7 + seed * 3) % 9).toDouble();
      canvas.drawLine(
        Offset(x, (size.height - h) / 2),
        Offset(x, (size.height + h) / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WavePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.seed != seed;
}

/// POEMS: a poetry card in the bundled display face (Baloo Bhaijaan 2).
class _PoemCard extends StatelessWidget {
  const new({required this.post, required this.look});

  final Post post;
  final CategoryLook look;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SizedBox(
      width: 220,
      child: Material(
        color: Color.alphaBlend(look.accent.withValues(alpha: 0.10), p.surface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KRadius.lg),
          side: BorderSide(color: look.accent.withValues(alpha: 0.45)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _open(context, post),
          child: Padding(
            padding: const EdgeInsets.all(KSpacing.md),
            child: Column(
              children: [
                Text(
                  '❝',
                  style: TextStyle(color: look.accent, fontSize: 22, height: 1),
                ),
                const SizedBox(height: KSpacing.xs),
                Expanded(
                  child: Center(
                    child: Text(
                      post.text.trim(),
                      textAlign: TextAlign.center,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: KFonts.poetry,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        height: 1.5,
                        color: p.textPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ARTICLES: a title and an excerpt per post.
class _ArticleList extends StatelessWidget {
  const new({required this.items, required this.look});

  final List<Post> items;
  final CategoryLook look;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.textStyles;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
      child: Column(
        children: [
          for (final post in items.take(3))
            Padding(
              key: FeaturedSectionSliver.itemKey(post.id),
              padding: const EdgeInsets.only(bottom: KSpacing.sm),
              child: Material(
                color: p.surface,
                borderRadius: BorderRadius.circular(KRadius.md),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => _open(context, post),
                  child: Container(
                    decoration: BoxDecoration(
                      border: BorderDirectional(
                        start: BorderSide(color: look.accent, width: 3),
                      ),
                    ),
                    padding: const EdgeInsets.all(KSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _titleAndRest(post.text).$1,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: t.bodyStrong.copyWith(color: p.textPrimary),
                        ),
                        if (_titleAndRest(post.text).$2 case final rest
                            when rest.isNotEmpty) ...[
                          const SizedBox(height: KSpacing.xxs),
                          Text(
                            rest,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: t.caption.copyWith(color: p.textSecondary),
                          ),
                        ],
                        const SizedBox(height: KSpacing.xs),
                        Text(
                          context.l10n.featuredReadMore,
                          style: t.label.copyWith(color: look.accent),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// REPORTS: news cards — a picture at the reading start (when there is
/// one), the headline and the date.
class _NewsList extends StatelessWidget {
  const new({required this.items, required this.look});

  final List<Post> items;
  final CategoryLook look;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.textStyles;
    final tag = Localizations.localeOf(context).toLanguageTag();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
      child: Column(
        children: [
          for (final post in items.take(3))
            Padding(
              key: FeaturedSectionSliver.itemKey(post.id),
              padding: const EdgeInsets.only(bottom: KSpacing.sm),
              child: Material(
                color: p.surface,
                borderRadius: BorderRadius.circular(KRadius.md),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => _open(context, post),
                  child: SizedBox(
                    height: 84,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: 84,
                          child: _PostPicture(post: post, look: look),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: KSpacing.md,
                              vertical: KSpacing.sm,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _titleAndRest(post.text).$1,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: t.bodyStrong.copyWith(
                                    color: p.textPrimary,
                                    height: 1.3,
                                  ),
                                ),
                                const SizedBox(height: KSpacing.xxs),
                                Text(
                                  KFormat.date(
                                    post.publishedAt ?? post.createdAt,
                                    tag,
                                  ),
                                  maxLines: 1,
                                  style: t.caption.copyWith(color: look.accent),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// PROGRAM: the upcoming lives and podcast episodes.
class _ScheduleList extends StatelessWidget {
  const new({required this.items, required this.look});

  final List<FeaturedScheduleItem> items;
  final CategoryLook look;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.textStyles;
    final l10n = context.l10n;
    final tag = Localizations.localeOf(context).toLanguageTag();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
      child: Column(
        children: [
          for (final s in items)
            Padding(
              key: FeaturedSectionSliver.itemKey(s.id),
              padding: const EdgeInsets.only(bottom: KSpacing.sm),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(KRadius.md),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(KSpacing.sm),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        padding: const EdgeInsets.symmetric(
                          vertical: KSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: look.accent,
                          borderRadius: BorderRadius.circular(KRadius.sm),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '${s.startsAt.toLocal().day}',
                              style: t.title.copyWith(
                                color: look.onAccent,
                                height: 1.1,
                              ),
                            ),
                            Text(
                              KFormat.time(s.startsAt, tag),
                              maxLines: 1,
                              style: t.caption.copyWith(
                                color: look.onAccent,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: KSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.bodyStrong.copyWith(
                                color: p.textPrimary,
                              ),
                            ),
                            Text(
                              _scheduleLine(l10n, s, tag),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.caption.copyWith(color: p.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      AppIcon(
                        s.podcast ? AppIcons.podcast : AppIcons.liveTv,
                        size: 20,
                        color: look.accent,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String _scheduleLine(
  AppLocalizations l10n,
  FeaturedScheduleItem s,
  String tag,
) {
  final kind = s.podcast ? l10n.featuredPodcast : l10n.featuredUpcoming;
  return '$kind · ${KFormat.date(s.startsAt, tag)}';
}

/// GALLERY: a 3-column image grid (up to 6).
class _Gallery extends StatelessWidget {
  const new({required this.items, required this.look});

  final List<Post> items;
  final CategoryLook look;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
    child: GridView.count(
      crossAxisCount: 3,
      mainAxisSpacing: 3,
      crossAxisSpacing: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        for (final (i, post) in items.indexed)
          ClipRRect(
            key: FeaturedSectionSliver.itemKey(post.id),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(i == 0 ? KRadius.md : 2),
              topRight: Radius.circular(i == 2 ? KRadius.md : 2),
              bottomLeft: Radius.circular(
                i == items.length - 3 || items.length <= 3 && i == 0
                    ? KRadius.md
                    : 2,
              ),
              bottomRight: Radius.circular(
                i == items.length - 1 && i % 3 == 2 ? KRadius.md : 2,
              ),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: () => _open(context, post),
                child: _PostPicture(post: post, look: look),
              ),
            ),
          ),
      ],
    ),
  );
}

/// The person's own empty section: how to pin.
class _EmptyOwn extends StatelessWidget {
  const new({required this.look});

  final CategoryLook look;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.textStyles;
    return Padding(
      key: FeaturedSectionSliver.emptyKey,
      padding: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(KRadius.md),
          border: Border.all(color: look.accent.withValues(alpha: 0.5)),
          color: look.accent.withValues(alpha: 0.06),
        ),
        child: Padding(
          padding: const EdgeInsets.all(KSpacing.md),
          child: Row(
            children: [
              Icon(Icons.push_pin_outlined, color: look.accent, size: 20),
              const SizedBox(width: KSpacing.sm),
              Expanded(
                child: Text(
                  context.l10n.featuredEmptyOwn,
                  style: t.caption.copyWith(color: p.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// «ترتيب»: drag the pinned posts into a new order; Save returns the ids.
class FeaturedReorderSheet extends StatefulWidget {
  const new({required this.items, super.key});

  final List<Post> items;

  static const saveKey = Key('profile.featured.reorder.save');
  static const listKey = Key('profile.featured.reorder.list');

  @override
  State<FeaturedReorderSheet> createState() => _FeaturedReorderSheetState();
}

class _FeaturedReorderSheetState extends State<FeaturedReorderSheet> {
  late final List<Post> _items = [...widget.items];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final p = context.palette;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              KSpacing.lg,
              KSpacing.lg,
              KSpacing.lg,
              KSpacing.xs,
            ),
            child: Text(l10n.featuredReorder, style: t.title),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
            child: Text(
              l10n.featuredReorderHint,
              style: t.caption.copyWith(color: p.textSecondary),
            ),
          ),
          Flexible(
            child: ReorderableListView(
              key: FeaturedReorderSheet.listKey,
              shrinkWrap: true,
              onReorderItem: (from, to) => setState(() {
                final moved = _items.removeAt(from);
                _items.insert(to, moved);
              }),
              children: [
                for (final post in _items)
                  ListTile(
                    key: ValueKey(post.id),
                    title: Text(
                      _titleAndRest(post.text).$1,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    leading: SizedBox.square(
                      dimension: 40,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(KRadius.sm),
                        child: switch (post.media.firstOrNull) {
                          final m? => Image(
                            image: NetworkImage(m.posterUrl ?? m.thumbUrl),
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                ColoredBox(color: p.surfaceOverlay),
                          ),
                          null => ColoredBox(color: p.surfaceOverlay),
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(KSpacing.lg),
            child: KButton(
              key: FeaturedReorderSheet.saveKey,
              label: l10n.featuredReorderSave,
              onPressed: () =>
                  Navigator.of(context).pop([for (final p in _items) p.id]),
            ),
          ),
        ],
      ),
    );
  }
}
