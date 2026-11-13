// D301 follow-up (owner 2026-11-07: «اريد عند حساب الارباح على صفحتي كمؤسس
// ان تزيل نسب الجميع لكون ربح نهائي وضعها قبل وبعد. بالاضافة هناك تكاليف
// ثابتة … هذه التكاليف الشهرية يتم تقسيمها على الشهر»; §10.112.10):
//
// - the card: «ربح اليوم» before → after, blurred with the income until
//   tapped;
// - the details: a day or its month (a past day picked), «الدخل قبل» with its
//   parts, each deduction expandable with its cherries / coins / orders, the
//   fixed costs with each share, «الربح النهائي بعد» (red when negative),
//   other currencies apart, the error with a retry;
// - «تكاليف ثابتة»: the list (an ended one marked), add, edit, delete with a
//   confirmation, an invalid form refused.
//
// With D301_CAPTURE_DIR set, the capture group writes PNGs there (not
// committed).

import 'dart:io';
import 'dart:ui' as ui;

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/owner_profile/domain/owner_models.dart';
import 'package:kabso_live/features/owner_profile/presentation/owner_cover_video.dart';
import 'package:kabso_live/features/owner_profile/presentation/owner_profit.dart';
import 'package:kabso_live/features/owner_profile/presentation/owner_sections.dart';
import 'package:kabso_live/features/profile/profile_cover_header.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/owner/owner_fixtures.dart';
import '../../helpers/fake_owner_profile_repository.dart';
import '../../helpers/golden.dart';
import '../profile/profile_cover_d278_test.dart' show coverBytes;
import 'owner_profile_d301_test.dart'
    show d301Now, d301Poster, d301Repo, pumpOwnerOwn, testD301;

/// The owner's dashboard details, opened (and «قبل» expanded when [expand]).
Future<FakeOwnerProfileRepository> pumpProfitDetails(
  WidgetTester tester, {
  required AppLanguage language,
  Brightness brightness = Brightness.light,
  FakeOwnerProfileRepository? repo,
  bool month = false,
  bool expand = true,
}) async {
  final r = await pumpOwnerOwn(
    tester,
    language: language,
    brightness: brightness,
    repo: repo,
  );
  await withClock(Clock.fixed(d301Now), () async {
    await tester.tap(find.byKey(FounderDashboardCard.onlineKey));
    await tester.pumpAndSettle();
    if (month) {
      await tester.tap(find.byKey(OwnerProfitView.monthTabKey));
      await tester.pumpAndSettle();
    }
    if (expand) {
      await tester.tap(find.byKey(OwnerProfitView.beforeKey));
      await tester.pumpAndSettle();
    }
  });
  return r;
}

/// «تكاليف ثابتة» opened from the details.
Future<FakeOwnerProfileRepository> pumpCostsEditor(
  WidgetTester tester, {
  required AppLanguage language,
  Brightness brightness = Brightness.light,
}) async {
  final r = await pumpProfitDetails(
    tester,
    language: language,
    brightness: brightness,
    expand: false,
  );
  await withClock(Clock.fixed(d301Now), () async {
    await tester.ensureVisible(find.byKey(OwnerProfitView.manageCostsKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(OwnerProfitView.manageCostsKey));
    await tester.pumpAndSettle();
  });
  return r;
}

String usd(int minor) => ownerMoney(minor.abs(), 'USD');

Future<void> _end(WidgetTester tester) => tester.pumpWidget(const SizedBox());

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

  final day = ownerProfit().day;
  final month = ownerProfit().month;

  test('OwnerProfit reads the contract (and skips an unknown line)', () {
    final p = OwnerProfitPeriod.fromJson(const {
      'kind': 'MONTH',
      'key': '2026-06',
      'from': '2026-06-01',
      'to': '2026-06-30',
      'days': 30,
      'daysInMonth': 30,
      'partial': false,
      'before': {
        'amountMinor': 17000,
        'cardChargedMinor': 17000,
        'refundsMinor': 1000,
        'chargebacksMinor': 2000,
        'agentsMinor': 3000,
      },
      'deductions': [
        {
          'key': 'GIFTS',
          'amountMinor': 1100,
          'cherries': 10000000,
          'coins': null,
          'orders': null,
        },
        {
          'key': 'COIN_REWARDS',
          'amountMinor': 300,
          'cherries': null,
          'coins': 250000,
          'orders': null,
        },
        {'key': 'SOMETHING_NEW', 'amountMinor': 1},
      ],
      'fixedCosts': {
        'amountMinor': 33100,
        'items': [
          {
            'id': 'x',
            'name': 'Servers',
            'monthlyMinor': 30000,
            'days': 30,
            'shareMinor': 30000,
          },
        ],
      },
      'after': {'amountMinor': -18168},
      'info': {'agentCoins': 0, 'agentCoinsRetailMinor': 0},
      'otherCurrencies': <Object>[],
    });
    expect(p.month, isTrue);
    expect(p.deductions.map((d) => d.key), [
      ProfitDeductionKey.gifts,
      ProfitDeductionKey.coinRewards,
    ]);
    expect(p.deductions.last.coins, 250000);
    expect(p.deductionsMinor, 1400);
    expect(p.fixedCosts.single.shareMinor, 30000);
    expect(p.afterMinor, -18168);
  });

  test('D387: the compensation coins are their own line (owner: «نعم ينقص '
      'تقرير الربح قيمة هذه العملات»)', () {
    final p = OwnerProfitPeriod.fromJson(const {
      'kind': 'DAY',
      'key': '2026-06-15',
      'from': '2026-06-15',
      'to': '2026-06-15',
      'days': 1,
      'daysInMonth': 30,
      'partial': false,
      'before': {
        'amountMinor': 15000,
        'cardChargedMinor': 15000,
        'refundsMinor': 0,
        'chargebacksMinor': 0,
        'agentsMinor': 0,
      },
      'deductions': [
        {
          'key': 'COIN_REWARDS',
          'amountMinor': 300,
          'cherries': null,
          'coins': 250000,
          'orders': null,
        },
        {
          'key': 'STAFF_COMPENSATIONS',
          'amountMinor': 120,
          'cherries': null,
          'coins': 100000,
          'orders': null,
        },
      ],
      'fixedCosts': {'amountMinor': 0, 'items': <Object>[]},
      'after': {'amountMinor': 14580},
      'info': {'agentCoins': 0, 'agentCoinsRetailMinor': 0},
      'otherCurrencies': <Object>[],
    });
    expect(p.deductions.map((d) => d.key), [
      ProfitDeductionKey.coinRewards,
      ProfitDeductionKey.staffCompensations,
    ]);
    expect(p.deductions.last.coins, 100000);
    expect(p.deductionsMinor, 420);
    expect(p.afterMinor, 14580);
    for (final language in AppLanguage.values) {
      final l10n = lookupAppLocalizations(language.locale);
      expect(
        deductionLabel(l10n, ProfitDeductionKey.staffCompensations),
        l10n.ownerProfitCompensations,
      );
    }
    expect(
      deductionLabel(
        lookupAppLocalizations(AppLanguage.ar.locale),
        ProfitDeductionKey.staffCompensations,
      ),
      'تعويضات دعم كبار الداعمين (عملات)',
    );
  });

  for (final language in AppLanguage.values) {
    final l10n = lookupAppLocalizations(language.locale);
    group('«الربح» (${language.name})', () {
      testD301('the card: before → after, blurred until tapped', (
        tester,
      ) async {
        await pumpOwnerOwn(tester, language: language);
        expect(find.byKey(FounderProfitStrip.stripKey), findsOneWidget);
        expect(find.byKey(FounderProfitStrip.hiddenKey), findsOneWidget);
        await tester.tap(find.byKey(FounderProfitStrip.stripKey));
        await tester.pump();
        expect(find.byKey(FounderProfitStrip.hiddenKey), findsNothing);
        // The income tile shows too (one switch).
        expect(find.byKey(FounderDashboardCard.incomeHiddenKey), findsNothing);
        final strip = find.byKey(FounderProfitStrip.stripKey);
        expect(
          find.descendant(of: strip, matching: find.text(usd(day.beforeMinor))),
          findsOneWidget,
        );
        expect(
          tester.widget<Text>(find.byKey(FounderProfitStrip.afterKey)).data,
          usd(day.afterMinor),
        );
        expect(day.afterMinor, 843125 - 513240 - 5700);
        await _end(tester);
      });

      testD301('the day: before, every deduction, fixed costs, after', (
        tester,
      ) async {
        await pumpProfitDetails(tester, language: language);
        final before = find.byKey(OwnerProfitView.beforeKey);
        for (final part in [650000, 230625]) {
          expect(
            find.descendant(of: before, matching: find.text(usd(part))),
            findsOneWidget,
          );
        }
        expect(
          find.descendant(of: before, matching: find.text('−${usd(25000)}')),
          findsOneWidget,
        );
        for (final d in day.deductions) {
          final row = find.byKey(OwnerProfitView.deductionKey(d.key));
          await tester.ensureVisible(row);
          expect(
            find.descendant(
              of: row,
              matching: find.text(
                d.amountMinor == 0 ? usd(0) : '−${usd(d.amountMinor)}',
              ),
            ),
            findsOneWidget,
            reason: d.key.wire,
          );
        }
        // A cherry line opens to its cherries and the rate.
        final gifts = find.byKey(
          OwnerProfitView.deductionKey(ProfitDeductionKey.gifts),
        );
        await tester.ensureVisible(gifts);
        await tester.tap(gifts);
        await tester.pumpAndSettle();
        expect(
          find.text(l10n.ownerProfitCherries('3,745,454,545', r'$1.10')),
          findsOneWidget,
        );
        // The given-away coins at the owner's $12 a million.
        final coins = find.byKey(
          OwnerProfitView.deductionKey(ProfitDeductionKey.coinRewards),
        );
        await tester.ensureVisible(coins);
        await tester.tap(coins);
        await tester.pumpAndSettle();
        expect(
          find.text(l10n.ownerProfitCoinsDetail('1,200,000', r'$12.00')),
          findsOneWidget,
        );
        // Fixed costs: each share ($60 ÷ 30 = $2).
        final fixed = find.byKey(OwnerProfitView.fixedKey);
        await tester.ensureVisible(fixed);
        await tester.tap(fixed);
        await tester.pumpAndSettle();
        expect(find.text('−${usd(200)}'), findsOneWidget);
        expect(find.text('−${usd(5700)}'), findsOneWidget);
        expect(find.byKey(OwnerProfitView.partialKey), findsNothing);
        final after = find.byKey(OwnerProfitView.afterKey);
        await tester.ensureVisible(after);
        expect(tester.widget<Text>(after).data, usd(day.afterMinor));
        expect(tester.widget<Text>(after).style?.color, isNot(ownerLossRed));
        expect(
          find.text(l10n.ownerProfitOther('EUR', 'EUR 50.00', 'EUR 50.00')),
          findsOneWidget,
        );
        await _end(tester);
      });

      testD301('the month to date, and a loss in red', (tester) async {
        final repo = d301Repo(ar: language == AppLanguage.ar)
          ..profitData = ownerProfit(loss: true);
        await pumpProfitDetails(
          tester,
          language: language,
          repo: repo,
          month: true,
        );
        expect(find.byKey(OwnerProfitView.partialKey), findsOneWidget);
        final after = find.byKey(OwnerProfitView.afterKey);
        await tester.ensureVisible(after);
        final text = tester.widget<Text>(after);
        final loss = ownerProfit(loss: true).month.afterMinor;
        expect(loss, lessThan(0));
        expect(text.data, '−${usd(loss)}');
        expect(text.style?.color, ownerLossRed);
        expect(
          month.afterMinor,
          5120000 - 3180000 - (6000 + 45000 + 120000) * 7 ~/ 30,
        );
        await _end(tester);
      });

      testD301('a past day can be picked', (tester) async {
        final repo = await pumpProfitDetails(
          tester,
          language: language,
          expand: false,
        );
        expect(repo.profitDays, [null]);
        await tester.tap(find.byKey(OwnerProfitView.pickDayKey));
        await tester.pumpAndSettle();
        await tester.tap(find.text('3'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(
            MaterialLocalizations.of(
              tester.element(find.byType(DatePickerDialog)),
            ).okButtonLabel,
          ),
        );
        await tester.pumpAndSettle();
        expect(repo.profitDays.last, '2026-11-03');
        await _end(tester);
      });

      testD301('a failure says so, with a retry (no made-up numbers)', (
        tester,
      ) async {
        final repo = d301Repo(ar: language == AppLanguage.ar)
          ..profitData = null;
        await pumpProfitDetails(
          tester,
          language: language,
          repo: repo,
          expand: false,
        );
        expect(find.text(l10n.ownerProfitFailed), findsOneWidget);
        expect(find.byKey(OwnerProfitView.afterKey), findsNothing);
        repo.profitData = ownerProfit();
        await tester.tap(find.byKey(OwnerProfitView.retryKey));
        await tester.pumpAndSettle();
        expect(find.byKey(OwnerProfitView.afterKey), findsOneWidget);
        await _end(tester);
      });

      testD301('«تكاليف ثابتة»: list, add, edit, delete', (tester) async {
        final repo = await pumpCostsEditor(tester, language: language);
        expect(find.byKey(FixedCostsSheet.sheetKey), findsOneWidget);
        for (final c in ownerFixedCosts) {
          expect(find.byKey(FixedCostsSheet.rowKey(c.id)), findsOneWidget);
        }
        // DeepAR filters ended on 31 October.
        expect(
          find.descendant(
            of: find.byKey(FixedCostsSheet.rowKey('c4')),
            matching: find.textContaining(l10n.ownerCostsEnded),
          ),
          findsOneWidget,
        );
        // Add: the name and $25 a month, from today.
        await withClock(Clock.fixed(d301Now), () async {
          await tester.tap(find.byKey(FixedCostsSheet.addKey));
          await tester.pumpAndSettle();
          // An empty form is refused.
          await tester.tap(find.byKey(FixedCostForm.saveKey));
          await tester.pump();
          expect(find.text(l10n.ownerCostsInvalid), findsOneWidget);
          expect(repo.calls.where((c) => c.startsWith('cost:')), isEmpty);
          await tester.enterText(
            find.byKey(FixedCostForm.nameKey),
            'Cloudflare',
          );
          await tester.enterText(find.byKey(FixedCostForm.amountKey), '25');
          await tester.tap(find.byKey(FixedCostForm.saveKey));
          await tester.pumpAndSettle();
        });
        expect(repo.calls, contains('cost:create:Cloudflare:2500:2026-11-07:'));
        expect(find.text('Cloudflare'), findsOneWidget);
        // Edit Claude: $90 a month.
        await tester.tap(find.byKey(FixedCostsSheet.editKey('c1')));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TextField>(find.byKey(FixedCostForm.amountKey))
              .controller
              ?.text,
          '60.00',
        );
        await tester.enterText(find.byKey(FixedCostForm.amountKey), '90');
        await tester.tap(find.byKey(FixedCostForm.saveKey));
        await tester.pumpAndSettle();
        expect(repo.calls, contains('cost:update:c1:Claude:9000'));
        // Delete LiveKit, after the confirmation (a cancel keeps it).
        await tester.tap(find.byKey(FixedCostsSheet.deleteKey('c2')));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.ownerCostsCancel));
        await tester.pumpAndSettle();
        expect(repo.calls, isNot(contains('cost:delete:c2')));
        await tester.tap(find.byKey(FixedCostsSheet.deleteKey('c2')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('owner.costs.deleteConfirm')));
        await tester.pumpAndSettle();
        expect(repo.calls, contains('cost:delete:c2'));
        expect(find.byKey(FixedCostsSheet.rowKey('c2')), findsNothing);
        await _end(tester);
      });
    });
  }

  final captureDir = Platform.environment['D301_CAPTURE_DIR'];
  group('D301 profit captures', skip: captureDir == null, () {
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
      final lang = language.name;
      testD301('card $lang', (tester) async {
        await pumpOwnerOwn(tester, language: language);
        await tester.tap(find.byKey(FounderProfitStrip.stripKey));
        await tester.pump();
        await capture(tester, 'profit.card.$lang.light');
        await _end(tester);
      });
      for (final brightness in Brightness.values) {
        testD301('day $lang ${brightness.name}', (tester) async {
          await pumpProfitDetails(
            tester,
            language: language,
            brightness: brightness,
          );
          await capture(tester, 'profit.day.$lang.${brightness.name}');
          await _end(tester);
        });
      }
      testD301('month loss $lang', (tester) async {
        final repo = d301Repo(ar: language == AppLanguage.ar)
          ..profitData = ownerProfit(loss: true);
        await pumpProfitDetails(
          tester,
          language: language,
          repo: repo,
          month: true,
          expand: false,
        );
        final gifts = find.byKey(
          OwnerProfitView.deductionKey(ProfitDeductionKey.gifts),
        );
        await tester.ensureVisible(gifts);
        await tester.tap(gifts);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(OwnerProfitView.afterKey));
        await tester.pumpAndSettle();
        await capture(tester, 'profit.month.loss.$lang.light');
        await _end(tester);
      });
      testD301('costs $lang', (tester) async {
        await pumpCostsEditor(tester, language: language);
        await capture(tester, 'profit.costs.$lang.light');
        await withClock(Clock.fixed(d301Now), () async {
          await tester.tap(find.byKey(FixedCostsSheet.addKey));
          await tester.pumpAndSettle();
          await tester.enterText(find.byKey(FixedCostForm.nameKey), 'LiveKit');
          await tester.enterText(find.byKey(FixedCostForm.amountKey), '450');
          await tester.pumpAndSettle();
        });
        await capture(tester, 'profit.costform.$lang.light');
        await _end(tester);
      });
    }
  });
}
