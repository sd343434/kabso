import 'package:flutter/foundation.dart';

/// D175 (contract v1.47-social, CONVENTIONS §10.47): the profile fields
/// gender, account category and links. Unknown wire values read as null
/// (or [ProfileLinkPlatform.other]), so a newer server never breaks an older
/// app.

/// `Gender`: «ذكر / أنثى / أفضّل عدم الذكر».
enum Gender {
  male('MALE'),
  female('FEMALE'),
  undisclosed('UNDISCLOSED');

  new(this.wire);

  final String wire;

  static Gender? fromWire(Object? wire) =>
      values.where((g) => g.wire == wire).firstOrNull;
}

Gender? genderFromJson(Object? json) => Gender.fromWire(json);
String? genderToJson(Gender? gender) => gender?.wire;

/// `AccountCategory`, in the owner's order (shown under the name).
enum AccountCategory {
  singer('SINGER'),
  musician('MUSICIAN'),
  poet('POET'),
  presenter('PRESENTER'),
  gamer('GAMER'),
  contentCreator('CONTENT_CREATOR'),
  athlete('ATHLETE'),
  artist('ARTIST'),
  blogger('BLOGGER'),
  publicFigure('PUBLIC_FIGURE'),
  other('OTHER'),

  // D386 (v1.138-social, §10.175.1): 13 more («نعم وأضف أي فئة مقترحة»).
  quranReciter('QURAN_RECITER'),
  storyteller('STORYTELLER'),
  writer('WRITER'),
  journalist('JOURNALIST'),
  photographer('PHOTOGRAPHER'),
  actor('ACTOR'),
  comedian('COMEDIAN'),
  calligrapher('CALLIGRAPHER'),
  designer('DESIGNER'),
  chef('CHEF'),
  teacher('TEACHER'),
  dj('DJ'),
  traveler('TRAVELER');

  new(this.wire);

  final String wire;

  static AccountCategory? fromWire(Object? wire) =>
      values.where((c) => c.wire == wire).firstOrNull;

  /// D386: the family that gives the profile its look and the picker its
  /// group (§10.175.1).
  CategoryFamily get family => switch (this) {
    singer || musician || dj => CategoryFamily.music,
    quranReciter || storyteller => CategoryFamily.reciter,
    poet || writer || blogger || journalist => CategoryFamily.word,
    artist || photographer || designer || calligrapher => CategoryFamily.visual,
    contentCreator ||
    actor ||
    comedian ||
    presenter => CategoryFamily.performer,
    athlete || gamer => CategoryFamily.sportsGames,
    chef || traveler || teacher => CategoryFamily.lifestyle,
    publicFigure || other => CategoryFamily.public,
  };
}

/// D386 (§10.175.1): the eight families of the 24 categories, in the
/// picker's order. A family is an app grouping; the wire carries the
/// category.
enum CategoryFamily {
  music,
  reciter,
  word,
  visual,
  performer,
  sportsGames,
  lifestyle,
  public;

  /// The family's categories, in the picker's order.
  List<AccountCategory> get categories => [
    for (final c in AccountCategory.values)
      if (c.family == this) c,
  ];
}

/// D386 (§10.175.2): `FeaturedSection` — the section at the top of a
/// verified category's profile. Unknown wire values read as null (no
/// section), so a newer server never breaks an older app.
enum FeaturedSection {
  works('WORKS'),
  recitations('RECITATIONS'),
  stories('STORIES'),
  poems('POEMS'),
  articles('ARTICLES'),
  reports('REPORTS'),
  program('PROGRAM'),
  games('GAMES'),
  achievements('ACHIEVEMENTS'),
  gallery('GALLERY'),
  mostViewed('MOST_VIEWED'),
  highlights('HIGHLIGHTS');

  new(this.wire);

  final String wire;

  static FeaturedSection? fromWire(Object? wire) =>
      values.where((s) => s.wire == wire).firstOrNull;

  /// The section of [category] (the server's table, §10.175.2), for the
  /// owner's «تثبيت في …» menu before the section was read.
  static FeaturedSection? of(AccountCategory category) => switch (category) {
    AccountCategory.singer ||
    AccountCategory.musician ||
    AccountCategory.dj => works,
    AccountCategory.quranReciter => recitations,
    AccountCategory.storyteller => stories,
    AccountCategory.poet => poems,
    AccountCategory.writer || AccountCategory.blogger => articles,
    AccountCategory.journalist => reports,
    AccountCategory.presenter => program,
    AccountCategory.gamer => games,
    AccountCategory.athlete => achievements,
    AccountCategory.artist ||
    AccountCategory.photographer ||
    AccountCategory.designer ||
    AccountCategory.calligrapher => gallery,
    AccountCategory.contentCreator ||
    AccountCategory.actor ||
    AccountCategory.comedian => mostViewed,
    AccountCategory.chef ||
    AccountCategory.traveler ||
    AccountCategory.teacher => highlights,
    AccountCategory.publicFigure || AccountCategory.other => null,
  };
}

AccountCategory? accountCategoryFromJson(Object? json) =>
    AccountCategory.fromWire(json);
String? accountCategoryToJson(AccountCategory? category) => category?.wire;

/// `ProfileLinkPlatform`: the server names the known domains. The app opens
/// TikTok, YouTube, X, Instagram and Facebook directly and shows «أنت تغادر
/// Kabso» before every other link — WhatsApp and Snapchat included (D361;
/// 2026-11-10 owner: Instagram/Facebook direct again, as under D175).
enum ProfileLinkPlatform {
  instagram('INSTAGRAM'),
  tiktok('TIKTOK'),
  youtube('YOUTUBE'),
  facebook('FACEBOOK'),
  x('X'),

  /// v1.118-social (D357): wa.me, whatsapp.com.
  whatsapp('WHATSAPP'),

  /// v1.118-social (D357): snapchat.com.
  snapchat('SNAPCHAT'),
  other('OTHER');

  new(this.wire);

  final String wire;

  static ProfileLinkPlatform fromWire(Object? wire) =>
      values.where((p) => p.wire == wire).firstOrNull ?? other;

  /// A platform the server names (not [other]).
  bool get known => this != other;

  /// Opened without the «أنت تغادر Kabso» warning (D175's sheet for every
  /// other link). D361, 2026-11-10 owner: Instagram/Facebook direct again
  /// (as under D175); WhatsApp and Snapchat ask first — the founder's social
  /// row too.
  bool get opensDirectly =>
      this == tiktok ||
      this == youtube ||
      this == x ||
      this == instagram ||
      this == facebook;
}

/// `ProfileLink`.
@immutable
class ProfileLink {
  const new({
    required this.id,
    required this.url,
    required this.platform,
    this.label,
  });

  factory fromJson(Map<String, dynamic> json) => ProfileLink(
    id: json['id'] as String,
    url: json['url'] as String,
    label: json['label'] as String?,
    platform: ProfileLinkPlatform.fromWire(json['platform']),
  );

  final String id;
  final String url;
  final String? label;
  final ProfileLinkPlatform platform;

  Map<String, dynamic> toJson() => {
    'id': id,
    'url': url,
    'label': label,
    'platform': platform.wire,
  };

  /// The host without `www.`, for compact display ("instagram.com").
  String get host {
    final h = Uri.tryParse(url)?.host ?? url;
    return h.startsWith('www.') ? h.substring(4) : h;
  }

  /// What a chip shows: the label, else the host and path, shortened.
  String get display {
    final label = this.label;
    if (label != null && label.isNotEmpty) return label;
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    final path = uri.path == '/' ? '' : uri.path;
    return '$host$path';
  }

  @override
  bool operator ==(Object other) =>
      other is ProfileLink &&
      other.id == id &&
      other.url == url &&
      other.label == label &&
      other.platform == platform;

  @override
  int get hashCode => Object.hash(id, url, label, platform);
}

/// `@JsonKey(fromJson:)` of the `links` arrays (absent → none).
List<ProfileLink> profileLinksFromJson(Object? json) => json is List
    ? [
        for (final item in json)
          if (item is Map<String, dynamic>) ProfileLink.fromJson(item),
      ]
    : const [];

List<Map<String, dynamic>> profileLinksToJson(List<ProfileLink> links) => [
  for (final l in links) l.toJson(),
];

/// The app-side mirror of the server's link rules (CONVENTIONS §10.47), so
/// the editor can say what is wrong before saving. The server stays
/// authoritative.
abstract final class ProfileLinkRules {
  static const int maxLinks = 3;

  /// v1.118-social (D357): the app owner's limit (his 3 plus one per
  /// platform of his page's social row).
  static const int maxFounderLinks = 7;

  /// D357: the platforms of the founder page's social row, in its order
  /// (the same in Arabic and English).
  static const List<ProfileLinkPlatform> founderSocials = [
    ProfileLinkPlatform.instagram,
    ProfileLinkPlatform.facebook,
    ProfileLinkPlatform.whatsapp,
    ProfileLinkPlatform.snapchat,
  ];

  /// D357: a bare phone number the server stores as `https://wa.me/<digits>`
  /// (8–15 digits with a `+` or `00` country code; separators allowed).
  static bool isWhatsAppNumber(String raw) {
    final t = raw.trim();
    if (!RegExp(r'^(?:\+|00)?[0-9][0-9 ().-]*[0-9]$').hasMatch(t)) return false;
    var digits = t.replaceAll(RegExp('[^0-9]'), '');
    if (t.startsWith('00')) digits = digits.substring(2);
    return !digits.startsWith('0') && digits.length >= 8 && digits.length <= 15;
  }

  static const int maxLabel = 30;
  static const int maxLength = 500;

  static final _forbidden = RegExp(
    r'[\s\u0000-\u001f\u007f-\u009f\u00ad\u061c\u200b-\u200f'
    r'\u2028-\u202e\u2060-\u2069\ufeff]',
  );
  static final _ipv4 = RegExp(r'^[0-9.]+$');
  static final _hex = RegExp(r'^(0x[0-9a-f]*\.?)+$');

  /// Null when [raw] looks like an acceptable https link, else the issue
  /// (`invalid_format` or `too_long`), as the server would name it.
  static String? issue(String raw) {
    final value = raw.trim();
    if (isWhatsAppNumber(value)) return null;
    if (value.isEmpty || _forbidden.hasMatch(value)) return 'invalid_format';
    if (!value.toLowerCase().startsWith('https://')) return 'invalid_format';
    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme.toLowerCase() != 'https') {
      return 'invalid_format';
    }
    if (uri.userInfo.isNotEmpty || uri.hasPort && uri.port != 443) {
      return 'invalid_format';
    }
    final host = uri.host.toLowerCase();
    if (host.isEmpty ||
        host.contains(':') ||
        _ipv4.hasMatch(host) ||
        _hex.hasMatch(host)) {
      return 'invalid_format';
    }
    final labels = host.split('.');
    if (labels.length < 2 || labels.any((l) => l.isEmpty)) {
      return 'invalid_format';
    }
    final tld = labels.last;
    if (RegExp(r'^[0-9]+$').hasMatch(tld)) return 'invalid_format';
    if (value.length > maxLength) return 'too_long';
    return null;
  }
}
