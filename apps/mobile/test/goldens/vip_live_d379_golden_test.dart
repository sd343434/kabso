// D379 (v1.132-social, CONVENTIONS §10.169): the VIP perks inside live rooms.
//
//   room.vip_live.<ar|en>     the room's VIP perks on the dark background:
//                             the VIP room lock on a card, the
//                             host's greeting card «VIP n دخل البث» with «رحّب»,
//                             seats with the crown, a VIP seat emoji and a seat
//                             kept for a friend, the pinned message with its
//                             time bar, the coin rain (one frame) and the lock
//                             sheet
//   setup.vip_live.<ar|en>.<light|dark>   the holder's own controls: «غرفة VIP»
//                             with its tiers, the VIP seat-emoji row and the
//                             «قفل المقعد لصديق» field
//
// 393 × 852 with the status bar 59 and the home indicator 34; the clock is
// pinned (2026-11-12 09:30 UTC). The art is test-only stand-in art
// (test/fixtures/vip/d379_*_standin.png), never the owner's. Regenerate on
// Linux with the pinned Flutter:
//   flutter test --update-goldens test/goldens/vip_live_d379_golden_test.dart
@Tags(['golden'])
library;

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/domain/live_vip.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_vip_perks.dart';
import 'package:kabso_live/features/vip/application/vip_look.dart';
import 'package:kabso_live/features/vip/application/vip_providers.dart';
import 'package:kabso_live/features/vip/data/vip_repository.dart';
import 'package:kabso_live/features/vip/presentation/vip_parts.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../fixtures/vip/vip_live_d379_fixtures.dart';
import '../helpers/golden.dart';

final _mine = VipMembership(
  tierId: 'id-VIP_2',
  tierCode: 'VIP_2',
  tierName: 'VIP 2',
  tierColor: 0xFF1E6FD9,
  onSale: true,
  startedAt: DateTime.utc(2026, 11, 2),
  expiresAt: DateTime.utc(2026, 12, 2),
  daysLeft: 19,
);

List<Override> _overrides() => [
  vipCatalogProvider.overrideWith((ref) async => d379Catalog),
  myVipLivePerksProvider.overrideWith((ref) async => d379MyPerks),
  myVipProvider.overrideWith((ref) async => _mine),
];

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  required AppLanguage language,
  Brightness brightness = Brightness.dark,
}) async {
  await loadAppFonts();
  setViewport(tester, GoldenViewport.phone);
  tester.view.padding = const FakeViewPadding(
    top: 59 * GoldenViewport.pixelRatio,
    bottom: 34 * GoldenViewport.pixelRatio,
  );
  addTearDown(tester.view.resetPadding);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: _overrides(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: language.locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: const [Locale('ar'), Locale('en')],
        theme: buildAppTheme(brightness: brightness, locale: language.locale),
        builder: (context, app) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: app!,
        ),
        home: child,
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  await precacheImages(tester);
}

/// A seat: the picture (initials), the crown above it, the name under it.
class _Seat extends StatelessWidget {
  const new({required this.name, this.vip, this.emoji = false});

  final String name;
  final UserVip? vip;
  final bool emoji;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 76,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 78,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              KAvatar(name: name, imageUrl: null),
              Positioned(
                top: 0,
                child: LiveVipSeatCrown(vip: vip, picture: 42),
              ),
              if (emoji)
                const Positioned(
                  bottom: 6,
                  child: SizedBox.square(
                    dimension: 40,
                    child: VipSeatEmojiArt(art: d379EmojiUrl),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.textStyles.caption.copyWith(
            color: const Color(0xFFFFFFFF),
          ),
        ),
      ],
    ),
  );
}

class _Room extends StatelessWidget {
  const new({required this.ar});

  final bool ar;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pin = LiveChatPin.fromJson(
      d379PinJson(text: ar ? 'أهلاً بالجميع، نورتوا الغرفة' : 'Welcome all!'),
    );
    const tier = LiveVipMinTier(code: 'VIP_2', name: 'VIP 2', color: '#1E6FD9');
    return Scaffold(
      backgroundColor: const Color(0xFF1B1030),
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF2A1650), Color(0xFF120A22)],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: KSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        ar ? 'سهرة VIP' : 'VIP night',
                        style: context.textStyles.title.copyWith(
                          color: const Color(0xFFFFFFFF),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const LiveVipRoomBadge(tier: tier),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LiveVipGreetingCard(
                    user: d379User(
                      'u-layan',
                      ar ? 'ليان' : 'Layan',
                      vip: d379Vip2,
                    ),
                    onGreet: () {},
                    onClose: () {},
                  ),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _Seat(name: ar ? 'المضيف' : 'Host', vip: d379Vip2),
                      _Seat(name: ar ? 'سارة' : 'Sara', vip: d379Vip1),
                      _Seat(name: ar ? 'عمر' : 'Omar', emoji: true),
                      Column(
                        children: [
                          const SizedBox(height: 14),
                          LiveVipReservedSeat(
                            reservation: LiveSeatReservation(
                              user: d379User('u-f', ar ? 'هدى' : 'Huda'),
                              until: d379Now,
                            ),
                            picture: 50,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  LiveVipPinBar(
                    pin: pin,
                    left: const Duration(seconds: 18),
                    onRemove: () {},
                  ),
                  const Spacer(),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1426),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const LiveVipLockSheet(tierName: 'VIP 2'),
                  ),
                  Text(
                    l10n.errorLiveVipOnly,
                    style: context.textStyles.caption.copyWith(
                      color: const Color(0x99FFFFFF),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // The rain's frame in the empty band (so the perks above stay
          // legible in the golden; in a room it covers the whole screen).
          Positioned(
            left: 0,
            right: 0,
            top: 420,
            height: 300,
            child: IgnorePointer(
              child: LiveVipCoinRain(
                rain: VipGiftRain.fromJson(d379RainJson(still: d379CoinUrl)),
                progress: 0.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Setup extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(KSpacing.lg),
        children: [
          LiveVipRoomPicker(value: 'VIP_2', onChanged: (_) {}),
          const SizedBox(height: KSpacing.lg),
          LiveVipSeatEmojiRow(onPick: (_, _) {}),
          const SizedBox(height: KSpacing.lg),
          Text(
            context.l10n.liveVipReserveTitle,
            style: context.textStyles.title,
          ),
          const SizedBox(height: KSpacing.sm),
          TextField(
            decoration: InputDecoration(
              labelText: context.l10n.liveVipReserveHint,
              prefixText: '@',
            ),
          ),
        ],
      ),
    ),
  );
}

void main() {
  setUp(() => vipImageFor = (src) => MemoryImage(d379ArtFor(src)));
  tearDown(() => vipImageFor = NetworkImage.new);

  forEachLanguage((language) {
    testWidgets('room VIP perks ($language)', (tester) async {
      await withClock(Clock.fixed(d379Now), () async {
        await _pump(
          tester,
          _Room(ar: language == AppLanguage.ar),
          language: language,
        );
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('png/room.vip_live.${language.name}.phone.png'),
        );
      });
    });

    for (final brightness in Brightness.values) {
      testWidgets('holder setup ($language ${brightness.name})', (
        tester,
      ) async {
        await withClock(Clock.fixed(d379Now), () async {
          await _pump(
            tester,
            const _Setup(),
            language: language,
            brightness: brightness,
          );
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
              'png/setup.vip_live.${language.name}.${brightness.name}'
              '.phone.png',
            ),
          );
        });
      });
    }
  });
}
