// D381 (owner 2026-11-11; contract v1.134-social, CONVENTIONS §10.171): the
// app's side of the gift, CP, support, rocket and voice perks — reading
// `MyVip.perksNow`, «الخاص بي VIP»'s rows, the gift sheet's «VIP» tab and
// larger quantities (never for a lucky gift), the LONGER_VOICE limit the
// recorders read, «هدية مؤجلة» (list, cancel, the form), the free CP
// request's confirmation and the two ledger reasons. Arabic RTL and English.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/cp/domain/cp_models.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_gift_models.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_gift_sheet.dart';
import 'package:kabso_live/features/vip/application/vip_gift_perks_providers.dart';
import 'package:kabso_live/features/vip/application/vip_providers.dart';
import 'package:kabso_live/features/vip/data/vip_gift_perks_repository.dart';
import 'package:kabso_live/features/vip/data/vip_repository.dart';
import 'package:kabso_live/features/vip/presentation/vip_gift_perks.dart';
import 'package:kabso_live/features/wallet/data/wallet_repository.dart';
import 'package:kabso_live/l10n/gen/app_localizations_ar.dart';
import 'package:kabso_live/l10n/gen/app_localizations_en.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_gift_fixtures.dart';
import '../../helpers/fake_live_gift_repository.dart';
import '../../helpers/fake_live_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

final _ar = AppLocalizationsAr();
final _en = AppLocalizationsEn();

/// Every D381 part, as `GET /me/vip` sends it.
const Map<String, Object?> fullPerksNowJson = {
  'monthlyRockets': {
    'month': '2026-11-01',
    'stage': 2,
    'minutes': 20,
    'count': 2,
    'grantedAt': '2026-11-01T08:00:00.000Z',
    'nextAt': '2026-11-30T21:00:00.000Z',
  },
  'freeCpRequests': {
    'perMonth': 3,
    'used': 1,
    'left': 2,
    'resetsAt': '2026-11-30T21:00:00.000Z',
  },
  'maxGiftQuantity': 9999,
  'voiceSeconds': 180,
  'exclusiveGifts': 4,
  'scheduledGifts': {'pending': 1, 'maxPending': 10},
  'prioritySupport': true,
};

/// `VipScheduledGift` JSON for the fakes and goldens.
Map<String, Object?> scheduledGiftJson(
  String id,
  String status, {
  required DateTime at,
  String name = 'سارة',
  String gift = 'crown',
  bool ar = true,
}) => {
  'id': id,
  'to': {
    'id': 'u-$id',
    'username': 'sara_$id',
    'displayName': name,
    'avatarUrl': null,
  },
  'giftCode': gift,
  'gift': giftJson(gift, ar: ar),
  'quantity': 10,
  'coins': 2990,
  'deliverAt': at.toUtc().toIso8601String(),
  'status': status,
  'failure': status == 'FAILED' ? 'DM_NOT_ALLOWED' : null,
  'createdAt': at.subtract(const Duration(days: 1)).toUtc().toIso8601String(),
  'handledAt': status == 'PENDING' ? null : at.toUtc().toIso8601String(),
};

/// The scheduled gifts API: [items] listed; a cancel recorded.
class FakeVipGiftPerks implements VipGiftPerksRepository {
  new({List<VipScheduledGift>? items}) : items = items ?? [];

  final List<VipScheduledGift> items;
  final List<String> cancels = [];

  @override
  Future<VipPerksNow> perksNow() async =>
      VipPerksNow.fromJson(fullPerksNowJson);

  @override
  Future<VipScheduledGiftList> scheduled() async => (
    data: items,
    pending: items
        .where((g) => g.status == VipScheduledGiftStatus.pending)
        .length,
    maxPending: 10,
  );

  @override
  Future<({VipScheduledGift gift, int coins})> schedule({
    required String to,
    required String giftCode,
    required int quantity,
    required DateTime deliverAt,
    required String clientId,
  }) => throw UnimplementedError();

  @override
  Future<({VipScheduledGift gift, int coins})> cancel(String id) async {
    cancels.add(id);
    final i = items.indexWhere((g) => g.id == id);
    final g = items[i];
    final done = VipScheduledGift(
      id: g.id,
      to: g.to,
      giftCode: g.giftCode,
      gift: g.gift,
      quantity: g.quantity,
      coins: g.coins,
      deliverAt: g.deliverAt,
      status: VipScheduledGiftStatus.cancelled,
    );
    items[i] = done;
    return (gift: done, coins: 5000);
  }
}

/// `GET /me/vip` with [membership].
class _MineVip implements VipRepository {
  new(this.membership);

  final VipMembership? membership;

  @override
  Future<VipMembership?> mine() async => membership;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The catalogue with the caller's VIP gifts and quantities.
class _VipGiftsRepo extends FakeLiveGiftRepository {
  new({required super.ar}) : super(coins: 100000);

  @override
  Future<GiftCatalogue> catalogue() async {
    final c = await super.catalogue();
    return c.copyWith(
      vipGiftCodes: const ['crown'],
      vipQuantities: const [3344, 5200, 9999],
    );
  }
}

class _Opener extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        key: const Key('test.open'),
        onPressed: () => unawaited(
          KLiveGiftSheet.show(
            context,
            room: LiveGiftRoom(
              roomId: 'room-0',
              host: const UserSummary(
                id: 'user-sara',
                username: 'sara',
                displayName: 'Sara',
                avatarUrl: null,
              ),
              seated: (_) => const [],
              onSeatsStale: () {},
            ),
          ),
        ),
        child: const SizedBox.square(dimension: 40),
      ),
    ),
  );
}

VipMembership membershipWith(Map<String, Object?>? now) => VipMembership(
  tierId: 't1',
  tierCode: 'VIP_1',
  tierName: 'VIP 1',
  tierColor: 0xFF2E8B3D,
  onSale: true,
  startedAt: DateTime.utc(2026, 11),
  expiresAt: DateTime.utc(2026, 12),
  daysLeft: 19,
  perksNow: now == null ? null : VipPerksNow.fromJson(now),
);

void main() {
  group('the model', () {
    test('reads perksNow; an absent part is not held', () {
      final now = VipPerksNow.fromJson(fullPerksNowJson);
      expect(now.monthlyRockets, (
        stage: 2,
        minutes: 20,
        count: 2,
        nextAt: DateTime.utc(2026, 11, 30, 21),
      ));
      expect(now.freeCpRequests, (perMonth: 3, used: 1, left: 2));
      expect(now.maxGiftQuantity, 9999);
      expect(now.voiceLimit, const Duration(seconds: 180));
      expect(now.scheduledGifts, isTrue);
      expect(now.prioritySupport, isTrue);
      expect(now.isEmpty, isFalse);
      final none = VipPerksNow.fromJson(const {});
      expect(none.isEmpty, isTrue);
      expect(none.voiceLimit, defaultVoiceLimit);
      expect(none.scheduledGifts, isFalse);
    });

    test('the voice size grows with the seconds: 1 MiB per 30 s', () {
      expect(voiceBytesFor(defaultVoiceLimit), 1024 * 1024);
      expect(voiceBytesFor(const Duration(seconds: 180)), 6 * 1024 * 1024);
      expect(voiceBytesFor(const Duration(seconds: 10)), 1024 * 1024);
    });

    test('a scheduled gift and its statuses (an unknown one reads FAILED)', () {
      final g = VipScheduledGift.fromJson(
        scheduledGiftJson('g1', 'PENDING', at: DateTime.utc(2026, 11, 20, 18)),
      );
      expect(g.status, VipScheduledGiftStatus.pending);
      expect(g.gift?.code, 'crown');
      expect(g.to?.displayName, 'سارة');
      expect(
        VipScheduledGiftStatus.fromWire('X'),
        VipScheduledGiftStatus.failed,
      );
    });

    test('CpConfig carries the free requests; older servers none', () {
      final c = CpConfig.fromJson(const {
        'requestCost': 99,
        'requestTtlDays': 7,
        'giftAmounts': [520],
        'tiers': <Object>[],
        'vipFreeRequests': {
          'perMonth': 3,
          'used': 1,
          'left': 2,
          'resetsAt': '2026-11-30T21:00:00.000Z',
        },
      });
      expect(c.vipFreeRequests?.left, 2);
      expect(
        CpConfig.fromJson(const {
          'requestCost': 99,
          'requestTtlDays': 7,
          'giftAmounts': [520],
          'tiers': <Object>[],
        }).vipFreeRequests,
        isNull,
      );
    });

    test('the ledger reasons of a scheduled gift', () {
      expect(
        WalletLedgerReason.fromWire('VIP_SCHEDULED_GIFT'),
        WalletLedgerReason.vipScheduledGift,
      );
      expect(
        WalletLedgerReason.fromWire('VIP_SCHEDULED_GIFT_RELEASE'),
        WalletLedgerReason.vipScheduledGiftRelease,
      );
    });

    test(
      'the catalogue reads the VIP gifts and quantities; none by default',
      () {
        final base = giftCatalogueJson(codes: const ['rose', 'crown']);
        expect(GiftCatalogue.fromJson(base).vipGiftCodes, isEmpty);
        final c = GiftCatalogue.fromJson({
          ...base,
          'vipGiftCodes': ['crown'],
          'vipQuantities': [3344, 9999],
        });
        expect(c.vipGiftCodes, ['crown']);
        expect(c.vipQuantities, [3344, 9999]);
      },
    );
  });

  group('LONGER_VOICE', () {
    test(
      "`GET /me/vip` sets the recorders' limit; without the perk 30 s",
      () async {
        final prefs = await testPrefs();
        final holder = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            currentUserProvider.overrideWithValue(testUser()),
            vipRepositoryProvider.overrideWithValue(
              _MineVip(membershipWith(fullPerksNowJson)),
            ),
          ],
        );
        addTearDown(holder.dispose);
        expect(holder.read(vipVoiceLimitProvider), defaultVoiceLimit);
        final sub = holder.listen(myVipProvider, (_, _) {});
        addTearDown(sub.close);
        await holder.read(myVipProvider.future);
        expect(
          holder.read(vipVoiceLimitProvider),
          const Duration(seconds: 180),
        );

        final plain = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            currentUserProvider.overrideWithValue(testUser()),
            vipRepositoryProvider.overrideWithValue(_MineVip(null)),
          ],
        );
        addTearDown(plain.dispose);
        final sub2 = plain.listen(myVipProvider, (_, _) {});
        addTearDown(sub2.close);
        await plain.read(myVipProvider.future);
        expect(plain.read(vipVoiceLimitProvider), defaultVoiceLimit);
      },
    );
  });

  group('«الخاص بي VIP» rows', () {
    Future<void> pumpSection(
      WidgetTester tester,
      VipPerksNow? now, {
      AppLanguage language = AppLanguage.ar,
      VoidCallback? onOpen,
    }) => pumpScreen(
      tester,
      Scaffold(
        body: SingleChildScrollView(
          child: VipPerksNowSection(now: now, onOpenScheduled: onOpen),
        ),
      ),
      language: language,
    );

    testWidgets('one row per held perk, with its numbers (ar)', (tester) async {
      var opened = 0;
      await pumpSection(
        tester,
        VipPerksNow.fromJson(fullPerksNowJson),
        onOpen: () => opened++,
      );
      expect(find.text(_ar.vipNowTitle), findsOneWidget);
      expect(find.text(_ar.vipNowRockets('2', '20')), findsOneWidget);
      expect(find.text(_ar.vipNowFreeCp('2', '3')), findsOneWidget);
      expect(find.text(_ar.vipNowExclusive('4')), findsOneWidget);
      expect(find.text(_ar.vipNowMaxQuantity('9,999')), findsOneWidget);
      expect(find.text(_ar.vipNowVoice('180')), findsOneWidget);
      expect(find.text(_ar.vipNowPriority), findsOneWidget);
      expect(find.text(_ar.vipScheduledEntrySub('1', '10')), findsOneWidget);
      await tester.tap(find.byKey(VipPerksNowSection.scheduledKey));
      expect(opened, 1);
    });

    testWidgets('only what is held (en); nothing without perks or from an '
        'older API', (tester) async {
      await pumpSection(
        tester,
        VipPerksNow.fromJson(const {'voiceSeconds': 120}),
        language: AppLanguage.en,
      );
      expect(find.text(_en.vipNowVoice('120')), findsOneWidget);
      expect(
        find.byKey(VipPerksNowSection.rowKey('MONTHLY_ROCKETS')),
        findsNothing,
      );
      expect(find.byKey(VipPerksNowSection.scheduledKey), findsNothing);
      await pumpSection(tester, VipPerksNow.none);
      expect(find.byKey(VipPerksNowSection.sectionKey), findsNothing);
      await pumpSection(tester, null);
      expect(find.byKey(VipPerksNowSection.sectionKey), findsNothing);
    });
  });

  group('the gift sheet', () {
    Future<void> pumpSheet(WidgetTester tester) async {
      setViewport(tester, GoldenViewport.phone);
      await pumpScreen(
        tester,
        const _Opener(),
        language: AppLanguage.ar,
        liveGiftRepository: _VipGiftsRepo(ar: true)
          ..codes = const ['rose', 'crown', 'sports_car'],
        disableAnimations: true,
        overrides: [
          liveRepositoryProvider.overrideWithValue(FakeLiveRepository()),
          currentUserProvider.overrideWithValue(testUser()),
        ],
      );
      await tester.tap(find.byKey(const Key('test.open')));
      await tester.pumpAndSettle();
    }

    testWidgets('a «VIP» tab first with the exclusive gifts; the larger '
        'quantities beside the configured ones', (tester) async {
      await pumpSheet(tester);
      final vip = find.byKey(KLiveGiftSheet.tabKey(KLiveGiftSheet.vipTab));
      expect(vip, findsOneWidget);
      expect(
        find.descendant(of: vip, matching: find.text('VIP')),
        findsOneWidget,
      );
      await tester.tap(vip);
      await tester.pumpAndSettle();
      expect(find.byKey(KLiveGiftSheet.cellKey('crown')), findsOneWidget);
      expect(find.byKey(KLiveGiftSheet.cellKey('rose')), findsNothing);
      await tester.tap(find.byKey(KLiveGiftSheet.cellKey('crown')));
      await tester.pumpAndSettle();
      for (final q in const [1314, 3344, 5200, 9999]) {
        expect(find.byKey(KLiveGiftSheet.quantityOptionKey(q)), findsOneWidget);
      }
    });
  });

  group('«هدية مؤجلة»', () {
    final at = DateTime.utc(2026, 11, 20, 18);

    Future<FakeVipGiftPerks> pumpList(
      WidgetTester tester, {
      List<VipScheduledGift>? items,
      AppLanguage language = AppLanguage.ar,
    }) async {
      final repo = FakeVipGiftPerks(
        items:
            items ??
            [
              VipScheduledGift.fromJson(
                scheduledGiftJson('g1', 'PENDING', at: at),
              ),
              VipScheduledGift.fromJson(
                scheduledGiftJson('g2', 'DELIVERED', at: at, name: 'ليلى'),
              ),
              VipScheduledGift.fromJson(
                scheduledGiftJson('g3', 'FAILED', at: at, name: 'منى'),
              ),
            ],
      );
      setViewport(tester, GoldenViewport.phone);
      await pumpScreen(
        tester,
        const VipScheduledGiftsScreen(),
        language: language,
        liveGiftRepository: FakeLiveGiftRepository(
          ar: language == AppLanguage.ar,
          codes: const ['rose', 'crown', 'sports_car'],
        )..categories = const ['POPULAR', 'LUCKY'],
        overrides: [
          currentUserProvider.overrideWithValue(testUser()),
          vipGiftPerksRepositoryProvider.overrideWithValue(repo),
        ],
      );
      await tester.pumpAndSettle();
      return repo;
    }

    testWidgets('lists them with their outcome; a waiting one is cancelled '
        '(coins back)', (tester) async {
      final repo = await pumpList(tester);
      expect(find.byKey(VipScheduledGiftsScreen.listKey), findsOneWidget);
      expect(find.text(_ar.vipScheduledStatusDelivered), findsNothing);
      expect(
        find.textContaining(_ar.vipScheduledStatusDelivered),
        findsOneWidget,
      );
      expect(find.textContaining(_ar.vipScheduledStatusFailed), findsOneWidget);
      expect(find.byKey(VipScheduledGiftsScreen.cancelKey('g2')), findsNothing);
      await tester.tap(find.byKey(VipScheduledGiftsScreen.cancelKey('g1')));
      await tester.pumpAndSettle();
      expect(repo.cancels, ['g1']);
      expect(find.text(_ar.vipScheduledCancelled), findsOneWidget);
      expect(find.byKey(VipScheduledGiftsScreen.cancelKey('g1')), findsNothing);
    });

    testWidgets('empty: says so (en)', (tester) async {
      await pumpList(tester, items: [], language: AppLanguage.en);
      expect(find.byKey(VipScheduledGiftsScreen.emptyKey), findsOneWidget);
      expect(find.text(_en.vipScheduledEmptyTitle), findsOneWidget);
    });

    testWidgets('the form offers schedulable gifts only (no lucky gift) and '
        'waits for a person, a gift and a time', (tester) async {
      await pumpList(tester);
      await tester.tap(find.byKey(VipScheduledGiftsScreen.newKey));
      await tester.pumpAndSettle();
      expect(find.byKey(VipScheduleForm.toKey), findsOneWidget);
      final submit = tester.widget<FilledButton>(
        find.byKey(VipScheduleForm.submitKey),
      );
      expect(submit.onPressed, isNull);
      expect(vipSchedulable(Gift.fromJson(giftJson('rose'))), isTrue);
      expect(
        vipSchedulable(
          Gift.fromJson({...giftJson('rose'), 'category': 'LUCKY'}),
        ),
        isFalse,
      );
      expect(
        vipSchedulable(
          Gift.fromJson({...giftJson('rose'), 'category': 'QUIPS'}),
        ),
        isFalse,
      );
    });
  });
}
