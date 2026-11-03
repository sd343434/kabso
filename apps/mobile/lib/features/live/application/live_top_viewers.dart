import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';

/// D256 (owner: «المشاهدين في الاعلى يكون الاكثر دعم واول ثلاث يكونو
/// بإطارات الاول والثاني والثالث»): this live's Contribution list (CP-014,
/// highest points first — gifts and taps). The key's `version` is the
/// live's gift points: a new gift reads the list again (a tap alone does
/// not). Unreadable → empty (the faces keep the join order).
typedef LiveTopKey = ({String roomId, int version});

final FutureProviderFamily<List<LiveContributor>, LiveTopKey>
liveTopContributorsProvider = FutureProvider.autoDispose
    .family<List<LiveContributor>, LiveTopKey>((ref, key) async {
      try {
        return await ref.read(liveRepositoryProvider).contributors(key.roomId);
      } on Object {
        return const [];
      }
    });

/// One face of the top viewers group: the person, their place (1–3) in
/// this live's support (or null) and their points in it.
typedef RankedViewer = ({UserSummary user, int? rank, int points});

/// D256: the viewers here now, the ones who supported this live most first
/// (in the Contribution list's order), then everyone else in [viewers]'
/// order; the first three supporters present get their place (1, 2, 3).
List<RankedViewer> rankViewersBySupport(
  List<LiveViewer> viewers,
  List<LiveContributor> contributors,
) {
  final present = <String, UserSummary>{};
  for (final v in viewers) {
    final u = v.user;
    if (u != null) present[u.id] = u;
  }
  final out = <RankedViewer>[];
  final placed = <String>{};
  for (final c in contributors) {
    if (c.points <= 0) continue;
    final u = present[c.user.id];
    if (u == null || !placed.add(u.id)) continue;
    out.add((
      user: u,
      rank: out.length < 3 ? out.length + 1 : null,
      points: c.points,
    ));
  }
  for (final v in viewers) {
    final u = v.user;
    if (u == null || !placed.add(u.id)) continue;
    out.add((user: u, rank: null, points: 0));
  }
  return out;
}

/// D256: the pill under a ringed face (its points, by [format]); null for a
/// face without a place.
String? rankPointsLabel(RankedViewer v, String Function(int) format) =>
    v.rank == null ? null : format(v.points);
