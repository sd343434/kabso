// D299g / D299h (owner: «اجعل آيدي الموظفين مميزاً من نوع ذهبي», then «لا،
// هكذا الآيدي غير مميز مثل آيدي المميز الذهبي بأيقونة»): the Kabso Team's
// official staff ID (D283c) is drawn as the GOLD special-ID pill (D146's
// KSpecialUsername: the gold medal, pill, outlined text, end-cap, glow),
// «Kabso01» with no «@», wherever it is shown: the profile's title (the bar
// size, over the cover and once solid), the staff Me tab and the person
// card (the normal size), list rows (the list size). Keys kept; read as the
// official staff ID (D283c's hint); a normal @username is never a pill.
//
// With STAFF_GOLD_CAPTURE_DIR set, the capture group writes PNGs there
// (not committed).

import 'dart:io';
import 'dart:ui' as ui;

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/models/premium_tier.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/follows/data/follow_requests_repository.dart';
import 'package:kabso_live/features/follows/presentation/follow_requests_screen.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_person_card.dart';
import 'package:kabso_live/features/profile/me_hub_screen.dart';
import 'package:kabso_live/features/profile/profile_cover_header.dart';
import 'package:material_ui/material_ui.dart';

import '../../goldens/live_person_card_golden_test.dart'
    show pumpPersonCardRoom;
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';
import '../profile/profile_cover_d278_test.dart' show otherProfile, pumpOther;
import 'staff_d283_test.dart' show d283Now, pumpStaffHub;
import 'staff_ids_d283c_test.dart' show ownerCardProfile, staffIdProfile;

class _Requests implements FollowRequestsRepository {
  new(this.users);

  final List<UserSummary> users;

  @override
  Future<FollowRequestPage> list({String? cursor}) async => FollowRequestPage(
    [
      for (final u in users)
        FollowRequest(user: u, requestedAt: DateTime.utc(2026, 11, 7, 9)),
    ],
    const PageInfo(nextCursor: null, hasMore: false),
    users.length,
  );

  @override
  Future<int> accept(String username) async => 0;

  @override
  Future<void> decline(String username) async {}
}

const _staffUser = UserSummary(
  id: 'u1',
  username: 'kabso.mod',
  displayName: 'مشرف كابسو',
  avatarUrl: null,
  staffId: 'Kabso01',
);

const _normalUser = UserSummary(
  id: 'u2',
  username: 'nour_8',
  displayName: 'نور',
  avatarUrl: null,
);

Future<void> _pumpRequests(
  WidgetTester tester, {
  required AppLanguage language,
  Brightness brightness = Brightness.light,
}) async {
  setViewport(tester, GoldenViewport.phone);
  await pumpScreen(
    tester,
    const FollowRequestsScreen(),
    language: language,
    brightness: brightness,
    overrides: [
      secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
      followRequestsRepositoryProvider.overrideWithValue(
        _Requests([_staffUser, _normalUser]),
      ),
    ],
  );
  await tester.pumpAndSettle();
}

/// The gold special-ID pill of [staffId] at [height] under [of].
void _expectPill(
  WidgetTester tester,
  Finder of, {
  required String staffId,
  required double height,
  required AppLanguage language,
}) {
  final pill = find.descendant(
    of: of,
    matching: find.byType(KSpecialUsername),
    matchRoot: true,
  );
  expect(pill, findsOneWidget);
  final w = tester.widget<KSpecialUsername>(pill);
  expect(w.username, staffId);
  expect(w.tier, PremiumTier.gold);
  expect(w.tier, KStaffIdText.tier);
  expect(w.height, height);
  // Read as the official staff ID, not as a paid name.
  expect(w.semanticHint, l10nFor(language).profileStaffIdHint);
  // (In a list tile the row's node merges the pill's in.)
  final node = tester.getSemantics(pill);
  expect(node.hint, contains(l10nFor(language).profileStaffIdHint));
  expect(node.label, contains(staffId));
}

void main() {
  setUpAll(loadAppFonts);

  test('the pill sizes: the list size, the normal size, the bar size (as '
      "the premium badge's)", () {
    expect(KStaffIdText.list, 18);
    expect(KStaffIdText.normal, 22);
    expect(KStaffIdText.bar, ProfileCoverHandle.badgeHeight);
  });

  for (final language in AppLanguage.values) {
    final ar = language == AppLanguage.ar;
    final name = language.name;

    testWidgets('the profile title: the gold pill «Kabso01», the bar size, '
        'centred, over the cover and once solid ($name)', (tester) async {
      await withClock(Clock.fixed(d283Now), () async {
        await pumpOther(tester, staffIdProfile(ar: ar), language: language);
      });
      final id = find.byKey(ProfileCoverHeader.staffIdKey);
      _expectPill(
        tester,
        id,
        staffId: 'Kabso01',
        height: KStaffIdText.bar,
        language: language,
      );
      final bar = tester.getRect(find.byType(AppBar));
      final pill = tester.getRect(
        find.descendant(of: id, matching: find.byType(KSpecialUsername)),
      );
      expect(pill.center.dx, moreOrLessEquals(393 / 2, epsilon: 1));
      expect(pill.bottom, lessThanOrEqualTo(bar.bottom));
      expect(find.textContaining('@Kabso01'), findsNothing);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(
        tester.widget<AppBar>(find.byType(AppBar)).backgroundColor,
        isNot(Colors.transparent),
      );
      expect(
        find.descendant(of: id, matching: find.byType(KSpecialUsername)),
        findsOneWidget,
      );
    });

    testWidgets('a normal @username is not a pill ($name)', (tester) async {
      await pumpOther(tester, otherProfile(ar: ar), language: language);
      expect(find.byKey(ProfileCoverHeader.staffIdKey), findsNothing);
      expect(find.byType(KStaffIdText), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(ProfileCoverHeader.handleKey),
          matching: find.byType(KSpecialUsername),
        ),
        findsNothing,
      );
    });

    testWidgets('the staff Me tab: the gold pill, the normal size ($name)', (
      tester,
    ) async {
      await pumpStaffHub(tester, language: language, staffId: 'Kabso01');
      expect(tester.takeException(), isNull);
      _expectPill(
        tester,
        find.byKey(MeHubScreen.staffIdKey),
        staffId: 'Kabso01',
        height: KStaffIdText.normal,
        language: language,
      );
    });

    testWidgets('the person card: the gold pill «Kabso», the normal size '
        '($name)', (tester) async {
      await pumpPersonCardRoom(
        tester,
        language: language,
        profile: ownerCardProfile(ar: ar),
      );
      expect(tester.takeException(), isNull);
      _expectPill(
        tester,
        find.byKey(LivePersonSheet.staffIdKey),
        staffId: 'Kabso',
        height: KStaffIdText.normal,
        language: language,
      );
    });

    testWidgets('a list row: the staff ID as the gold pill (list size), a '
        'normal @username as text ($name)', (tester) async {
      await _pumpRequests(tester, language: language);
      expect(tester.takeException(), isNull);
      _expectPill(
        tester,
        find.byType(KStaffIdText),
        staffId: 'Kabso01',
        height: KStaffIdText.list,
        language: language,
      );
      expect(find.textContaining('nour_8'), findsOneWidget);
      expect(find.byType(KSpecialUsername), findsOneWidget);
    });
  }

  final captureDir = Platform.environment['STAFF_GOLD_CAPTURE_DIR'];
  group('D299g captures', skip: captureDir == null, () {
    Future<void> capture(WidgetTester tester, String name) async {
      await precacheImages(tester);
      await tester.runAsync(() async {
        final element = find.byType(MaterialApp).evaluate().first;
        final image = await captureImage(element);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('${captureDir!}/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
      });
    }

    for (final brightness in Brightness.values) {
      testWidgets('staff profile ar ${brightness.name}', (tester) async {
        await withClock(Clock.fixed(d283Now), () async {
          await pumpOther(
            tester,
            staffIdProfile(ar: true),
            language: AppLanguage.ar,
            brightness: brightness,
          );
        });
        await capture(tester, 'staff.profile.ar.${brightness.name}');
      });
    }
    testWidgets('staff profile ar light solid', (tester) async {
      await withClock(Clock.fixed(d283Now), () async {
        await pumpOther(
          tester,
          staffIdProfile(ar: true),
          language: AppLanguage.ar,
        );
      });
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pumpAndSettle();
      await capture(tester, 'staff.profile.ar.light.solid');
    });
    testWidgets('staff me ar', (tester) async {
      await pumpStaffHub(tester, language: AppLanguage.ar, staffId: 'Kabso01');
      await capture(tester, 'staff.me.ar');
    });
    testWidgets('follow requests ar', (tester) async {
      await _pumpRequests(tester, language: AppLanguage.ar);
      await capture(tester, 'follow_requests.ar');
    });
    testWidgets('person card ar', (tester) async {
      await pumpPersonCardRoom(
        tester,
        language: AppLanguage.ar,
        profile: ownerCardProfile(ar: true),
      );
      await capture(tester, 'person_card.ar');
    });
  });
}
