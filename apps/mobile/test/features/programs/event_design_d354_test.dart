// D354 (owner 2026-11-10 «اجعل كل الخيارات متاحة»; CONVENTIONS §10.150): the
// event page designer, phase 1 in the app. A gift event's `design` draws one
// of three layouts with one of five leaderboard styles, six countdowns, six
// card presets, six rules buttons on either edge (or none), the sections in
// the team's order, the rewards tab from the team's tiers over the boards'
// own prize lines, the leaderboard background and the motion settings — over
// the event's real data (the repository, not fixtures inside the app). A null
// or unknown design is today's page.
//
// Goldens (a representative matrix, not every combination — CONVENTIONS
// §10.150.7 lists it): each layout, each leaderboard style, each large
// countdown, each preset and each rules button appear at least once; the
// rewards tab in both languages; 360 × 800 at text scale 1.3. The photos are
// Kabso's development previews and the background the owner's D303 sample.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/core/svga/svga_engine.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/programs/data/event_page_design.dart';
import 'package:kabso_live/features/programs/data/programs_repository.dart';
import 'package:kabso_live/features/programs/presentation/event_concepts.dart';
import 'package:kabso_live/features/programs/presentation/event_designed_page.dart';
import 'package:kabso_live/features/programs/presentation/event_detail_screen.dart';
import 'package:kabso_live/features/programs/presentation/event_hero_countdown.dart';
import 'package:kabso_live/features/programs/presentation/event_leaderboard_styles.dart';
import 'package:kabso_live/features/programs/presentation/event_page_theme.dart';
import 'package:kabso_live/features/programs/presentation/gift_event_sections.dart';
import 'package:kabso_live/features/vip/presentation/vip_svga.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/svga_fixture.dart';

const _id = '01a1b6a1-0000-7000-8000-000000000354';
const _media = 'https://media.example.test';

final Uint8List _bg = File('test/fixtures/programs/d303_event_bg_treasure.webp')
    .readAsBytesSync();

ImageProvider _image(String url) {
  final m = RegExp('avatar_[a-z]+').firstMatch(url);
  if (m != null) {
    return MemoryImage(
      File('assets/preview/${m.group(0)}.webp').readAsBytesSync(),
    );
  }
  return MemoryImage(_bg);
}

Map<String, Object?> _designJson({
  String layout = 'HERO_PODIUM',
  String leaderboard = 'THRONE',
  String countdown = 'CLASSIC',
  String preset = 'CLASSIC',
  Map<String, Object?>? rules,
  List<String> order = const [
    'GIFTS',
    'RULES',
    'BOARDS',
    'REWARDS',
    'MILESTONES',
  ],
  List<String> hidden = const [],
  bool background = false,
  bool tiers = true,
  Map<String, Object?> motion = const {},
}) => {
  'v': 1,
  'layout': layout,
  'leaderboard': leaderboard,
  'countdown': countdown,
  'preset': preset,
  'rulesButton': rules,
  'sections': [
    for (final id in order) {'id': id, 'visible': !hidden.contains(id)},
  ],
  'leaderboardBackgroundMediaId': null,
  'leaderboardBackgroundUrl': background ? '$_media/media/x/1080.webp' : null,
  'rewards': tiers
      ? {
          'tiers': [
            {
              'board': 'SENDERS',
              'from': 1,
              'to': 1,
              'labelAr': 'البطل',
              'labelEn': 'Champion',
              'featured': [1],
            },
            {'board': 'SENDERS', 'from': 2, 'to': 2, 'featured': <int>[]},
            {'board': 'SENDERS', 'from': 3, 'to': 3, 'featured': <int>[]},
            {'board': 'SENDERS', 'from': 4, 'to': 10, 'featured': <int>[]},
          ],
        }
      : null,
  'motion': {
    'entrance': 'FADE',
    'durationMs': 450,
    'shimmer': true,
    'pulseFirst': true,
    'overlaySpeed': 1,
    'overlayOpacity': 1,
    ...motion,
  },
};

/// The event as the server sends it (`EventDetail`), parsed by the app.
EventDetail _event(
  bool ar,
  Map<String, Object?>? design, {
  String metric = 'EVENT_GIFTS',
  Map<String, Object?>? overlay,
}) => EventDetail.fromJson({
  'id': _id,
  'title': ar ? 'ملك الهدايا' : 'Gift King',
  'startsAt': '2026-11-10T17:00:00Z',
  'endsAt': '2026-11-17T17:00:00Z',
  'status': 'RUNNING',
  'metric': metric,
  'audience': 'EVERYONE',
  'permanent': false,
  'featured': true,
  'rules': ar
      ? 'شارك بإرسال هدايا الفعالية في أي بث.'
      : 'Send the event gifts in any live.',
  'prizes': const <Object?>[],
  'timeZone': 'Asia/Riyadh',
  'art': {
    'background': const {
      'kind': 'IMAGE',
      'url': '$_media/media/events/bg/a.webp',
      'posterUrl': null,
    },
    'titleUrl': null,
    'overlay': overlay,
  },
  'gifts': [
    for (final (i, g) in [
      (ar ? 'وردة' : 'Rose', 100),
      (ar ? 'تاج' : 'Crown', 5000),
      (ar ? 'قلعة' : 'Castle', 50000),
    ].indexed)
      {
        'code': 'd354_$i',
        'name': g.$1,
        'priceCoins': g.$2,
        'assetKey': 'd354_$i',
        'imageUrl': null,
        'pointsPerCoin': 1,
        'pointsPerGift': 0,
        'pointsEach': g.$2,
      },
  ],
  'boards': [
    {
      'kind': 'SENDERS',
      'minPoints': 1000,
      'shown': 20,
      'prizes': [
        {
          'rankFrom': 1,
          'rankTo': 1,
          'items': [
            const {'type': 'COINS', 'amount': 100000},
            {
              'type': 'BAG_ITEM',
              'days': null,
              'code': 'frame_gold',
              'name': ar ? 'إطار البطل' : 'Champion frame',
              'category': 'AVATAR_FRAME',
            },
            {
              'type': 'GIFT_PIECES',
              'amount': 3,
              'code': 'd354_2',
              'name': ar ? 'قلعة' : 'Castle',
              'category': 'GIFT',
            },
          ],
        },
        {
          'rankFrom': 2,
          'rankTo': 2,
          'items': [
            const {'type': 'COINS', 'amount': 50000},
            {
              'type': 'BAG_ITEM',
              'days': 7,
              'code': 'car',
              'name': ar ? 'سيارة الدخول' : 'Entry car',
              'category': 'ENTRY_EFFECT',
            },
          ],
        },
        const {
          'rankFrom': 3,
          'rankTo': 3,
          'items': [
            {'type': 'COINS', 'amount': 20000},
          ],
        },
        const {
          'rankFrom': 4,
          'rankTo': 10,
          'items': [
            {'type': 'COINS', 'amount': 5000},
          ],
        },
      ],
    },
    const {
      'kind': 'RECEIVERS',
      'minPoints': 0,
      'shown': 20,
      'prizes': [
        {
          'rankFrom': 1,
          'rankTo': 3,
          'items': [
            {'type': 'CHERRIES', 'amount': 80000},
          ],
        },
      ],
    },
  ],
  'milestones': [
    const {
      'board': 'SENDERS',
      'points': 100000,
      'prize': [
        {'type': 'COINS', 'amount': 1000},
      ],
    },
    {
      'board': 'SENDERS',
      'points': 1000000,
      'prize': [
        {
          'type': 'BADGE',
          'days': null,
          'name': ar ? 'وسام الفعالية' : 'Event medal',
          'level': 1,
          'category': 'BADGE',
        },
      ],
    },
  ],
  'frozenAt': null,
  'payoutDueAt': null,
  'paidAt': null,
  'design': design,
});

UserSummary _u(String id, String name, [String? photo]) => UserSummary(
  id: id,
  username: id,
  displayName: name,
  avatarUrl: photo == null ? null : '$_media/a/$photo.webp',
);

EventLeaderboard _board(bool ar) {
  final names = ar
      ? [
          'سارة الحربي',
          'خالد',
          'ليان',
          'عمر',
          'نورة',
          'أحمد علي',
          'ريم',
          'يوسف',
          'هدى',
          'كريم',
          'لمى',
          'زياد',
        ]
      : [
          'Sara',
          'Khaled.77',
          'Layan',
          'Omar_Q',
          'Noura',
          'Ahmed Ali',
          'Reem',
          'Yousef',
          'Huda',
          'Karim',
          'Lama',
          'Ziad',
        ];
  const photos = [
    'avatar_layla',
    'avatar_karim',
    'avatar_rania',
    'avatar_omar',
    'avatar_huda',
  ];
  final rows = [
    for (var i = 0; i < names.length; i++)
      GiftBoardRow(
        rank: i + 1,
        user: _u('u$i', names[i], i < photos.length ? photos[i] : null),
        score: (60980000 / (i + 1) / (i + 1)).round(),
        qualified: true,
        prize: const [],
      ),
  ];
  return EventLeaderboard(
    isFinal: false,
    rows: const [],
    myRank: 8,
    myScore: rows[7].score,
    myPrize: 0,
    board: EventBoardKind.senders,
    minPoints: 1000,
    myQualified: true,
    giftRows: rows,
  );
}

class _Programs implements ProgramsRepository {
  new({
    required this.ar,
    required this.design,
    this.metric = 'EVENT_GIFTS',
    this.overlay,
  });

  final bool ar;
  final Map<String, Object?>? design;
  final String metric;
  final Map<String, Object?>? overlay;

  @override
  Future<EventDetail> event(String eventId) async =>
      _event(ar, design, metric: metric, overlay: overlay);

  @override
  Future<EventLeaderboard> leaderboard(String eventId, {String? board}) async =>
      _board(ar);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _at = DateTime.utc(2026, 11, 12, 9, 30, 5);

/// D396: with `_pump(motion: true)`, whether the page has motion (a golden
/// turns it on once the page has settled: the page's own motion never does).
final _overlayMotion = ValueNotifier<bool>(true);

Future<void> _pump(
  WidgetTester tester, {
  Map<String, Object?>? design,
  AppLanguage language = AppLanguage.ar,
  GoldenViewport viewport = GoldenViewport.phone,
  String metric = 'EVENT_GIFTS',
  Map<String, Object?>? overlay,
  // D396: the overlay plays only with motion (the goldens turn it off).
  bool motion = false,
}) async {
  EventDetailScreen.countdownClock = () => _at;
  EventHeroCountdown.debugClock = () => _at;
  GiftEventBackdrop.imageForTesting = _image;
  addTearDown(() {
    EventDetailScreen.countdownClock = null;
    EventHeroCountdown.debugClock = null;
    GiftEventBackdrop.imageForTesting = null;
  });
  final prefs = await testPrefs(language: language.name);
  await pumpGolden(
    tester,
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
        currentUserProvider.overrideWithValue(testUser()),
        programsRepositoryProvider.overrideWithValue(
          _Programs(
            ar: language == AppLanguage.ar,
            design: design,
            metric: metric,
            overlay: overlay,
          ),
        ),
      ],
      child: motion
          ? ValueListenableBuilder<bool>(
              valueListenable: _overlayMotion,
              builder: (context, on, _) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: !on),
                child: const EventDetailScreen(eventId: _id),
              ),
            )
          : const EventDetailScreen(eventId: _id),
    ),
    language: language,
    viewport: viewport,
    bare: true,
  );
}

Finder get _page => find.byKey(EventDesignedPage.pageKey);

Future<void> _scrollTo(WidgetTester tester, Finder f) async {
  await tester.scrollUntilVisible(
    f,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  group('the design model (EventDetail.design)', () {
    test('null, another version, an unknown layout or a malformed value '
        '→ today’s page', () {
      expect(EventPageDesign.fromJson(null), isNull);
      expect(EventPageDesign.fromJson('HERO_PODIUM'), isNull);
      expect(EventPageDesign.fromJson({'v': 2, 'layout': 'STAGE'}), isNull);
      expect(EventPageDesign.fromJson({'v': 1, 'layout': 'GRID'}), isNull);
      expect(_event(true, {'v': 2, 'layout': 'DECK'}).design, isNull);
      // A D166 metric event is never designed.
      expect(
        _event(true, _designJson(), metric: 'GIFT_COINS_SENT').design,
        isNull,
      );
    });

    test('unknown values of the other choices fall back to their defaults', () {
      final d = EventPageDesign.fromJson({
        'v': 1,
        'layout': 'DECK',
        'leaderboard': 'TOWER',
        'countdown': 'SAND',
        'preset': 'PINK',
        'rulesButton': {'style': 'BUBBLE'},
        'sections': [
          {'id': 'BOARDS', 'visible': true},
          {'id': 'WALL', 'visible': true},
          {'id': 'RULES', 'visible': false},
        ],
        'motion': {'entrance': 'SPIN', 'durationMs': 9000, 'overlaySpeed': 9},
      })!;
      expect(d.layout, EventPageLayout.deck);
      expect(d.leaderboard, EventBoardStyle.throne);
      expect(d.countdown, EventCountdownKind.classic);
      expect(d.preset, EventCardPreset.classic);
      expect(d.rulesButton, isNull);
      expect(d.sections.map((s) => s.id), [
        EventPageSectionId.boards,
        EventPageSectionId.rules,
        EventPageSectionId.gifts,
        EventPageSectionId.rewards,
        EventPageSectionId.milestones,
      ]);
      expect(d.isVisible(EventPageSectionId.rules), isFalse);
      expect(d.motion.entrance, EventEntrance.fade);
      expect(d.motion.durationMs, 1500);
      expect(d.motion.overlaySpeed, 2);
    });

    test('every wire value of every choice parses', () {
      for (final l in EventPageLayout.values) {
        expect(EventPageDesign.fromJson({'v': 1, 'layout': l.wire})!.layout, l);
      }
      for (final s in EventBoardStyle.values) {
        expect(
          EventPageDesign.fromJson({
            'v': 1,
            'layout': 'STAGE',
            'leaderboard': s.wire,
          })!.leaderboard,
          s,
        );
      }
      for (final c in EventCountdownKind.values) {
        expect(
          EventPageDesign.fromJson({
            'v': 1,
            'layout': 'STAGE',
            'countdown': c.wire,
          })!.countdown,
          c,
        );
      }
      for (final p in EventCardPreset.values) {
        expect(
          EventPageDesign.fromJson({
            'v': 1,
            'layout': 'STAGE',
            'preset': p.wire,
          })!.preset,
          p,
        );
      }
      for (final r in EventRulesStyle.values) {
        for (final edge in ['START', 'END']) {
          final b = EventPageDesign.fromJson({
            'v': 1,
            'layout': 'STAGE',
            'rulesButton': {'style': r.wire, 'edge': edge},
          })!.rulesButton!;
          expect((b.style, b.atStart), (r, edge == 'START'));
        }
      }
      final d = _event(true, _designJson()).design!;
      expect(d.tiers!.map((t) => (t.board, t.from, t.to)), [
        ('SENDERS', 1, 1),
        ('SENDERS', 2, 2),
        ('SENDERS', 3, 3),
        ('SENDERS', 4, 10),
      ]);
      expect(d.tiers!.first.label('ar'), 'البطل');
      expect(d.tiers!.first.featured, [1]);
    });
  });

  group('null / invalid design → today’s page', () {
    for (final (name, design) in [
      ('null', null),
      ('another version', {'v': 9, 'layout': 'HERO_PODIUM'}),
      ('an unknown layout', {'v': 1, 'layout': 'GRID'}),
    ]) {
      testWidgets(name, (tester) async {
        await _pump(tester, design: design);
        expect(_page, findsNothing);
        expect(find.byKey(EventDetailScreen.titleArtKey), findsNothing);
        expect(find.byKey(EventGiftsSection.sectionKey), findsOneWidget);
        await _scrollTo(tester, find.byKey(EventDetailScreen.rulesKey));
        await _scrollTo(tester, find.byKey(GiftEventBoards.sectionKey));
        expect(find.byKey(GiftEventBoards.sectionKey), findsOneWidget);
      });
    }
  });

  group('each option renders on real data', () {
    for (final layout in EventPageLayout.values) {
      testWidgets('layout ${layout.wire}', (tester) async {
        await _pump(tester, design: _designJson(layout: layout.wire));
        expect(_page, findsOneWidget);
        expect(find.byKey(EventHero.heroKey), findsOneWidget);
        expect(find.byKey(GiftsStrip.stripKey), findsOneWidget);
        await _scrollTo(tester, find.byKey(EventDesignedPage.boardsKey));
        if (layout == EventPageLayout.deck) {
          expect(find.byType(BoardDeckCard), findsWidgets);
          expect(find.byType(LeaderboardStage), findsNothing);
        } else {
          expect(find.byType(LeaderboardStage), findsOneWidget);
        }
        // The caller's gold «مركزي» bar, from the real board.
        expect(find.byKey(GiftEventMyBar.barKey), findsOneWidget);
        expect(find.byType(MyRankBar), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    for (final style in EventBoardStyle.values) {
      testWidgets('leaderboard ${style.wire}', (tester) async {
        await _pump(tester, design: _designJson(leaderboard: style.wire));
        await _scrollTo(tester, find.byKey(EventDesignedPage.boardsKey));
        final stage = tester.widget<LeaderboardStage>(
          find.byType(LeaderboardStage),
        );
        expect(stage.style, eventStageStyle(style));
        expect(stage.entries.first.name, 'سارة الحربي');
        expect(stage.entries.firstWhere((e) => e.isMe).rank, 8);
        expect(stage.background, isNull);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('the leaderboard background is the uploaded picture', (
      tester,
    ) async {
      await _pump(tester, design: _designJson(background: true));
      await _scrollTo(tester, find.byKey(EventDesignedPage.boardsKey));
      expect(
        tester
            .widget<LeaderboardStage>(find.byType(LeaderboardStage))
            .background,
        isNotNull,
      );
    });

    for (final kind in EventCountdownKind.values) {
      testWidgets('countdown ${kind.wire}', (tester) async {
        await _pump(tester, design: _designJson(countdown: kind.wire));
        if (kind == EventCountdownKind.classic) {
          expect(find.byKey(EventCountdown.countdownKey), findsOneWidget);
          expect(find.byKey(EventHeroCountdown.key0), findsNothing);
        } else {
          expect(find.byKey(EventHeroCountdown.key0), findsOneWidget);
          final w = tester.widget<EventHeroCountdown>(
            find.byType(EventHeroCountdown),
          );
          expect(w.style.name, kind.name);
        }
        expect(tester.takeException(), isNull);
      });
    }

    for (final style in EventRulesStyle.values) {
      for (final atStart in [false, true]) {
        testWidgets('rules button ${style.wire} ${atStart ? 'START' : 'END'} '
            '(rules section hidden)', (tester) async {
          await _pump(
            tester,
            design: _designJson(
              rules: {'style': style.wire, 'edge': atStart ? 'START' : 'END'},
              hidden: const ['RULES'],
            ),
          );
          final button = find.byKey(EventDesignedPage.rulesButtonKey);
          expect(button, findsOneWidget);
          expect(find.byKey(EventDesignedPage.rulesSectionKey), findsNothing);
          // Edges are logical: START is the right edge in Arabic.
          if (style == EventRulesStyle.edgeRibbon ||
              style == EventRulesStyle.sideTab) {
            final r = tester.getRect(button);
            if (atStart) {
              expect(r.right, closeTo(393, 1));
            } else {
              expect(r.left, closeTo(0, 1));
            }
          }
          await tester.tap(button);
          await tester.pumpAndSettle();
          expect(find.byKey(EventRulesSheet.sheetKey), findsOneWidget);
          expect(
            find.textContaining('شارك بإرسال هدايا الفعالية'),
            findsWidgets,
          );
        });
      }
    }

    testWidgets('the START edge is the left edge in English', (tester) async {
      await _pump(
        tester,
        language: AppLanguage.en,
        design: _designJson(rules: {'style': 'EDGE_RIBBON', 'edge': 'START'}),
      );
      expect(
        tester.getRect(find.byKey(EventDesignedPage.rulesButtonKey)).left,
        closeTo(0, 1),
      );
    });

    for (final preset in EventCardPreset.values) {
      testWidgets('preset ${preset.wire}', (tester) async {
        await _pump(tester, design: _designJson(preset: preset.wire));
        final ctx = tester.element(find.byKey(GiftsStrip.stripKey));
        expect(EventPageTheme.of(ctx), eventPresetTheme(preset));
        expect(
          EventPageTheme.of(ctx) == null,
          preset == EventCardPreset.classic,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('sections, rewards and motion', () {
    testWidgets(
      'the sections follow the team’s order; hidden ones are left out',
      (tester) async {
        await _pump(
          tester,
          design: _designJson(
            order: const ['MILESTONES', 'BOARDS', 'GIFTS', 'RULES', 'REWARDS'],
            hidden: const ['GIFTS'],
          ),
        );
        Finder s(EventPageSectionId id) =>
            find.byKey(EventDesignedPage.sectionKey(id), skipOffstage: false);
        expect(s(EventPageSectionId.gifts), findsNothing);
        final ys = [
          for (final id in [
            EventPageSectionId.milestones,
            EventPageSectionId.boards,
            EventPageSectionId.rules,
          ])
            tester.getTopLeft(s(id)).dy,
        ];
        expect(ys, orderedEquals([...ys]..sort()));
        expect(find.byKey(EventDesignedPage.milestonesKey), findsOneWidget);
      },
    );

    testWidgets('the rewards tab: the team’s tiers, the featured prize, '
        'the board’s own prizes', (tester) async {
      await _pump(tester, design: _designJson());
      await tester.tap(find.byKey(GoldTabs.tabKey(1)));
      await tester.pumpAndSettle();
      expect(find.byKey(RewardTierCard.tierKey(1)), findsOneWidget);
      expect(find.text('البطل'), findsOneWidget);
      // Featured: item 1 of the rank-1 line (the frame).
      expect(find.byType(FeaturedReward), findsOneWidget);
      expect(
        tester.widget<FeaturedReward>(find.byType(FeaturedReward)).p.name,
        'إطار البطل',
      );
      // Another board without designed tiers: one tier per prize line.
      await tester.tap(
        find.byKey(GiftEventBoards.tabKey(EventBoardKind.receivers)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(RewardTierCard), findsOneWidget);
      expect(find.byKey(RewardTierCard.tierKey(1)), findsOneWidget);
      expect(find.text('البطل'), findsNothing);
      // Back on the senders: every designed tier, down to 4–10.
      await tester.tap(
        find.byKey(GiftEventBoards.tabKey(EventBoardKind.senders)),
      );
      await tester.pumpAndSettle();
      await _scrollTo(tester, find.byKey(RewardTierCard.tierKey(4)));
      expect(find.byType(RewardTierCard), findsNWidgets(4));
    });

    testWidgets('without designed tiers each prize line is a tier; '
        'REWARDS hidden → no tabs', (tester) async {
      await _pump(tester, design: _designJson(tiers: false));
      await tester.tap(find.byKey(GoldTabs.tabKey(1)));
      await tester.pumpAndSettle();
      expect(find.byKey(RewardTierCard.tierKey(1)), findsOneWidget);
      expect(find.byKey(RewardTierCard.tierKey(2)), findsOneWidget);
      await _pump(tester, design: _designJson(hidden: const ['REWARDS']));
      expect(find.byType(GoldTabs), findsNothing);
    });

    testWidgets('REWARDS before BOARDS opens on the rewards tab', (
      tester,
    ) async {
      await _pump(
        tester,
        design: _designJson(
          order: const ['REWARDS', 'GIFTS', 'RULES', 'BOARDS', 'MILESTONES'],
        ),
      );
      expect(find.byKey(RewardTierCard.tierKey(1)), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(GoldTabs.tabKey(1))).dx,
        greaterThan(tester.getTopLeft(find.byKey(GoldTabs.tabKey(0))).dx),
      );
    });

    testWidgets(
      'motion: off with reduce-motion; the switches reach the stage',
      (tester) async {
        await _pump(
          tester,
          design: _designJson(
            motion: {
              'shimmer': false,
              'pulseFirst': false,
              'entrance': 'SLIDE',
            },
          ),
        );
        // The goldens' app reduces motion: no entrance animation, no ticker.
        expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
        final ctx = tester.element(find.byKey(GiftsStrip.stripKey));
        expect(StageMotion.shimmerOf(ctx), isFalse);
        expect(StageMotion.pulseOf(ctx), isFalse);
        await tester.pumpAndSettle();
        expect(tester.binding.transientCallbackCount, 0);
      },
    );

    testWidgets(
      'motion: the entrance plays when motion is allowed (and NONE does not)',
      (tester) async {
        for (final (entrance, plays) in [('FADE', true), ('NONE', false)]) {
          EventHeroCountdown.debugClock = () => _at;
          GiftEventBackdrop.imageForTesting = _image;
          addTearDown(() {
            EventHeroCountdown.debugClock = null;
            GiftEventBackdrop.imageForTesting = null;
          });
          final e = _event(true, _designJson(motion: {'entrance': entrance}));
          await loadAppFonts();
          final prefs = await testPrefs(language: 'ar');
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                sharedPreferencesProvider.overrideWithValue(prefs),
                secureTokenStoreProvider.overrideWithValue(
                  InMemoryTokenStore(),
                ),
                currentUserProvider.overrideWithValue(testUser()),
                programsRepositoryProvider.overrideWithValue(
                  _Programs(ar: true, design: null),
                ),
              ],
              child: MaterialApp(
                locale: const Locale('ar'),
                supportedLocales: const [Locale('ar'), Locale('en')],
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  ...GlobalMaterialLocalizations.delegates,
                ],
                home: EventDesignedPage(
                  event: e,
                  design: e.design!,
                  onRefresh: () async {},
                  now: () => _at,
                ),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 50));
          expect(
            find.byType(TweenAnimationBuilder<double>).evaluate().isNotEmpty,
            plays,
            reason: entrance,
          );
          await tester.pumpWidget(const SizedBox());
        }
      },
    );
  });

  group('360 × 800 at text scale 1.3, Arabic and English', () {
    for (final layout in EventPageLayout.values) {
      testWidgets(
        'layout ${layout.wire}: no overflow, the tabs and the bar fit',
        (tester) async {
          tester.platformDispatcher.textScaleFactorTestValue = 1.3;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          for (final language in AppLanguage.values) {
            // A fresh tree per language (no state carried over).
            await tester.pumpWidget(const SizedBox());
            await _pump(
              tester,
              language: language,
              viewport: GoldenViewport.android,
              design: _designJson(
                layout: layout.wire,
                countdown: 'FLIP',
                rules: {'style': 'GOLD_PILL'},
                leaderboard: 'SPOTLIGHT',
              ),
            );
            expect(tester.takeException(), isNull);
            await _scrollTo(tester, find.byKey(EventDesignedPage.boardsKey));
            expect(tester.takeException(), isNull);
            await tester.tap(find.byKey(GoldTabs.tabKey(1)));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            final bar = tester.getRect(find.byKey(GiftEventMyBar.barKey));
            expect(bar.bottom, lessThanOrEqualTo(800));
          }
        },
      );
    }
  });

  group('goldens (representative matrix)', () {
    final matrix = <(String, Map<String, Object?>, List<AppLanguage>)>[
      (
        'heroPodium.throne.flip.luxuryGold.ribbonStart',
        _designJson(
          countdown: 'FLIP',
          preset: 'LUXURY_GOLD',
          rules: {'style': 'EDGE_RIBBON', 'edge': 'START'},
          hidden: const ['RULES'],
        ),
        AppLanguage.values,
      ),
      (
        'stage.cardsRow.ring.glass.roundIcon',
        _designJson(
          layout: 'STAGE',
          leaderboard: 'CARDS_ROW',
          countdown: 'RING',
          preset: 'GLASS',
          rules: {'style': 'ROUND_ICON'},
        ),
        const [AppLanguage.ar],
      ),
      (
        'deck.podium.ribbon.kabsoRed.goldPill',
        _designJson(
          layout: 'DECK',
          leaderboard: 'PODIUM',
          countdown: 'RIBBON',
          preset: 'KABSO_RED',
          rules: {'style': 'GOLD_PILL'},
        ),
        const [AppLanguage.ar],
      ),
      (
        'heroPodium.spotlight.coins.neon.glassChip',
        _designJson(
          leaderboard: 'SPOTLIGHT',
          countdown: 'COINS',
          preset: 'NEON',
          rules: {'style': 'GLASS_CHIP', 'edge': 'START'},
        ),
        const [AppLanguage.ar],
      ),
      (
        'stage.shieldCrest.neon.darkMinimal.sideTab',
        _designJson(
          layout: 'STAGE',
          leaderboard: 'SHIELD_CREST',
          countdown: 'NEON',
          preset: 'DARK_MINIMAL',
          rules: {'style': 'SIDE_TAB'},
        ),
        const [AppLanguage.ar],
      ),
      (
        'heroPodium.classic.appBarLink.boardsFirst',
        _designJson(
          rules: {'style': 'APP_BAR_LINK'},
          order: const ['BOARDS', 'GIFTS', 'RULES', 'REWARDS', 'MILESTONES'],
          background: true,
        ),
        const [AppLanguage.ar],
      ),
    ];
    for (final (name, design, languages) in matrix) {
      for (final language in languages) {
        testWidgets('$name ${language.name}', (tester) async {
          await _pump(tester, design: design, language: language);
          await expectScreenGolden('events.d354.$name', language: language);
        });
      }
    }

    for (final language in AppLanguage.values) {
      testWidgets('the rewards tab ${language.name}', (tester) async {
        await _pump(
          tester,
          design: _designJson(preset: 'LUXURY_GOLD'),
          language: language,
        );
        await tester.tap(find.byKey(GoldTabs.tabKey(1)));
        await tester.pumpAndSettle();
        await expectScreenGolden('events.d354.rewards', language: language);
      });
    }

    testWidgets('the boards, scrolled (heroPodium.throne) ar', (tester) async {
      await _pump(tester, design: _designJson(background: true));
      await _scrollTo(tester, find.byKey(EventDesignedPage.boardsKey));
      await expectScreenGolden('events.d354.boards', language: AppLanguage.ar);
    });

    testWidgets('360 × 800 at text scale 1.3 (stage) ar', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _pump(
        tester,
        viewport: GoldenViewport.android,
        design: _designJson(
          layout: 'STAGE',
          countdown: 'FLIP',
          preset: 'LUXURY_GOLD',
        ),
      );
      await expectScreenGolden(
        'events.d354.stage.scale13',
        language: AppLanguage.ar,
        viewport: GoldenViewport.android,
      );
    });
  });

  // D396 (owner: «عند اضافة طبقة حركة في الفعاليات لا تظهر في الفعالية»): the
  // panel offers «طبقة الحركة (SVGA أو Lottie)» and the server stores both, but
  // the page drew only a Lottie overlay, and the designed page drew it under
  // the hero's opaque background (a Lottie was hidden there too).
  group('D396 the animation overlay («طبقة الحركة»)', () {
    const svga = {
      'format': 'SVGA',
      'url':
          '$_media/media/events/overlay/0b7c2f4e-0000-7000-8000-000000000396.svga',
    };
    late Future<Uint8List> Function(String) fetch;
    setUp(() {
      fetch = SvgaDocs.fetch;
      // No network in tests: the clip cannot be read (the player stays empty).
      SvgaDocs.fetch = (_) => Future.error(StateError('offline'));
    });
    tearDown(() {
      SvgaDocs.fetch = fetch;
      VipSvgaCache.clear();
    });

    /// The index of the child of [stack] whose subtree holds [target].
    int childHolding(Element stack, Element target) {
      var index = -1;
      var i = 0;
      stack.visitChildren((child) {
        var hit = false;
        void walk(Element e) {
          if (identical(e, target)) hit = true;
          if (!hit) e.visitChildren(walk);
        }

        walk(child);
        if (hit) index = i;
        i++;
      });
      return index;
    }

    Future<void> pumpOverlay(
      WidgetTester tester,
      Map<String, Object?> overlay, {
      double opacity = 1,
      bool reduceMotion = false,
    }) => tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: EventArtOverlay(
            art: EventArt.fromJson({'overlay': overlay}),
            opacity: opacity,
          ),
        ),
      ),
    );

    testWidgets('an SVGA overlay is played (it was never drawn)', (
      tester,
    ) async {
      await pumpOverlay(tester, svga);
      final overlay = find.byKey(GiftEventBackdrop.overlayKey);
      expect(overlay, findsOneWidget);
      expect(
        find.descendant(of: overlay, matching: find.byType(VipSvga)),
        findsOneWidget,
      );
      expect(
        find.ancestor(
          of: find.byType(VipSvga),
          matching: find.byType(IgnorePointer),
        ),
        findsWidgets,
      );
    });

    testWidgets('not with reduced motion, at opacity 0, or an unknown format', (
      tester,
    ) async {
      await pumpOverlay(tester, svga, reduceMotion: true);
      expect(find.byKey(GiftEventBackdrop.overlayKey), findsNothing);
      await pumpOverlay(tester, svga, opacity: 0);
      expect(find.byKey(GiftEventBackdrop.overlayKey), findsNothing);
      await pumpOverlay(tester, {...svga, 'format': 'MP4'});
      expect(find.byKey(GiftEventBackdrop.overlayKey), findsNothing);
    });

    for (final layout in ['HERO_PODIUM', 'STAGE', 'DECK']) {
      testWidgets('$layout: the overlay is in the hero, over the background '
          'and the title art, not under the cards', (tester) async {
        await _pump(
          tester,
          design: _designJson(layout: layout),
          overlay: svga,
        );
        final hero = find.byKey(EventHero.heroKey);
        expect(hero, findsOneWidget);
        final overlay = find.descendant(
          of: hero,
          matching: find.byType(EventArtOverlay),
        );
        expect(overlay, findsOneWidget);
        // Drawn after the background picture and the title art in the hero.
        final stack = find
            .descendant(of: hero, matching: find.byType(Stack))
            .first
            .evaluate()
            .single;
        final at = childHolding(stack, overlay.evaluate().single);
        expect(
          at,
          greaterThan(
            childHolding(
              stack,
              find
                  .descendant(of: hero, matching: find.byType(Image))
                  .first
                  .evaluate()
                  .single,
            ),
          ),
        );
        expect(
          at,
          greaterThan(
            childHolding(
              stack,
              find
                  .descendant(of: hero, matching: find.byType(EventTitleArt))
                  .evaluate()
                  .single,
            ),
          ),
        );
        // At the head of the page, and nowhere else (not behind the cards).
        expect(find.byType(EventArtOverlay), findsOneWidget);
        expect(tester.getTopLeft(overlay).dy, 0);
        expect(tester.getSize(overlay).height, tester.getSize(hero).height);
        // The design's speed and opacity reach it.
        expect(tester.widget<EventArtOverlay>(overlay).opacity, 1);
      });
    }

    testWidgets('no Kabso logo at the bottom of a designed page', (
      tester,
    ) async {
      await _pump(tester, design: _designJson());
      // To the end of the page.
      for (var i = 0; i < 4; i++) {
        await tester.drag(
          find.byType(Scrollable).first,
          const Offset(0, -3000),
        );
        await tester.pumpAndSettle();
      }
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Image &&
              w.image is AssetImage &&
              (w.image as AssetImage).assetName.contains('kabso_live_logo'),
        ),
        findsNothing,
      );
      expect(find.bySemanticsLabel('Kabso Live'), findsNothing);
    });

    testWidgets('today’s page (no design) plays the overlay in the top band, '
        'over the list', (tester) async {
      await _pump(tester, overlay: svga, motion: true);
      expect(find.byKey(EventDesignedPage.pageKey), findsNothing);
      final band = find.byKey(EventArtOverlayBand.bandKey);
      expect(band, findsOneWidget);
      final overlay = find.byKey(GiftEventBackdrop.overlayKey);
      expect(
        find.descendant(of: band, matching: find.byType(VipSvga)),
        findsOneWidget,
      );
      final stackFinder = find.ancestor(of: band, matching: find.byType(Stack));
      final page = tester.getRect(stackFinder.first);
      expect(tester.getTopLeft(overlay).dy, page.top);
      expect(
        tester.getSize(overlay).height,
        moreOrLessEquals(page.height * EventArtOverlayBand.heightFactor),
      );
      // Over the list (its cards), not under it.
      final list = find.byType(RefreshIndicator);
      final stack = stackFinder.first.evaluate().single;
      expect(
        childHolding(stack, band.evaluate().single),
        greaterThan(childHolding(stack, list.evaluate().single)),
      );
    });

    // The golden: a half-transparent red SVGA (the test fixture) plays over
    // the hero — background and title art — and nowhere under the cards.
    testWidgets('golden: the overlay at the head of the page', (tester) async {
      late Uint8List file;
      await tester.runAsync(() async => file = await svgaFixture(width: 180));
      final clock = VipSvga.clock;
      VipSvga.enabled = true;
      SvgaDocs.fetch = (_) async => file;
      VipSvga.clock = () => Duration(
        microseconds: tester.binding.clock.now().microsecondsSinceEpoch,
      );
      addTearDown(() {
        VipSvga.enabled = false;
        VipSvga.clock = clock;
        _overlayMotion.value = true;
      });
      _overlayMotion.value = false;
      await _pump(
        tester,
        design: _designJson(motion: {'overlayOpacity': .45}),
        overlay: svga,
        motion: true,
      );
      _overlayMotion.value = true;
      // Its pictures are decoded in the real zone, as it plays.
      for (var i = 0; i < 30; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 150)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
      await expectScreenGolden(
        'events.d396.overlay.heroPodium',
        language: AppLanguage.ar,
      );
    });
  });
}
