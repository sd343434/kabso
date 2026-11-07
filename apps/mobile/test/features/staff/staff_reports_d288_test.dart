// v1.78-live (D288, CONVENTIONS §10.101; owner: «ان البلاغ يصل كل المشرفين
// والدعم والذي يقوم بحله يضغط تم حله»): «بلاغات» in the staff Me tab
// (MODERATION / SUPPORT only) with the unresolved count at the row's end
// (hidden at 0, «99+», RTL and LTR), the shared queue screen («غير محلولة» /
// «تم حلها», «تم حله» with an optional note, who resolved it, the second
// press), and the STAFF_REPORT_NEW notification's tap.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/notifications/domain/notification_models.dart';
import 'package:kabso_live/features/profile/me_hub_screen.dart';
import 'package:kabso_live/features/push/push_payload.dart';
import 'package:kabso_live/features/staff/data/staff_repository.dart';
import 'package:kabso_live/features/staff/domain/staff_identity.dart';
import 'package:kabso_live/features/staff/domain/staff_models.dart';
import 'package:kabso_live/features/staff/presentation/staff_reports_screen.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/golden.dart';
import 'staff_d273_test.dart' show FakeStaffRepository;
import 'staff_d283_test.dart';

const supportStatus = StaffStatus(
  isStaff: true,
  roles: ['SUPPORT'],
  capabilities: [
    'reports.view',
    'reports.resolve',
    'lives.watch',
    'lives.reports',
  ],
  authenticatorEnrolled: true,
  onShift: false,
);

final openReport = SharedReport.fromJson(const {
  'id': 'rep-open-1',
  'targetType': 'POST',
  'targetId': 'post-1',
  'reason': 'SPAM',
  'note': 'روابط مزعجة متكررة',
  'status': 'OPEN',
  'createdAt': '2026-11-06T09:30:00.000Z',
  'resolvedAt': null,
  'resolvedBy': null,
  'resolutionNote': null,
  'reporter': {'id': 'u1', 'username': 'reader01', 'displayName': 'قارئ'},
  'preview': {
    'text': 'اربح الآن! اضغط على الرابط',
    'mediaUrl': null,
    'author': {
      'id': 'a1',
      'username': 'spammer01',
      'displayName': 'حساب مزعج',
      'status': 'ACTIVE',
    },
    'gone': false,
  },
});

final resolvedReport = SharedReport.fromJson(const {
  'id': 'rep-done-1',
  'targetType': 'USER',
  'targetId': 'user-9',
  'reason': 'HARASSMENT',
  'note': null,
  'status': 'ACTIONED',
  'createdAt': '2026-11-06T08:00:00.000Z',
  'resolvedAt': '2026-11-06T10:15:00.000Z',
  'resolvedBy': {'id': 's1', 'username': 'support01', 'displayName': 'سارة'},
  'resolutionNote': 'تواصلت مع الطرفين',
  'reporter': {'id': 'u2', 'username': 'viewer02', 'displayName': 'مشاهد'},
  'preview': {
    'text': null,
    'mediaUrl': null,
    'author': {
      'id': 'u9',
      'username': 'rude09',
      'displayName': 'Rude',
      'status': 'ACTIVE',
    },
    'gone': false,
  },
});

/// D288: the shared queue's fake: a page per tab, records «تم حله».
class FakeReportsRepository extends FakeStaffRepository {
  new({this.alreadyResolved = false}) : super(supportStatus);

  final bool alreadyResolved;
  final resolved = <String, String?>{};
  int listReads = 0;

  @override
  Future<SharedReportPage> sharedReports(
    SharedReportTab tab, {
    String? cursor,
  }) async {
    listReads += 1;
    return SharedReportPage(
      items: tab == SharedReportTab.open ? [openReport] : [resolvedReport],
    );
  }

  @override
  Future<int> openReportsCount() async => 1;

  @override
  Future<SharedReport> resolveReport(String reportId, {String? note}) async {
    if (alreadyResolved) {
      throw const ServerFailure(
        code: ErrorCode.reportAlreadyResolved,
        rawCode: 'REPORT_ALREADY_RESOLVED',
        statusCode: 409,
        debugMessage: 'The report was already resolved.',
      );
    }
    resolved[reportId] = note;
    return resolvedReport;
  }
}

Future<void> pumpReportsScreen(
  WidgetTester tester, {
  required AppLanguage language,
  required StaffRepository repo,
  String? focus,
}) async {
  await loadAppFonts();
  setViewport(tester, GoldenViewport.phone);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [staffRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
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
        home: StaffReportsScreen(focusReportId: focus),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('the «بلاغات» row in the staff Me tab', () {
    testWidgets('MODERATION: the row with no badge at 0', (tester) async {
      await pumpStaffHub(tester, language: AppLanguage.ar);
      expect(find.byKey(MeHubScreen.staffReportsKey), findsOneWidget);
      expect(find.text('بلاغات'), findsOneWidget);
      expect(find.byKey(StaffReportsCountBadge.badgeKey), findsNothing);
    });

    testWidgets("the count at the row's end: 7", (tester) async {
      await pumpStaffHub(tester, language: AppLanguage.ar, openReports: 7);
      expect(
        find.descendant(
          of: find.byKey(StaffReportsCountBadge.badgeKey),
          matching: find.text('7'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('«99+» above 99', (tester) async {
      await pumpStaffHub(tester, language: AppLanguage.en, openReports: 150);
      expect(
        find.descendant(
          of: find.byKey(StaffReportsCountBadge.badgeKey),
          matching: find.text('99+'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('RTL: the badge is left of the title', (tester) async {
      await pumpStaffHub(tester, language: AppLanguage.ar, openReports: 3);
      final title = tester.getCenter(find.text('بلاغات'));
      final badge = tester.getCenter(
        find.byKey(StaffReportsCountBadge.badgeKey),
      );
      expect(badge.dx, lessThan(title.dx));
    });

    testWidgets('LTR: the badge is right of the title', (tester) async {
      await pumpStaffHub(tester, language: AppLanguage.en, openReports: 3);
      final title = tester.getCenter(find.text('Reports'));
      final badge = tester.getCenter(
        find.byKey(StaffReportsCountBadge.badgeKey),
      );
      expect(badge.dx, greaterThan(title.dx));
    });

    testWidgets('SUPPORT has the row', (tester) async {
      await pumpStaffHub(
        tester,
        language: AppLanguage.en,
        staff: europeSupport,
        openReports: 2,
      );
      expect(find.byKey(MeHubScreen.staffReportsKey), findsOneWidget);
    });

    for (final role in [StaffLineRole.finance, StaffLineRole.bd]) {
      testWidgets('${role.wire} has no row', (tester) async {
        await pumpStaffHub(
          tester,
          language: AppLanguage.en,
          staff: KabsoStaffIdentity(role: role),
          openReports: 2,
        );
        expect(find.byKey(MeHubScreen.staffReportsKey), findsNothing);
      });
    }

    testWidgets('a tap opens «بلاغات»', (tester) async {
      await pumpStaffHub(tester, language: AppLanguage.ar, openReports: 1);
      await tester.ensureVisible(find.byKey(MeHubScreen.staffReportsKey));
      await tester.tap(find.byKey(MeHubScreen.staffReportsKey));
      await tester.pumpAndSettle();
      expect(find.text('page ${AppRoutes.staffReports}'), findsOneWidget);
    });

    test('the badge text: hidden at 0, the number, «99+»', () {
      expect(StaffReportsCountBadge.text(0), isNull);
      expect(StaffReportsCountBadge.text(-3), isNull);
      expect(StaffReportsCountBadge.text(1), '1');
      expect(StaffReportsCountBadge.text(99), '99');
      expect(StaffReportsCountBadge.text(100), '99+');
    });
  });

  group('«بلاغات» — the shared queue', () {
    testWidgets('unresolved: the details and «تم حله» with a note', (
      tester,
    ) async {
      final repo = FakeReportsRepository();
      await pumpReportsScreen(tester, language: AppLanguage.ar, repo: repo);
      expect(find.text('غير محلولة'), findsOneWidget);
      expect(find.text('اربح الآن! اضغط على الرابط'), findsOneWidget);
      expect(find.text('منشور'), findsOneWidget);
      expect(find.text('رسائل مزعجة'), findsOneWidget);
      await tester.tap(find.byKey(StaffReportsScreen.resolve('rep-open-1')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(SharedReportResolveDialog.noteKey),
        'حُذف المنشور',
      );
      await tester.tap(find.byKey(SharedReportResolveDialog.applyKey));
      await tester.pumpAndSettle();
      expect(repo.resolved, {'rep-open-1': 'حُذف المنشور'});
      expect(find.text('تم حل البلاغ'), findsOneWidget);
    });

    testWidgets('the note is optional', (tester) async {
      final repo = FakeReportsRepository();
      await pumpReportsScreen(tester, language: AppLanguage.en, repo: repo);
      await tester.tap(find.byKey(StaffReportsScreen.resolve('rep-open-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(SharedReportResolveDialog.applyKey));
      await tester.pumpAndSettle();
      expect(repo.resolved, {'rep-open-1': ''});
    });

    testWidgets('a second press: «تم حله بالفعل» and the list reads again', (
      tester,
    ) async {
      final repo = FakeReportsRepository(alreadyResolved: true);
      await pumpReportsScreen(tester, language: AppLanguage.ar, repo: repo);
      final before = repo.listReads;
      await tester.tap(find.byKey(StaffReportsScreen.resolve('rep-open-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(SharedReportResolveDialog.applyKey));
      await tester.pumpAndSettle();
      expect(find.text('تم حله بالفعل من عضو آخر في الفريق'), findsOneWidget);
      expect(repo.listReads, greaterThan(before));
    });

    testWidgets('resolved: who resolved it, when and the note; no button', (
      tester,
    ) async {
      final repo = FakeReportsRepository();
      await pumpReportsScreen(tester, language: AppLanguage.ar, repo: repo);
      await tester.tap(find.text('تم حلها'));
      await tester.pumpAndSettle();
      expect(find.textContaining('حلّه'), findsOneWidget);
      expect(find.textContaining('سارة'), findsOneWidget);
      expect(find.textContaining('تواصلت مع الطرفين'), findsOneWidget);
      expect(
        find.byKey(StaffReportsScreen.resolve('rep-done-1')),
        findsNothing,
      );
    });

    testWidgets('a role without reports.resolve sees no «تم حله»', (
      tester,
    ) async {
      final repo = FakeReportsRepository()
        ..state = const StaffStatus(
          isStaff: true,
          roles: ['MODERATION'],
          capabilities: ['reports.view'],
          authenticatorEnrolled: true,
          onShift: false,
        );
      await pumpReportsScreen(tester, language: AppLanguage.en, repo: repo);
      expect(
        find.byKey(StaffReportsScreen.resolve('rep-open-1')),
        findsNothing,
      );
    });
  });

  group('STAFF_REPORT_NEW', () {
    test('the model, the inbox tap and the push tap open «بلاغات» on it', () {
      expect(
        NotificationType.fromWire('STAFF_REPORT_NEW'),
        NotificationType.staffReportNew,
      );
      expect(NotificationType.staffReportNew.isSystem, isTrue);
      expect(
        NotificationTargetType.fromWire('REPORT'),
        NotificationTargetType.report,
      );
      const push = PushPayload({
        'kind': 'notification',
        'channel': 'staff',
        'type': 'STAFF_REPORT_NEW',
        'targetType': 'REPORT',
        'targetId': 'rep-open-1',
      });
      expect(push.isStaffReport, isTrue);
      // v1.93-social (D296): the tap opens the report itself (its content and
      // actions), no longer the list.
      expect(push.route(), AppRoutes.staffReport('rep-open-1'));
      expect(push.route(), '/me/staff/reports/rep-open-1');
    });
  });
}
