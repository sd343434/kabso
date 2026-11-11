// D362 (owner: «ايقونة تكون ببطاقة البث من الخارج حسب نوع البث بخط صغير
// جداً لكي لا تأخذ مساحة», then 2026-11-10: «لا ازل الايقونات فقط جنبي موجة
// الكلمة بتصنيف لايف»): the live hub's cards with the room type as a tiny
// tag right beside the teal live wave, no glyph (still frames: reduce
// motion, as in every golden).
//
//   live_tags.grid        the hub grid, one card of every kind the data
//                         carries (PK, streamer, podcast, audio, multi,
//                         camera live) and one on a bright cover; dark
//   live_tags.grid_light  the same in the light theme
//   live_tags.zoom        the six card tags 3×, each beside the live wave
//
// 393 × 852 @3x. Regenerate on Linux with the pinned Flutter:
//   flutter test --update-goldens test/goldens/live_type_tags_d362_golden_test.dart
@Tags(['golden'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart' show OffsetLayer;
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/presentation/hub/live_grid_card.dart';
import 'package:kabso_live/features/live/presentation/hub/live_hub_grid.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_type_tag.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_view_data.dart';
import 'package:material_ui/material_ui.dart';

import '../fixtures/fixture_images.dart';
import '../fixtures/live/live_fixtures.dart';
import '../helpers/golden.dart';

final String? _captureDir = Platform.environment['KABSO_CAPTURE_DIR'];

/// Writes the whole screen at @3x to KABSO_CAPTURE_DIR (when set).
Future<void> _capture(WidgetTester tester, String name) async {
  final dir = _captureDir;
  if (dir == null) return;
  final view = tester.binding.renderViews.first;
  await tester.runAsync(() async {
    final layer = view.debugLayer! as OffsetLayer;
    final image = await layer.toImage(
      Offset.zero & (view.size * GoldenViewport.pixelRatio),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('$dir/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
  });
}

/// A bright, almost white cover (the tag's shadow must carry it).
final MemoryImage _bright = fixtureImage(
  top: const Color(0xFFFFFFFF),
  bottom: KBrandColors.gold,
);

List<LiveRoomCardData> _rooms(AppLanguage language) {
  final ar = language == AppLanguage.ar;
  return [
    LiveRoomCardData(
      hostName: ar ? 'خالد' : 'Khalid',
      title: ar ? 'تحدي الليلة' : 'Tonight’s battle',
      viewerCount: 1240,
      cover: coverRed,
      inPk: true,
    ),
    LiveRoomCardData(
      hostName: ar ? 'سارة' : 'Sara',
      title: ar ? 'نلعب سوا' : 'Playing together',
      viewerCount: 3180,
      cover: coverBlue,
      isStreamer: true,
    ),
    LiveRoomCardData(
      hostName: ar ? 'ليلى' : 'Layla',
      title: ar ? 'حلقة ريادة الأعمال' : 'The business episode',
      viewerCount: 87,
      cover: coverGold,
      isAudio: true,
      isPodcast: true,
    ),
    LiveRoomCardData(
      hostName: ar ? 'يوسف' : 'Youssef',
      title: ar ? 'دردشة الصباح' : 'Morning chat',
      viewerCount: 0,
      cover: coverBlue,
      isAudio: true,
    ),
    // D368: a live video podcast is a camera card of the hub, with the
    // podcast's tag and no camera after it (D369: no multi-guest card).
    LiveRoomCardData(
      hostName: ar ? 'مريم' : 'Maryam',
      title: ar ? 'ضيوف على المسرح' : 'Guests on stage',
      viewerCount: 12345,
      cover: coverRed,
      isAudio: true,
      isPodcast: true,
      podcast: const LivePodcast(
        episodeNumber: 4,
        topic: PodcastTopic.society,
        video: true,
      ),
    ),
    LiveRoomCardData(
      hostName: ar ? 'أحمد' : 'Ahmad',
      title: ar ? 'سهرة على غلاف فاتح' : 'A night on a bright cover',
      viewerCount: 1234567,
      cover: _bright,
    ),
  ];
}

Widget _grid(AppLanguage language) => CustomScrollView(
  slivers: [LiveHubGrid.sliver(rooms: _rooms(language), onOpenRoom: (_) {})],
);

/// The card tags 3× on a mid cover, each beside the live wave (the grid
/// card's 10 lp wave and 4 lp gap, 3×).
Widget _zoom() => Container(
  constraints: const BoxConstraints.expand(),
  color: const Color(0xFF5A5F6B),
  child: Padding(
    padding: const EdgeInsets.all(12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final kind in LiveCardKind.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const KLiveEqualizer(color: KLiveGrid.liveMark, size: 30),
                const SizedBox(width: KSpacing.xs * 3),
                LiveTypeTag(kind: kind, fontSize: 28.5),
              ],
            ),
          ),
      ],
    ),
  ),
);

void main() {
  setUpAll(loadAppFonts);

  forEachLanguage((language) {
    final name = language.name;

    testWidgets('live_tags.grid $name', (tester) async {
      await pumpGolden(
        tester,
        _grid(language),
        language: language,
        padding: EdgeInsets.zero,
      );
      await expectScreenGolden('live_tags.grid', language: language);
      await _capture(tester, 'hub_grid.$name.dark.393x852@3x');
    });

    testWidgets('live_tags.grid_light $name', (tester) async {
      await pumpGolden(
        tester,
        _grid(language),
        language: language,
        brightness: Brightness.light,
        padding: EdgeInsets.zero,
      );
      await expectScreenGolden('live_tags.grid_light', language: language);
      await _capture(tester, 'hub_grid.$name.light.393x852@3x');
    });

    testWidgets('live_tags.zoom $name', (tester) async {
      await pumpGolden(
        tester,
        _zoom(),
        language: language,
        padding: EdgeInsets.zero,
      );
      await expectScreenGolden('live_tags.zoom', language: language);
      await _capture(tester, 'tags_zoom.$name.393x852@3x');
    });
  });
}
