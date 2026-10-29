// D164: the Me hub's Wallet, Earn money and Creator Center pages — real
// data from the API only (fakes here), honest empty and failure states,
// recharge and withdraw honestly disabled with "Soon", Arabic RTL and
// English LTR, 360×800 and large text sizes.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/creator/data/creator_repository.dart';
import 'package:kabso_live/features/creator/presentation/creator_center_screen.dart';
import 'package:kabso_live/features/live/application/live_wallet_controller.dart';
import 'package:kabso_live/features/profile/me_hub_screen.dart';
import 'package:kabso_live/features/programs/data/programs_repository.dart';
import 'package:kabso_live/features/wallet/data/wallet_repository.dart';
import 'package:kabso_live/features/wallet/presentation/earnings_screen.dart';
import 'package:kabso_live/features/wallet/presentation/wallet_screen.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

final AppLocalizations _en = l10nFor(AppLanguage.en);
final AppLocalizations _ar = l10nFor(AppLanguage.ar);

class _Coins extends LiveCoinsController {
  @override
  Future<int> build() async => 1250;
}

final DateTime _at = DateTime.utc(2026, 10, 29, 9, 30);

WalletLedgerEntry _entry(
  String id,
  WalletLedgerReason reason,
  int delta,
  int after,
) => WalletLedgerEntry(
  id: id,
  reason: reason,
  delta: delta,
  balanceAfter: after,
  createdAt: _at,
);

const UserSummary _fan = UserSummary(
  id: 'u-fan',
  username: 'sara.m',
  displayName: 'Sara',
  avatarUrl: null,
);

Earning _earning(String id, {UserSummary? sender, bool dm = false}) => Earning(
  id: id,
  createdAt: _at,
  context: dm ? EarningContext.dm : EarningContext.live,
  giftCode: 'rose',
  giftName: 'Rose',
  quantity: 10,
  giftCoins: 100,
  shareBps: 6500,
  coins: 65,
  sender: sender,
);

class _FakeWallet implements WalletRepository {
  new({
    this.pages = const {},
    this.earningPages = const {},
    this.totals = const MyEarnings(
      totalCoins: 1200,
      last7DaysCoins: 114,
      last30DaysCoins: 900,
      sendCount: 3,
    ),
    this.fail = false,
  });

  /// Pages by cursor (null = the first).
  final Map<String?, WalletPage<WalletLedgerEntry>> pages;
  final Map<String?, WalletPage<Earning>> earningPages;
  final MyEarnings totals;
  final bool fail;
  final List<String?> ledgerCalls = [];

  @override
  Future<WalletPage<WalletLedgerEntry>> ledger({String? cursor}) async {
    ledgerCalls.add(cursor);
    if (fail) throw const NetworkFailure.offline();
    return pages[cursor] ?? (items: const <WalletLedgerEntry>[], next: null);
  }

  @override
  Future<MyEarnings> earnings() async {
    if (fail) throw const NetworkFailure.offline();
    return totals;
  }

  @override
  Future<WalletPage<Earning>> earningHistory({String? cursor}) async {
    if (fail) throw const NetworkFailure.offline();
    return earningPages[cursor] ?? (items: const <Earning>[], next: null);
  }
}

/// D166: the wallet's recharge packages (the rest of the programs are
/// tested in programs_d166_test).
class _FakePrograms implements ProgramsRepository {
  @override
  Future<RechargeOffer> rechargePackages() async => const RechargeOffer(
    currency: 'USD',
    purchasesEnabled: false,
    packages: [
      RechargePackage(id: 'p1', coins: 10, bonusCoins: 20, priceMinor: 29),
    ],
  );

  @override
  Future<MyTasks> tasks() => throw UnimplementedError();

  @override
  Future<ProgramPayout> checkIn() => throw UnimplementedError();

  @override
  Future<ProgramPayout> claim(String code) => throw UnimplementedError();

  @override
  Future<SvipStatus> svip() => throw UnimplementedError();

  @override
  Future<EventList> events(EventTab tab, {String? month}) =>
      throw UnimplementedError();

  @override
  Future<EventDetail> event(String eventId) => throw UnimplementedError();

  @override
  Future<EventLeaderboard> leaderboard(String eventId) =>
      throw UnimplementedError();
}

/// D166: the coin history moved to the wallet's second tab.
Future<void> _openHistory(WidgetTester tester) async {
  await tester.tap(find.byKey(WalletScreen.historyButtonKey));
  await tester.pumpAndSettle();
}

CreatorStats _stats(CreatorStatsPeriod period, {bool empty = false}) =>
    CreatorStats(
      period: period,
      followersTotal: 1234,
      followersNew: period == CreatorStatsPeriod.allTime ? null : 12,
      posts: CreatorContentStats(
        published: empty ? 0 : 3,
        views: empty ? 0 : 4500,
        likes: empty ? 0 : 210,
        comments: empty ? 0 : 33,
        shares: empty ? 0 : 7,
      ),
      reels: const CreatorContentStats(
        published: 0,
        views: 0,
        likes: 0,
        comments: 0,
        shares: 0,
      ),
      live: CreatorLiveStats(
        lives: empty ? 0 : 2,
        liveSeconds: empty ? 0 : 5400,
        giftCount: empty ? 0 : 9,
        giftCoins: empty ? 0 : 990,
        earningsCoins: empty ? 0 : 600,
        newFollowers: empty ? 0 : 4,
        peakViewers: empty ? 0 : 57,
      ),
    );

class _FakeCreator implements CreatorRepository {
  new({this.empty = false, this.fail = false});

  final bool empty;
  final bool fail;
  final List<CreatorStatsPeriod> calls = [];

  @override
  Future<CreatorStats> mine(CreatorStatsPeriod period) async {
    calls.add(period);
    if (fail) throw const NetworkFailure.offline();
    return _stats(period, empty: empty);
  }
}

Future<void> _pump(
  WidgetTester tester,
  String location, {
  _FakeWallet? wallet,
  _FakeCreator? creator,
  AppLanguage language = AppLanguage.en,
  GoldenViewport viewport = GoldenViewport.phone,
  double textScale = 1,
}) async {
  final router = GoRouter(
    initialLocation: location,
    routes: [
      GoRoute(path: AppRoutes.wallet, builder: (_, _) => const WalletScreen()),
      GoRoute(
        path: AppRoutes.earnings,
        builder: (_, _) => const EarningsScreen(),
      ),
      GoRoute(
        path: AppRoutes.creatorCenter,
        builder: (_, _) => const CreatorCenterScreen(),
      ),
      GoRoute(
        path: AppRoutes.myProfile,
        builder: (_, _) => const Text('page profile'),
      ),
    ],
  );
  await loadAppFonts();
  setViewport(tester, viewport);
  final prefs = await testPrefs(language: language.name);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
        currentUserProvider.overrideWithValue(testUser()),
        liveCoinsProvider.overrideWith(_Coins.new),
        walletRepositoryProvider.overrideWithValue(wallet ?? _FakeWallet()),
        creatorRepositoryProvider.overrideWithValue(creator ?? _FakeCreator()),
        programsRepositoryProvider.overrideWithValue(_FakePrograms()),
      ],
      child: MaterialApp.router(
        routerConfig: router,
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
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

_FakeWallet _walletWithHistory() => _FakeWallet(
  pages: {
    null: (
      items: [
        _entry('l3', WalletLedgerReason.adminGrant, 100, 1250),
        _entry('l2', WalletLedgerReason.bulletMessage, -15, 1150),
      ],
      next: 'c1',
    ),
    'c1': (
      items: [_entry('l1', WalletLedgerReason.other, 1165, 1165)],
      next: null,
    ),
  },
  earningPages: {
    null: (
      items: [
        _earning('e2', sender: _fan),
        _earning('e1', dm: true),
      ],
      next: null,
    ),
  },
);

/// The "Soon" button: disabled, labelled "…, coming soon", with the tag.
void _expectSoon(WidgetTester tester, Key key, String label) {
  final node = tester.getSemantics(find.byKey(key));
  expect(node.label, _en.meHubSoonItem(label));
  expect(node.flagsCollection.isEnabled.toBoolOrNull(), isFalse);
  expect(
    find.descendant(
      of: find.byKey(key),
      matching: find.byKey(MeHubScreen.soonKey),
    ),
    findsOneWidget,
  );
}

void main() {
  test('share percentages read like the stored basis points', () {
    expect(sharePercent(6500), '65');
    expect(sharePercent(5000), '50');
    expect(sharePercent(1250), '12.5');
    expect(sharePercent(3333), '33.33');
    expect(signedCoins(100), '+100');
    expect(signedCoins(-1500), '-1,500');
  });

  group('wallet', () {
    testWidgets('the real balance, the history newest first with reasons, '
        'signed amounts and the balance after; the next page loads', (
      tester,
    ) async {
      final wallet = _walletWithHistory();
      final semantics = tester.ensureSemantics();
      await _pump(tester, AppRoutes.wallet, wallet: wallet);
      expect(
        find.descendant(
          of: find.byKey(WalletScreen.balanceKey),
          matching: find.text('1,250'),
        ),
        findsOneWidget,
      );
      await _openHistory(tester);
      expect(find.text(_en.walletReasonAdminGrant), findsOneWidget);
      expect(find.text('+100'), findsOneWidget);
      expect(find.text('-15'), findsOneWidget);
      expect(find.text(_en.walletBalanceAfter('1,150')), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(WalletScreen.entryKey('l1')),
        100,
        // D166: the wallet's tabs scroll too; the list is the last one.
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      // An unknown reason from a newer server reads as a plain change.
      expect(find.text(_en.walletReasonOther), findsOneWidget);
      expect(wallet.ledgerCalls, [null, 'c1']);
      final top = tester.getTopLeft(find.byKey(WalletScreen.entryKey('l3')));
      final next = tester.getTopLeft(find.byKey(WalletScreen.entryKey('l2')));
      expect(top.dy, lessThan(next.dy));
      semantics.dispose();
    });

    testWidgets('recharge is honestly "Soon" and does nothing', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester, AppRoutes.wallet, wallet: _walletWithHistory());
      // D166: the packages' button, disabled until payments exist (B5).
      _expectSoon(
        tester,
        WalletScreen.rechargeKey,
        _en.walletGetCoins('30', r'$0.29'),
      );
      expect(find.text(_en.walletRechargeSoon), findsOneWidget);
      await tester.tap(find.byKey(WalletScreen.rechargeKey));
      await tester.pumpAndSettle();
      expect(find.byType(WalletScreen), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('no history: the empty state, never sample rows', (
      tester,
    ) async {
      await _pump(tester, AppRoutes.wallet);
      await _openHistory(tester);
      expect(find.byKey(WalletScreen.emptyKey), findsOneWidget);
      expect(find.text(_en.walletHistoryEmpty), findsOneWidget);
    });

    testWidgets('a failure shows the error with a retry', (tester) async {
      await _pump(tester, AppRoutes.wallet, wallet: _FakeWallet(fail: true));
      await _openHistory(tester);
      expect(find.text(_en.walletLoadError), findsOneWidget);
      expect(find.text(_en.actionRetry), findsOneWidget);
    });
  });

  group('earnings', () {
    testWidgets('totals, the display-only note, and each send with its '
        'sender, place and share', (tester) async {
      await _pump(tester, AppRoutes.earnings, wallet: _walletWithHistory());
      expect(
        find.descendant(
          of: find.byKey(EarningsScreen.totalKey),
          matching: find.text('1,200'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(EarningsScreen.last7Key),
          matching: find.text('114'),
        ),
        findsOneWidget,
      );
      expect(find.text(_en.earnDisplayOnly), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(EarningsScreen.entryKey('e1')),
        100,
      );
      expect(find.text('+65'), findsNWidgets(2));
      expect(find.text(_en.earnShare('65', '100')), findsNWidgets(2));
      expect(
        find.text(
          '${_en.earnFrom('\u2068Sara\u2069')} · ${_en.earnContextLive}',
        ),
        findsOneWidget,
      );
      // A hidden sender (inactive or blocked) is never named.
      expect(
        find.text('${_en.earnFromHidden} · ${_en.earnContextDm}'),
        findsOneWidget,
      );
    });

    testWidgets('withdraw is honestly "Soon" (D149)', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester, AppRoutes.earnings);
      _expectSoon(tester, EarningsScreen.withdrawKey, _en.earnWithdraw);
      expect(find.text(_en.earnWithdrawSoon), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('no earnings: zeros and the empty state', (tester) async {
      await _pump(
        tester,
        AppRoutes.earnings,
        wallet: _FakeWallet(
          totals: const MyEarnings(
            totalCoins: 0,
            last7DaysCoins: 0,
            last30DaysCoins: 0,
            sendCount: 0,
          ),
        ),
      );
      expect(
        find.descendant(
          of: find.byKey(EarningsScreen.totalKey),
          matching: find.text('0'),
        ),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(find.byKey(EarningsScreen.emptyKey), 100);
      expect(find.text(_en.earnEmpty), findsOneWidget);
    });

    testWidgets('a failure shows the error with a retry', (tester) async {
      await _pump(tester, AppRoutes.earnings, wallet: _FakeWallet(fail: true));
      expect(find.text(_en.earnLoadError), findsWidgets);
    });
  });

  group('creator center', () {
    testWidgets('7 days by default; the periods ask the server again', (
      tester,
    ) async {
      final creator = _FakeCreator();
      await _pump(tester, AppRoutes.creatorCenter, creator: creator);
      expect(creator.calls, [CreatorStatsPeriod.last7Days]);
      expect(
        find.descendant(
          of: find.byKey(CreatorCenterScreen.statKey('followers', 'total')),
          matching: find.text('1,234'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(CreatorCenterScreen.statKey('followers', 'new')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(CreatorCenterScreen.statKey('posts', 'views')),
          matching: find.text('4,500'),
        ),
        findsOneWidget,
      );
      // No reels in the period: an honest line, no zero grid.
      expect(find.byKey(CreatorCenterScreen.noReelsKey), findsOneWidget);
      expect(
        find.byKey(CreatorCenterScreen.statKey('reels', 'views')),
        findsNothing,
      );
      await tester.scrollUntilVisible(
        find.byKey(CreatorCenterScreen.statKey('live', 'time')),
        100,
      );
      expect(
        find.descendant(
          of: find.byKey(CreatorCenterScreen.statKey('live', 'time')),
          matching: find.text(_en.liveDataDuration(1, 30)),
        ),
        findsOneWidget,
      );

      await tester.scrollUntilVisible(
        find.byKey(CreatorCenterScreen.periodKey(CreatorStatsPeriod.allTime)),
        -100,
      );
      await tester.tap(
        find.byKey(CreatorCenterScreen.periodKey(CreatorStatsPeriod.allTime)),
      );
      await tester.pumpAndSettle();
      expect(creator.calls.last, CreatorStatsPeriod.allTime);
      // All time has no "new in the period".
      expect(
        find.byKey(CreatorCenterScreen.statKey('followers', 'new')),
        findsNothing,
      );
    });

    testWidgets('nothing in the period: honest lines for each section', (
      tester,
    ) async {
      await _pump(
        tester,
        AppRoutes.creatorCenter,
        creator: _FakeCreator(empty: true),
      );
      expect(find.byKey(CreatorCenterScreen.noPostsKey), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(CreatorCenterScreen.noLivesKey),
        100,
      );
      expect(find.text(_en.creatorNoLives), findsOneWidget);
    });

    testWidgets('a failure shows the error with a retry', (tester) async {
      await _pump(
        tester,
        AppRoutes.creatorCenter,
        creator: _FakeCreator(fail: true),
      );
      expect(find.text(_en.creatorLoadError), findsOneWidget);
    });

    testWidgets('"My posts and reels" opens the profile', (tester) async {
      await _pump(tester, AppRoutes.creatorCenter);
      await tester.scrollUntilVisible(
        find.byKey(CreatorCenterScreen.openProfileKey),
        200,
      );
      await tester.tap(find.byKey(CreatorCenterScreen.openProfileKey));
      await tester.pumpAndSettle();
      expect(find.text('page profile'), findsOneWidget);
    });
  });

  group('direction', () {
    testWidgets('Arabic RTL: amounts at the left end, reasons in Arabic', (
      tester,
    ) async {
      await _pump(
        tester,
        AppRoutes.wallet,
        wallet: _walletWithHistory(),
        language: AppLanguage.ar,
      );
      await _openHistory(tester);
      expect(find.text(_ar.walletReasonAdminGrant), findsOneWidget);
      final amount = tester.getCenter(find.text('+100'));
      final reason = tester.getCenter(find.text(_ar.walletReasonAdminGrant));
      expect(amount.dx, lessThan(393 / 2));
      expect(reason.dx, greaterThan(amount.dx));
    });

    testWidgets('English LTR: amounts at the right end', (tester) async {
      await _pump(tester, AppRoutes.wallet, wallet: _walletWithHistory());
      await _openHistory(tester);
      final amount = tester.getCenter(find.text('+100'));
      final reason = tester.getCenter(find.text(_en.walletReasonAdminGrant));
      expect(amount.dx, greaterThan(393 / 2));
      expect(reason.dx, lessThan(amount.dx));
    });

    testWidgets('Arabic creator center: the first period chip at the right', (
      tester,
    ) async {
      await _pump(tester, AppRoutes.creatorCenter, language: AppLanguage.ar);
      final first = tester.getCenter(
        find.byKey(CreatorCenterScreen.periodKey(CreatorStatsPeriod.last7Days)),
      );
      final last = tester.getCenter(
        find.byKey(CreatorCenterScreen.periodKey(CreatorStatsPeriod.allTime)),
      );
      expect(first.dx, greaterThan(last.dx));
      expect(find.text(_ar.creatorFollowers), findsOneWidget);
    });
  });

  for (final language in AppLanguage.values) {
    for (final scale in [1.0, 1.3, 2.0]) {
      for (final location in [
        AppRoutes.wallet,
        AppRoutes.earnings,
        AppRoutes.creatorCenter,
      ]) {
        testWidgets(
          '360x800 at $scale (${language.name}) $location: no overflow',
          (tester) async {
            await _pump(
              tester,
              location,
              wallet: _walletWithHistory(),
              language: language,
              viewport: GoldenViewport.android,
              textScale: scale,
            );
            expect(tester.takeException(), isNull);
            // Scroll to the end: every row laid out without overflow.
            await tester.fling(
              find.byType(Scrollable).first,
              const Offset(0, -3000),
              3000,
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
