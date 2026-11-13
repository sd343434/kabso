// Owner (2026-11-13: «انقل رسائل واتساب داخل تطبيق الى رسائل لتكون اسهل
// للوصول»): «واتساب» moved from a Me tab row to «الرسائل» — a pinned circle
// first in the row for the staff who answer the official number
// (`waEntryProvider`: the founder; a staff member by their WhatsApp level,
// the D355 roles while it is unknown), with the conversations waiting for
// them on its badge; it opens the inbox. A Kabso Team account has no «دعم
// كابسو» circle (owner: «موظف ليس لديه رسائل دعم فقط في الاعلى مثبت رقم
// واتساب»). Nobody else sees «واتساب», and it hides
// while the server says the inbox serves nothing. No overflow at 360 wide,
// text ×1.3, Arabic.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/domain/entities.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/messages/data/dm_groups_repository.dart';
import 'package:kabso_live/features/messages/data/dm_repository.dart';
import 'package:kabso_live/features/messages/messages_tab.dart';
import 'package:kabso_live/features/messages/widgets/dm_pinned_row.dart';
import 'package:kabso_live/features/owner_profile/data/owner_profile_repository.dart'
    show isKabsoOwnerProvider;
import 'package:kabso_live/features/staff/application/staff_providers.dart';
import 'package:kabso_live/features/staff/domain/staff_identity.dart';
import 'package:kabso_live/features/staff/domain/staff_models.dart';
import 'package:kabso_live/features/stories/data/stories_repository.dart';
import 'package:kabso_live/features/support/data/support_repository.dart';
import 'package:kabso_live/features/whatsapp/application/wa_providers.dart';
import 'package:kabso_live/features/whatsapp/data/wa_repository.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_dm_groups_repository.dart';
import '../../helpers/fake_dm_repository.dart';
import '../../helpers/fake_stories_repository.dart';
import '../../helpers/fake_support_repository.dart';
import '../../helpers/fake_whatsapp.dart';
import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

final List<String> _visited = [];

class _FixedStaffStatus extends StaffStatusController {
  new(this.status);

  final StaffStatus status;

  @override
  Future<StaffStatus> build() async => status;
}

StaffStatus _status(List<String> capabilities) => StaffStatus(
  isStaff: true,
  roles: const ['SUPPORT'],
  capabilities: capabilities,
  authenticatorEnrolled: true,
  onShift: false,
);

const List<String> _reply = [WaCapability.view, WaCapability.reply];

User _staff(StaffLineRole role) =>
    testUser().copyWith(kabsoTeam: true, staff: KabsoStaffIdentity(role: role));

Future<void> _pump(
  WidgetTester tester, {
  required User user,
  List<String> capabilities = _reply,
  FakeWaRepository? wa,
  bool founder = false,
  AppLanguage language = AppLanguage.en,
  Size size = const Size(393, 852),
  double textScale = 1,
}) async {
  _visited.clear();
  tester.view
    ..physicalSize = size * 3
    ..devicePixelRatio = 3;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final prefs = await testPrefs(language: language.name);
  final router = GoRouter(
    routes: [GoRoute(path: '/', builder: (_, _) => const MessagesTab())],
    errorBuilder: (_, state) {
      _visited.add(state.uri.toString());
      return Scaffold(body: Text('at ${state.uri}'));
    },
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        dmRepositoryProvider.overrideWithValue(FakeDmRepository()),
        dmGroupsRepositoryProvider.overrideWithValue(FakeDmGroupsRepository()),
        supportRepositoryProvider.overrideWithValue(FakeSupportRepository()),
        dmPinsRepositoryProvider.overrideWithValue(FakeDmPinsRepository()),
        storiesRepositoryProvider.overrideWithValue(FakeStoriesRepository()),
        currentUserProvider.overrideWithValue(user),
        isKabsoOwnerProvider.overrideWithValue(founder),
        waRepositoryProvider.overrideWithValue(wa ?? FakeWaRepository()),
        staffStatusProvider.overrideWith(
          () => _FixedStaffStatus(_status(capabilities)),
        ),
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
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The circles of the row, from the reading start (their keys' ids).
List<String> _circles(WidgetTester tester) {
  final circle = RegExp(r'^dm\.pins\.[^.]+$');
  final found = find.byWidgetPredicate((w) {
    final k = w.key;
    return k is ValueKey<String> &&
        k.value != 'dm.pins.row' &&
        circle.hasMatch(k.value);
  });
  final rtl =
      Directionality.of(tester.element(find.byKey(DmPinnedRow.rowKey))) ==
      TextDirection.rtl;
  final items = [
    for (final e in found.evaluate())
      (
        (e.renderObject! as RenderBox).localToGlobal(Offset.zero).dx,
        (e.widget.key! as ValueKey<String>).value.substring('dm.pins.'.length),
      ),
  ]..sort((a, b) => rtl ? b.$1.compareTo(a.$1) : a.$1.compareTo(b.$1));
  return [for (final i in items) i.$2];
}

Future<void> _end(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

void main() {
  testWidgets(
    'a support agent: «واتساب» alone at the top (no «دعم كابسو»), its badge, '
    'opens the inbox',
    (tester) async {
      await _pump(tester, user: _staff(StaffLineRole.support));
      expect(_circles(tester), ['whatsapp']);
      // FakeWaRepository's summary: 3 conversations waiting.
      expect(
        find.descendant(
          of: find.byKey(DmPinnedRow.whatsAppBadgeKey),
          matching: find.text('3'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(DmPinnedRow.whatsAppKey),
          matching: find.text('WhatsApp'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(DmPinnedRow.whatsAppKey));
      await tester.pumpAndSettle();
      expect(_visited, [AppRoutes.staffWhatsApp]);
      await _end(tester);
    },
  );

  testWidgets('read-only (VIEW) staff see it too', (tester) async {
    await _pump(
      tester,
      user: _staff(StaffLineRole.moderation),
      capabilities: const [WaCapability.view],
    );
    expect(find.byKey(DmPinnedRow.whatsAppKey), findsOneWidget);
    await _end(tester);
  });

  testWidgets('the founder sees it', (tester) async {
    await _pump(
      tester,
      user: testUser().copyWith(kabsoTeam: true),
      founder: true,
    );
    expect(_circles(tester), ['whatsapp']);
    await _end(tester);
  });

  testWidgets('nobody else: a member, a staff member without a WhatsApp '
      'level, a finance agent without a level', (tester) async {
    await _pump(tester, user: testUser());
    expect(find.byKey(DmPinnedRow.whatsAppKey), findsNothing);
    expect(_circles(tester), ['support']);
    await _end(tester);

    await _pump(
      tester,
      user: _staff(StaffLineRole.support),
      capabilities: const [],
    );
    expect(find.byKey(DmPinnedRow.whatsAppKey), findsNothing);
    expect(find.byKey(DmPinnedRow.supportKey), findsNothing);
    await _end(tester);

    await _pump(
      tester,
      user: _staff(StaffLineRole.finance),
      capabilities: const [],
    );
    expect(find.byKey(DmPinnedRow.whatsAppKey), findsNothing);
    await _end(tester);
  });

  testWidgets('hidden while the inbox serves nothing; shown for the in-app '
      'threads alone', (tester) async {
    await _pump(
      tester,
      user: _staff(StaffLineRole.support),
      wa: FakeWaRepository(enabled: false),
    );
    expect(find.byKey(DmPinnedRow.whatsAppKey), findsNothing);
    await _end(tester);

    await _pump(
      tester,
      user: _staff(StaffLineRole.support),
      wa: FakeWaRepository(enabled: false, inApp: true),
    );
    expect(find.byKey(DmPinnedRow.whatsAppKey), findsOneWidget);
    await _end(tester);
  });

  testWidgets('Arabic, 360 wide, text ×1.3: «واتساب» first, no '
      'overflow', (tester) async {
    await _pump(
      tester,
      user: _staff(StaffLineRole.support),
      language: AppLanguage.ar,
      size: const Size(360, 800),
      textScale: 1.3,
    );
    expect(_circles(tester), ['whatsapp']);
    expect(
      find.descendant(
        of: find.byKey(DmPinnedRow.whatsAppKey),
        matching: find.text('واتساب'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await _end(tester);
  });
}
