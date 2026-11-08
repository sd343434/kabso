// v1.95-social (D301, CONVENTIONS §10.112): the app owner's profile
// «صفحة صاحب البرنامج» — the bilingual cover video, «رحلة Kabso», «لوحة
// المؤسس» and the staff accounts «أبلغ عن موظف» may name. Plain immutable
// models read from `openapi.yaml` (no generated code).

import 'package:kabso_live/core/models/shared_models.dart';
import 'package:material_ui/material_ui.dart';

/// `CoverVideoVariant`: one language's cover video and its poster.
@immutable
class CoverVideoVariant {
  const new({
    required this.url,
    required this.posterUrl,
    required this.durationMs,
    this.width = 0,
    this.height = 0,
  });

  factory fromJson(Map<String, dynamic> json) => CoverVideoVariant(
    url: json['url']! as String,
    posterUrl: json['posterUrl']! as String,
    durationMs: (json['durationMs']! as num).toInt(),
    width: (json['width'] as num?)?.toInt() ?? 0,
    height: (json['height'] as num?)?.toInt() ?? 0,
  );

  final String url;
  final String posterUrl;
  final int durationMs;
  final int width;
  final int height;

  Map<String, dynamic> toJson() => {
    'url': url,
    'posterUrl': posterUrl,
    'durationMs': durationMs,
    'width': width,
    'height': height,
  };

  @override
  bool operator ==(Object other) =>
      other is CoverVideoVariant &&
      other.url == url &&
      other.posterUrl == posterUrl &&
      other.durationMs == durationMs;

  @override
  int get hashCode => Object.hash(url, posterUrl, durationMs);
}

/// `OwnerCoverVideo`: the owner's cover videos — Arabic and English.
@immutable
class OwnerCoverVideo {
  const new({this.ar, this.en});

  factory fromJson(Map<String, dynamic> json) => OwnerCoverVideo(
    ar: switch (json['ar']) {
      final Map<String, dynamic> v => CoverVideoVariant.fromJson(v),
      _ => null,
    },
    en: switch (json['en']) {
      final Map<String, dynamic> v => CoverVideoVariant.fromJson(v),
      _ => null,
    },
  );

  final CoverVideoVariant? ar;
  final CoverVideoVariant? en;

  bool get isEmpty => ar == null && en == null;

  /// §10.112.1: the app's own language decides — Arabic shows [ar], any
  /// other language [en]; with only one, everyone sees that one; with none,
  /// null (the cover picture shows).
  CoverVideoVariant? pick(String languageCode) =>
      languageCode == 'ar' ? (ar ?? en) : (en ?? ar);

  Map<String, dynamic> toJson() => {
    if (ar case final v?) 'ar': v.toJson(),
    if (en case final v?) 'en': v.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      other is OwnerCoverVideo && other.ar == ar && other.en == en;

  @override
  int get hashCode => Object.hash(ar, en);
}

/// `PublicProfile.coverVideo` from JSON (absent → null).
OwnerCoverVideo? ownerCoverVideoFromJson(Object? json) => switch (json) {
  final Map<String, dynamic> m => OwnerCoverVideo.fromJson(m),
  _ => null,
};

Object? ownerCoverVideoToJson(OwnerCoverVideo? value) => value?.toJson();

/// «رحلة Kabso»: the closed set of icons (`JourneyIcon`).
enum JourneyIcon {
  rocket(Icons.rocket_launch_rounded, Color(0xFFE53935), Color(0xFFFF5A5F)),
  users(Icons.groups_rounded, Color(0xFFF57C00), Color(0xFFFF9F43)),
  agency(Icons.apartment_rounded, Color(0xFFE0A100), Color(0xFFF5C451)),
  globe(Icons.public_rounded, Color(0xFFD81B60), Color(0xFFFF5C93)),
  sparkles(Icons.auto_awesome_rounded, Color(0xFF7E57C2), Color(0xFFA78BFA)),
  star(Icons.star_rounded, Color(0xFFE0A100), Color(0xFFFFD166)),
  trophy(Icons.emoji_events_rounded, Color(0xFFC77D00), Color(0xFFF5C451)),
  heart(Icons.favorite_rounded, Color(0xFFE53950), Color(0xFFFF7A8A)),
  gift(Icons.card_giftcard_rounded, Color(0xFFD81B60), Color(0xFFFF6FA5)),
  live(Icons.videocam_rounded, Color(0xFFB80710), Color(0xFFFF3B47)),
  crown(Icons.workspace_premium_rounded, Color(0xFFB8860B), Color(0xFFF5C451)),
  flag(Icons.flag_rounded, Color(0xFF00897B), Color(0xFF4DD0C1));

  new(this.icon, this.deep, this.light);

  final IconData icon;

  /// The node's gradient, deep to light.
  final Color deep;
  final Color light;

  static JourneyIcon fromWire(Object? value) =>
      values.firstWhere((i) => i.name == value, orElse: () => flag);
}

/// `JourneyMilestone`: one milestone of «رحلة Kabso».
@immutable
class JourneyMilestone {
  const new({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    required this.year,
    required this.month,
    required this.icon,
    this.lineAr,
    this.lineEn,
    this.latest = false,
    this.position = 0,
  });

  factory fromJson(Map<String, dynamic> json) => JourneyMilestone(
    id: json['id']! as String,
    titleAr: json['titleAr']! as String,
    titleEn: json['titleEn']! as String,
    lineAr: json['lineAr'] as String?,
    lineEn: json['lineEn'] as String?,
    year: (json['year']! as num).toInt(),
    month: (json['month']! as num).toInt(),
    icon: JourneyIcon.fromWire(json['icon']),
    latest: json['latest'] == true,
    position: (json['position'] as num?)?.toInt() ?? 0,
  );

  final String id;
  final String titleAr;
  final String titleEn;
  final String? lineAr;
  final String? lineEn;
  final int year;
  final int month;
  final JourneyIcon icon;
  final bool latest;
  final int position;

  /// The viewer's language: Arabic → the Arabic texts, else English.
  String title(String languageCode) => languageCode == 'ar' ? titleAr : titleEn;

  String? line(String languageCode) => languageCode == 'ar' ? lineAr : lineEn;

  /// The body of a create or a full update.
  Map<String, dynamic> toBody() => {
    'titleAr': titleAr,
    'titleEn': titleEn,
    'lineAr': lineAr,
    'lineEn': lineEn,
    'year': year,
    'month': month,
    'icon': icon.name,
    'latest': latest,
  };
}

/// `OwnerDashboard`: «لوحة المؤسس».
@immutable
class OwnerDashboard {
  const new({
    required this.onlineNow,
    required this.liveRoomsNow,
    required this.incomeMinor,
    required this.websiteMinor,
    required this.agentsMinor,
    required this.currency,
    required this.generatedAt,
    this.onlineWindowMinutes = 5,
    this.timeZone = '',
    this.otherCurrencies = const [],
  });

  factory fromJson(Map<String, dynamic> json) {
    final income = json['income']! as Map<String, dynamic>;
    return OwnerDashboard(
      onlineNow: (json['onlineNow']! as num).toInt(),
      onlineWindowMinutes: (json['onlineWindowMinutes'] as num?)?.toInt() ?? 5,
      liveRoomsNow: (json['liveRoomsNow']! as num).toInt(),
      incomeMinor: (income['amountMinor']! as num).toInt(),
      websiteMinor: (income['websiteMinor'] as num?)?.toInt() ?? 0,
      agentsMinor: (income['agentsMinor'] as num?)?.toInt() ?? 0,
      currency: income['currency'] as String? ?? 'USD',
      timeZone: income['timeZone'] as String? ?? '',
      otherCurrencies: [
        for (final l
            in (income['otherCurrencies'] as List<dynamic>?) ?? const [])
          if (l case {
            'currency': final String currency,
            'amountMinor': final num amount,
          })
            (currency: currency, amountMinor: amount.toInt()),
      ],
      generatedAt: DateTime.parse(json['generatedAt']! as String),
    );
  }

  final int onlineNow;
  final int onlineWindowMinutes;
  final int liveRoomsNow;
  final int incomeMinor;
  final int websiteMinor;
  final int agentsMinor;
  final String currency;
  final String timeZone;
  final DateTime generatedAt;

  /// Owner (PP-58): money Kabso received today in another currency, one
  /// line each, never converted.
  final List<({String currency, int amountMinor})> otherCurrencies;
}

/// `OwnerFeedbackStaff`: a Kabso Team account a report may name.
@immutable
class FeedbackStaff {
  const new({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    this.staffId,
  });

  factory fromJson(Map<String, dynamic> json) => FeedbackStaff(
    id: json['id']! as String,
    username: json['username']! as String,
    displayName: json['displayName']! as String,
    avatarUrl: json['avatarUrl'] as String?,
    staffId: json['staffId'] as String?,
  );

  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final String? staffId;
}

/// «اقترح ميزة» or «الإبلاغ عن موظف».
enum FeedbackKind {
  feature('FEATURE'),
  staffReport('STAFF_REPORT');

  new(this.wire);
  final String wire;
}

/// The reason of a staff report (`OwnerFeedbackCategory`).
enum FeedbackCategory {
  rudeness('RUDENESS'),
  abuseOfPower('ABUSE_OF_POWER'),
  unfairAction('UNFAIR_ACTION'),
  noResponse('NO_RESPONSE'),
  corruption('CORRUPTION'),
  other('OTHER');

  new(this.wire);
  final String wire;
}

/// `SearchFeatured.owner` (§10.112.9): the founder pinned in search.
@immutable
class FeaturedFounder {
  const new({
    required this.user,
    this.isFollowing = false,
    this.isSelf = false,
  });

  /// Reads `SearchFeatured`; null when there is no founder to show.
  static FeaturedFounder? fromSearchFeatured(Map<String, dynamic> json) =>
      switch (json['owner']) {
        final Map<String, dynamic> o => FeaturedFounder(
          user: UserSummary.fromJson(o),
          isFollowing: o['isFollowing'] == true,
          isSelf: o['isSelf'] == true,
        ),
        _ => null,
      };

  final UserSummary user;
  final bool isFollowing;
  final bool isSelf;
}

/// At most this many characters (`CreateOwnerFeedbackRequest.text`).
const int ownerFeedbackMaxText = 1000;

/// At most this many milestones (409 `OWNER_JOURNEY_LIMIT`).
const int ownerJourneyMax = 30;

// ---- «الربح» (D301 follow-up, §10.112.10) ----------------------------------

/// `OwnerProfitDeductionKey`: one deduction line of «الربح».
enum ProfitDeductionKey {
  gifts('GIFTS'),
  agencyCommissions('AGENCY_COMMISSIONS'),
  referralRewards('REFERRAL_REWARDS'),
  taskRewards('TASK_REWARDS'),
  staffCommissions('STAFF_COMMISSIONS'),
  teamAdjustments('TEAM_ADJUSTMENTS'),
  coinRewards('COIN_REWARDS'),
  cardFees('CARD_FEES');

  new(this.wire);

  final String wire;

  static ProfitDeductionKey? fromWire(Object? v) {
    for (final k in values) {
      if (k.wire == v) return k;
    }
    return null;
  }
}

int _int(Object? v) => (v as num?)?.toInt() ?? 0;

/// One deduction of a period.
@immutable
class ProfitDeduction {
  const new({
    required this.key,
    required this.amountMinor,
    this.cherries,
    this.coins,
    this.orders,
  });

  final ProfitDeductionKey key;

  /// US cents (a negative net lowers the costs).
  final int amountMinor;

  /// The net cherries of a cherry line (null otherwise).
  final int? cherries;

  /// The coins given away of the coin rewards (null otherwise).
  final int? coins;

  /// The card orders of the card fees (null otherwise).
  final int? orders;
}

/// A fixed cost's share of a period.
@immutable
class FixedCostShare {
  const new({
    required this.id,
    required this.name,
    required this.monthlyMinor,
    required this.days,
    required this.shareMinor,
  });

  final String id;
  final String name;
  final int monthlyMinor;
  final int days;
  final int shareMinor;
}

/// Money received in another currency (never converted).
@immutable
class ProfitOtherCurrency {
  const new({
    required this.currency,
    required this.beforeMinor,
    required this.deductionsMinor,
    required this.afterMinor,
  });

  final String currency;
  final int beforeMinor;
  final int deductionsMinor;
  final int afterMinor;
}

/// `OwnerProfitPeriod`: a day or a month of «الربح».
@immutable
class OwnerProfitPeriod {
  const new({
    required this.month,
    required this.key,
    required this.from,
    required this.to,
    required this.days,
    required this.daysInMonth,
    required this.beforeMinor,
    required this.cardChargedMinor,
    required this.refundsMinor,
    required this.chargebacksMinor,
    required this.agentsMinor,
    required this.deductions,
    required this.fixedCostsMinor,
    required this.fixedCosts,
    required this.afterMinor,
    this.partial = false,
    this.otherCurrencies = const [],
  });

  factory fromJson(Map<String, dynamic> json) {
    final before = json['before']! as Map<String, dynamic>;
    final fixed = json['fixedCosts']! as Map<String, dynamic>;
    return OwnerProfitPeriod(
      month: json['kind'] == 'MONTH',
      key: json['key']! as String,
      from: json['from']! as String,
      to: json['to']! as String,
      days: _int(json['days']),
      daysInMonth: _int(json['daysInMonth']),
      partial: json['partial'] == true,
      beforeMinor: _int(before['amountMinor']),
      cardChargedMinor: _int(before['cardChargedMinor']),
      refundsMinor: _int(before['refundsMinor']),
      chargebacksMinor: _int(before['chargebacksMinor']),
      agentsMinor: _int(before['agentsMinor']),
      deductions: [
        for (final d in (json['deductions'] as List<dynamic>?) ?? const [])
          if (d case {'key': final Object k} when d is Map<String, dynamic>)
            if (ProfitDeductionKey.fromWire(k) case final key?)
              ProfitDeduction(
                key: key,
                amountMinor: _int(d['amountMinor']),
                cherries: (d['cherries'] as num?)?.toInt(),
                coins: (d['coins'] as num?)?.toInt(),
                orders: (d['orders'] as num?)?.toInt(),
              ),
      ],
      fixedCostsMinor: _int(fixed['amountMinor']),
      fixedCosts: [
        for (final i in (fixed['items'] as List<dynamic>?) ?? const [])
          if (i is Map<String, dynamic>)
            FixedCostShare(
              id: i['id']! as String,
              name: i['name']! as String,
              monthlyMinor: _int(i['monthlyMinor']),
              days: _int(i['days']),
              shareMinor: _int(i['shareMinor']),
            ),
      ],
      afterMinor: _int((json['after']! as Map<String, dynamic>)['amountMinor']),
      otherCurrencies: [
        for (final o in (json['otherCurrencies'] as List<dynamic>?) ?? const [])
          if (o is Map<String, dynamic>)
            ProfitOtherCurrency(
              currency: o['currency']! as String,
              beforeMinor: _int(o['beforeMinor']),
              deductionsMinor: _int(o['deductionsMinor']),
              afterMinor: _int(o['afterMinor']),
            ),
      ],
    );
  }

  /// A month (else a day).
  final bool month;
  final String key;
  final String from;
  final String to;
  final int days;
  final int daysInMonth;

  /// The current month counted to today (the elapsed share of the fixed
  /// costs).
  final bool partial;

  /// «الدخل قبل» and its parts (US cents).
  final int beforeMinor;
  final int cardChargedMinor;
  final int refundsMinor;
  final int chargebacksMinor;
  final int agentsMinor;
  final List<ProfitDeduction> deductions;
  final int fixedCostsMinor;
  final List<FixedCostShare> fixedCosts;

  /// «الربح النهائي بعد» (may be negative).
  final int afterMinor;

  final List<ProfitOtherCurrency> otherCurrencies;

  int get deductionsMinor => deductions.fold(0, (s, d) => s + d.amountMinor);
}

/// `OwnerProfit`: a day and its month.
@immutable
class OwnerProfit {
  const new({
    required this.today,
    required this.day,
    required this.month,
    required this.rateCherries,
    required this.rateMinor,
    required this.cardFeeBps,
    required this.cardFeeFixedMinor,
    required this.generatedAt,
    this.coinValueMinorPerMillion = 0,
  });

  factory fromJson(Map<String, dynamic> json) {
    final rates = json['rates'] as Map<String, dynamic>? ?? const {};
    return OwnerProfit(
      today: json['today']! as String,
      day: OwnerProfitPeriod.fromJson(json['day']! as Map<String, dynamic>),
      month: OwnerProfitPeriod.fromJson(json['month']! as Map<String, dynamic>),
      rateCherries: _int(rates['cherries']),
      rateMinor: _int(rates['minor']),
      cardFeeBps: _int(rates['cardFeeBps']),
      cardFeeFixedMinor: _int(rates['cardFeeFixedMinor']),
      coinValueMinorPerMillion: _int(rates['coinValueMinorPerMillion']),
      generatedAt: DateTime.parse(json['generatedAt']! as String),
    );
  }

  final String today;
  final OwnerProfitPeriod day;
  final OwnerProfitPeriod month;
  final int rateCherries;
  final int rateMinor;
  final int cardFeeBps;
  final int cardFeeFixedMinor;

  /// Given-away coins' value: US cents per 1 000 000 coins (owner: 1200).
  final int coinValueMinorPerMillion;
  final DateTime generatedAt;
}

/// `OwnerFixedCost`: a fixed monthly cost «تكلفة ثابتة» (USD).
@immutable
class OwnerFixedCost {
  const new({
    required this.id,
    required this.name,
    required this.monthlyMinor,
    required this.activeFrom,
    this.activeTo,
  });

  factory fromJson(Map<String, dynamic> json) => OwnerFixedCost(
    id: json['id']! as String,
    name: json['name']! as String,
    monthlyMinor: _int(json['monthlyMinor']),
    activeFrom: json['activeFrom']! as String,
    activeTo: json['activeTo'] as String?,
  );

  final String id;
  final String name;
  final int monthlyMinor;

  /// Local days `YYYY-MM-DD`; [activeTo] null = open-ended.
  final String activeFrom;
  final String? activeTo;

  /// Whether it counts on [day] (`YYYY-MM-DD`).
  bool activeOn(String day) =>
      activeFrom.compareTo(day) <= 0 &&
      (activeTo == null || activeTo!.compareTo(day) >= 0);
}
