import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/presentation/go_live/seat_controls.dart';
import 'package:kabso_live/features/live/presentation/widgets/kabso_team_badge.dart';
import 'package:kabso_live/features/push/push_payload.dart';
import 'package:kabso_live/features/staff/data/staff_repository.dart';
import 'package:kabso_live/features/staff/domain/staff_models.dart';
import 'package:kabso_live/features/staff/domain/staff_report_view.dart';
import 'package:kabso_live/features/staff/presentation/staff_entry_dialog.dart';
import 'package:kabso_live/features/staff/presentation/staff_screen.dart';
import 'package:kabso_live/features/staff/presentation/staff_tools_sheet.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_live_repository.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

/// v1.68-live (D273, CONVENTIONS §10.96.6–§10.96.8): «فريق كابسو» from the
/// app — «أدوات فريق كابسو» limited by role (SUPPORT reads, MODERATION acts),
/// the shift and «بثوثي», the visible / hidden entry, the team's chat tag, and
/// the staff alert's route to the live's reports. D286: no step-up dialog any
/// more, and staff work shows the shift on at once.

StaffStatus _status({
  List<String> roles = const ['MODERATION'],
  bool enrolled = true,
  bool onShift = true,
}) => StaffStatus(
  isStaff: true,
  roles: roles,
  capabilities: [
    StaffCapability.watch,
    StaffCapability.reports,
    if (roles.contains('MODERATION') || roles.contains('OWNER')) ...[
      StaffCapability.watchHidden,
      StaffCapability.moderate,
      StaffCapability.deviceBan,
    ],
  ],
  authenticatorEnrolled: enrolled,
  onShift: onShift,
);

final _reports = [
  StaffReport(
    id: 'r1',
    target: StaffReportTarget.live,
    reason: 'HARASSMENT',
    open: true,
    createdAt: DateTime.utc(2026, 11, 4, 20),
    reporter: const StaffPerson(username: 'huda', displayName: 'هدى'),
  ),
  StaffReport(
    id: 'r2',
    target: StaffReportTarget.message,
    reason: 'SPAM',
    open: true,
    createdAt: DateTime.utc(2026, 11, 4, 20, 5),
    person: const StaffPerson(username: 'omar', displayName: 'عمر'),
    messageId: 'm1',
    messageText: 'اشترك في قناتي',
    reporter: const StaffPerson(username: 'sara', displayName: 'Sara'),
  ),
];

final _lives = [
  StaffLive(
    roomId: 'room-1',
    title: 'سهرة الجمعة',
    hostName: 'ليان',
    hostUsername: 'layan',
    viewerCount: 1240,
    openReports: 2,
    startedAt: DateTime.utc(2026, 11, 4, 19),
  ),
  StaffLive(
    roomId: 'room-2',
    title: 'Morning talk',
    hostName: 'Adam',
    hostUsername: 'adam',
    viewerCount: 87,
    openReports: 0,
    startedAt: DateTime.utc(2026, 11, 4, 18),
  ),
];

class FakeStaffRepository implements StaffRepository {
  new(this.state);

  StaffStatus state;
  final calls = <String>[];

  @override
  Future<StaffStatus> status() async => state;

  @override
  Future<bool> setShift({required bool onShift}) async {
    calls.add('shift:$onShift');
    return onShift;
  }

  @override
  Future<List<StaffLive>> myLives() async => _lives;

  @override
  Future<List<StaffReport>> reports(String roomId) async => _reports;

  @override
  Future<void> moderate(
    String roomId,
    StaffLiveAction action, {
    required String reason,
    int? hours,
  }) async => calls.add('moderate:${action.wire}:$reason:$hours');

  @override
  Future<void> dismissReports(String roomId, {required String reason}) async =>
      calls.add('dismiss:$reason');

  @override
  Future<void> kick(
    String roomId, {
    required String username,
    required String reason,
  }) async => calls.add('kick:$username:$reason');

  @override
  Future<void> mute(
    String roomId, {
    required String username,
    required String reason,
  }) async => calls.add('mute:$username:$reason');

  @override
  Future<void> removeMessage(
    String roomId,
    String messageId, {
    required String reason,
  }) async => calls.add('remove:$messageId:$reason');

  // v1.78-live (D288): the shared queue (not used by the D273 tests).
  @override
  Future<SharedReportPage> sharedReports(
    SharedReportTab tab, {
    String? cursor,
  }) async => const SharedReportPage(items: []);

  @override
  Future<int> openReportsCount() async => 0;

  @override
  Future<SharedReport> resolveReport(String reportId, {String? note}) =>
      throw UnimplementedError();

  // v1.93-social (D296): one report and its actions (not used by these tests).
  @override
  Future<StaffReportView> report(String reportId) => throw UnimplementedError();

  @override
  Future<SharedReport> actOnReport(
    String reportId,
    StaffReportAction action, {
    required String reason,
    StaffRestriction? restriction,
    int? days,
  }) => throw UnimplementedError();
}

/// A phone with the notch and home bar (insets 59 / 34).
void _phone(WidgetTester tester) {
  setViewport(tester, GoldenViewport.phone);
  tester.view
    ..padding = const FakeViewPadding(top: 59 * 3, bottom: 34 * 3)
    ..viewPadding = const FakeViewPadding(top: 59 * 3, bottom: 34 * 3);
}

Widget _sheetOpener({
  StaffVisibility visibility = StaffVisibility.visible,
  ValueChanged<StaffVisibility>? onSwitch,
}) => Builder(
  builder: (context) => Center(
    child: TextButton(
      onPressed: () => showStaffTools(
        context,
        roomId: 'room-1',
        hostName: 'ليان',
        visibility: visibility,
        onSwitchMode: onSwitch,
      ),
      child: const Text('tools'),
    ),
  ),
);

Future<FakeStaffRepository> _pumpSheet(
  WidgetTester tester,
  StaffStatus status, {
  AppLanguage language = AppLanguage.en,
  StaffVisibility visibility = StaffVisibility.visible,
  ValueChanged<StaffVisibility>? onSwitch,
  bool golden = false,
}) async {
  final repo = FakeStaffRepository(status);
  if (golden) {
    await loadAppFonts();
    _phone(tester);
  }
  await pumpScreen(
    tester,
    Scaffold(
      body: _sheetOpener(visibility: visibility, onSwitch: onSwitch),
    ),
    overrides: [staffRepositoryProvider.overrideWithValue(repo)],
    language: language,
    brightness: Brightness.light,
  );
  await tester.tap(find.text('tools'));
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  group('models', () {
    test('StaffStatus reads the server (the deprecated stepUp ignored)', () {
      final s = StaffStatus.fromJson(const {
        'isStaff': true,
        'protected': true,
        'roles': ['SUPPORT'],
        'capabilities': ['lives.watch', 'lives.reports'],
        'authenticatorEnrolled': true,
        'lockedUntil': null,
        'stepUp': {'expiresAt': '2026-11-04T22:30:00.000Z'},
        'onShift': true,
      });
      expect(s.can(StaffCapability.moderate), isFalse);
      expect(s.can(StaffCapability.reports), isTrue);
      expect(s.onShift, isTrue);
      expect(StaffStatus.fromJson(const {'isStaff': false}).isStaff, isFalse);
    });

    test('a report of a chat message names its author and text', () {
      final r = StaffReport.fromJson(const {
        'id': 'r',
        'targetType': 'LIVE_CHAT_MESSAGE',
        'target': {
          'user': {'id': 'u', 'username': 'omar', 'displayName': 'عمر'},
          'messageId': 'm1',
          'text': 'hi',
        },
        'reason': 'SPAM',
        'status': 'OPEN',
        'createdAt': '2026-11-04T20:00:00.000Z',
        'reporter': null,
      });
      expect(r.target, StaffReportTarget.message);
      expect(r.person!.username, 'omar');
      expect(r.messageId, 'm1');
      expect(r.open, isTrue);
    });

    test(
      "a staff member's chat line: the team's tag, no VIP / levels / CP",
      () {
        final e = LiveChatEntry.fromJson(const {
          'id': 'm',
          'roomId': 'r',
          'author': {
            'id': 'u',
            'username': 'sara',
            'displayName': 'Sara',
            'avatarUrl': null,
            'rechargeAgent': {'code': 'A1'},
          },
          'authorRole': 'VIEWER',
          'kind': 'TEXT',
          'text': 'hello',
          'media': null,
          'expiresAt': null,
          'createdAt': '2026-11-04T20:00:00.000Z',
          'cpBubble': true,
          'authorBadges': {'charmLevel': 30},
          'authorStaff': true,
        });
        expect(e.authorStaff, isTrue);
        expect(e.cpBubble, isFalse);
        expect(e.authorBadges!.kabsoTeam, isTrue);
        expect(e.authorBadges!.charmLevel, isNull);
        expect(e.author.rechargeAgentCode, isNull);
      },
    );

    test('LiveMediaAccess carries the staff entry', () {
      final a = LiveMediaAccess.fromJson(const {
        'url': 'wss://m',
        'token': 't',
        'expiresAt': '2026-11-04T20:00:00.000Z',
        'role': 'VIEWER',
        'identity': 'staff:u:1',
        'guestNumber': null,
        'staff': 'HIDDEN',
      });
      expect(StaffVisibility.fromWire(a.staff), StaffVisibility.hidden);
    });

    test('a staff alert push opens the live on its reports', () {
      const push = PushPayload({
        'kind': 'notification',
        'type': 'LIVE_STAFF_REPORT',
        'targetType': 'LIVE_ROOM',
        'targetId': 'room-1',
      });
      expect(push.route(), AppRoutes.liveRoomStaffReports('room-1'));
      expect(push.route(), '/home/room/room-1?staff=reports');
    });
  });

  group('D286: no code, the shift on by itself', () {
    testWidgets('the tools open at once — no step-up dialog, no lock', (
      tester,
    ) async {
      await _pumpSheet(tester, _status(onShift: false));
      expect(
        find.byKey(StaffToolsSheet.action(StaffLiveAction.end)),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.lock_rounded), findsNothing);
      expect(find.byIcon(Icons.key_rounded), findsNothing);
    });

    testWidgets('reading the reports (staff work) shows the shift on', (
      tester,
    ) async {
      final l = l10nFor(AppLanguage.en);
      final repo = await _pumpSheet(tester, _status(onShift: false));
      final shift = find.byKey(StaffToolsSheet.shiftKey);
      expect(
        find.descendant(of: shift, matching: find.text(l.staffShift)),
        findsOneWidget,
      );
      expect(repo.calls, isEmpty);
    });

    testWidgets('SUPPORT: off shift stays off until staff work is done', (
      tester,
    ) async {
      final l = l10nFor(AppLanguage.en);
      // No reports capability → nothing loaded → the shift as the server said.
      final repo = FakeStaffRepository(
        const StaffStatus(
          isStaff: true,
          roles: ['SUPPORT'],
          capabilities: [StaffCapability.watch],
          authenticatorEnrolled: false,
          onShift: false,
        ),
      );
      await pumpScreen(
        tester,
        Scaffold(body: _sheetOpener()),
        overrides: [staffRepositoryProvider.overrideWithValue(repo)],
      );
      await tester.tap(find.text('tools'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(StaffToolsSheet.shiftKey),
          matching: find.text(l.staffShiftOff),
        ),
        findsOneWidget,
      );
    });
  });

  group('«أدوات فريق كابسو»', () {
    testWidgets('SUPPORT reads the reports and takes no action', (
      tester,
    ) async {
      final l = l10nFor(AppLanguage.en);
      await _pumpSheet(tester, _status(roles: ['SUPPORT']));
      expect(find.text(l.staffReadOnly), findsOneWidget);
      expect(find.byKey(StaffToolsSheet.report(0)), findsOneWidget);
      expect(find.byKey(StaffToolsSheet.report(1)), findsOneWidget);
      for (final a in StaffLiveAction.values) {
        expect(find.byKey(StaffToolsSheet.action(a)), findsNothing);
      }
      expect(find.text(l.staffActionKick), findsNothing);
      // No hidden mode for SUPPORT.
      expect(find.byKey(StaffToolsSheet.switchKey), findsNothing);
    });

    testWidgets('MODERATION: every action asks a reason (and a duration)', (
      tester,
    ) async {
      final l = l10nFor(AppLanguage.en);
      final repo = await _pumpSheet(tester, _status());
      // Warn the host with a reason.
      final warn = find.byKey(StaffToolsSheet.action(StaffLiveAction.warn));
      await tester.ensureVisible(warn);
      await tester.pumpAndSettle();
      await tester.tap(warn);
      await tester.pumpAndSettle();
      expect(find.text(l.staffReasonHostHint), findsOneWidget);
      final apply = find.byKey(StaffReasonDialog.applyKey);
      expect(tester.widget<FilledButton>(apply).onPressed, isNull);
      await tester.enterText(find.byKey(StaffReasonDialog.reasonKey), 'Lang');
      await tester.pump();
      await tester.tap(apply);
      await tester.pumpAndSettle();
      // A ban from going live: the duration too.
      final noLive = find.byKey(StaffToolsSheet.action(StaffLiveAction.noLive));
      await tester.ensureVisible(noLive);
      await tester.pumpAndSettle();
      await tester.tap(noLive);
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.staffDuration7d));
      await tester.enterText(find.byKey(StaffReasonDialog.reasonKey), 'Rules');
      await tester.pump();
      await tester.tap(find.byKey(StaffReasonDialog.applyKey));
      await tester.pumpAndSettle();
      // A reported message: remove it.
      await tester.ensureVisible(find.text(l.staffActionRemoveMessage));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.staffActionRemoveMessage));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(StaffReasonDialog.reasonKey), 'Spam');
      await tester.pump();
      await tester.tap(find.byKey(StaffReasonDialog.applyKey));
      await tester.pumpAndSettle();
      // Someone by username: kick.
      await tester.ensureVisible(find.byKey(StaffToolsSheet.personKey));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(StaffToolsSheet.personKey), '@omar');
      await tester.pump();
      await tester.tap(find.widgetWithText(OutlinedButton, l.staffActionKick));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(StaffReasonDialog.reasonKey), 'Abuse');
      await tester.pump();
      await tester.tap(find.byKey(StaffReasonDialog.applyKey));
      await tester.pumpAndSettle();
      expect(repo.calls, [
        'moderate:WARN:Lang:null',
        'moderate:NO_LIVE:Rules:168',
        'remove:m1:Spam',
        'kick:omar:Abuse',
      ]);
    });

    testWidgets('MODERATION switches to the hidden watch from the sheet', (
      tester,
    ) async {
      final switched = <StaffVisibility>[];
      await _pumpSheet(tester, _status(), onSwitch: switched.add);
      await tester.tap(find.byKey(StaffToolsSheet.switchKey));
      await tester.pumpAndSettle();
      expect(switched, [StaffVisibility.hidden]);
    });
  });

  group('the shift and «بثوثي»', () {
    testWidgets('the shift switch and the lives (the most reported first)', (
      tester,
    ) async {
      final l = l10nFor(AppLanguage.en);
      final repo = FakeStaffRepository(_status(onShift: false));
      await pumpScreen(
        tester,
        const StaffScreen(),
        overrides: [staffRepositoryProvider.overrideWithValue(repo)],
      );
      await tester.pumpAndSettle();
      expect(find.byKey(StaffScreen.live('room-1')), findsOneWidget);
      expect(find.byKey(StaffScreen.live('room-2')), findsOneWidget);
      expect(find.text(l.staffReportsCount('2')), findsOneWidget);
      expect(find.text(l.staffShiftAutoHint), findsOneWidget);
      // D286: opening «بثوثي» is staff work — the switch is on at once, with
      // no call of its own (the server switched it).
      final shift = find.byKey(StaffScreen.shiftKey);
      expect(tester.widget<SwitchListTile>(shift).value, isTrue);
      expect(tester.widget<SwitchListTile>(shift).onChanged, isNotNull);
      expect(repo.calls, isEmpty);
      // Off stays by hand.
      await tester.tap(shift);
      await tester.pumpAndSettle();
      expect(repo.calls, ['shift:false']);
      expect(tester.widget<SwitchListTile>(shift).value, isFalse);
    });
  });

  group('the entry', () {
    testWidgets('visible or hidden (hidden only with the capability)', (
      tester,
    ) async {
      StaffVisibility? chosen;
      await pumpScreen(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  chosen = await showStaffEntryChoice(context, canHidden: true),
              child: const Text('go'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(StaffEntryDialog.optionKey(StaffVisibility.visible)),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(StaffEntryDialog.optionKey(StaffVisibility.hidden)),
      );
      await tester.pumpAndSettle();
      expect(chosen, StaffVisibility.hidden);
      await pumpScreen(
        tester,
        const Scaffold(body: StaffEntryDialog(canHidden: false)),
      );
      expect(
        find.byKey(StaffEntryDialog.optionKey(StaffVisibility.hidden)),
        findsNothing,
      );
    });
  });

  group('goldens', () {
    for (final language in AppLanguage.values) {
      testWidgets('staff_tools_sheet (${language.name})', (tester) async {
        await _pumpSheet(tester, _status(), language: language, golden: true);
        // D282: the Kabso Team badge's art painted.
        await precacheImages(tester);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            '../../goldens/png/staff_tools_sheet.${language.name}.phone.png',
          ),
        );
      }, tags: goldenTag);

      testWidgets('staff_tools_sheet_support (${language.name})', (
        tester,
      ) async {
        await _pumpSheet(
          tester,
          _status(roles: ['SUPPORT']),
          language: language,
          golden: true,
        );
        // D282: the Kabso Team badge's art painted.
        await precacheImages(tester);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            '../../goldens/png/staff_tools_sheet_support.${language.name}'
            '.phone.png',
          ),
        );
      }, tags: goldenTag);

      testWidgets('staff_shift_lives (${language.name})', (tester) async {
        await loadAppFonts();
        _phone(tester);
        await pumpScreen(
          tester,
          const StaffScreen(),
          overrides: [
            staffRepositoryProvider.overrideWithValue(
              FakeStaffRepository(_status()),
            ),
          ],
          language: language,
          brightness: Brightness.light,
        );
        await tester.pumpAndSettle();
        // D282: the Kabso Team badge's art painted.
        await precacheImages(tester);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            '../../goldens/png/staff_shift_lives.${language.name}.phone.png',
          ),
        );
      }, tags: goldenTag);

      testWidgets('live_viewers_app_staff (${language.name})', (tester) async {
        // D273: a staff member who entered from the app is listed like a
        // panel watcher — first, with the badge, not counted.
        await loadAppFonts();
        _phone(tester);
        final repo = FakeLiveRepository()
          ..viewerList = [
            LiveViewer(
              kind: LiveViewerKind.user,
              user: const UserSummary(
                id: 'u-huda',
                username: 'huda',
                displayName: 'Huda',
                avatarUrl: null,
              ),
              guestNumber: null,
              joinedAt: DateTime.utc(2026, 11, 4),
            ),
          ]
          ..staffList = [
            LiveStaffWatcher(
              displayName: 'سارة',
              avatarUrl: null,
              since: DateTime.utc(2026, 11, 4, 10),
            ),
            LiveStaffWatcher(
              displayName: 'Omar',
              avatarUrl: null,
              since: DateTime.utc(2026, 11, 4, 10, 5),
            ),
          ];
        await pumpScreen(
          tester,
          Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: TextButton(
                  onPressed: () => showLiveViewers(context, roomId: 'room-1'),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
          overrides: [liveRepositoryProvider.overrideWithValue(repo)],
          language: language,
          brightness: Brightness.light,
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        final l = l10nFor(language);
        expect(find.text(l.liveViewersTab('1')), findsOneWidget);
        expect(find.byKey(KabsoTeamBadge.badgeKey), findsNWidgets(2));
        expect(find.byKey(SeatControlKeys.staffRow(1)), findsOneWidget);
        // D282: the Kabso Team badge's art painted.
        await precacheImages(tester);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            '../../goldens/png/live_viewers_app_staff.${language.name}'
            '.phone.png',
          ),
        );
      }, tags: goldenTag);
    }
  });
}
