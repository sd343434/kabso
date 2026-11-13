// D287 (v1.87-social, CONVENTIONS §10.100): a recharge agent's employee acts
// FOR the agent — the hub's «يعمل لصالح …» group with the agent's orders inbox
// and «شراء كرز للوكيل», the cherry screen for the agent (on shift: ask a
// host and answer; off shift or not allowed: read only with the reason; the
// server's `actions`), the orders inbox with «تم استلامه بواسطة موظف آخر»,
// the agent's two switches per employee and the employee's acts, and the
// new error messages. Arabic RTL and English LTR, light and dark, 360×800
// with ×1.3 text. Fakes only (the real flow is the API's e2e). With
// --dart-define=D287_CAPTURE_DIR=<dir> the owner's captures are written
// (393×852 @3x, ar light; labelled fixtures).

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/state/paged_list.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/recharge/application/recharge_orders_providers.dart';
import 'package:kabso_live/features/recharge/data/recharge_orders_repository.dart';
import 'package:kabso_live/features/recharge/data/recharge_repository.dart';
import 'package:kabso_live/features/recharge/presentation/recharge_cherry_screen.dart';
import 'package:kabso_live/features/recharge/presentation/recharge_employees_screen.dart';
import 'package:kabso_live/features/recharge/presentation/recharge_hub_screen.dart';
import 'package:kabso_live/features/recharge/presentation/recharge_order_screen.dart';
import 'package:kabso_live/features/recharge/presentation/recharge_orders_screen.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_recharge_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

const _captureDir = String.fromEnvironment('D287_CAPTURE_DIR');
final AppLocalizations _ar = l10nFor(AppLanguage.ar);
final AppLocalizations _en = l10nFor(AppLanguage.en);

/// The signed-in user (`testUser()`): the employee in these tests.
final String _meId = testUser().id;
final _me = UserSummary(
  id: _meId,
  username: 'layla.k',
  displayName: 'ليلى',
  avatarUrl: null,
);
const _agent = UserSummary(
  id: 'u-agent',
  username: 'coin0007',
  displayName: 'نور للشحن',
  avatarUrl: null,
  rechargeAgentCode: 'coin0007',
);
const _other = UserSummary(
  id: 'u-sami',
  username: 'sami',
  displayName: 'سامي',
  avatarUrl: null,
);
const _host = UserSummary(
  id: 'u-host',
  username: 'host.rana',
  displayName: 'رنا',
  avatarUrl: null,
);
const _buyer = UserSummary(
  id: 'u-sara',
  username: 'sara.m',
  displayName: 'سارة',
  avatarUrl: null,
);

const _rules = RechargeRules(
  activationMinCoins: 30000000,
  cherryUnit: 1000000,
  coinsPerCherryUnit: 93220,
  minCherries: 1000000,
  stepCherries: 100000,
  requestTtlMinutes: 30,
  payoutRateCherries: 1000000,
  payoutRateMinor: 110,
  currency: 'USD',
  ordersEnabled: true,
  orderMinCoins: 10000,
);

RechargeAgentMe _employee({
  bool onShift = true,
  bool buy = true,
  bool orders = true,
  bool kabsoTeam = false,
}) => RechargeAgentMe(
  status: RechargeAgentStatus.none,
  canApply: false,
  rules: _rules,
  employment: RechargeEmployment(
    agentCode: 'coin0007',
    agent: _agent,
    timeZone: 'Africa/Cairo',
    schedule: const [
      WeeklySlot(days: [6, 7, 1, 2, 3], start: '10:00', end: '18:00'),
    ],
    onShiftNow: onShift,
    canBuyCherries: buy,
    receivesOrders: orders,
    kabsoTeam: kabsoTeam,
  ),
);

RechargeCherryRequest _request(
  String id, {
  RechargeCherryStatus status = RechargeCherryStatus.pending,
  bool byHost = true,
  List<String>? actions = const ['confirm', 'decline'],
  RechargeAgentSideBlock? block,
  UserSummary? actedBy,
  int cherries = 2000000,
}) => RechargeCherryRequest(
  id: id,
  status: status,
  cherries: cherries,
  coins: cherries * 93220 ~/ 1000000,
  payoutMinor: cherries * 110 ~/ 1000000,
  currency: 'USD',
  agentCode: 'coin0007',
  agent: _agent,
  host: _host,
  byHost: byHost,
  createdAt: DateTime.utc(2026, 11, 2, 10),
  expiresAt: DateTime.utc(2026, 11, 2, 10, 30),
  viewerIsHost: false,
  actions: actions,
  viewerBlock: block,
  actedBy: actedBy,
);

RechargeOrder _order(
  String id, {
  RechargeOrderStatus status = RechargeOrderStatus.requested,
  UserSummary? claimedBy,
  RechargeAgentSideBlock? block,
  Set<RechargeOrderAction> actions = const {
    RechargeOrderAction.sendDetails,
    RechargeOrderAction.cancel,
    RechargeOrderAction.message,
  },
}) => RechargeOrder(
  id: id,
  status: status,
  viewerRole: 'EMPLOYEE',
  buyer: _buyer,
  agent: _agent,
  agentCode: 'coin0007',
  country: 'EG',
  coins: 5000000,
  price: const RechargePrice(usdMinor: 6250, usd: '62.50'),
  paymentType: RechargePaymentType.mobileWallet,
  heldCoins: status == RechargeOrderStatus.requested ? 0 : 5000000,
  noticeAcknowledged: false,
  actions: block == null ? actions : const {},
  createdAt: DateTime.utc(2026, 11, 2, 9),
  claimedBy: claimedBy,
  viewerBlock: block,
);

class _FakeOrders implements RechargeOrdersRepository {
  new(this.orders);

  final List<RechargeOrder> orders;
  final asked = <bool>[];

  @override
  Future<PageResult<RechargeOrder>> list({
    required bool asAgent,
    String? cursor,
  }) async {
    asked.add(asAgent);
    return (items: orders, next: null);
  }

  @override
  Future<RechargeOrder> get(String id) async =>
      orders.firstWhere((o) => o.id == id);

  @override
  Future<List<RechargeOrderMessage>> messages(
    String id, {
    int limit = 100,
  }) async => [
    RechargeOrderMessage(
      id: 'm1',
      kind: 'SYSTEM',
      role: 'SYSTEM',
      event: 'CREATED',
      hasImage: false,
      createdAt: DateTime.utc(2026, 11, 2, 9),
    ),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    '${invocation.memberName} is not used by these tests',
  );
}

final GlobalKey _boundary = GlobalKey();

Future<void> _pump(
  WidgetTester tester,
  String location, {
  required FakeRechargeRepository repo,
  _FakeOrders? orders,
  AppLanguage language = AppLanguage.ar,
  GoldenViewport viewport = GoldenViewport.phone,
  double textScale = 1,
  Brightness brightness = Brightness.light,
}) async {
  final router = GoRouter(
    initialLocation: location,
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SizedBox.shrink()),
      GoRoute(
        path: AppRoutes.recharge,
        builder: (_, _) => const RechargeHubScreen(),
      ),
      GoRoute(
        path: AppRoutes.rechargeEmployees,
        builder: (_, _) => const RechargeEmployeesScreen(),
      ),
      GoRoute(
        path: AppRoutes.rechargeCherries,
        builder: (_, _) => const RechargeCherryScreen(),
      ),
      GoRoute(
        path: AppRoutes.rechargeOrders,
        builder: (_, state) => RechargeOrdersScreen(
          incoming: state.uri.queryParameters['incoming'] == '1',
        ),
      ),
      GoRoute(
        path: AppRoutes.rechargeOrderPattern,
        builder: (_, state) =>
            RechargeOrderScreen(orderId: state.pathParameters['orderId']!),
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
        rechargeRepositoryProvider.overrideWithValue(repo),
        rechargeOrdersRepositoryProvider.overrideWithValue(
          orders ?? _FakeOrders(const []),
        ),
        storeBuildProvider.overrideWithValue(false),
      ],
      child: RepaintBoundary(
        key: _boundary,
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          routerConfig: router,
          locale: language.locale,
          supportedLocales: KabsoApp.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          theme: buildAppTheme(brightness: brightness, locale: language.locale),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The owner's capture (only with D287_CAPTURE_DIR).
Future<void> _capture(WidgetTester tester, String name) async {
  if (_captureDir.isEmpty) return;
  await tester.runAsync(() async {
    final boundary =
        _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    await Directory(_captureDir).create(recursive: true);
    await File('$_captureDir/$name.png')
        .writeAsBytes(data!.buffer.asUint8List());
  });
}

final _staff = [
  RechargeEmployee(
    user: _me,
    timeZone: 'Africa/Cairo',
    schedule: const [
      WeeklySlot(days: [6, 7, 1, 2, 3], start: '10:00', end: '18:00'),
    ],
    onShiftNow: true,
    addedAt: DateTime.utc(2026, 10, 30),
    sales: (
      today: (count: 2, coins: 3000000),
      last7Days: (count: 9, coins: 12000000),
      last30Days: (count: 30, coins: 41000000),
    ),
    cherryPurchases: (
      today: (count: 3, coins: 559320),
      last7Days: (count: 5, coins: 932200),
      last30Days: (count: 5, coins: 932200),
    ),
    orders: (
      today: (count: 1, coins: 5000000),
      last7Days: (count: 4, coins: 21000000),
      last30Days: (count: 4, coins: 21000000),
    ),
  ),
  RechargeEmployee(
    user: _other,
    timeZone: 'Africa/Cairo',
    schedule: const [
      WeeklySlot(days: [4, 5], start: '18:00', end: '24:00'),
    ],
    onShiftNow: false,
    addedAt: DateTime.utc(2026, 10, 31),
    sales: noSalesStats,
    canBuyCherries: false,
  ),
];

void main() {
  group('models', () {
    test('a Kabso Team account: the STAFF block and kabsoTeam (owner)', () {
      expect(
        RechargeAgentSideBlock.fromWire('STAFF'),
        RechargeAgentSideBlock.staff,
      );
      const slot = {
        'days': [1],
        'start': '10:00',
        'end': '18:00',
      };
      const user = {
        'id': 'u1',
        'username': 'nour',
        'displayName': 'نور',
        'avatarUrl': null,
      };
      final job = RechargeEmployment.fromJson(const {
        'agentCode': 'coin0007',
        'agent': user,
        'timeZone': 'UTC',
        'schedule': [slot],
        'onShiftNow': true,
        'canBuyCherries': true,
        'receivesOrders': true,
        'kabsoTeam': true,
      });
      expect(job.kabsoTeam, isTrue);
      expect(job.mayAct, isFalse);
      // An older server sends no flag: not the team.
      final old = RechargeEmployment.fromJson(const {
        'agent': user,
        'timeZone': 'UTC',
        'schedule': [slot],
        'onShiftNow': true,
      });
      expect(old.kabsoTeam, isFalse);
      expect(old.mayAct, isTrue);
      final e = RechargeEmployee.fromJson(const {
        'user': user,
        'timeZone': 'UTC',
        'schedule': [slot],
        'onShiftNow': true,
        'addedAt': '2026-10-30T00:00:00.000Z',
        'sales': null,
        'kabsoTeam': true,
      });
      expect(e.kabsoTeam, isTrue);
    });

    test('a cherry request carries the side, actions, block and actedBy', () {
      final r = RechargeCherryRequest.fromJson(const {
        'id': 'r1',
        'status': 'PENDING',
        'cherries': 1000000,
        'coins': 93220,
        'payoutMinor': 110,
        'currency': 'USD',
        'agentCode': 'coin0007',
        'agent': {'id': 'a', 'username': 'coin0007', 'displayName': 'نور'},
        'host': {'id': 'h', 'username': 'rana', 'displayName': 'رنا'},
        'initiatedBy': 'HOST',
        'createdAt': '2026-11-02T10:00:00Z',
        'expiresAt': '2026-11-02T10:30:00Z',
        'decidedAt': null,
        'viewerSide': 'AGENT',
        'actions': <String>[],
        'viewerBlock': 'OFF_SHIFT',
        'actedBy': {'id': 's', 'username': 'sami', 'displayName': 'سامي'},
      });
      expect(r.viewerIsHost, isFalse);
      expect(r.actions, isEmpty);
      expect(r.viewerBlock, RechargeAgentSideBlock.offShift);
      expect(r.actedBy?.displayName, 'سامي');
    });

    test('an older server: no side or actions; employment permissions off', () {
      final r = RechargeCherryRequest.fromJson(const {
        'id': 'r1',
        'status': 'PENDING',
        'cherries': 1000000,
        'coins': 93220,
        'payoutMinor': 110,
        'currency': 'USD',
        'agentCode': 'coin0007',
        'agent': {'id': 'a', 'username': 'coin0007', 'displayName': 'نور'},
        'host': {'id': 'h', 'username': 'rana', 'displayName': 'رنا'},
        'initiatedBy': 'AGENT',
        'createdAt': '2026-11-02T10:00:00Z',
        'expiresAt': '2026-11-02T10:30:00Z',
      });
      expect(r.viewerIsHost, isNull);
      expect(r.actions, isNull);
      final job = RechargeEmployment.fromJson(const {
        'agentCode': 'coin0007',
        'agent': {'id': 'a', 'username': 'coin0007', 'displayName': 'نور'},
        'timeZone': 'UTC',
        'schedule': <Object>[],
        'onShiftNow': true,
      });
      expect(job.canBuyCherries, isFalse);
      expect(job.receivesOrders, isFalse);
    });

    test('an order carries who owns it and the viewer block', () {
      final o = RechargeOrder.fromJson(const {
        'id': 'o1',
        'status': 'AWAITING_PAYMENT',
        'viewerRole': 'EMPLOYEE',
        'buyer': {'id': 'b', 'username': 'sara', 'displayName': 'سارة'},
        'agent': {'id': 'a', 'username': 'coin0007', 'displayName': 'نور'},
        'agentCode': 'coin0007',
        'country': 'EG',
        'coins': 1000000,
        'price': {'usdMinor': 1250, 'usd': '12.50', 'local': null},
        'paymentType': 'MOBILE_WALLET',
        'heldCoins': 1000000,
        'noticeAcknowledged': false,
        'actions': <String>[],
        'claimedBy': {'id': 's', 'username': 'sami', 'displayName': 'سامي'},
        'claimedAt': '2026-11-02T10:00:00Z',
        'viewerBlock': 'CLAIMED',
        'createdAt': '2026-11-02T09:00:00Z',
      });
      expect(o.claimedBy?.id, 's');
      expect(o.viewerBlock, RechargeAgentSideBlock.claimed);
      expect(
        rechargeOrderClaimText(_ar, o, _meId)?.text,
        'تم استلامه بواسطة موظف آخر',
      );
    });

    test('the two new codes have their own messages', () {
      expect(
        failureMessage(
          _ar,
          const ServerFailure(
            code: ErrorCode.rechargeEmployeeNotPermitted,
            rawCode: 'RECHARGE_EMPLOYEE_NOT_PERMITTED',
            debugMessage: '',
          ),
        ),
        _ar.errorRechargeEmployeeNotPermitted,
      );
      expect(
        failureMessage(
          _en,
          const ServerFailure(
            code: ErrorCode.rechargeOrderClaimed,
            rawCode: 'RECHARGE_ORDER_CLAIMED',
            debugMessage: '',
          ),
        ),
        'Another employee already took this order.',
      );
    });
  });

  group('the employee hub', () {
    testWidgets('«يعمل لصالح …» with the agent’s inbox and «شراء كرز للوكيل»', (
      tester,
    ) async {
      await _pump(
        tester,
        AppRoutes.recharge,
        repo: FakeRechargeRepository(mine: _employee()),
      );
      expect(find.byKey(RechargeHubScreen.employmentKey), findsOneWidget);
      expect(
        find.text(_ar.rechargeWorksFor(KFormat.bidiIsolate('نور للشحن'))),
        findsOneWidget,
      );
      expect(find.byKey(RechargeHubScreen.agentOrdersKey), findsOneWidget);
      expect(find.byKey(RechargeHubScreen.agentCherriesKey), findsOneWidget);
      expect(find.text(_ar.rechargeCherryBuyForAgentTitle), findsOneWidget);
      // The host flow «بيع الكرز لوكيل» is not offered to them any more.
      expect(find.byKey(RechargeHubScreen.cherriesKey), findsNothing);
      expect(tester.takeException(), isNull);
      await _capture(tester, 'app-01-employee-hub');
    });

    testWidgets('without the permissions: no «يعمل لصالح» group', (
      tester,
    ) async {
      await _pump(
        tester,
        AppRoutes.recharge,
        repo: FakeRechargeRepository(
          mine: _employee(buy: false, orders: false),
        ),
      );
      expect(find.byKey(RechargeHubScreen.forAgentKey), findsNothing);
      expect(find.byKey(RechargeHubScreen.agentOrdersKey), findsNothing);
      expect(find.byKey(RechargeHubScreen.cherriesKey), findsOneWidget);
    });

    testWidgets(
      'a Kabso Team account now: reads only, no «بيع عملات», says why (owner)',
      (tester) async {
        await _pump(
          tester,
          AppRoutes.recharge,
          repo: FakeRechargeRepository(mine: _employee(kabsoTeam: true)),
        );
        expect(find.text(_ar.rechargeBlockStaff), findsNWidgets(3));
        expect(
          tester
              .widget<Text>(find.byKey(RechargeHubScreen.employeeBlockKey))
              .data,
          _ar.rechargeBlockStaff,
        );
        final sell = tester.widget<KButton>(
          find.byKey(RechargeHubScreen.sellKey),
        );
        expect(sell.onPressed, isNull);
        expect(tester.takeException(), isNull);
        await _capture(tester, 'app-07-hub-kabso-team-reads-only');
      },
    );

    testWidgets('off shift: both rows say so', (tester) async {
      await _pump(
        tester,
        AppRoutes.recharge,
        repo: FakeRechargeRepository(mine: _employee(onShift: false)),
      );
      expect(find.text(_ar.rechargeBlockOffShift), findsNWidgets(2));
    });

    for (final (language, brightness) in [
      (AppLanguage.ar, Brightness.light),
      (AppLanguage.ar, Brightness.dark),
      (AppLanguage.en, Brightness.light),
      (AppLanguage.en, Brightness.dark),
    ]) {
      testWidgets(
        'fits 360×800 with ×1.3 text (${language.name}, ${brightness.name})',
        (tester) async {
          await _pump(
            tester,
            AppRoutes.recharge,
            repo: FakeRechargeRepository(mine: _employee()),
            language: language,
            brightness: brightness,
            viewport: GoldenViewport.android,
            textScale: 1.3,
          );
          expect(tester.takeException(), isNull);
          await tester.scrollUntilVisible(
            find.byKey(RechargeHubScreen.agentCherriesKey),
            200,
            scrollable: find.byType(Scrollable).first,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  });

  group('cherry purchases for the agent', () {
    testWidgets('on shift: answers the agent’s requests, asks a host by name', (
      tester,
    ) async {
      final repo = FakeRechargeRepository(
        mine: _employee(),
        requests: [
          _request('r1'),
          _request(
            'r2',
            status: RechargeCherryStatus.confirmed,
            actions: const [],
            actedBy: _other,
          ),
        ],
      );
      await _pump(tester, AppRoutes.rechargeCherries, repo: repo);
      expect(find.text(_ar.rechargeCherryBuyForAgentTitle), findsWidgets);
      expect(find.byKey(RechargeCherryScreen.forAgentKey), findsOneWidget);
      // Another employee's confirmed purchase shows who did it.
      expect(
        find.text(_ar.rechargeActedBy(KFormat.bidiIsolate('سامي'))),
        findsOneWidget,
      );
      await _capture(tester, 'app-02-cherry-purchase-employee');
      await tester.tap(find.byKey(RechargeCherryScreen.confirmKey('r1')));
      await tester.pumpAndSettle();
      expect(repo.answered, [('r1', 'confirm')]);

      await tester.tap(find.byKey(RechargeCherryScreen.newKey));
      await tester.pumpAndSettle();
      // As the agent's side: the host's username is asked.
      expect(find.text(_ar.rechargeHostField), findsOneWidget);
      await tester.enterText(
        find.byKey(RechargeCherryNewSheet.otherKey),
        'host.rana',
      );
      await tester.enterText(
        find.byKey(RechargeCherryNewSheet.amountKey),
        '2000000',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(RechargeCherryNewSheet.sendKey));
      await tester.pumpAndSettle();
      expect(repo.created.single, (
        cherries: 2000000,
        agentCode: null,
        host: 'host.rana',
      ));
    });

    testWidgets('off shift: read only with the reason, no new request', (
      tester,
    ) async {
      final repo = FakeRechargeRepository(
        mine: _employee(onShift: false),
        requests: [
          _request(
            'r1',
            actions: const [],
            block: RechargeAgentSideBlock.offShift,
          ),
        ],
      );
      await _pump(tester, AppRoutes.rechargeCherries, repo: repo);
      expect(find.byKey(RechargeCherryScreen.blockKey('r1')), findsOneWidget);
      expect(find.byKey(RechargeCherryScreen.confirmKey('r1')), findsNothing);
      final button = tester.widget<KButton>(
        find.byKey(RechargeCherryScreen.newKey),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('an older server: as before (the agent or the host)', (
      tester,
    ) async {
      final repo = FakeRechargeRepository(
        mine: fixtureActive(),
        requests: [
          RechargeCherryRequest(
            id: 'r9',
            status: RechargeCherryStatus.pending,
            cherries: 1000000,
            coins: 93220,
            payoutMinor: 110,
            currency: 'USD',
            agentCode: 'coin0007',
            agent: _me,
            host: _host,
            byHost: true,
            createdAt: DateTime.utc(2026, 11, 2, 10),
            expiresAt: DateTime.utc(2026, 11, 2, 10, 30),
          ),
        ],
      );
      await _pump(tester, AppRoutes.rechargeCherries, repo: repo);
      expect(find.byKey(RechargeCherryScreen.confirmKey('r9')), findsOneWidget);
    });
  });

  group('the orders inbox', () {
    testWidgets('«تم استلامه بواسطة موظف آخر» and the owner’s own line', (
      tester,
    ) async {
      final orders = _FakeOrders([
        _order('o1'),
        _order(
          'o2',
          status: RechargeOrderStatus.awaitingPayment,
          claimedBy: _other,
          block: RechargeAgentSideBlock.claimed,
        ),
        _order(
          'o3',
          status: RechargeOrderStatus.paid,
          claimedBy: _me,
          actions: const {
            RechargeOrderAction.confirm,
            RechargeOrderAction.message,
          },
        ),
      ]);
      await _pump(
        tester,
        '${AppRoutes.rechargeOrders}?incoming=1',
        repo: FakeRechargeRepository(mine: _employee()),
        orders: orders,
      );
      expect(orders.asked.last, isTrue);
      expect(find.byKey(RechargeOrdersScreen.claimKey('o1')), findsNothing);
      expect(
        tester
            .widget<Text>(find.byKey(RechargeOrdersScreen.claimKey('o2')))
            .data,
        'تم استلامه بواسطة موظف آخر',
      );
      expect(
        tester
            .widget<Text>(find.byKey(RechargeOrdersScreen.claimKey('o3')))
            .data,
        _ar.rechargeOrderClaimedByYou,
      );
      await _capture(tester, 'app-03-orders-inbox-claimed');

      await tester.tap(find.byKey(RechargeOrdersScreen.rowKey('o2')));
      await tester.pumpAndSettle();
      expect(find.byKey(RechargeOrderScreen.claimKey), findsOneWidget);
      expect(find.byKey(RechargeOrderScreen.detailsKey), findsNothing);
      expect(find.byKey(RechargeOrderScreen.sendKey), findsNothing);
    });

    testWidgets('without «يستقبل طلبات الشراء»: only their own orders', (
      tester,
    ) async {
      final orders = _FakeOrders(const []);
      await _pump(
        tester,
        '${AppRoutes.rechargeOrders}?incoming=1',
        repo: FakeRechargeRepository(mine: _employee(orders: false)),
        orders: orders,
      );
      expect(find.byKey(RechargeOrdersScreen.incomingKey), findsNothing);
      expect(orders.asked, everyElement(isFalse));
    });
  });

  group('the agent’s employees', () {
    testWidgets('two switches per employee, the acts of today', (tester) async {
      final repo = FakeRechargeRepository(
        mine: fixtureActive(),
        staff: List.of(_staff),
      );
      await _pump(tester, AppRoutes.rechargeEmployees, repo: repo);
      Switch switchOf(Key k) => tester.widget<Switch>(
        find.descendant(of: find.byKey(k), matching: find.byType(Switch)),
      );
      expect(switchOf(RechargeEmployeesScreen.buyKey('layla.k')).value, isTrue);
      expect(
        switchOf(RechargeEmployeesScreen.ordersKey('layla.k')).value,
        isTrue,
      );
      expect(switchOf(RechargeEmployeesScreen.buyKey('sami')).value, isFalse);
      expect(
        tester
            .widget<Text>(
              find.byKey(RechargeEmployeesScreen.actsKey('layla.k')),
            )
            .data,
        _ar.rechargeEmployeeActsToday(3, 1),
      );
      await _capture(tester, 'app-04-employee-permissions');
      await tester.tap(
        find.descendant(
          of: find.byKey(RechargeEmployeesScreen.ordersKey('layla.k')),
          matching: find.byType(Switch),
        ),
      );
      await tester.pumpAndSettle();
      expect(repo.permits.single, (
        username: 'layla.k',
        canBuyCherries: null,
        receivesOrders: false,
      ));
      expect(
        switchOf(RechargeEmployeesScreen.ordersKey('layla.k')).value,
        isFalse,
      );
    });

    for (final language in [AppLanguage.ar, AppLanguage.en]) {
      testWidgets(
        'adding a Kabso Team account: the honest message in the sheet '
        '(${language.name}, owner)',
        (tester) async {
          final repo =
              FakeRechargeRepository(
                  mine: fixtureActive(),
                  staff: List.of(_staff),
                )
                ..addEmployeeError = const ServerFailure(
                  code: ErrorCode.rechargeEmployeeIsStaff,
                  rawCode: 'RECHARGE_EMPLOYEE_IS_STAFF',
                  debugMessage: 'A Kabso Team account cannot be an employee.',
                  statusCode: 403,
                );
          await _pump(
            tester,
            AppRoutes.rechargeEmployees,
            repo: repo,
            language: language,
          );
          await tester.tap(find.byKey(RechargeEmployeesScreen.addKey));
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byKey(RechargeEmployeeSheet.usernameKey),
            'kabso_mod',
          );
          await tester.ensureVisible(find.byKey(RechargeEmployeeSheet.saveKey));
          await tester.tap(find.byKey(RechargeEmployeeSheet.saveKey));
          await tester.pumpAndSettle();
          final l10n = language == AppLanguage.ar ? _ar : _en;
          expect(find.text(l10n.errorRechargeEmployeeIsStaff), findsOneWidget);
          // The sheet stays open; nobody was added.
          expect(find.byKey(RechargeEmployeeSheet.saveKey), findsOneWidget);
          expect(repo.staff, hasLength(_staff.length));
          expect(tester.takeException(), isNull);
          if (language == AppLanguage.ar) {
            await _capture(tester, 'app-05-add-kabso-team-refused');
          }
        },
      );
    }

    testWidgets(
      'an employee who became a Kabso Team account: the agent sees why',
      (tester) async {
        final staffNow = _staff.first;
        await _pump(
          tester,
          AppRoutes.rechargeEmployees,
          repo: FakeRechargeRepository(
            mine: fixtureActive(),
            staff: [
              RechargeEmployee(
                user: staffNow.user,
                timeZone: staffNow.timeZone,
                schedule: staffNow.schedule,
                onShiftNow: true,
                addedAt: staffNow.addedAt,
                sales: staffNow.sales,
                kabsoTeam: true,
              ),
              _staff.last,
            ],
          ),
        );
        final note = find.byKey(
          RechargeEmployeesScreen.staffKey(staffNow.user.username),
        );
        expect(note, findsOneWidget);
        expect(
          find.descendant(
            of: note,
            matching: find.text(_ar.rechargeEmployeeIsStaffNote),
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(
            RechargeEmployeesScreen.staffKey(_staff.last.user.username),
          ),
          findsNothing,
        );
        await _capture(tester, 'app-06-employee-became-kabso-team');
      },
    );

    testWidgets('fits 360×800 with ×1.3 text (en, dark)', (tester) async {
      await _pump(
        tester,
        AppRoutes.rechargeEmployees,
        repo: FakeRechargeRepository(
          mine: fixtureActive(),
          staff: List.of(_staff),
        ),
        language: AppLanguage.en,
        brightness: Brightness.dark,
        viewport: GoldenViewport.android,
        textScale: 1.3,
      );
      expect(find.text(_en.rechargePermReceivesOrders), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });
}
