import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/profile/profile_fields_view.dart';
import 'package:kabso_live/features/settings/social/official_accounts.dart';
import 'package:kabso_live/features/staff/application/staff_providers.dart';
import 'package:kabso_live/features/staff/domain/staff_identity.dart';
import 'package:kabso_live/features/staff/domain/staff_models.dart';
import 'package:kabso_live/features/staff/presentation/staff_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_ops_roles.dart';
import '../../helpers/pump_app.dart';

/// v1.139-social (D387, CONVENTIONS §10.176): the operations roles in the
/// app — the role names (MODERATION reads TRUST_SAFETY), the staff page's
/// «في المناوبة الآن» badge from the shift schedule, an operations role's
/// minimal page (no live shift, no «بثوثي»), and «تابعنا» in Settings with
/// the official accounts (https links only, opened outside the app).

class _Opener implements ExternalLinkOpener {
  final opened = <Uri>[];

  @override
  Future<bool> open(Uri url) async {
    opened.add(url);
    return true;
  }
}

void main() {
  group('the roles', () {
    test(
      'StaffStatus reads the schedule’s «now» (false from an older API)',
      () {
        final on = StaffStatus.fromJson(const {
          'isStaff': false,
          'roles': ['VIP_CARE'],
          'capabilities': <String>[],
          'authenticatorEnrolled': true,
          'onShift': false,
          'scheduledShift': true,
        });
        expect(on.scheduledShift, isTrue);
        expect(on.copyWith(onShift: true).scheduledShift, isTrue);
        expect(
          StaffStatus.fromJson(const {'isStaff': true}).scheduledShift,
          isFalse,
        );
      },
    );

    test(
      'every role has a name in both languages; MODERATION is TRUST_SAFETY',
      () {
        final ar = l10nFor(AppLanguage.ar);
        final en = l10nFor(AppLanguage.en);
        expect(staffRoleLabel(ar, 'MODERATION'), 'مراقبة المحتوى والأمان');
        expect(staffRoleLabel(en, 'MODERATION'), 'Trust & safety');
        expect(staffRoleLabel(ar, 'LIVE_OPS'), 'مدير عمليات البث');
        expect(staffRoleLabel(ar, 'TALENT'), 'مدير الوكالات والمواهب');
        expect(staffRoleLabel(ar, 'VIP_CARE'), 'دعم كبار الداعمين');
        expect(staffRoleLabel(ar, 'COMMUNITY'), 'المجتمع والفعاليات');
        expect(staffRoleLabel(en, 'FINANCE'), en.staffRoleFinance);
        // An unknown future role shows its wire value, never another role.
        expect(staffRoleLabel(en, 'NEW_ROLE'), 'NEW_ROLE');
      },
    );

    test('the operations roles are limited staff identities with a line', () {
      final en = l10nFor(AppLanguage.en);
      for (final (wire, name) in [
        ('LIVE_OPS', en.staffRoleLiveOps),
        ('TALENT', en.staffRoleTalent),
        ('VIP_CARE', en.staffRoleVipCare),
        ('COMMUNITY', en.staffRoleCommunity),
      ]) {
        final id = staffIdentityFromJson({
          'role': wire,
          'regions': ['ARAB_WORLD'],
        });
        expect(id, isNotNull, reason: wire);
        expect(id!.line(en), name);
        expect(staffIdentityToJson(id)!['role'], wire);
      }
    });
  });

  group('the staff page', () {
    Future<void> pumpStaff(
      WidgetTester tester,
      StaffStatus status, {
      AppLanguage language = AppLanguage.ar,
    }) async {
      await pumpScreen(
        tester,
        const StaffScreen(),
        language: language,
        overrides: [
          staffStatusProvider.overrideWith(() => FixedStaff(status)),
          staffLivesProvider.overrideWith((ref) async => const <StaffLive>[]),
        ],
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      'VIP_CARE on the schedule: its role, the badge, no live shift',
      (tester) async {
        await pumpStaff(tester, d387Status(roles: ['VIP_CARE']));
        final l = l10nFor(AppLanguage.ar);
        expect(find.text('دعم كبار الداعمين'), findsOneWidget);
        expect(find.byKey(StaffScreen.scheduledBadgeKey), findsOneWidget);
        expect(find.text(l.staffOnShiftNow), findsOneWidget);
        expect(find.text(l.staffOpsPanelHint), findsOneWidget);
        expect(find.byKey(StaffScreen.shiftKey), findsNothing);
        expect(find.text(l.staffMyLives), findsNothing);
      },
    );

    testWidgets(
      'a moderator off the schedule: no badge, the live shift stays',
      (tester) async {
        await pumpStaff(
          tester,
          d387Status(roles: ['MODERATION'], scheduled: false, watch: true),
          language: AppLanguage.en,
        );
        expect(find.text('Trust & safety'), findsOneWidget);
        expect(find.byKey(StaffScreen.scheduledBadgeKey), findsNothing);
        expect(find.byKey(StaffScreen.shiftKey), findsOneWidget);
      },
    );

    testWidgets('several roles: every one, then the badge', (tester) async {
      await pumpStaff(
        tester,
        d387Status(roles: ['MODERATION', 'VIP_CARE'], watch: true),
        language: AppLanguage.en,
      );
      expect(find.text('Trust & safety'), findsOneWidget);
      expect(find.text('VIP care'), findsOneWidget);
      expect(find.byKey(StaffScreen.scheduledBadgeKey), findsOneWidget);
    });
  });

  group('«تابعنا»', () {
    test('https links only; an unknown platform reads as other', () {
      expect(
        OfficialSocialAccount.fromJson({
          'platform': 'X',
          'handle': 'a',
          'url': 'http://x.com/a',
        }),
        isNull,
      );
      expect(
        OfficialSocialAccount.fromJson({
          'platform': 'X',
          'handle': 'a',
          'url': 'javascript:alert(1)',
        }),
        isNull,
      );
      final odd = OfficialSocialAccount.fromJson({
        'platform': 'MASTODON',
        'handle': 'a',
        'url': 'https://example.social/@a',
      })!;
      expect(odd.platform, SocialPlatform.other);
    });

    Widget section() =>
        const Scaffold(body: SingleChildScrollView(child: FollowUsSection()));

    testWidgets('lists the accounts in order and opens a link outside', (
      tester,
    ) async {
      final opener = _Opener();
      await pumpScreen(
        tester,
        section(),
        language: AppLanguage.ar,
        overrides: [
          officialAccountsRepositoryProvider.overrideWithValue(
            FakeOfficialAccounts(d387Accounts()),
          ),
          externalLinkOpenerProvider.overrideWithValue(opener),
        ],
      );
      await tester.pumpAndSettle();
      final l = l10nFor(AppLanguage.ar);
      expect(find.byKey(FollowUsSection.headerKey), findsOneWidget);
      expect(find.text(l.settingsFollowUs), findsOneWidget);
      expect(find.text(l.socialPlatformInstagram), findsOneWidget);
      expect(find.textContaining('@kabso.live'), findsOneWidget);
      // Generic glyphs of the app's icon set.
      expect(find.byIcon(Icons.photo_camera_outlined), findsOneWidget);
      final first = tester.getTopLeft(find.byKey(FollowUsSection.row(0)));
      final second = tester.getTopLeft(find.byKey(FollowUsSection.row(1)));
      expect(first.dy, lessThan(second.dy));
      await tester.tap(find.byKey(FollowUsSection.row(1)));
      await tester.pump();
      expect(opener.opened, [Uri.parse('https://www.tiktok.com/@kabso')]);
    });

    testWidgets('nothing at all when there is no account', (tester) async {
      await pumpScreen(
        tester,
        section(),
        overrides: [
          officialAccountsRepositoryProvider.overrideWithValue(
            FakeOfficialAccounts(const []),
          ),
        ],
      );
      await tester.pumpAndSettle();
      expect(find.byKey(FollowUsSection.headerKey), findsNothing);
      expect(find.byType(ListTile), findsNothing);
    });
  });
}
