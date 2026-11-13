import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/network/api_call.dart';
import 'package:kabso_live/core/network/network_providers.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/profile/profile_fields_view.dart'
    show externalLinkOpenerProvider;
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// v1.139-social (D387, CONVENTIONS §10.176.5): the app's official social
/// media accounts «حساباتنا الرسمية», set in the admin panel (COMMUNITY,
/// OWNER) and shown in Settings under «تابعنا». Links only — the app never
/// sees a password or token of those accounts. Each row uses a generic glyph
/// of the app's own icon set (no third-party logo art).
enum SocialPlatform {
  instagram('INSTAGRAM', Icons.photo_camera_outlined),
  tiktok('TIKTOK', Icons.music_note_outlined),
  x('X', Icons.alternate_email_rounded),
  facebook('FACEBOOK', Icons.people_outline_rounded),
  youtube('YOUTUBE', Icons.play_circle_outline_rounded),
  snapchat('SNAPCHAT', Icons.chat_bubble_outline_rounded),
  telegram('TELEGRAM', Icons.send_outlined),
  whatsapp('WHATSAPP', Icons.phone_in_talk_outlined),
  threads('THREADS', Icons.forum_outlined),
  linkedin('LINKEDIN', Icons.work_outline_rounded),
  discord('DISCORD', Icons.headset_mic_outlined),
  other('OTHER', Icons.link_rounded);

  new(this.wire, this.icon);

  final String wire;
  final IconData icon;

  /// An unknown future platform reads as [other].
  static SocialPlatform fromWire(Object? v) =>
      values.where((p) => p.wire == v).firstOrNull ?? other;

  String label(AppLocalizations l10n) => switch (this) {
    instagram => l10n.socialPlatformInstagram,
    tiktok => l10n.socialPlatformTiktok,
    x => l10n.socialPlatformX,
    facebook => l10n.socialPlatformFacebook,
    youtube => l10n.socialPlatformYoutube,
    snapchat => l10n.socialPlatformSnapchat,
    telegram => l10n.socialPlatformTelegram,
    whatsapp => l10n.socialPlatformWhatsapp,
    threads => l10n.socialPlatformThreads,
    linkedin => l10n.socialPlatformLinkedin,
    discord => l10n.socialPlatformDiscord,
    other => l10n.socialPlatformOther,
  };
}

/// `OfficialSocialAccount`.
@immutable
class OfficialSocialAccount {
  const new({required this.platform, required this.handle, required this.url});

  /// Null when the link is not https (never opened).
  static OfficialSocialAccount? fromJson(Object? json) {
    if (json is! Map) return null;
    final url = Uri.tryParse('${json['url'] ?? ''}');
    if (url == null || url.scheme != 'https' || url.host.isEmpty) return null;
    return OfficialSocialAccount(
      platform: SocialPlatform.fromWire(json['platform']),
      handle: '${json['handle'] ?? ''}',
      url: url,
    );
  }

  final SocialPlatform platform;
  final String handle;
  final Uri url;
}

/// `GET /social-accounts` (public, cached 60 s by the server).
abstract interface class OfficialAccountsRepository {
  Future<List<OfficialSocialAccount>> list();
}

class ApiOfficialAccountsRepository implements OfficialAccountsRepository {
  new(this._dio);

  final Dio _dio;

  @override
  Future<List<OfficialSocialAccount>> list() => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>('/social-accounts');
    final data = res.data?['data'];
    return [
      if (data is List)
        for (final a in data) ?OfficialSocialAccount.fromJson(a),
    ];
  });
}

final officialAccountsRepositoryProvider = Provider<OfficialAccountsRepository>(
  (ref) => ApiOfficialAccountsRepository(ref.watch(apiDioProvider)),
);

final FutureProvider<List<OfficialSocialAccount>> officialAccountsProvider =
    FutureProvider.autoDispose<List<OfficialSocialAccount>>(
      (ref) => ref.watch(officialAccountsRepositoryProvider).list(),
    );

/// «تابعنا» in Settings: the official accounts in the panel's order, each
/// opening its link outside the app. Nothing while loading, on an error or
/// when there is none (the section is extra, never in the way).
class FollowUsSection extends ConsumerWidget {
  const new({super.key});

  static const headerKey = Key('settings.followUs');
  static Key row(int i) => Key('settings.followUs.$i');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(officialAccountsProvider).value ?? const [];
    if (accounts.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final p = context.palette;
    final text = context.textStyles;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          key: headerKey,
          padding: const EdgeInsetsDirectional.fromSTEB(
            KSpacing.lg,
            0,
            KSpacing.lg,
            KSpacing.sm,
          ),
          child: Semantics(
            header: true,
            child: Text(
              l10n.settingsFollowUs,
              style: text.label.copyWith(color: p.textSecondary),
            ),
          ),
        ),
        for (final (i, a) in accounts.indexed)
          ListTile(
            key: row(i),
            leading: Icon(a.platform.icon),
            title: Text(a.platform.label(l10n)),
            // The handle isolated left-to-right, aligned with the title.
            subtitle: Text(
              '\u2066${a.handle}\u2069',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Icon(
              Icons.open_in_new_rounded,
              size: 18,
              color: p.textTertiary,
            ),
            onTap: () =>
                unawaited(ref.read(externalLinkOpenerProvider).open(a.url)),
          ),
        const SizedBox(height: KSpacing.xl),
      ],
    );
  }
}
