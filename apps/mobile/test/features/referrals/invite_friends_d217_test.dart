// v1.74-social (D217, CONVENTIONS §10.71): «دعوة صديق» behind the Me hub's
// «اربح المال» — the hero with the server's «اربح حتى N», the ticker of real
// rewards (hidden when empty), the steps and what each side gets, «ادعُ
// الآن», the code with «نسخ», the milestones (locked / unlocked / claimed)
// with «N مدعو», the friends, the rules sheet, the share bar; loading, error
// and the programme off (→ the cherry wallet); the later code in Settings;
// the optional code at sign-up. Arabic RTL and English LTR, 393×852 and
// 360×800 with text ×1.3, light and dark. Fakes only (the real flow is the
// API's e2e `d217-referrals`). With --dart-define=D217_CAPTURE_DIR=<dir> the
// owner's captures are written (393×852 @3x).

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/notifications/domain/notification_models.dart';
import 'package:kabso_live/features/push/push_payload.dart';
import 'package:kabso_live/features/referrals/application/referral_providers.dart';
import 'package:kabso_live/features/referrals/data/referral_repository.dart';
import 'package:kabso_live/features/referrals/presentation/invite_friends_screen.dart';
import 'package:kabso_live/features/referrals/presentation/referral_code_sheet.dart';
import 'package:kabso_live/features/wallet/data/cherry_repository.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

const _captureDir = String.fromEnvironment('D217_CAPTURE_DIR');
final AppLocalizations _ar = l10nFor(AppLanguage.ar);
final AppLocalizations _en = l10nFor(AppLanguage.en);
final GlobalKey _boundary = GlobalKey();
const _walletPage = Key('test.wallet');

MyReferral _referral({
  bool enabled = true,
  int invited = 3,
  int qualified = 1,
  int pending = 2,
  int inviteeSignup = 0,
  List<ReferralInvitee>? invitees,
  bool canApply = true,
  ReferralStatus? invitedBy,
  List<MilestoneState> states = const [
    MilestoneState.claimed,
    MilestoneState.locked,
    MilestoneState.locked,
  ],
}) => MyReferral(
  enabled: enabled,
  code: 'K7QM4P2X',
  link: 'https://kabsolive.com/i/K7QM4P2X',
  rules: ReferralRules(
    inviterSignupCherries: 20000,
    inviteeSignupCherries: inviteeSignup,
    firstRechargeBps: 500,
    holdHours: 24,
    applyWindowDays: 7,
    dailySignupCap: 20,
  ),
  upToTotal: 1650000,
  upToMilestones: 1350000,
  payout: const CherryPayoutRules(
    currency: 'USD',
    rateCherries: 1000000,
    rateMinor: 110,
    minAmountMinor: 0,
    payoutDays: 0,
  ),
  invited: invited,
  qualified: qualified,
  pending: pending,
  pendingCherries: 40000,
  creditedCherries: 70000,
  milestones: [
    ReferralMilestone(friends: 1, cherries: 50000, state: states[0]),
    ReferralMilestone(friends: 5, cherries: 300000, state: states[1]),
    ReferralMilestone(friends: 15, cherries: 1000000, state: states[2]),
  ],
  invitees:
      invitees ??
      [
        ReferralInvitee(
          name: 'س***ة',
          status: ReferralStatus.qualified,
          joinedAt: DateTime.utc(2026, 10, 30),
          firstRecharge: true,
        ),
        ReferralInvitee(
          name: 'A***d',
          status: ReferralStatus.pending,
          joinedAt: DateTime.utc(2026, 10, 31),
          firstRecharge: false,
        ),
        ReferralInvitee(
          name: 'م***ر',
          status: ReferralStatus.rejected,
          joinedAt: DateTime.utc(2026, 11),
          firstRecharge: false,
        ),
      ],
  canApply: canApply,
  invitedByStatus: invitedBy,
  applyUntil: canApply ? DateTime.utc(2026, 11, 7) : null,
);

class _FakeReferrals implements ReferralRepository {
  new({
    this.page,
    this.items = const [],
    this.failMine,
    this.applyResult,
    this.applyFailure,
  });

  MyReferral? page;
  final List<ReferralTickerItem> items;
  AppFailure? failMine;
  final MyReferral? applyResult;
  final AppFailure? applyFailure;
  int mineCalls = 0;
  final applied = <(String, String?)>[];
  Completer<void>? gate;

  @override
  Future<MyReferral?> mine() async {
    mineCalls++;
    await gate?.future;
    final f = failMine;
    if (f != null) throw f;
    return page;
  }

  @override
  Future<MyReferral> apply(String code, {String? installId}) async {
    applied.add((code, installId));
    final f = applyFailure;
    if (f != null) throw f;
    return applyResult ?? page!;
  }

  @override
  Future<List<ReferralTickerItem>> ticker() async => items;
}

class _FakeSharer implements InviteSharer {
  new({this.whatsappOk = true});

  final bool whatsappOk;
  final shared = <String>[];
  final whatsapped = <String>[];

  @override
  Future<bool> share(String text, {Rect? origin}) async {
    shared.add(text);
    return true;
  }

  @override
  Future<bool> whatsapp(String text) async {
    whatsapped.add(text);
    return whatsappOk;
  }
}

const _ticker = [
  ReferralTickerItem(
    name: 'ن***ر',
    cherries: 20000,
    kind: ReferralRewardKind.signupInviter,
  ),
  ReferralTickerItem(
    name: 'L***a',
    cherries: 50000,
    kind: ReferralRewardKind.milestone,
  ),
];

Future<void> _pump(
  WidgetTester tester, {
  required _FakeReferrals repo,
  _FakeSharer? sharer,
  AppLanguage language = AppLanguage.ar,
  GoldenViewport viewport = GoldenViewport.phone,
  double textScale = 1,
  Brightness brightness = Brightness.light,
  Widget? home,
  bool settle = true,
}) async {
  InviteFriendsScreen.animateArt = false;
  addTearDown(() => InviteFriendsScreen.animateArt = true);
  final router = GoRouter(
    initialLocation: home == null ? AppRoutes.inviteFriends : '/home-test',
    routes: [
      GoRoute(
        path: AppRoutes.inviteFriends,
        builder: (_, _) => const InviteFriendsScreen(),
      ),
      GoRoute(
        path: AppRoutes.wallet,
        builder: (_, s) => Scaffold(
          key: _walletPage,
          body: Text('wallet ${s.uri.queryParameters['tab']}'),
        ),
      ),
      if (home != null) GoRoute(path: '/home-test', builder: (_, _) => home),
    ],
  );
  await loadAppFonts();
  setViewport(tester, viewport);
  final prefs = await testPrefs(language: language.name);
  await tester.pumpWidget(
    RepaintBoundary(
      key: _boundary,
      child: ProviderScope(
        retry: (_, _) => null,
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
          currentUserProvider.overrideWithValue(testUser()),
          referralRepositoryProvider.overrideWithValue(repo),
          inviteSharerProvider.overrideWithValue(sharer ?? _FakeSharer()),
        ],
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
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
              disableAnimations: true,
            ),
            child: child!,
          ),
        ),
      ),
    ),
  );
  if (settle) {
    await precacheImages(tester);
    await tester.pumpAndSettle();
  }
}

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

/// Scrolls the page's list until [finder] shows.
Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find
        .descendant(
          of: find.byType(InviteFriendsScreen),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
}

String _plain(String s) => s.replaceAll(RegExp('[\u2066-\u2069]'), '');

bool _textContains(WidgetTester tester, String part) => tester
    .widgetList<Text>(find.byType(Text))
    .any(
      (t) => _plain(t.data ?? t.textSpan?.toPlainText() ?? '').contains(part),
    );

void main() {
  group('«دعوة صديق»', () {
    for (final language in const [AppLanguage.ar, AppLanguage.en]) {
      for (final viewport in GoldenViewport.values) {
        for (final textScale in [1.0, 1.3]) {
          for (final brightness in Brightness.values) {
            testWidgets('${language.name} ${viewport.name} ×$textScale '
                '${brightness.name}: every part, the server numbers, no '
                'overflow', (tester) async {
              final l10n = language == AppLanguage.ar ? _ar : _en;
              await _pump(
                tester,
                repo: _FakeReferrals(page: _referral(), items: _ticker),
                language: language,
                viewport: viewport,
                textScale: textScale,
                brightness: brightness,
              );
              expect(tester.takeException(), isNull);
              expect(find.text(l10n.inviteTitle), findsOneWidget);
              expect(find.byKey(InviteFriendsScreen.heroKey), findsOneWidget);
              expect(find.text(l10n.inviteHeroLine), findsOneWidget);
              expect(_textContains(tester, '1,650,000'), isTrue);
              // ≈ $1.81 (1 650 000 cherries at 1 000 000 = $1.10).
              expect(_textContains(tester, r'$1.81'), isTrue);
              expect(find.byKey(InviteFriendsScreen.tickerKey), findsOneWidget);
              expect(_textContains(tester, 'ن***ر'), isTrue);
              expect(
                _textContains(tester, _plain(l10n.inviteStepSignup('20,000'))),
                isTrue,
              );
              expect(
                _textContains(tester, _plain(l10n.inviteStepRecharge('5%'))),
                isTrue,
              );
              // The third reward: the milestones, from the server's values.
              expect(
                _textContains(
                  tester,
                  _plain(
                    l10n.inviteStepMilestones(
                      referralMilestoneList(l10n, _referral().milestones),
                    ),
                  ),
                ),
                isTrue,
              );
              expect(
                find.byKey(InviteFriendsScreen.shareBarKey),
                findsOneWidget,
              );
              await _scrollTo(tester, find.byKey(InviteFriendsScreen.codeKey));
              expect(find.text('K7QM4P2X'), findsOneWidget);
              await _scrollTo(
                tester,
                find.byKey(InviteFriendsScreen.milestoneKey(15)),
              );
              expect(_textContains(tester, '1,350,000'), isTrue);
              expect(
                _textContains(tester, _plain(l10n.inviteInvitedCount('3'))),
                isTrue,
              );
              await _scrollTo(
                tester,
                find.byKey(InviteFriendsScreen.friendsKey),
              );
              expect(find.text('A***d'), findsOneWidget);
              expect(find.text(l10n.inviteStatusRejected), findsOneWidget);
              expect(tester.takeException(), isNull);
            });
          }
        }
      }
    }

    testWidgets('milestones: locked / unlocked / claimed are announced', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pump(
        tester,
        language: AppLanguage.en,
        repo: _FakeReferrals(
          page: _referral(
            states: const [
              MilestoneState.claimed,
              MilestoneState.unlocked,
              MilestoneState.locked,
            ],
          ),
        ),
      );
      await _scrollTo(tester, find.byKey(InviteFriendsScreen.milestoneKey(15)));
      for (final (friends, state) in [
        ('1 friend', _en.inviteMilestoneClaimed),
        ('5 friends', _en.inviteMilestoneUnlocked),
        ('15 friends', _en.inviteMilestoneLocked),
      ]) {
        expect(
          find.bySemanticsLabel(RegExp('Milestone $friends: .* $state')),
          findsOneWidget,
          reason: friends,
        );
      }
      semantics.dispose();
    });

    testWidgets('both sides get something: «تحصل أنت على X، ويحصل صديقك على '
        'Y»', (tester) async {
      await _pump(
        tester,
        repo: _FakeReferrals(page: _referral(inviteeSignup: 5000)),
      );
      await _scrollTo(tester, find.byKey(InviteFriendsScreen.youGetKey));
      expect(
        _textContains(
          tester,
          _plain(
            _ar.inviteYouGet(
              _ar.inviteCherries('20,000'),
              _ar.inviteCherries('5,000'),
            ),
          ),
        ),
        isTrue,
      );
    });

    testWidgets('no ticker and no friends: the ticker is hidden, the friends '
        'part says so', (tester) async {
      await _pump(
        tester,
        repo: _FakeReferrals(
          page: _referral(invited: 0, qualified: 0, pending: 0, invitees: []),
        ),
      );
      expect(find.byKey(InviteFriendsScreen.tickerKey), findsNothing);
      await _scrollTo(tester, find.byKey(InviteFriendsScreen.noFriendsKey));
      expect(find.text(_ar.inviteNoFriends), findsOneWidget);
    });

    testWidgets('«ادعُ الآن» and «مشاركة» open the share sheet with the code '
        'and link; «نسخ» copies the code; «نسخ الرابط» the link', (
      tester,
    ) async {
      final copied = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final sharer = _FakeSharer();
      await _pump(
        tester,
        repo: _FakeReferrals(page: _referral()),
        sharer: sharer,
      );
      await _scrollTo(tester, find.byKey(InviteFriendsScreen.inviteNowKey));
      await tester.tap(find.byKey(InviteFriendsScreen.inviteNowKey));
      await tester.pumpAndSettle();
      expect(sharer.shared, [
        _ar.inviteShareText('K7QM4P2X', 'https://kabsolive.com/i/K7QM4P2X'),
      ]);
      await tester.tap(find.byKey(InviteFriendsScreen.shareKey));
      await tester.pumpAndSettle();
      expect(sharer.shared, hasLength(2));
      await _scrollTo(tester, find.byKey(InviteFriendsScreen.copyKey));
      await tester.tap(find.byKey(InviteFriendsScreen.copyKey));
      await tester.pumpAndSettle();
      expect(copied.last, 'K7QM4P2X');
      expect(find.text(_ar.inviteCodeCopied), findsOneWidget);
      await tester.tap(find.byKey(InviteFriendsScreen.copyLinkKey));
      await tester.pumpAndSettle();
      expect(copied.last, 'https://kabsolive.com/i/K7QM4P2X');
    });

    testWidgets('WhatsApp: the text is handed over; when it cannot open, the '
        'link is copied and the person is told', (tester) async {
      final copied = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final sharer = _FakeSharer(whatsappOk: false);
      await _pump(
        tester,
        repo: _FakeReferrals(page: _referral()),
        sharer: sharer,
        language: AppLanguage.en,
      );
      await tester.tap(find.byKey(InviteFriendsScreen.whatsappKey));
      await tester.pumpAndSettle();
      expect(sharer.whatsapped.single, contains('K7QM4P2X'));
      expect(copied.single, 'https://kabsolive.com/i/K7QM4P2X');
      expect(find.text(_en.inviteShareFailed), findsOneWidget);
    });

    testWidgets('«?» shows the rules with the configured values', (
      tester,
    ) async {
      await _pump(tester, repo: _FakeReferrals(page: _referral()));
      await tester.tap(find.byKey(InviteFriendsScreen.helpKey));
      await tester.pumpAndSettle();
      expect(find.text(_ar.inviteRulesTitle), findsOneWidget);
      final milestones = _ar.inviteRuleMilestones(
        'صديق واحد: 50,000 كرزة\n5 أصدقاء: 300,000 كرزة\n'
        '15 صديقاً: 1,000,000 كرزة',
      );
      final ordered = [
        _ar.inviteRuleSignup('20,000'),
        _ar.inviteRuleRecharge('5%'),
        milestones,
      ];
      for (final rule in [
        ...ordered,
        _ar.inviteRuleHold('24'),
        _ar.inviteRuleCap('20'),
        _ar.inviteRuleLater('7'),
        _ar.inviteRuleFair,
        _ar.inviteRuleClawback,
      ]) {
        expect(_textContains(tester, _plain(rule)), isTrue, reason: rule);
      }
      // The three rewards come first, in this order (owner 2026-11-01).
      final tops = [
        for (final rule in ordered)
          tester
              .getTopLeft(find.textContaining(_plain(rule).substring(0, 12)))
              .dy,
      ];
      expect(tops, [...tops]..sort());
      await _capture(tester, '05-rules.ar');
    });

    testWidgets('loading, then an error with «حاول مرة أخرى» that reloads', (
      tester,
    ) async {
      final repo = _FakeReferrals(
        page: _referral(),
        failMine: const NetworkFailure.offline(),
      )..gate = Completer<void>();
      await _pump(tester, repo: repo, settle: false);
      await tester.pump();
      expect(find.byKey(InviteFriendsScreen.loadingKey), findsOneWidget);
      repo.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(InviteFriendsScreen.errorKey), findsOneWidget);
      expect(find.text(_ar.inviteErrorTitle), findsOneWidget);
      repo.failMine = null;
      await tester.tap(find.text(_ar.actionRetry));
      await tester.pumpAndSettle();
      expect(find.byKey(InviteFriendsScreen.heroKey), findsOneWidget);
      expect(repo.mineCalls, 2);
    });

    testWidgets('switched off (or an older server): the page gives way to the '
        'cherry wallet', (tester) async {
      for (final page in [_referral(enabled: false), null]) {
        await _pump(tester, repo: _FakeReferrals(page: page));
        expect(find.byKey(_walletPage), findsOneWidget);
        expect(find.text('wallet cherries'), findsOneWidget);
        expect(find.byType(InviteFriendsScreen), findsNothing);
      }
    });

    testWidgets('the programme found off is remembered for «اربح المال»', (
      tester,
    ) async {
      await _pump(
        tester,
        repo: _FakeReferrals(page: _referral(enabled: false)),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byKey(_walletPage)),
      );
      expect(container.read(referralEnabledProvider), isFalse);
    });
  });

  group('the code later (Settings › «كود الدعوة»)', () {
    Widget host() => Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => showReferralCodeSheet(context),
            child: const Text('open'),
          ),
        ),
      ),
    );

    testWidgets('within the window: the form sends the code and the install '
        'id; success says so', (tester) async {
      final repo = _FakeReferrals(
        page: _referral(),
        applyResult: _referral(
          canApply: false,
          invitedBy: ReferralStatus.pending,
        ),
      );
      await _pump(tester, repo: repo, home: host());
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text(_ar.referralApplyTitle), findsOneWidget);
      await tester.enterText(
        find.byKey(ReferralCodeSheet.fieldKey),
        ' k7qm-4p2x ',
      );
      await tester.tap(find.byKey(ReferralCodeSheet.submitKey));
      await tester.pumpAndSettle();
      expect(repo.applied.single.$1, ' k7qm-4p2x ');
      expect(repo.applied.single.$2, matches(RegExp(r'^[0-9a-f-]{36}$')));
      expect(find.text(_ar.referralApplied), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a wrong code: the server message stays in the sheet', (
      tester,
    ) async {
      final repo = _FakeReferrals(
        page: _referral(),
        applyFailure: const ServerFailure(
          code: ErrorCode.referralCodeInvalid,
          rawCode: 'REFERRAL_CODE_INVALID',
          debugMessage: 'x',
          statusCode: 422,
        ),
      );
      await _pump(
        tester,
        repo: repo,
        home: host(),
        language: AppLanguage.en,
        textScale: 1.3,
        viewport: GoldenViewport.android,
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(ReferralCodeSheet.fieldKey),
        'ZZZZZZZZ',
      );
      await tester.tap(find.byKey(ReferralCodeSheet.submitKey));
      await tester.pumpAndSettle();
      expect(find.text(_en.errorReferralCodeInvalid), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('already linked or past the window: no form', (tester) async {
      await _pump(
        tester,
        repo: _FakeReferrals(
          page: _referral(canApply: false, invitedBy: ReferralStatus.pending),
        ),
        home: host(),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byKey(ReferralCodeSheet.fieldKey), findsNothing);
      expect(find.byKey(ReferralCodeSheet.closedKey), findsOneWidget);
      expect(find.text(_ar.referralApplied), findsOneWidget);
    });
  });

  group('claw-back (the team voided a referral)', () {
    test('the notification opens the cherry wallet (inbox and push)', () {
      final type = NotificationType.fromWire('REFERRAL_REWARD_REVERSED');
      expect(type, NotificationType.referralRewardReversed);
      expect(type.isSystem, isTrue);
      expect(
        const PushPayload({
          'kind': 'notification',
          'type': 'REFERRAL_REWARD_REVERSED',
        }).route(),
        AppRoutes.walletCherries,
      );
      expect(_ar.notifReferralReversed, contains('Kabso'));
      expect(_en.notifReferralReversed, contains('cherry wallet'));
    });
  });

  group('captures (D217_CAPTURE_DIR)', () {
    testWidgets('ar 393×852 @3x: light and dark, top, middle and bottom', (
      tester,
    ) async {
      if (_captureDir.isEmpty) return;
      for (final brightness in Brightness.values) {
        await _pump(
          tester,
          repo: _FakeReferrals(page: _referral(), items: _ticker),
          brightness: brightness,
        );
        final b = brightness.name;
        await _capture(tester, '01-top.ar.$b');
        await _scrollTo(
          tester,
          find.byKey(InviteFriendsScreen.milestoneKey(15)),
        );
        await _capture(tester, '02-milestones.ar.$b');
        await _scrollTo(tester, find.byKey(InviteFriendsScreen.friendsKey));
        await _capture(tester, '03-friends.ar.$b');
      }
      await _pump(
        tester,
        repo: _FakeReferrals(
          page: _referral(invited: 0, qualified: 0, pending: 0, invitees: []),
        ),
      );
      await _capture(tester, '04-new.ar.light');
    });

    testWidgets('en 393×852 @3x: light and dark, top and milestones', (
      tester,
    ) async {
      if (_captureDir.isEmpty) return;
      for (final brightness in Brightness.values) {
        await _pump(
          tester,
          repo: _FakeReferrals(page: _referral(), items: _ticker),
          language: AppLanguage.en,
          brightness: brightness,
        );
        final b = brightness.name;
        await _capture(tester, '06-top.en.$b');
        await _scrollTo(
          tester,
          find.byKey(InviteFriendsScreen.milestoneKey(15)),
        );
        await _capture(tester, '07-milestones.en.$b');
      }
    });
  });

  group('goldens', () {
    forEachLanguage((language) {
      for (final brightness in Brightness.values) {
        testWidgets(
          'invite friends page (${language.name}, ${brightness.name})',
          tags: [goldenTag],
          (tester) async {
            await _pump(
              tester,
              repo: _FakeReferrals(page: _referral(), items: _ticker),
              language: language,
              brightness: brightness,
            );
            await expectLater(
              find.byKey(_boundary),
              matchesGoldenFile(
                '../../goldens/png/invite_friends.${brightness.name}.'
                '${language.name}.phone.png',
              ),
            );
          },
        );
      }
    });
  });
}
