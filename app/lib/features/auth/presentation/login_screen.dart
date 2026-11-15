import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/validation/validators.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/settings_actions.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../shell/role_shells.dart';
import '../application/auth_controller.dart';
import '../data/auth_repository.dart';
import '../domain/auth_exceptions.dart';

/// A3: one login form for every role.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final identifier = Validators.normalizeIdentifier(_identifier.text)!;

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).login(identifier, _password.text);
    } on RoleNotAllowedOnPlatformException {
      if (!mounted) return;
      // Stop the button's spinner before the dialog opens over it.
      setState(() => _submitting = false);
      await _showPatientOnDesktopDialog(l10n);
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = _messageFor(l10n, error));
    } catch (_) {
      if (mounted) setState(() => _error = l10n.errorUnknown);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _messageFor(AppLocalizations l10n, AuthException error) => switch (error) {
        InvalidCredentialsException() => l10n.errorInvalidCredentials,
        TooManyAttemptsException() => l10n.errorTooManyAttempts,
        NetworkException() => l10n.errorNoInternet,
        RoleNotAllowedOnPlatformException() => l10n.patientDesktopTitle,
        UnknownAuthException() => l10n.errorUnknown,
      };

  Future<void> _showPatientOnDesktopDialog(AppLocalizations l10n) => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.phone_iphone),
          title: Text(l10n.patientDesktopTitle),
          content: Text(l10n.patientDesktopBody),
          actions: [
            FilledButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.ok)),
          ],
        ),
      );

  void _comingSoon() {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.comingSoon)));
  }

  void _fillTestAccount(String identifier) {
    _identifier.text = identifier.startsWith('+20') ? '0${identifier.substring(3)}' : identifier;
    _password.text = 'dev';
    setState(() => _error = null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(actions: const [SettingsActions(showLogout: false)]),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: AppLogoMark()),
                    const SizedBox(height: 12),
                    Text(
                      l10n.appTitle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      l10n.appTagline,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 32),
                    Text(l10n.loginTitle, style: theme.textTheme.titleLarge),
                    const SizedBox(height: 16),
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _identifier,
                            keyboardType: TextInputType.emailAddress,
                            // Phone numbers and emails always read left-to-right.
                            textDirection: TextDirection.ltr,
                            autofillHints: const [AutofillHints.username],
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: l10n.identifierLabel,
                              prefixIcon: const Icon(Icons.person_outline),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) return l10n.errorRequired;
                              if (Validators.normalizeIdentifier(value) == null) {
                                return l10n.errorInvalidIdentifier;
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _password,
                            obscureText: _obscure,
                            autofillHints: const [AutofillHints.password],
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _submit(),
                            decoration: InputDecoration(
                              labelText: l10n.passwordLabel,
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                tooltip: _obscure ? l10n.showPassword : l10n.hidePassword,
                                icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                                onPressed: () => setState(() => _obscure = !_obscure),
                              ),
                            ),
                            validator: (value) =>
                                (value == null || value.isEmpty) ? l10n.errorRequired : null,
                          ),
                        ],
                      ),
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(_error!, style: TextStyle(color: scheme.error)),
                      ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l10n.signInButton),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        // TODO(A8): forgot-password flow.
                        TextButton(onPressed: _comingSoon, child: Text(l10n.forgotPassword)),
                        // TODO(A4): doctor registration.
                        TextButton(onPressed: _comingSoon, child: Text(l10n.registerAsDoctor)),
                      ],
                    ),
                    if (Env.useFakeAuth) ...[
                      const SizedBox(height: 24),
                      _TestAccountsCard(onPick: _fillTestAccount),
                    ],
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

class _TestAccountsCard extends StatelessWidget {
  const _TestAccountsCard({required this.onPick});

  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              title: Text(l10n.devAccountsTitle, style: theme.textTheme.titleSmall),
              subtitle: Text(l10n.devAccountsBody),
            ),
            for (final entry in FakeAuthRepository.accounts.entries)
              ListTile(
                dense: true,
                leading: const Icon(Icons.account_circle_outlined),
                title: Text(entry.value.$1.label(l10n)),
                subtitle: Text(
                  entry.key.startsWith('+20') ? '0${entry.key.substring(3)}' : entry.key,
                  textDirection: TextDirection.ltr,
                ),
                onTap: () => onPick(entry.key),
              ),
          ],
        ),
      ),
    );
  }
}
