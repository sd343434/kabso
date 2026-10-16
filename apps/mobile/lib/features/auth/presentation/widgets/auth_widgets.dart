import 'package:flutter/semantics.dart'
    show AttributedString, LocaleStringAttribute;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/domain/auth_failures.dart';
import 'package:kabso_live/features/auth/domain/validators.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Shared layout of the auth screens: wordmark, title, subtitle and a
/// scrollable, width-constrained body (no overflow at large text scales).
class AuthScaffold extends StatelessWidget {
  const new({
    required this.title,
    required this.child,
    super.key,
    this.subtitle,
    this.subtitleWidget,
    this.showBack = false,
    this.onBack,
    this.backLabel,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;

  /// Replaces [subtitle] when rich content is needed.
  final Widget? subtitleWidget;
  final Widget child;
  final bool showBack;

  /// Custom back action (default: pop).
  final VoidCallback? onBack;

  /// Semantics/tooltip of a custom back action.
  final String? backLabel;

  /// TopBar end slot (e.g. the language switch).
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final hasBar = showBack || actions.isNotEmpty;
    return Scaffold(
      appBar: hasBar
          ? AppBar(
              automaticallyImplyLeading: showBack && onBack == null,
              leading: showBack && onBack != null
                  ? IconButton(
                      tooltip: backLabel,
                      icon: const BackButtonIcon(),
                      onPressed: onBack,
                    )
                  : null,
              actions: [
                ...actions,
                const SizedBox(width: KSpacing.sm),
              ],
            )
          : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: KSpacing.xl,
              vertical: KSpacing.xxl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: KLogo(
                        primary: l10n.brandWordmarkPrimary,
                        accent: l10n.brandWordmarkAccent,
                        semanticLabel: l10n.brandSemanticLabel,
                      ),
                    ),
                    const SizedBox(height: KSpacing.xxl),
                    Semantics(
                      header: true,
                      child: Text(title, style: t.headline),
                    ),
                    if (subtitleWidget != null) ...[
                      const SizedBox(height: KSpacing.sm),
                      subtitleWidget!,
                    ] else if (subtitle != null) ...[
                      const SizedBox(height: KSpacing.sm),
                      Text(
                        subtitle!,
                        style: t.body.copyWith(
                          color: context.palette.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: KSpacing.xl),
                    child,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// TopBar language switch on Login and Register (PHASE1_1_SCREENS §3.2):
/// shows the **other** language in its own script and toggles instantly.
/// The choice is persisted; field contents survive (no navigation).
class AuthLanguageSwitch extends ConsumerWidget {
  const new({super.key, this.enabled = true});

  static const switchKey = Key('auth.languageSwitch');

  /// Disabled while a submit is loading (no mid-request flip).
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final current = ref.watch(languageControllerProvider);
    final target = current.other;
    final name = switch (target) {
      AppLanguage.ar => l10n.languageArabic,
      AppLanguage.en => l10n.languageEnglish,
    };
    return Semantics(
      button: true,
      enabled: enabled,
      attributedLabel: AttributedString(
        name,
        attributes: [
          LocaleStringAttribute(
            range: TextRange(start: 0, end: name.length),
            locale: target.locale,
          ),
        ],
      ),
      hint: l10n.languageSwitchHint,
      excludeSemantics: true,
      onTap: enabled ? () => _toggle(ref, target) : null,
      child: ActionChip(
        key: switchKey,
        // The globe never flips.
        avatar: const Icon(Icons.language_rounded, size: 16),
        label: Text(name),
        onPressed: enabled ? () => _toggle(ref, target) : null,
      ),
    );
  }

  Future<void> _toggle(WidgetRef ref, AppLanguage target) =>
      ref.read(languageControllerProvider.notifier).select(target);
}

/// Localized message for a client-side validation error.
///
/// [formatMessage] replaces the generic text for
/// [ValidationIssue.invalidFormat] (e.g. the username rules).
String? validationMessage(
  AppLocalizations l10n,
  ValidationError? error, {
  String? formatMessage,
}) {
  if (error == null) return null;
  return switch (error.issue) {
    ValidationIssue.required => l10n.validationRequired,
    ValidationIssue.tooShort => l10n.validationTooShort(error.limit ?? 0),
    ValidationIssue.tooLong => l10n.validationTooLong(error.limit ?? 0),
    ValidationIssue.invalidFormat => formatMessage ?? l10n.validationInvalid,
  };
}

/// Localized message for a server `VALIDATION_FAILED` detail on [field]
/// (issue vocabulary of CONVENTIONS.md §4). Unknown issues fall back to a
/// generic message.
String serverIssueMessage(
  AppLocalizations l10n,
  AuthField field,
  ValidationIssueCode? issue,
) {
  final (int? min, int max) = switch (field) {
    AuthField.username => (AuthRules.usernameMin, AuthRules.usernameMax),
    AuthField.password => (AuthRules.passwordMin, AuthRules.passwordMax),
    AuthField.email => (null, AuthRules.emailMax),
    AuthField.displayName => (
      AuthRules.displayNameMin,
      AuthRules.displayNameMax,
    ),
    AuthField.identifier => (AuthRules.identifierMin, AuthRules.identifierMax),
  };
  if (field == AuthField.displayName) {
    // PHASE1_1_SCREENS §2 (v1.2). The reserved list never ships in the app.
    return switch (issue) {
      ValidationIssueCode.required => l10n.validationRequired,
      ValidationIssueCode.tooLong ||
      ValidationIssueCode.tooBig => l10n.displayNameTooLong,
      ValidationIssueCode.reservedTerm => l10n.displayNameReserved,
      ValidationIssueCode.invalidFormat ||
      ValidationIssueCode.tooShort => l10n.displayNameInvalid,
      _ => l10n.validationInvalid,
    };
  }
  return switch (issue) {
    ValidationIssueCode.required => l10n.validationRequired,
    ValidationIssueCode.invalidEmail => l10n.validationEmailInvalid,
    ValidationIssueCode.invalidFormat when field == AuthField.username =>
      l10n.usernameBadChars,
    ValidationIssueCode.invalidFormat when field == AuthField.email =>
      l10n.validationEmailInvalid,
    ValidationIssueCode.tooShort when min != null => l10n.validationTooShort(
      min,
    ),
    ValidationIssueCode.tooLong => l10n.validationTooLong(max),
    _ => l10n.validationInvalid,
  };
}

/// Localized message for a client-side [DisplayNameIssue]
/// (PHASE1_1_SCREENS §2).
String? displayNameIssueMessage(
  AppLocalizations l10n,
  DisplayNameIssue? issue,
) => switch (issue) {
  null => null,
  DisplayNameIssue.required => l10n.validationRequired,
  DisplayNameIssue.tooLong => l10n.displayNameTooLong,
  DisplayNameIssue.invalidFormat => l10n.displayNameInvalid,
};

/// Localized reason for a [UsernameIssue] (PHASE1_SCREENS §4.2).
String? usernameIssueMessage(AppLocalizations l10n, UsernameIssue? issue) =>
    switch (issue) {
      null => null,
      UsernameIssue.required => l10n.validationRequired,
      UsernameIssue.badChars => l10n.usernameBadChars,
      UsernameIssue.tooShort => l10n.usernameTooShort,
      UsernameIssue.tooLong => l10n.usernameTooLong,
      UsernameIssue.badEdges => l10n.usernameBadEdges,
    };

/// A "question + link" row, e.g. "Don't have an account? Create account".
class AuthSwitchPrompt extends StatelessWidget {
  const new({
    required this.question,
    required this.action,
    required this.onPressed,
    super.key,
  });

  final String question;
  final String action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          question,
          style: context.textStyles.body.copyWith(
            color: context.palette.textSecondary,
          ),
        ),
        TextButton(onPressed: onPressed, child: Text(action)),
      ],
    );
  }
}
