// v1.82-live (D295, CONVENTIONS §10.108): the purple «صانع محتوى» /
// "Creator" badge — on the live card (grid and party rows) and next to the
// host's name in the room's host pill; `hostIsCreator` from the API (older
// servers: false).

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/presentation/hub/live_grid_card.dart';
import 'package:kabso_live/features/live/presentation/hub/voice_room_list.dart';
import 'package:kabso_live/features/live/presentation/widgets/creator_live_badge.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_scaffold.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_view_data.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/creator_live_fixtures.dart';
import '../../helpers/component_harness.dart';

Map<String, dynamic> _summaryJson({Object? hostIsCreator}) => {
  'id': '0190f3a0-0000-7000-8000-000000000295',
  'title': 'Creator live',
  'mode': 'SOLO',
  'viewerCount': 3,
  'startedAt': '2027-03-29T09:00:00.000Z',
  'coverUrl': null,
  'category': null,
  'host': {
    'id': '0190f3a0-0000-7000-8000-000000000001',
    'username': 'sara',
    'displayName': 'Sara',
    'avatarUrl': null,
  },
  'seatCount': null,
  'occupiedSeats': 0,
  'theme': 'classic',
  'score': 0,
  'topic': null,
  'hostIsCreator': ?hostIsCreator,
};

void main() {
  group('hostIsCreator from the API', () {
    test('true → the card data carries it; absent (older server) → false', () {
      final creator = LiveRoomSummary.fromJson(
        _summaryJson(hostIsCreator: true),
      );
      expect(creator.hostIsCreator, isTrue);
      expect(LiveRoomCardData.fromSummary(creator).hostIsCreator, isTrue);
      expect(LiveRoomSummary.fromJson(_summaryJson()).hostIsCreator, isFalse);
      expect(
        LiveRoom.fromJson({
          ..._summaryJson(hostIsCreator: true),
          'status': 'LIVE',
          'endedAt': null,
          'endReason': null,
        }).hostIsCreator,
        isTrue,
      );
    });
  });

  for (final language in AppLanguage.values) {
    final ar = language == AppLanguage.ar;
    final label = ar ? 'صانع محتوى' : 'Creator';

    testWidgets('the grid card shows the badge only for a creator '
        '(${language.name})', (tester) async {
      final rooms = creatorLiveRooms(language);
      await pumpComponent(
        tester,
        Row(
          children: [
            for (final room in rooms.take(2))
              Expanded(
                child: AspectRatio(
                  aspectRatio: 0.75,
                  child: KLiveGridCard(room: room),
                ),
              ),
          ],
        ),
        language: language,
      );
      expect(find.byType(CreatorLiveBadge), findsOneWidget);
      expect(find.text(label), findsOneWidget);
      final badge = tester.widget<Container>(
        find.byKey(CreatorLiveBadge.badgeKey),
      );
      expect(
        (badge.decoration! as BoxDecoration).color,
        const Color(0xFF7B3FC4),
      );
      // Announced with the card.
      expect(find.bySemanticsLabel(RegExp(RegExp.escape(label))), findsWidgets);
    });

    testWidgets('the party row shows the badge for a creator '
        '(${language.name})', (tester) async {
      final creator = creatorLiveRooms(language)[1];
      await pumpComponent(
        tester,
        VoiceRoomRow(room: creator),
        language: language,
      );
      expect(find.byType(CreatorLiveBadge), findsOneWidget);
      await pumpComponent(
        tester,
        VoiceRoomRow(room: creatorLiveRooms(language)[2]),
        language: language,
      );
      expect(find.byType(CreatorLiveBadge), findsNothing);
    });

    testWidgets('the room host pill shows the badge after the name '
        '(${language.name})', (tester) async {
      await pumpComponent(
        tester,
        const Align(
          alignment: AlignmentDirectional.topStart,
          child: KHostPill(hostName: 'Sara', hostIsCreator: true),
        ),
        language: language,
      );
      expect(find.byType(CreatorLiveBadge), findsOneWidget);
      final name = tester.getRect(find.text('Sara'));
      final badge = tester.getRect(find.byType(CreatorLiveBadge));
      // After the name in the reading direction.
      if (ar) {
        expect(badge.right, lessThanOrEqualTo(name.left + 0.5));
      } else {
        expect(badge.left, greaterThanOrEqualTo(name.right - 0.5));
      }
      await pumpComponent(
        tester,
        const KHostPill(hostName: 'Khalid'),
        language: language,
      );
      expect(find.byType(CreatorLiveBadge), findsNothing);
    });
  }
}
