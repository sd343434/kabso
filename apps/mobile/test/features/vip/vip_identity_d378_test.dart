// D378 (owner 2026-11-11, contract v1.131-social, CONVENTIONS §10.168): the
// VIP identity perks in the app — POST_BADGE after the name on posts, reels
// and comments, ANIMATED_SIGNATURE under posts and public messages,
// STORY_RING in the tray and the viewer, GLOWING_NAME in the live chat
// (reduce motion: a steady glow), DM_BUBBLE (the tier's chat bubble in
// direct messages), ANIMATED_COVER on the profile, GOLDEN_ID as the gold
// special-ID pill, and «هويتي المميزة» (the signature, the golden ID pick and
// the VIP premium username). Each shows only for a member whose tier — or a
// lower one (D258's inheritance) — holds the perk. Goldens: 393 × 852,
// insets 59 / 34, real fonts, a pinned clock, test-only stand-in art (a
// generated gradient); ar / en, light / dark.

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/core/models/premium_tier.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/home/presentation/widgets/feed_stories_tray.dart';
import 'package:kabso_live/features/messages/domain/dm_models.dart';
import 'package:kabso_live/features/messages/widgets/dm_message_view.dart';
import 'package:kabso_live/features/premium/domain/premium_models.dart';
import 'package:kabso_live/features/vip/application/vip_look.dart';
import 'package:kabso_live/features/vip/application/vip_providers.dart';
import 'package:kabso_live/features/vip/data/vip_identity_repository.dart';
import 'package:kabso_live/features/vip/data/vip_repository.dart';
import 'package:kabso_live/features/vip/presentation/vip_identity.dart';
import 'package:kabso_live/features/vip/presentation/vip_identity_screen.dart';
import 'package:kabso_live/features/vip/presentation/vip_parts.dart';
import 'package:kabso_live/features/vip/presentation/vip_wear.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/fixture_images.dart';
import '../../helpers/golden.dart';

final DateTime _now = DateTime.utc(2026, 11, 11, 9, 30);

VipPerk _p(String code, {Object? value, String? still}) => VipPerk(
  code: code,
  title: code,
  available: true,
  value: value,
  still: still,
  artWidth: still == null ? null : 1080,
  artHeight: still == null ? null : 720,
);

/// VIP_0 holds only the BADGE (a member without the identity perks); VIP_1
/// holds the look perks; VIP_2 adds the cover, the golden ID and the
/// premium username and inherits the rest.
VipTierList _catalog() => VipTierList(
  tiers: [
    VipTier(
      id: 't0',
      code: 'VIP_0',
      name: 'VIP 0',
      level: 1,
      color: 0xFF5B6B7A,
      priceCoins: 100,
      durationDays: 30,
      perks: [_p(VipPerks.badge)],
    ),
    VipTier(
      id: 't1',
      code: 'VIP_1',
      name: 'VIP 1',
      level: 2,
      color: 0xFF2E8B3D,
      priceCoins: 1000,
      durationDays: 30,
      perks: [
        _p(VipPerks.postBadge),
        _p(VipPerks.signature),
        _p(VipPerks.storyRing, value: '#E94BA0'),
        _p(VipPerks.glowingName),
        _p(VipPerks.dmBubble),
      ],
    ),
    VipTier(
      id: 't2',
      code: 'VIP_2',
      name: 'VIP 2',
      level: 3,
      color: 0xFF7B3FE4,
      priceCoins: 5000,
      durationDays: 30,
      perks: [
        _p(VipPerks.animatedCover, still: 'https://cdn.test/vip/cover.png'),
        _p(VipPerks.goldenId, value: 'FOUR_DIGIT'),
        _p(VipPerks.premiumUsername, value: 'GOLD'),
      ],
    ),
  ],
  maxAheadDays: 400,
);

const _vip0 = UserVip(tier: 'VIP_0', rank: 1, color: 0xFF5B6B7A);
const _vip1 = UserVip(
  tier: 'VIP_1',
  rank: 2,
  color: 0xFF2E8B3D,
  signature: 'نجمة كابسو',
);
const _vip2 = UserVip(
  tier: 'VIP_2',
  rank: 3,
  color: 0xFF7B3FE4,
  signature: 'Kabso star',
);

/// A non-holder (VIP_0) with a signature stored: never shown.
const _vip0Signed = UserVip(
  tier: 'VIP_0',
  rank: 1,
  color: 0xFF5B6B7A,
  signature: 'hidden',
);

DmMessage _dm(String id, {required bool mine, required String text}) =>
    DmMessage(
      id: id,
      conversationId: 'c1',
      senderId: mine ? 'me' : 'peer',
      mine: mine,
      kind: DmMessageKind.text,
      text: text,
      createdAt: _now,
      expiresAt: _now.add(const Duration(hours: 24)),
    );

class _FakeIdentity implements VipIdentityRepository {
  final List<String?> signatures = [];
  final List<String> claimed = [];
  final List<String> premium = [];
  int released = 0;

  @override
  Future<String?> setSignature(String? signature) async {
    signatures.add(signature);
    return signature?.trim();
  }

  @override
  Future<VipGoldenIdChoice> goldenIds() async => VipGoldenIdChoice(
    goldenClass: 'FOUR_DIGIT',
    mine: claimed.isEmpty
        ? null
        : VipGoldenIdHolding(
            number: claimed.last,
            goldenClass: 'FOUR_DIGIT',
            grace: false,
            heldUntil: _now.add(const Duration(days: 30)),
          ),
    available: const ['2026', '1234', '5678'],
  );

  @override
  Future<VipGoldenIdHolding> claimGoldenId(String number) async {
    claimed.add(number);
    return VipGoldenIdHolding(
      number: number,
      goldenClass: 'FOUR_DIGIT',
      grace: false,
    );
  }

  @override
  Future<void> releaseGoldenId() async => released++;

  @override
  Future<MyPremiumUsername> claimPremiumUsername(String username) async {
    premium.add(username);
    return MyPremiumUsername(
      username: username,
      tier: PremiumTier.gold,
      grace: false,
      granted: false,
      startedAt: _now,
      expiresAt: _now.add(const Duration(days: 30)),
      graceUntil: null,
      regularUsername: 'layla',
      renewPriceCoins: null,
      canRenew: false,
    );
  }

  @override
  Future<({PremiumTier? vipTier, List<PremiumNameStatus> names})>
  premiumChoice() async => (
    vipTier: PremiumTier.gold,
    names: const [
      PremiumNameStatus(
        username: 'kk',
        tier: PremiumTier.gold,
        state: PremiumNameState.notForSale,
        priceCoins: null,
        periodDays: 30,
      ),
    ],
  );
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  AppLanguage language = AppLanguage.en,
  Brightness brightness = Brightness.dark,
  List<Override> overrides = const [],
  bool disableAnimations = true,
  bool home = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      retry: (_, _) => null,
      overrides: [
        vipCatalogProvider.overrideWith((ref) async => _catalog()),
        vipTiersProvider.overrideWith((ref) async => _catalog()),
        currentUserProvider.overrideWithValue(null),
        ...overrides,
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: language.locale,
        supportedLocales: KabsoApp.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        theme: buildAppTheme(brightness: brightness, locale: language.locale),
        builder: (context, app) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(disableAnimations: disableAnimations),
          child: app!,
        ),
        home: home ? child : Scaffold(body: child),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

/// Every perk at once, as the composite golden shows them.
class _Showcase extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final t = context.textStyles;
    final p = context.palette;
    Widget label(String s) => Padding(
      padding: const EdgeInsets.only(top: KSpacing.md, bottom: KSpacing.xs),
      child: Text(s, style: t.caption.copyWith(color: p.textSecondary)),
    );
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 59, 16, 34),
      children: [
        // ANIMATED_COVER: the tier's art over the own cover.
        SizedBox(
          height: 120,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(KRadius.lg),
            child: const Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: Color(0xFF333344)),
                VipAnimatedCover(vip: _vip2),
              ],
            ),
          ),
        ),
        const SizedBox(height: KSpacing.sm),
        // GOLDEN_ID + POST_BADGE after a name.
        Row(
          children: [
            Text(ar ? 'ليلى' : 'Layla', style: t.bodyStrong),
            const SizedBox(width: 4),
            const VipNameBadge(
              vip: _vip2,
              height: 16,
              perk: VipPerks.postBadge,
            ),
            const SizedBox(width: KSpacing.sm),
            const VipGoldenIdChip(
              goldenId: UserGoldenId(number: '8888', goldenClass: 'REPEATED'),
              height: 20,
            ),
          ],
        ),
        label('ANIMATED_SIGNATURE'),
        const Align(
          alignment: AlignmentDirectional.centerStart,
          child: VipSignatureLine(vip: _vip1),
        ),
        label('STORY_RING'),
        FeedStoriesTray(
          stories: [
            FeedStoryData(
              authorName: ar ? 'ليلى' : 'Layla',
              authorAvatar: fixtureImage(
                top: const Color(0xFFE9A0B0),
                bottom: const Color(0xFF8A3050),
              ),
              username: 'layla',
              vip: _vip1,
            ),
            FeedStoryData(
              authorName: ar ? 'عمر' : 'Omar',
              authorAvatar: fixtureImage(
                top: const Color(0xFFA0C0E9),
                bottom: const Color(0xFF305080),
              ),
              username: 'omar',
              vip: _vip1,
              seen: true,
            ),
            FeedStoryData(
              authorName: ar ? 'هدى' : 'Huda',
              username: 'huda',
              vip: _vip0,
            ),
          ],
        ),
        label('GLOWING_NAME'),
        DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF14101C),
            borderRadius: BorderRadius.circular(KRadius.md),
          ),
          child: Padding(
            padding: const EdgeInsets.all(KSpacing.sm),
            child: Row(
              children: [
                VipGlowingName(
                  vip: _vip1,
                  child: Text(
                    ar ? 'ليلى' : 'Layla',
                    style: t.bodyStrong.copyWith(
                      color: vipNameTint(const Color(0xFF2E8B3D)),
                    ),
                  ),
                ),
                Text(
                  ar ? ': مرحباً بالجميع' : ': hello everyone',
                  style: t.body.copyWith(color: const Color(0xFFFFFFFF)),
                ),
              ],
            ),
          ),
        ),
        label('DM_BUBBLE'),
        DmMessageView(
          message: _dm('m1', mine: false, text: ar ? 'أهلاً!' : 'Hi there!'),
          peerName: 'Layla',
          vip: _vip1,
        ),
        DmMessageView(
          message: _dm(
            'm2',
            mine: true,
            text: ar ? 'كيف حالك؟' : 'How are you?',
          ),
          peerName: 'Layla',
        ),
      ],
    );
  }
}

void main() {
  setUp(() {
    vipImageFor = (_) => fixtureImage(
      top: const Color(0xFF7B3FE4),
      bottom: const Color(0xFFE94BA0),
      width: 108,
      height: 72,
    );
  });
  tearDown(() => vipImageFor = NetworkImage.new);

  group('D378 wire', () {
    test('UserVip.signature is read and written; blank is none', () {
      final vip = userVipFromJson({
        'tier': 'VIP_1',
        'rank': 2,
        'color': '#2E8B3D',
        'signature': 'Kabso star',
      })!;
      expect(vip.signature, 'Kabso star');
      expect(userVipToJson(vip)!['signature'], 'Kabso star');
      expect(
        userVipFromJson({
          'tier': 'VIP_1',
          'rank': 2,
          'color': '#2E8B3D',
          'signature': '  ',
        })!.signature,
        isNull,
      );
    });

    test('UserGoldenId: {number, class}; anything else is none', () {
      expect(
        userGoldenIdFromJson({'number': '8888', 'class': 'REPEATED'}),
        const UserGoldenId(number: '8888', goldenClass: 'REPEATED'),
      );
      expect(userGoldenIdFromJson({'number': '0888', 'class': 'X'}), isNull);
      expect(userGoldenIdFromJson(null), isNull);
      final summary = UserSummary.fromJson({
        'id': 'u1',
        'username': 'layla',
        'displayName': 'Layla',
        'avatarUrl': null,
        'goldenId': {'number': '2026', 'class': 'FOUR_DIGIT'},
      });
      expect(summary.goldenId?.number, '2026');
      expect(summary.toJson()['goldenId'], {
        'number': '2026',
        'class': 'FOUR_DIGIT',
      });
    });

    test('the VIP premium medal claims its own and lower ones', () {
      expect(vipPremiumClaimAllows(PremiumTier.gold, PremiumTier.silver), true);
      expect(vipPremiumClaimAllows(PremiumTier.gold, PremiumTier.gold), true);
      expect(vipPremiumClaimAllows(PremiumTier.gold, PremiumTier.ruby), false);
      expect(vipPremiumClaimAllows(PremiumTier.legend, PremiumTier.ruby), true);
    });
  });

  group('D378 the look (inheritance)', () {
    test('signature and ring only for a holder; VIP_2 inherits VIP_1', () {
      final c = _catalog();
      expect(vipLookOf(_vip1, c)!.signature, 'نجمة كابسو');
      expect(vipLookOf(_vip2, c)!.signature, 'Kabso star');
      expect(vipLookOf(_vip0Signed, c)!.signature, isNull);
      expect(vipLookOf(_vip1, c)!.storyRingColor, const Color(0xFFE94BA0));
      expect(vipLookOf(_vip0, c)!.storyRingColor, isNull);
      expect(vipStoryRingColors(vipLookOf(_vip0, c)), isNull);
      expect(vipStoryRingColors(vipLookOf(_vip2, c)), hasLength(4));
      // The perks of a higher tier are not a lower tier's.
      expect(vipLookOf(_vip1, c)!.has(VipPerks.goldenId), false);
      expect(VipIdentityScreen.hasAny(vipLookOf(_vip1, c)), true);
      expect(VipIdentityScreen.hasAny(vipLookOf(_vip0, c)), false);
      // A store-only look (no membership) holds nothing here.
      expect(vipLookOf(const UserVip.storeOnly({}), c)?.signature, isNull);
    });
  });

  group('D378 widgets: holder vs non-holder', () {
    testWidgets('POST_BADGE after the name: holder (inherited) only', (
      tester,
    ) async {
      await _pump(
        tester,
        const Column(
          children: [
            VipNameBadge(
              key: Key('a'),
              vip: _vip2,
              height: 16,
              perk: VipPerks.postBadge,
            ),
            VipNameBadge(
              key: Key('b'),
              vip: _vip0,
              height: 16,
              perk: VipPerks.postBadge,
            ),
            VipNameBadge(
              key: Key('c'),
              vip: null,
              height: 16,
              perk: VipPerks.postBadge,
            ),
          ],
        ),
      );
      expect(find.byKey(VipNameBadge.badgeKey), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('a')),
          matching: find.byKey(VipNameBadge.badgeKey),
        ),
        findsOneWidget,
      );
      expect(find.text('VIP3'), findsOneWidget);
    });

    testWidgets('ANIMATED_SIGNATURE: shown for a holder only', (tester) async {
      await _pump(
        tester,
        const Column(
          children: [
            VipSignatureLine(vip: _vip1),
            VipSignatureLine(vip: _vip0Signed),
            VipSignatureLine(vip: null),
          ],
        ),
      );
      expect(find.byKey(VipSignatureLine.signatureKey), findsOneWidget);
      expect(find.textContaining('نجمة كابسو'), findsOneWidget);
      expect(find.textContaining('hidden'), findsNothing);
    });

    testWidgets('STORY_RING: the tray rings a holder; others keep theirs', (
      tester,
    ) async {
      await _pump(
        tester,
        const FeedStoriesTray(
          stories: [
            FeedStoryData(authorName: 'A', username: 'a', vip: _vip1),
            FeedStoryData(authorName: 'B', username: 'b', vip: _vip0),
            FeedStoryData(authorName: 'C', username: 'c'),
          ],
        ),
      );
      expect(find.byKey(VipStoryRing.ringKey), findsOneWidget);
      expect(find.byType(KAvatar), findsNWidgets(3));
    });

    testWidgets('GLOWING_NAME: a holder glows; reduce motion is still', (
      tester,
    ) async {
      VipAnimatedArt.animationsEnabled = true;
      addTearDown(() => VipAnimatedArt.animationsEnabled = false);
      await _pump(
        tester,
        const Column(
          children: [
            VipGlowingName(vip: _vip1, child: Text('glow')),
            VipGlowingName(vip: _vip0, child: Text('plain')),
          ],
        ),
      );
      expect(find.byKey(VipGlowingName.glowKey), findsOneWidget);
      // Reduce motion: the glow is there, nothing runs.
      expect(tester.hasRunningAnimations, false);
      // Motion allowed: it breathes.
      await _pump(
        tester,
        const VipGlowingName(vip: _vip1, child: Text('glow')),
        disableAnimations: false,
      );
      expect(tester.hasRunningAnimations, true);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('DM_BUBBLE: a holder writes in the tier bubble', (
      tester,
    ) async {
      await _pump(
        tester,
        Column(
          children: [
            DmMessageView(
              message: _dm('1', mine: false, text: 'vip'),
              peerName: 'x',
              vip: _vip2,
            ),
            DmMessageView(
              message: _dm('2', mine: false, text: 'plain'),
              peerName: 'x',
              vip: _vip0,
            ),
            DmMessageView(
              message: _dm('3', mine: true, text: 'mine'),
              peerName: 'x',
            ),
          ],
        ),
      );
      expect(find.byKey(const Key('dm.bubble.vip')), findsOneWidget);
      expect(
        find.ancestor(
          of: find.text('vip'),
          matching: find.byKey(const Key('dm.bubble.vip')),
        ),
        findsOneWidget,
      );
    });

    testWidgets('ANIMATED_COVER and GOLDEN_ID', (tester) async {
      await _pump(
        tester,
        const Column(
          children: [
            SizedBox(height: 100, child: VipAnimatedCover(vip: _vip2)),
            SizedBox(height: 100, child: VipAnimatedCover(vip: _vip1)),
            VipGoldenIdChip(
              goldenId: UserGoldenId(number: '8888', goldenClass: 'REPEATED'),
            ),
            VipGoldenIdChip(goldenId: null),
          ],
        ),
      );
      expect(find.byKey(VipAnimatedCover.coverKey), findsOneWidget);
      expect(find.byKey(VipGoldenIdChip.chipKey), findsOneWidget);
      expect(
        VipGoldenIdChip.label(
          const UserGoldenId(number: '8888', goldenClass: 'REPEATED'),
        ),
        'ID 8888',
      );
    });
  });

  group('D378 «هويتي المميزة»', () {
    List<Override> member(String code, int color, _FakeIdentity repo) => [
      myVipProvider.overrideWith(
        (ref) async => VipMembership(
          tierId: 't',
          tierCode: code,
          tierName: code,
          tierColor: color,
          onSale: true,
          startedAt: _now,
          expiresAt: _now.add(const Duration(days: 30)),
          daysLeft: 30,
        ),
      ),
      vipIdentityRepositoryProvider.overrideWithValue(repo),
    ];

    testWidgets('a VIP_2 member sets the signature, picks a golden ID and '
        'claims a premium username', (tester) async {
      setViewport(tester, GoldenViewport.phone);
      final repo = _FakeIdentity();
      await _pump(
        tester,
        const VipIdentityScreen(),
        home: true,
        overrides: member('VIP_2', 0xFF7B3FE4, repo),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(VipIdentityScreen.signatureFieldKey),
        ' Kabso star ',
      );
      await tester.pump();
      await tester.tap(find.byKey(VipIdentityScreen.signatureSaveKey));
      await tester.pumpAndSettle();
      expect(repo.signatures, [' Kabso star ']);
      expect(find.byKey(VipSignatureLine.signatureKey), findsOneWidget);

      await tester.scrollUntilVisible(
        find.byKey(VipIdentityScreen.goldenNumberKey('2026')),
        100,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.byKey(VipIdentityScreen.goldenNumberKey('2026')));
      await tester.pumpAndSettle();
      expect(repo.claimed, ['2026']);
      expect(find.byKey(VipGoldenIdChip.chipKey), findsOneWidget);
      await tester.tap(find.byKey(VipIdentityScreen.goldenReleaseKey));
      await tester.pumpAndSettle();
      expect(repo.released, 1);
      // The snack bar would cover the next card.
      tester
          .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
          .removeCurrentSnackBar();
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(VipIdentityScreen.premiumNameKey('kk')),
        100,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.ensureVisible(
        find.byKey(VipIdentityScreen.premiumNameKey('kk')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(VipIdentityScreen.premiumNameKey('kk')));
      await tester.pumpAndSettle();
      expect(repo.premium, ['kk']);
    });

    testWidgets('a VIP_1 member sees only the signature card; VIP_0 none', (
      tester,
    ) async {
      final repo = _FakeIdentity();
      await _pump(
        tester,
        const VipIdentityScreen(),
        home: true,
        overrides: member('VIP_1', 0xFF2E8B3D, repo),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(VipIdentityScreen.signatureFieldKey), findsOneWidget);
      expect(find.byKey(VipIdentityScreen.goldenCardKey), findsNothing);
      expect(find.byKey(VipIdentityScreen.premiumCardKey), findsNothing);

      await _pump(
        tester,
        const VipIdentityScreen(),
        home: true,
        overrides: member('VIP_0', 0xFF5B6B7A, repo),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(VipIdentityScreen.noneKey), findsOneWidget);
    });

    testWidgets('no membership (ended): nothing to set', (tester) async {
      await _pump(
        tester,
        const VipIdentityScreen(),
        home: true,
        overrides: [
          myVipProvider.overrideWith((ref) async => null),
          vipIdentityRepositoryProvider.overrideWithValue(_FakeIdentity()),
        ],
      );
      await tester.pumpAndSettle();
      expect(find.byKey(VipIdentityScreen.noneKey), findsOneWidget);
    });
  });

  group('D378 goldens', () {
    for (final language in [AppLanguage.ar, AppLanguage.en]) {
      for (final brightness in Brightness.values) {
        testWidgets('identity perks ${language.name} ${brightness.name}', (
          tester,
        ) async {
          await withClock(Clock.fixed(_now), () async {
            await loadAppFonts();
            setViewport(tester, GoldenViewport.phone);
            await _pump(
              tester,
              const _Showcase(),
              language: language,
              brightness: brightness,
            );
            await precacheImages(tester);
            await expectLater(
              find.byType(_Showcase),
              matchesGoldenFile(
                'png/vip.d378.identity.${language.name}.'
                '${brightness.name}.phone.png',
              ),
            );
          });
        });
      }
    }
  });
}
