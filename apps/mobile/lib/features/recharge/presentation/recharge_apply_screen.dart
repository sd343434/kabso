import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/posts/data/media_repository.dart'
    show sniffImageType;
import 'package:kabso_live/features/profile/data/profile_edit_repository.dart';
import 'package:kabso_live/features/recharge/application/recharge_providers.dart';
import 'package:kabso_live/features/recharge/data/recharge_repository.dart';
import 'package:kabso_live/features/recharge/presentation/recharge_widgets.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// `/recharge/apply` «كن وكيل شحن» (v1.54-social, D185, §10.48): the full
/// four-part name, a phone number with WhatsApp, a photo of the agent, a
/// face-confirmation selfie (taken with the front camera; a person at Kabso
/// reviews it), the selling locations (country + cities) and the payment
/// methods per country. Checked here like the server checks it; the two
/// pictures go up as private uploads the application consumes (never
/// public). The data is private: only the team reads it.
class RechargeApplyScreen extends ConsumerStatefulWidget {
  const new({super.key});

  static const nameKey = Key('recharge.apply.name');
  static const phoneKey = Key('recharge.apply.phone');
  static const photoKey = Key('recharge.apply.photo');
  static const selfieKey = Key('recharge.apply.selfie');
  static const submitKey = Key('recharge.apply.submit');
  static const addLocationKey = Key('recharge.apply.addLocation');
  static const addPaymentKey = Key('recharge.apply.addPayment');
  static Key countryKey(int i) => Key('recharge.apply.country.$i');
  static Key citiesKey(int i) => Key('recharge.apply.cities.$i');
  static Key paymentKey(int i) => Key('recharge.apply.payment.$i');

  @override
  ConsumerState<RechargeApplyScreen> createState() =>
      _RechargeApplyScreenState();
}

class _Location {
  final country = TextEditingController();
  final cities = TextEditingController();

  void dispose() {
    country.dispose();
    cities.dispose();
  }
}

class _Payment {
  new(this.country);

  String country;
  RechargePaymentType type = RechargePaymentType.mobileWallet;
  final details = TextEditingController();
}

class _RechargeApplyScreenState extends ConsumerState<RechargeApplyScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _locations = <_Location>[_Location()];
  final _payments = <_Payment>[_Payment('')];
  Uint8List? _photo;
  Uint8List? _selfie;
  bool _busy = false;
  bool _tried = false;
  String? _error;

  static final _e164 = RegExp(r'^\+[1-9][0-9]{7,14}$');

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    for (final l in _locations) {
      l.dispose();
    }
    for (final p in _payments) {
      p.details.dispose();
    }
    super.dispose();
  }

  List<String> get _countries => [
    for (final l in _locations)
      if (l.country.text.trim().length == 2)
        l.country.text.trim().toUpperCase(),
  ];

  String? _nameError(AppLocalizations l10n) {
    final words = _name.text.trim().split(RegExp(r'\s+'));
    final ok =
        _name.text.trim().length >= 8 &&
        words.where((w) => w.isNotEmpty).length >= 4;
    return ok ? null : l10n.rechargeFullNameError;
  }

  String? _phoneError(AppLocalizations l10n) =>
      _e164.hasMatch(_phone.text.trim()) ? null : l10n.rechargePhoneError;

  Future<void> _pick(bool selfie) async {
    final bytes = await ref
        .read(avatarPhotoPickerProvider)
        .pick(selfie ? AvatarSource.camera : AvatarSource.library);
    if (bytes == null || !mounted) return;
    setState(() => selfie ? _selfie = bytes : _photo = bytes);
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    setState(() {
      _tried = true;
      _error = null;
    });
    final locations = <RechargeLocation>[];
    for (final l in _locations) {
      final country = l.country.text.trim().toUpperCase();
      final cities = [
        for (final c in l.cities.text.split(RegExp('[,،]')))
          if (c.trim().isNotEmpty) c.trim(),
      ];
      if (!RegExp(r'^[A-Z]{2}$').hasMatch(country) || cities.isEmpty) {
        setState(() => _error = l10n.rechargeLocationError);
        return;
      }
      locations.add((country: country, cities: cities));
    }
    final payments = [
      for (final p in _payments)
        (country: p.country, type: p.type, details: p.details.text.trim()),
    ];
    if (payments.any(
      (p) => p.details.isEmpty || !locations.any((l) => l.country == p.country),
    )) {
      setState(() => _error = l10n.rechargePaymentError);
      return;
    }
    final photo = _photo;
    final selfie = _selfie;
    if (_nameError(l10n) != null || _phoneError(l10n) != null) return;
    if (photo == null || selfie == null) {
      setState(() => _error = l10n.rechargeMissingPhotos);
      return;
    }
    final photoType = sniffImageType(photo);
    final selfieType = sniffImageType(selfie);
    if (photoType == null || selfieType == null) {
      setState(() => _error = l10n.rechargeMissingPhotos);
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(rechargeRepositoryProvider)
          .apply(
            RechargeApplicationDraft(
              fullName: _name.text.trim(),
              phone: _phone.text.trim(),
              photo: photo,
              photoType: photoType,
              selfie: selfie,
              selfieType: selfieType,
              locations: locations,
              paymentMethods: payments,
            ),
          );
      if (!mounted) return;
      ref.invalidate(myRechargeAgentProvider);
      KSnack.success(context, l10n.rechargeSubmitted);
      // Back to «وكيل الشحن» (now «قيد المراجعة»).
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppRoutes.recharge);
      }
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = failureMessage(l10n, toAppFailure(e));
      });
    }
  }

  Widget _picture({
    required Key key,
    required String title,
    required String hint,
    required Uint8List? bytes,
    required IconData icon,
    required VoidCallback onPick,
  }) {
    final p = context.palette;
    final t = context.textStyles;
    return Semantics(
      button: true,
      label: '$title. $hint',
      excludeSemantics: true,
      child: InkWell(
        key: key,
        onTap: onPick,
        borderRadius: BorderRadius.circular(KRadius.md),
        child: Container(
          padding: const EdgeInsets.all(KSpacing.sm),
          decoration: BoxDecoration(
            border: Border.all(
              color: _tried && bytes == null ? p.error : p.border,
            ),
            borderRadius: BorderRadius.circular(KRadius.md),
          ),
          child: Column(
            children: [
              SizedBox.square(
                dimension: 84,
                child: ClipOval(
                  child: bytes == null
                      ? ColoredBox(
                          color: p.surfaceOverlay,
                          child: Icon(icon, size: 36, color: p.textSecondary),
                        )
                      : Image.memory(bytes, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(height: KSpacing.xs),
              Text(
                title,
                textAlign: TextAlign.center,
                style: t.bodyStrong.copyWith(color: p.textPrimary),
              ),
              Text(
                hint,
                textAlign: TextAlign.center,
                style: t.caption.copyWith(color: p.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _typeName(AppLocalizations l10n, RechargePaymentType type) =>
      rechargePaymentTypeName(l10n, type);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final countries = _countries;
    return Scaffold(
      backgroundColor: p.background,
      appBar: KAppBar(
        backgroundColor: p.background,
        centerTitle: true,
        title: Text(l10n.rechargeApplyTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(KSpacing.lg),
        children: [
          RechargeNotice(
            icon: Icons.lock_outline_rounded,
            text: l10n.rechargePrivacyNote,
          ),
          const SizedBox(height: KSpacing.md),
          KTextField(
            fieldKey: RechargeApplyScreen.nameKey,
            label: l10n.rechargeFullName,
            helperText: l10n.rechargeFullNameHint,
            controller: _name,
            maxLength: 120,
            errorText: _tried ? _nameError(l10n) : null,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: KSpacing.sm),
          KTextField(
            fieldKey: RechargeApplyScreen.phoneKey,
            label: l10n.rechargePhone,
            helperText: l10n.rechargePhoneHint,
            controller: _phone,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[+0-9]')),
              LengthLimitingTextInputFormatter(16),
            ],
            errorText: _tried ? _phoneError(l10n) : null,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: KSpacing.md),
          Row(
            children: [
              Expanded(
                child: _picture(
                  key: RechargeApplyScreen.photoKey,
                  title: l10n.rechargePhoto,
                  hint: l10n.rechargePhotoHint,
                  bytes: _photo,
                  icon: Icons.person_rounded,
                  onPick: () => unawaited(_pick(false)),
                ),
              ),
              const SizedBox(width: KSpacing.sm),
              Expanded(
                child: _picture(
                  key: RechargeApplyScreen.selfieKey,
                  title: l10n.rechargeSelfie,
                  hint: l10n.rechargeSelfieHint,
                  bytes: _selfie,
                  icon: Icons.face_retouching_natural_rounded,
                  onPick: () => unawaited(_pick(true)),
                ),
              ),
            ],
          ),
          const SizedBox(height: KSpacing.lg),
          Text(
            l10n.rechargeLocations,
            style: t.bodyStrong.copyWith(color: p.textPrimary),
          ),
          const SizedBox(height: KSpacing.xs),
          for (final (i, l) in _locations.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: KSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 92,
                    child: KTextField(
                      fieldKey: RechargeApplyScreen.countryKey(i),
                      label: l10n.rechargeCountry,
                      controller: l.country,
                      textDirection: TextDirection.ltr,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp('[A-Za-z]')),
                        LengthLimitingTextInputFormatter(2),
                      ],
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: KSpacing.xs),
                  Expanded(
                    child: KTextField(
                      fieldKey: RechargeApplyScreen.citiesKey(i),
                      label: l10n.rechargeCities,
                      controller: l.cities,
                    ),
                  ),
                  if (_locations.length > 1)
                    IconButton(
                      tooltip: l10n.rechargeRemove,
                      onPressed: () => setState(() {
                        _locations.removeAt(i).dispose();
                      }),
                      icon: Icon(Icons.close_rounded, color: p.textSecondary),
                    ),
                ],
              ),
            ),
          if (_locations.length < 10)
            TextButton.icon(
              key: RechargeApplyScreen.addLocationKey,
              onPressed: () => setState(() => _locations.add(_Location())),
              icon: const Icon(Icons.add_location_alt_rounded),
              label: Text(l10n.rechargeAddLocation),
            ),
          const SizedBox(height: KSpacing.md),
          Text(
            l10n.rechargePaymentMethods,
            style: t.bodyStrong.copyWith(color: p.textPrimary),
          ),
          const SizedBox(height: KSpacing.xs),
          for (final (i, pay) in _payments.indexed)
            Container(
              key: RechargeApplyScreen.paymentKey(i),
              margin: const EdgeInsets.only(bottom: KSpacing.sm),
              padding: const EdgeInsets.all(KSpacing.sm),
              decoration: BoxDecoration(
                border: Border.all(color: p.border),
                borderRadius: BorderRadius.circular(KRadius.md),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: countries.contains(pay.country)
                              ? pay.country
                              : null,
                          decoration: InputDecoration(
                            labelText: l10n.rechargeCountry,
                          ),
                          items: [
                            for (final c in countries)
                              DropdownMenuItem(value: c, child: Text(c)),
                          ],
                          onChanged: (c) =>
                              setState(() => pay.country = c ?? ''),
                        ),
                      ),
                      const SizedBox(width: KSpacing.xs),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<RechargePaymentType>(
                          initialValue: pay.type,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: l10n.rechargePaymentType,
                          ),
                          items: [
                            for (final ty in RechargePaymentType.values)
                              DropdownMenuItem(
                                value: ty,
                                child: Text(_typeName(l10n, ty)),
                              ),
                          ],
                          onChanged: (ty) => setState(
                            () => pay.type = ty ?? RechargePaymentType.other,
                          ),
                        ),
                      ),
                      if (_payments.length > 1)
                        IconButton(
                          tooltip: l10n.rechargeRemove,
                          onPressed: () => setState(() {
                            _payments.removeAt(i).details.dispose();
                          }),
                          icon: Icon(
                            Icons.close_rounded,
                            color: p.textSecondary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: KSpacing.xs),
                  KTextField(
                    label: l10n.rechargePaymentDetails,
                    controller: pay.details,
                    maxLength: 200,
                  ),
                ],
              ),
            ),
          if (_payments.length < 30)
            TextButton.icon(
              key: RechargeApplyScreen.addPaymentKey,
              onPressed: () => setState(
                () => _payments.add(
                  _Payment(countries.isEmpty ? '' : countries.first),
                ),
              ),
              icon: const Icon(Icons.add_card_rounded),
              label: Text(l10n.rechargeAddPayment),
            ),
          if (_error case final e?)
            Padding(
              padding: const EdgeInsets.only(top: KSpacing.sm),
              child: Text(
                e,
                key: const Key('recharge.apply.error'),
                style: t.caption.copyWith(color: p.error),
              ),
            ),
          const SizedBox(height: KSpacing.lg),
          KButton(
            key: RechargeApplyScreen.submitKey,
            label: l10n.rechargeSubmit,
            loading: _busy,
            onPressed: _busy ? null : () => unawaited(_submit()),
          ),
        ],
      ),
    );
  }
}

/// The name of a payment-method type.
String rechargePaymentTypeName(
  AppLocalizations l10n,
  RechargePaymentType type,
) => switch (type) {
  RechargePaymentType.bankTransfer => l10n.rechargePayBank,
  RechargePaymentType.mobileWallet => l10n.rechargePayWallet,
  RechargePaymentType.cash => l10n.rechargePayCash,
  RechargePaymentType.card => l10n.rechargePayCard,
  RechargePaymentType.crypto => l10n.rechargePayCrypto,
  RechargePaymentType.other => l10n.rechargePayOther,
};
