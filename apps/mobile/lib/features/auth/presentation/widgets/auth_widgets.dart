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
    this.showBack = false,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    return Scaffold(
      appBar: showBack ? AppBar() : null,
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
                    if (subtitle != null) ...[
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
  return switch (issue) {
    ValidationIssueCode.required => l10n.validationRequired,
    ValidationIssueCode.invalidEmail => l10n.validationEmailInvalid,
    ValidationIssueCode.invalidFormat when field == AuthField.username =>
      l10n.validationUsernameFormat,
    ValidationIssueCode.invalidFormat when field == AuthField.email =>
      l10n.validationEmailInvalid,
    ValidationIssueCode.tooShort when min != null => l10n.validationTooShort(
      min,
    ),
    ValidationIssueCode.tooLong => l10n.validationTooLong(max),
    _ => l10n.validationInvalid,
  };
}

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
