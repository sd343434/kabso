// D340 (owner 2026-11-09; CONVENTIONS §10.134): an ended event's page shows
// the caller's final result — «مركزك النهائي: N» and the prize won, «لم
// تتأهل», «لم تشارك» — never «باقي N نقطة للتأهل»; a board without a minimum
// never says what is missing; and the full-screen announcements (an event
// starts, a prize is won) with their gate: once each, marked seen, never in a
// live, the event page on «شارك الآن». Arabic RTL first and English LTR,
// light and dark goldens at 393 × 852; 360 × 800 at text scale 1.3. Kabso's
// own fixtures only (the owner's background sample of the D303 tests, Kabso's
// gift box and rank shields); no third-party art.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/application/live_host_controller.dart';
import 'package:kabso_live/features/programs/data/event_announcements_repository.dart';
import 'package:kabso_live/features/programs/data/programs_repository.dart';
import 'package:kabso_live/features/programs/presentation/event_announcement.dart';
import 'package:kabso_live/features/programs/presentation/event_detail_screen.dart';
import 'package:kabso_live/features/programs/presentation/gift_event_sections.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_event_announcements_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

const _id = '01a1b6a1-0000-7000-8000-000000000340';

UserSummary _u(String id, String name) =>
    UserSummary(id: id, username: id, displayName: name, avatarUrl: null);

EventSummary _summary(bool ar, {EventStatus status = EventStatus.ended}) =>
    EventSummary(
      id: _id,
      title: ar ? 'ملك الهدايا' : 'Gift King',
      startsAt: DateTime.utc(2026, 11, 10, 17),
      endsAt: DateTime.utc(2026, 11, 17, 17),
      status: status,
      metric: 'EVENT_GIFTS',
      forHosts: false,
      permanent: false,
      featured: true,
    );

EventDetail _event(bool ar, {required EventStatus status}) => EventDetail(
  id: _id,
  title: ar ? 'ملك الهدايا' : 'Gift King',
  startsAt: DateTime.utc(2026, 11, 10, 17),
  endsAt: DateTime.utc(2026, 11, 17, 17),
  status: status,
  metric: 'EVENT_GIFTS',
  forHosts: false,
  permanent: false,
  featured: true,
  rules: ar
      ? 'شارك بإرسال هدايا الفعالية.'
      : 'Join by sending the event gifts.',
  prizes: const [],
  timeZone: 'Asia/Riyadh',
  boards: [
    EventBoardInfo(
      kind: EventBoardKind.senders,
      minPoints: 1000,
      prizes: [
        (
          rankFrom: 1,
          rankTo: 1,
          items: [
            const EventPrizeItem(type: 'COINS', amount: 10000),
            EventPrizeItem(
              type: 'BAG_ITEM',
              days: 7,
              code: 'frame_gold',
              name: ar ? 'إطار ذهبي' : 'Gold frame',
              category: 'AVATAR_FRAME',
            ),
          ],
        ),
      ],
    ),
    const EventBoardInfo(
      kind: EventBoardKind.cp,
      minPoints: 0,
      prizes: [
        (
          rankFrom: 1,
          rankTo: 1,
          items: [EventPrizeItem(type: 'COINS', amount: 7000)],
        ),
      ],
    ),
  ],
);

/// The caller's standing on the senders board.
enum _Me { winner, pending, notQualified, absent, running }

EventLeaderboard _board(EventBoardKind kind, bool ar, _Me me) {
  final rows = [
    GiftBoardRow(
      rank: 1,
      user: me == _Me.winner || me == _Me.pending
          ? _u('me', ar ? 'أنا' : 'Me')
          : _u('s1', ar ? 'سارة' : 'Sara'),
      score: 21000,
      qualified: true,
      prize: const [EventPrizeItem(type: 'COINS', amount: 10000)],
    ),
    GiftBoardRow(
      rank: 2,
      user: _u('s2', ar ? 'خالد' : 'Khaled'),
      score: 1500,
      qualified: true,
      prize: const [],
    ),
    if (me == _Me.notQualified)
      GiftBoardRow(
        rank: 3,
        user: _u('me', ar ? 'أنا' : 'Me'),
        score: 400,
        qualified: false,
        prize: const [],
      ),
  ];
  if (kind == EventBoardKind.cp) {
    // A board without a minimum, the caller not on it yet.
    return EventLeaderboard(
      isFinal: false,
      rows: const [],
      myScore: 0,
      myPrize: 0,
      board: kind,
      giftRows: [
        GiftBoardRow(
          rank: 1,
          user: _u('p1', ar ? 'ليلى' : 'Layla'),
          partner: _u('p2', ar ? 'عمر' : 'Omar'),
          score: 2100,
          qualified: true,
          prize: const [EventPrizeItem(type: 'COINS', amount: 7000)],
        ),
      ],
    );
  }
  final ended = me != _Me.running;
  return switch (me) {
    _Me.winner || _Me.pending => EventLeaderboard(
      isFinal: true,
      rows: const [],
      myRank: 1,
      myScore: 21000,
      myPrize: 10000,
      board: kind,
      minPoints: 1000,
      myQualified: true,
      myBundle: [
        const EventPrizeItem(type: 'COINS', amount: 10000),
        EventPrizeItem(
          type: 'BAG_ITEM',
          days: 7,
          code: 'frame_gold',
          name: ar ? 'إطار ذهبي' : 'Gold frame',
          category: 'AVATAR_FRAME',
        ),
      ],
      myPrizeStatus: me == _Me.pending
          ? EventPrizeStatus.pending
          : EventPrizeStatus.paid,
      giftRows: rows,
    ),
    _Me.notQualified || _Me.running => EventLeaderboard(
      isFinal: ended,
      rows: const [],
      myRank: 3,
      myScore: 400,
      myPrize: 0,
      board: kind,
      minPoints: 1000,
      pointsToQualify: 600,
      myPrizeStatus: ended ? EventPrizeStatus.none : null,
      giftRows: rows,
    ),
    _Me.absent => EventLeaderboard(
      isFinal: true,
      rows: const [],
      myScore: 0,
      myPrize: 0,
      board: kind,
      minPoints: 1000,
      pointsToQualify: 1000,
      myPrizeStatus: EventPrizeStatus.none,
      giftRows: rows,
    ),
  };
}

class _Programs implements ProgramsRepository {
  new({required this.ar, required this.me});

  final bool ar;
  final _Me me;

  @override
  Future<EventDetail> event(String eventId) async => _event(
    ar,
    status: me == _Me.running ? EventStatus.running : EventStatus.ended,
  );

  @override
  Future<EventLeaderboard> leaderboard(String eventId, {String? board}) async =>
      _board(EventBoardKind.fromWire(board) ?? EventBoardKind.senders, ar, me);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final Uint8List _bg = File('test/fixtures/programs/d303_event_bg_treasure.webp')
    .readAsBytesSync();

Future<void> _pumpPage(
  WidgetTester tester, {
  required _Me me,
  AppLanguage language = AppLanguage.ar,
  Brightness brightness = Brightness.dark,
  GoldenViewport viewport = GoldenViewport.phone,
}) async {
  // After the end, or while it runs.
  final at = me == _Me.running
      ? DateTime.utc(2026, 11, 12, 9, 30)
      : DateTime.utc(2026, 11, 18, 9, 30);
  EventDetailScreen.countdownClock = () => at;
  addTearDown(() => EventDetailScreen.countdownClock = null);
  final prefs = await testPrefs(language: language.name);
  await pumpGolden(
    tester,
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
        currentUserProvider.overrideWithValue(testUser()),
        programsRepositoryProvider.overrideWithValue(
          _Programs(ar: language == AppLanguage.ar, me: me),
        ),
      ],
      child: const EventDetailScreen(eventId: _id),
    ),
    language: language,
    brightness: brightness,
    viewport: viewport,
    bare: true,
  );
}

Future<void> _showBoards(WidgetTester tester, {EventBoardKind? tab}) async {
  await tester.scrollUntilVisible(
    find.byKey(GiftEventBoards.meKey),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  if (tab != null) {
    await tester.ensureVisible(find.byKey(GiftEventBoards.tabKey(tab)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(GiftEventBoards.tabKey(tab)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(GiftEventBoards.meKey),
      300,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.pumpAndSettle();
}

Finder _inCard(String text) => find.descendant(
  of: find.byKey(GiftEventBoards.meKey),
  matching: find.text(text),
);

Finder _inBar(String text) => find.descendant(
  of: find.byKey(GiftEventMyBar.barKey),
  matching: find.text(text),
);

EventAnnouncement _start(bool ar) => EventAnnouncement(
  id: 'start_$_id',
  kind: EventAnnouncementKind.start,
  event: _summary(ar, status: EventStatus.running),
  backgroundUrl: 'https://media.example.test/media/events/bg/x.webp',
  prize: [
    const EventPrizeItem(type: 'COINS', amount: 10000),
    EventPrizeItem(
      type: 'BAG_ITEM',
      days: 7,
      code: 'frame_gold',
      name: ar ? 'إطار ذهبي' : 'Gold frame',
      category: 'AVATAR_FRAME',
    ),
  ],
);

EventAnnouncement _win(bool ar, {int rank = 1}) => EventAnnouncement(
  id: 'win_01a1b6a1-0000-7000-8000-00000000a340',
  kind: EventAnnouncementKind.win,
  event: _summary(ar),
  prize: const [
    EventPrizeItem(type: 'COINS', amount: 10000),
    EventPrizeItem(type: 'CHERRIES', amount: 500),
  ],
  board: EventBoardKind.senders,
  rank: rank,
);

Future<List<EventAnnouncementChoice>> _pumpView(
  WidgetTester tester,
  EventAnnouncement a, {
  AppLanguage language = AppLanguage.ar,
  Brightness brightness = Brightness.dark,
  GoldenViewport viewport = GoldenViewport.phone,
}) async {
  EventAnnouncementView.imageForTesting = (_) => MemoryImage(_bg);
  addTearDown(() => EventAnnouncementView.imageForTesting = null);
  final choices = <EventAnnouncementChoice>[];
  await pumpGolden(
    tester,
    EventAnnouncementView(announcement: a, onChoice: choices.add),
    language: language,
    brightness: brightness,
    viewport: viewport,
    bare: true,
  );
  return choices;
}

void main() {
  group('the ended page shows the final result', () {
    testWidgets('a winner: «مركزك النهائي: 1» and the prize won, no points '
        'missing (Arabic)', (tester) async {
      await _pumpPage(tester, me: _Me.winner);
      await _showBoards(tester);
      expect(find.textContaining('باقي'), findsNothing);
      expect(find.textContaining('الحد الأدنى للتأهل'), findsNothing);
      expect(find.text('النتائج النهائية'), findsWidgets);
      expect(_inCard('مركزك النهائي: 1'), findsOneWidget);
      expect(_inCard('فزت بـ:'), findsOneWidget);
      expect(_inCard('إطار ذهبي · 7 يوم'), findsOneWidget);
      expect(_inCard('تُسلَّم الجائزة بعد المراجعة'), findsNothing);
      expect(_inBar('مركزك النهائي: 1 · 21,000 نقطة'), findsOneWidget);
      expect(_inBar('فزت بـ 10,000 كوينز +1'), findsOneWidget);
    });

    testWidgets('a winner whose payout is held: delivered after the review', (
      tester,
    ) async {
      await _pumpPage(tester, me: _Me.pending, language: AppLanguage.en);
      await _showBoards(tester);
      expect(_inCard('Your final place: 1'), findsOneWidget);
      expect(_inCard('You won:'), findsOneWidget);
      expect(
        _inCard('Your prize is delivered after the review'),
        findsOneWidget,
      );
    });

    testWidgets('below the minimum: the final place and «لم تتأهل»', (
      tester,
    ) async {
      await _pumpPage(tester, me: _Me.notQualified);
      await _showBoards(tester);
      expect(find.textContaining('باقي'), findsNothing);
      expect(_inCard('مركزك النهائي: 3'), findsOneWidget);
      expect(_inCard('لم تتأهل — الحد الأدنى 1,000 نقطة'), findsOneWidget);
      expect(_inBar('مركزك النهائي: 3 · 400 نقطة'), findsOneWidget);
      expect(_inBar('لم تتأهل'), findsOneWidget);
    });

    testWidgets('not on the board: «لم تشارك», no 0 beside it (English)', (
      tester,
    ) async {
      await _pumpPage(tester, me: _Me.absent, language: AppLanguage.en);
      await _showBoards(tester);
      expect(find.textContaining('pts to qualify'), findsNothing);
      expect(_inCard('You did not take part'), findsOneWidget);
      expect(_inCard('0'), findsNothing);
      expect(_inBar('You did not take part'), findsOneWidget);
    });

    testWidgets('while it runs the missing points stay (D303 unchanged)', (
      tester,
    ) async {
      await _pumpPage(tester, me: _Me.running, language: AppLanguage.en);
      await _showBoards(tester);
      expect(find.text('Minimum to qualify: 1,000 pts'), findsOneWidget);
      expect(_inCard('Your place: 3'), findsOneWidget);
      expect(_inCard('600 pts to qualify'), findsOneWidget);
      expect(_inBar('600 pts to qualify'), findsOneWidget);
    });
  });

  testWidgets('a board without a minimum: no minimum line, nothing «to '
      'qualify», «لم تدخل الترتيب بعد» without «· 0 نقطة»', (tester) async {
    await _pumpPage(tester, me: _Me.running);
    await _showBoards(tester, tab: EventBoardKind.cp);
    expect(find.textContaining('الحد الأدنى للتأهل'), findsNothing);
    expect(find.textContaining('نقطة للتأهل'), findsNothing);
    expect(_inCard('لم تدخل اللوحة بعد'), findsOneWidget);
    expect(_inCard('0'), findsNothing);
    expect(_inBar('لم تدخل الترتيب بعد'), findsOneWidget);
    expect(find.textContaining('· 0'), findsNothing);
  });

  group('the full-screen announcement', () {
    testWidgets('an event starts: its art, title, dates and top prize, «شارك '
        'الآن» and «لاحقاً»', (tester) async {
      final choices = await _pumpView(tester, _start(true));
      expect(find.text('بدأت فعالية جديدة'), findsOneWidget);
      expect(find.text('ملك الهدايا'), findsOneWidget);
      expect(find.text('الجائزة الكبرى'), findsOneWidget);
      expect(find.text('إطار ذهبي · 7 يوم'), findsOneWidget);
      expect(find.byKey(EventAnnouncementView.artKey), findsOneWidget);
      await tester.tap(find.byKey(EventAnnouncementView.openKey));
      await tester.tap(find.byKey(EventAnnouncementView.laterKey));
      await tester.tap(find.byKey(EventAnnouncementView.closeKey));
      expect(choices, [
        EventAnnouncementChoice.open,
        EventAnnouncementChoice.later,
        EventAnnouncementChoice.later,
      ]);
      expect(find.text('شارك الآن'), findsOneWidget);
      expect(find.text('لاحقاً'), findsOneWidget);
    });

    testWidgets('a prize won: «مبروك», the place and the prize, «عرض '
        'النتائج» (English)', (tester) async {
      await _pumpView(tester, _win(false), language: AppLanguage.en);
      expect(find.text('Congratulations'), findsOneWidget);
      expect(find.text('You took place 1 in Gift King'), findsOneWidget);
      expect(find.text('Your prize'), findsOneWidget);
      expect(find.text('500 cherries'), findsOneWidget);
      expect(find.text('See the results'), findsOneWidget);
    });

    testWidgets('Arabic is RTL: the close button at the top left', (
      tester,
    ) async {
      await _pumpView(tester, _win(true));
      final close = tester.getRect(find.byKey(EventAnnouncementView.closeKey));
      expect(close.center.dx, lessThan(393 / 2));
      expect(find.text('حصلت على المركز 1 في ملك الهدايا'), findsOneWidget);
    });

    testWidgets('moves unless the system asks for reduced motion', (
      tester,
    ) async {
      await loadAppFonts();
      setViewport(tester, GoldenViewport.phone);
      Widget app({required bool reduce}) => MaterialApp(
        locale: AppLanguage.en.locale,
        supportedLocales: KabsoApp.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        theme: buildAppTheme(
          brightness: Brightness.dark,
          locale: AppLanguage.en.locale,
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reduce),
          child: child!,
        ),
        home: EventAnnouncementView(
          announcement: _win(false),
          onChoice: (_) {},
        ),
      );
      // The art's drift: where the hero picture is, frame to frame.
      double heroY() => tester
          .getTopLeft(
            find
                .descendant(
                  of: find.byKey(EventAnnouncementView.artKey),
                  matching: find.byType(Image),
                )
                .last,
          )
          .dy;
      await tester.pumpWidget(app(reduce: false));
      await tester.pump(const Duration(milliseconds: 100));
      final moving = heroY();
      await tester.pump(const Duration(milliseconds: 900));
      expect(heroY(), isNot(moving));
      await tester.pumpWidget(app(reduce: true));
      await tester.pump();
      final still = heroY();
      await tester.pump(const Duration(milliseconds: 900));
      expect(heroY(), still);
    });

    for (final language in [AppLanguage.ar, AppLanguage.en]) {
      testWidgets('360 × 800 at text scale 1.3 (${language.name}): no '
          'overflow, the buttons reachable', (tester) async {
        for (final a in [
          _start(language == AppLanguage.ar),
          _win(language == AppLanguage.ar, rank: 7),
        ]) {
          await loadAppFonts();
          setViewport(tester, GoldenViewport.android);
          await tester.pumpWidget(
            MaterialApp(
              locale: language.locale,
              supportedLocales: KabsoApp.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                ...GlobalMaterialLocalizations.delegates,
              ],
              theme: buildAppTheme(
                brightness: Brightness.light,
                locale: language.locale,
              ),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  disableAnimations: true,
                  textScaler: const TextScaler.linear(1.3),
                ),
                child: child!,
              ),
              home: EventAnnouncementView(announcement: a, onChoice: (_) {}),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          for (final k in [
            EventAnnouncementView.openKey,
            EventAnnouncementView.laterKey,
            EventAnnouncementView.closeKey,
          ]) {
            final r = tester.getRect(find.byKey(k));
            expect(r.bottom, lessThanOrEqualTo(800));
            expect(r.top, greaterThanOrEqualTo(0));
          }
        }
      });
    }

    testWidgets('the ended page at 360 × 800, text scale 1.3: no overflow', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      for (final language in [AppLanguage.ar, AppLanguage.en]) {
        for (final me in [_Me.winner, _Me.notQualified, _Me.absent]) {
          await _pumpPage(
            tester,
            me: me,
            language: language,
            viewport: GoldenViewport.android,
          );
          await _showBoards(tester);
          expect(tester.takeException(), isNull);
          expect(find.byKey(GiftEventMyBar.barKey), findsOneWidget);
        }
      }
    });
  });

  group('the gate', () {
    late FakeEventAnnouncementsRepository repo;

    Future<GoRouter> pumpGate(
      WidgetTester tester, {
      String initial = '/home',
      bool hosting = false,
      List<EventAnnouncement>? items,
    }) async {
      repo = FakeEventAnnouncementsRepository(
        items ?? [_win(true), _start(true)],
      );
      EventAnnouncementView.imageForTesting = (_) => MemoryImage(_bg);
      addTearDown(() => EventAnnouncementView.imageForTesting = null);
      await loadAppFonts();
      setViewport(tester, GoldenViewport.phone);
      Widget page(String name) => Scaffold(body: Center(child: Text(name)));
      final router = GoRouter(
        initialLocation: initial,
        routes: [
          GoRoute(
            path: '/home',
            builder: (_, _) => page('home'),
            routes: [
              GoRoute(path: 'room/:roomId', builder: (_, _) => page('room')),
            ],
          ),
          GoRoute(path: '/live/new', builder: (_, _) => page('go live')),
          GoRoute(
            path: '/events/:id',
            builder: (_, s) => page('event ${s.pathParameters['id']}'),
          ),
        ],
      );
      addTearDown(router.dispose);
      final prefs = await testPrefs(language: 'ar');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
            currentUserProvider.overrideWithValue(testUser()),
            eventAnnouncementsRepositoryProvider.overrideWithValue(repo),
            if (hosting) liveMinimizedProvider.overrideWith(_Minimized.new),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              return MaterialApp.router(
                routerConfig: router,
                locale: AppLanguage.ar.locale,
                supportedLocales: KabsoApp.supportedLocales,
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  ...GlobalMaterialLocalizations.delegates,
                ],
                theme: buildAppTheme(
                  brightness: Brightness.dark,
                  locale: AppLanguage.ar.locale,
                ),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(disableAnimations: true),
                  child: Stack(
                    children: [
                      child!,
                      EventAnnouncementGate(router: router),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      return router;
    }

    testWidgets('shows each one once, wins first, marks it seen when closed; '
        '«عرض النتائج» opens the event', (tester) async {
      final router = await pumpGate(tester);
      expect(repo.calls, 1);
      expect(find.text('مبروك'), findsOneWidget);
      await tester.tap(find.byKey(EventAnnouncementView.openKey));
      await tester.pumpAndSettle();
      expect(repo.seen, ['win_01a1b6a1-0000-7000-8000-00000000a340']);
      // The event page is open — and the start announcement waits over it.
      expect(find.text('بدأت فعالية جديدة'), findsOneWidget);
      await tester.tap(find.byKey(EventAnnouncementView.laterKey));
      await tester.pumpAndSettle();
      expect(repo.seen, hasLength(2));
      expect(find.byKey(EventAnnouncementView.viewKey), findsNothing);
      expect(router.state.matchedLocation, '/events/$_id');
      expect(find.text('event $_id'), findsOneWidget);
      // Back in the foreground: nothing new to show.
      _backToForeground(tester);
      await tester.pumpAndSettle();
      expect(repo.calls, 2);
      expect(find.byKey(EventAnnouncementView.viewKey), findsNothing);
    });

    testWidgets('waits while the person watches a live, shows once they '
        'leave', (tester) async {
      final router = await pumpGate(tester, initial: '/home/room/r1');
      expect(find.text('room'), findsOneWidget);
      expect(find.byKey(EventAnnouncementView.viewKey), findsNothing);
      router.go('/home');
      await tester.pumpAndSettle();
      expect(find.text('مبروك'), findsOneWidget);
    });

    testWidgets('a live room pushed over the app (as the app opens lives) '
        'holds them back too; leaving it shows them', (tester) async {
      final router = await pumpGate(tester, items: []);
      unawaited(router.push('/home/room/r2'));
      await tester.pumpAndSettle();
      expect(find.text('room'), findsOneWidget);
      repo.items.add(_win(true));
      _backToForeground(tester);
      await tester.pumpAndSettle();
      expect(repo.calls, 2);
      expect(find.byKey(EventAnnouncementView.viewKey), findsNothing);
      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('مبروك'), findsOneWidget);
    });

    testWidgets('waits on the go-live screen and while a hosted live is '
        'minimized', (tester) async {
      final router = await pumpGate(tester, initial: '/live/new');
      expect(find.byKey(EventAnnouncementView.viewKey), findsNothing);
      router.go('/home');
      await tester.pumpAndSettle();
      expect(find.byKey(EventAnnouncementView.viewKey), findsOneWidget);
    });

    testWidgets('a minimized hosted live keeps them queued until it ends', (
      tester,
    ) async {
      await pumpGate(tester, hosting: true, items: [_win(true)]);
      expect(repo.calls, 1);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(EventAnnouncementGate)),
      );
      expect(container.read(liveMinimizedProvider), isTrue);
      _backToForeground(tester);
      await tester.pumpAndSettle();
      expect(find.byKey(EventAnnouncementView.viewKey), findsNothing);
      expect(repo.seen, isEmpty);
      container.read(liveMinimizedProvider.notifier).restore();
      await tester.pumpAndSettle();
      expect(find.byKey(EventAnnouncementView.viewKey), findsOneWidget);
    });
  });

  forEachLanguage((language) {
    final ar = language == AppLanguage.ar;
    for (final brightness in Brightness.values) {
      final b = brightness.name;
      testWidgets('golden events.d340.ended.winner.$b ($language)', (
        tester,
      ) async {
        await _pumpPage(
          tester,
          me: _Me.winner,
          language: language,
          brightness: brightness,
        );
        await _showBoards(tester);
        await expectScreenGolden(
          'events.d340.ended.winner.$b',
          language: language,
        );
      }, tags: ['golden']);
      testWidgets('golden events.d340.ended.notQualified.$b ($language)', (
        tester,
      ) async {
        await _pumpPage(
          tester,
          me: _Me.notQualified,
          language: language,
          brightness: brightness,
        );
        await _showBoards(tester);
        await expectScreenGolden(
          'events.d340.ended.notQualified.$b',
          language: language,
        );
      }, tags: ['golden']);
      testWidgets('golden events.d340.zeroMinimum.cp.$b ($language)', (
        tester,
      ) async {
        await _pumpPage(
          tester,
          me: _Me.running,
          language: language,
          brightness: brightness,
        );
        await _showBoards(tester, tab: EventBoardKind.cp);
        await expectScreenGolden(
          'events.d340.zeroMinimum.cp.$b',
          language: language,
        );
      }, tags: ['golden']);
      testWidgets('golden events.d340.announce.start.$b ($language)', (
        tester,
      ) async {
        await _pumpView(
          tester,
          _start(ar),
          language: language,
          brightness: brightness,
        );
        await expectScreenGolden(
          'events.d340.announce.start.$b',
          language: language,
        );
      }, tags: ['golden']);
      testWidgets('golden events.d340.announce.win.$b ($language)', (
        tester,
      ) async {
        await _pumpView(
          tester,
          _win(ar),
          language: language,
          brightness: brightness,
        );
        await expectScreenGolden(
          'events.d340.announce.win.$b',
          language: language,
        );
      }, tags: ['golden']);
    }
  });
}

class _Minimized extends LiveMinimized {
  @override
  bool build() => true;
}

/// Background, then foreground (the transitions the binding accepts).
void _backToForeground(WidgetTester tester) => const [
  AppLifecycleState.inactive,
  AppLifecycleState.hidden,
  AppLifecycleState.paused,
  AppLifecycleState.hidden,
  AppLifecycleState.inactive,
  AppLifecycleState.resumed,
].forEach(tester.binding.handleAppLifecycleStateChanged);
