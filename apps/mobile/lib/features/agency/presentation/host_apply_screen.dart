import 'dart:async';
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/agency/application/agency_providers.dart';
import 'package:kabso_live/features/agency/data/agency_repository.dart';
import 'package:kabso_live/features/agency/data/hosting_application.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/kyc/application/kyc_providers.dart';
import 'package:kabso_live/features/kyc/data/kyc_models.dart';
import 'package:kabso_live/features/kyc/presentation/kyc_step.dart';
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

/// `/agency/host-apply` «كن مضيفاً مع الإدارة» (v1.73-social, D209,
/// CONVENTIONS §10.68): a person who is not a host and in no agency applies
/// to host directly with the Kabso Live team — no agency, no agency
/// commission. The name they host under (the profile's, to check), the
/// country, the date of birth (18+), a contact method, a short bio, up to
/// three links to their streaming accounts, the **mandatory** ID check (the
/// D185 picture tiles) and the host rules accepted. On success «الوكالة»
/// shows «طلبك قيد المراجعة».
class HostApplyScreen extends ConsumerStatefulWidget {
  const new({super.key, this.minAge = 18});

  /// From `MyHostingApplication.rule.minAge` (the server's number).
  final int minAge;

  static const nameKey = Key('host.apply.name');
  static const countryKey = Key('host.apply.country');
  static const birthKey = Key('host.apply.birth');
  static const contactTypeKey = Key('host.apply.contactType');
  static const contactKey = Key('host.apply.contact');
  static const bioKey = Key('host.apply.bio');
  static const addLinkKey = Key('host.apply.addLink');
  static const idCardKey = Key('host.apply.idCard');
  static const selfieKey = Key('host.apply.selfie');
  static const rulesKey = Key('host.apply.rules');
  static const acceptKey = Key('host.apply.accept');
  static const introKey = Key('host.apply.intro');
  static const submitKey = Key('host.apply.submit');
  static const errorKey = Key('host.apply.error');
  static Key linkKey(int i) => Key('host.apply.link.$i');

  /// At most three links (the server's limit).
  static const maxLinks = 3;

  @override
  ConsumerState<HostApplyScreen> createState() => _HostApplyScreenState();
}

class _HostApplyScreenState extends ConsumerState<HostApplyScreen> {
  late final TextEditingController _name = TextEditingController(
    text: ref.read(currentUserProvider)?.displayName ?? '',
  );
  final _contact = TextEditingController();
  final _bio = TextEditingController();
  final List<TextEditingController> _links = [TextEditingController()];

  /// The profile's country when it is one of the list.
  late String? _country = switch (ref
      .read(currentUserProvider)
      ?.country
      ?.toUpperCase()) {
    final String c when rechargeCountries.contains(c) => c,
    _ => null,
  };
  DateTime? _birth;
  HostingContactType _contactType = HostingContactType.whatsapp;
  Uint8List? _idCard;
  Uint8List? _selfie;
  bool _accepted = false;
  bool _busy = false;
  bool _tried = false;
  String? _error;

  /// One key per filled-in form: a retry after a lost answer is the same
  /// request (the server answers 200 with the application).
  String _key = newIdempotencyKey();

  @override
  void dispose() {
    _name.dispose();
    _contact.dispose();
    _bio.dispose();
    for (final c in _links) {
      c.dispose();
    }
    super.dispose();
  }

  void _changed() => setState(() {
    _error = null;
    _key = newIdempotencyKey();
  });

  String? _nameError(AppLocalizations l10n) {
    final n = _name.text.trim().characters.length;
    return n >= 1 && n <= 50 ? null : l10n.hostApplyNameError;
  }

  String? _birthError(AppLocalizations l10n) {
    final birth = _birth;
    if (birth == null) return l10n.hostApplyBirthError;
    return ageOn(birth, clock.now()) >= widget.minAge
        ? null
        : l10n.hostApplyMinAge(KFormat.bidiIsolate('${widget.minAge}'));
  }

  String? _contactError(AppLocalizations l10n) =>
      _contact.text.trim().length >= 3 ? null : l10n.hostApplyContactError;

  String? _bioError(AppLocalizations l10n) {
    final n = _bio.text.trim().length;
    return n >= 10 && n <= 300 ? null : l10n.hostApplyBioError;
  }

  static bool _linkOk(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return true;
    final uri = Uri.tryParse(v);
    return v.length <= 200 &&
        uri != null &&
        uri.scheme == 'https' &&
        uri.host.contains('.');
  }

  List<String> get _linkValues => [
    for (final c in _links)
      if (c.text.trim().isNotEmpty) c.text.trim(),
  ];

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

  Future<void> _pickBirth() async {
    final now = clock.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birth ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked == null || !mounted) return;
    _birth = DateTime(picked.year, picked.month, picked.day);
    _changed();
  }

  String _refusal(AppLocalizations l10n, AppFailure failure) {
    final issue = switch (failure) {
      ServerFailure(:final details) => details.firstOrNull?.issue,
      _ => null,
    };
    return switch (HostingApplyRefusal.fromWire(issue)) {
      HostingApplyRefusal.pending => l10n.hostApplyRefusedPending,
      HostingApplyRefusal.alreadyHost => l10n.hostApplyRefusedHost,
      HostingApplyRefusal.hostOfAgency ||
      HostingApplyRefusal.ownsAgency => l10n.hostApplyRefusedAgency,
      HostingApplyRefusal.reapplyCooldown => l10n.hostApplyRefusedCooldown,
      HostingApplyRefusal.accountNotActive => l10n.hostApplyNotActive,
      HostingApplyRefusal.underMinAge => l10n.hostApplyMinAge(
        KFormat.bidiIsolate('${widget.minAge}'),
      ),
      null => failureMessage(l10n, failure),
    };
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    final idCard = _idCard;
    final selfie = _selfie;
    final country = _country;
    final birth = _birth;
    // v1.80-kyc (D227): with Didit on, «تأكيد الهوية» replaces the two
    // pictures (approved, or under Didit's review; the team approves only
    // after an approved check).
    final kyc = ref.read(myKycProvider).value;
    final kycOn = kyc?.enabled ?? false;
    final picturesOk =
        kycOn ||
        (idCard != null &&
            selfie != null &&
            sniffImageType(idCard) != null &&
            sniffImageType(selfie) != null);
    setState(() {
      _tried = true;
      _error = null;
    });
    if (_nameError(l10n) != null ||
        country == null ||
        birth == null ||
        _birthError(l10n) != null ||
        _contactError(l10n) != null ||
        _bioError(l10n) != null ||
        !_links.every((c) => _linkOk(c.text)) ||
        !picturesOk ||
        !kycReady(kyc, KycPurpose.hostApplication) ||
        !_accepted) {
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(agencyRepositoryProvider)
          .applyForHosting(
            HostingDraft(
              displayName: _name.text.trim(),
              country: country,
              dateOfBirth: birth,
              contactType: _contactType,
              contactValue: _contact.text.trim(),
              bio: _bio.text.trim(),
              links: _linkValues,
              idCard: kycOn ? null : idCard,
              idCardType: kycOn || idCard == null
                  ? null
                  : sniffImageType(idCard),
              selfie: kycOn ? null : selfie,
              selfieType: kycOn || selfie == null
                  ? null
                  : sniffImageType(selfie),
              idempotencyKey: _key,
            ),
          );
      if (!mounted) return;
      ref.invalidate(myHostingProvider);
      KSnack.success(context, l10n.hostApplySent);
      // «الوكالة» now says «طلبك قيد المراجعة».
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
        _error = failure.code == ErrorCode.hostApplicationNotAllowed
            ? _refusal(l10n, failure)
            : failureMessage(l10n, failure);
      });
    }
  }

  String _contactName(AppLocalizations l10n, HostingContactType type) =>
      switch (type) {
        HostingContactType.whatsapp => l10n.agencyContactWhatsapp,
        HostingContactType.telegram => l10n.agencyContactTelegram,
        HostingContactType.phone => l10n.agencyContactPhone,
        HostingContactType.email => l10n.agencyContactEmail,
        HostingContactType.other => l10n.agencyContactOther,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final kyc = ref.watch(myKycProvider).value;
    final kycOn = kyc?.enabled ?? false;
    final picturesMissing =
        !kycOn && _tried && (_idCard == null || _selfie == null);
    final kycMissing = _tried && !kycReady(kyc, KycPurpose.hostApplication);
    final birth = _birth;
    return Scaffold(
      backgroundColor: p.background,
      appBar: KAppBar(
        backgroundColor: p.background,
        centerTitle: true,
        title: Text(l10n.hostApplyFormTitle),
      ),
      bottomNavigationBar: _SubmitBar(
        error: _error,
        busy: _busy,
        onSubmit: () => unawaited(_submit()),
      ),
      body: ListView(
        padding: const EdgeInsets.all(KSpacing.lg),
        children: [
          // What it is first: directly with the team, no agency, no commission.
          Container(
            key: HostApplyScreen.introKey,
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
                    Icon(Icons.verified_user_rounded, color: p.success),
                    const SizedBox(width: KSpacing.xs),
                    Expanded(
                      child: Text(
                        l10n.hostApplyTitle,
                        style: t.bodyStrong.copyWith(color: p.textPrimary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: KSpacing.xs),
                Text(
                  l10n.hostApplyIntro,
                  style: t.body.copyWith(color: p.textSecondary),
                ),
              ],
            ),
          ),
          RechargeSection(
            step: 1,
            title: l10n.hostApplyStepInfo,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                KTextField(
                  fieldKey: HostApplyScreen.nameKey,
                  label: l10n.hostApplyName,
                  helperText: l10n.hostApplyNameHint,
                  controller: _name,
                  maxLength: 50,
                  errorText: _tried ? _nameError(l10n) : null,
                  onChanged: (_) => _changed(),
                ),
                const SizedBox(height: KSpacing.sm),
                DropdownButtonFormField<String>(
                  key: HostApplyScreen.countryKey,
                  initialValue: _country,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: l10n.hostApplyCountry,
                    errorText: _tried && _country == null
                        ? l10n.hostApplyCountryError
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
                InkWell(
                  key: HostApplyScreen.birthKey,
                  borderRadius: BorderRadius.circular(KRadius.md),
                  onTap: () => unawaited(_pickBirth()),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: l10n.hostApplyBirth,
                      helperText: l10n.hostApplyMinAge(
                        KFormat.bidiIsolate('${widget.minAge}'),
                      ),
                      helperMaxLines: 2,
                      errorText: _tried ? _birthError(l10n) : null,
                      errorMaxLines: 2,
                      suffixIcon: const Icon(Icons.calendar_month_rounded),
                    ),
                    child: Text(
                      birth == null
                          ? l10n.hostApplyBirthPick
                          : KFormat.bidiIsolate(KFormat.date(birth, locale)),
                      style: t.body.copyWith(
                        color: birth == null ? p.textTertiary : p.textPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: KSpacing.sm),
                DropdownButtonFormField<HostingContactType>(
                  key: HostApplyScreen.contactTypeKey,
                  initialValue: _contactType,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: l10n.hostApplyContactType,
                  ),
                  items: [
                    for (final c in HostingContactType.values)
                      DropdownMenuItem(
                        value: c,
                        child: Text(_contactName(l10n, c)),
                      ),
                  ],
                  onChanged: (c) {
                    _contactType = c ?? HostingContactType.other;
                    _changed();
                  },
                ),
                const SizedBox(height: KSpacing.sm),
                KTextField(
                  fieldKey: HostApplyScreen.contactKey,
                  label: l10n.hostApplyContactValue,
                  controller: _contact,
                  maxLength: 100,
                  textDirection: TextDirection.ltr,
                  keyboardType:
                      _contactType == HostingContactType.whatsapp ||
                          _contactType == HostingContactType.phone
                      ? TextInputType.phone
                      : _contactType == HostingContactType.email
                      ? TextInputType.emailAddress
                      : TextInputType.text,
                  errorText: _tried ? _contactError(l10n) : null,
                  onChanged: (_) => _changed(),
                ),
                const SizedBox(height: KSpacing.sm),
                KTextField(
                  fieldKey: HostApplyScreen.bioKey,
                  label: l10n.hostApplyBio,
                  helperText: l10n.hostApplyBioHint,
                  controller: _bio,
                  maxLength: 300,
                  keyboardType: TextInputType.multiline,
                  errorText: _tried ? _bioError(l10n) : null,
                  onChanged: (_) => _changed(),
                ),
                const SizedBox(height: KSpacing.sm),
                Text(
                  l10n.hostApplyLinks,
                  style: t.bodyStrong.copyWith(color: p.textPrimary),
                ),
                const SizedBox(height: KSpacing.xs),
                for (final (i, c) in _links.indexed) ...[
                  KTextField(
                    fieldKey: HostApplyScreen.linkKey(i),
                    label: 'https://',
                    controller: c,
                    maxLength: 200,
                    textDirection: TextDirection.ltr,
                    keyboardType: TextInputType.url,
                    errorText: _tried && !_linkOk(c.text)
                        ? l10n.hostApplyLinkError
                        : null,
                    onChanged: (_) => _changed(),
                  ),
                  const SizedBox(height: KSpacing.xs),
                ],
                if (_links.length < HostApplyScreen.maxLinks)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      key: HostApplyScreen.addLinkKey,
                      onPressed: () {
                        setState(() => _links.add(TextEditingController()));
                      },
                      icon: const Icon(Icons.add_link_rounded),
                      label: Text(l10n.hostApplyAddLink),
                    ),
                  ),
              ],
            ),
          ),
          if (kycOn)
            RechargeSection(
              step: 2,
              title: l10n.kycStepTitle,
              error: kycMissing ? l10n.kycRequiredToSubmit : null,
              child: const KycStep(purpose: KycPurpose.hostApplication),
            )
          else
            RechargeSection(
              step: 2,
              title: l10n.hostApplyStepId,
              error: picturesMissing ? l10n.agencyOpenIdMissing : null,
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: RechargeIdPicture(
                        key: HostApplyScreen.idCardKey,
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
                        key: HostApplyScreen.selfieKey,
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
            step: 3,
            title: l10n.hostApplyStepRules,
            error: _tried && !_accepted ? l10n.hostApplyRulesError : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.hostApplyRulesText,
                  key: HostApplyScreen.rulesKey,
                  style: t.body.copyWith(color: p.textSecondary),
                ),
                const SizedBox(height: KSpacing.xs),
                InkWell(
                  borderRadius: BorderRadius.circular(KRadius.md),
                  onTap: () => setState(() {
                    _accepted = !_accepted;
                    _key = newIdempotencyKey();
                  }),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        key: HostApplyScreen.acceptKey,
                        value: _accepted,
                        onChanged: (v) => setState(() {
                          _accepted = v ?? false;
                          _key = newIdempotencyKey();
                        }),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsetsDirectional.only(top: 12),
                          child: Text(
                            l10n.hostApplyRulesAccept,
                            style: t.body.copyWith(color: p.textPrimary),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          RechargeSection(
            icon: Icons.lock_outline_rounded,
            title: l10n.rechargeApplyStepPrivacy,
            child: RechargeNotice(
              icon: Icons.lock_outline_rounded,
              text: l10n.hostApplyPrivacy,
            ),
          ),
        ],
      ),
    );
  }
}

/// The sticky bar: the request's failure (if any) and «أرسل الطلب».
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
                    key: HostApplyScreen.errorKey,
                    style: t.caption.copyWith(color: p.error),
                  ),
                ),
              KButton(
                key: HostApplyScreen.submitKey,
                label: l10n.hostApplySubmit,
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
