// D307 follow-up (owner, from a device: «في صفحة المؤسس لا تحتوي على
// اعداداته بل تحتوي على اعدادات مضيف او وكيل. يظهر عدد كرز المستلم والكوينز
// المرسل وهذا لا يوجد في صفحة المؤسس او موظفين»):
//
// - the founder's «أنا» tab has no host / creator / agency / recharge-agent
//   rows (and no «اربح المال»), keeps «فريق كابسو», «مركز الفعاليات», the
//   wallet, settings and the cards, and gains «لوحة المؤسس»; anyone else's
//   is unchanged;
// - «الكرز المستلم» / «الكوينز المرسلة» are not on the founder's profile nor
//   on any Kabso Team profile (own view and visitors); others unchanged;
// - the own profile scrolled: the bar turns solid as soon as the photo
//   would pass under it (no photo under the bar's buttons, no name under
//   the status bar), in both layouts, ar / en, 393 × 852 and 360 × 800;
// - the posts tab with no posts shows the posts empty state, full width.
//
// With D307C_CAPTURE_DIR set, the capture group writes PNGs there (not
// committed).

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/features/auth/presentation/auth_controller.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/levels/application/levels_providers.dart';
import 'package:kabso_live/features/owner_profile/data/owner_profile_repository.dart';
import 'package:kabso_live/features/owner_profile/presentation/announcement_composer.dart';
import 'package:kabso_live/features/owner_profile/presentation/journey_editor.dart';
import 'package:kabso_live/features/owner_profile/presentation/official_posts_screen.dart';
import 'package:kabso_live/features/owner_profile/presentation/owner_bio_editor.dart';
import 'package:kabso_live/features/owner_profile/presentation/owner_cover_video.dart';
import 'package:kabso_live/features/owner_profile/presentation/owner_cover_video_editor.dart';
import 'package:kabso_live/features/owner_profile/presentation/owner_profit.dart';
import 'package:kabso_live/features/profile/application/profile_grid_provider.dart';
import 'package:kabso_live/features/profile/domain/profile_models.dart';
import 'package:kabso_live/features/profile/me_hub_screen.dart';
import 'package:kabso_live/features/profile/profile_cover_header.dart';
import 'package:kabso_live/features/profile/profile_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/owner/owner_fixtures.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';
import '../profile/profile_cover_d278_test.dart' show coverBytes, insets;
import 'owner_profile_d301_test.dart'
    show
        D301Pushed,
        d301Repo,
        ownerMe,
        pumpOwnerOwn,
        pumpOwnerVisitor,
        testD301;

/// The founder's «أنا» tab ([owner] false: the same account without the
/// OWNER role, as any user sees it).
Future<void> pumpOwnerMe(
  WidgetTester tester, {
  required AppLanguage language,
  bool owner = true,
  GoldenViewport viewport = GoldenViewport.phone,
}) async {
  final ar = language == AppLanguage.ar;
  setViewport(tester, viewport);
  insets(tester);
  final me = ownerMe(ar: ar);
  await pumpScreen(
    tester,
    const D301Pushed(MeHubScreen()),
    language: language,
    brightness: Brightness.light,
    disableAnimations: true,
    overrides: [
      secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
      meProvider.overrideWith((ref) => me),
      currentUserProvider.overrideWithValue(me),
      profileLevelsProvider.overrideWith((ref, _) async => const []),
      profileStatsProvider.overrideWith(
        (ref, _) => ownerProfile(
          ar: ar,
          self: true,
        ).copyWith(kabsoOwner: owner, kabsoTeam: owner),
      ),
      ownerProfileRepositoryProvider.overrideWithValue(d301Repo(ar: ar)),
    ],
  );
  await tester.pumpAndSettle();
}

/// Scrolls the profile's list by [dy] (up).
Future<void> _scroll(WidgetTester tester, double dy) async {
  // A jump (with its scroll notifications), not a drag: a drag shorter than
  // the touch slop would be a tap.
  final position = tester
      .state<ScrollableState>(find.byType(Scrollable).first)
      .position;
  position.jumpTo(
    (position.pixels + dy).clamp(0, position.maxScrollExtent).toDouble(),
  );
  await tester.pumpAndSettle();
}

Future<void> _end(WidgetTester tester) => tester.pumpWidget(const SizedBox());

void main() {
  setUpAll(() async {
    await loadAppFonts();
    d307cPoster = await paintOwnerPoster();
  });
  setUp(() {
    profileCoverImageFor = (_) => MemoryImage(coverBytes);
    ownerPosterImageFor = (_) => MemoryImage(d307cPoster);
  });
  tearDown(() {
    profileCoverImageFor = NetworkImage.new;
    ownerPosterImageFor = NetworkImage.new;
  });

  group("the founder's «أنا» tab: his control centre", () {
    const founderRows = [
      MeHubScreen.founderDashboardKey,
      MeHubScreen.founderProfitKey,
      MeHubScreen.founderCostsKey,
      MeHubScreen.founderOfficialKey,
      MeHubScreen.founderAnnounceKey,
      MeHubScreen.founderJourneyKey,
      MeHubScreen.founderBioKey,
      MeHubScreen.founderVideoKey,
      MeHubScreen.kabsoTeamKey,
    ];
    for (final language in AppLanguage.values) {
      for (final viewport in GoldenViewport.values) {
        testD301('${language.name} ${viewport.name}: the founder rows and '
            '«فريق كابسو», the gear; no cards, no user / host / agent rows', (
          tester,
        ) async {
          await pumpOwnerMe(tester, language: language, viewport: viewport);
          expect(tester.takeException(), isNull);
          expect(find.byKey(MeHubScreen.cardsKey), findsNothing);
          expect(find.byKey(MeHubScreen.settingsKey), findsOneWidget);
          for (final key in founderRows) {
            await tester.scrollUntilVisible(
              find.byKey(key),
              120,
              scrollable: find.byType(Scrollable).first,
            );
            expect(find.byKey(key), findsOneWidget, reason: '$key');
            expect(tester.takeException(), isNull);
          }
          for (final item in MeHubItem.values) {
            expect(find.byKey(item.key), findsNothing, reason: item.name);
          }
          await _end(tester);
        });
      }
    }

    testD301('each row opens its real tool', (tester) async {
      await pumpOwnerMe(tester, language: AppLanguage.en);
      Future<void> open(Key row) async {
        await tester.scrollUntilVisible(
          find.byKey(row),
          120,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.byKey(row));
        await tester.pumpAndSettle();
      }

      Future<void> close() async {
        await tester.tapAt(const Offset(20, 20));
        await tester.pumpAndSettle();
      }

      await open(MeHubScreen.founderProfitKey);
      expect(find.byKey(OwnerProfitView.sheetKey), findsOneWidget);
      await close();
      await open(MeHubScreen.founderCostsKey);
      expect(find.byKey(FixedCostsSheet.sheetKey), findsOneWidget);
      await close();
      await open(MeHubScreen.founderAnnounceKey);
      expect(find.byKey(AnnouncementComposer.arKey), findsOneWidget);
      await close();
      await open(MeHubScreen.founderJourneyKey);
      expect(find.byKey(JourneyEditorSheet.sheetKey), findsOneWidget);
      await close();
      await open(MeHubScreen.founderBioKey);
      expect(find.byKey(OwnerBioEditor.sheetKey), findsOneWidget);
      await close();
      await open(MeHubScreen.founderVideoKey);
      expect(find.byKey(OwnerCoverVideoEditor.sheetKey), findsOneWidget);
      await close();
      await open(MeHubScreen.founderOfficialKey);
      expect(find.byKey(OfficialPostsScreen.listKey), findsOneWidget);
      await _end(tester);
    });

    testD301('anyone else keeps every row (the same account without '
        'OWNER): cards, creator, agency, recharge, events, wallet, earn', (
      tester,
    ) async {
      await pumpOwnerMe(tester, language: AppLanguage.en, owner: false);
      expect(find.byKey(MeHubScreen.cardsKey), findsOneWidget);
      for (final item in [
        MeHubItem.creatorCenter,
        MeHubItem.agency,
        MeHubItem.recharge,
        MeHubItem.eventCenter,
        MeHubItem.wallet,
        MeHubItem.earn,
      ]) {
        await tester.scrollUntilVisible(
          find.byKey(item.key),
          120,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.byKey(item.key), findsOneWidget, reason: item.name);
      }
      expect(find.byKey(MeHubScreen.founderDashboardKey), findsNothing);
      expect(find.byKey(MeHubScreen.founderProfitKey), findsNothing);
      await _end(tester);
    });
  });

  group('the founder page has no tabs and no grid', () {
    testD301('visitor: ends with «رحلة Kabso»', (tester) async {
      await pumpOwnerVisitor(tester, language: AppLanguage.ar);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is SliverPersistentHeader && w.delegate is ProfileTabsDelegate,
        ),
        findsNothing,
      );
      expect(find.byKey(ProfileGrid.gridKey), findsNothing);
      expect(find.text('منشورات'), findsNothing);
      await _end(tester);
    });

    testD301('own view: no tabs, no «محفوظات»', (tester) async {
      await pumpOwnerOwn(tester, language: AppLanguage.en);
      expect(find.byKey(ProfileGrid.gridKey), findsNothing);
      expect(find.text('Saved'), findsNothing);
      expect(find.text('Posts'), findsNothing);
      await _end(tester);
    });

    testD301('anyone else keeps the tabs and the grid', (tester) async {
      await pumpOwnerVisitor(
        tester,
        language: AppLanguage.ar,
        profile: ownerProfile(ar: true)
            .copyWith(kabsoOwner: false, coverVideo: null, username: 'sara'),
      );
      await tester.scrollUntilVisible(
        find.byKey(ProfileGrid.gridKey),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(ProfileGrid.gridKey), findsOneWidget);
      expect(find.text('منشورات'), findsOneWidget);
      await _end(tester);
    });
  });

  group('«الكرز المستلم» / «الكوينز المرسلة»', () {
    PublicProfile withMoney(PublicProfile p) =>
        p.copyWith(cherriesReceived: 1200, coinsSent: 3400);

    testD301("not on the founder's page (visitor)", (tester) async {
      await pumpOwnerVisitor(
        tester,
        language: AppLanguage.ar,
        profile: withMoney(ownerProfile(ar: true)),
      );
      expect(find.byKey(ProfileCoverHeader.cherriesKey), findsNothing);
      expect(find.byKey(ProfileCoverHeader.coinsKey), findsNothing);
      expect(find.byKey(ProfileHeaderView.followersKey), findsOneWidget);
      await _end(tester);
    });

    testD301('not on a Kabso Team profile (visitor)', (tester) async {
      await pumpOwnerVisitor(
        tester,
        language: AppLanguage.en,
        profile: withMoney(
          ownerProfile(ar: false)
              .copyWith(kabsoOwner: false, coverVideo: null, username: 'mod1'),
        ),
      );
      expect(find.byKey(ProfileCoverHeader.cherriesKey), findsNothing);
      expect(find.byKey(ProfileCoverHeader.coinsKey), findsNothing);
      await _end(tester);
    });

    testD301("still on anyone else's profile", (tester) async {
      await pumpOwnerVisitor(
        tester,
        language: AppLanguage.en,
        profile: withMoney(
          ownerProfile(ar: false).copyWith(
            kabsoOwner: false,
            kabsoTeam: false,
            staffId: null,
            coverVideo: null,
            username: 'sara',
          ),
        ),
      );
      expect(find.byKey(ProfileCoverHeader.cherriesKey), findsOneWidget);
      expect(find.byKey(ProfileCoverHeader.coinsKey), findsOneWidget);
      await _end(tester);
    });
  });

  group('the profile scrolled: the bar turns solid before anything passes '
      'under it', () {
    for (final language in AppLanguage.values) {
      for (final viewport in GoldenViewport.values) {
        for (final own in [true, false]) {
          for (final founder in [true, false]) {
            final what =
                '${own ? 'own' : 'visitor'} '
                '${founder ? 'founder' : 'other'} ${language.name} '
                '${viewport.name}';
            testD301(what, (tester) async {
              final ar = language == AppLanguage.ar;
              final other = ownerProfile(ar: ar).copyWith(
                kabsoOwner: false,
                kabsoTeam: false,
                staffId: null,
                coverVideo: null,
                username: 'sara',
              );
              if (own) {
                await pumpOwnerOwn(
                  tester,
                  language: language,
                  viewport: viewport,
                  stats: founder ? null : other.copyWith(username: 'kabso'),
                );
              } else {
                await pumpOwnerVisitor(
                  tester,
                  language: language,
                  viewport: viewport,
                  profile: founder ? null : other,
                );
              }
              final bar = tester.getRect(find.byType(ProfileCoverBar));
              for (final dy in [8.0, 40.0, 120.0, 200.0]) {
                await _scroll(tester, dy);
                final solid = tester
                    .widget<ProfileCoverBar>(find.byType(ProfileCoverBar))
                    .solid;
                final photo = tester.getRect(
                  find.byKey(ProfileHeaderView.avatarKey),
                );
                // Either the photo is still wholly under the bar's bottom,
                // or the bar is solid (it hides what scrolled under it).
                expect(
                  solid || photo.top >= bar.bottom - 0.5,
                  isTrue,
                  reason: '$what after $dy: photo $photo bar $bar',
                );
              }
              expect(tester.takeException(), isNull);
              await _end(tester);
            });
          }
        }
      }
    }
  });

  group('the top bar is pinned: same place at every scroll, solid over '
      'the status bar once scrolled', () {
    for (final language in AppLanguage.values) {
      for (final viewport in GoldenViewport.values) {
        for (final (what, own, founder) in [
          ('own founder', true, true),
          ('visitor founder', false, true),
          ('visitor other', false, false),
        ]) {
          testD301('$what ${language.name} ${viewport.name}', (tester) async {
            final ar = language == AppLanguage.ar;
            if (own) {
              await pumpOwnerOwn(
                tester,
                language: language,
                viewport: viewport,
              );
            } else {
              await pumpOwnerVisitor(
                tester,
                language: language,
                viewport: viewport,
                profile: founder
                    ? null
                    : ownerProfile(ar: ar).copyWith(
                        kabsoOwner: false,
                        kabsoTeam: false,
                        staffId: null,
                        coverVideo: null,
                        username: 'sara',
                      ),
              );
            }
            const statusBar = 59.0;
            final bar = find.byType(ProfileCoverBar);
            final expected = Rect.fromLTWH(
              0,
              0,
              viewport.logicalSize.width,
              statusBar +
                  const ProfileCoverBar(
                    solid: true,
                    title: SizedBox(),
                    actions: [],
                  ).preferredSize.height,
            );
            final position = tester
                .state<ScrollableState>(find.byType(Scrollable).first)
                .position;
            for (final offset in [0.0, 60.0, 300.0, 2000.0]) {
              position.jumpTo(offset.clamp(0, position.maxScrollExtent));
              await tester.pumpAndSettle();
              // From the screen's top edge (the status bar included) to the
              // bar's bottom, at every offset: it never slides.
              expect(tester.getRect(bar), expected, reason: '$offset');
              final solid = tester.widget<ProfileCoverBar>(bar).solid;
              expect(solid, offset > 0, reason: '$offset');
              if (solid) {
                // The bar's own opaque surface fills that whole rect (the
                // status bar's area too): nothing scrolls into view between
                // the status bar and the bar.
                final material = tester.widget<Material>(
                  find
                      .descendant(of: bar, matching: find.byType(Material))
                      .first,
                );
                expect(material.color?.a, 1, reason: '$offset');
                expect(
                  tester.getRect(
                    find
                        .descendant(of: bar, matching: find.byType(Material))
                        .first,
                  ),
                  expected,
                );
              }
            }
            expect(tester.takeException(), isNull);
            await _end(tester);
          });
        }
      }
    }
  });

  testD301('the posts tab with no posts: the posts empty state, full '
      'width, never a reels tile', (tester) async {
    setViewport(tester, GoldenViewport.phone);
    await pumpScreen(
      tester,
      const Scaffold(
        body: CustomScrollView(
          slivers: [
            ProfileGrid(username: 'kabso', tab: ProfileTab.posts, own: true),
          ],
        ),
      ),
      language: AppLanguage.ar,
      overrides: [
        profileGridProvider.overrideWith((ref, _) => const FeedItems([])),
      ],
    );
    await tester.pumpAndSettle();
    expect(find.byKey(ProfileGrid.stateKey), findsOneWidget);
    expect(find.byKey(ProfileGrid.gridKey), findsNothing);
    expect(find.text('لا توجد ريلز بعد'), findsNothing);
    final state = tester.getRect(find.byKey(ProfileGrid.stateKey));
    expect(state.width, closeTo(393, 0.5));
    await _end(tester);
  });

  final captureDir = Platform.environment['D307C_CAPTURE_DIR'];
  group('D307c captures', skip: captureDir == null, () {
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

    for (final language in AppLanguage.values) {
      testD301('me ${language.name}', (tester) async {
        await pumpOwnerMe(tester, language: language);
        await capture(tester, 'me.${language.name}');
        await _scroll(tester, 400);
        await capture(tester, 'me.${language.name}.scrolled');
        await _end(tester);
      });
      testD301('own scrolled ${language.name}', (tester) async {
        await pumpOwnerOwn(
          tester,
          language: language,
          brightness: Brightness.dark,
        );
        for (final dy in [60.0, 140.0]) {
          await _scroll(tester, dy);
          await capture(tester, 'own.${language.name}.scrolled$dy');
        }
        await _end(tester);
      });
    }
  });
}

late Uint8List d307cPoster;
