// D289 (owner; contract v1.79-live, CONVENTIONS §10.102): gift badges as a
// set in the gift box — a tile shows at most two running badges in the
// priority order, with their names while they fit and the icon alone when
// they do not, never over the name or the price; a lucky gift's tile keeps
// its earlier mark; a long press opens the gift's details with all its
// badges and the days left of a timed one. Arabic RTL and English LTR at
// 360×800 with text scale 1.3; goldens of the (dark) gift box and the
// details sheet.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/models/item_badge.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_gift_models.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_gift_sheet.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_gift_fixtures.dart';
import '../../helpers/fake_live_gift_repository.dart';
import '../../helpers/fake_live_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

const _host = UserSummary(
  id: 'user-sara',
  username: 'sara',
  displayName: 'Sara',
  avatarUrl: null,
);
const _open = Key('test.openGifts');

/// Far ahead: the goldens never depend on the day they run.
const _far = '2099-01-01T00:00:00.000Z';

Map<String, Object?> _badge(String code, [String? until]) => {
  'code': code,
  'until': until,
};

/// A gift of the POPULAR tab as the D289 API sends it (`badge` derived).
Map<String, Object?> _gift(
  String code,
  String ar,
  String en,
  int price,
  List<Map<String, Object?>> badges, {
  required bool arabic,
  String category = 'POPULAR',
  String legacy = 'NONE',
  int sort = 1,
}) => {
  ...giftJson('rose', ar: arabic),
  'code': code,
  'category': category,
  'name': arabic ? ar : en,
  'priceCoins': price,
  'assetKey': 'gift_$code',
  'sortOrder': sort,
  'badge': legacy,
  'badges': badges,
  'tag': null,
};

List<Map<String, Object?>> _gifts({required bool arabic}) => [
  _gift('plain', 'وردة', 'Rose', 1, const [], arabic: arabic),
  _gift(
    'one',
    'بالون',
    'Balloon',
    10,
    [_badge('NEW', _far)],
    arabic: arabic,
    legacy: 'NEW',
    sort: 2,
  ),
  _gift(
    'two',
    'سيارة',
    'Car',
    5000,
    [_badge('LIMITED', _far), _badge('SOUND')],
    arabic: arabic,
    sort: 3,
  ),
  _gift(
    'many',
    'قلعة',
    'Castle',
    99999,
    [
      _badge('LIMITED', _far),
      _badge('NEW', _far),
      _badge('EXCLUSIVE'),
      _badge('MOST_WANTED'),
      _badge('FULLSCREEN'),
      _badge('SOUND'),
    ],
    arabic: arabic,
    legacy: 'NEW',
    sort: 4,
  ),
  _gift(
    'timed',
    'فانوس',
    'Lantern',
    520,
    [
      _badge(
        'SEASONAL',
        DateTime.now()
            .toUtc()
            .add(const Duration(days: 3, hours: 1))
            .toIso8601String(),
      ),
      _badge('FEATURED'),
      _badge('NO_SOUND'),
    ],
    arabic: arabic,
    legacy: 'EVENT',
    sort: 5,
  ),
  // Ended by the device clock since the list was read: not shown.
  _gift(
    'ended',
    'نجمة',
    'Star',
    66,
    [_badge('LIMITED', '2020-01-01T00:00:00.000Z')],
    arabic: arabic,
    sort: 6,
  ),
  // A lucky gift: badges in the data, the earlier single mark on its tile.
  _gift(
    'lucky_star',
    'نجمة الحظ',
    'Lucky star',
    10,
    [_badge('NEW', _far), _badge('SOUND')],
    arabic: arabic,
    category: 'LUCKY',
    legacy: 'NEW',
    sort: 7,
  ),
];

class _Opener extends StatelessWidget {
  const new({required this.room});

  final LiveGiftRoom room;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF101014),
    body: Center(
      child: TextButton(
        key: _open,
        onPressed: () => unawaited(KLiveGiftSheet.show(context, room: room)),
        child: const SizedBox.square(dimension: 40),
      ),
    ),
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required AppLanguage language,
  double textScale = 1.3,
}) async {
  await loadAppFonts();
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  setViewport(tester, GoldenViewport.android);
  final arabic = language == AppLanguage.ar;
  final gifts = FakeLiveGiftRepository(ar: arabic, coins: 100000)
    ..categories = const ['POPULAR', 'LUCKY']
    ..extraGifts = _gifts(arabic: arabic);
  await pumpScreen(
    tester,
    _Opener(
      room: LiveGiftRoom(
        roomId: 'room-0',
        host: _host,
        seated: (_) => const [],
        onSeatsStale: () {},
      ),
    ),
    language: language,
    liveGiftRepository: gifts,
    disableAnimations: true,
    overrides: [
      liveRepositoryProvider.overrideWithValue(FakeLiveRepository()),
      currentUserProvider.overrideWithValue(testUser()),
    ],
  );
  await tester.tap(find.byKey(_open));
  await tester.pumpAndSettle();
  await precacheImages(tester);
}

Finder _cell(String code) => find.byKey(KLiveGiftSheet.cellKey(code));

Finder _in(String code, Finder f) =>
    find.descendant(of: _cell(code), matching: f);

Iterable<Key?> _pillKeys(WidgetTester tester, String code) => tester
    .widgetList<KItemBadgePill>(_in(code, find.byType(KItemBadgePill)))
    .map((p) => KItemBadgePill.keyOf(p.code, iconOnly: p.iconOnly));

void main() {
  // The captures go to the owner: no debug banner.
  setUp(() => WidgetsApp.debugAllowBannerOverride = false);
  tearDown(() => WidgetsApp.debugAllowBannerOverride = true);

  group('the model', () {
    test('reads the badges: known codes, priority order, each once', () {
      final list = itemBadgesFromJson([
        {'code': 'SOUND', 'until': null},
        {'code': 'HOT', 'until': null},
        {'code': 'LIMITED', 'until': '2027-04-01T00:00:00.000Z'},
        {'code': 'SOUND', 'until': null},
        'junk',
      ]);
      expect(list.map((b) => b.code), [
        ItemBadgeCode.limited,
        ItemBadgeCode.sound,
      ]);
      expect(list.first.until, DateTime.utc(2027, 4));
      expect(itemBadgesFromJson(null), isEmpty);
      final now = DateTime.utc(2027, 3, 29, 12);
      expect(list.first.daysLeft(now), 3);
      expect(list.first.runningAt(DateTime.utc(2027, 4, 2)), isFalse);
      expect(list.last.daysLeft(now), isNull);
    });

    test('an older API (no `badges`) shows its single badge', () {
      Gift gift(String badge, {List<Object?>? badges}) => Gift.fromJson({
        ...giftJson('rose'),
        'badge': badge,
        'badges': ?badges,
      });
      expect(gift('NEW').shownBadges.single.code, ItemBadgeCode.isNew);
      expect(gift('EVENT').shownBadges.single.code, ItemBadgeCode.seasonal);
      expect(gift('NONE').shownBadges, isEmpty);
      expect(
        gift(
          'NEW',
          badges: [
            {'code': 'FEATURED', 'until': null},
          ],
        ).shownBadges.single.code,
        ItemBadgeCode.featured,
      );
    });

    test(
      'fits names, then the first name and icons, then icons, then fewer',
      () {
        final codes = [ItemBadgeCode.limited, ItemBadgeCode.isNew];
        double label(ItemBadgeCode c) => c == ItemBadgeCode.limited ? 40 : 14;
        List<bool> icons(double w) => [
          for (final f in fitItemBadges(
            codes: codes,
            maxWidth: w,
            height: 12,
            labelWidth: label,
          ))
            f.iconOnly,
        ];
        expect(icons(200), [false, false]);
        expect(icons(75), [false, true]);
        expect(icons(30), [true, true]);
        expect(icons(13), [true]);
        expect(icons(5), isEmpty);
      },
    );
  });

  for (final language in AppLanguage.values) {
    final l10n = lookupAppLocalizations(language.locale);
    testWidgets('${language.name} 360×800 ×1.3: at most two badges, names or '
        'icons, never over the name or the price; ended ones hidden', (
      tester,
    ) async {
      await _pump(tester, language: language);
      expect(tester.takeException(), isNull);
      for (final code in ['one', 'two', 'many', 'timed']) {
        final row = find.byKey(KLiveGiftSheet.badgesKey(code));
        expect(row, findsOneWidget, reason: code);
        final rowRect = tester.getRect(row);
        final cell = tester.getRect(_cell(code));
        final price = tester.getRect(find.byKey(KLiveGiftSheet.priceKey(code)));
        expect(
          rowRect.left >= cell.left && rowRect.right <= cell.right,
          isTrue,
          reason: '$code stays in its tile',
        );
        expect(rowRect.bottom <= price.top, isTrue, reason: '$code price');
        final name = tester.getRect(
          _in(
            code,
            find.text(
              code == 'one'
                  ? (language == AppLanguage.ar ? 'بالون' : 'Balloon')
                  : code == 'two'
                  ? (language == AppLanguage.ar ? 'سيارة' : 'Car')
                  : code == 'many'
                  ? (language == AppLanguage.ar ? 'قلعة' : 'Castle')
                  : (language == AppLanguage.ar ? 'فانوس' : 'Lantern'),
            ),
          ),
        );
        expect(rowRect.bottom <= name.top, isTrue, reason: '$code name');
        expect(
          tester.widgetList(_in(code, find.byType(KItemBadgePill))).length,
          lessThanOrEqualTo(2),
          reason: code,
        );
        // The end side of the tile (the corner reads from the end).
        final end = language == AppLanguage.ar ? cell.left : cell.right;
        final rowEnd = language == AppLanguage.ar
            ? rowRect.left
            : rowRect.right;
        expect((rowEnd - end).abs(), lessThan(6), reason: '$code end corner');
      }
      expect(find.byKey(KLiveGiftSheet.badgesKey('plain')), findsNothing);
      expect(find.byKey(KLiveGiftSheet.badgesKey('ended')), findsNothing);
      // One badge with room: its name.
      expect(_pillKeys(tester, 'one'), [
        KItemBadgePill.keyOf(ItemBadgeCode.isNew),
      ]);
      // Many: the first two by priority (LIMITED, NEW).
      final many = tester
          .widgetList<KItemBadgePill>(_in('many', find.byType(KItemBadgePill)))
          .map((p) => p.code);
      expect(many, [ItemBadgeCode.limited, ItemBadgeCode.isNew]);
      // The Arabic names are too wide for the tile at ×1.3: icons only.
      if (language == AppLanguage.ar) {
        expect(
          tester
              .widgetList<KItemBadgePill>(
                _in('many', find.byType(KItemBadgePill)),
              )
              .every((p) => p.iconOnly),
          isTrue,
        );
      }
      // The screen reader hears every running badge.
      final semantics = tester.getSemantics(_cell('many'));
      expect(semantics.label, contains(l10n.itemBadgeExclusive));
      expect(semantics.label, contains(l10n.itemBadgeLimited));
    });

    testWidgets('${language.name}: the lucky tile keeps its earlier mark', (
      tester,
    ) async {
      await _pump(tester, language: language);
      await tester.tap(find.byKey(KLiveGiftSheet.tabKey('LUCKY')));
      await tester.pumpAndSettle();
      expect(_cell('lucky_star'), findsOneWidget);
      expect(find.byKey(KLiveGiftSheet.badgesKey('lucky_star')), findsNothing);
      expect(_in('lucky_star', find.byType(KItemBadgePill)), findsNothing);
      expect(
        _in('lucky_star', find.text(l10n.liveGiftBadgeNew.toUpperCase())),
        findsOneWidget,
      );
    });

    testWidgets('${language.name}: a long press shows all the badges and the '
        'days left', (tester) async {
      await _pump(tester, language: language);
      await tester.longPress(_cell('timed'));
      await tester.pumpAndSettle();
      expect(find.byKey(KLiveGiftSheet.detailsKey), findsOneWidget);
      final details = find.byKey(KItemBadgeList.listKey);
      for (final code in [
        ItemBadgeCode.seasonal,
        ItemBadgeCode.featured,
        ItemBadgeCode.noSound,
      ]) {
        expect(
          find.descendant(
            of: details,
            matching: find.byKey(KItemBadgePill.keyOf(code)),
          ),
          findsOneWidget,
          reason: code.wire,
        );
      }
      expect(
        find.descendant(
          of: details,
          matching: find.text(l10n.itemBadgeSeasonal),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: details,
          matching: find.text(l10n.itemBadgeNoSound),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: details,
          matching: find.text(l10n.itemBadgeDaysLeft(4)),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  group('goldens', () {
    for (final language in AppLanguage.values) {
      testWidgets(
        'gift box with badges (${language.name}, dark, 360×800 ×1.3)',
        (tester) async {
          await _pump(tester, language: language);
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
              '../../goldens/png/gift_box_badges.${language.name}.android.png',
            ),
          );
        },
        tags: goldenTag,
      );

      testWidgets('gift details (${language.name})', (tester) async {
        await _pump(tester, language: language);
        // A gift whose end is relative to now: the days left stay the same.
        await tester.longPress(_cell('timed'));
        await tester.pumpAndSettle();
        await precacheImages(tester);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            '../../goldens/png/gift_details_badges.${language.name}.android.png',
          ),
        );
      }, tags: goldenTag);
    }

    testWidgets('lucky tab unchanged (ar)', (tester) async {
      await _pump(tester, language: AppLanguage.ar);
      await tester.tap(find.byKey(KLiveGiftSheet.tabKey('LUCKY')));
      await tester.pumpAndSettle();
      await precacheImages(tester);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../../goldens/png/gift_box_lucky.ar.android.png'),
      );
    }, tags: goldenTag);
  });

  testWidgets('every badge pill, light and dark, both languages', (
    tester,
  ) async {
    for (final language in AppLanguage.values) {
      for (final brightness in Brightness.values) {
        await pumpGolden(
          tester,
          Wrap(
            spacing: KSpacing.sm,
            runSpacing: KSpacing.sm,
            children: [
              for (final code in ItemBadgeCode.values) ...[
                KItemBadgePill(code, height: 24),
                KItemBadgePill(code, height: 14, iconOnly: true),
              ],
            ],
          ),
          language: language,
          brightness: brightness,
          viewport: GoldenViewport.android,
        );
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            '../../goldens/png/item_badges.${language.name}.${brightness.name}.png',
          ),
        );
      }
    }
  }, tags: goldenTag);
}
