import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/agency/application/agency_providers.dart';
import 'package:kabso_live/features/agency/data/agency_repository.dart';
import 'package:kabso_live/features/posts/application/compose_controller.dart'
    show newIdempotencyKey;
import 'package:kabso_live/features/posts/data/media_repository.dart'
    show sniffImageType;
import 'package:kabso_live/features/profile/data/profile_edit_repository.dart';
import 'package:kabso_live/features/recharge/presentation/recharge_directory_screen.dart'
    show rechargeCountries, rechargeCountryName;
import 'package:kabso_live/features/recharge/presentation/recharge_widgets.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// `/agency/open` «افتح وكالة» (v1.70-social, D206, §10.65): a person in no
/// agency opens one — free. The agency's name, the country, a contact
/// method, the expected hosts and a short bio, then the **mandatory** ID
/// check (an ID card and a selfie: the D185 private uploads, the recharge
/// application's picture tiles). The 7-day rule and «free» are said before
/// the button. On success the agency exists at once: back to «الوكالة»,
/// which is now the owner's dashboard with the probation card on top.
class AgencyOpenScreen extends ConsumerStatefulWidget {
  const new({super.key, this.probationDays = 7, this.requiredHosts = 3});

  /// From `MyAgency.openRule` (the server's numbers).
  final int probationDays;
  final int requiredHosts;

  static const nameKey = Key('agency.open.name');
  static const countryKey = Key('agency.open.country');
  static const contactTypeKey = Key('agency.open.contactType');
  static const contactKey = Key('agency.open.contact');
  static const expectedKey = Key('agency.open.expected');
  static const bioKey = Key('agency.open.bio');
  static const idCardKey = Key('agency.open.idCard');
  static const selfieKey = Key('agency.open.selfie');
  static const ruleKey = Key('agency.open.rule');
  static const submitKey = Key('agency.open.submit');
  static const errorKey = Key('agency.open.error');

  @override
  ConsumerState<AgencyOpenScreen> createState() => _AgencyOpenScreenState();
}

class _AgencyOpenScreenState extends ConsumerState<AgencyOpenScreen> {
  final _name = TextEditingController();
  final _contact = TextEditingController();
  final _expected = TextEditingController();
  final _bio = TextEditingController();
  String? _country;
  AgencyContactType _contactType = AgencyContactType.whatsapp;
  Uint8List? _idCard;
  Uint8List? _selfie;
  bool _busy = false;
  bool _tried = false;
  String? _error;

  /// One key per filled-in form: a retry after a lost answer is the same
  /// request (the server answers 200 with the agency).
  String _key = newIdempotencyKey();

  @override
  void dispose() {
    _name.dispose();
    _contact.dispose();
    _expected.dispose();
    _bio.dispose();
    super.dispose();
  }

  void _changed() => setState(() {
    _error = null;
    _key = newIdempotencyKey();
  });

  String? _nameError(AppLocalizations l10n) {
    final n = _name.text.trim().length;
    return n >= 2 && n <= 40 ? null : l10n.agencyOpenNameError;
  }

  String? _contactError(AppLocalizations l10n) =>
      _contact.text.trim().length >= 3 ? null : l10n.agencyOpenContactError;

  int? get _expectedValue {
    final v = int.tryParse(_expected.text.trim());
    return v != null && v >= 1 && v <= 10000 ? v : null;
  }

  Future<void> _pick(bool selfie) async {
    final bytes = await ref
        .read(avatarPhotoPickerProvider)
        .pick(selfie ? AvatarSource.camera : AvatarSource.library);
    if (bytes == null || !mounted) return;
    setState(() {
      selfie ? _selfie = bytes : _idCard = bytes;
      _key = newIdempotencyKey();
    });
  }

  String _refusal(AppLocalizations l10n, AppFailure failure) {
    final issue = switch (failure) {
      ServerFailure(:final details) => details.firstOrNull?.issue,
      _ => null,
    };
    return switch (AgencyOpenRefusal.fromWire(issue)) {
      AgencyOpenRefusal.ownsAgency => l10n.agencyOpenOwns,
      AgencyOpenRefusal.hostOfAgency => l10n.agencyOpenIsHost,
      AgencyOpenRefusal.accountNotActive => l10n.agencyOpenNotActive,
      AgencyOpenRefusal.reopenCooldown || null => failureMessage(l10n, failure),
    };
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    final idCard = _idCard;
    final selfie = _selfie;
    final expected = _expectedValue;
    final country = _country;
    final picturesOk =
        idCard != null &&
        selfie != null &&
        sniffImageType(idCard) != null &&
        sniffImageType(selfie) != null;
    setState(() {
      _tried = true;
      _error = null;
    });
    if (_nameError(l10n) != null ||
        _contactError(l10n) != null ||
        country == null ||
        expected == null ||
        !picturesOk) {
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(agencyRepositoryProvider)
          .open(
            AgencyOpenDraft(
              name: _name.text.trim(),
              country: country,
              contactType: _contactType,
              contactValue: _contact.text.trim(),
              expectedHosts: expected,
              bio: _bio.text.trim(),
              idCard: idCard,
              idCardType: sniffImageType(idCard)!,
              selfie: selfie,
              selfieType: sniffImageType(selfie)!,
              idempotencyKey: _key,
            ),
          );
      if (!mounted) return;
      ref
        ..invalidate(myAgencyProvider)
        ..invalidate(agencyHostsProvider);
      KSnack.success(context, l10n.agencyOpenDone);
      // «الوكالة» is now the owner's dashboard (with the probation card).
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppRoutes.agency);
      }
    } on Object catch (e) {
      if (!mounted) return;
      final failure = toAppFailure(e);
      setState(() {
        _busy = false;
        _error = failure.code == ErrorCode.agencyOpenNotAllowed
            ? _refusal(l10n, failure)
            : failureMessage(l10n, failure);
      });
    }
  }

  String _contactName(AppLocalizations l10n, AgencyContactType type) =>
      switch (type) {
        AgencyContactType.whatsapp => l10n.agencyContactWhatsapp,
        AgencyContactType.telegram => l10n.agencyContactTelegram,
        AgencyContactType.phone => l10n.agencyContactPhone,
        AgencyContactType.email => l10n.agencyContactEmail,
        AgencyContactType.other => l10n.agencyContactOther,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final days = l10n.agencyDaysCount(widget.probationDays);
    final hosts = l10n.agencyHostsCount(widget.requiredHosts);
    final picturesMissing = _tried && (_idCard == null || _selfie == null);
    return Scaffold(
      backgroundColor: p.background,
      appBar: KAppBar(
        backgroundColor: p.background,
        centerTitle: true,
        title: Text(l10n.agencyOpenTitle),
      ),
      bottomNavigationBar: _SubmitBar(
        error: _error,
        busy: _busy,
        onSubmit: () => unawaited(_submit()),
      ),
      body: ListView(
        padding: const EdgeInsets.all(KSpacing.lg),
        children: [
          // The rule first: free, created at once, 3 hosts in 7 days.
          Container(
            key: AgencyOpenScreen.ruleKey,
            margin: const EdgeInsets.only(bottom: KSpacing.md),
            padding: const EdgeInsets.all(KSpacing.md),
            decoration: BoxDecoration(
              color: KBrandColors.red400.withValues(alpha: 0.10),
              border: Border.all(
                color: KBrandColors.red400.withValues(alpha: 0.35),
              ),
              borderRadius: BorderRadius.circular(KRadius.lg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.verified_rounded, color: p.success, size: 20),
                    const SizedBox(width: KSpacing.xs),
                    Expanded(
                      child: Text(
                        l10n.agencyOpenFree,
                        style: t.bodyStrong.copyWith(color: p.textPrimary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: KSpacing.xs),
                Text(
                  l10n.agencyOpenRule(days, hosts),
                  style: t.body.copyWith(color: p.textSecondary),
                ),
              ],
            ),
          ),
          RechargeSection(
            step: 1,
            title: l10n.agencyOpenStepInfo,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                KTextField(
                  fieldKey: AgencyOpenScreen.nameKey,
                  label: l10n.agencyOpenName,
                  controller: _name,
                  maxLength: 40,
                  errorText: _tried ? _nameError(l10n) : null,
                  onChanged: (_) => _changed(),
                ),
                const SizedBox(height: KSpacing.sm),
                DropdownButtonFormField<String>(
                  key: AgencyOpenScreen.countryKey,
                  initialValue: _country,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: l10n.agencyOpenCountry,
                    errorText: _tried && _country == null
                        ? l10n.agencyOpenCountryError
                        : null,
                  ),
                  items: [
                    for (final c in rechargeCountries)
                      DropdownMenuItem(
                        value: c,
                        child: Text(
                          rechargeCountryName(context, c),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (c) {
                    _country = c;
                    _changed();
                  },
                ),
                const SizedBox(height: KSpacing.sm),
                DropdownButtonFormField<AgencyContactType>(
                  key: AgencyOpenScreen.contactTypeKey,
                  initialValue: _contactType,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: l10n.agencyOpenContactType,
                  ),
                  items: [
                    for (final c in AgencyContactType.values)
                      DropdownMenuItem(
                        value: c,
                        child: Text(_contactName(l10n, c)),
                      ),
                  ],
                  onChanged: (c) {
                    _contactType = c ?? AgencyContactType.other;
                    _changed();
                  },
                ),
                const SizedBox(height: KSpacing.sm),
                KTextField(
                  fieldKey: AgencyOpenScreen.contactKey,
                  label: l10n.agencyOpenContactValue,
                  controller: _contact,
                  maxLength: 100,
                  textDirection: TextDirection.ltr,
                  keyboardType:
                      _contactType == AgencyContactType.whatsapp ||
                          _contactType == AgencyContactType.phone
                      ? TextInputType.phone
                      : _contactType == AgencyContactType.email
                      ? TextInputType.emailAddress
                      : TextInputType.text,
                  errorText: _tried ? _contactError(l10n) : null,
                  onChanged: (_) => _changed(),
                ),
                const SizedBox(height: KSpacing.sm),
                KTextField(
                  fieldKey: AgencyOpenScreen.expectedKey,
                  label: l10n.agencyOpenExpected,
                  controller: _expected,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(5),
                  ],
                  errorText: _tried && _expectedValue == null
                      ? l10n.agencyOpenExpectedError
                      : null,
                  onChanged: (_) => _changed(),
                ),
                const SizedBox(height: KSpacing.sm),
                KTextField(
                  fieldKey: AgencyOpenScreen.bioKey,
                  label: l10n.agencyOpenBio,
                  helperText: l10n.agencyOpenBioHint,
                  controller: _bio,
                  maxLength: 300,
                  keyboardType: TextInputType.multiline,
                  onChanged: (_) => _changed(),
                ),
              ],
            ),
          ),
          RechargeSection(
            step: 2,
            title: l10n.agencyOpenStepId,
            error: picturesMissing ? l10n.agencyOpenIdMissing : null,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: RechargeIdPicture(
                      key: AgencyOpenScreen.idCardKey,
                      title: l10n.agencyOpenIdCard,
                      hint: l10n.agencyOpenIdCardHint,
                      bytes: _idCard,
                      icon: Icons.badge_rounded,
                      missing: _tried && _idCard == null,
                      onPick: () => unawaited(_pick(false)),
                    ),
                  ),
                  const SizedBox(width: KSpacing.sm),
                  Expanded(
                    child: RechargeIdPicture(
                      key: AgencyOpenScreen.selfieKey,
                      title: l10n.rechargeSelfie,
                      hint: l10n.rechargeSelfieHint,
                      bytes: _selfie,
                      icon: Icons.face_retouching_natural_rounded,
                      missing: _tried && _selfie == null,
                      onPick: () => unawaited(_pick(true)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          RechargeSection(
            icon: Icons.lock_outline_rounded,
            title: l10n.rechargeApplyStepPrivacy,
            child: RechargeNotice(
              icon: Icons.lock_outline_rounded,
              text: l10n.agencyOpenPrivacy,
            ),
          ),
        ],
      ),
    );
  }
}

/// The sticky bar: the request's failure (if any) and «افتح الوكالة مجانًا».
class _SubmitBar extends StatelessWidget {
  const new({required this.error, required this.busy, required this.onSubmit});

  final String? error;
  final bool busy;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final error = this.error;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.surfaceRaised,
        border: Border(top: BorderSide(color: p.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            KSpacing.lg,
            KSpacing.sm,
            KSpacing.lg,
            KSpacing.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: KSpacing.xs),
                  child: Text(
                    error,
                    key: AgencyOpenScreen.errorKey,
                    style: t.caption.copyWith(color: p.error),
                  ),
                ),
              KButton(
                key: AgencyOpenScreen.submitKey,
                label: l10n.agencyOpenSubmit,
                loading: busy,
                onPressed: busy ? null : onSubmit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
