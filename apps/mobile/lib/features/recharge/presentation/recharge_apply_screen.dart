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
import 'package:kabso_live/features/recharge/presentation/recharge_directory_screen.dart'
    show rechargeCountries, rechargeCountryName;
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
  /// ISO alpha-2, chosen from the list.
  String? country;
  final cities = TextEditingController();

  List<String> get cityList => [
    for (final c in cities.text.split(RegExp('[,،]')))
      if (c.trim().isNotEmpty) c.trim(),
  ];

  void dispose() => cities.dispose();
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

  /// A failure of the request itself (shown above the submit bar).
  String? _error;

  /// The sections' own messages after a submit that was refused here.
  String? _locationError;
  String? _paymentError;
  String? _photoError;

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

  List<String> get _countries => [for (final l in _locations) ?l.country];

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
    final locations = <RechargeLocation>[
      for (final l in _locations)
        if (l.country case final c? when l.cityList.isNotEmpty)
          (country: c, cities: l.cityList),
    ];
    final payments = [
      for (final p in _payments)
        (country: p.country, type: p.type, details: p.details.text.trim()),
    ];
    final photo = _photo;
    final selfie = _selfie;
    final locationsOk = locations.length == _locations.length;
    final paymentsOk = !payments.any(
      (p) => p.details.isEmpty || !locations.any((l) => l.country == p.country),
    );
    final photosOk =
        photo != null &&
        selfie != null &&
        sniffImageType(photo) != null &&
        sniffImageType(selfie) != null;
    setState(() {
      _tried = true;
      _error = null;
      _locationError = locationsOk ? null : l10n.rechargeLocationError;
      _paymentError = paymentsOk ? null : l10n.rechargePaymentError;
      _photoError = photosOk ? null : l10n.rechargeMissingPhotos;
    });
    if (!locationsOk ||
        !paymentsOk ||
        !photosOk ||
        _nameError(l10n) != null ||
        _phoneError(l10n) != null) {
      return;
    }
    final photoType = sniffImageType(photo)!;
    final selfieType = sniffImageType(selfie)!;
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
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final added = bytes != null;
    final missing = _tried && !added;
    return Semantics(
      button: true,
      label:
          '$title. $hint. '
          '${added ? l10n.rechargePhotoAdded : l10n.rechargePhotoRequired}',
      excludeSemantics: true,
      child: InkWell(
        key: key,
        onTap: onPick,
        borderRadius: BorderRadius.circular(KRadius.md),
        child: Container(
          padding: const EdgeInsets.all(KSpacing.sm),
          decoration: BoxDecoration(
            color: p.surface,
            border: Border.all(
              color: missing
                  ? p.error
                  : added
                  ? p.success
                  : p.border,
            ),
            borderRadius: BorderRadius.circular(KRadius.md),
          ),
          child: Column(
            children: [
              SizedBox.square(
                dimension: 72,
                child: ClipOval(
                  child: bytes == null
                      ? ColoredBox(
                          color: p.surfaceOverlay,
                          child: Icon(icon, size: 32, color: p.textSecondary),
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
              const SizedBox(height: KSpacing.xs),
              RechargePill(
                label: added
                    ? l10n.rechargePhotoAdded
                    : l10n.rechargePhotoRequired,
                color: added ? p.success : (missing ? p.error : null),
                dot: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// A country dropdown over [rechargeCountries] (names in the app
  /// language).
  Widget _countryField({
    required Key key,
    required String? value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    final l10n = context.l10n;
    return DropdownButtonFormField<String>(
      key: key,
      initialValue: options.contains(value) ? value : null,
      isExpanded: true,
      decoration: InputDecoration(labelText: l10n.rechargeCountry),
      hint: Text(l10n.rechargeChooseCountry),
      items: [
        for (final c in options)
          DropdownMenuItem(
            value: c,
            child: Text(
              rechargeCountryName(context, c),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: onChanged,
    );
  }

  String _typeName(AppLocalizations l10n, RechargePaymentType type) =>
      rechargePaymentTypeName(l10n, type);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final countries = _countries;
    return Scaffold(
      backgroundColor: p.background,
      appBar: KAppBar(
        backgroundColor: p.background,
        centerTitle: true,
        title: Text(l10n.rechargeApplyTitle),
      ),
      // Owner polish: the submit button stays in reach.
      bottomNavigationBar: _SubmitBar(
        error: _error,
        busy: _busy,
        onSubmit: () => unawaited(_submit()),
      ),
      body: ListView(
        padding: const EdgeInsets.all(KSpacing.lg),
        children: [
          RechargeSection(
            step: 1,
            title: l10n.rechargeApplyStepPersonal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
              ],
            ),
          ),
          RechargeSection(
            step: 2,
            title: l10n.rechargeApplyStepPhotos,
            error: _tried && (_photo == null || _selfie == null)
                ? _photoError ?? l10n.rechargeMissingPhotos
                : null,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
            ),
          ),
          RechargeSection(
            step: 3,
            title: l10n.rechargeLocations,
            error: _locationError,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, l) in _locations.indexed)
                  _LocationEditor(
                    key: ObjectKey(l),
                    index: i,
                    location: l,
                    country: _countryField(
                      key: RechargeApplyScreen.countryKey(i),
                      value: l.country,
                      options: [
                        for (final c in rechargeCountries)
                          if (c == l.country || !countries.contains(c)) c,
                      ],
                      onChanged: (c) => setState(() {
                        l.country = c;
                        _locationError = null;
                        // A payment method without a country takes it.
                        for (final pay in _payments) {
                          if (pay.country.isEmpty && c != null) pay.country = c;
                        }
                      }),
                    ),
                    onChanged: () => setState(() => _locationError = null),
                    onRemove: _locations.length > 1
                        ? () => setState(() {
                            _locations.removeAt(i).dispose();
                          })
                        : null,
                  ),
                if (_locations.length < 10)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      key: RechargeApplyScreen.addLocationKey,
                      onPressed: () =>
                          setState(() => _locations.add(_Location())),
                      icon: const Icon(Icons.add_location_alt_rounded),
                      label: Text(l10n.rechargeAddLocation),
                    ),
                  ),
              ],
            ),
          ),
          RechargeSection(
            step: 4,
            title: l10n.rechargePaymentMethods,
            error: _paymentError,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, pay) in _payments.indexed)
                  Container(
                    key: RechargeApplyScreen.paymentKey(i),
                    margin: const EdgeInsets.only(bottom: KSpacing.sm),
                    padding: const EdgeInsets.all(KSpacing.sm),
                    decoration: BoxDecoration(
                      color: p.surface,
                      border: Border.all(color: p.border),
                      borderRadius: BorderRadius.circular(KRadius.md),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _countryField(
                                key: ValueKey('recharge.apply.payCountry.$i'),
                                value: pay.country,
                                options: countries,
                                onChanged: (c) => setState(() {
                                  pay.country = c ?? '';
                                  _paymentError = null;
                                }),
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
                        const SizedBox(height: KSpacing.sm),
                        DropdownButtonFormField<RechargePaymentType>(
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
                        const SizedBox(height: KSpacing.sm),
                        KTextField(
                          label: l10n.rechargePaymentDetails,
                          controller: pay.details,
                          maxLength: 200,
                          onChanged: (_) =>
                              setState(() => _paymentError = null),
                        ),
                      ],
                    ),
                  ),
                if (_payments.length < 30)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      key: RechargeApplyScreen.addPaymentKey,
                      onPressed: () => setState(
                        () => _payments.add(
                          _Payment(countries.isEmpty ? '' : countries.first),
                        ),
                      ),
                      icon: const Icon(Icons.add_card_rounded),
                      label: Text(l10n.rechargeAddPayment),
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
              text: l10n.rechargePrivacyNote,
            ),
          ),
        ],
      ),
    );
  }
}

/// One selling place: the country and its cities (typed with commas, shown
/// as chips as they are typed).
class _LocationEditor extends StatefulWidget {
  const new({
    required this.index,
    required this.location,
    required this.country,
    required this.onChanged,
    super.key,
    this.onRemove,
  });

  final int index;
  final _Location location;
  final Widget country;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  @override
  State<_LocationEditor> createState() => _LocationEditorState();
}

class _LocationEditorState extends State<_LocationEditor> {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final cities = widget.location.cityList;
    return Container(
      margin: const EdgeInsets.only(bottom: KSpacing.sm),
      padding: const EdgeInsets.all(KSpacing.sm),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border.all(color: p.border),
        borderRadius: BorderRadius.circular(KRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: widget.country),
              if (widget.onRemove case final remove?)
                IconButton(
                  tooltip: l10n.rechargeRemove,
                  onPressed: remove,
                  icon: Icon(Icons.close_rounded, color: p.textSecondary),
                ),
            ],
          ),
          const SizedBox(height: KSpacing.sm),
          KTextField(
            fieldKey: RechargeApplyScreen.citiesKey(widget.index),
            label: l10n.rechargeCities,
            controller: widget.location.cities,
            onChanged: (_) {
              setState(() {});
              widget.onChanged();
            },
          ),
          if (cities.isNotEmpty) ...[
            const SizedBox(height: KSpacing.xs),
            Wrap(
              spacing: KSpacing.xs,
              runSpacing: KSpacing.xs,
              children: [
                for (final c in cities)
                  RechargePill(label: c, color: p.primaryText),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// The sticky bar: the request's failure (if any) and «إرسال الطلب».
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
                    key: const Key('recharge.apply.error'),
                    style: t.caption.copyWith(color: p.error),
                  ),
                ),
              KButton(
                key: RechargeApplyScreen.submitKey,
                label: l10n.rechargeSubmit,
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
