// D390 «برنامج سفراء Kabso»: the programme page (off → «قريباً», no form;
// on → the levels and rules from the server, the form with https-only links,
// the application sent, the status), the dashboard (code, level, progress,
// the month's targets, referrals, commissions, history, the held notice,
// share), the badge's spoken label, the notifications and the error code.

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/ambassadors/data/ambassador_repository.dart';
import 'package:kabso_live/features/ambassadors/presentation/ambassador_badge.dart';
import 'package:kabso_live/features/ambassadors/presentation/ambassador_dashboard_screen.dart';
import 'package:kabso_live/features/ambassadors/presentation/ambassador_entry_card.dart';
import 'package:kabso_live/features/ambassadors/presentation/ambassador_programme_screen.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/notifications/domain/notification_models.dart';
import 'package:kabso_live/features/profile/domain/profile_models.dart'
    show ambassadorLevelFromJson, ambassadorLevelToJson;
import 'package:kabso_live/features/referrals/presentation/invite_friends_screen.dart'
    show InviteSharer, inviteSharerProvider;
import 'package:material_ui/material_ui.dart';

import '../../fixtures/ambassadors/ambassador_fixtures.dart';
import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

class _Sharer implements InviteSharer {
  final List<String> shared = [];

  @override
  Future<bool> share(String text, {Rect? origin}) async {
    shared.add(text);
    return true;
  }

  @override
  Future<bool> whatsapp(String text) async => true;
}

void main() {
  Future<FakeAmbassadorRepository> pumpProgramme(
    WidgetTester tester, {
    AmbassadorProgramme? programme,
    AppLanguage language = AppLanguage.en,
  }) async {
    final repo = FakeAmbassadorRepository(programme: programme);
    tester.view.physicalSize = const Size(393 * 3, 2600 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await pumpScreen(
      tester,
      const AmbassadorProgrammeScreen(),
      language: language,
      overrides: [
        currentUserProvider.overrideWithValue(testUser()),
        ambassadorRepositoryProvider.overrideWithValue(repo),
      ],
    );
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets('off: «coming soon», no levels and no form', (tester) async {
    await pumpProgramme(
      tester,
      programme: ambassadorProgramme(enabled: false, refusal: 'DISABLED'),
    );
    expect(find.text('Coming soon — you can apply once it launches'), findsOne);
    expect(find.byKey(AmbassadorProgrammeScreen.submitKey), findsNothing);
    expect(find.byType(AmbassadorBadge), findsNothing);
  });

  testWidgets('on: the four levels with their commission and reward, the '
      'rules from the server', (tester) async {
    await pumpProgramme(tester);
    expect(find.byType(AmbassadorBadge), findsNWidgets(4));
    for (final pct in ['2%', '3%', '4%', '5%']) {
      expect(find.textContaining(pct), findsWidgets);
    }
    expect(find.textContaining('100,000'), findsWidgets);
    expect(find.textContaining('VIP 1'), findsOne);
    expect(find.textContaining('days): \u206860\u2069'), findsOne);
  });

  testWidgets('the form refuses an http link and sends a valid application', (
    tester,
  ) async {
    final repo = await pumpProgramme(tester);
    await tester.enterText(
      find.byKey(AmbassadorProgrammeScreen.linkKey(0)),
      'http://example.com/me',
    );
    await tester.tap(find.byKey(AmbassadorProgrammeScreen.submitKey));
    await tester.pumpAndSettle();
    expect(find.text('Enter a link that starts with https://'), findsOne);
    expect(find.text('Choose your country'), findsOne);
    expect(repo.sent, isEmpty);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Egypt').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(AmbassadorProgrammeScreen.linkKey(0)),
      'https://example.com/@sara',
    );
    await tester.enterText(
      find.byKey(AmbassadorProgrammeScreen.audienceKey),
      '25000',
    );
    await tester.enterText(
      find.byKey(AmbassadorProgrammeScreen.motivationKey),
      'Weekly contests in Cairo',
    );
    await tester.tap(find.byKey(AmbassadorProgrammeScreen.submitKey));
    await tester.pumpAndSettle();
    expect(repo.sent, hasLength(1));
    expect(repo.sent.single.country, 'EG');
    expect(repo.sent.single.links, ['https://example.com/@sara']);
    expect(repo.sent.single.audienceSize, 25000);
    expect(
      find.text('Your application is being reviewed by the management'),
      findsOne,
    );
  });

  testWidgets('a rejected application shows the reason above the form', (
    tester,
  ) async {
    await pumpProgramme(
      tester,
      programme: ambassadorProgramme(
        status: 'REJECTED',
        rejectReason: 'Audience too small',
      ),
      language: AppLanguage.ar,
    );
    expect(find.textContaining('Audience too small'), findsOne);
    expect(find.byKey(AmbassadorProgrammeScreen.submitKey), findsOne);
  });

  testWidgets('staff and ambassadors see a status, an ambassador the '
      'dashboard button', (tester) async {
    await pumpProgramme(
      tester,
      programme: ambassadorProgramme(refusal: 'STAFF'),
      language: AppLanguage.ar,
    );
    expect(
      find.text('حسابات فريق كابسو لا يمكنها الانضمام إلى برنامج السفراء'),
      findsOne,
    );
    await pumpProgramme(
      tester,
      programme: ambassadorProgramme(
        status: 'AMBASSADOR',
        refusal: 'AMBASSADOR',
      ),
    );
    expect(find.byKey(AmbassadorProgrammeScreen.dashboardKey), findsOne);
  });

  Future<_Sharer> pumpDashboard(
    WidgetTester tester, {
    bool held = false,
  }) async {
    final sharer = _Sharer();
    tester.view.physicalSize = const Size(393 * 3, 2400 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await pumpScreen(
      tester,
      const AmbassadorDashboardScreen(),
      overrides: [
        currentUserProvider.overrideWithValue(testUser()),
        ambassadorRepositoryProvider.overrideWithValue(
          FakeAmbassadorRepository(
            dashboard: ambassadorDashboard(payoutsHeld: held),
          ),
        ),
        inviteSharerProvider.overrideWithValue(sharer),
      ],
    );
    await tester.pumpAndSettle();
    return sharer;
  }

  testWidgets('the dashboard: code, level, progress, targets, counts, '
      'commissions, history; share', (tester) async {
    final sharer = await pumpDashboard(tester);
    expect(find.text('K7M4QX2D'), findsOne);
    expect(find.text('https://kabsolive.com/i/K7M4QX2D'), findsOne);
    expect(find.textContaining('3%'), findsOne);
    expect(find.text('To reach Gold this month'), findsOne);
    expect(
      find.textContaining('Active referrals to go: \u20686\u2069'),
      findsOne,
    );
    expect(find.text('\u20689\u2069 / \u206815\u2069'), findsOne);
    expect(find.text('3,860,000'), findsOne);
    expect(find.text('410,000'), findsOne);
    expect(find.text('23'), findsOne);
    expect(find.text('Reward granted'), findsOne);
    expect(find.text('Reversed'), findsOne);
    expect(find.byKey(AmbassadorDashboardScreen.heldKey), findsNothing);
    await tester.tap(find.byKey(AmbassadorDashboardScreen.shareKey));
    await tester.pump();
    expect(sharer.shared.single, contains('K7M4QX2D'));
  });

  testWidgets('payouts held: the notice, never the reason', (tester) async {
    await pumpDashboard(tester, held: true);
    expect(find.byKey(AmbassadorDashboardScreen.heldKey), findsOne);
    expect(
      find.text('Your payouts are on hold while the management reviews them'),
      findsOne,
    );
  });

  testWidgets('the badge speaks «Kabso ambassador · level»', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpScreen(
      tester,
      const Center(child: AmbassadorBadge(level: 'DIAMOND', large: true)),
    );
    expect(find.bySemanticsLabel('Kabso ambassador · Diamond'), findsOne);
    handle.dispose();
  });

  testWidgets('the invite page entry shows only while the programme is on', (
    tester,
  ) async {
    for (final (enabled, shown) in [(false, false), (true, true)]) {
      await pumpScreen(
        tester,
        const AmbassadorEntryCard(),
        overrides: [
          ambassadorRepositoryProvider.overrideWithValue(
            FakeAmbassadorRepository(
              programme: ambassadorProgramme(
                enabled: enabled,
                refusal: enabled ? null : 'DISABLED',
              ),
            ),
          ),
        ],
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(AmbassadorEntryCard.cardKey),
        shown ? findsOne : findsNothing,
      );
    }
  });

  testWidgets('an ended membership: the status, no form', (tester) async {
    await pumpProgramme(
      tester,
      programme: ambassadorProgramme(status: 'ENDED', refusal: 'ENDED'),
    );
    expect(
      find.textContaining('Your ambassador membership has ended'),
      findsOne,
    );
    expect(find.byKey(AmbassadorProgrammeScreen.submitKey), findsNothing);
    expect(find.byKey(AmbassadorProgrammeScreen.dashboardKey), findsNothing);
  });

  test('PublicProfile.ambassador → the level; absent or malformed → null', () {
    expect(ambassadorLevelFromJson({'level': 'GOLD'}), 'GOLD');
    expect(ambassadorLevelFromJson(null), isNull);
    expect(ambassadorLevelFromJson({'level': ''}), isNull);
    expect(ambassadorLevelFromJson('GOLD'), isNull);
    expect(ambassadorLevelToJson('SILVER'), {'level': 'SILVER'});
  });

  test('the D389 explainer text for the badge (ar and en)', () {
    expect(
      ambassadorBadgeExplainer(l10nFor(AppLanguage.ar), 'GOLD'),
      'سفير Kabso — المستوى ذهبي',
    );
    expect(
      ambassadorBadgeExplainer(l10nFor(AppLanguage.en), 'GOLD'),
      'Kabso ambassador — Gold level',
    );
  });

  test('the four notifications are system notifications of the programme', () {
    for (final wire in [
      'AMBASSADOR_APPLICATION_APPROVED',
      'AMBASSADOR_APPLICATION_REJECTED',
      'AMBASSADOR_LEVEL_UP',
      'AMBASSADOR_REWARD_GRANTED',
      'AMBASSADOR_MEMBERSHIP_ENDED',
    ]) {
      final t = NotificationType.fromWire(wire);
      expect(t, isNot(NotificationType.unknown), reason: wire);
      expect(t.isSystem, isTrue);
      expect(t.isAmbassador, isTrue);
    }
  });

  test('AMBASSADOR_APPLICATION_NOT_ALLOWED has its own message', () {
    final l10n = l10nFor(AppLanguage.ar);
    expect(
      ErrorCode.values.byName('ambassadorApplicationNotAllowed').wire,
      'AMBASSADOR_APPLICATION_NOT_ALLOWED',
    );
    expect(
      failureMessage(
        l10n,
        const ServerFailure(
          code: ErrorCode.ambassadorApplicationNotAllowed,
          rawCode: 'AMBASSADOR_APPLICATION_NOT_ALLOWED',
          debugMessage: '',
          statusCode: 409,
        ),
      ),
      'لا يمكنك التقديم إلى برنامج السفراء الآن',
    );
  });
}
