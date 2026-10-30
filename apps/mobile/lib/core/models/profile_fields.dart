import 'package:flutter/foundation.dart';

/// D175 (contract v1.47-social, CONVENTIONS §10.43): the profile fields
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
  other('OTHER');

  new(this.wire);

  final String wire;

  static AccountCategory? fromWire(Object? wire) =>
      values.where((c) => c.wire == wire).firstOrNull;
}

AccountCategory? accountCategoryFromJson(Object? json) =>
    AccountCategory.fromWire(json);
String? accountCategoryToJson(AccountCategory? category) => category?.wire;

/// `ProfileLinkPlatform`: the server names the known domains; the app opens
/// those directly and warns before any [other] link.
enum ProfileLinkPlatform {
  instagram('INSTAGRAM'),
  tiktok('TIKTOK'),
  youtube('YOUTUBE'),
  facebook('FACEBOOK'),
  x('X'),
  other('OTHER');

  new(this.wire);

  final String wire;

  static ProfileLinkPlatform fromWire(Object? wire) =>
      values.where((p) => p.wire == wire).firstOrNull ?? other;

  /// Opened without the «أنت تغادر Kabso» warning.
  bool get known => this != other;
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

/// The app-side mirror of the server's link rules (CONVENTIONS §10.43), so
/// the editor can say what is wrong before saving. The server stays
/// authoritative.
abstract final class ProfileLinkRules {
  static const int maxLinks = 3;
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
