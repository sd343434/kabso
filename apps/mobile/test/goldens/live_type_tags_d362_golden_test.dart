// D362 (owner: «ايقونة تكون ببطاقة البث من الخارج حسب نوع البث بخط صغير
// جداً لكي لا تأخذ مساحة»): the live hub's cards with the owner's room-type
// glyph and tiny tag (still frames: reduce motion, as in every golden).
//
//   live_tags.grid        the hub grid, one card of every kind the data
//                         carries (PK, streamer, podcast, audio, multi,
//                         camera live) and one on a bright cover; dark
//   live_tags.grid_light  the same in the light theme
//   live_tags.zoom        every glyph of the owner's file 4× (the four with
//                         no backing room state marked «unused» by layout:
//                         the second block), then the six card tags 3×
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
import 'package:kabso_live/features/live/presentation/hub/live_hub_grid.dart';
import 'package:kabso_live/features/live/presentation/widgets/kabso_live_icon.dart';
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
    LiveRoomCardData(
      hostName: ar ? 'مريم' : 'Maryam',
      title: ar ? 'ضيوف على المسرح' : 'Guests on stage',
      viewerCount: 12345,
      cover: coverRed,
      isMulti: true,
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

/// The owner's glyphs enlarged on a mid cover, then the card tags.
Widget _zoom() => Container(
  constraints: const BoxConstraints.expand(),
  color: const Color(0xFF5A5F6B),
  child: Padding(
    padding: const EdgeInsets.all(12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Used on the cards.
        Wrap(
          spacing: 14,
          runSpacing: 10,
          children: [
            for (final type in {for (final k in LiveCardKind.values) k.glyph})
              KabsoLiveIcon(type: type, size: 56),
          ],
        ),
        const SizedBox(height: 18),
        // In the owner's file, no room state backs them yet.
        Opacity(
          opacity: 0.6,
          child: Wrap(
            spacing: 14,
            children: [
              for (final type in KabsoLiveType.values)
                if (!LiveCardKind.values.any((k) => k.glyph == type))
                  KabsoLiveIcon(type: type, size: 56),
            ],
          ),
        ),
        const SizedBox(height: 22),
        for (final kind in LiveCardKind.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: LiveTypeTag(kind: kind, iconSize: 39, fontSize: 28.5),
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
      await _capture(tester, 'icons_zoom.$name.393x852@3x');
    });

    // Captures only (KABSO_CAPTURE_DIR): frames of the loops, never a golden.
    testWidgets('live_tags.frames $name', (tester) async {
      if (_captureDir == null) return;
      KabsoLiveIcon.animationsEnabled = true;
      addTearDown(() => KabsoLiveIcon.animationsEnabled = false);
      setViewport(tester, GoldenViewport.phone);
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(),
          child: ColoredBox(
            color: const Color(0xFF5A5F6B),
            child: Center(
              child: Wrap(
                textDirection: TextDirection.ltr,
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final type in KabsoLiveType.values)
                    KabsoLiveIcon(type: type, size: 112),
                ],
              ),
            ),
          ),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 230));
        await _capture(tester, 'icons_frames.$name.$i');
      }
      await tester.pumpWidget(const SizedBox());
    });
  });
}
