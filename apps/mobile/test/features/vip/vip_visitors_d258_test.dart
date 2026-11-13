// D258 phase 4 (§10.94.9): «من زار ملفي».
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/vip/application/vip_look.dart';
import 'package:kabso_live/features/vip/data/vip_repository.dart';
import 'package:kabso_live/features/vip/presentation/vip_visitors_screen.dart';
import 'package:kabso_live/features/vip/presentation/vip_wear.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';

class _Repo implements VipRepository {
  new(this.answer);

  final Future<ProfileVisitorList> Function() answer;

  @override
  Future<ProfileVisitorList> profileVisitors() => answer();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _vip1 = UserVip(tier: 'VIP_1', rank: 1, color: 0xFF2E8B3D);

ProfileVisitor _v(String id, String name, {int visits = 1, UserVip? vip}) =>
    ProfileVisitor(
      user: UserSummary(
        id: id,
        username: id,
        displayName: name,
        avatarUrl: null,
        vip: vip,
      ),
      lastVisitedAt: DateTime.utc(2026, 11, 4, 18, 30),
      visits: visits,
    );

Future<void> _pump(
  WidgetTester tester,
  Future<ProfileVisitorList> Function() answer, {
  AppLanguage language = AppLanguage.en,
}) async {
  await pumpGolden(
    tester,
    ProviderScope(
      overrides: [
        secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
        currentUserProvider.overrideWithValue(testUser()),
        vipRepositoryProvider.overrideWithValue(_Repo(answer)),
        vipCatalogProvider.overrideWith((ref) async => null),
      ],
      child: const VipVisitorsScreen(),
    ),
    language: language,
    bare: true,
    brightness: Brightness.light,
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the visitors, the latest first, with the total and visits', (
    tester,
  ) async {
    await _pump(
      tester,
      () async => (
        data: [
          _v('u1', 'Layla', visits: 3, vip: _vip1),
          _v('u2', 'Omar'),
        ],
        total: 2,
      ),
    );
    expect(find.byKey(VipVisitorsScreen.listKey), findsOneWidget);
    expect(find.text('2 visitors in the last 30 days'), findsOneWidget);
    expect(find.textContaining('Layla'), findsOneWidget);
    expect(find.text('3 visits'), findsOneWidget);
    expect(find.byKey(VipNameBadge.badgeKey), findsOneWidget);
  });

  testWidgets('no visitors yet', (tester) async {
    await _pump(tester, () async => (data: const <ProfileVisitor>[], total: 0));
    expect(find.byKey(VipVisitorsScreen.emptyKey), findsOneWidget);
  });

  testWidgets('without the perk: the page leads to «شراء VIP»', (tester) async {
    await _pump(
      tester,
      () async => throw const ServerFailure(
        code: ErrorCode.vipUnavailable,
        rawCode: 'VIP_UNAVAILABLE',
        debugMessage: 'no_perk',
      ),
    );
    expect(find.byKey(VipVisitorsScreen.noPerkKey), findsOneWidget);
  });

  forEachLanguage((language) {
    testWidgets('golden vip.visitors ($language)', (tester) async {
      final ar = language == AppLanguage.ar;
      await _pump(
        tester,
        () async => (
          data: [
            _v('u1', ar ? 'ليلى' : 'Layla', visits: 3, vip: _vip1),
            _v('u2', ar ? 'عمر' : 'Omar'),
            _v('u3', ar ? 'سارة' : 'Sara', visits: 2),
          ],
          total: 3,
        ),
        language: language,
      );
      await expectScreenGolden('vip.visitors', language: language);
    });
  });
}
