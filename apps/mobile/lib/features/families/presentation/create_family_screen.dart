import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/core/ids/client_id.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/families/application/families_providers.dart';
import 'package:kabso_live/features/families/data/families_repository.dart';
import 'package:kabso_live/features/families/presentation/bond_widgets.dart';
import 'package:kabso_live/features/live/application/live_wallet_controller.dart';
import 'package:kabso_live/features/posts/application/compose_controller.dart';
import 'package:kabso_live/features/posts/data/media_repository.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// `/families/new` (CP-018, §10.21): a name (2–20 characters, unique), an
/// optional emblem photo (`FAMILY_EMBLEM` upload), and the price from
/// `GET /families/config` against the balance (`GET /wallet/me`). The
/// request carries one `clientId` for this attempt, so a retry is never
/// charged twice. Too few coins is said before and after asking the server
/// (409 `INSUFFICIENT_COINS`: nothing created or charged).
class CreateFamilyScreen extends ConsumerStatefulWidget {
  const new({super.key});

  static const nameKey = Key('families.new.name');
  static const emblemKey = Key('families.new.emblem');
  static const submitKey = Key('families.new.submit');
  static const notEnoughKey = Key('families.new.notEnough');

  @override
  ConsumerState<CreateFamilyScreen> createState() => _CreateFamilyState();
}

class _CreateFamilyState extends ConsumerState<CreateFamilyScreen> {
  final _name = TextEditingController();
  late String _clientId = newClientId();
  Uint8List? _emblem;
  late String _emblemType;

  /// The uploaded emblem of [_emblem], reused when creating again.
  String? _emblemId;
  String? _nameError;
  bool _busy = false;

  /// The server said the balance is too low.
  bool _refusedCoins = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickEmblem() async {
    final l10n = context.l10n;
    final picked = await ref.read(photoPickerProvider).pickPhotos(1);
    if (!mounted || picked.isEmpty) return;
    final bytes = picked.first;
    final type = sniffImageType(bytes);
    if (type == null) {
      KSnack.error(context, l10n.createPhotoUnsupported);
      return;
    }
    if (bytes.length > maxPhotoBytes) {
      KSnack.error(context, l10n.createPhotoTooLarge);
      return;
    }
    setState(() {
      _emblem = bytes;
      _emblemType = type;
      _emblemId = null;
    });
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    final name = _name.text.trim();
    if (name.characters.length < 2 || name.characters.length > 20) {
      setState(() => _nameError = l10n.familyNameInvalid);
      return;
    }
    setState(() {
      _busy = true;
      _nameError = null;
      _refusedCoins = false;
    });
    try {
      var emblemId = _emblemId;
      if (_emblem case final bytes? when emblemId == null) {
        emblemId =
            (await ref
                    .read(mediaRepositoryProvider)
                    .uploadFamilyEmblem(bytes, _emblemType))
                .id;
        _emblemId = emblemId;
      }
      final result = await ref
          .read(familiesRepositoryProvider)
          .create(name: name, clientId: _clientId, emblemMediaId: emblemId);
      if (!mounted) return;
      _clientId = newClientId();
      showCoins(ref, result.coins);
      refreshFamilies(ref);
      KSnack.success(context, l10n.familyCreated(result.family.name));
      context.pushReplacement(AppRoutes.family(result.family.id));
    } on Object catch (e) {
      if (!mounted) return;
      final failure = toAppFailure(e);
      switch (failure.code) {
        case ErrorCode.insufficientCoins:
          reloadCoins(ref);
          setState(() => _refusedCoins = true);
        case ErrorCode.familyNameTaken:
          setState(() => _nameError = l10n.errorFamilyNameTaken);
        case ErrorCode.validationFailed
            when failure is ServerFailure &&
                failure.details.any((d) => d.field == 'name'):
          setState(() => _nameError = l10n.familyNameInvalid);
        case _:
          KSnack.error(context, failureMessage(l10n, failure));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final config = ref.watch(familyConfigProvider);
    final coins = ref.watch(liveCoinsProvider).value;
    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        backgroundColor: p.background,
        centerTitle: true,
        title: Text(l10n.familyCreateTitle),
      ),
      body: switch (config) {
        AsyncValue(:final value?) => Builder(
          builder: (context) {
            final cost = value.createCost;
            final price = l10n.bondsCoins(cost);
            final short = coins != null && coins < cost;
            final notEnough = short || _refusedCoins;
            return ListView(
              padding: const EdgeInsets.all(KSpacing.lg),
              children: [
                Center(
                  child: Semantics(
                    button: true,
                    label: l10n.familyEmblemChoose,
                    excludeSemantics: true,
                    child: InkWell(
                      key: CreateFamilyScreen.emblemKey,
                      customBorder: const CircleBorder(),
                      onTap: _busy ? null : _pickEmblem,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          if (_emblem case final emblem?)
                            ClipOval(
                              child: Image.memory(
                                emblem,
                                width: 88,
                                height: 88,
                                fit: BoxFit.cover,
                              ),
                            )
                          else
                            const FamilyEmblem(url: null, size: 88),
                          PositionedDirectional(
                            bottom: 0,
                            end: 0,
                            child: CircleAvatar(
                              radius: 14,
                              backgroundColor: p.primary,
                              child: Icon(
                                Icons.photo_camera_rounded,
                                size: 16,
                                color: p.onPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: KSpacing.xs),
                Center(
                  child: Text(
                    l10n.familyEmblemLabel,
                    style: t.caption.copyWith(color: p.textSecondary),
                  ),
                ),
                const SizedBox(height: KSpacing.lg),
                KTextField(
                  fieldKey: CreateFamilyScreen.nameKey,
                  label: l10n.familyNameLabel,
                  controller: _name,
                  helperText: l10n.familyNameHelp,
                  errorText: _nameError,
                  enabled: !_busy,
                  maxLength: 20,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) {
                    if (_nameError != null) setState(() => _nameError = null);
                  },
                ),
                const SizedBox(height: KSpacing.lg),
                Text(
                  l10n.familyCreateCost(price),
                  style: t.bodyStrong.copyWith(color: p.textPrimary),
                ),
                if (coins != null)
                  Text(
                    l10n.bondsBalance(l10n.bondsCoins(coins)),
                    style: t.body.copyWith(color: p.textSecondary),
                  ),
                if (notEnough) ...[
                  const SizedBox(height: KSpacing.md),
                  KInlineMessage(
                    key: CreateFamilyScreen.notEnoughKey,
                    message: l10n.familyCreateNotEnough(price),
                  ),
                ],
                const SizedBox(height: KSpacing.xl),
                KButton(
                  key: CreateFamilyScreen.submitKey,
                  label: l10n.familyCreateSubmit(price),
                  loading: _busy,
                  onPressed: short ? null : _submit,
                ),
              ],
            );
          },
        ),
        AsyncValue(:final error?, isLoading: false) => FailureErrorState(
          title: l10n.errorTitle,
          failure: toAppFailure(error),
          onRetry: () => ref.invalidate(familyConfigProvider),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}
