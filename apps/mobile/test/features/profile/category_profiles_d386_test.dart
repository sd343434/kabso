// D386 (owner 2026-11-12, contract v1.138-social, CONVENTIONS §10.175): a
// profile page per account category — only for a category the Kabso Team
// verified. Covers the 24 categories and their families, the wire models,
// each family's page (featured section, tab order, badge with a check,
// accent, pattern), an unverified category (the default look and the word),
// a Kabso Team account, the empty section (the own page's hint, nothing on
// someone else's), the grouped picker with «طلب توثيق الفئة», the post
// menu's «تثبيت في …», and no overflow at 360/393 × 1.0/1.3 in ar/en, dark
// and light.

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/models/profile_fields.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/home/presentation/widgets/feed_post_tile.dart';
import 'package:kabso_live/features/posts/application/posts_feed_controller.dart';
import 'package:kabso_live/features/profile/application/profile_grid_provider.dart';
import 'package:kabso_live/features/profile/category/category_decor.dart';
import 'package:kabso_live/features/profile/category/category_models.dart';
import 'package:kabso_live/features/profile/category/category_picker.dart';
import 'package:kabso_live/features/profile/category/category_repository.dart';
import 'package:kabso_live/features/profile/category/category_style.dart';
import 'package:kabso_live/features/profile/category/featured_section.dart';
import 'package:kabso_live/features/profile/profile_fields_view.dart';
import 'package:kabso_live/features/profile/profile_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/profile/category_profile_fixtures.dart';
import '../../helpers/fake_category_profile_repository.dart';
import '../../helpers/fake_posts_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';
import 'category_profiles_harness.dart';

/// The expected section title of each family's sample (ar).
const Map<CategoryFamily, String?> _titleAr = {
  CategoryFamily.music: 'أعمالي',
  CategoryFamily.reciter: 'تلاواتي',
  CategoryFamily.word: 'قصائدي',
  CategoryFamily.visual: 'معرضي',
  CategoryFamily.performer: 'الأكثر مشاهدة',
  CategoryFamily.sportsGames: 'إنجازاتي',
  CategoryFamily.lifestyle: 'المميز',
  CategoryFamily.public: null,
};

void main() {
  setUp(() => featuredImageFor = d386Image);
  tearDown(() => featuredImageFor = NetworkImage.new);

  group('models', () {
    test('24 categories in 8 families; the 11 of D175 kept in order', () {
      expect(AccountCategory.values, hasLength(24));
      expect(AccountCategory.values.take(11).map((c) => c.wire), [
        'SINGER',
        'MUSICIAN',
        'POET',
        'PRESENTER',
        'GAMER',
        'CONTENT_CREATOR',
        'ATHLETE',
        'ARTIST',
        'BLOGGER',
        'PUBLIC_FIGURE',
        'OTHER',
      ]);
      expect(CategoryFamily.values, hasLength(8));
      expect(
        CategoryFamily.values.expand((f) => f.categories).toSet(),
        AccountCategory.values.toSet(),
      );
      for (final f in CategoryFamily.values) {
        expect(f.categories, isNotEmpty, reason: f.name);
      }
      // An unknown value (a newer server) reads as nothing.
      expect(AccountCategory.fromWire('ASTRONAUT'), isNull);
      expect(FeaturedSection.fromWire('SOMETHING_NEW'), isNull);
    });

    test('the section of each category matches the server table', () {
      const table = {
        'SINGER': 'WORKS',
        'MUSICIAN': 'WORKS',
        'DJ': 'WORKS',
        'QURAN_RECITER': 'RECITATIONS',
        'STORYTELLER': 'STORIES',
        'POET': 'POEMS',
        'WRITER': 'ARTICLES',
        'BLOGGER': 'ARTICLES',
        'JOURNALIST': 'REPORTS',
        'PRESENTER': 'PROGRAM',
        'GAMER': 'GAMES',
        'ATHLETE': 'ACHIEVEMENTS',
        'ARTIST': 'GALLERY',
        'PHOTOGRAPHER': 'GALLERY',
        'DESIGNER': 'GALLERY',
        'CALLIGRAPHER': 'GALLERY',
        'CONTENT_CREATOR': 'MOST_VIEWED',
        'ACTOR': 'MOST_VIEWED',
        'COMEDIAN': 'MOST_VIEWED',
        'CHEF': 'HIGHLIGHTS',
        'TRAVELER': 'HIGHLIGHTS',
        'TEACHER': 'HIGHLIGHTS',
        'PUBLIC_FIGURE': null,
        'OTHER': null,
      };
      for (final c in AccountCategory.values) {
        expect(FeaturedSection.of(c)?.wire, table[c.wire], reason: c.wire);
      }
    });

    test('ProfileFeatured, FeaturedPinList and the verification read the '
        'wire', () {
      final f = ProfileFeatured.fromJson(const {
        'section': 'PROGRAM',
        'source': 'AUTO',
        'items': <Object?>[],
        'schedule': [
          {
            'id': 's1',
            'title': 'Ep 1',
            'startsAt': '2026-11-13T18:00:00.000Z',
            'createdAt': '2026-11-12T18:00:00.000Z',
            'mode': 'PODCAST',
            'podcastTopic': 'tech',
            'podcastVideo': true,
          },
        ],
      });
      expect(f.section, FeaturedSection.program);
      expect(f.source, FeaturedSource.auto);
      expect(f.schedule.single.podcast, isTrue);
      expect(f.schedule.single.video, isTrue);
      expect(
        ProfileFeatured.fromJson(const {
          'section': null,
          'source': 'NONE',
          'items': <Object?>[],
          'schedule': <Object?>[],
        }).section,
        isNull,
      );
      expect(
        FeaturedPinList.fromJson(const {
          'postIds': ['a', 'b'],
          'max': 6,
        }).postIds,
        ['a', 'b'],
      );
      final v = CategoryVerification.fromJson(const {
        'category': 'POET',
        'verified': false,
        'locked': true,
        'request': {
          'id': 'r1',
          'category': 'POET',
          'status': 'REJECTED',
          'createdAt': '2026-11-12T10:00:00.000Z',
          'decidedAt': '2026-11-12T11:00:00.000Z',
          'rejectReason': 'add a link',
        },
      });
      expect(v.category, AccountCategory.poet);
      expect(v.locked, isTrue);
      expect(v.request?.status, CategoryRequestStatus.rejected);
      expect(v.request?.rejectReason, 'add a link');
      expect(v.pending, isFalse);
    });

    test('tab order: reels first for music, recitation and performance', () {
      final all = [ProfileTab.posts, ProfileTab.reels, ProfileTab.reposts];
      for (final c in AccountCategory.values) {
        final look = CategoryLook(
          category: c,
          accent: const Color(0xFF000000),
          onAccent: const Color(0xFFFFFFFF),
        );
        final first = look.orderTabs(all).first;
        final reels = switch (c.family) {
          CategoryFamily.music ||
          CategoryFamily.reciter ||
          CategoryFamily.performer => true,
          _ => false,
        };
        expect(
          first,
          reels ? ProfileTab.reels : ProfileTab.posts,
          reason: c.wire,
        );
        // Only the tabs that exist, moved.
        expect(look.orderTabs(all).toSet(), all.toSet());
      }
    });
  });

  group("each family's page (verified)", () {
    for (final entry in d386FamilySample.entries) {
      final family = entry.key;
      final category = entry.value;
      testWidgets('${family.name}: badge, accent, pattern, section, tabs', (
        tester,
      ) async {
        await withClock(Clock.fixed(d386Now), () async {
          await pumpCategoryProfile(
            tester,
            d386Profile(category: category, ar: true),
            section: d386Featured(category, ar: true),
            language: AppLanguage.ar,
          );
        });
        // The badge with its check, in the family's accent.
        expect(find.byKey(CategoryBadge.badgeKey), findsOneWidget);
        expect(find.byKey(CategoryBadge.checkKey), findsOneWidget);
        final ctx = tester.element(find.byKey(CategoryBadge.badgeKey));
        final look = CategoryLookScope.maybeOf(ctx)!;
        expect(look.category, category);
        expect(look.accent, categoryAccent(ctx, family));
        expect(look.accent, switch (family) {
          CategoryFamily.music => KCategoryAccents.dark.music,
          CategoryFamily.reciter => KCategoryAccents.dark.reciter,
          CategoryFamily.word => KCategoryAccents.dark.word,
          CategoryFamily.visual => KCategoryAccents.dark.visual,
          CategoryFamily.performer => KCategoryAccents.dark.performer,
          CategoryFamily.sportsGames => KCategoryAccents.dark.sportsGames,
          CategoryFamily.lifestyle => KCategoryAccents.dark.lifestyle,
          CategoryFamily.public => KCategoryAccents.dark.public,
        });
        // The cover's tint and pattern.
        expect(find.byKey(CategoryCoverOverlay.overlayKey), findsOneWidget);
        // The section, named per family (none for public).
        final title = _titleAr[family];
        if (title == null) {
          expect(find.byKey(FeaturedSectionSliver.sectionKey), findsNothing);
        } else {
          expect(find.byKey(FeaturedSectionSliver.sectionKey), findsOneWidget);
          expect(
            tester
                .widget<Text>(find.byKey(FeaturedSectionSliver.titleKey))
                .data,
            title,
          );
        }
        // The tab order (scrolled into view under a tall section).
        await tester.scrollUntilVisible(
          find.byKey(ProfileScreen.tabKey(ProfileTab.posts)),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        final reelsFirst =
            family == CategoryFamily.music ||
            family == CategoryFamily.reciter ||
            family == CategoryFamily.performer;
        final posts = tester.getCenter(
          find.byKey(ProfileScreen.tabKey(ProfileTab.posts)),
        );
        final reels = tester.getCenter(
          find.byKey(ProfileScreen.tabKey(ProfileTab.reels)),
        );
        // RTL: the first tab is at the right.
        expect(reels.dx > posts.dx, reelsFirst);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets("a reciter's list shows each recitation with its length", (
      tester,
    ) async {
      await pumpCategoryProfile(
        tester,
        d386Profile(category: AccountCategory.quranReciter, ar: true),
        section: d386Featured(AccountCategory.quranReciter, ar: true),
        language: AppLanguage.ar,
      );
      expect(find.text('سورة الرحمن'), findsOneWidget);
      expect(find.text('5:12'), findsOneWidget);
      expect(find.byKey(FeaturedSectionSliver.itemKey('r3')), findsOneWidget);
    });

    testWidgets("a presenter's «برنامجي» lists the schedule", (tester) async {
      await withClock(Clock.fixed(d386Now), () async {
        await pumpCategoryProfile(
          tester,
          d386Profile(category: AccountCategory.presenter, ar: false),
          section: d386Featured(AccountCategory.presenter, ar: false),
          language: AppLanguage.en,
        );
      });
      expect(find.text('My show'), findsOneWidget);
      expect(find.text('This week’s episode'), findsOneWidget);
      expect(find.byKey(FeaturedSectionSliver.itemKey('s2')), findsOneWidget);
    });

    testWidgets('the light theme uses the light accents', (tester) async {
      await pumpCategoryProfile(
        tester,
        d386Profile(category: AccountCategory.singer, ar: false),
        section: d386Featured(AccountCategory.singer, ar: false),
        language: AppLanguage.en,
        brightness: Brightness.light,
      );
      final ctx = tester.element(find.byKey(CategoryBadge.badgeKey));
      expect(
        CategoryLookScope.maybeOf(ctx)!.accent,
        KCategoryAccents.light.music,
      );
      expect(find.text('My works'), findsOneWidget);
    });
  });

  group('the default look', () {
    testWidgets('an unverified singer: the word, no badge, no section, '
        'the usual tabs', (tester) async {
      final repo = await pumpCategoryProfile(
        tester,
        d386Profile(
          category: AccountCategory.singer,
          ar: true,
          verified: false,
        ),
        section: d386Featured(AccountCategory.singer, ar: true),
        language: AppLanguage.ar,
      );
      expect(find.byKey(CategoryBadge.badgeKey), findsNothing);
      expect(find.byKey(CategoryCoverOverlay.overlayKey), findsNothing);
      expect(find.byKey(FeaturedSectionSliver.sectionKey), findsNothing);
      // Not even asked for.
      expect(repo.calls.where((c) => c.startsWith('featured:')), isEmpty);
      final line = tester.widget<Text>(find.byKey(ProfileFieldsLine.lineKey));
      expect(line.data, 'مغنٍّ');
      final posts = tester.getCenter(
        find.byKey(ProfileScreen.tabKey(ProfileTab.posts)),
      );
      final reels = tester.getCenter(
        find.byKey(ProfileScreen.tabKey(ProfileTab.reels)),
      );
      expect(posts.dx > reels.dx, isTrue);
    });

    testWidgets('a Kabso Team account keeps the default look (D367)', (
      tester,
    ) async {
      await pumpCategoryProfile(
        tester,
        d386Profile(
          category: AccountCategory.poet,
          ar: true,
        ).copyWith(kabsoTeam: true, staffId: 'Kabso07'),
        section: d386Featured(AccountCategory.poet, ar: true),
        language: AppLanguage.ar,
      );
      expect(find.byKey(CategoryBadge.badgeKey), findsNothing);
      expect(find.byKey(FeaturedSectionSliver.sectionKey), findsNothing);
      expect(find.text('شاعر'), findsNothing);
    });

    testWidgets('a verified category with an empty section: nothing on '
        "someone else's page", (tester) async {
      await pumpCategoryProfile(
        tester,
        d386Profile(category: AccountCategory.writer, ar: true),
        section: const ProfileFeatured(section: FeaturedSection.articles),
        language: AppLanguage.ar,
      );
      expect(find.byKey(CategoryBadge.badgeKey), findsOneWidget);
      expect(find.byKey(FeaturedSectionSliver.sectionKey), findsNothing);
    });

    testWidgets('the own empty section shows how to pin', (tester) async {
      await pumpOwnCategoryProfile(
        tester,
        d386Me(ar: true, category: AccountCategory.writer),
        section: const ProfileFeatured(section: FeaturedSection.articles),
        language: AppLanguage.ar,
      );
      expect(find.byKey(FeaturedSectionSliver.sectionKey), findsOneWidget);
      expect(find.byKey(FeaturedSectionSliver.emptyKey), findsOneWidget);
      expect(find.text('مقالاتي'), findsOneWidget);
      expect(find.byKey(CategoryBadge.badgeKey), findsOneWidget);
    });

    testWidgets('the own pinned section offers «ترتيب» and saves the order', (
      tester,
    ) async {
      final repo = await pumpOwnCategoryProfile(
        tester,
        d386Me(ar: false, category: AccountCategory.photographer),
        section: d386Featured(AccountCategory.photographer, ar: false),
        language: AppLanguage.en,
        pins: const ['g1', 'g2', 'g3', 'g4', 'g5', 'g6'],
      );
      await tester.ensureVisible(find.byKey(FeaturedSectionSliver.reorderKey));
      await tester.tap(find.byKey(FeaturedSectionSliver.reorderKey));
      await tester.pumpAndSettle();
      expect(find.byKey(FeaturedReorderSheet.listKey), findsOneWidget);
      await tester.tap(find.byKey(FeaturedReorderSheet.saveKey));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('setPins:g1,g2,g3,g4,g5,g6'));
    });
  });

  group('the category picker', () {
    Future<FakeCategoryProfileRepository> pumpPicker(
      WidgetTester tester, {
      required AppLanguage language,
      AccountCategory? current = AccountCategory.singer,
      bool verified = false,
      bool locked = false,
      CategoryVerification? state,
    }) async {
      tester.view
        ..physicalSize = const Size(393, 852) * 3
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final repo = FakeCategoryProfileRepository(
        state:
            state ??
            CategoryVerification(
              category: current,
              verified: verified,
              locked: locked,
            ),
      );
      await pumpScreen(
        tester,
        Scaffold(
          body: CategoryPickerSheet(
            current: current,
            verified: verified,
            locked: locked,
          ),
        ),
        language: language,
        overrides: [categoryProfileRepositoryProvider.overrideWithValue(repo)],
      );
      await tester.pumpAndSettle();
      return repo;
    }

    testWidgets('lists the 24 categories in their 8 groups', (tester) async {
      await pumpPicker(tester, language: AppLanguage.ar);
      // A tall view builds the whole list at once.
      tester.view.physicalSize = const Size(393, 3200) * 3;
      await tester.pumpAndSettle();
      for (final f in CategoryFamily.values) {
        expect(find.byKey(CategoryPickerSheet.family(f)), findsOneWidget);
        for (final c in f.categories) {
          expect(find.byKey(CategoryPickerSheet.option(c)), findsOneWidget);
        }
      }
      expect(find.byKey(CategoryPickerSheet.none), findsOneWidget);
      expect(find.text('بدون فئة'), findsOneWidget);
      expect(find.text('قارئ قرآن'), findsOneWidget);
      expect(find.text('التلاوة والرواية'), findsOneWidget);
      // The groups come in the families' order.
      final ys = [
        for (final f in CategoryFamily.values)
          tester.getTopLeft(find.byKey(CategoryPickerSheet.family(f))).dy,
      ];
      expect([...ys]..sort(), ys);
    });

    testWidgets('«طلب توثيق الفئة» sends a request, then offers to cancel', (
      tester,
    ) async {
      final repo = await pumpPicker(tester, language: AppLanguage.ar);
      expect(find.text('طلب توثيق الفئة'), findsOneWidget);
      await tester.tap(find.byKey(CategoryPickerSheet.requestKey));
      await tester.pumpAndSettle();
      expect(repo.calls, ['request']);
      expect(find.text('طلب التوثيق قيد المراجعة'), findsOneWidget);
      await tester.tap(find.byKey(CategoryPickerSheet.cancelKey));
      await tester.pumpAndSettle();
      expect(repo.calls, ['request', 'cancel']);
      expect(find.byKey(CategoryPickerSheet.requestKey), findsOneWidget);
    });

    testWidgets("a rejection shows the team's reason", (tester) async {
      await pumpPicker(
        tester,
        language: AppLanguage.en,
        state: const CategoryVerification(
          category: AccountCategory.singer,
          request: CategoryRequest(
            id: 'r1',
            status: CategoryRequestStatus.rejected,
            rejectReason: 'Add a link to your work',
          ),
        ),
      );
      expect(
        find.text('Your request was not accepted: Add a link to your work'),
        findsOneWidget,
      );
    });

    testWidgets('verified: the check and the warning; locked: read-only', (
      tester,
    ) async {
      await pumpPicker(tester, language: AppLanguage.en, verified: true);
      expect(find.byKey(CategoryPickerSheet.verifiedKey), findsOneWidget);
      expect(
        find.text('Changing the category removes the verification.'),
        findsOneWidget,
      );
      await pumpPicker(tester, language: AppLanguage.en, locked: true);
      expect(find.byKey(CategoryPickerSheet.lockedKey), findsOneWidget);
      final tile = tester.widget<RadioListTile<AccountCategory?>>(
        find.byKey(CategoryPickerSheet.option(AccountCategory.singer)),
      );
      expect(tile.enabled, isFalse);
    });
  });

  group('the post menu', () {
    testWidgets('a verified singer pins their own post in «أعمالي»', (
      tester,
    ) async {
      final repo = FakeCategoryProfileRepository();
      final me = d386Me(ar: true, category: AccountCategory.singer);
      await pumpScreen(
        tester,
        Scaffold(
          body: ListView(
            children: [
              FeedPostTile(
                post: feedPostOf(
                  testPost('own1', username: me.username, isSelf: true),
                ),
              ),
            ],
          ),
        ),
        language: AppLanguage.ar,
        postsRepository: FakePostsRepository(),
        overrides: [
          secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
          currentUserProvider.overrideWithValue(me),
          categoryProfileRepositoryProvider.overrideWithValue(repo),
        ],
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(FeedPostTile.moreKey).first);
      await tester.pumpAndSettle();
      expect(find.text('تثبيت في «أعمالي»'), findsOneWidget);
      await tester.tap(find.byKey(FeedPostTile.featureActionKey));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('pin:own1'));
      // Now it is featured: the menu offers to unpin.
      await tester.tap(find.byKey(FeedPostTile.moreKey).first);
      await tester.pumpAndSettle();
      expect(find.text('إلغاء التثبيت من «أعمالي»'), findsOneWidget);
    });

    testWidgets('no «تثبيت في …» without a verified category', (tester) async {
      await pumpScreen(
        tester,
        Scaffold(
          body: ListView(
            children: [
              FeedPostTile(post: feedPostOf(testPost('own2', isSelf: true))),
            ],
          ),
        ),
        language: AppLanguage.ar,
        postsRepository: FakePostsRepository(),
        overrides: [
          secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
          currentUserProvider.overrideWithValue(
            d386Me(ar: true, category: AccountCategory.singer, verified: false),
          ),
          categoryProfileRepositoryProvider.overrideWithValue(
            FakeCategoryProfileRepository(),
          ),
        ],
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(FeedPostTile.moreKey).first);
      await tester.pumpAndSettle();
      expect(find.byKey(FeedPostTile.featureActionKey), findsNothing);
    });
  });

  group('no overflow', () {
    const sizes = [Size(360, 800), Size(393, 852)];
    const scales = [1.0, 1.3];
    for (final entry in d386FamilySample.entries) {
      for (final language in [AppLanguage.ar, AppLanguage.en]) {
        testWidgets('${entry.key.name} ${language.name}', (tester) async {
          for (final size in sizes) {
            for (final scale in scales) {
              for (final brightness in Brightness.values) {
                await withClock(Clock.fixed(d386Now), () async {
                  await pumpCategoryProfile(
                    tester,
                    d386Profile(
                      category: entry.value,
                      ar: language == AppLanguage.ar,
                    ),
                    section: d386Featured(
                      entry.value,
                      ar: language == AppLanguage.ar,
                    ),
                    language: language,
                    brightness: brightness,
                    size: size,
                    textScale: scale,
                  );
                  // The section, scrolled into view.
                  final section = find.byKey(FeaturedSectionSliver.sectionKey);
                  if (section.evaluate().isNotEmpty) {
                    await tester.ensureVisible(section);
                    await tester.pumpAndSettle();
                  }
                });
                expect(
                  tester.takeException(),
                  isNull,
                  reason: '$size ×$scale $brightness',
                );
              }
            }
          }
        });
      }
    }
  });
}
