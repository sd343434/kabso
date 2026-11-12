// D374 (owner 2026-11-11: each VIP tier gets the perks the admin picks in
// the panel; contract v1.129-social, CONVENTIONS §10.166): the VIP page lists
// a tier's EFFECTIVE perks — its own and the lower tiers' (D258's
// inheritance, `VipTier.effectivePerks`) — with «قريباً» under the ones the
// app does not do yet; the «(x/y)» count follows them. Goldens: 393 × 852,
// status bar 59, home indicator 34, real fonts, a pinned clock; ar / en,
// light / dark.

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/vip/data/vip_repository.dart';
import 'package:kabso_live/features/vip/presentation/vip_carousel.dart';
import 'package:kabso_live/features/vip/presentation/vip_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';
import 'vip_points_harness.dart';

final DateTime _now = DateTime.utc(2026, 11, 11, 9, 30);

VipPerk _p(
  String code,
  String title, {
  bool built = true,
  int? amount,
  Object? value,
  String? from,
}) => VipPerk(
  code: code,
  title: title,
  available: built,
  amount: amount,
  value: value ?? amount,
  fromTier: from,
);

/// VIP 1 holds four perks; VIP 2 adds three of its own (one built, two
/// «قريباً») and raises DAILY_BULLET; it inherits the rest from VIP 1.
VipTierList _tiers(AppLanguage lang) {
  final ar = lang == AppLanguage.ar;
  final badge = _p('BADGE', ar ? 'شارة بجانب الاسم' : 'Name badge');
  final frame = _p('AVATAR_FRAME', ar ? 'إطار الصورة' : 'Avatar frame');
  final bullet1 = _p(
    'DAILY_BULLET',
    ar ? 'رسائل عامة مجانية' : 'Free public messages',
    amount: 3,
  );
  final visitors = _p(
    'PROFILE_VISITORS',
    ar ? 'من زار ملفي' : 'Profile visitors',
  );
  final bullet2 = _p(
    'DAILY_BULLET',
    ar ? 'رسائل عامة مجانية' : 'Free public messages',
    amount: 10,
  );
  final speed = _p(
    'LEVEL_SPEEDUP',
    ar ? 'تسريع المستوى' : 'Level speed-up',
    amount: 2,
  );
  final voice = _p(
    'LONGER_VOICE',
    ar ? 'رسائل صوتية أطول' : 'Longer voice messages',
    built: false,
    value: 180,
  );
  final crown = _p(
    'SEAT_CROWN',
    ar ? 'تاج المقعد' : 'Seat crown',
    built: false,
  );
  VipPerk inherited(VipPerk p) => VipPerk(
    code: p.code,
    title: p.title,
    available: p.available,
    amount: p.amount,
    value: p.value,
    fromTier: 'VIP_1',
  );
  return VipTierList(
    tiers: [
      VipTier(
        id: 't1',
        code: 'VIP_1',
        name: 'VIP 1',
        level: 1,
        color: 0xFF2E8B3D,
        priceCoins: 1000000,
        durationDays: 30,
        perks: [badge, frame, bullet1, visitors],
        effectivePerks: [badge, frame, bullet1, visitors],
      ),
      VipTier(
        id: 't2',
        code: 'VIP_2',
        name: 'VIP 2',
        level: 2,
        color: 0xFF2AA7B8,
        priceCoins: 4000000,
        durationDays: 30,
        perks: [bullet2, speed, voice, crown],
        // In the catalogue's order, as the server sends them.
        effectivePerks: [
          inherited(badge),
          inherited(frame),
          bullet2,
          voice,
          crown,
          inherited(visitors),
          speed,
        ],
      ),
    ],
    maxAheadDays: 400,
  );
}

/// Brings VIP 2's card to the middle: a swipe toward the next page (to the
/// left in LTR, to the right in RTL) until its perks are listed.
Future<void> _openVip2(WidgetTester tester) async {
  final carousel = find.byKey(VipTierCarousel.carouselKey);
  final rtl = Directionality.of(tester.element(carousel)) == TextDirection.rtl;
  for (var i = 0; i < 4; i++) {
    final count = tester.widget<Text>(find.byKey(VipPrivilegesHeader.countKey));
    if (count.data == '(7/7)') return;
    await tester.drag(carousel, Offset(rtl ? 300 : -300, 0));
    await tester.pumpAndSettle();
  }
  fail('VIP 2 was not selected');
}

void main() {
  group('D374 the VIP page lists the effective perks', () {
    testWidgets('VIP 2 shows its own and the inherited perks; «Soon» on the '
        'ones not built; the count follows', (tester) async {
      await withClock(Clock.fixed(_now), () async {
        await pumpPoints(
          tester,
          vip: FakePointsVip(list: _tiers(AppLanguage.en)),
          language: AppLanguage.en,
          brightness: Brightness.light,
        );
        // VIP 1: its four perks, out of the most any tier has (seven).
        expect(
          tester.widget<Text>(find.byKey(VipPrivilegesHeader.countKey)).data,
          '(4/7)',
        );
        await _openVip2(tester);
        expect(
          tester.widget<Text>(find.byKey(VipPrivilegesHeader.countKey)).data,
          '(7/7)',
        );
        for (final code in [
          'BADGE',
          'AVATAR_FRAME',
          'DAILY_BULLET',
          'LONGER_VOICE',
          'SEAT_CROWN',
          'PROFILE_VISITORS',
          'LEVEL_SPEEDUP',
        ]) {
          expect(
            find.byKey(Key('vip.perk.$code')),
            findsOneWidget,
            reason: code,
          );
        }
        final en = l10nFor(AppLanguage.en);
        // VIP 2's own number wins over VIP 1's.
        expect(find.text(en.vipPerkPerDay('10')), findsOneWidget);
        expect(find.text('+2%'), findsWidgets);
        // Two perks not built: «Soon».
        expect(
          find.descendant(
            of: find.byKey(VipHexPerkGrid.gridKey),
            matching: find.text(en.vipPerkSoonTag),
          ),
          findsNWidgets(2),
        );
      });
    });

    test('VipTier.effectivePerks falls back to perks (an older server)', () {
      final t = VipTier.fromJson(const {
        'id': 'x',
        'code': 'VIP_1',
        'name': 'VIP 1',
        'level': 1,
        'color': '#2E8B3D',
        'priceCoins': 1,
        'durationDays': 30,
        'perks': [
          {'code': 'BADGE', 'title': 'Badge', 'available': true},
        ],
      });
      expect(t.effectivePerks.map((p) => p.code), ['BADGE']);
      final withEffective = VipTier.fromJson(const {
        'id': 'x',
        'code': 'VIP_2',
        'name': 'VIP 2',
        'level': 2,
        'color': '#2E8B3D',
        'priceCoins': 1,
        'durationDays': 30,
        'perks': [
          {
            'code': 'PINNED_MESSAGE',
            'title': 'Pin',
            'available': false,
            'value': {'count': 3, 'seconds': 60},
            'category': 'CHAT',
          },
        ],
        'effectivePerks': [
          {
            'code': 'BADGE',
            'title': 'Badge',
            'available': true,
            'fromTier': 'VIP_1',
          },
          {
            'code': 'DAILY_BULLET',
            'title': 'Bullets',
            'available': true,
            'amount': 3,
            'value': 3,
          },
        ],
      });
      expect(withEffective.effectivePerks.map((p) => p.code), [
        'BADGE',
        'DAILY_BULLET',
      ]);
      expect(withEffective.effectivePerks.first.fromTier, 'VIP_1');
      expect(withEffective.effectivePerks.last.number, 3);
      expect(withEffective.perks.single.value, {'count': 3, 'seconds': 60});
      expect(withEffective.perks.single.category, 'CHAT');
    });
  });

  group('D374 goldens', () {
    for (final language in [AppLanguage.ar, AppLanguage.en]) {
      for (final brightness in Brightness.values) {
        testWidgets('VIP 2 effective perks ${language.name} '
            '${brightness.name}', (tester) async {
          await withClock(Clock.fixed(_now), () async {
            await pumpPoints(
              tester,
              vip: FakePointsVip(list: _tiers(language)),
              language: language,
              brightness: brightness,
            );
            await _openVip2(tester);
            await precacheImages(tester);
            await expectLater(
              find.byType(VipScreen),
              matchesGoldenFile(
                'png/vip.d374.effective_perks.${language.name}.'
                '${brightness.name}.phone.png',
              ),
            );
          });
        });
      }
    }
  });
}
