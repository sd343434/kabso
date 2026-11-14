import 'package:kabso_live/features/programs/data/event_announcements_repository.dart';

/// D340: the full-screen event announcements without the network — none by
/// default; a test lists some and reads which were marked seen.
class FakeEventAnnouncementsRepository implements EventAnnouncementsRepository {
  new([List<EventAnnouncement>? items]) : items = [...?items];

  final List<EventAnnouncement> items;
  final List<String> seen = [];
  int calls = 0;

  @override
  Future<List<EventAnnouncement>> pending() async {
    calls++;
    return [
      for (final a in items)
        if (!seen.contains(a.id)) a,
    ];
  }

  @override
  Future<void> markSeen(String announcementId) async {
    if (!seen.contains(announcementId)) seen.add(announcementId);
  }
}
