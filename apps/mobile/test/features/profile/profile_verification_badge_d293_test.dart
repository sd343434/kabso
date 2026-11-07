// D293 (owner, contract v1.90-social, CONVENTIONS §10.105): the automatic
// verification badge «شارة التوثيق» — a scalloped seal drawn in code in the
// badge's colour with its white Material icon (the OWNER's a black seal with
// a gold rim and a gold brain), right after the display name.
//
// Checked: the six variants (icon, colours, rim, the spoken label in Arabic
// and English, the tooltip on a long press), the size (≈ 1.2 × the name's
// cap height), the wire values (unknown → none), the profile header (someone
// else's and the own) in both directions, and the badge row golden
// (dark / light, ar / en).
//
// With D293_CAPTURE_DIR set, the capture group writes PNGs there (not
// committed): the six seals side by side and the profile header in Arabic,
// light and dark.

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/models/verification_badge.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/profile/domain/profile_models.dart';
import 'package:kabso_live/features/profile/profile_cover_header.dart';
import 'package:kabso_live/features/profile/profile_verification_badge.dart';
import 'package:kabso_live/features/vip/presentation/vip_wear.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/golden.dart';
import 'profile_cover_d278_test.dart' show otherProfile, pumpOther;

const Map<VerificationBadge, (String, String)> _labels = {
  VerificationBadge.owner: ('موثّق: مالك التطبيق', 'Verified: app owner'),
  VerificationBadge.staff: ('موثّق: فريق كابسو', 'Verified: Kabso Team'),
  VerificationBadge.rechargeAgent: (
    'موثّق: وكيل شحن',
    'Verified: recharge agent',
  ),
  VerificationBadge.hostAgent: ('موثّق: وكيل مضيفين', 'Verified: host agent'),
  VerificationBadge.creator: ('موثّق: صانع محتوى', 'Verified: content creator'),
  VerificationBadge.verifiedHost: (
    'موثّق: مضيف موثّق الهوية',
    'Verified: identity-verified host',
  ),
};

/// The six seals, each after a sample name in the profile header's style
/// (the badge row), and the six seals large side by side.
class _BadgeRows extends StatelessWidget {
  const new({required this.ar});

  final bool ar;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.textStyles;
    final nameStyle = t.title.copyWith(
      color: p.textPrimary,
      fontSize: KPublicProfile.nameFont,
      fontWeight: FontWeight.w700,
    );
    return Column(
      key: const Key('d293.rows'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final b in VerificationBadge.values)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: KSpacing.xs),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(ar ? 'نبّ' : 'Nabb', style: nameStyle),
                const SizedBox(width: KSpacing.sm),
                ProfileVerificationBadge(
                  badge: b,
                  size: ProfileVerificationBadge.sizeForFont(
                    KPublicProfile.nameFont,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: KSpacing.lg),
        Row(
          key: const Key('d293.seals'),
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final b in VerificationBadge.values)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: KSpacing.md),
                child: ProfileVerificationBadge(badge: b, size: 44),
              ),
          ],
        ),
      ],
    );
  }
}

Future<void> _pumpBadge(
  WidgetTester tester,
  VerificationBadge badge, {
  AppLanguage language = AppLanguage.en,
}) => pumpGolden(
  tester,
  Align(
    alignment: AlignmentDirectional.topStart,
    child: ProfileVerificationBadge(badge: badge, size: 40),
  ),
  language: language,
);

void main() {
  test('the wire values; unknown is no badge', () {
    expect(VerificationBadge.values.map((b) => b.wire), [
      'OWNER',
      'STAFF',
      'RECHARGE_AGENT',
      'HOST_AGENT',
      'CREATOR',
      'VERIFIED_HOST',
    ]);
    expect(
      verificationBadgeFromJson('HOST_AGENT'),
      VerificationBadge.hostAgent,
    );
    expect(verificationBadgeFromJson('NEW_KIND'), isNull);
    expect(verificationBadgeFromJson(null), isNull);
    expect(verificationBadgeToJson(VerificationBadge.owner), 'OWNER');
    final p = PublicProfile.fromJson({
      ..._minimalProfileJson,
      'verification': 'RECHARGE_AGENT',
    });
    expect(p.verification, VerificationBadge.rechargeAgent);
    expect(PublicProfile.fromJson(_minimalProfileJson).verification, isNull);
  });

  test('about 1.0–1.1 × the name line height, at least 14', () {
    expect(ProfileVerificationBadge.sizeForFont(20), 23);
    expect(ProfileVerificationBadge.sizeForFont(18), 21);
    expect(ProfileVerificationBadge.sizeForFont(10), 14);
  });

  test('the rosette: 8 soft lobes, touching its box, symmetric', () {
    const box = Size(100, 100);
    final path = VerificationSealPainter.sealPath(box);
    final b = path.getBounds();
    expect(b.top, moreOrLessEquals(0, epsilon: 0.01));
    expect(b.width, moreOrLessEquals(b.height, epsilon: 1));
    expect(b.width, lessThanOrEqualTo(100.01));
    // A lobe's tip and a valley between two lobes: gentle (≈ 14 % deep).
    expect(path.contains(const Offset(50, 1)), isTrue);
    const valley = 50 - 50 * (1 - 0.075) / (1 + 0.075);
    const a = -math.pi / 2 + math.pi / 8;
    final inside = Offset(
      50 + math.cos(a) * (50 - valley - 1),
      50 + math.sin(a) * (50 - valley - 1),
    );
    final outside = Offset(
      50 + math.cos(a) * (50 - valley + 1),
      50 + math.sin(a) * (50 - valley + 1),
    );
    expect(path.contains(inside), isTrue);
    expect(path.contains(outside), isFalse);
  });

  for (final badge in VerificationBadge.values) {
    testWidgets('${badge.wire}: its icon, colour and label', (tester) async {
      await _pumpBadge(tester, badge);
      final icon = tester.widget<Icon>(
        find.descendant(
          of: find.byType(ProfileVerificationBadge),
          matching: find.byType(Icon),
        ),
      );
      // Owner: the same check mark in every seal; only the colour differs.
      expect(icon.icon, Icons.check_rounded);
      final owner = badge == VerificationBadge.owner;
      expect(
        icon.color,
        owner ? VerificationBadgeColors.ownerGold : const Color(0xFFFFFFFF),
      );
      final paint = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byType(ProfileVerificationBadge),
          matching: find.byType(CustomPaint),
        ),
      );
      final painter = paint.painter! as VerificationSealPainter;
      expect(painter.fill, VerificationBadgeColors.sealOf(badge));
      expect(painter.rim, owner ? VerificationBadgeColors.ownerGold : isNull);
      expect(tester.getSize(find.byType(CustomPaint).last), const Size(40, 40));
      // The spoken label, English then Arabic.
      expect(find.bySemanticsLabel(_labels[badge]!.$2), findsOneWidget);
      await tester.longPress(find.byType(ProfileVerificationBadge));
      await tester.pumpAndSettle();
      expect(
        find.text('${_labels[badge]!.$2}\nGranted automatically by conditions'),
        findsOneWidget,
      );
      await _pumpBadge(tester, badge, language: AppLanguage.ar);
      expect(find.bySemanticsLabel(_labels[badge]!.$1), findsOneWidget);
    });
  }

  test('the colours are distinct; the OWNER is black with gold', () {
    final fills = VerificationBadge.values
        .map(VerificationBadgeColors.sealOf)
        .toSet();
    expect(fills, hasLength(6));
    expect(
      VerificationBadgeColors.sealOf(VerificationBadge.owner).r,
      0x11 / 255,
    );
    expect(
      VerificationBadge.values.where(
        (b) => VerificationBadgeColors.rimOf(b) != null,
      ),
      [VerificationBadge.owner],
    );
  });

  group('the profile header', () {
    for (final language in AppLanguage.values) {
      final ar = language == AppLanguage.ar;
      testWidgets(
        'right after the name, before the VIP badge (${language.name})',
        (tester) async {
          await pumpOther(
            tester,
            otherProfile(ar: ar)
                .copyWith(verification: VerificationBadge.rechargeAgent),
            language: language,
          );
          expect(tester.takeException(), isNull);
          final name = tester.getRect(
            find.byKey(const Key('profile.displayName')),
          );
          final seal = tester.getRect(
            find.byKey(ProfileVerificationBadge.badgeKey),
          );
          final vip = tester.getRect(find.byType(VipNameBadge));
          expect(seal.center.dy, moreOrLessEquals(name.center.dy, epsilon: 4));
          expect(
            seal.width,
            ProfileVerificationBadge.sizeForFont(KPublicProfile.nameFont),
          );
          if (ar) {
            // Right to left: the seal is to the left of the name, the VIP badge
            // further left.
            expect(seal.right, lessThan(name.left));
            expect(vip.right, lessThanOrEqualTo(seal.left));
          } else {
            expect(seal.left, greaterThan(name.right));
            expect(vip.left, greaterThanOrEqualTo(seal.right));
          }
          expect(
            find.bySemanticsLabel(_labels[VerificationBadge.rechargeAgent]!.$1),
            ar ? findsOneWidget : findsNothing,
          );
        },
      );
    }

    for (final language in AppLanguage.values) {
      testWidgets('fits the name row at 360 × 800 and text scale 1.3 '
          '(${language.name})', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await pumpOther(
          tester,
          otherProfile(ar: language == AppLanguage.ar)
              .copyWith(verification: VerificationBadge.owner),
          language: language,
          viewport: GoldenViewport.android,
        );
        expect(tester.takeException(), isNull);
        final name = tester.getRect(
          find.byKey(const Key('profile.displayName')),
        );
        final seal = tester.getRect(
          find.byKey(ProfileVerificationBadge.badgeKey),
        );
        final row = tester.getRect(find.byKey(ProfileCoverHeader.nameRowKey));
        expect(seal.left, greaterThanOrEqualTo(0));
        expect(seal.right, lessThanOrEqualTo(360));
        expect(seal.top, greaterThanOrEqualTo(row.top));
        expect(seal.bottom, lessThanOrEqualTo(row.bottom));
        // On the name's own line, vertically centred with it.
        expect(seal.center.dy, moreOrLessEquals(name.center.dy, epsilon: 4));
      });
    }

    testWidgets('no badge without one', (tester) async {
      await pumpOther(tester, otherProfile(ar: true), language: AppLanguage.ar);
      expect(find.byType(ProfileVerificationBadge), findsNothing);
      expect(find.byKey(ProfileCoverHeader.nameRowKey), findsOneWidget);
    });
  });

  group('golden', () {
    for (final language in AppLanguage.values) {
      for (final brightness in Brightness.values) {
        final tag = '${language.name}.${brightness.name}';
        testWidgets('verification badge rows $tag', tags: [goldenTag], (
          tester,
        ) async {
          await pumpGolden(
            tester,
            _BadgeRows(ar: language == AppLanguage.ar),
            language: language,
            brightness: brightness,
          );
          await expectLater(
            find.byKey(const Key('d293.rows')),
            matchesGoldenFile('../../goldens/png/verification_badges.$tag.png'),
          );
        });
      }
    }
  });

  final captureDir = Platform.environment['D293_CAPTURE_DIR'];
  group('D293 captures', skip: captureDir == null, () {
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
      for (final language in AppLanguage.values) {
        testWidgets('seals ${language.name} ${brightness.name}', (
          tester,
        ) async {
          await pumpGolden(
            tester,
            _BadgeRows(ar: language == AppLanguage.ar),
            language: language,
            brightness: brightness,
          );
          await capture(tester, 'seals.${language.name}.${brightness.name}');
        });
      }
      testWidgets('header ar 360 1.3 ${brightness.name}', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await pumpOther(
          tester,
          otherProfile(ar: true)
              .copyWith(verification: VerificationBadge.owner),
          language: AppLanguage.ar,
          brightness: brightness,
          viewport: GoldenViewport.android,
        );
        await capture(tester, 'header.ar.360x1_3.${brightness.name}.owner');
      });
      for (final badge in [
        VerificationBadge.owner,
        VerificationBadge.rechargeAgent,
        VerificationBadge.verifiedHost,
      ]) {
        testWidgets('header ar ${brightness.name} ${badge.wire}', (
          tester,
        ) async {
          await pumpOther(
            tester,
            otherProfile(ar: true).copyWith(verification: badge),
            language: AppLanguage.ar,
            brightness: brightness,
          );
          await capture(
            tester,
            'header.ar.${brightness.name}.${badge.wire.toLowerCase()}',
          );
        });
      }
    }
  });
}

const Map<String, Object?> _minimalProfileJson = {
  'id': 'u1',
  'username': 'layla',
  'displayName': 'Layla',
  'avatarUrl': null,
  'bio': null,
  'isPrivate': false,
  'followerCount': 0,
  'followingCount': 0,
  'isFollowing': false,
  'isSelf': false,
  'liveRoomId': null,
};
