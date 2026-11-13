// Wire models of the CP space (docs/contracts/openapi.yaml v1.24-live
// DRAFT, tag `cp`, CP-021; CONVENTIONS §10.24): daily tasks, privileges,
// the public couple page, the gift wall, the couples ranking and the
// confession wall. Codes the app does not know yet are kept as strings or
// left out, so a newer server never breaks the page.

import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/features/cp/domain/cp_models.dart';
import 'package:material_ui/material_ui.dart';

Map<String, dynamic> _map(Object? v) => v! as Map<String, dynamic>;
List<Map<String, dynamic>> _list(Object? v) => [
  for (final e in v! as List<dynamic>) e as Map<String, dynamic>,
];
int _int(Object? v) => (v! as num).toInt();
int? _intOrNull(Object? v) => (v as num?)?.toInt();
DateTime _date(Object? v) => DateTime.parse(v! as String);
DateTime? _dateOrNull(Object? v) => v == null ? null : _date(v);

/// `CpPrivilegeCode`: one privilege per CP tier.
enum CpPrivilegeCode {
  specialFrame('SPECIAL_FRAME', 1),
  chatBubble('CHAT_BUBBLE', 2),
  micEffect('MIC_EFFECT', 3),
  entranceEffect('ENTRANCE_EFFECT', 4),
  giftWall('GIFT_WALL', 5);

  new(this.wire, this.unlockLevel);

  final String wire;

  /// The CP level that unlocks it (CONVENTIONS §10.24; the server says the
  /// same in `CpPrivilege.unlockLevel`).
  final int unlockLevel;

  /// The code of [wire], or null for one this app does not know.
  static CpPrivilegeCode? fromWire(Object? wire) =>
      values.where((c) => c.wire == wire).firstOrNull;

  /// The known codes of [wires], in catalogue order.
  static Set<CpPrivilegeCode> parseAll(Iterable<Object?> wires) => {
    for (final w in wires) ?fromWire(w),
  };
}

/// `CpPrivilege`.
@immutable
class CpPrivilege {
  const new({
    required this.code,
    required this.name,
    required this.unlockLevel,
    required this.unlocked,
    required this.iconKey,
  });

  final CpPrivilegeCode code;
  final String name;
  final int unlockLevel;
  final bool unlocked;
  final String iconKey;
}

/// `CpPrivileges` (`GET /cp/me/privileges`): [level] null when not paired.
@immutable
class CpPrivileges {
  const new({required this.level, required this.privileges});

  factory fromJson(Map<String, dynamic> json) => CpPrivileges(
    level: _intOrNull(json['level']),
    privileges: [
      for (final p in _list(json['privileges']))
        if (CpPrivilegeCode.fromWire(p['code']) case final code?)
          CpPrivilege(
            code: code,
            name: p['name']! as String,
            unlockLevel: _int(p['unlockLevel']),
            unlocked: p['unlocked']! as bool,
            iconKey: p['iconKey']! as String,
          ),
    ],
  );

  final int? level;
  final List<CpPrivilege> privileges;
}

/// `CpTask`: one daily task of the couple. [code] is `CHECK_IN`,
/// `SEND_GIFT` or `CHAT_TOGETHER` today; [name] and [description] follow
/// the app language.
@immutable
class CpTask {
  const new({
    required this.code,
    required this.name,
    required this.description,
    required this.reward,
    required this.progress,
    required this.target,
    required this.completed,
    required this.claimed,
  });

  factory fromJson(Map<String, dynamic> json) => CpTask(
    code: json['code']! as String,
    name: json['name']! as String,
    description: json['description']! as String,
    reward: _int(json['reward']),
    progress: _int(json['progress']),
    target: _int(json['target']),
    completed: json['completed']! as bool,
    claimed: json['claimed']! as bool,
  );

  final String code;
  final String name;
  final String description;

  /// CP points the claim adds.
  final int reward;
  final int progress;
  final int target;
  final bool completed;

  /// Claimed today by either partner.
  final bool claimed;
}

/// `CpTasks` (`GET /cp/me/tasks`, `POST /cp/me/check-in`): today's tasks.
@immutable
class CpTasks {
  const new({
    required this.day,
    required this.timeZone,
    required this.startsAt,
    required this.resetsAt,
    required this.checkedInMe,
    required this.checkedInPartner,
    required this.tasks,
  });

  factory fromJson(Map<String, dynamic> json) {
    final checkedIn = _map(json['checkedIn']);
    return CpTasks(
      day: json['day']! as String,
      timeZone: json['timeZone']! as String,
      startsAt: _date(json['startsAt']),
      resetsAt: _date(json['resetsAt']),
      checkedInMe: checkedIn['me']! as bool,
      checkedInPartner: checkedIn['partner']! as bool,
      tasks: [for (final t in _list(json['tasks'])) CpTask.fromJson(t)],
    );
  }

  final String day;
  final String timeZone;
  final DateTime startsAt;

  /// The next 00:00 in [timeZone].
  final DateTime resetsAt;
  final bool checkedInMe;
  final bool checkedInPartner;
  final List<CpTask> tasks;

  /// The same day with [task] in place of the task of its code.
  CpTasks withTask(CpTask task) => CpTasks(
    day: day,
    timeZone: timeZone,
    startsAt: startsAt,
    resetsAt: resetsAt,
    checkedInMe: checkedInMe,
    checkedInPartner: checkedInPartner,
    tasks: [
      for (final t in tasks)
        if (t.code == task.code) task else t,
    ],
  );
}

/// `CpTaskClaimResult`: the task after the claim and the couple; `added`
/// is false when it was claimed already today (200: nothing added again).
typedef CpTaskClaim = ({CpTask task, CpCouple cp, bool added});

/// `CpCouplePublic` (`GET /cp/couples/{coupleId}`): a couple as anyone
/// signed in may read it. [mine] = the reader is a partner.
@immutable
class CpCouplePublic {
  const new({
    required this.id,
    required this.partners,
    required this.since,
    required this.days,
    required this.points,
    required this.level,
    required this.levelName,
    required this.nextLevelName,
    required this.pointsToNext,
    required this.privileges,
    required this.mine,
  });

  factory fromJson(Map<String, dynamic> json) => CpCouplePublic(
    id: json['id']! as String,
    partners: [
      for (final u in _list(json['partners'])) UserSummary.fromJson(u),
    ],
    since: _date(json['since']),
    days: _int(json['days']),
    points: _int(json['points']),
    level: _int(json['level']),
    levelName: json['levelName']! as String,
    nextLevelName: json['nextLevelName'] as String?,
    pointsToNext: _intOrNull(json['pointsToNext']),
    privileges: CpPrivilegeCode.parseAll(json['privileges']! as List<dynamic>),
    mine: json['mine']! as bool,
  );

  final String id;

  /// Both partners, ordered by user id.
  final List<UserSummary> partners;
  final DateTime since;
  final int days;
  final int points;
  final int level;
  final String levelName;
  final String? nextLevelName;
  final int? pointsToNext;
  final Set<CpPrivilegeCode> privileges;
  final bool mine;
}

/// `CpGiftWallEntry`: one CP gift. [giftCode] null for an amount no longer
/// offered.
@immutable
class CpGiftWallEntry {
  const new({
    required this.id,
    required this.amount,
    required this.giftCode,
    required this.sender,
    required this.receiver,
    required this.createdAt,
  });

  factory fromJson(Map<String, dynamic> json) => CpGiftWallEntry(
    id: json['id']! as String,
    amount: _int(json['amount']),
    giftCode: json['giftCode'] as String?,
    sender: UserSummary.fromJson(_map(json['sender'])),
    receiver: UserSummary.fromJson(_map(json['receiver'])),
    createdAt: _date(json['createdAt']),
  );

  final String id;
  final int amount;
  final String? giftCode;
  final UserSummary sender;
  final UserSummary receiver;
  final DateTime createdAt;
}

/// `CpGiftWall`: a page of the wall and the couple's totals.
@immutable
class CpGiftWall {
  const new({
    required this.data,
    required this.page,
    required this.totalGifts,
    required this.totalCoins,
  });

  factory fromJson(Map<String, dynamic> json) {
    final totals = _map(json['totals']);
    return CpGiftWall(
      data: [for (final e in _list(json['data'])) CpGiftWallEntry.fromJson(e)],
      page: PageInfo.fromJson(_map(json['page'])),
      totalGifts: _int(totals['gifts']),
      totalCoins: _int(totals['coins']),
    );
  }

  final List<CpGiftWallEntry> data;
  final PageInfo page;
  final int totalGifts;
  final int totalCoins;
}

/// `CpRankingPeriod`.
enum CpRankingPeriod {
  week('WEEK'),
  all('ALL');

  new(this.wire);

  final String wire;
}

/// `CpRankingEntry`.
@immutable
class CpRankingEntry {
  const new({
    required this.rank,
    required this.coupleId,
    required this.partners,
    required this.level,
    required this.levelName,
    required this.points,
  });

  factory fromJson(Map<String, dynamic> json) => CpRankingEntry(
    rank: _int(json['rank']),
    coupleId: json['coupleId']! as String,
    partners: [
      for (final u in _list(json['partners'])) UserSummary.fromJson(u),
    ],
    level: _int(json['level']),
    levelName: json['levelName']! as String,
    points: _int(json['points']),
  );

  final int rank;
  final String coupleId;
  final List<UserSummary> partners;
  final int level;
  final String levelName;

  /// CP points gained in the period.
  final int points;
}

/// `CpRankings.me`: the caller's couple; `rank` null with no points in the
/// period.
typedef CpRankingMe = ({String coupleId, int? rank, int points});

/// `CpRankings` (`GET /cp/rankings`).
@immutable
class CpRankings {
  const new({
    required this.period,
    required this.startsAt,
    required this.endsAt,
    required this.data,
    required this.page,
    required this.me,
  });

  factory fromJson(Map<String, dynamic> json) => CpRankings(
    period: json['period'] == CpRankingPeriod.all.wire
        ? CpRankingPeriod.all
        : CpRankingPeriod.week,
    startsAt: _dateOrNull(json['startsAt']),
    endsAt: _dateOrNull(json['endsAt']),
    data: [for (final e in _list(json['data'])) CpRankingEntry.fromJson(e)],
    page: PageInfo.fromJson(_map(json['page'])),
    me: switch (json['me']) {
      final Map<String, dynamic> me => (
        coupleId: me['coupleId']! as String,
        rank: _intOrNull(me['rank']),
        points: _int(me['points']),
      ),
      _ => null,
    },
  );

  final CpRankingPeriod period;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final List<CpRankingEntry> data;
  final PageInfo page;

  /// Null when the caller is not paired.
  final CpRankingMe? me;
}

/// `CpConfession`: a note from one partner to the other.
@immutable
class CpConfession {
  const new({
    required this.id,
    required this.coupleId,
    required this.author,
    required this.recipient,
    required this.text,
    required this.createdAt,
  });

  factory fromJson(Map<String, dynamic> json) => CpConfession(
    id: json['id']! as String,
    coupleId: json['coupleId']! as String,
    author: UserSummary.fromJson(_map(json['author'])),
    recipient: UserSummary.fromJson(_map(json['recipient'])),
    text: json['text']! as String,
    createdAt: _date(json['createdAt']),
  );

  final String id;
  final String coupleId;
  final UserSummary author;
  final UserSummary recipient;

  /// Both partners' live blocked words are masked by the server.
  final String text;
  final DateTime createdAt;
}

/// `CpConfessionPage`.
@immutable
class CpConfessionPage {
  const new({required this.data, required this.page});

  factory fromJson(Map<String, dynamic> json) => CpConfessionPage(
    data: [for (final c in _list(json['data'])) CpConfession.fromJson(c)],
    page: PageInfo.fromJson(_map(json['page'])),
  );

  final List<CpConfession> data;
  final PageInfo page;
}

/// The most code points a confession may have (§10.24, the live chat rule).
const int cpConfessionMaxCodePoints = 200;
