// D204: recharge orders «طلبات الشحن» in the app — «اطلب شحن» in the
// directory (only when the server allows orders and never in a store
// build), the new order with the server's price (USD and the local amount),
// the order's chat (system lines, the payment details, «الإدارة»), the agent's
// payment details (the coins are frozen), the protection notice that must be
// acknowledged before «قمت بالإرسال» (with the transfer's screenshot), the
// 15-minute wait seen by both sides with «نزاع» enabled after it, the agent's
// «استلمت» / «نزاع», the orders list, the notification sentence and route.
// Arabic RTL and English LTR, 393×852 and 360×800 with large text. Fakes only
// (the real flow is the API's e2e). With --dart-define=D204_CAPTURE_DIR=<dir>
// the owner's captures are written (393×852 @3x).

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:clock/clock.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/state/paged_list.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/notifications/presentation/notifications_screen.dart'
    show rechargeOrderNotificationText;
import 'package:kabso_live/features/profile/data/profile_edit_repository.dart';
import 'package:kabso_live/features/push/push_payload.dart';
import 'package:kabso_live/features/recharge/application/recharge_orders_providers.dart';
import 'package:kabso_live/features/recharge/data/recharge_orders_repository.dart';
import 'package:kabso_live/features/recharge/data/recharge_repository.dart';
import 'package:kabso_live/features/recharge/presentation/recharge_directory_screen.dart';
import 'package:kabso_live/features/recharge/presentation/recharge_order_new_screen.dart';
import 'package:kabso_live/features/recharge/presentation/recharge_order_screen.dart';
import 'package:kabso_live/features/recharge/presentation/recharge_orders_screen.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_recharge_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

const _captureDir = String.fromEnvironment('D204_CAPTURE_DIR');
final AppLocalizations _ar = l10nFor(AppLanguage.ar);
final AppLocalizations _en = l10nFor(AppLanguage.en);

/// A 1×1 PNG (the "screenshot" the fake picker returns).
final Uint8List _png = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 13, 0x49, 0x48, //
  0x44, 0x52, 0, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0, 0, 0, 0x1F, 0x15, 0xC4, 0x89,
  0, 0, 0, 13, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0, 1, 0, 0, 5, 0, 1,
  0x0D, 0x0A, 0x2D, 0xB4, 0, 0, 0, 0, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42,
  0x60, 0x82,
]);

class _Picker implements AvatarPhotoPicker {
  int asked = 0;

  @override
  Future<Uint8List?> pick(AvatarSource source) async {
    asked += 1;
    return _png;
  }
}

const _buyer = UserSummary(
  id: 'u-sara',
  username: 'sara.m',
  displayName: 'سارة',
  avatarUrl: null,
);
const _agent = UserSummary(
  id: 'u-noor',
  username: 'coin0007',
  displayName: 'نور للشحن',
  avatarUrl: null,
  rechargeAgentCode: 'coin0007',
);

const _egp = RechargePrice(
  usdMinor: 12500,
  usd: '125.00',
  local: (currency: 'EGP', amount: '6312.50', rate: '50.5'),
);

RechargeOrder _order({
  required RechargeOrderStatus status,
  String role = 'BUYER',
  Set<RechargeOrderAction> actions = const {RechargeOrderAction.message},
  bool ack = false,
  int held = 0,
  DateTime? paidAt,
}) => RechargeOrder(
  id: 'o-1',
  status: status,
  viewerRole: role,
  buyer: _buyer,
  agent: _agent,
  agentCode: 'coin0007',
  country: 'EG',
  coins: 10000000,
  price: _egp,
  paymentType: RechargePaymentType.mobileWallet,
  heldCoins: held,
  noticeAcknowledged: ack,
  paidAt: paidAt,
  disputeOpensAt: paidAt?.add(const Duration(minutes: 15)),
  actions: actions,
  createdAt: DateTime.utc(2026, 10, 31, 9),
);

RechargeOrderMessage _m(
  String id,
  String kind,
  String role, {
  String? text,
  String? event,
  bool image = false,
  UserSummary? author,
}) => RechargeOrderMessage(
  id: id,
  kind: kind,
  role: role,
  author: author,
  text: text,
  event: event,
  method: kind == 'PAYMENT_DETAILS' ? RechargePaymentType.mobileWallet : null,
  hasImage: image,
  createdAt: DateTime.utc(2026, 10, 31, 9, int.parse(id.substring(1))),
);

final List<RechargeOrderMessage> _chat = [
  _m('m1', 'SYSTEM', 'SYSTEM', event: 'CREATED'),
  _m(
    'm2',
    'TEXT',
    'BUYER',
    author: _buyer,
    text: 'السلام عليكم، أريد ١٠ ملايين عملة',
  ),
  _m(
    'm3',
    'TEXT',
    'AGENT',
    author: _agent,
    text: 'أهلاً بك، هذه معلومات التحويل',
  ),
  _m(
    'm4',
    'PAYMENT_DETAILS',
    'AGENT',
    author: _agent,
    text: 'فودافون كاش: 0100 000 0000\nباسم: نور أحمد',
  ),
  _m('m5', 'SYSTEM', 'SYSTEM', event: 'DETAILS_SENT'),
];

class _FakeOrders implements RechargeOrdersRepository {
  new(this.order, {List<RechargeOrderMessage>? chat})
    : chat = chat ?? List.of(_chat);

  RechargeOrder order;
  final List<RechargeOrderMessage> chat;
  final calls = <String>[];
  final created = <({int coins, String type, String key})>[];
  final details = <String>[];
  final texts = <String>[];
  int? lastQuotedCoins;

  @override
  Future<RechargeOrderQuote> quote({
    required String agentCode,
    required String country,
    required int coins,
  }) async {
    lastQuotedCoins = coins;
    final usd = coins * 1250 ~/ 1000000;
    String money(int minor) =>
        '${minor ~/ 100}.${(minor % 100).toString().padLeft(2, '0')}';
    return RechargeOrderQuote(
      coins: coins,
      price: RechargePrice(
        usdMinor: usd,
        usd: money(usd),
        local: (currency: 'EGP', amount: money(usd * 505 ~/ 10), rate: '50.5'),
      ),
      paymentTypes: const [
        RechargePaymentType.mobileWallet,
        RechargePaymentType.bankTransfer,
      ],
      minCoins: 10000,
      maxCoins: 1000000000,
    );
  }

  @override
  Future<RechargeOrder> create({
    required String agentCode,
    required String country,
    required int coins,
    required RechargePaymentType paymentType,
    required String idempotencyKey,
  }) async {
    created.add((coins: coins, type: paymentType.wire, key: idempotencyKey));
    return order;
  }

  @override
  Future<PageResult<RechargeOrder>> list({
    required bool asAgent,
    String? cursor,
  }) async => (items: [order], next: null);

  @override
  Future<RechargeOrder> get(String id) async => order;

  @override
  Future<List<RechargeOrderMessage>> messages(
    String id, {
    int limit = 100,
  }) async => List.of(chat);

  @override
  Future<RechargeOrderMessage> sendText(String id, String text) async {
    texts.add(text);
    final m = _m('m9', 'TEXT', 'BUYER', author: _buyer, text: text);
    chat.add(m);
    return m;
  }

  @override
  Future<RechargeOrderMessage> sendImage(String id, Uint8List bytes) async {
    calls.add('image');
    return _m('m9', 'IMAGE', 'BUYER', image: true);
  }

  @override
  Future<Uint8List> image(String id, String messageId) async => _png;

  @override
  Future<RechargeOrder> sendDetails(
    String id,
    RechargePaymentType method,
    String text,
  ) async {
    details.add(text);
    return order = _order(
      status: RechargeOrderStatus.awaitingPayment,
      role: 'AGENT',
      held: order.coins,
    );
  }

  @override
  Future<RechargeOrder> acknowledgeNotice(String id) async {
    calls.add('ack');
    return order = _order(
      status: RechargeOrderStatus.awaitingPayment,
      ack: true,
      held: order.coins,
      actions: const {
        RechargeOrderAction.message,
        RechargeOrderAction.markPaid,
        RechargeOrderAction.cancel,
      },
    );
  }

  @override
  Future<RechargeOrder> markPaid(String id, Uint8List screenshot) async {
    calls.add('paid:${screenshot.length}');
    return order = _order(
      status: RechargeOrderStatus.paid,
      ack: true,
      held: order.coins,
      paidAt: clock.now(),
    );
  }

  @override
  Future<RechargeOrder> confirm(String id) async {
    calls.add('confirm');
    return order = _order(status: RechargeOrderStatus.completed, role: 'AGENT');
  }

  @override
  Future<RechargeOrder> dispute(String id, {String? reason}) async {
    calls.add('dispute:${reason ?? ''}');
    return order = _order(
      status: RechargeOrderStatus.disputed,
      role: order.viewerRole,
      held: order.coins,
    );
  }

  @override
  Future<RechargeOrder> cancel(String id, {String? reason}) async {
    calls.add('cancel');
    return order = _order(status: RechargeOrderStatus.cancelled);
  }
}

const _ordersOn = RechargeRules(
  activationMinCoins: 30000000,
  cherryUnit: 1000000,
  coinsPerCherryUnit: 93220,
  minCherries: 1000000,
  stepCherries: 100000,
  requestTtlMinutes: 30,
  payoutRateCherries: 1000000,
  payoutRateMinor: 1000,
  currency: 'USD',
  ordersEnabled: true,
  orderMinCoins: 10000,
);

final GlobalKey _boundary = GlobalKey();

Future<void> _pump(
  WidgetTester tester,
  String location, {
  required _FakeOrders orders,
  FakeRechargeRepository? recharge,
  AppLanguage language = AppLanguage.ar,
  GoldenViewport viewport = GoldenViewport.phone,
  double textScale = 1,
  bool storeBuild = false,
  _Picker? picker,
  Brightness brightness = Brightness.light,
}) async {
  final router = GoRouter(
    initialLocation: location,
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SizedBox.shrink()),
      GoRoute(
        path: AppRoutes.rechargeAgents,
        builder: (_, _) => const RechargeDirectoryScreen(),
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
      GoRoute(
        path: AppRoutes.rechargeOrderNew,
        builder: (_, state) => RechargeOrderNewScreen(
          agentCode: state.uri.queryParameters['agent'] ?? '',
          country: state.uri.queryParameters['country'] ?? 'EG',
        ),
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
        rechargeRepositoryProvider.overrideWithValue(
          recharge ??
              FakeRechargeRepository(
                mine: const RechargeAgentMe(
                  status: RechargeAgentStatus.none,
                  canApply: true,
                  rules: _ordersOn,
                ),
              ),
        ),
        rechargeOrdersRepositoryProvider.overrideWithValue(orders),
        storeBuildProvider.overrideWithValue(storeBuild),
        avatarPhotoPickerProvider.overrideWithValue(picker ?? _Picker()),
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

/// The owner's capture (only with D204_CAPTURE_DIR).
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

void main() {
  group('the directory', () {
    final agents = [
      const RechargeAgentListing(
        code: 'coin0007',
        user: _agent,
        locations: [
          (country: 'EG', cities: ['القاهرة']),
        ],
        paymentTypes: [RechargePaymentType.mobileWallet],
        whatsappNow: '+201001234567',
        paymentMethodNow: 'فودافون كاش',
      ),
    ];

    testWidgets('«اطلب شحن» opens the new order when orders are on', (
      tester,
    ) async {
      final orders = _FakeOrders(_order(status: RechargeOrderStatus.requested));
      await _pump(
        tester,
        AppRoutes.rechargeAgents,
        orders: orders,
        recharge: FakeRechargeRepository(
          agents: agents,
          mine: const RechargeAgentMe(
            status: RechargeAgentStatus.none,
            canApply: true,
            rules: _ordersOn,
          ),
        ),
      );
      final order = find.byKey(RechargeDirectoryScreen.orderKey('coin0007'));
      expect(order, findsOneWidget);
      expect(
        find.byKey(RechargeDirectoryScreen.contactKey('coin0007')),
        findsOneWidget,
      );
      await tester.tap(order);
      await tester.pumpAndSettle();
      expect(find.byType(RechargeOrderNewScreen), findsOneWidget);
    });

    testWidgets('no «اطلب شحن» in a store build or when the server is off', (
      tester,
    ) async {
      for (final (store, rules) in [(true, _ordersOn), (false, fixtureRules)]) {
        await _pump(
          tester,
          AppRoutes.rechargeAgents,
          orders: _FakeOrders(_order(status: RechargeOrderStatus.requested)),
          storeBuild: store,
          recharge: FakeRechargeRepository(
            agents: agents,
            mine: RechargeAgentMe(
              status: RechargeAgentStatus.none,
              canApply: true,
              rules: rules,
            ),
          ),
        );
        expect(
          find.byKey(RechargeDirectoryScreen.orderKey('coin0007')),
          findsNothing,
        );
        // Direct contact (D185) is unchanged.
        expect(
          find.byKey(RechargeDirectoryScreen.contactKey('coin0007')),
          findsOneWidget,
        );
      }
    });
  });

  group('the new order', () {
    testWidgets('the server price (USD and EGP), the methods, one key; then '
        'the order opens', (tester) async {
      final orders = _FakeOrders(_order(status: RechargeOrderStatus.requested));
      await _pump(
        tester,
        AppRoutes.rechargeOrderNewFor('coin0007', 'EG'),
        orders: orders,
      );
      expect(find.text('طلب شحن جديد'), findsOneWidget);
      // 1 000 000 coins by default at $12.50.
      expect(find.textContaining('12.50'), findsWidgets);
      expect(find.textContaining('631.25'), findsOneWidget);
      await tester.tap(find.byKey(RechargeOrderNewScreen.presetKey(10000000)));
      await tester.pumpAndSettle();
      expect(orders.lastQuotedCoins, 10000000);
      expect(find.textContaining('125.00'), findsWidgets);
      expect(find.textContaining('6312.50'), findsOneWidget);
      expect(
        find.byKey(RechargeOrderNewScreen.typeKey('BANK_TRANSFER')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(RechargeOrderNewScreen.typeKey('BANK_TRANSFER')),
      );
      await tester.pumpAndSettle();
      await _capture(tester, 'app-01-new-order');
      await tester.tap(find.byKey(RechargeOrderNewScreen.submitKey));
      await tester.pumpAndSettle();
      expect(orders.created.single.coins, 10000000);
      expect(orders.created.single.type, 'BANK_TRANSFER');
      expect(orders.created.single.key, matches(RegExp(r'^[0-9a-f-]{36}$')));
      expect(find.byType(RechargeOrderScreen), findsOneWidget);
    });

    testWidgets('a typed amount under the minimum is refused (English)', (
      tester,
    ) async {
      final orders = _FakeOrders(_order(status: RechargeOrderStatus.requested));
      await _pump(
        tester,
        AppRoutes.rechargeOrderNewFor('coin0007', 'EG'),
        orders: orders,
        language: AppLanguage.en,
      );
      expect(find.text('New recharge order'), findsOneWidget);
      await tester.enterText(
        find.byKey(RechargeOrderNewScreen.coinsKey),
        '500',
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      final submit = tester.widget<FilledButton>(
        find.byKey(RechargeOrderNewScreen.submitKey),
      );
      expect(submit.onPressed, isNull);
      expect(
        Directionality.of(tester.element(find.byType(TextField))),
        TextDirection.ltr,
      );
    });
  });

  group('the buyer', () {
    testWidgets('the notice first, then «قمت بالإرسال» with the screenshot', (
      tester,
    ) async {
      final picker = _Picker();
      final orders = _FakeOrders(
        _order(
          status: RechargeOrderStatus.awaitingPayment,
          held: 10000000,
          actions: const {
            RechargeOrderAction.message,
            RechargeOrderAction.ackNotice,
            RechargeOrderAction.cancel,
          },
        ),
      );
      await _pump(
        tester,
        AppRoutes.rechargeOrder('o-1'),
        orders: orders,
        picker: picker,
      );
      expect(find.byKey(RechargeOrderScreen.noticeKey), findsOneWidget);
      expect(find.text(_ar.rechargeOrderNotice), findsOneWidget);
      expect(find.byKey(RechargeOrderScreen.sentKey), findsNothing);
      expect(find.byKey(RechargeOrderScreen.frozenKey), findsOneWidget);
      // The chat: system lines, the payment details card.
      expect(find.text(_ar.rechargeOrderEventDetails), findsOneWidget);
      expect(find.textContaining('فودافون كاش: 0100'), findsOneWidget);
      await _capture(tester, 'app-02-chat-details-notice');
      await tester.tap(find.byKey(RechargeOrderScreen.ackKey));
      await tester.pumpAndSettle();
      expect(orders.calls, ['ack']);
      expect(find.byKey(RechargeOrderScreen.noticeKey), findsNothing);
      await tester.tap(find.byKey(RechargeOrderScreen.sentKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_ar.rechargeOrderPickScreenshot));
      await tester.pumpAndSettle();
      expect(picker.asked, 1);
      // The sheet's button (the page's small one is under it).
      await tester.tap(
        find.widgetWithText(FilledButton, _ar.rechargeOrderSent).last,
      );
      await tester.pumpAndSettle();
      expect(orders.calls.last, 'paid:${_png.length}');
      // PAID: the 15-minute wait; «نزاع» shown but disabled.
      expect(find.byKey(RechargeOrderScreen.countdownKey), findsOneWidget);
      expect(find.textContaining(RegExp(r'1[45]:\d\d')), findsOneWidget);
      final dispute = tester.widget<OutlinedButton>(
        find.byKey(RechargeOrderScreen.disputeKey),
      );
      expect(dispute.onPressed, isNull);
    });

    testWidgets('after 15 minutes «نزاع» opens with a reason', (tester) async {
      final orders = _FakeOrders(
        _order(
          status: RechargeOrderStatus.paid,
          ack: true,
          held: 10000000,
          paidAt: clock.now(),
        ),
      );
      await _pump(tester, AppRoutes.rechargeOrder('o-1'), orders: orders);
      await tester.pump(const Duration(minutes: 3, seconds: 20));
      expect(find.textContaining(RegExp(r'11:[34]\d')), findsOneWidget);
      await _capture(tester, 'app-03-paid-countdown');
      // The server now allows the buyer's dispute.
      orders.order = _order(
        status: RechargeOrderStatus.paid,
        ack: true,
        held: 10000000,
        paidAt: clock.now().subtract(const Duration(minutes: 16)),
        actions: const {
          RechargeOrderAction.message,
          RechargeOrderAction.dispute,
        },
      );
      await tester.pump(const Duration(seconds: 7));
      await tester.pumpAndSettle();
      expect(find.text(_ar.rechargeOrderWaitOver), findsOneWidget);
      await tester.tap(find.byKey(RechargeOrderScreen.disputeKey));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'لم تصل العملات');
      await tester.tap(
        find.widgetWithText(FilledButton, _ar.rechargeOrderDispute),
      );
      await tester.pumpAndSettle();
      expect(orders.calls.last, 'dispute:لم تصل العملات');
      expect(find.text(_ar.rechargeOrderStatusDisputed), findsOneWidget);
    });

    testWidgets('writes in the chat; «الإدارة» has no name', (tester) async {
      final orders = _FakeOrders(
        _order(status: RechargeOrderStatus.disputed, held: 10000000),
        chat: [
          ..._chat,
          _m('m6', 'TRANSFER_PROOF', 'BUYER', author: _buyer, image: true),
          _m('m7', 'SYSTEM', 'SYSTEM', event: 'DISPUTED_BY_AGENT'),
          _m('m8', 'TEXT', 'ADMIN', text: 'نراجع الإثباتات الآن'),
        ],
      );
      await _pump(tester, AppRoutes.rechargeOrder('o-1'), orders: orders);
      expect(find.text(_ar.rechargeOrderRoleAdmin), findsOneWidget);
      expect(find.text('نراجع الإثباتات الآن'), findsOneWidget);
      expect(find.text(_ar.rechargeOrderProof), findsOneWidget);
      expect(find.byType(Image), findsWidgets);
      await tester.enterText(find.byType(TextField), 'هذا فيديو الشاشة');
      await tester.pump();
      await tester.tap(find.byKey(RechargeOrderScreen.sendKey));
      await tester.pumpAndSettle();
      expect(orders.texts, ['هذا فيديو الشاشة']);
    });
  });

  group('the agent', () {
    testWidgets('sends the payment details (the coins are frozen)', (
      tester,
    ) async {
      final orders = _FakeOrders(
        _order(
          status: RechargeOrderStatus.requested,
          role: 'AGENT',
          actions: const {
            RechargeOrderAction.message,
            RechargeOrderAction.sendDetails,
            RechargeOrderAction.cancel,
          },
        ),
        chat: [_chat.first],
      );
      await _pump(tester, AppRoutes.rechargeOrder('o-1'), orders: orders);
      await tester.tap(find.byKey(RechargeOrderScreen.detailsKey));
      await tester.pumpAndSettle();
      expect(
        find.text(
          _ar.rechargeOrderDetailsBody(KFormat.bidiIsolate('10,000,000')),
        ),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField).last, 'فودافون كاش 0100');
      await tester.pump();
      await tester.tap(
        find.widgetWithText(FilledButton, _ar.rechargeOrderSendDetails).last,
      );
      await tester.pumpAndSettle();
      expect(orders.details, ['فودافون كاش 0100']);
      expect(find.byKey(RechargeOrderScreen.frozenKey), findsOneWidget);
    });

    testWidgets('«استلمت» and «نزاع» after PAID; «استلمت» asks first', (
      tester,
    ) async {
      final orders = _FakeOrders(
        _order(
          status: RechargeOrderStatus.paid,
          role: 'AGENT',
          ack: true,
          held: 10000000,
          paidAt: clock.now(),
          actions: const {
            RechargeOrderAction.message,
            RechargeOrderAction.confirm,
            RechargeOrderAction.dispute,
          },
        ),
        chat: [
          ..._chat,
          _m('m6', 'TRANSFER_PROOF', 'BUYER', author: _buyer, image: true),
          _m('m7', 'SYSTEM', 'SYSTEM', event: 'PAID'),
        ],
      );
      await _pump(tester, AppRoutes.rechargeOrder('o-1'), orders: orders);
      expect(find.byKey(RechargeOrderScreen.receivedKey), findsOneWidget);
      expect(find.byKey(RechargeOrderScreen.disputeKey), findsOneWidget);
      expect(find.textContaining(RegExp(r'1[45]:\d\d')), findsOneWidget);
      await _capture(tester, 'app-04-agent-buttons');
      await tester.tap(find.byKey(RechargeOrderScreen.receivedKey));
      await tester.pumpAndSettle();
      expect(find.text(_ar.rechargeOrderReceivedTitle), findsOneWidget);
      await tester.tap(find.text(_ar.rechargeOrderKeep));
      await tester.pumpAndSettle();
      expect(orders.calls, isEmpty);
      await tester.tap(find.byKey(RechargeOrderScreen.receivedKey));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilledButton, _ar.rechargeOrderReceived).last,
      );
      await tester.pumpAndSettle();
      expect(orders.calls, ['confirm']);
      expect(find.text(_ar.rechargeOrderStatusCompleted), findsOneWidget);
    });
  });

  group('layout', () {
    for (final language in AppLanguage.values) {
      testWidgets('the order fits 360×800 at ×1.3 (${language.name}, dark)', (
        tester,
      ) async {
        final orders = _FakeOrders(
          _order(
            status: RechargeOrderStatus.paid,
            role: 'AGENT',
            ack: true,
            held: 10000000,
            paidAt: clock.now(),
            actions: const {
              RechargeOrderAction.message,
              RechargeOrderAction.confirm,
              RechargeOrderAction.dispute,
            },
          ),
        );
        await _pump(
          tester,
          AppRoutes.rechargeOrder('o-1'),
          orders: orders,
          language: language,
          viewport: GoldenViewport.android,
          textScale: 1.3,
          brightness: Brightness.dark,
        );
        expect(tester.takeException(), isNull);
        expect(
          Directionality.of(
            tester.element(find.byKey(RechargeOrderScreen.receivedKey)),
          ),
          language == AppLanguage.ar ? TextDirection.rtl : TextDirection.ltr,
        );
        expect(
          find.text(
            (language == AppLanguage.ar ? _ar : _en).rechargeOrderReceived,
          ),
          findsOneWidget,
        );
      });
    }

    testWidgets('the orders list (incoming)', (tester) async {
      final orders = _FakeOrders(
        _order(status: RechargeOrderStatus.paid, role: 'AGENT', held: 10),
      );
      await _pump(
        tester,
        '${AppRoutes.rechargeOrders}?incoming=1',
        orders: orders,
        recharge: FakeRechargeRepository(mine: fixtureActive()),
      );
      expect(find.byKey(RechargeOrdersScreen.rowKey('o-1')), findsOneWidget);
      expect(find.text(_ar.rechargeOrderStatusPaid), findsOneWidget);
      await tester.tap(find.byKey(RechargeOrdersScreen.rowKey('o-1')));
      await tester.pumpAndSettle();
      expect(find.byType(RechargeOrderScreen), findsOneWidget);
    });
  });

  group('notifications', () {
    test('the sentence of each event and the push route', () {
      expect(
        rechargeOrderNotificationText(_ar, 'CREATED', 10000000),
        contains('طلب شحن جديد'),
      );
      expect(
        rechargeOrderNotificationText(_en, 'COMPLETED_BY_ADMIN', 2000000),
        contains('2,000,000'),
      );
      expect(
        rechargeOrderNotificationText(_ar, 'ADMIN_MESSAGE', 1),
        _ar.notifRechargeOrderAdmin,
      );
      expect(
        rechargeOrderNotificationText(_en, 'SOMETHING_NEW', 1),
        _en.notifRechargeOrderMessage,
      );
      expect(
        const PushPayload({
          'kind': 'notification',
          'type': 'RECHARGE_ORDER_UPDATE',
          'targetType': 'RECHARGE_ORDER',
          'targetId': 'o-1',
        }).route(),
        AppRoutes.rechargeOrder('o-1'),
      );
    });
  });
}
