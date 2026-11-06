// D290 (owner, contract v1.89-social, CONVENTIONS §10.103): «طلب رفع ليفيل»
// in the app —
//  - the staff Me tab row (MODERATION / SUPPORT, not FINANCE / BD);
//  - «طلبات رفع الليفيل»: the staff member's own requests with the status,
//    the approved level and a rejection's reason; the empty state;
//  - the form: the username check (recharge, levels, eligibility; a Kabso
//    Team account and an open request refused), the app with its confidence
//    label («مؤكد» / «تقدير»), "other" with its name, the ID and level, the
//    video (uploaded as LEVEL_RAISE_VIDEO), sending only when complete, the
//    refusal's message;
//  - the three notifications (inbox text, tap and push routes).
// A fixed clock. The goldens are in test/goldens/level_raise_d290_golden_test.dart.

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/level_raise/data/level_raise_repository.dart';
import 'package:kabso_live/features/level_raise/presentation/level_raise_screens.dart';
import 'package:kabso_live/features/notifications/domain/notification_models.dart';
import 'package:kabso_live/features/notifications/presentation/notifications_screen.dart';
import 'package:kabso_live/features/posts/data/media_repository.dart';
import 'package:kabso_live/features/posts/data/video_source.dart';
import 'package:kabso_live/features/profile/me_hub_screen.dart';
import 'package:kabso_live/features/push/push_payload.dart';
import 'package:kabso_live/features/staff/domain/staff_identity.dart';
import 'package:kabso_live/l10n/gen/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_media_repository.dart';
import '../../helpers/pump_app.dart';
import '../staff/staff_d283_test.dart';

final DateTime d290Now = DateTime.utc(2027, 3, 24, 9);

LevelRaisePerson _person(String id, String name, String username) =>
    LevelRaisePerson(
      id: id,
      username: username,
      displayName: name,
      avatarUrl: null,
    );

/// The seeded apps (CONVENTIONS §10.103.6): Zafa CONFIRMED, the rest ESTIMATE.
List<LevelRaiseSourceApp> sourceAppsFixture() => const [
  LevelRaiseSourceApp(
    code: 'ZAFA',
    nameAr: 'زفة',
    nameEn: 'Zafa',
    confidence: LevelRaiseConfidence.confirmed,
    isOther: false,
  ),
  LevelRaiseSourceApp(
    code: 'BIGO_LIVE',
    nameAr: 'بيقو لايف',
    nameEn: 'Bigo Live',
    confidence: LevelRaiseConfidence.estimate,
    isOther: false,
  ),
  LevelRaiseSourceApp(
    code: 'OTHER',
    nameAr: 'تطبيق آخر',
    nameEn: 'Other app',
    confidence: LevelRaiseConfidence.estimate,
    isOther: true,
  ),
];

List<LevelRaiseRequest> requestsFixture({required bool ar}) => [
  LevelRaiseRequest(
    id: 'r1',
    status: LevelRaiseStatus.pending,
    supporter: _person('u1', ar ? 'أبو فهد' : 'Abu Fahad', 'abu.fahad'),
    sourceApp: sourceAppsFixture()[0],
    sourceAppName: 'Zafa',
    sourceAccountId: '88123456',
    sourceLevel: 32,
    createdAt: DateTime.utc(2027, 3, 24, 8),
  ),
  LevelRaiseRequest(
    id: 'r2',
    status: LevelRaiseStatus.approved,
    supporter: _person('u2', ar ? 'سلطان' : 'Sultan', 'sultan.k'),
    sourceApp: sourceAppsFixture()[1],
    sourceAppName: 'Bigo Live',
    sourceAccountId: '5544',
    sourceLevel: 41,
    createdAt: DateTime.utc(2027, 3, 22, 18),
    decidedAt: DateTime.utc(2027, 3, 23, 10),
    approvedLevel: 22,
    levelBefore: 8,
    levelAfter: 22,
  ),
  LevelRaiseRequest(
    id: 'r3',
    status: LevelRaiseStatus.rejected,
    supporter: _person('u3', ar ? 'نوف' : 'Nouf', 'nouf_x'),
    sourceApp: sourceAppsFixture()[2],
    sourceAppName: ar ? 'تطبيق صوتي' : 'A voice app',
    sourceAccountId: 'n-77',
    sourceLevel: 18,
    createdAt: DateTime.utc(2027, 3, 21, 12),
    decidedAt: DateTime.utc(2027, 3, 21, 15),
    rejectReason: ar
        ? 'الفيديو لا يُظهر الآيدي'
        : 'The video does not show the ID',
  ),
  LevelRaiseRequest(
    id: 'r4',
    status: LevelRaiseStatus.pending,
    supporter: _person('u4', ar ? 'نوف الثانية' : 'Nouf II', 'nouf_2'),
    sourceApp: sourceAppsFixture()[1],
    sourceAppName: 'Bigo Live',
    sourceAccountId: '5544',
    sourceLevel: 25,
    createdAt: DateTime.utc(2027, 3, 24, 7),
    previouslyRejected: true,
  ),
];

/// 409 LEVEL_RAISE_DUPLICATE as the API sends it.
const duplicateFailure = ServerFailure(
  code: ErrorCode.levelRaiseDuplicate,
  rawCode: 'LEVEL_RAISE_DUPLICATE',
  debugMessage: 'dup',
  details: [
    FieldIssue(field: 'status', issue: 'APPROVED'),
    FieldIssue(field: 'createdAt', issue: '2027-03-22T18:00:00.000Z'),
    FieldIssue(field: 'requestedBy', issue: 'Kabso Moderator'),
  ],
);

LevelRaiseCheck checkFixture({
  required bool ar,
  bool eligible = false,
  bool open = false,
}) => LevelRaiseCheck(
  found: true,
  supporter: _person('u9', ar ? 'أبو فهد' : 'Abu Fahad', 'abu.fahad'),
  evidence: LevelRaiseEvidence(
    totalRechargeCoins: eligible ? 1500000 : 400000,
    firstDaysRechargeCoins: eligible ? 1200000 : 400000,
    firstDays: 7,
    supportLevel: 6,
    charmLevel: 11,
    minRechargeCoins: 1000000,
    eligible: eligible,
  ),
  openRequest: open,
  staffAccount: false,
);

/// An in-memory [LevelRaiseRepository] (tests only).
class FakeLevelRaiseRepository implements LevelRaiseRepository {
  new({List<LevelRaiseRequest>? requests, this.checkResult, this.createError})
    : requests = requests ?? [];

  final List<LevelRaiseRequest> requests;
  LevelRaiseCheck? checkResult;
  Exception? createError;
  final List<String> checks = [];
  final List<LevelRaiseDraft> created = [];

  @override
  Future<List<LevelRaiseSourceApp>> sourceApps() async => sourceAppsFixture();

  /// D290: «هل تقصد: …؟» — Zafa for its spellings, an earlier name otherwise.
  final List<String> suggested = [];

  @override
  Future<List<LevelRaiseSuggestion>> suggest(String q) async {
    suggested.add(q);
    final k = q.toLowerCase().replaceAll(' ', '');
    if (k.contains('زف') || k.startsWith('zaf')) {
      return [LevelRaiseSuggestion(app: sourceAppsFixture()[0])];
    }
    if (k.startsWith('voice')) {
      return const [LevelRaiseSuggestion(name: 'Voice X')];
    }
    return const [];
  }

  @override
  Future<LevelRaiseCheck> check(String username) async {
    checks.add(username);
    return checkResult ??
        const LevelRaiseCheck(
          found: false,
          supporter: null,
          evidence: null,
          openRequest: false,
          staffAccount: false,
        );
  }

  @override
  Future<List<LevelRaiseRequest>> mine() async => requests;

  @override
  Future<LevelRaiseRequest> create(LevelRaiseDraft draft) async {
    if (createError case final e?) throw e;
    created.add(draft);
    return LevelRaiseRequest(
      id: 'new',
      status: LevelRaiseStatus.pending,
      supporter: _person('u9', 'x', draft.username),
      sourceApp: null,
      sourceAppName: draft.sourceAppName ?? draft.sourceApp,
      sourceAccountId: draft.sourceAccountId,
      sourceLevel: draft.sourceLevel,
      createdAt: d290Now,
    );
  }
}

/// The form inside a router (it pops `true` when sent).
Future<String?> pumpForm(
  WidgetTester tester, {
  required FakeLevelRaiseRepository repo,
  required FakeMediaRepository media,
  required FakeVideoPicker picker,
  AppLanguage language = AppLanguage.en,
}) async {
  String? popped;
  // A tall view: the whole form is built (a ListView builds what is visible).
  tester.view
    ..physicalSize = const Size(1200, 4200)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: '/start',
    routes: [
      GoRoute(
        path: '/start',
        builder: (context, _) => Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final r = await context.push<bool>(AppRoutes.staffLevelRaiseNew);
              popped = '$r';
            },
            child: const Text('open'),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.staffLevelRaiseNew,
        builder: (_, _) => const LevelRaiseFormScreen(),
      ),
    ],
  );
  await pumpScreen(
    tester,
    _RouterHost(router: router),
    language: language,
    overrides: [
      levelRaiseRepositoryProvider.overrideWithValue(repo),
      mediaRepositoryProvider.overrideWithValue(media),
      videoPickerProvider.overrideWithValue(picker),
    ],
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return popped;
}

class _RouterHost extends StatelessWidget {
  const new({required this.router});

  final GoRouter router;

  @override
  Widget build(BuildContext context) => Router(
    routerDelegate: router.routerDelegate,
    routeInformationParser: router.routeInformationParser,
    routeInformationProvider: router.routeInformationProvider,
  );
}

Future<void> _fill(
  WidgetTester tester, {
  String app = 'Zafa · Confirmed',
}) async {
  await tester.enterText(
    find.byKey(LevelRaiseFormScreen.usernameKey),
    '@abu.fahad',
  );
  await tester.pump();
  await tester.tap(find.byKey(LevelRaiseFormScreen.checkKey));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(LevelRaiseFormScreen.appKey));
  await tester.pumpAndSettle();
  await tester.tap(find.text(app).last);
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(LevelRaiseFormScreen.accountKey),
    '88123456',
  );
  await tester.enterText(find.byKey(LevelRaiseFormScreen.levelKey), '32');
  await tester.pumpAndSettle();
}

KButton _send(WidgetTester tester) =>
    tester.widget<KButton>(find.byKey(LevelRaiseFormScreen.sendKey));

void main() {
  group('D290 the staff Me tab', () {
    for (final (role, shown) in [
      (StaffLineRole.moderation, true),
      (StaffLineRole.support, true),
      (StaffLineRole.finance, false),
      (StaffLineRole.bd, false),
    ]) {
      testWidgets('${role.name}: the «طلب رفع ليفيل» row '
          '${shown ? 'shows' : 'is hidden'}', (tester) async {
        await pumpStaffHub(
          tester,
          language: AppLanguage.ar,
          staff: KabsoStaffIdentity(role: role),
        );
        expect(
          find.byKey(MeHubScreen.staffLevelRaiseKey),
          shown ? findsOneWidget : findsNothing,
        );
        if (shown) expect(find.text('طلب رفع ليفيل'), findsOneWidget);
      });
    }
  });

  group('D290 «طلبات رفع الليفيل»', () {
    testWidgets('lists the requests with status, approved level and reason', (
      tester,
    ) async {
      await withClock(Clock.fixed(d290Now), () async {
        await pumpScreen(
          tester,
          const StaffLevelRaisesScreen(),
          language: AppLanguage.ar,
          overrides: [
            levelRaiseRepositoryProvider.overrideWithValue(
              FakeLevelRaiseRepository(requests: requestsFixture(ar: true)),
            ),
          ],
        );
        await tester.pumpAndSettle();
      });
      expect(find.byKey(StaffLevelRaisesScreen.rowKey('r1')), findsOneWidget);
      // r1 and r4 (the flagged one) are pending.
      expect(find.text('قيد المراجعة'), findsNWidgets(2));
      expect(find.text('تمت الموافقة'), findsOneWidget);
      expect(find.textContaining('رُفع إلى المستوى'), findsOneWidget);
      expect(find.text('مرفوض'), findsOneWidget);
      expect(find.textContaining('الفيديو لا يُظهر الآيدي'), findsOneWidget);
      // "other" shows the typed name, a listed app its own name.
      expect(find.textContaining('تطبيق صوتي'), findsOneWidget);
      expect(find.textContaining('زفة'), findsOneWidget);
      expect(find.byKey(StaffLevelRaisesScreen.newKey), findsOneWidget);
    });

    testWidgets('the empty state', (tester) async {
      await pumpScreen(
        tester,
        const StaffLevelRaisesScreen(),
        overrides: [
          levelRaiseRepositoryProvider.overrideWithValue(
            FakeLevelRaiseRepository(),
          ),
        ],
      );
      await tester.pumpAndSettle();
      expect(find.text('You haven’t sent a request yet.'), findsOneWidget);
    });
  });

  group('D290 the form', () {
    testWidgets('the check shows the recharge, levels and eligibility', (
      tester,
    ) async {
      final repo = FakeLevelRaiseRepository(
        checkResult: checkFixture(ar: false),
      );
      await pumpForm(
        tester,
        repo: repo,
        media: FakeMediaRepository(),
        picker: FakeVideoPicker(),
      );
      await tester.enterText(
        find.byKey(LevelRaiseFormScreen.usernameKey),
        '@abu.fahad',
      );
      await tester.pump();
      await tester.tap(find.byKey(LevelRaiseFormScreen.checkKey));
      await tester.pumpAndSettle();
      expect(repo.checks, ['abu.fahad']);
      expect(find.byKey(LevelRaiseFormScreen.evidenceKey), findsOneWidget);
      expect(find.textContaining('Total recharge'), findsOneWidget);
      expect(find.textContaining('400,000'), findsNWidgets(2));
      expect(find.textContaining('First'), findsOneWidget);
      expect(find.textContaining('can’t be approved before'), findsOneWidget);
      expect(_send(tester).onPressed, isNull);
    });

    testWidgets('a Kabso Team account and an unknown name are refused', (
      tester,
    ) async {
      final repo = FakeLevelRaiseRepository(
        checkResult: const LevelRaiseCheck(
          found: true,
          supporter: null,
          evidence: null,
          openRequest: false,
          staffAccount: true,
        ),
      );
      await pumpForm(
        tester,
        repo: repo,
        media: FakeMediaRepository(),
        picker: FakeVideoPicker(),
      );
      await tester.enterText(
        find.byKey(LevelRaiseFormScreen.usernameKey),
        'mod',
      );
      await tester.pump();
      await tester.tap(find.byKey(LevelRaiseFormScreen.checkKey));
      await tester.pumpAndSettle();
      expect(
        find.text('A Kabso Team account: it has no levels'),
        findsOneWidget,
      );
      repo.checkResult = null;
      await tester.enterText(
        find.byKey(LevelRaiseFormScreen.usernameKey),
        'zz',
      );
      await tester.pump();
      await tester.tap(find.byKey(LevelRaiseFormScreen.checkKey));
      await tester.pumpAndSettle();
      expect(find.text('No account with this username'), findsOneWidget);
    });

    testWidgets('the apps carry their confidence labels', (tester) async {
      await pumpForm(
        tester,
        repo: FakeLevelRaiseRepository(),
        media: FakeMediaRepository(),
        picker: FakeVideoPicker(),
        language: AppLanguage.ar,
      );
      await tester.tap(find.byKey(LevelRaiseFormScreen.appKey));
      await tester.pumpAndSettle();
      expect(find.text('زفة · مؤكد'), findsWidgets);
      expect(find.text('بيقو لايف · تقدير'), findsWidgets);
      expect(find.text('تطبيق آخر · تقدير'), findsWidgets);
    });

    testWidgets('sends only when complete: the video as LEVEL_RAISE_VIDEO', (
      tester,
    ) async {
      final repo = FakeLevelRaiseRepository(
        checkResult: checkFixture(ar: false, eligible: true),
      );
      final media = FakeMediaRepository();
      final picker = FakeVideoPicker(testVideo(seconds: 25));
      await pumpForm(tester, repo: repo, media: media, picker: picker);
      await _fill(tester);
      expect(_send(tester).onPressed, isNull, reason: 'no video yet');
      await tester.ensureVisible(find.byKey(LevelRaiseFormScreen.videoKey));
      await tester.tap(find.byKey(LevelRaiseFormScreen.videoKey));
      await tester.pumpAndSettle();
      expect(picker.calls, [maxPostVideoLength]);
      expect(find.textContaining('25'), findsWidgets);
      await tester.enterText(find.byKey(LevelRaiseFormScreen.noteKey), 'vip');
      await tester.pumpAndSettle();
      expect(_send(tester).onPressed, isNotNull);
      await tester.ensureVisible(find.byKey(LevelRaiseFormScreen.sendKey));
      await tester.tap(find.byKey(LevelRaiseFormScreen.sendKey));
      await tester.pumpAndSettle();
      expect(media.videoUploads.single, startsWith('LEVEL_RAISE_VIDEO:'));
      final d = repo.created.single;
      expect(d.toJson(), {
        'username': 'abu.fahad',
        'sourceApp': 'ZAFA',
        'sourceAccountId': '88123456',
        'sourceLevel': 32,
        'videoId': 'v1',
        'note': 'vip',
      });
      // Back on the start page (popped with true).
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('"other" needs its name; it is sent with the request', (
      tester,
    ) async {
      final repo = FakeLevelRaiseRepository(
        checkResult: checkFixture(ar: false),
      );
      await pumpForm(
        tester,
        repo: repo,
        media: FakeMediaRepository(),
        picker: FakeVideoPicker(testVideo()),
      );
      await _fill(tester, app: 'Other app · Estimate');
      await tester.ensureVisible(find.byKey(LevelRaiseFormScreen.videoKey));
      await tester.tap(find.byKey(LevelRaiseFormScreen.videoKey));
      await tester.pumpAndSettle();
      expect(_send(tester).onPressed, isNull, reason: 'no app name yet');
      await tester.enterText(
        find.byKey(LevelRaiseFormScreen.otherNameKey),
        'Voice X',
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(LevelRaiseFormScreen.sendKey));
      await tester.tap(find.byKey(LevelRaiseFormScreen.sendKey));
      await tester.pumpAndSettle();
      expect(repo.created.single.sourceAppName, 'Voice X');
      expect(repo.created.single.sourceApp, 'OTHER');
    });

    testWidgets('a refusal (an open request) is worded and nothing pops', (
      tester,
    ) async {
      final repo = FakeLevelRaiseRepository(
        checkResult: checkFixture(ar: false),
        createError: const ServerFailure(
          code: ErrorCode.adminActionRefused,
          rawCode: 'ADMIN_ACTION_REFUSED',
          debugMessage: 'open',
          details: [
            FieldIssue(field: 'rule', issue: 'level_raise_open_exists'),
          ],
        ),
      );
      await pumpForm(
        tester,
        repo: repo,
        media: FakeMediaRepository(),
        picker: FakeVideoPicker(testVideo()),
      );
      await _fill(tester);
      await tester.ensureVisible(find.byKey(LevelRaiseFormScreen.videoKey));
      await tester.tap(find.byKey(LevelRaiseFormScreen.videoKey));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(LevelRaiseFormScreen.sendKey));
      await tester.tap(find.byKey(LevelRaiseFormScreen.sendKey));
      await tester.pumpAndSettle();
      expect(
        find.text('This supporter already has a pending request'),
        findsOneWidget,
      );
      expect(find.byType(LevelRaiseFormScreen), findsOneWidget);
    });
  });

  group('D290 notifications', () {
    AppNotification note(NotificationType type, {int? level, String? text}) =>
        AppNotification(
          id: 'n1',
          type: type,
          actors: const [],
          actorCount: 0,
          target: NotificationTarget(
            type: NotificationTargetType.levelRaise,
            id: 'r1',
            text: text,
            level: level,
          ),
          createdAt: d290Now,
          read: false,
        );

    test('the types and target parse; all are system types', () {
      final n = AppNotification.fromJson(const {
        'id': 'n1',
        'type': 'LEVEL_RAISE_APPROVED',
        'actors': <Object>[],
        'actorCount': 0,
        'target': {
          'type': 'LEVEL_RAISE',
          'id': 'r1',
          'postId': null,
          'thumbUrl': null,
          'text': 'abu.fahad',
          'level': 20,
        },
        'createdAt': '2027-03-24T09:00:00.000Z',
        'read': false,
      });
      expect(n.type, NotificationType.levelRaiseApproved);
      expect(n.target?.level, 20);
      expect(NotificationType.levelRaised.isSystem, isTrue);
      expect(NotificationType.levelRaiseRejected.isLevelRaise, isTrue);
    });

    test(
      'taps and pushes open the requests, or the levels for the supporter',
      () {
        expect(
          NotificationRow(
            item: note(NotificationType.levelRaiseApproved, level: 20),
          ).routeTo(),
          AppRoutes.staffLevelRaises,
        );
        expect(
          NotificationRow(item: note(NotificationType.levelRaised, level: 20))
              .routeTo(),
          AppRoutes.levels,
        );
        for (final (type, route) in [
          ('LEVEL_RAISED', AppRoutes.levels),
          ('LEVEL_RAISE_APPROVED', AppRoutes.staffLevelRaises),
          ('LEVEL_RAISE_REJECTED', AppRoutes.staffLevelRaises),
        ]) {
          expect(
            PushPayload({
              'kind': 'notification',
              'type': type,
              'targetType': 'LEVEL_RAISE',
              'targetId': 'r1',
            }).route(),
            route,
          );
        }
      },
    );

    testWidgets('the inbox words each one', (tester) async {
      await pumpScreen(
        tester,
        Column(
          children: [
            NotificationRow(
              item: note(
                NotificationType.levelRaiseApproved,
                level: 20,
                text: 'abu.fahad',
              ),
            ),
            NotificationRow(
              item: note(NotificationType.levelRaiseRejected, text: 'nouf_x'),
            ),
            NotificationRow(
              item: note(NotificationType.levelRaised, level: 20),
            ),
          ],
        ),
        language: AppLanguage.ar,
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('تمت الموافقة على طلب رفع ليفيل'),
        findsOneWidget,
      );
      expect(
        find.textContaining('لم تتم الموافقة على طلب رفع ليفيل'),
        findsOneWidget,
      );
      expect(
        find.textContaining('تم رفع ليفيل الدعم الخاص بك'),
        findsOneWidget,
      );
    });
  });

  group('D290 follow-up: «هل تقصد», duplicates, the earlier rejection', () {
    testWidgets('an "other" name suggests the listed app; a tap selects it', (
      tester,
    ) async {
      final repo = FakeLevelRaiseRepository(
        checkResult: checkFixture(ar: true),
      );
      await pumpForm(
        tester,
        repo: repo,
        media: FakeMediaRepository(),
        picker: FakeVideoPicker(testVideo()),
        language: AppLanguage.ar,
      );
      await tester.tap(find.byKey(LevelRaiseFormScreen.appKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تطبيق آخر · تقدير').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(LevelRaiseFormScreen.otherNameKey),
        'زفه',
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(repo.suggested, ['زفه']);
      expect(find.text('هل تقصد: زفة؟ · مؤكد'), findsOneWidget);
      await tester.tap(find.byKey(LevelRaiseFormScreen.suggestionKey('ZAFA')));
      await tester.pumpAndSettle();
      // Zafa is now the app; the "other" name field is gone.
      expect(find.byKey(LevelRaiseFormScreen.otherNameKey), findsNothing);
      expect(find.text('زفة · مؤكد'), findsOneWidget);
    });

    testWidgets('an earlier typed name is offered with its first spelling', (
      tester,
    ) async {
      await pumpForm(
        tester,
        repo: FakeLevelRaiseRepository(),
        media: FakeMediaRepository(),
        picker: FakeVideoPicker(),
      );
      await tester.tap(find.byKey(LevelRaiseFormScreen.appKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Other app · Estimate').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(LevelRaiseFormScreen.otherNameKey),
        'voice  x',
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Did you mean: Voice X?'));
      await tester.pumpAndSettle();
      final field = tester.widget<TextFormField>(
        find.byKey(LevelRaiseFormScreen.otherNameKey),
      );
      expect(field.controller!.text, 'Voice X');
      expect(find.text('Did you mean: Voice X?'), findsNothing);
    });

    test('the duplicate refusal says the status, the date and the sender', () {
      final en = lookupAppLocalizations(const Locale('en'));
      final ar = lookupAppLocalizations(const Locale('ar'));
      final text = levelRaiseFailure(en, duplicateFailure);
      expect(text, contains('already has a request (Approved)'));
      expect(text, contains('Kabso Moderator'));
      expect(text, contains('2027'));
      expect(
        levelRaiseFailure(ar, duplicateFailure, localeTag: 'ar'),
        contains('(تمت الموافقة)'),
      );
    });

    testWidgets('a duplicate on send is shown on the form; nothing pops', (
      tester,
    ) async {
      final repo = FakeLevelRaiseRepository(
        checkResult: checkFixture(ar: false),
        createError: duplicateFailure,
      );
      await pumpForm(
        tester,
        repo: repo,
        media: FakeMediaRepository(),
        picker: FakeVideoPicker(testVideo()),
      );
      await _fill(tester);
      await tester.tap(find.byKey(LevelRaiseFormScreen.videoKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(LevelRaiseFormScreen.sendKey));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('already has a request (Approved)'),
        findsOneWidget,
      );
      expect(find.byType(LevelRaiseFormScreen), findsOneWidget);
    });

    testWidgets('the list flags a request whose account was rejected before', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        const StaffLevelRaisesScreen(),
        language: AppLanguage.ar,
        overrides: [
          levelRaiseRepositoryProvider.overrideWithValue(
            FakeLevelRaiseRepository(requests: requestsFixture(ar: true)),
          ),
        ],
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(StaffLevelRaisesScreen.rowKey('r4')),
        200,
      );
      expect(find.text('سبق رفض طلب بنفس الحساب'), findsOneWidget);
    });

    test('a request parses the deleted video and the earlier rejection', () {
      final r = LevelRaiseRequest.fromJson(const {
        'id': 'x',
        'status': 'REJECTED',
        'supporter': {'id': 'u', 'username': 'a', 'displayName': 'A'},
        'sourceApp': null,
        'sourceAppName': 'Zafa',
        'sourceAccountId': '1',
        'sourceLevel': 3,
        'createdAt': '2027-03-24T09:00:00.000Z',
        'video': {'id': 'v', 'deletedAt': '2027-03-24T10:00:00.000Z'},
        'previousRejection': {'id': 'old'},
      });
      expect(r.videoDeletedAt, DateTime.utc(2027, 3, 24, 10));
      expect(r.previouslyRejected, isTrue);
    });
  });
}
