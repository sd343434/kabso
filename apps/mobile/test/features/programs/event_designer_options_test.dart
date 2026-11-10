// KL-352 DESIGN-OPTIONS captures (scratch branch, not a regression test):
// the rules button options, the five card theme presets and the countdown
// banners, on the gift event page over the owner's sample background
// (`test/fixtures/programs/d303_event_bg_treasure.webp`). Writes PNGs with
// `flutter test --update-goldens` into `designer_png/` and a JSON of the
// measured rects next to each, for the contrast check.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/programs/data/programs_repository.dart';
import 'package:kabso_live/features/programs/presentation/event_detail_screen.dart';
import 'package:kabso_live/features/programs/presentation/event_page_theme.dart';
import 'package:kabso_live/features/programs/presentation/gift_event_sections.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

UserSummary _u(String id, String name) =>
    UserSummary(id: id, username: id, displayName: name, avatarUrl: null);

EventDetail _event(bool ar, {bool art = false}) => EventDetail(
  id: '01a1b6a1-0000-7000-8000-000000000303',
  title: ar ? 'ملك الهدايا' : 'Gift King',
  startsAt: DateTime.utc(2026, 11, 10, 17),
  endsAt: DateTime.utc(2026, 11, 17, 17),
  status: EventStatus.running,
  metric: 'EVENT_GIFTS',
  forHosts: false,
  permanent: false,
  featured: true,
  rules: ar
      ? 'شارك بإرسال هدايا الفعالية.'
      : 'Join by sending the event gifts.',
  art: art
      ? const EventArt(
          backgroundKind: 'IMAGE',
          backgroundUrl: 'https://media.example.test/media/events/bg/x.webp',
        )
      : const EventArt(),
  prizes: const [],
  timeZone: 'Asia/Riyadh',
  gifts: [
    EventGiftInfo(
      code: 'rose',
      name: ar ? 'وردة' : 'Rose',
      priceCoins: 10,
      assetKey: 'gift_rose',
      pointsPerCoin: 2,
      pointsPerGift: 0,
      pointsEach: 20,
    ),
    EventGiftInfo(
      code: 'crown',
      name: ar ? 'تاج' : 'Crown',
      priceCoins: 1000,
      assetKey: 'gift_crown',
      pointsPerCoin: 1,
      pointsPerGift: 50,
      pointsEach: 1050,
    ),
  ],
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
            EventPrizeItem(
              type: 'VIP',
              days: 30,
              code: 'VIP_1',
              name: ar ? 'في آي بي 1' : 'VIP 1',
              category: 'VIP',
            ),
          ],
        ),
        (
          rankFrom: 2,
          rankTo: 3,
          items: [const EventPrizeItem(type: 'CHERRIES', amount: 500)],
        ),
      ],
    ),
    const EventBoardInfo(
      kind: EventBoardKind.receivers,
      minPoints: 0,
      prizes: [
        (
          rankFrom: 1,
          rankTo: 1,
          items: [EventPrizeItem(type: 'COINS', amount: 7000)],
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
          items: [
            EventPrizeItem(type: 'CP_MONEY', cherries: 400, coins: 250),
            EventPrizeItem(type: 'BAG_ITEM', code: 'car', name: 'Car'),
          ],
        ),
      ],
    ),
  ],
);

EventLeaderboard _board(EventBoardKind kind, bool ar) => switch (kind) {
  EventBoardKind.cp => EventLeaderboard(
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
        prize: const [],
      ),
    ],
  ),
  _ => EventLeaderboard(
    isFinal: false,
    rows: const [],
    myRank: 3,
    myScore: 400,
    myPrize: 0,
    board: kind,
    minPoints: 1000,
    pointsToQualify: 600,
    giftRows: [
      GiftBoardRow(
        rank: 1,
        user: _u('s1', ar ? 'سارة' : 'Sara'),
        score: 21000,
        qualified: true,
        prize: const [EventPrizeItem(type: 'COINS', amount: 10000)],
      ),
      GiftBoardRow(
        rank: 2,
        user: _u('s2', ar ? 'خالد' : 'Khaled'),
        score: 1500,
        qualified: true,
        prize: const [EventPrizeItem(type: 'CHERRIES', amount: 500)],
      ),
      GiftBoardRow(
        rank: 3,
        user: _u('me', ar ? 'أنا' : 'Me'),
        score: 400,
        qualified: false,
        prize: const [],
      ),
    ],
  ),
};

class _Programs implements ProgramsRepository {
  new({required this.ar, this.art = false});

  final bool ar;
  final bool art;
  final List<String?> boards = [];

  @override
  Future<EventDetail> event(String eventId) async => _event(ar, art: art);

  @override
  Future<EventLeaderboard> leaderboard(String eventId, {String? board}) async {
    boards.add(board);
    return _board(EventBoardKind.fromWire(board) ?? EventBoardKind.senders, ar);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final Uint8List _bg = File('test/fixtures/programs/d303_event_bg_treasure.webp')
    .readAsBytesSync();

Future<_Programs> _pump(
  WidgetTester tester, {
  AppLanguage language = AppLanguage.en,
  Brightness brightness = Brightness.dark,
  bool art = false,
}) async {
  GiftEventBackdrop.imageForTesting = (_) => MemoryImage(_bg);
  EventDetailScreen.countdownClock = () => DateTime.utc(2026, 11, 12, 9, 30);
  addTearDown(() {
    GiftEventBackdrop.imageForTesting = null;
    EventDetailScreen.countdownClock = null;
  });
  final repo = _Programs(ar: language == AppLanguage.ar, art: art);
  final prefs = await testPrefs(language: language.name);
  await pumpGolden(
    tester,
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
        currentUserProvider.overrideWithValue(testUser()),
        programsRepositoryProvider.overrideWithValue(repo),
      ],
      child: const EventDetailScreen(
        eventId: '01a1b6a1-0000-7000-8000-000000000303',
      ),
    ),
    language: language,
    brightness: brightness,
    bare: true,
  );
  return repo;
}

Future<void> _capture(WidgetTester tester, String name) async {
  final rects = <String, List<double>>{};
  void add(String id, Finder f) {
    if (f.evaluate().length != 1) return;
    final r = tester.getRect(f);
    rects[id] = [r.left, r.top, r.right, r.bottom];
  }

  add('gifts', find.byKey(EventGiftsSection.sectionKey));
  add('boards', find.byKey(GiftEventBoards.sectionKey));
  add('me', find.byKey(GiftEventBoards.meKey));
  add(
    'countdown',
    find.byKey(EventGiftsSection.sectionKey).evaluate().isEmpty
        ? find.byKey(EventCountdown.countdownKey)
        : find.byKey(EventCountdown.countdownKey),
  );
  add('bar', find.byKey(GiftEventMyBar.barKey));
  add('rulesButton', find.byKey(EventDetailScreen.rulesButtonKey));
  add('sheet', find.byKey(EventRulesSheet.sheetKey));
  for (final k in [EventBoardKind.senders, EventBoardKind.receivers]) {
    add('tab.${k.wire}', find.byKey(GiftEventBoards.tabKey(k)));
  }
  add('tile.rose', find.byKey(EventGiftsSection.giftKey('rose')));
  final dir = Directory('test/features/programs/designer_png')
    ..createSync(recursive: true);
  File('${dir.path}/$name.json').writeAsStringSync(jsonEncode(rects));
  // The real @3x pixels (a golden file is written at 1x).
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byType(RepaintBoundary).first,
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 3);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('${dir.path}/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

Future<void> _scrollToBoards(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.byKey(GiftEventBoards.tabKey(EventBoardKind.senders)),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  final top = tester.getRect(find.byKey(GiftEventBoards.sectionKey)).top;
  // Bring the boards card just under the app bar.
  await tester.drag(find.byType(Scrollable).first, Offset(0, -(top - 110)));
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() {
    EventDetailScreen.designTheme = null;
    EventDetailScreen.designRules = null;
    EventDetailScreen.designCountdown = EventCountdownStyle.pill;
    EventDetailScreen.designSections = const ['gifts', 'rules', 'boards'];
  });

  // D. Reordered: boards first, then gifts; the rules card hidden (the
  // ribbon opens them). Recommended button + preset.
  testWidgets('reordered', (tester) async {
    EventDetailScreen.designTheme = EventPageTheme.luxuryGold;
    EventDetailScreen.designRules = EventRulesButtonStyle.edgeRibbonEnd;
    EventDetailScreen.designSections = const ['boards', 'gifts'];
    await _pump(tester, language: AppLanguage.ar, art: true);
    expect(find.byKey(EventDetailScreen.rulesKey), findsNothing);
    await _capture(tester, 'D_reordered_top.ar');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -520));
    await tester.pumpAndSettle();
    await _capture(tester, 'D_reordered_scrolled.ar');
    await tester.tap(find.byKey(EventDetailScreen.rulesButtonKey));
    await tester.pumpAndSettle();
    await _capture(tester, 'D_reordered_rules_sheet.ar');
  });
  // The recommended pair with the segmented countdown (same page).
  testWidgets('recommended combo', (tester) async {
    EventDetailScreen.designTheme = EventPageTheme.luxuryGold;
    EventDetailScreen.designRules = EventRulesButtonStyle.edgeRibbonEnd;
    EventDetailScreen.designCountdown = EventCountdownStyle.segmented;
    EventDetailScreen.designSections = const ['boards', 'gifts'];
    await _pump(tester, language: AppLanguage.ar, art: true);
    await _capture(tester, 'D_reordered_segmented_top.ar');
  });

  // A. The rules button.
  for (final style in EventRulesButtonStyle.values) {
    testWidgets('rules.${style.name}', (tester) async {
      EventDetailScreen.designRules = style;
      await _pump(tester, language: AppLanguage.ar, art: true);
      await _capture(tester, 'A_rules_${style.index + 1}_${style.name}.ar');
    });
  }
  testWidgets('rules.edgeRibbonEnd en', (tester) async {
    EventDetailScreen.designRules = EventRulesButtonStyle.edgeRibbonEnd;
    await _pump(tester, art: true);
    await _capture(tester, 'A_rules_1_edgeRibbonEnd.en');
  });
  testWidgets('rules sheet', (tester) async {
    EventDetailScreen.designRules = EventRulesButtonStyle.edgeRibbonEnd;
    await _pump(tester, language: AppLanguage.ar, art: true);
    await tester.tap(find.byKey(EventDetailScreen.rulesButtonKey));
    await tester.pumpAndSettle();
    expect(find.byKey(EventRulesSheet.sheetKey), findsOneWidget);
    await _capture(tester, 'A_rules_sheet.ar');
  });

  // B. The card theme presets.
  for (final theme in EventPageTheme.presets) {
    testWidgets('theme.${theme.id}', (tester) async {
      EventDetailScreen.designTheme = theme;
      await _pump(tester, language: AppLanguage.ar, art: true);
      await _capture(tester, 'B_theme_${theme.id}_top.ar');
      await _scrollToBoards(tester);
      await _capture(tester, 'B_theme_${theme.id}_boards.ar');
    });
  }
  testWidgets('theme.current', (tester) async {
    await _pump(tester, language: AppLanguage.ar, art: true);
    await _capture(tester, 'B_theme_current_top.ar');
    await _scrollToBoards(tester);
    await _capture(tester, 'B_theme_current_boards.ar');
  });

  // C. The countdown banners.
  for (final style in EventCountdownStyle.values) {
    testWidgets('countdown.${style.name}', (tester) async {
      EventDetailScreen.designCountdown = style;
      await _pump(tester, language: AppLanguage.ar, art: true);
      await _capture(tester, 'C_countdown_${style.index}_${style.name}.ar');
    });
  }
}
