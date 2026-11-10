// KL-352 E: an «info / campaign» event page assembled only from blocks.
// The texts are admin content (made up for the capture), not app strings.
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/programs/presentation/event_blocks.dart';
import 'package:kabso_live/features/programs/presentation/event_concepts.dart';
import 'package:material_ui/material_ui.dart';

import 'capture.dart';
import 'data.dart';

List<Widget> _blocks() => [
  Stack(
    children: [
      EbHero(
        image: MemoryImage(bgBytes),
        title: 'نجوم كابسو',
        subtitle: 'حملة المضيفين الجدد · نوفمبر 2026',
      ),
      const Positioned.fill(child: HeroChrome(ribbonTop: 200)),
    ],
  ),
  const EbSectionTitle('عن الحملة'),
  const SizedBox(height: KSpacing.md),
  const EbParagraph(
    'ابدأ بثك على كابسو لايف وانضم إلى نخبة المضيفين. نوفر لك '
    'الدعم والظهور والمكافآت من أول يوم، فقط التزم بساعات البث الأسبوعية.',
  ),
  const SizedBox(height: KSpacing.xl),
  const EbIconGrid([
    EbIconItem(
      'انضم لعائلة كابسو',
      asset: KDefaultAvatarArt.large,
      round: true,
    ),
    EbIconItem('مكافآت أسبوعية', asset: 'assets/recharge_badges/tier_5.webp'),
    EbIconItem('جمهور من كل الدول', icon: Icons.public_rounded),
  ]),
  const SizedBox(height: KSpacing.xxl),
  const EbSectionTitle('المكافآت', ornament: EbOrnament.wings),
  const SizedBox(height: KSpacing.lg),
  const EbRewardsBox(
    title: 'جوائز الحملة',
    items: [
      EbRewardItem(
        'حتى 50,000 كوينز\nللمضيف الأعلى',
        'assets/currency/kabso_coin.png',
      ),
      EbRewardItem('إطار المركز الأول\nلمدة 7 أيام', null, frameRank: 1),
      EbRewardItem(
        'دخولية القصر\nلمدة 7 أيام',
        'assets/cp_space/privilege_entrance.webp',
      ),
    ],
  ),
  const SizedBox(height: KSpacing.xxl),
  const EbSectionTitle('خطوات المشاركة'),
  const SizedBox(height: KSpacing.lg),
  const EbSteps([
    ('سجّل في الحملة', 'اضغط «قدّم الآن» واملأ بياناتك خلال أقل من دقيقة.'),
    ('ابدأ البث', 'ابثّ ساعتين يومياً على الأقل خلال مدة الحملة.'),
    ('اجمع النقاط', 'كل هدية تصلك أثناء البث تضيف نقاطاً إلى رصيدك.'),
    ('استلم مكافأتك', 'تُصرف الجوائز تلقائياً بعد 24 ساعة من انتهاء الحملة.'),
  ]),
  const SizedBox(height: KSpacing.md),
  const EbNotes(
    title: 'ملاحظات',
    lines: [
      'الحملة للمضيفين الجدد الذين انضموا خلال آخر 30 يوماً.',
      'أي مخالفة لإرشادات المجتمع تلغي المشاركة.',
      'لإدارة كابسو لايف الحق في تعديل الشروط مع الإعلان المسبق.',
    ],
  ),
  const SizedBox(height: KSpacing.xl),
  const EbCta('قدّم الآن'),
  const SizedBox(height: KSpacing.xxl),
  const EbFooter('بثّك… نجوميتك'),
  const SizedBox(height: KSpacing.xxl),
];

void main() {
  testWidgets('E full page', (tester) async {
    await pumpScene(
      tester,
      RepaintBoundary(
        key: sceneKey,
        child: ColoredBox(
          color: kPageBg,
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Column(children: _blocks()),
          ),
        ),
      ),
      size: const Size(393, 2500),
    );
    await tester.pump(const Duration(milliseconds: 100));
    // Size the capture to the content.
    final h = tester.getSize(find.byType(Column).first).height;
    await tester.pumpWidget(const SizedBox());
    await pumpScene(
      tester,
      RepaintBoundary(
        key: sceneKey,
        child: ColoredBox(
          color: kPageBg,
          child: Column(children: _blocks()),
        ),
      ),
      size: Size(393, h),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await shot(tester, 'E_blocks/E_campaign_full.ar.png', ratio: 2);
    await tester.pumpWidget(const SizedBox());
    await pumpScene(
      tester,
      RepaintBoundary(
        key: sceneKey,
        child: ColoredBox(
          color: kPageBg,
          child: ListView(padding: EdgeInsets.zero, children: _blocks()),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await shot(tester, 'E_blocks/E_campaign_top.ar.png');
    dumpTextRects(tester, 'contrast/E_campaign_top.json');
    await tester.pumpWidget(const SizedBox());
  });
}
