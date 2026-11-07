// v1.93-social (D296, CONVENTIONS §10.109; owner: «يجب عند الضغط عليه الدخول
// إلى البوست، ويكون له أزرار صلاحية للتحذير والحظر ومنع النشر … عندما يضغط على
// البلاغ يدخل إلى الشات المبلغ عنه ويكون عنده إجراء»): a report of «بلاغات»
// opens its content for the staff — a post with the «محتوى مُبلّغ عنه» banner
// and its state, a DM as a read-only view of the report's snapshot, the
// deleted content with what the report kept — with the action bar (only the
// actions the server allows the role), the confirmation dialogs and the
// automatic resolution.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/notifications/domain/notification_models.dart';
import 'package:kabso_live/features/staff/data/staff_repository.dart';
import 'package:kabso_live/features/staff/domain/staff_models.dart';
import 'package:kabso_live/features/staff/domain/staff_report_view.dart';
import 'package:kabso_live/features/staff/presentation/staff_report_detail_screen.dart';
import 'package:kabso_live/features/staff/presentation/staff_reports_screen.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/golden.dart';
import 'staff_reports_d288_test.dart'
    show FakeReportsRepository, openReport, resolvedReport;

const Map<String, String?> _author = {
  'id': 'a1',
  'username': 'spammer01',
  'displayName': 'حساب مزعج',
  'avatarUrl': null,
};

Map<String, dynamic> _report(
  String id,
  String type, {
  String reason = 'SPAM',
}) => {
  'id': id,
  'targetType': type,
  'targetId': 'target-$id',
  'reason': reason,
  'note': 'روابط مزعجة متكررة',
  'status': 'OPEN',
  'createdAt': '2026-11-06T09:30:00.000Z',
  'resolvedAt': null,
  'resolvedBy': null,
  'resolutionNote': null,
  'resolutionAction': null,
  'reporter': {'id': 'u1', 'username': 'reader01', 'displayName': 'قارئ'},
  'preview': {
    'text': 'اربح الآن! اضغط على الرابط',
    'mediaUrl': null,
    'author': {..._author, 'status': 'ACTIVE'},
    'gone': false,
  },
};

const _allActions = [
  'WARN',
  'RESTRICT',
  'SUSPEND',
  'BAN',
  'REMOVE_CONTENT',
  'DELETE_CONTENT',
  'DELETE_ACCOUNT',
];

Map<String, dynamic> _threadMessage(
  String id,
  String sender,
  bool fromReported,
  String text,
  String at, {
  bool reported = false,
}) => {
  'id': id,
  'sender': sender,
  'fromReported': fromReported,
  'kind': 'TEXT',
  'text': text,
  'token': null,
  'sentAt': '2026-11-05T$at:00.000Z',
  'mediaUrl': null,
  'mediaMissing': false,
  'giftCode': null,
  'quantity': null,
  'reported': reported,
};

/// A hidden post opened by an OWNER (every action; a moderator has all but
/// DELETE_ACCOUNT — the server lists them).
final postView = StaffReportView.fromJson({
  'report': _report('rep-post', 'POST'),
  'target': const {
    'type': 'POST',
    'state': 'HIDDEN',
    'author': _author,
    'post': {
      'id': 'post-1',
      'format': 'POST',
      'author': _author,
      'text': 'اربح الآن! اضغط على الرابط واحصل على ١٠٠٠ كوينز مجاناً',
      'media': <Object>[],
      'location': null,
      'hashtags': <Object>[],
      'mentions': <Object>[],
      'status': 'PUBLISHED',
      'createdAt': '2026-11-06T08:10:00.000Z',
      'pinned': false,
      'likeCount': 3,
      'commentCount': 0,
      'shareCount': 0,
      'repostCount': 0,
      'viewCount': 40,
      'viewerHasLiked': false,
      'viewerHasSaved': false,
      'viewerHasReposted': false,
      'isSelf': false,
      'settings': {
        'commentsEnabled': true,
        'whoCanComment': 'EVERYONE',
        'hideLikeCount': false,
      },
    },
  },
  'actions': _allActions,
  'restrictions': const ['NO_POSTING', 'NO_LIVE', 'CHAT_MUTE'],
  'canResolve': true,
});

/// A reported DM opened by SUPPORT: the snapshot only, and the temporary lock.
final dmView = StaffReportView.fromJson({
  'report': _report('rep-dm', 'DM_MESSAGE', reason: 'HARASSMENT'),
  'target': const {
    'type': 'DM_MESSAGE',
    'state': 'EXPIRED',
    'author': _author,
    'dm': {
      'snapshot': {
        'kind': 'TEXT',
        'text': 'إذا لم ترد سأنشر صورك',
        'token': null,
        'sender': 'spammer01',
        'sentAt': '2026-11-05T21:04:00.000Z',
        'mediaUrl': null,
        'giftCode': null,
        'quantity': null,
        'purged': false,
      },
      'recipient': {
        'id': 'u1',
        'username': 'reader01',
        'displayName': 'قارئ',
        'avatarUrl': null,
      },
      // D296 follow-up (owner): the report arrives closed — a summary only.
      'threadSummary': {
        'messages': 5,
        'total': 5,
        'truncated': false,
        'capturedAt': '2026-11-06T09:30:00.000Z',
      },
    },
  },
  'actions': const ['SUSPEND'],
  'restrictions': const <Object>[],
  'canResolve': true,
});

/// D296 (owner): the whole conversation as the report froze it — what the
/// closed card opens (`getStaffReportDmThread`).
final dmThreadView = StaffDmThreadView.fromJson({
  'reportId': 'rep-dm',
  'reported': _author,
  'recipient': const {
    'id': 'u1',
    'username': 'reader01',
    'displayName': 'قارئ',
    'avatarUrl': null,
  },
  'snapshot': null,
  'thread': {
    'capturedAt': '2026-11-06T09:30:00.000Z',
    'total': 5,
    'truncated': false,
    'messages': [
      _threadMessage('m1', 'reader01', false, 'مرحباً، من أنت؟', '20:40'),
      _threadMessage('m2', 'spammer01', true, 'أرسل لي صورك', '20:45'),
      _threadMessage('m3', 'reader01', false, 'لا، توقف من فضلك', '20:50'),
      _threadMessage(
        'm4',
        'spammer01',
        true,
        'إذا لم ترد سأنشر صورك',
        '21:04',
        reported: true,
      ),
      _threadMessage('m5', 'reader01', false, 'سأبلغ عنك', '21:06'),
    ],
  },
});

/// A comment deleted by its author: «المحتوى محذوف» with what the report kept.
final goneView = StaffReportView.fromJson({
  'report': _report('rep-gone', 'COMMENT'),
  'target': const {'type': 'COMMENT', 'state': 'GONE', 'author': null},
  'actions': _allActions,
  'restrictions': const ['NO_POSTING', 'NO_LIVE', 'CHAT_MUTE'],
  'canResolve': true,
});

/// The views by report id; records the actions.
class FakeReportViewRepository extends FakeReportsRepository {
  new({
    Map<String, StaffReportView>? views,
    Map<String, StaffDmThreadView>? threads,
    this.alreadyActed = false,
  }) : views = views ?? {'rep-post': postView, 'rep-dm': dmView},
       threads = threads ?? {'rep-dm': dmThreadView};

  final Map<String, StaffDmThreadView> threads;

  /// D296 follow-up: the conversations actually opened (the audited call).
  final threadOpens = <String>[];

  @override
  Future<StaffDmThreadView> dmThread(String reportId) async {
    threadOpens.add(reportId);
    return threads[reportId]!;
  }

  final Map<String, StaffReportView> views;
  final bool alreadyActed;
  final acts = <String>[];

  @override
  Future<SharedReportPage> sharedReports(
    SharedReportTab tab, {
    String? cursor,
  }) async => SharedReportPage(
    items: tab == SharedReportTab.open
        ? [for (final v in views.values) v.report]
        : [resolvedReport],
  );

  @override
  Future<StaffReportView> report(String reportId) async => views[reportId]!;

  @override
  Future<SharedReport> actOnReport(
    String reportId,
    StaffReportAction action, {
    required String reason,
    StaffRestriction? restriction,
    int? days,
  }) async {
    if (alreadyActed) {
      throw const ServerFailure(
        code: ErrorCode.reportAlreadyResolved,
        rawCode: 'REPORT_ALREADY_RESOLVED',
        statusCode: 409,
        debugMessage: 'The report was already resolved.',
      );
    }
    acts.add(
      [
        reportId,
        action.wire,
        ?restriction?.wire,
        ?days?.toString(),
        reason,
      ].join(':'),
    );
    return openReport;
  }
}

/// «بلاغات» and the report route, as the app's router has them.
Future<void> pumpReportRoutes(
  WidgetTester tester, {
  required AppLanguage language,
  required StaffRepository repo,
  String initial = AppRoutes.staffReports,
}) async {
  await loadAppFonts();
  setViewport(tester, GoldenViewport.phone);
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(
        path: AppRoutes.staffReports,
        builder: (_, _) => const StaffReportsScreen(),
      ),
      GoRoute(
        path: AppRoutes.staffReportPattern,
        builder: (_, state) => StaffReportDetailScreen(
          reportId: state.pathParameters['reportId']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.staffReportChatPattern,
        builder: (_, state) =>
            StaffReportChatScreen(reportId: state.pathParameters['reportId']!),
      ),
      GoRoute(
        path: AppRoutes.userProfilePattern,
        builder: (_, state) =>
            Scaffold(body: Text('profile ${state.pathParameters['username']}')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [staffRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp.router(
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
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _action(StaffReportAction a) =>
    find.byKey(StaffReportDetailScreen.action(a));

void main() {
  group('a report opens its content', () {
    testWidgets('a tap in «بلاغات» opens the reported post with the banner', (
      tester,
    ) async {
      final repo = FakeReportViewRepository();
      await pumpReportRoutes(tester, language: AppLanguage.ar, repo: repo);
      await tester.tap(find.byKey(StaffReportsScreen.card('rep-post')));
      await tester.pumpAndSettle();
      expect(find.byType(StaffReportDetailScreen), findsOneWidget);
      expect(find.byKey(StaffReportDetailScreen.bannerKey), findsOneWidget);
      expect(find.text('محتوى مُبلّغ عنه'), findsOneWidget);
      // Hidden by moderation: the staff still see it, and the state says so.
      expect(find.text('مخفي بالإشراف'), findsOneWidget);
      expect(find.byKey(StaffReportDetailScreen.postViewKey), findsOneWidget);
      expect(find.textContaining('احصل على ١٠٠٠ كوينز مجاناً'), findsOneWidget);
    });

    testWidgets('the «فتح» button opens it too', (tester) async {
      await pumpReportRoutes(
        tester,
        language: AppLanguage.en,
        repo: FakeReportViewRepository(),
      );
      await tester.tap(find.byKey(StaffReportsScreen.open('rep-dm')));
      await tester.pumpAndSettle();
      expect(find.byKey(StaffReportDetailScreen.dmViewKey), findsOneWidget);
    });

    testWidgets('a DM arrives closed: the card, no conversation, nothing '
        'opened', (tester) async {
      final repo = FakeReportViewRepository();
      await pumpReportRoutes(
        tester,
        language: AppLanguage.ar,
        repo: repo,
        initial: AppRoutes.staffReport('rep-dm'),
      );
      expect(find.byKey(StaffReportDetailScreen.dmViewKey), findsOneWidget);
      expect(find.byKey(StaffReportDetailScreen.openThreadKey), findsOneWidget);
      expect(find.text('المحادثة كاملة — للقراءة فقط'), findsOneWidget);
      expect(find.text('اضغط لفتح المحادثة'), findsOneWidget);
      expect(find.text('الرسائل المحفوظة: 5'), findsOneWidget);
      expect(find.textContaining('@spammer01'), findsWidgets);
      expect(find.textContaining('@reader01'), findsWidgets);
      // Closed: no message of the conversation, and it was not read.
      expect(find.byKey(StaffReportDetailScreen.threadKey), findsNothing);
      for (final text in ['مرحباً، من أنت؟', 'أرسل لي صورك', 'سأبلغ عنك']) {
        expect(find.text(text), findsNothing, reason: text);
      }
      expect(repo.threadOpens, isEmpty);
      // The report card and the action bar are still there.
      expect(find.byKey(StaffReportDetailScreen.actionBarKey), findsOneWidget);
    });

    testWidgets('a tap opens the whole conversation full screen, read only, '
        'the reported one outlined', (tester) async {
      final repo = FakeReportViewRepository();
      await pumpReportRoutes(
        tester,
        language: AppLanguage.ar,
        repo: repo,
        initial: AppRoutes.staffReport('rep-dm'),
      );
      await tester.tap(find.byKey(StaffReportDetailScreen.openThreadKey));
      await tester.pumpAndSettle();
      expect(find.byType(StaffReportChatScreen), findsOneWidget);
      expect(repo.threadOpens, ['rep-dm']);
      expect(find.byKey(StaffReportDetailScreen.threadKey), findsOneWidget);
      for (final text in [
        'مرحباً، من أنت؟',
        'أرسل لي صورك',
        'لا، توقف من فضلك',
        'إذا لم ترد سأنشر صورك',
        'سأبلغ عنك',
      ]) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
      // The reported message is outlined and labelled, once.
      expect(
        find.descendant(
          of: find.byKey(StaffReportDetailScreen.reportedMessageKey),
          matching: find.text('إذا لم ترد سأنشر صورك'),
        ),
        findsOneWidget,
      );
      expect(find.text('الرسالة المُبلّغ عنها'), findsOneWidget);
      expect(find.textContaining('ولا تُضاف رسائل لاحقة'), findsOneWidget);
      // The reported person at the start, the reporter at the end (RTL: the
      // start is on the right).
      final reportedX = tester.getCenter(find.text('أرسل لي صورك')).dx;
      final reporterX = tester.getCenter(find.text('سأبلغ عنك')).dx;
      expect(reportedX, greaterThan(reporterX));
      // No composer: nothing to type into; back returns to the report.
      expect(find.byType(TextField), findsNothing);
      GoRouter.of(tester.element(find.byType(StaffReportChatScreen))).pop();
      await tester.pumpAndSettle();
      expect(find.byType(StaffReportDetailScreen), findsOneWidget);
    });

    testWidgets('an older DM report without a thread: the one message', (
      tester,
    ) async {
      final old = StaffReportView.fromJson({
        'report': _report('rep-old', 'DM_MESSAGE'),
        'target': const {
          'type': 'DM_MESSAGE',
          'state': 'EXPIRED',
          'author': _author,
          'dm': {
            'snapshot': {
              'kind': 'TEXT',
              'text': 'رسالة قديمة',
              'sentAt': '2026-11-05T21:04:00.000Z',
              'purged': false,
            },
            'recipient': null,
            'threadSummary': null,
          },
        },
        'actions': const ['SUSPEND'],
        'canResolve': true,
      });
      final opened = StaffDmThreadView.fromJson(const {
        'reportId': 'rep-old',
        'reported': _author,
        'recipient': null,
        'snapshot': {
          'kind': 'TEXT',
          'text': 'رسالة قديمة',
          'sender': 'spammer01',
          'sentAt': '2026-11-05T21:04:00.000Z',
          'purged': false,
        },
        'thread': null,
      });
      await pumpReportRoutes(
        tester,
        language: AppLanguage.ar,
        repo: FakeReportViewRepository(
          views: {'rep-old': old},
          threads: {'rep-old': opened},
        ),
        initial: AppRoutes.staffReport('rep-old'),
      );
      expect(find.text('بلاغ قديم: الرسالة المُبلّغ عنها فقط'), findsOneWidget);
      await tester.tap(find.byKey(StaffReportDetailScreen.openThreadKey));
      await tester.pumpAndSettle();
      expect(find.text('رسالة قديمة'), findsOneWidget);
      expect(find.byKey(StaffReportDetailScreen.reportedMessageKey), findsOne);
    });

    testWidgets('gone: «المحتوى محذوف» with what the report kept', (
      tester,
    ) async {
      await pumpReportRoutes(
        tester,
        language: AppLanguage.ar,
        repo: FakeReportViewRepository(views: {'rep-gone': goneView}),
        initial: AppRoutes.staffReport('rep-gone'),
      );
      expect(find.byKey(StaffReportDetailScreen.deletedKey), findsOneWidget);
      expect(find.text('المحتوى محذوف'), findsOneWidget);
      expect(find.text('اربح الآن! اضغط على الرابط'), findsWidgets);
    });

    test('the STAFF_REPORT_NEW notification opens the report', () {
      expect(
        NotificationTargetType.fromWire('REPORT'),
        NotificationTargetType.report,
      );
      expect(AppRoutes.staffReport('rep-1'), '/me/staff/reports/rep-1');
    });
  });

  group('the action bar per role', () {
    testWidgets('OWNER: every action (deleting an account too) and «تم حله»', (
      tester,
    ) async {
      await pumpReportRoutes(
        tester,
        language: AppLanguage.ar,
        repo: FakeReportViewRepository(),
        initial: AppRoutes.staffReport('rep-post'),
      );
      expect(find.byKey(StaffReportDetailScreen.actionBarKey), findsOneWidget);
      for (final a in StaffReportAction.values) {
        expect(_action(a), findsOneWidget, reason: a.wire);
      }
      expect(find.byKey(StaffReportDetailScreen.resolveKey), findsOneWidget);
    });

    testWidgets('SUPPORT: only what the matrix allows (the temporary lock)', (
      tester,
    ) async {
      await pumpReportRoutes(
        tester,
        language: AppLanguage.ar,
        repo: FakeReportViewRepository(),
        initial: AppRoutes.staffReport('rep-dm'),
      );
      expect(_action(StaffReportAction.suspend), findsOneWidget);
      for (final a in [
        StaffReportAction.warn,
        StaffReportAction.restrict,
        StaffReportAction.ban,
        StaffReportAction.removeContent,
        StaffReportAction.deleteContent,
        StaffReportAction.deleteAccount,
      ]) {
        expect(_action(a), findsNothing, reason: a.wire);
      }
      expect(find.byKey(StaffReportDetailScreen.resolveKey), findsOneWidget);
    });

    testWidgets('a closed report has no action bar', (tester) async {
      final closed = StaffReportView.fromJson({
        'report': {
          ..._report('rep-closed', 'POST'),
          'status': 'ACTIONED',
          'resolvedAt': '2026-11-06T10:00:00.000Z',
          'resolvedBy': const {
            'id': 's1',
            'username': 'mod01',
            'displayName': 'مها',
          },
          'resolutionNote': 'تحذير أول',
          'resolutionAction': 'WARN',
        },
        'target': const {'type': 'POST', 'state': 'GONE', 'author': null},
        'actions': const <Object>[],
        'restrictions': const <Object>[],
        'canResolve': false,
      });
      await pumpReportRoutes(
        tester,
        language: AppLanguage.ar,
        repo: FakeReportViewRepository(views: {'rep-closed': closed}),
        initial: AppRoutes.staffReport('rep-closed'),
      );
      expect(find.byKey(StaffReportDetailScreen.actionBarKey), findsNothing);
      expect(find.text('حُلّ بإجراء: تحذير'), findsOneWidget);
    });
  });

  group('the actions', () {
    testWidgets('DELETE_CONTENT: the word must be typed, then it acts', (
      tester,
    ) async {
      final repo = FakeReportViewRepository();
      await pumpReportRoutes(
        tester,
        language: AppLanguage.ar,
        repo: repo,
        initial: AppRoutes.staffReport('rep-post'),
      );
      await tester.tap(_action(StaffReportAction.deleteContent));
      await tester.pumpAndSettle();
      expect(find.text('حذف هذا المحتوى نهائياً؟'), findsOneWidget);
      expect(find.byKey(StaffReportActionDialog.confirmKey), findsOneWidget);
      await tester.enterText(
        find.byKey(StaffReportActionDialog.reasonKey),
        'محتوى غير قانوني',
      );
      // A wrong word: refused in the dialog, nothing sent.
      await tester.enterText(
        find.byKey(StaffReportActionDialog.confirmKey),
        'حذ',
      );
      await tester.tap(find.byKey(StaffReportActionDialog.applyKey));
      await tester.pumpAndSettle();
      expect(find.text('اكتب الكلمة كما هي'), findsOneWidget);
      expect(repo.acts, isEmpty);
      await tester.enterText(
        find.byKey(StaffReportActionDialog.confirmKey),
        'حذف',
      );
      await tester.tap(find.byKey(StaffReportActionDialog.applyKey));
      await tester.pumpAndSettle();
      expect(repo.acts, ['rep-post:DELETE_CONTENT:محتوى غير قانوني']);
    });

    testWidgets('DELETE_ACCOUNT: «DELETE» is accepted in English', (
      tester,
    ) async {
      final repo = FakeReportViewRepository();
      await pumpReportRoutes(
        tester,
        language: AppLanguage.en,
        repo: repo,
        initial: AppRoutes.staffReport('rep-post'),
      );
      await tester.tap(_action(StaffReportAction.deleteAccount));
      await tester.pumpAndSettle();
      expect(find.textContaining('Delete '), findsWidgets);
      await tester.enterText(
        find.byKey(StaffReportActionDialog.reasonKey),
        'fraud ring',
      );
      await tester.enterText(
        find.byKey(StaffReportActionDialog.confirmKey),
        'DELETE',
      );
      await tester.tap(find.byKey(StaffReportActionDialog.applyKey));
      await tester.pumpAndSettle();
      expect(repo.acts, ['rep-post:DELETE_ACCOUNT:fraud ring']);
    });

    testWidgets('BAN asks for confirmation and a reason, then acts', (
      tester,
    ) async {
      final repo = FakeReportViewRepository();
      await pumpReportRoutes(
        tester,
        language: AppLanguage.ar,
        repo: repo,
        initial: AppRoutes.staffReport('rep-post'),
      );
      await tester.tap(_action(StaffReportAction.ban));
      await tester.pumpAndSettle();
      expect(find.byType(StaffReportActionDialog), findsOneWidget);
      expect(find.textContaining('نهائياً؟'), findsOneWidget);
      // No reason: refused in the dialog.
      await tester.tap(find.byKey(StaffReportActionDialog.applyKey));
      await tester.pumpAndSettle();
      expect(find.text('اكتب السبب'), findsOneWidget);
      expect(repo.acts, isEmpty);
      await tester.enterText(
        find.byKey(StaffReportActionDialog.reasonKey),
        'حساب احتيال',
      );
      await tester.tap(find.byKey(StaffReportActionDialog.applyKey));
      await tester.pumpAndSettle();
      expect(repo.acts, ['rep-post:BAN:حساب احتيال']);
      expect(find.text('تم الإجراء وحُلّ البلاغ'), findsOneWidget);
    });

    testWidgets('RESTRICT: «منع النشر» for 3 days', (tester) async {
      final repo = FakeReportViewRepository();
      await pumpReportRoutes(
        tester,
        language: AppLanguage.ar,
        repo: repo,
        initial: AppRoutes.staffReport('rep-post'),
      );
      await tester.tap(_action(StaffReportAction.restrict));
      await tester.pumpAndSettle();
      expect(find.text('منع النشر'), findsOneWidget);
      expect(find.text('منع البث'), findsOneWidget);
      expect(find.text('منع الرسائل'), findsOneWidget);
      await tester.tap(
        find.byKey(
          StaffReportActionDialog.restriction(StaffRestriction.noPosting),
        ),
      );
      await tester.tap(find.byKey(StaffReportActionDialog.days(3)));
      await tester.enterText(
        find.byKey(StaffReportActionDialog.reasonKey),
        'منشورات مزعجة',
      );
      await tester.tap(find.byKey(StaffReportActionDialog.applyKey));
      await tester.pumpAndSettle();
      expect(repo.acts, ['rep-post:RESTRICT:NO_POSTING:3:منشورات مزعجة']);
    });

    testWidgets('WARN and cancel: nothing sent', (tester) async {
      final repo = FakeReportViewRepository();
      await pumpReportRoutes(
        tester,
        language: AppLanguage.en,
        repo: repo,
        initial: AppRoutes.staffReport('rep-post'),
      );
      await tester.tap(_action(StaffReportAction.warn));
      await tester.pumpAndSettle();
      expect(find.byType(StaffReportActionDialog), findsOneWidget);
      expect(find.text('Apply'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repo.acts, isEmpty);
    });

    testWidgets('another staff member acted first: «تم حله بالفعل»', (
      tester,
    ) async {
      final repo = FakeReportViewRepository(alreadyActed: true);
      await pumpReportRoutes(
        tester,
        language: AppLanguage.ar,
        repo: repo,
        initial: AppRoutes.staffReport('rep-post'),
      );
      await tester.tap(_action(StaffReportAction.warn));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(StaffReportActionDialog.reasonKey),
        'تحذير',
      );
      await tester.tap(find.byKey(StaffReportActionDialog.applyKey));
      await tester.pumpAndSettle();
      expect(
        find.text(
          lookupAppLocalizations(const Locale('ar')).staffSharedAlreadyResolved,
        ),
        findsOneWidget,
      );
    });

    testWidgets('«تم حله» without an action still works', (tester) async {
      final repo = FakeReportViewRepository();
      await pumpReportRoutes(
        tester,
        language: AppLanguage.ar,
        repo: repo,
        initial: AppRoutes.staffReport('rep-dm'),
      );
      await tester.tap(find.byKey(StaffReportDetailScreen.resolveKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(SharedReportResolveDialog.applyKey));
      await tester.pumpAndSettle();
      expect(repo.resolved.keys, ['rep-dm']);
      expect(repo.acts, isEmpty);
    });
  });
}
