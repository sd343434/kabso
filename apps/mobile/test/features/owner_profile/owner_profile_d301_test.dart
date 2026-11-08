// D301 (owner, §10.112): the app owner's profile «صفحة صاحب البرنامج» —
// features chosen from five mock-ups:
//
// - the bilingual video cover (mock-up 4): the app's Arabic → the Arabic
//   video, anything else → the English one, one → everyone sees it, none →
//   the cover picture; looping, plays only when half on screen, the mute
//   button; D307: with sound from the start, no «فيديو» pill, paused under
//   another page and in the background; reduce motion: never by itself (a
//   round play button);
// - D307: no «فريق كابسو» badge under the founder's name (other staff keep
//   it); the bilingual bio (the app's language, else the default text) and
//   «بايو المؤسس» in «لوحة المؤسس»; «اقترح ميزة / أبلغ» outline only;
// - «رحلة Kabso» (mock-up 5): the timeline in order, in the viewer's
//   language, the nodes at the reading start, «الأحدث»; the owner edits it
//   in the app (owner: «في التطبيق») — add, edit, delete, ▲ / ▼;
// - «إعلانات رسمية» (mock-up 3): three rows, «عرض الكل»;
// - «لوحة المؤسس» (mock-up 2): only on the owner's own view, «خاص», the
//   income blurred until tapped, the fuller view;
// - «متابعة المؤسس» and «اقترح ميزة / أبلغ عن موظف» for visitors; the sheet's
//   two forms;
// - any other profile is unchanged.
//
// With D301_CAPTURE_DIR set, the capture group writes PNGs there (not
// committed).

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/models/verification_badge.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/features/auth/domain/entities.dart';
import 'package:kabso_live/features/auth/presentation/auth_controller.dart';
import 'package:kabso_live/features/home/presentation/widgets/feed_post_tile.dart';
import 'package:kabso_live/features/levels/application/levels_providers.dart';
import 'package:kabso_live/features/live/presentation/widgets/kabso_team_badge.dart';
import 'package:kabso_live/features/notifications/domain/notification_models.dart';
import 'package:kabso_live/features/notifications/presentation/notifications_screen.dart';
import 'package:kabso_live/features/owner_profile/data/owner_profile_repository.dart';
import 'package:kabso_live/features/owner_profile/domain/owner_models.dart';
import 'package:kabso_live/features/owner_profile/presentation/announcement_composer.dart';
import 'package:kabso_live/features/owner_profile/presentation/journey_editor.dart';
import 'package:kabso_live/features/owner_profile/presentation/official_label.dart';
import 'package:kabso_live/features/owner_profile/presentation/owner_actions.dart';
import 'package:kabso_live/features/owner_profile/presentation/owner_bio_editor.dart';
import 'package:kabso_live/features/owner_profile/presentation/owner_cover_video.dart';
import 'package:kabso_live/features/owner_profile/presentation/owner_cover_video_editor.dart';
import 'package:kabso_live/features/owner_profile/presentation/owner_feedback_sheet.dart';
import 'package:kabso_live/features/owner_profile/presentation/owner_profit.dart';
import 'package:kabso_live/features/owner_profile/presentation/owner_sections.dart';
import 'package:kabso_live/features/posts/data/media_repository.dart';
import 'package:kabso_live/features/posts/data/video_source.dart';
import 'package:kabso_live/features/posts/domain/post_models.dart';
import 'package:kabso_live/features/profile/application/profile_grid_provider.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:kabso_live/features/profile/domain/profile_models.dart';
import 'package:kabso_live/features/profile/profile_cover_header.dart';
import 'package:kabso_live/features/profile/profile_screen.dart';
import 'package:kabso_live/features/profile/profile_verification_badge.dart';
import 'package:kabso_live/features/profile/public_profile_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/owner/owner_fixtures.dart';
import '../../helpers/fake_inline_video.dart';
import '../../helpers/fake_media_repository.dart';
import '../../helpers/fake_owner_profile_repository.dart';
import '../../helpers/fake_posts_repository.dart' show postJson;
import '../../helpers/fake_profile_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';
import '../profile/profile_cover_d278_test.dart' show coverBytes, insets;

/// The fixed "now" of the relative times.
final DateTime d301Now = DateTime.utc(2026, 11, 7, 9, 41);

/// A widget test run wholly at [d301Now] (every build, not only the pumps
/// inside `withClock`): the relative times («منذ يومين») and the dates do
/// not move with the real day.
void testD301(
  String description,
  Future<void> Function(WidgetTester tester) body, {
  Object? tags,
}) => testWidgets(
  description,
  (tester) => withClock(Clock.fixed(d301Now), () => body(tester)),
  tags: tags,
);

late Uint8List d301Poster;

/// Opens [screen] over a first page, so the back button shows.
class D301Pushed extends StatefulWidget {
  const new(this.screen, {super.key});

  final Widget screen;

  @override
  State<D301Pushed> createState() => _D301PushedState();
}

class _D301PushedState extends State<D301Pushed> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).push(
        PageRouteBuilder<void>(
          pageBuilder: (_, _, _) => widget.screen,
          transitionDuration: Duration.zero,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold();
}

FakeOwnerProfileRepository d301Repo({
  required bool ar,
  bool empty = false,
  bool dashboardFails = false,
}) => FakeOwnerProfileRepository(
  journey: empty ? const [] : ownerJourney,
  official: empty ? const [] : ownerOfficialPosts(ar: ar, now: d301Now),
  dashboardData: ownerDashboard(),
  dashboardFails: dashboardFails,
  staff: ownerFeedbackStaff,
  profitData: ownerProfit(),
  costs: ownerFixedCosts,
);

List<Override> _common(FakeOwnerProfileRepository repo) => [
  secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
  profileLevelsProvider.overrideWith((ref, _) async => const []),
  profileGridProvider.overrideWith(
    (ref, _) =>
        FeedItems([for (var i = 0; i < 12; i++) const ProfileGridItem()]),
  ),
  ownerProfileRepositoryProvider.overrideWithValue(repo),
];

/// A visitor on the owner's page.
Future<FakeOwnerProfileRepository> pumpOwnerVisitor(
  WidgetTester tester, {
  required AppLanguage language,
  Brightness brightness = Brightness.light,
  PublicProfile? profile,
  FakeOwnerProfileRepository? repo,
  FakeInlineVideos? videos,
  bool still = true,
  GoldenViewport viewport = GoldenViewport.phone,
}) async {
  final ar = language == AppLanguage.ar;
  final r = repo ?? d301Repo(ar: ar);
  setViewport(tester, viewport);
  insets(tester);
  await withClock(Clock.fixed(d301Now), () async {
    await pumpScreen(
      tester,
      const D301Pushed(PublicProfileScreen(username: 'kabso')),
      language: language,
      brightness: brightness,
      disableAnimations: still,
      inlineVideos: videos,
      overrides: [
        profileRepositoryProvider.overrideWithValue(
          FakeProfileRepository(profile ?? ownerProfile(ar: ar)),
        ),
        ..._common(r),
      ],
    );
    await tester.pumpAndSettle();
  });
  return r;
}

User ownerMe({required bool ar}) => User(
  id: 'owner-0',
  email: 'owner@example.invalid',
  emailVerified: true,
  username: 'kabso',
  displayName: ar ? 'مؤسس كابسو' : 'Kabso Founder',
  locale: ar ? 'ar' : 'en',
  role: UserRole.admin,
  isPrivate: false,
  createdAt: DateTime.utc(2026),
  bio: ar ? 'مؤسس كابسو لايف' : 'Founder of Kabso Live',
  kabsoTeam: true,
  staffId: 'Kabso',
  verification: VerificationBadge.owner,
);

/// The owner on his own profile.
Future<FakeOwnerProfileRepository> pumpOwnerOwn(
  WidgetTester tester, {
  required AppLanguage language,
  Brightness brightness = Brightness.light,
  FakeOwnerProfileRepository? repo,
  bool videos = true,
  GoldenViewport viewport = GoldenViewport.phone,
  PublicProfile? stats,
}) async {
  final ar = language == AppLanguage.ar;
  final r = repo ?? d301Repo(ar: ar);
  setViewport(tester, viewport);
  insets(tester);
  await withClock(Clock.fixed(d301Now), () async {
    await pumpScreen(
      tester,
      const D301Pushed(ProfileScreen()),
      language: language,
      brightness: brightness,
      disableAnimations: true,
      overrides: [
        meProvider.overrideWith((ref) => ownerMe(ar: ar)),
        profileStatsProvider.overrideWith(
          (ref, username) =>
              stats ??
              ownerProfile(
                ar: ar,
                self: true,
                videos: videos ? ownerVideos : null,
              ),
        ),
        ..._common(r),
      ],
    );
    await tester.pumpAndSettle();
  });
  return r;
}

/// D301 follow-up: the feed's top — the owner's latest announcement (in the
/// app's language, as the server sends it) above an ordinary post.
Future<void> pumpFeedTop(
  WidgetTester tester, {
  required AppLanguage language,
  Brightness brightness = Brightness.light,
}) async {
  final ar = language == AppLanguage.ar;
  setViewport(tester, GoldenViewport.phone);
  insets(tester);
  await withClock(Clock.fixed(d301Now), () async {
    await pumpScreen(
      tester,
      Scaffold(
        body: SafeArea(
          child: ListView(
            children: [
              FeedPostTile(
                post: FeedPostData(
                  authorName: ar ? 'مؤسس كابسو' : 'Kabso Founder',
                  authorUsername: 'kabso',
                  postedAt: d301Now.subtract(const Duration(hours: 3)),
                  postId: 'pa1',
                  text: ar
                      ? 'إطلاق الإصدار 2.0 من كابسو لايف — '
                            'بثوث أسرع وهدايا جديدة'
                      : 'Kabso Live 2.0 is here — faster lives and new gifts',
                  official: true,
                  isFollowingAuthor: false,
                ),
              ),
              FeedPostTile(
                post: FeedPostData(
                  authorName: ar ? 'سارة' : 'Sara',
                  authorUsername: 'sara',
                  postedAt: d301Now.subtract(const Duration(hours: 5)),
                  postId: 'p2',
                  text: ar ? 'مساء الخير يا أصدقاء' : 'Good evening, friends',
                ),
              ),
            ],
          ),
        ),
      ),
      language: language,
      brightness: brightness,
      disableAnimations: true,
      overrides: [
        ownerProfileRepositoryProvider.overrideWithValue(d301Repo(ar: ar)),
      ],
    );
    await tester.pumpAndSettle();
  });
}

/// D301 follow-up: the owner's composer over his own profile, filled.
Future<FakeOwnerProfileRepository> pumpComposer(
  WidgetTester tester, {
  required AppLanguage language,
  Brightness brightness = Brightness.light,
  bool fill = true,
}) async {
  final repo = await pumpOwnerOwn(
    tester,
    language: language,
    brightness: brightness,
  );
  await _scrollTo(tester, find.byKey(OfficialAnnouncementsFeed.newKey));
  await tester.tap(find.byKey(OfficialAnnouncementsFeed.newKey));
  await tester.pumpAndSettle();
  if (fill) {
    await tester.enterText(
      find.byKey(AnnouncementComposer.arKey),
      'إطلاق الإصدار 2.0 من كابسو لايف — بثوث أسرع وهدايا جديدة',
    );
    await tester.enterText(
      find.byKey(AnnouncementComposer.enKey),
      'Kabso Live 2.0 is here — faster lives and new gifts',
    );
    await tester.pumpAndSettle();
  }
  return repo;
}

Future<void> _end(WidgetTester tester) => tester.pumpWidget(const SizedBox());

Future<void> _scrollTo(
  WidgetTester tester,
  Finder finder, {
  double at = 280,
}) async {
  await tester.scrollUntilVisible(
    finder,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  // Clear of the bar and the pinned tabs: [at] from the top.
  final top = tester.getRect(finder.first).top;
  if ((top - at).abs() > 1) {
    await tester.drag(find.byType(Scrollable).first, Offset(0, at - top));
    await tester.pumpAndSettle();
  }
}

void main() {
  setUpAll(() async {
    await loadAppFonts();
    d301Poster = await paintOwnerPoster();
  });
  setUp(() {
    profileCoverImageFor = (_) => MemoryImage(coverBytes);
    ownerPosterImageFor = (_) => MemoryImage(d301Poster);
  });
  tearDown(() {
    profileCoverImageFor = NetworkImage.new;
    ownerPosterImageFor = NetworkImage.new;
  });

  group('the models', () {
    test('the cover video by the app language, with the fallback', () {
      expect(ownerVideos.pick('ar')?.url, ownerVideoAr);
      expect(ownerVideos.pick('en')?.url, ownerVideoEn);
      expect(ownerVideos.pick('fr')?.url, ownerVideoEn);
      const onlyAr = OwnerCoverVideo(
        ar: CoverVideoVariant(url: 'a', posterUrl: 'p', durationMs: 1),
      );
      const onlyEn = OwnerCoverVideo(
        en: CoverVideoVariant(url: 'e', posterUrl: 'p', durationMs: 1),
      );
      expect(onlyAr.pick('en')?.url, 'a');
      expect(onlyEn.pick('ar')?.url, 'e');
      expect(const OwnerCoverVideo().pick('ar'), isNull);
    });

    test('PublicProfile reads kabsoOwner and coverVideo (absent → none)', () {
      final json = jsonDecode(
        jsonEncode(ownerProfile(ar: true).toJson()),
      ) as Map<String, dynamic>;
      final back = PublicProfile.fromJson(json);
      expect(back.kabsoOwner, isTrue);
      expect(back.coverVideo, ownerVideos);
      final plain = PublicProfile.fromJson(
        {...json}
          ..remove('kabsoOwner')
          ..remove('coverVideo'),
      );
      expect(plain.kabsoOwner, isFalse);
      expect(plain.coverVideo, isNull);
    });

    test('a milestone reads its texts in the viewer language; '
        'an unknown icon is a flag', () {
      final m = JourneyMilestone.fromJson(const {
        'id': 'x',
        'titleAr': 'عنوان',
        'titleEn': 'Title',
        'lineAr': null,
        'lineEn': 'Line',
        'year': 2026,
        'month': 3,
        'icon': 'unknown',
        'latest': true,
        'position': 0,
      });
      expect(m.title('ar'), 'عنوان');
      expect(m.title('en'), 'Title');
      expect(m.line('ar'), isNull);
      expect(m.icon, JourneyIcon.flag);
      expect(m.toBody()['icon'], 'flag');
    });

    test('OWNER_FEEDBACK_NEW and its target are known', () {
      expect(
        NotificationType.fromWire('OWNER_FEEDBACK_NEW'),
        NotificationType.ownerFeedbackNew,
      );
      expect(NotificationType.ownerFeedbackNew.isSystem, isTrue);
      final target = NotificationTarget.fromJson(const {
        'type': 'OWNER_FEEDBACK',
        'id': 'f1',
        'postId': null,
        'thumbUrl': null,
        'text': null,
        'feedbackKind': 'STAFF_REPORT',
      });
      expect(target.type, NotificationTargetType.ownerFeedback);
      expect(target.feedbackKind, 'STAFF_REPORT');
    });

    test('the dashboard money in dollars, Latin digits', () {
      expect(ownerMoney(843125, 'USD'), r'$8,431.25');
    });
  });

  group("a visitor on the owner's page", () {
    for (final language in AppLanguage.values) {
      final ar = language == AppLanguage.ar;
      testD301('${language.name}: the poster of the ${language.name} video, '
          'follow and suggest, announcements and the journey; no dashboard', (
        tester,
      ) async {
        await pumpOwnerVisitor(tester, language: language);
        expect(tester.takeException(), isNull);
        expect(find.byKey(OwnerCoverVideoLayer.layerKey), findsOneWidget);
        final poster = tester.widget<Image>(
          find.byKey(OwnerCoverVideoLayer.posterKey),
        );
        expect(poster.image, isA<MemoryImage>());
        // D307: no «فيديو» pill — neither the word nor the length.
        expect(find.byKey(const Key('owner.coverVideo.pill')), findsNothing);
        expect(find.text(ar ? '0:24' : '0:18'), findsNothing);
        expect(find.text(ar ? 'فيديو' : 'Video'), findsNothing);
        expect(
          tester
              .widget<OwnerCoverVideoLayer>(find.byType(OwnerCoverVideoLayer))
              .video
              .url,
          ar ? ownerVideoAr : ownerVideoEn,
        );
        expect(find.byKey(OwnerVisitorActions.followKey), findsOneWidget);
        expect(find.byKey(OwnerVisitorActions.feedbackKey), findsOneWidget);
        expect(
          find.text(ar ? 'متابعة المؤسس' : 'Follow the founder'),
          findsOneWidget,
        );
        expect(find.byKey(FounderDashboardCard.cardKey), findsNothing);
        await _scrollTo(tester, find.byKey(JourneySection.nodeKey('m5')));
        expect(
          find.text(ar ? 'إطلاق صناع المحتوى' : 'Content creators launch'),
          findsOneWidget,
        );
        expect(find.text(ar ? 'الأحدث' : 'Latest'), findsOneWidget);
        expect(find.text(ar ? 'أكتوبر 2026' : 'October 2026'), findsOneWidget);
        // The nodes at the reading start: right in Arabic, left in English.
        final node = tester.getRect(find.byKey(JourneySection.nodeKey('m5')));
        final card = tester.getRect(
          find.text(ar ? 'إطلاق صناع المحتوى' : 'Content creators launch'),
        );
        expect(ar ? node.left > card.right : node.right < card.left, isTrue);
        // No editing for a visitor.
        expect(find.byKey(JourneySection.editKey), findsNothing);
        // D307 follow-up: then the announcements in full, under the journey,
        // as feed cards, newest (pinned) first.
        await _scrollTo(
          tester,
          find.byKey(OfficialAnnouncementsFeed.sectionKey),
        );
        final journey = tester.getRect(find.byKey(JourneySection.sectionKey));
        expect(
          tester.getRect(find.byKey(OfficialAnnouncementsFeed.sectionKey)).top,
          greaterThan(journey.bottom - 1),
        );
        for (final id in ['o1', 'o2', 'o3']) {
          await _scrollTo(
            tester,
            find.byKey(OfficialAnnouncementsFeed.cardKey(id)),
          );
          expect(
            find.descendant(
              of: find.byKey(OfficialAnnouncementsFeed.cardKey(id)),
              matching: find.byType(FeedPostTile),
            ),
            findsOneWidget,
          );
        }
        expect(find.byKey(OfficialAnnouncementsFeed.newKey), findsNothing);
        expect(
          find.byKey(OfficialAnnouncementsFeed.editKey('o1')),
          findsNothing,
        );
        await _end(tester);
      });
    }

    testD301('only one video: an English viewer sees the Arabic one', (
      tester,
    ) async {
      await pumpOwnerVisitor(
        tester,
        language: AppLanguage.en,
        profile: ownerProfile(
          ar: false,
          videos: OwnerCoverVideo(ar: ownerVideos.ar),
        ),
      );
      expect(find.byKey(OwnerCoverVideoLayer.layerKey), findsOneWidget);
      expect(
        tester
            .widget<OwnerCoverVideoLayer>(find.byType(OwnerCoverVideoLayer))
            .video
            .url,
        ownerVideoAr,
      );
      await _end(tester);
    });

    testD301('no video: the cover picture, as on any profile', (tester) async {
      await pumpOwnerVisitor(
        tester,
        language: AppLanguage.ar,
        profile: ownerProfile(
          ar: true,
          videos: null,
        ).copyWith(coverUrl: 'https://c/x.jpg'),
      );
      expect(find.byKey(OwnerCoverVideoLayer.layerKey), findsNothing);
      expect(find.byKey(ProfileCoverHeader.coverKey), findsOneWidget);
      await _end(tester);
    });

    testD301(
      'D307: the video plays by itself WITH sound when on screen, the mute '
      'button silences it, and it pauses off-screen',
      (tester) async {
        final videos = FakeInlineVideos();
        await pumpOwnerVisitor(
          tester,
          language: AppLanguage.ar,
          videos: videos,
          still: false,
        );
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump();
        expect(videos.created.map((v) => v.url), [ownerVideoAr]);
        final v = videos.created.single;
        expect(v.plays, greaterThan(0));
        expect(v.volumes.first, 1);
        expect(find.byKey(OwnerCoverVideoLayer.surfaceKey), findsOneWidget);
        // No play button without reduce motion; the sound button says mute.
        expect(find.byKey(OwnerCoverVideoLayer.playKey), findsNothing);
        expect(find.bySemanticsLabel('Mute'), findsNothing);
        await tester.tap(find.byKey(OwnerCoverVideoLayer.muteKey));
        await tester.pump();
        expect(v.volumes.last, 0);
        // Scrolled away: paused.
        await tester.drag(
          find.byType(Scrollable).first,
          const Offset(0, -1400),
        );
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump();
        expect(v.pauses, greaterThan(0));
        expect(v.state.playing, isFalse);
        await _end(tester);
      },
    );

    testD301('reduce motion: the poster stays until the play button is '
        'tapped (D307: a round button, not the pill)', (tester) async {
      final videos = FakeInlineVideos();
      await pumpOwnerVisitor(tester, language: AppLanguage.en, videos: videos);
      await tester.pump(const Duration(milliseconds: 600));
      expect(videos.created, isEmpty);
      expect(find.byKey(OwnerCoverVideoLayer.playKey), findsOneWidget);
      await tester.tap(find.byKey(OwnerCoverVideoLayer.playKey));
      await tester.pump();
      await tester.pump();
      expect(videos.created.map((v) => v.url), [ownerVideoEn]);
      expect(videos.created.single.plays, 1);
      await _end(tester);
    });

    testD301('«متابعة المؤسس» follows; then «تتابع المؤسس»', (tester) async {
      await pumpOwnerVisitor(tester, language: AppLanguage.ar);
      await tester.tap(find.byKey(OwnerVisitorActions.followKey));
      await tester.pumpAndSettle();
      expect(find.text('تتابع المؤسس'), findsOneWidget);
      await _end(tester);
    });

    testD301('D307 follow-up: the announcements page by page (the next '
        'page when the list reaches its end), each in the app language', (
      tester,
    ) async {
      final repo = d301Repo(ar: false)
        ..official = [
          for (var i = 0; i < 13; i++)
            Post.fromJson({
              ...postJson('n$i', text: 'نص $i'),
              'official': true,
              'texts': {'ar': 'نص $i', 'en': 'Text $i'},
            }),
        ];
      await pumpOwnerVisitor(tester, language: AppLanguage.en, repo: repo);
      await _scrollTo(
        tester,
        find.byKey(OfficialAnnouncementsFeed.cardKey('n0')),
      );
      // The English caption of a bilingual announcement.
      expect(
        find.descendant(
          of: find.byKey(OfficialAnnouncementsFeed.cardKey('n0')),
          matching: find.textContaining('Text 0'),
        ),
        findsOneWidget,
      );
      expect(repo.calls, contains('official:kabso:10:'));
      await _scrollTo(
        tester,
        find.byKey(OfficialAnnouncementsFeed.cardKey('n12')),
      );
      expect(repo.calls, contains('official:kabso:10:10'));
      expect(
        find.byKey(OfficialAnnouncementsFeed.cardKey('n12')),
        findsOneWidget,
      );
      await _end(tester);
    });

    testD301('D307 follow-up: the announcements fail: a retry for the '
        'owner, nothing for a visitor', (tester) async {
      final repo = d301Repo(ar: true)..officialFails = true;
      await pumpOwnerOwn(tester, language: AppLanguage.ar, repo: repo);
      await _scrollTo(tester, find.byKey(OfficialAnnouncementsFeed.errorKey));
      expect(find.byKey(OfficialAnnouncementsFeed.errorKey), findsOneWidget);
      repo.officialFails = false;
      await tester.tap(
        find.descendant(
          of: find.byKey(OfficialAnnouncementsFeed.errorKey),
          matching: find.byType(TextButton),
        ),
      );
      await tester.pumpAndSettle();
      await _scrollTo(
        tester,
        find.byKey(OfficialAnnouncementsFeed.cardKey('o1')),
      );
      expect(
        find.byKey(OfficialAnnouncementsFeed.cardKey('o1')),
        findsOneWidget,
      );
      await _end(tester);
      final visitor = d301Repo(ar: true)..officialFails = true;
      await pumpOwnerVisitor(tester, language: AppLanguage.ar, repo: visitor);
      expect(find.byKey(OfficialAnnouncementsFeed.sectionKey), findsNothing);
      expect(find.byKey(OfficialAnnouncementsFeed.errorKey), findsNothing);
      await _end(tester);
    });

    testD301('an owner with no announcements and no journey: '
        'neither section for a visitor', (tester) async {
      await pumpOwnerVisitor(
        tester,
        language: AppLanguage.ar,
        repo: d301Repo(ar: true, empty: true),
      );
      expect(find.byKey(OfficialAnnouncementsFeed.sectionKey), findsNothing);
      expect(find.byKey(JourneySection.sectionKey), findsNothing);
      await _end(tester);
    });

    testD301('any other profile is unchanged (no owner parts)', (tester) async {
      await pumpOwnerVisitor(
        tester,
        language: AppLanguage.ar,
        profile: ownerProfile(ar: true)
            .copyWith(kabsoOwner: false, coverVideo: null, username: 'sara'),
      );
      expect(find.byKey(OwnerProfileSections.sectionsKey), findsNothing);
      expect(find.byKey(OwnerVisitorActions.followKey), findsNothing);
      expect(find.byKey(PublicProfileScreen.followKey), findsOneWidget);
      expect(find.byKey(OwnerCoverVideoLayer.layerKey), findsNothing);
      // D307: another staff account keeps the «فريق كابسو» badge and its
      // own bio (no founder default).
      expect(find.byType(KabsoTeamBadge), findsOneWidget);
      expect(find.text('مؤسس كابسو لايف'), findsOneWidget);
      // D307 follow-up: the photo stays at the reading start with the name
      // beside it (only the owner's page centres them).
      expect(find.byKey(ProfileCoverHeader.ownerStackKey), findsNothing);
      final photo = tester.getRect(find.byKey(ProfileHeaderView.avatarKey));
      final name = tester.getRect(find.byKey(const Key('profile.displayName')));
      expect(name.right, lessThan(photo.left));
      expect(name.center.dy, closeTo(photo.center.dy, 40));
      expect(find.textContaining('بنيتُ هذه المنصة'), findsNothing);
      await _end(tester);
    });

    group('D307', () {
      testD301('the video pauses under another page and in the background, and '
          'resumes when back', (tester) async {
        final videos = FakeInlineVideos();
        await pumpOwnerVisitor(
          tester,
          language: AppLanguage.en,
          videos: videos,
          still: false,
        );
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump();
        final v = videos.created.single;
        expect(v.state.playing, isTrue);
        // Another page over the profile (a sheet or a dialog too).
        final nav =
            Navigator.of(tester.element(find.byType(OwnerCoverVideoLayer)))
              ..push(
                PageRouteBuilder<void>(
                  opaque: false,
                  pageBuilder: (_, _, _) => const SizedBox.expand(),
                  transitionDuration: Duration.zero,
                ),
              );
        await tester.pump();
        await tester.pump();
        expect(v.state.playing, isFalse);
        nav.pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump();
        expect(v.state.playing, isTrue);
        // The app in the background, then back.
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump();
        expect(v.state.playing, isFalse);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        await tester.pump();
        expect(v.state.playing, isTrue);
        // Still with sound: nobody muted it.
        expect(v.volumes, everyElement(1));
        await _end(tester);
      });

      for (final language in AppLanguage.values) {
        final ar = language == AppLanguage.ar;
        testD301('${language.name}: no «فريق كابسو» badge under the '
            "founder's name; the seal and the special ID stay; the default "
            'bio in the app language (not the one-language bio)', (
          tester,
        ) async {
          await pumpOwnerVisitor(tester, language: language);
          expect(find.byType(KabsoTeamBadge), findsNothing);
          expect(find.byType(ProfileVerificationBadge), findsOneWidget);
          final bio = tester.widget<Text>(
            find.byKey(ProfileCoverHeader.bioKey),
          );
          expect(
            bio.data,
            ar
                ? 'مؤسس Kabso Live. بنيتُ هذه المنصة لتجمعنا في البث والمحتوى '
                      'ومجتمع واحد. اقتراحاتكم تصلني مباشرة، فشاركوني أفكاركم.'
                : 'Founder of Kabso Live. I built this place to bring us '
                      'together through live streams, content and one '
                      'community. Your ideas reach me directly, so share '
                      'yours.',
          );
          expect(bio.maxLines, KPublicProfile.ownerBioLines);
          expect(
            find.text(ar ? 'مؤسس كابسو لايف' : 'Founder of Kabso Live'),
            findsNothing,
          );
          await _end(tester);
        });
      }

      for (final language in AppLanguage.values) {
        for (final viewport in GoldenViewport.values) {
          testD301('follow-up ${language.name} ${viewport.name}: the photo '
              'centred, the name and the seal centred under it; a long name '
              'is cut with «…», nothing overflows', (tester) async {
            final ar = language == AppLanguage.ar;
            await pumpOwnerVisitor(
              tester,
              language: language,
              viewport: viewport,
              profile: ownerProfile(ar: ar).copyWith(
                displayName: ar
                    ? 'مؤسس كابسو لايف للبث والمحتوى والمجتمع العربي الكبير'
                    : 'Kabso Live founder of streams, content and community',
              ),
            );
            expect(tester.takeException(), isNull);
            final width = viewport.logicalSize.width;
            expect(
              find.byKey(ProfileCoverHeader.ownerStackKey),
              findsOneWidget,
            );
            final photo = tester.getRect(
              find.byKey(ProfileHeaderView.avatarKey),
            );
            // The photo's box (the frames' slot) is centred exactly.
            final slot = tester.getRect(
              find
                  .ancestor(
                    of: find.byKey(ProfileHeaderView.avatarKey),
                    matching: find.byType(SizedBox),
                  )
                  .first,
            );
            expect(slot.center.dx, closeTo(width / 2, 0.5));
            expect(photo.center.dx, closeTo(width / 2, 0.5));
            final line = tester.getRect(
              find.byKey(ProfileCoverHeader.nameLineKey),
            );
            expect(line.top, greaterThanOrEqualTo(photo.bottom - 1));
            expect(line.center.dx, closeTo(width / 2, 1));
            expect(line.left, greaterThanOrEqualTo(0));
            expect(line.right, lessThanOrEqualTo(width));
            expect(find.byType(ProfileVerificationBadge), findsOneWidget);
            final seal = tester.getRect(find.byType(ProfileVerificationBadge));
            expect(seal.right, lessThanOrEqualTo(width));
            expect(seal.left, greaterThanOrEqualTo(0));
            // The name is cut on one line (not wrapped, not clipped away).
            final name = tester.widget<Text>(
              find.byKey(const Key('profile.displayName')),
            );
            expect(name.maxLines, 1);
            expect(name.overflow, TextOverflow.ellipsis);
            // The name block stays on the picture, above the numbers.
            final cover = tester.getRect(
              find.byKey(ProfileCoverHeader.coverAreaKey),
            );
            expect(line.bottom, lessThanOrEqualTo(cover.bottom));
            // The sound button keeps its corner, clear of the photo.
            final mute = tester.getRect(
              find.byKey(OwnerCoverVideoLayer.muteKey),
            );
            expect(mute.overlaps(photo), isFalse);
            await _end(tester);
          });
        }
      }

      testD301("the owner's text for the app language; the other "
          "language's text is never shown (the default instead)", (
        tester,
      ) async {
        const owned = OwnerBio(ar: 'أهلاً بكم في صفحتي');
        await pumpOwnerVisitor(
          tester,
          language: AppLanguage.ar,
          profile: ownerProfile(ar: true).copyWith(ownerBio: owned),
        );
        expect(find.text('أهلاً بكم في صفحتي'), findsOneWidget);
        await _end(tester);
        await pumpOwnerVisitor(
          tester,
          language: AppLanguage.en,
          profile: ownerProfile(ar: false).copyWith(ownerBio: owned),
        );
        expect(find.text('أهلاً بكم في صفحتي'), findsNothing);
        expect(
          find.textContaining('Founder of Kabso Live. I built'),
          findsOneWidget,
        );
        await _end(tester);
      });

      testD301('PublicProfile reads ownerBio (absent → null)', (tester) async {
        final json = jsonDecode(
          jsonEncode(
            ownerProfile(ar: true)
                .copyWith(
                  ownerBio: const OwnerBio(ar: 'ع', en: 'E'),
                )
                .toJson(),
          ),
        ) as Map<String, dynamic>;
        expect(json['ownerBio'], {'ar': 'ع', 'en': 'E'});
        expect(
          PublicProfile.fromJson(json).ownerBio,
          const OwnerBio(ar: 'ع', en: 'E'),
        );
        expect(
          PublicProfile.fromJson({...json}..remove('ownerBio')).ownerBio,
          isNull,
        );
        expect(const OwnerBio(en: 'E').pick('ar'), isNull);
        expect(const OwnerBio(en: 'E').pick('fr'), 'E');
      });

      testD301('«متابعة المؤسس» has no shadow under it', (tester) async {
        await pumpOwnerVisitor(tester, language: AppLanguage.ar);
        final box = tester.widget<DecoratedBox>(
          find
              .ancestor(
                of: find.byKey(OwnerVisitorActions.followKey),
                matching: find.byType(DecoratedBox),
              )
              .first,
        );
        final decoration = box.decoration as BoxDecoration;
        expect(decoration.boxShadow, isNull);
        // Its red gradient stays.
        expect(decoration.gradient, isNotNull);
        await _end(tester);
      });

      testD301('«اقترح ميزة / أبلغ» is an outline only (no fill), in '
          'light and dark', (tester) async {
        for (final brightness in Brightness.values) {
          await pumpOwnerVisitor(
            tester,
            language: AppLanguage.ar,
            brightness: brightness,
          );
          final button = tester.widget<OutlinedButton>(
            find.byKey(OwnerVisitorActions.feedbackKey),
          );
          final style = button.style!;
          expect(style.backgroundColor?.resolve(<WidgetState>{})?.a, 0);
          final side = style.side?.resolve(<WidgetState>{});
          expect(side?.color.a, greaterThan(0.5));
          expect(side?.width, greaterThan(0));
          await _end(tester);
        }
      });
    });
  });

  group("the owner's own view", () {
    testD301('ar: «لوحة المؤسس» (خاص) with the income blurred until tapped; '
        'a tap on the card opens the fuller view', (tester) async {
      await pumpOwnerOwn(tester, language: AppLanguage.ar);
      expect(tester.takeException(), isNull);
      expect(find.byKey(FounderDashboardCard.cardKey), findsOneWidget);
      expect(find.text('خاص'), findsOneWidget);
      expect(find.textContaining('48.2K'), findsOneWidget);
      expect(find.text('1,284'), findsOneWidget);
      expect(find.byKey(FounderDashboardCard.incomeHiddenKey), findsOneWidget);
      await tester.tap(find.byKey(FounderDashboardCard.incomeKey));
      await tester.pump();
      expect(find.byKey(FounderDashboardCard.incomeHiddenKey), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(FounderDashboardCard.incomeKey),
          matching: find.text(r'$8,431.25'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(FounderDashboardCard.onlineKey));
      await tester.pumpAndSettle();
      expect(find.byKey(FounderDashboardCard.detailsKey), findsOneWidget);
      // D301 follow-up: the income's parts under «الدخل قبل».
      await tester.tap(find.byKey(OwnerProfitView.beforeKey));
      await tester.pumpAndSettle();
      final before = find.byKey(OwnerProfitView.beforeKey);
      expect(
        find.descendant(of: before, matching: find.text(r'$6,500.00')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: before, matching: find.text(r'$2,306.25')),
        findsOneWidget,
      );
      await _end(tester);
    });

    testD301('the dashboard that fails says so (no made-up numbers)', (
      tester,
    ) async {
      await pumpOwnerOwn(
        tester,
        language: AppLanguage.en,
        repo: d301Repo(ar: false, dashboardFails: true),
      );
      expect(find.textContaining("Couldn't load the numbers"), findsOneWidget);
      expect(find.textContaining('48.2K'), findsNothing);
      await _end(tester);
    });

    testD301(
      'no announcements yet: the hint to mark one; no journey: «أضف أول محطة»',
      (tester) async {
        await pumpOwnerOwn(
          tester,
          language: AppLanguage.ar,
          repo: d301Repo(ar: true, empty: true),
        );
        await _scrollTo(tester, find.byKey(OfficialAnnouncementsFeed.emptyKey));
        expect(find.byKey(OfficialAnnouncementsFeed.emptyKey), findsOneWidget);
        expect(find.byKey(OfficialAnnouncementsFeed.newKey), findsOneWidget);
        expect(find.byKey(JourneySection.addFirstKey), findsOneWidget);
        await _end(tester);
      },
    );

    testD301(
      '«تعديل» on the journey: ▲ reorders, add, edit and delete go to the API',
      (tester) async {
        final repo = await pumpOwnerOwn(tester, language: AppLanguage.ar);
        await _scrollTo(tester, find.byKey(JourneySection.editKey));
        await tester.tap(find.byKey(JourneySection.editKey));
        await tester.pumpAndSettle();
        expect(find.byKey(JourneyEditorSheet.sheetKey), findsOneWidget);
        // ▲ on the second moves it first.
        await tester.tap(find.byKey(JourneyEditorSheet.upKey('m2')));
        await tester.pumpAndSettle();
        expect(repo.calls, contains('reorder:m2,m1,m3,m4,m5'));
        expect(repo.journeyItems.first.id, 'm2');
        // Add: the form in both languages.
        await tester.tap(find.byKey(JourneyEditorSheet.addKey));
        await tester.pumpAndSettle();
        // The save refuses empty titles.
        await tester.tap(find.byKey(MilestoneForm.saveKey));
        await tester.pumpAndSettle();
        expect(find.text('مطلوب'), findsNWidgets(2));
        await tester.enterText(
          find.byKey(MilestoneForm.titleArKey),
          'مليونا مستخدم',
        );
        await tester.enterText(
          find.byKey(MilestoneForm.titleEnKey),
          'Two million users',
        );
        await tester.tap(find.byKey(MilestoneForm.iconKey(JourneyIcon.trophy)));
        await tester.ensureVisible(find.byKey(MilestoneForm.latestKey));
        await tester.tap(find.byKey(MilestoneForm.latestKey));
        await tester.ensureVisible(find.byKey(MilestoneForm.saveKey));
        await tester.tap(find.byKey(MilestoneForm.saveKey));
        await tester.pumpAndSettle();
        expect(repo.calls, contains('create:مليونا مستخدم'));
        final added = repo.journeyItems.last;
        expect(added.icon, JourneyIcon.trophy);
        expect(added.latest, isTrue);
        expect(repo.journeyItems.where((m) => m.latest), hasLength(1));
        // Delete it.
        await tester.tap(
          find.descendant(
            of: find.byKey(JourneyEditorSheet.rowKey(added.id)),
            matching: find.byType(PopupMenuButton<bool>),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(JourneyEditorSheet.deleteKey(added.id)));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('owner.journey.deleteConfirm')));
        await tester.pumpAndSettle();
        expect(repo.calls, contains('delete:${added.id}'));
        expect(repo.journeyItems.map((m) => m.id), isNot(contains(added.id)));
        await _end(tester);
      },
    );

    testD301('D307: no «فريق كابسو» badge on his own page either; the '
        'default bio', (tester) async {
      await pumpOwnerOwn(tester, language: AppLanguage.ar);
      expect(find.byType(KabsoTeamBadge), findsNothing);
      expect(find.textContaining('بنيتُ هذه المنصة'), findsOneWidget);
      await _end(tester);
    });

    testD301('D307: «بايو المؤسس» in «لوحة المؤسس» saves both languages '
        'and refreshes the page', (tester) async {
      final repo = await pumpOwnerOwn(tester, language: AppLanguage.en);
      await tester.tap(find.byKey(FounderDashboardCard.onlineKey));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(FounderDashboardCard.bioKey),
        300,
        scrollable: find
            .descendant(
              of: find.byKey(FounderDashboardCard.detailsKey),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.byKey(FounderDashboardCard.bioKey));
      await tester.pumpAndSettle();
      expect(find.byKey(OwnerBioEditor.sheetKey), findsOneWidget);
      // The defaults are the hints (an empty field shows the default).
      expect(
        find.textContaining('Founder of Kabso Live. I built'),
        findsWidgets,
      );
      await tester.enterText(find.byKey(OwnerBioEditor.arKey), ' مرحباً ');
      await tester.enterText(find.byKey(OwnerBioEditor.enKey), 'Hello all');
      await tester.tap(find.byKey(OwnerBioEditor.saveKey));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('setBio:مرحباً|Hello all'));
      expect(find.byKey(OwnerBioEditor.sheetKey), findsNothing);
      expect(find.text('Bio saved'), findsOneWidget);
      await _end(tester);
    });

    testD301('D307: a failed save keeps the sheet and says so', (tester) async {
      final repo = d301Repo(ar: false)..bioFails = true;
      await pumpOwnerOwn(tester, language: AppLanguage.en, repo: repo);
      await tester.tap(find.byKey(FounderDashboardCard.onlineKey));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(FounderDashboardCard.bioKey),
        300,
        scrollable: find
            .descendant(
              of: find.byKey(FounderDashboardCard.detailsKey),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.byKey(FounderDashboardCard.bioKey));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(OwnerBioEditor.enKey), 'Hello');
      await tester.tap(find.byKey(OwnerBioEditor.saveKey));
      await tester.pumpAndSettle();
      expect(find.byKey(OwnerBioEditor.sheetKey), findsOneWidget);
      expect(find.text('Bio saved'), findsNothing);
      await _end(tester);
    });

    testD301('the own view keeps «تعديل الملف» and has no follow / suggest', (
      tester,
    ) async {
      await pumpOwnerOwn(tester, language: AppLanguage.en);
      expect(find.byKey(ProfileScreen.editButtonKey), findsOneWidget);
      expect(find.byKey(OwnerVisitorActions.followKey), findsNothing);
      await _end(tester);
    });
  });

  group('«اقترح ميزة / أبلغ عن موظف»', () {
    Future<FakeOwnerProfileRepository> openSheet(
      WidgetTester tester, {
      required AppLanguage language,
    }) async {
      final repo = await pumpOwnerVisitor(tester, language: language);
      await tester.tap(find.byKey(OwnerVisitorActions.feedbackKey));
      await tester.pumpAndSettle();
      expect(find.byKey(OwnerFeedbackSheet.sheetKey), findsOneWidget);
      return repo;
    }

    testD301('a feature suggestion: send waits for the text', (tester) async {
      final repo = await openSheet(tester, language: AppLanguage.ar);
      await tester.tap(find.byKey(OwnerFeedbackSheet.featureKey));
      await tester.pumpAndSettle();
      FilledButton send() =>
          tester.widget<FilledButton>(find.byKey(OwnerFeedbackSheet.sendKey));
      expect(send().onPressed, isNull);
      await tester.enterText(
        find.byKey(OwnerFeedbackSheet.textKey),
        'أريد البث المشترك',
      );
      await tester.pump();
      expect(send().onPressed, isNotNull);
      await tester.tap(find.byKey(OwnerFeedbackSheet.sendKey));
      await tester.pumpAndSettle();
      expect(repo.feedback.single, {
        'kind': 'FEATURE',
        'text': 'أريد البث المشترك',
        'images': <String>[],
        'staff': null,
        'category': null,
      });
      expect(find.byKey(OwnerFeedbackSheet.sheetKey), findsNothing);
      await _end(tester);
    });

    testD301('a staff report: search by staff ID, the reason, '
        'the confidentiality note', (tester) async {
      final repo = await openSheet(tester, language: AppLanguage.en);
      await tester.tap(find.byKey(OwnerFeedbackSheet.reportKey));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.byKey(OwnerFeedbackSheet.confidentialKey), findsOneWidget);
      await tester.enterText(
        find.byKey(OwnerFeedbackSheet.searchKey),
        'Kabso02',
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(repo.staffQueries.last, 'Kabso02');
      expect(find.byKey(OwnerFeedbackSheet.staffKey('staff-1')), findsNothing);
      await tester.tap(find.byKey(OwnerFeedbackSheet.staffKey('staff-2')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          OwnerFeedbackSheet.categoryKey(FeedbackCategory.unfairAction),
        ),
      );
      await tester.enterText(
        find.byKey(OwnerFeedbackSheet.textKey),
        'Banned me with no reason',
      );
      await tester.pump();
      await tester.ensureVisible(find.byKey(OwnerFeedbackSheet.sendKey));
      await tester.tap(find.byKey(OwnerFeedbackSheet.sendKey));
      await tester.pumpAndSettle();
      expect(repo.feedback.single['kind'], 'STAFF_REPORT');
      expect(repo.feedback.single['staff'], 'staff-2');
      expect(repo.feedback.single['category'], 'UNFAIR_ACTION');
      await _end(tester);
    });
  });

  group('D301 follow-up: bilingual announcements', () {
    testD301('the owner composes in both languages; publish waits for both', (
      tester,
    ) async {
      final repo = await pumpComposer(
        tester,
        language: AppLanguage.ar,
        fill: false,
      );
      FilledButton publish() => tester.widget<FilledButton>(
        find.byKey(AnnouncementComposer.publishKey),
      );
      expect(publish().onPressed, isNull);
      await tester.enterText(find.byKey(AnnouncementComposer.arKey), 'إعلان');
      await tester.pump();
      expect(publish().onPressed, isNull);
      await tester.enterText(
        find.byKey(AnnouncementComposer.enKey),
        'Announcement',
      );
      await tester.pump();
      expect(publish().onPressed, isNotNull);
      await tester.ensureVisible(find.byKey(AnnouncementComposer.publishKey));
      await tester.tap(find.byKey(AnnouncementComposer.publishKey));
      await tester.pumpAndSettle();
      expect(repo.announcements.single, {
        'key': isA<String>(),
        'ar': 'إعلان',
        'en': 'Announcement',
        'media': <String>[],
      });
      expect(
        find.text('نُشر الإعلان، ويصل الإشعار للجميع خلال دقائق.'),
        findsOneWidget,
      );
      await _end(tester);
    });

    testD301(
      'a bilingual announcement is edited with both texts, no new notification',
      (tester) async {
        final ar = d301Repo(ar: true)
          ..official = [
            Post.fromJson({
              ...postJson('pb', text: 'نص عربي'),
              'official': true,
              'texts': const {'ar': 'نص عربي', 'en': 'English text'},
            }),
          ];
        await pumpOwnerOwn(tester, language: AppLanguage.en, repo: ar);
        await _scrollTo(
          tester,
          find.byKey(OfficialAnnouncementsFeed.editKey('pb')),
        );
        await tester.tap(find.byKey(OfficialAnnouncementsFeed.editKey('pb')));
        await tester.pumpAndSettle();
        expect(find.text('Editing sends no new notification.'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(AnnouncementComposer.arKey),
            matching: find.text('نص عربي'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(AnnouncementComposer.enKey),
            matching: find.text('English text'),
          ),
          findsOneWidget,
        );
        await tester.enterText(
          find.byKey(AnnouncementComposer.enKey),
          'Edited',
        );
        await tester.ensureVisible(find.byKey(AnnouncementComposer.publishKey));
        await tester.tap(find.byKey(AnnouncementComposer.publishKey));
        await tester.pumpAndSettle();
        expect(ar.calls, contains('updateAnnouncement:pb'));
        expect(ar.announcements.last, {
          'edit': 'pb',
          'ar': 'نص عربي',
          'en': 'Edited',
        });
        await _end(tester);
      },
    );

    test('Post reads both captions', () {
      final p = Post.fromJson({
        ...postJson('x', text: 'عربي'),
        'texts': const {'ar': 'عربي', 'en': 'English'},
      });
      expect(p.texts, (ar: 'عربي', en: 'English'));
      expect(Post.fromJson(postJson('y')).texts, isNull);
    });

    for (final language in AppLanguage.values) {
      final ar = language == AppLanguage.ar;
      testD301('${language.name}: the feed starts with the announcement '
          'and its «رسمي» label', (tester) async {
        await pumpFeedTop(tester, language: language);
        final top = tester.getRect(find.byType(FeedPostTile).first);
        expect(
          tester.getRect(find.byKey(OfficialPostLabel.labelKey)).top,
          lessThan(top.bottom),
        );
        expect(find.byKey(OfficialPostLabel.labelKey), findsOneWidget);
        expect(
          find.textContaining(
            ar ? 'إطلاق الإصدار 2.0' : 'Kabso Live 2.0 is here',
          ),
          findsOneWidget,
        );
        await _end(tester);
      });

      testD301(
        '${language.name}: the notification reads the app language caption',
        (tester) async {
          await pumpScreen(
            tester,
            Column(
              children: [
                NotificationRow(
                  item: AppNotification(
                    id: 'n1',
                    type: NotificationType.ownerAnnouncement,
                    actors: const [],
                    actorCount: 0,
                    target: const NotificationTarget(
                      type: NotificationTargetType.post,
                      id: 'pa1',
                      text: 'إطلاق الإصدار 2.0',
                      texts: (
                        ar: 'إطلاق الإصدار 2.0',
                        en: 'Kabso Live 2.0 is here',
                      ),
                    ),
                    createdAt: d301Now,
                    read: false,
                  ),
                ),
              ],
            ),
            language: language,
          );
          await tester.pumpAndSettle();
          expect(
            find.textContaining(
              ar
                  ? 'إعلان رسمي من المؤسس: \u2068إطلاق الإصدار 2.0'
                  : 'Official announcement from the founder: '
                        '\u2068Kabso Live 2.0 is here',
            ),
            findsOneWidget,
          );
          await _end(tester);
        },
      );
    }

    testD301(
      'the dashboard says what counts as income, and other currencies apart',
      (tester) async {
        final repo = d301Repo(ar: true)
          ..dashboardData = OwnerDashboard(
            onlineNow: 10,
            liveRoomsNow: 2,
            incomeMinor: 1000,
            websiteMinor: 800,
            agentsMinor: 200,
            currency: 'USD',
            generatedAt: d301Now,
            otherCurrencies: const [(currency: 'EUR', amountMinor: 5000)],
          );
        await pumpOwnerOwn(tester, language: AppLanguage.ar, repo: repo);
        await tester.tap(find.byKey(FounderDashboardCard.onlineKey));
        await tester.pumpAndSettle();
        // D301 follow-up: the definition under «الدخل قبل», other currencies
        // on their own line (never converted).
        await tester.tap(find.byKey(OwnerProfitView.beforeKey));
        await tester.pumpAndSettle();
        expect(find.byKey(FounderDashboardCard.incomeNoteKey), findsOneWidget);
        expect(find.text('EUR: قبل EUR 50.00، بعد EUR 50.00'), findsOneWidget);
        await _end(tester);
      },
    );
  });

  group('«فيديو الغلاف» in «تعديل الملف» (owner only)', () {
    Future<(FakeOwnerProfileRepository, FakeMediaRepository)> pumpEditor(
      WidgetTester tester, {
      PickedVideo? video,
    }) async {
      final repo = d301Repo(ar: true);
      final media = FakeMediaRepository();
      await pumpScreen(
        tester,
        const Scaffold(
          body: SingleChildScrollView(
            child: OwnerCoverVideoEditor(username: 'kabso'),
          ),
        ),
        language: AppLanguage.ar,
        brightness: Brightness.light,
        overrides: [
          ownerProfileRepositoryProvider.overrideWithValue(repo),
          mediaRepositoryProvider.overrideWithValue(media),
          videoPickerProvider.overrideWithValue(FakeVideoPicker(video)),
          profileStatsProvider.overrideWith(
            (ref, _) => ownerProfile(
              ar: true,
              self: true,
              videos: OwnerCoverVideo(ar: ownerVideos.ar),
            ),
          ),
        ],
      );
      await tester.pumpAndSettle();
      return (repo, media);
    }

    testD301('Arabic set (24 s), English none; choose uploads a '
        'PROFILE_COVER_VIDEO and sets it; remove removes', (tester) async {
      final (repo, media) = await pumpEditor(
        tester,
        video: testVideo(seconds: 20),
      );
      expect(find.text('24 ث'), findsOneWidget);
      expect(find.text('لا يوجد'), findsOneWidget);
      expect(find.byKey(OwnerCoverVideoEditor.removeKey('en')), findsNothing);
      await tester.tap(find.byKey(OwnerCoverVideoEditor.chooseKey('en')));
      await tester.pumpAndSettle();
      expect(media.videoUploads.single, startsWith('PROFILE_COVER_VIDEO:'));
      expect(repo.calls, contains('setVideo:en:v1'));
      await tester.tap(find.byKey(OwnerCoverVideoEditor.removeKey('ar')));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('removeVideo:ar'));
    });

    testD301('a video longer than 60 s is refused before any upload', (
      tester,
    ) async {
      final (repo, media) = await pumpEditor(
        tester,
        video: testVideo(seconds: 75),
      );
      await tester.tap(find.byKey(OwnerCoverVideoEditor.chooseKey('ar')));
      await tester.pumpAndSettle();
      expect(media.videoUploads, isEmpty);
      expect(repo.calls.where((c) => c.startsWith('setVideo')), isEmpty);
    });
  });

  group('«رسمي» from the post menu', () {
    Future<FakeOwnerProfileRepository> pumpTile(
      WidgetTester tester, {
      required bool owner,
      bool self = true,
    }) async {
      final repo = d301Repo(ar: true);
      await pumpScreen(
        tester,
        Scaffold(
          body: ListView(
            children: [
              FeedPostTile(
                post: FeedPostData(
                  authorName: 'مؤسس كابسو',
                  authorUsername: 'kabso',
                  postedAt: d301Now,
                  postId: 'p1',
                  text: 'إطلاق الإصدار 2.0',
                  isSelf: self,
                ),
              ),
            ],
          ),
        ),
        language: AppLanguage.ar,
        brightness: Brightness.light,
        overrides: [
          ownerProfileRepositoryProvider.overrideWithValue(repo),
          isKabsoOwnerProvider.overrideWithValue(owner),
        ],
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(FeedPostTile.moreKey).first);
      await tester.pumpAndSettle();
      return repo;
    }

    testD301('the owner marks his post official; the label shows', (
      tester,
    ) async {
      final repo = await pumpTile(tester, owner: true);
      expect(find.text('تعيين كإعلان رسمي'), findsOneWidget);
      await tester.tap(find.byKey(FeedPostTile.officialActionKey));
      await tester.pumpAndSettle();
      expect(repo.calls.last, 'official:p1:true');
      expect(find.text('أصبح إعلاناً رسمياً في ملفك'), findsOneWidget);
      await tester.tap(find.byKey(FeedPostTile.moreKey).first);
      await tester.pumpAndSettle();
      expect(find.text('إزالة من الإعلانات الرسمية'), findsOneWidget);
    });

    testD301('nobody else sees it (not the owner, or not his post)', (
      tester,
    ) async {
      await pumpTile(tester, owner: false);
      expect(find.byKey(FeedPostTile.officialActionKey), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await pumpTile(tester, owner: true, self: false);
      expect(find.byKey(FeedPostTile.officialActionKey), findsNothing);
    });
  });

  testD301('the «رسمي» label', (tester) async {
    await pumpScreen(
      tester,
      const Scaffold(body: Center(child: OfficialPostLabel())),
      language: AppLanguage.ar,
    );
    expect(find.text('رسمي'), findsOneWidget);
  });

  final captureDir = Platform.environment['D301_CAPTURE_DIR'];
  group('D301 captures', skip: captureDir == null, () {
    Future<void> capture(WidgetTester tester, String name) async {
      await precacheImages(tester);
      await tester.runAsync(() async {
        final element = find.byType(MaterialApp).evaluate().first;
        final image = await captureImage(element);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('${captureDir!}/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
      });
    }

    for (final brightness in Brightness.values) {
      testD301('visitor ar ${brightness.name}', (tester) async {
        await pumpOwnerVisitor(
          tester,
          language: AppLanguage.ar,
          brightness: brightness,
        );
        await capture(tester, 'visitor.ar.${brightness.name}');
        await _end(tester);
      });
      testD301('own ar ${brightness.name}', (tester) async {
        await pumpOwnerOwn(
          tester,
          language: AppLanguage.ar,
          brightness: brightness,
        );
        await capture(tester, 'own.ar.${brightness.name}');
        await _end(tester);
      });
    }
    testD301('visitor en light', (tester) async {
      await pumpOwnerVisitor(tester, language: AppLanguage.en);
      await capture(tester, 'visitor.en.light');
      await _end(tester);
    });
    testD301('own en dark', (tester) async {
      await pumpOwnerOwn(
        tester,
        language: AppLanguage.en,
        brightness: Brightness.dark,
      );
      await capture(tester, 'own.en.dark');
      await _end(tester);
    });
    for (final brightness in Brightness.values) {
      testD301('journey ar ${brightness.name}', (tester) async {
        await pumpOwnerVisitor(
          tester,
          language: AppLanguage.ar,
          brightness: brightness,
        );
        await _scrollTo(tester, find.byKey(JourneySection.sectionKey), at: 140);
        await capture(tester, 'journey.ar.${brightness.name}');
        await _end(tester);
      });
    }
    for (final language in AppLanguage.values) {
      testD301('announcements ${language.name} light', (tester) async {
        await pumpOwnerVisitor(tester, language: language);
        await _scrollTo(
          tester,
          find.byKey(OfficialAnnouncementsFeed.sectionKey),
          at: 140,
        );
        await capture(tester, 'announcements.${language.name}.light');
        await _scrollTo(
          tester,
          find.byKey(OfficialAnnouncementsFeed.cardKey('o3')),
          at: 140,
        );
        await capture(tester, 'announcements.${language.name}.light.more');
        await _end(tester);
      });
    }
    testD301('dashboard details ar dark', (tester) async {
      await pumpOwnerOwn(
        tester,
        language: AppLanguage.ar,
        brightness: Brightness.dark,
      );
      await tester.tap(find.byKey(FounderDashboardCard.incomeKey));
      await tester.pump();
      await capture(tester, 'own.ar.dark.incomeShown');
      await tester.tap(find.byKey(FounderDashboardCard.onlineKey));
      await tester.pumpAndSettle();
      await capture(tester, 'dashboard.details.ar.dark');
      await _end(tester);
    });
    for (final kind in ['feature', 'report']) {
      testD301('feedback sheet ar $kind', (tester) async {
        await pumpOwnerVisitor(tester, language: AppLanguage.ar);
        await tester.tap(find.byKey(OwnerVisitorActions.feedbackKey));
        await tester.pumpAndSettle();
        await capture(tester, 'feedback.ar.choices');
        await tester.tap(
          find.byKey(
            kind == 'feature'
                ? OwnerFeedbackSheet.featureKey
                : OwnerFeedbackSheet.reportKey,
          ),
        );
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();
        if (kind == 'report') {
          await tester.tap(
            find.byKey(
              OwnerFeedbackSheet.categoryKey(FeedbackCategory.abuseOfPower),
            ),
          );
          await tester.pump();
        }
        await capture(tester, 'feedback.ar.$kind');
        await _end(tester);
      });
    }
    for (final language in AppLanguage.values) {
      testD301('feed top ${language.name}', (tester) async {
        await pumpFeedTop(tester, language: language);
        await capture(tester, 'feedtop.${language.name}.light');
        await _end(tester);
      });
      testD301('composer ${language.name}', (tester) async {
        await pumpComposer(tester, language: language);
        await capture(tester, 'announcement.composer.${language.name}.light');
        await _end(tester);
      });
      testD301('notification ${language.name}', (tester) async {
        setViewport(tester, GoldenViewport.phone);
        await pumpScreen(
          tester,
          Scaffold(
            body: SafeArea(
              child: Column(
                children: [
                  NotificationRow(
                    item: AppNotification(
                      id: 'n1',
                      type: NotificationType.ownerAnnouncement,
                      actors: const [],
                      actorCount: 0,
                      target: const NotificationTarget(
                        type: NotificationTargetType.post,
                        id: 'pa1',
                        texts: (
                          ar: 'إطلاق الإصدار 2.0 من كابسو لايف',
                          en: 'Kabso Live 2.0 is here',
                        ),
                      ),
                      createdAt: d301Now,
                      read: false,
                    ),
                  ),
                ],
              ),
            ),
          ),
          language: language,
          brightness: Brightness.light,
        );
        await tester.pumpAndSettle();
        await capture(tester, 'notification.announcement.${language.name}');
        await _end(tester);
      });
    }
    testD301('journey editor ar light', (tester) async {
      await pumpOwnerOwn(tester, language: AppLanguage.ar);
      await _scrollTo(tester, find.byKey(JourneySection.editKey));
      await tester.tap(find.byKey(JourneySection.editKey));
      await tester.pumpAndSettle();
      await capture(tester, 'journey.editor.ar.light');
      await tester.tap(find.byKey(JourneyEditorSheet.addKey));
      await tester.pumpAndSettle();
      await capture(tester, 'journey.form.ar.light');
      await _end(tester);
    });
  });
}
