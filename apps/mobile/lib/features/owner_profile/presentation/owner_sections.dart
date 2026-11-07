import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/owner_profile/data/owner_profile_repository.dart';
import 'package:kabso_live/features/owner_profile/domain/owner_models.dart';
import 'package:kabso_live/features/owner_profile/presentation/announcement_composer.dart';
import 'package:kabso_live/features/owner_profile/presentation/journey_editor.dart';
import 'package:kabso_live/features/owner_profile/presentation/official_posts_screen.dart';
import 'package:kabso_live/features/posts/domain/post_models.dart';
import 'package:kabso_live/features/profile/domain/profile_models.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// v1.95-social (D301, §10.112.6): the parts of the app owner's profile under
/// the header — «لوحة المؤسس» (his own view only), «إعلانات رسمية» and «رحلة
/// كابسو». In the app's theme (light and dark) with Kabso red and gold.
class OwnerProfileSections extends ConsumerWidget {
  const new({required this.profile, required this.own, super.key});

  final PublicProfile profile;

  /// The owner's own profile: the dashboard and the editing controls.
  final bool own;

  static const sectionsKey = Key('owner.sections');

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
    key: sectionsKey,
    padding: const EdgeInsets.fromLTRB(
      KSpacing.lg,
      0,
      KSpacing.lg,
      KSpacing.md,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (own) ...[
          const FounderDashboardCard(),
          const SizedBox(height: KSpacing.md),
        ],
        OfficialAnnouncementsCard(username: profile.username, own: own),
        JourneySection(username: profile.username, own: own),
      ],
    ),
  );
}

/// The owner page's card surface: the theme's raised surface with its
/// border (light and dark).
BoxDecoration ownerCardDecoration(BuildContext context, {Color? border}) {
  final p = context.palette;
  return BoxDecoration(
    color: p.surface,
    borderRadius: BorderRadius.circular(KRadius.lg + 2),
    border: Border.all(color: border ?? p.border),
  );
}

/// «$61.25» — the dashboard's money in its currency (Latin digits).
String ownerMoney(int minor, String currency) => NumberFormat.currency(
  locale: 'en',
  name: currency,
  symbol: currency == 'USD' ? r'$' : '$currency ',
).format(minor / 100);

/// «خاص» with a lock: what only the owner sees.
class _PrivateChip extends StatelessWidget {
  const new({this.onRed = false});

  final bool onRed;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final fg = onRed ? const Color(0xFFFFFFFF) : p.textSecondary;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: onRed ? const Color(0x33FFFFFF) : p.surfaceRaised,
        borderRadius: BorderRadius.circular(KRadius.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: KSpacing.sm,
          vertical: KSpacing.xxs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_rounded, size: 12, color: fg),
            const SizedBox(width: KSpacing.xxs),
            Text(
              context.l10n.ownerPrivate,
              style: context.textStyles.caption.copyWith(color: fg),
            ),
          ],
        ),
      ),
    );
  }
}

// ---- «لوحة المؤسس» ---------------------------------------------------------

/// «لوحة المؤسس» (mock-up 2's red card): only on the owner's own profile,
/// marked «خاص» — users online now, lives now and today's income (blurred
/// until tapped). A tap on the card opens the fuller view.
class FounderDashboardCard extends ConsumerStatefulWidget {
  const new({super.key});

  static const cardKey = Key('owner.dashboard');
  static const incomeKey = Key('owner.dashboard.income');
  static const incomeHiddenKey = Key('owner.dashboard.income.hidden');
  static const onlineKey = Key('owner.dashboard.online');
  static const livesKey = Key('owner.dashboard.lives');
  static const detailsKey = Key('owner.dashboard.details');
  static const incomeNoteKey = Key('owner.dashboard.incomeNote');

  @override
  ConsumerState<FounderDashboardCard> createState() =>
      _FounderDashboardCardState();
}

class _FounderDashboardCardState extends ConsumerState<FounderDashboardCard> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final load = ref.watch(ownerDashboardProvider);
    final data = load.value;
    const white = Color(0xFFFFFFFF);
    // Mock-up 2: «1,284» in full, «48.2K» from ten thousand.
    String count(int? n) => n == null
        ? '—'
        : (n < 10000 ? KFormat.grouped(n) : KFormat.compactLatin(n));
    return Semantics(
      container: true,
      label: l10n.ownerDashboardTitle,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: FounderDashboardCard.cardKey,
          borderRadius: BorderRadius.circular(KRadius.lg + 2),
          onTap: data == null
              ? () => ref.invalidate(ownerDashboardProvider)
              : () => unawaited(_openDetails(context, data)),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(KRadius.lg + 2),
              gradient: const LinearGradient(
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
                colors: [Color(0xFFF0303A), Color(0xFFC40812)],
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x40E50914),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(KSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0x2EFFFFFF),
                          borderRadius: BorderRadius.circular(KRadius.sm),
                        ),
                        child: const Icon(
                          Icons.grid_view_rounded,
                          size: 18,
                          color: white,
                        ),
                      ),
                      const SizedBox(width: KSpacing.sm),
                      // Shrunk rather than cut (the English title is longer).
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            l10n.ownerDashboardTitle,
                            maxLines: 1,
                            style: t.bodyStrong.copyWith(
                              color: white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: KSpacing.sm),
                      const _PrivateChip(onRed: true),
                      const Spacer(),
                      Icon(
                        Directionality.of(context) == TextDirection.rtl
                            ? Icons.chevron_left_rounded
                            : Icons.chevron_right_rounded,
                        color: white,
                      ),
                    ],
                  ),
                  const SizedBox(height: KSpacing.sm),
                  if (load.hasError && data == null)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: KSpacing.sm,
                      ),
                      child: Text(
                        l10n.ownerDashboardFailed,
                        style: t.caption.copyWith(color: white),
                      ),
                    )
                  else
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _DashTile(
                              key: FounderDashboardCard.onlineKey,
                              label: l10n.ownerDashboardOnline,
                              dot: const Color(0xFF34D399),
                              value: count(data?.onlineNow),
                            ),
                          ),
                          const SizedBox(width: KSpacing.sm),
                          Expanded(
                            child: _DashTile(
                              key: FounderDashboardCard.livesKey,
                              label: l10n.ownerDashboardLives,
                              dot: const Color(0xFFFFFFFF),
                              icon: Icons.sensors_rounded,
                              value: count(data?.liveRoomsNow),
                            ),
                          ),
                          const SizedBox(width: KSpacing.sm),
                          Expanded(
                            child: _DashTile(
                              key: FounderDashboardCard.incomeKey,
                              label: l10n.ownerDashboardIncome,
                              icon: _revealed
                                  ? Icons.visibility_rounded
                                  : Icons.visibility_off_rounded,
                              value: data == null
                                  ? '—'
                                  : ownerMoney(data.incomeMinor, data.currency),
                              hidden: !_revealed,
                              semanticsHidden: l10n.ownerDashboardIncomeHidden,
                              onTap: data == null
                                  ? null
                                  : () =>
                                        setState(() => _revealed = !_revealed),
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
      ),
    );
  }

  Future<void> _openDetails(
    BuildContext context,
    OwnerDashboard d,
  ) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheet) {
      final l10n = sheet.l10n;
      final t = sheet.textStyles;
      final p = sheet.palette;
      final tag = Localizations.localeOf(sheet).toLanguageTag();
      Widget row(String label, String value, {Key? key}) => Padding(
        key: key,
        padding: const EdgeInsets.symmetric(vertical: KSpacing.xs),
        child: Row(
          children: [
            Expanded(child: Text(label, style: t.body)),
            Text(value, textDirection: TextDirection.ltr, style: t.bodyStrong),
          ],
        ),
      );
      return SafeArea(
        child: Padding(
          key: FounderDashboardCard.detailsKey,
          padding: const EdgeInsets.fromLTRB(
            KSpacing.lg,
            0,
            KSpacing.lg,
            KSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(l10n.ownerDashboardTitle, style: t.title),
                  const SizedBox(width: KSpacing.sm),
                  const _PrivateChip(),
                ],
              ),
              const SizedBox(height: KSpacing.md),
              row(
                l10n.ownerDashboardOnlineLong(d.onlineWindowMinutes),
                KFormat.grouped(d.onlineNow),
              ),
              row(l10n.ownerDashboardLives, KFormat.grouped(d.liveRoomsNow)),
              const Divider(),
              row(
                l10n.ownerDashboardIncome,
                ownerMoney(d.incomeMinor, d.currency),
              ),
              row(
                l10n.ownerDashboardIncomeWebsite,
                ownerMoney(d.websiteMinor, d.currency),
              ),
              row(
                l10n.ownerDashboardIncomeAgents,
                ownerMoney(d.agentsMinor, d.currency),
              ),
              for (final o in d.otherCurrencies)
                row(
                  l10n.ownerDashboardIncomeOther(o.currency),
                  ownerMoney(o.amountMinor, o.currency),
                ),
              const SizedBox(height: KSpacing.xs),
              Text(
                l10n.ownerDashboardIncomeNote,
                key: FounderDashboardCard.incomeNoteKey,
                style: t.caption.copyWith(color: p.textSecondary),
              ),
              const SizedBox(height: KSpacing.sm),
              Text(
                l10n.ownerDashboardUpdated(
                  KFormat.time(d.generatedAt.toLocal(), tag),
                ),
                style: t.caption.copyWith(color: p.textSecondary),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _DashTile extends StatelessWidget {
  const new({
    required this.label,
    required this.value,
    super.key,
    this.dot,
    this.icon,
    this.hidden = false,
    this.semanticsHidden,
    this.onTap,
  });

  final String label;
  final String value;
  final Color? dot;
  final IconData? icon;
  final bool hidden;
  final String? semanticsHidden;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.textStyles;
    const white = Color(0xFFFFFFFF);
    Widget number = Text(
      value,
      maxLines: 1,
      textDirection: TextDirection.ltr,
      style: t.title.copyWith(color: white, fontWeight: FontWeight.w800),
    );
    if (hidden) {
      number = ImageFiltered(
        key: FounderDashboardCard.incomeHiddenKey,
        imageFilter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
        child: ExcludeSemantics(child: number),
      );
    }
    final tile = DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0x24FFFFFF),
        borderRadius: BorderRadius.circular(KRadius.md),
        border: Border.all(color: const Color(0x33FFFFFF)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: KSpacing.sm,
          vertical: KSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                if (dot case final c? when icon == null)
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                  ),
                if (icon case final i?)
                  Icon(i, size: 13, color: const Color(0xE6FFFFFF)),
                const SizedBox(width: KSpacing.xxs),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: t.caption.copyWith(
                        color: const Color(0xE6FFFFFF),
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: KSpacing.xxs),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: number,
            ),
          ],
        ),
      ),
    );
    if (onTap == null) return tile;
    return Semantics(
      button: true,
      label: hidden ? '$label، ${semanticsHidden ?? ''}' : '$label $value',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: tile,
      ),
    );
  }
}

// ---- «إعلانات رسمية» -------------------------------------------------------

/// The first line of a post (the announcement's title).
String officialTitleOf(Post post) {
  final line = post.text
      .split('\n')
      .map((l) => l.trim())
      .firstWhere((l) => l.isNotEmpty, orElse: () => '');
  return line;
}

/// One announcement row (mock-up 3): an icon, the title line and the time.
class OfficialPostRow extends StatelessWidget {
  const new({required this.post, required this.first, super.key, this.onEdit});

  final Post post;

  /// The owner's own view: edit the announcement's two texts.
  final VoidCallback? onEdit;

  static Key editKey(String id) => Key('owner.official.edit.$id');

  /// The first row (the newest pinned one): the megaphone in Kabso red.
  final bool first;

  static Key rowKey(String id) => Key('owner.official.$id');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final title = officialTitleOf(post);
    final when =
        KFormat.relative(
          post.publishedAt ?? post.createdAt,
          clock.now(),
          l10n,
          Localizations.localeOf(context).toLanguageTag(),
        ) ??
        l10n.feedPostJustNow;
    return InkWell(
      key: rowKey(post.id),
      onTap: () => context.push(AppRoutes.post(post.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: KSpacing.sm),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: first
                    ? KBrandColors.red500.withValues(alpha: 0.12)
                    : p.surfaceRaised,
                borderRadius: BorderRadius.circular(KRadius.sm + 2),
              ),
              child: Icon(
                first
                    ? Icons.campaign_rounded
                    : (post.pinned
                          ? Icons.push_pin_rounded
                          : Icons.verified_user_outlined),
                size: 20,
                color: first ? KBrandColors.red500 : p.textSecondary,
              ),
            ),
            const SizedBox(width: KSpacing.md),
            Expanded(
              child: Text(
                title.isEmpty ? l10n.ownerOfficialUntitled : title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.bodyStrong.copyWith(fontSize: 14),
              ),
            ),
            const SizedBox(width: KSpacing.sm),
            Text(when, style: t.caption.copyWith(color: p.textTertiary)),
            if (onEdit case final edit?)
              IconButton(
                key: editKey(post.id),
                tooltip: l10n.ownerAnnouncementEdit,
                visualDensity: VisualDensity.compact,
                onPressed: edit,
                icon: Icon(
                  Icons.edit_rounded,
                  size: 18,
                  color: p.textSecondary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// «إعلانات رسمية» (mock-up 3): the owner's official posts, pinned first,
/// then newest — three here, «عرض الكل» for the rest. Hidden for visitors
/// when there are none; the owner gets a hint to mark one.
class OfficialAnnouncementsCard extends ConsumerWidget {
  const new({required this.username, required this.own, super.key});

  final String username;
  final bool own;

  static const cardKey = Key('owner.official');
  static const seeAllKey = Key('owner.official.seeAll');
  static const emptyKey = Key('owner.official.empty');

  /// D301 follow-up: the owner's «إعلان رسمي جديد».
  static const newKey = Key('owner.official.new');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final load = ref.watch(ownerOfficialPostsProvider(username));
    final posts = load.value;
    if (posts == null || (posts.isEmpty && !own)) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: KSpacing.md),
      child: Container(
        key: cardKey,
        decoration: ownerCardDecoration(context),
        padding: const EdgeInsets.fromLTRB(
          KSpacing.md,
          KSpacing.sm,
          KSpacing.md,
          KSpacing.xs,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.push_pin_rounded,
                  size: 18,
                  color: KBrandColors.red500,
                ),
                const SizedBox(width: KSpacing.xs),
                Expanded(
                  child: Text(
                    l10n.ownerOfficialTitle,
                    style: t.bodyStrong.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                if (own)
                  IconButton(
                    key: newKey,
                    tooltip: l10n.ownerAnnouncementNew,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => unawaited(
                      showAnnouncementComposer(context, username: username),
                    ),
                    icon: const Icon(
                      Icons.add_circle_rounded,
                      color: KBrandColors.red500,
                    ),
                  ),
                if (posts.isNotEmpty)
                  TextButton(
                    key: seeAllKey,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => OfficialPostsScreen(username: username),
                      ),
                    ),
                    child: Text(
                      l10n.ownerSeeAll,
                      style: t.caption.copyWith(color: p.textSecondary),
                    ),
                  ),
              ],
            ),
            if (posts.isEmpty)
              Padding(
                key: emptyKey,
                padding: const EdgeInsets.symmetric(vertical: KSpacing.sm),
                child: Text(
                  l10n.ownerOfficialEmptyOwn,
                  style: t.caption.copyWith(color: p.textSecondary),
                ),
              )
            else
              for (final (i, post) in posts.indexed) ...[
                if (i > 0) Divider(height: 1, color: p.border),
                OfficialPostRow(
                  post: post,
                  first: i == 0,
                  onEdit: own && post.texts != null
                      ? () => unawaited(
                          showAnnouncementComposer(
                            context,
                            username: username,
                            post: post,
                          ),
                        )
                      : null,
                ),
              ],
          ],
        ),
      ),
    );
  }
}

// ---- «رحلة Kabso» ----------------------------------------------------------

/// «مارس 2026» in the viewer's language.
String journeyDate(BuildContext context, int year, int month) {
  final tag = Localizations.localeOf(context).toLanguageTag();
  return '${DateFormat.MMMM(tag).format(DateTime(year, month))} $year';
}

/// «رحلة Kabso» (mock-up 5): a vertical timeline — coloured icon nodes on a
/// gradient line, each milestone's card with its title, line, date chip and
/// «الأحدث». In the viewer's language. The owner's own view has «تعديل».
class JourneySection extends ConsumerWidget {
  const new({required this.username, required this.own, super.key});

  final String username;
  final bool own;

  static const sectionKey = Key('owner.journey');
  static const editKey = Key('owner.journey.edit');
  static const addFirstKey = Key('owner.journey.addFirst');

  static Key nodeKey(String id) => Key('owner.journey.node.$id');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final load = ref.watch(ownerJourneyProvider(username));
    final items = load.value;
    if (items == null || (items.isEmpty && !own)) {
      return const SizedBox.shrink();
    }
    Future<void> edit() => showJourneyEditor(context, username: username);
    return Column(
      key: sectionKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              l10n.ownerJourneyTitle,
              style: t.headline.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: KSpacing.sm),
            Expanded(
              child: Text(
                l10n.ownerJourneySubtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: t.caption.copyWith(color: p.textSecondary),
              ),
            ),
            if (own)
              TextButton.icon(
                key: editKey,
                onPressed: () => unawaited(edit()),
                icon: const Icon(Icons.edit_rounded, size: 16),
                label: Text(l10n.ownerEdit),
              ),
          ],
        ),
        const SizedBox(height: KSpacing.sm),
        if (items.isEmpty)
          OutlinedButton.icon(
            key: addFirstKey,
            onPressed: () => unawaited(edit()),
            icon: const Icon(Icons.add_rounded),
            label: Text(l10n.ownerJourneyAddFirst),
          )
        else
          for (final (i, m) in items.indexed)
            _JourneyRow(
              milestone: m,
              next: i + 1 < items.length ? items[i + 1] : null,
            ),
      ],
    );
  }
}

class _JourneyRow extends StatelessWidget {
  const new({required this.milestone, required this.next});

  final JourneyMilestone milestone;
  final JourneyMilestone? next;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final lang = Localizations.localeOf(context).languageCode;
    final m = milestone;
    final line = m.line(lang);
    const latestColor = Color(0xFF7C3AED);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The node and the gradient line down to the next one.
          SizedBox(
            width: 48,
            child: Column(
              children: [
                Container(
                  key: JourneySection.nodeKey(m.id),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [m.icon.light, m.icon.deep],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: m.icon.deep.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    m.icon.icon,
                    size: 22,
                    color: const Color(0xFFFFFFFF),
                  ),
                ),
                if (next case final n?)
                  Expanded(
                    child: Container(
                      width: 3,
                      margin: const EdgeInsets.symmetric(
                        vertical: KSpacing.xxs,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [m.icon.light, n.icon.light],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: KSpacing.sm),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: KSpacing.sm),
              child: Container(
                decoration:
                    ownerCardDecoration(
                      context,
                      border: m.latest
                          ? latestColor.withValues(alpha: dark ? 0.7 : 0.45)
                          : null,
                    ).copyWith(
                      color: m.latest
                          ? latestColor.withValues(alpha: dark ? 0.14 : 0.06)
                          : null,
                    ),
                padding: const EdgeInsets.all(KSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.title(lang),
                      style: t.bodyStrong.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    if (line != null && line.isNotEmpty) ...[
                      const SizedBox(height: KSpacing.xxs),
                      Text(
                        line,
                        style: t.caption.copyWith(color: p.textSecondary),
                      ),
                    ],
                    const SizedBox(height: KSpacing.sm),
                    Wrap(
                      spacing: KSpacing.xs,
                      runSpacing: KSpacing.xs,
                      children: [
                        _Chip(
                          icon: Icons.calendar_today_rounded,
                          label: journeyDate(context, m.year, m.month),
                        ),
                        if (m.latest)
                          _Chip(
                            label: l10n.ownerJourneyLatest,
                            color: latestColor,
                            foreground: const Color(0xFFFFFFFF),
                          ),
                      ],
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

class _Chip extends StatelessWidget {
  const new({required this.label, this.icon, this.color, this.foreground});

  final String label;
  final IconData? icon;
  final Color? color;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final fg = foreground ?? p.textSecondary;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? p.surfaceRaised,
        borderRadius: BorderRadius.circular(KRadius.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: KSpacing.sm,
          vertical: KSpacing.xxs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon case final i?) ...[
              Icon(i, size: 12, color: fg),
              const SizedBox(width: KSpacing.xxs),
            ],
            Text(
              label,
              style: context.textStyles.caption.copyWith(
                color: fg,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
