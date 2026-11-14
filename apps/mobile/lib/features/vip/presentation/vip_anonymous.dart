import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// v1.133-social (D380, §10.170): the stand-in «مجهول» the server shows
/// instead of a VIP member ([UserSummary.anonymous]) — the app's own name for
/// it and the generic avatar.
extension AnonymousPerson on UserSummary {
  /// The name to show: «مجهول» / "Anonymous" for the stand-in, else the
  /// person's display name.
  String shownName(AppLocalizations l10n) =>
      anonymous ? l10n.vipAnonymousName : displayName;
}

/// D380: the generic avatar of «مجهول» (no picture, no initial).
class AnonymousAvatar extends StatelessWidget {
  const new({required this.size, super.key});

  final double size;

  static const avatarKey = Key('vip.anonymous.avatar');

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: context.l10n.vipAnonymousName,
    child: ExcludeSemantics(
      child: Container(
        key: avatarKey,
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF5B5F6B), Color(0xFF2E3038)],
          ),
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.person_rounded,
          size: size * 0.62,
          color: const Color(0xCCFFFFFF),
        ),
      ),
    ),
  );
}

/// D380: [user]'s avatar — the generic one for «مجهول».
Widget personAvatar(UserSummary user, {required double size}) => user.anonymous
    ? AnonymousAvatar(size: size)
    : KAvatar(name: user.displayName, imageUrl: user.avatarUrl, size: size);
