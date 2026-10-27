import 'package:flutter/foundation.dart';
import 'package:kabso_live/core/state/feed_load.dart';

/// Where a banner's `link` leads in the app (D124, CONVENTIONS §10.26).
sealed class HomeBannerTarget {
  const new();

  /// Parses an allowlisted link: `/cp/space`, `/families`,
  /// `/live?tab=trending|new|following`, `/home/room/{roomId}`,
  /// `/users/{username}`. Anything else is `null`, including `https://`
  /// links: the app has no in-app browser yet, and the contract lets an app
  /// ignore a link it cannot open (the banner is then not a button).
  static HomeBannerTarget? parse(String link) {
    switch (link) {
      case '/cp/space':
      case '/families':
        return HomeBannerRoute(link);
      case '/live?tab=trending':
        return const HomeBannerLiveTab(FeedTab.popular);
      case '/live?tab=new':
        return const HomeBannerLiveTab(FeedTab.latest);
      case '/live?tab=following':
        return const HomeBannerLiveTab(FeedTab.following);
    }
    final room = _room.firstMatch(link);
    if (room != null) return HomeBannerRoute(link.toLowerCase());
    if (_user.hasMatch(link)) return HomeBannerRoute(link);
    return null;
  }

  static final _room = RegExp(
    '^/home/room/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );
  static final _user = RegExp(r'^/users/[a-z0-9._]{1,30}$');
}

/// An in-app route pushed above the hub (its path is the app route).
@immutable
final class HomeBannerRoute extends HomeBannerTarget {
  const new(this.location);

  final String location;

  @override
  bool operator ==(Object other) =>
      other is HomeBannerRoute && other.location == location;

  @override
  int get hashCode => location.hashCode;
}

/// One of the live hub's own tabs.
@immutable
final class HomeBannerLiveTab extends HomeBannerTarget {
  const new(this.tab);

  final FeedTab tab;

  @override
  bool operator ==(Object other) =>
      other is HomeBannerLiveTab && other.tab == tab;

  @override
  int get hashCode => tab.hashCode;
}
