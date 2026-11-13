import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/data/live_gift_repository.dart';
import 'package:kabso_live/features/live/domain/live_gift_models.dart';
import 'package:kabso_live/features/posts/presentation/report_sheet.dart';
import 'package:kabso_live/features/vip/presentation/vip_anonymous.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// v1.133-social (D380, §10.170.5): what a recipient of an anonymous gift
/// «إهداء مجهول» can do without learning who sent it — report the sender
/// (`reportLiveGift`) or refuse their further anonymous gifts
/// (`blockAnonymousGiftSender`). Opened by a tap on the gift's strip.
abstract final class AnonymousGiftKeys {
  static const sheet = Key('gift.anonymous.sheet');
  static const report = Key('gift.anonymous.report');
  static const refuse = Key('gift.anonymous.refuse');
}

Future<void> showAnonymousGiftActions(
  BuildContext context,
  WidgetRef ref,
  LiveGift gift,
) async {
  final l10n = context.l10n;
  final action = await showModalBottomSheet<String>(
    context: context,
    builder: (sheet) => SafeArea(
      child: Column(
        key: AnonymousGiftKeys.sheet,
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const AnonymousAvatar(size: 36),
            title: Text(l10n.liveGiftAnonymousFrom),
            subtitle: Text(l10n.liveGiftAnonymousHint),
          ),
          ListTile(
            key: AnonymousGiftKeys.report,
            leading: const Icon(Icons.flag_outlined),
            title: Text(l10n.liveGiftAnonymousReport),
            onTap: () => Navigator.of(sheet).pop('report'),
          ),
          ListTile(
            key: AnonymousGiftKeys.refuse,
            leading: const Icon(Icons.block_rounded),
            title: Text(l10n.liveGiftAnonymousRefuse),
            onTap: () => Navigator.of(sheet).pop('refuse'),
          ),
        ],
      ),
    ),
  );
  if (action == null || !context.mounted) return;
  final repo = ref.read(liveGiftRepositoryProvider);
  try {
    if (action == 'report') {
      final reason = await pickReportReason(
        context,
        l10n.liveGiftAnonymousReport,
      );
      if (reason == null || !context.mounted) return;
      await repo.reportGift(gift.id, reason: reason.wire);
      if (context.mounted) KSnack.success(context, l10n.liveGiftReported);
    } else {
      await repo.setAnonymousSenderRefused(gift.id, refused: true);
      if (context.mounted) {
        KSnack.success(context, l10n.liveGiftAnonymousRefused);
      }
    }
  } on Object catch (e) {
    if (context.mounted) {
      KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
    }
  }
}

/// D380: opens [showAnonymousGiftActions] (fire and forget).
void openAnonymousGiftActions(
  BuildContext context,
  WidgetRef ref,
  LiveGift gift,
) => unawaited(showAnonymousGiftActions(context, ref, gift));
