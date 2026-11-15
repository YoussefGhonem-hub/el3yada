import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/network/api_error_text.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/motion.dart';
import '../../../core/validation/validators.dart';
import '../../../core/widgets/password_checklist.dart';
import '../../../core/widgets/settings_actions.dart';
import '../../../core/widgets/shake_on_error.dart';
import '../../../core/widgets/submit_button.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../application/auth_controller.dart';

/// A9: set a new password. Shown at a patient's or assistant's first login
/// and after a reset by their doctor (`mustChangePassword`). A patient who
/// hasn't accepted the Terms also gets a required checkbox. Saving signs out
/// every other device; the router then opens the role's home.
class SetPasswordScreen extends ConsumerStatefulWidget {
  const SetPasswordScreen({super.key});

  @override
  ConsumerState<SetPasswordScreen> createState() => _SetPasswordScreenState();
}

class _SetPasswordScreenState extends ConsumerState<SetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  late final TapGestureRecognizer _termsTap = TapGestureRecognizer()..onTap = () => context.push(AppRoutes.terms);
  late final TapGestureRecognizer _privacyTap = TapGestureRecognizer()..onTap = () => context.push(AppRoutes.privacy);
  bool _obscure = true;
  bool _accepted = false;
  bool _showTermsError = false;
  SubmitStatus _status = SubmitStatus.idle;
  String? _error;
  Map<String, String> _fieldErrors = const {};
  int _failures = 0;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  Future<void> _submit({required bool needsTerms}) async {
    if (_status != SubmitStatus.idle) return;
    setState(() {
      _fieldErrors = const {};
      _showTermsError = needsTerms && !_accepted;
    });
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid || _showTermsError) {
      setState(() => _failures++);
      return;
    }

    final l10n = AppLocalizations.of(context);
    final reduced = Motion.of(context).reduced;
    setState(() {
      _status = SubmitStatus.loading;
      _error = null;
    });
    try {
      // The new session clears mustChangePassword, and the router replaces
      // this screen with the role's home.
      await ref.read(authControllerProvider.notifier).setNewPassword(
            _password.text,
            acceptTerms: needsTerms ? true : null,
          );
      if (mounted && !reduced) setState(() => _status = SubmitStatus.success);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _status = SubmitStatus.idle;
        _fieldErrors = error.fieldCodes;
        _error = error.fieldCodes.isEmpty ? l10n.apiError(error) : null;
        _failures++;
      });
      _formKey.currentState?.validate();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final session = ref.watch(authControllerProvider).value;
    final needsTerms = session?.mustAcceptTerms ?? false;
    final busy = _status != SubmitStatus.idle;

    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false, actions: const [SettingsActions()]),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: ShakeOnError(
                trigger: _failures == 0 ? null : _failures,
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(l10n.setPasswordTitle, style: theme.textTheme.headlineSmall),
                      ),
                      if (session != null && session.displayName.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(session.displayName, style: theme.textTheme.titleMedium),
                      ],
                      const SizedBox(height: 8),
                      Text(l10n.setPasswordBody, style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant)),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _password,
                        enabled: !busy,
                        obscureText: _obscure,
                        autofillHints: const [AutofillHints.newPassword],
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: l10n.newPasswordLabel,
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            tooltip: _obscure ? l10n.showPassword : l10n.hidePassword,
                            icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (value) {
                          final server = l10n.fieldError(_fieldErrors['newPassword']);
                          if (server != null) return server;
                          if (value == null || value.isEmpty) return l10n.errorRequired;
                          if (!PasswordRules.isStrong(value)) return l10n.errorWeakPassword;
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      PasswordChecklist(controller: _password),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _confirm,
                        enabled: !busy,
                        obscureText: _obscure,
                        autofillHints: const [AutofillHints.newPassword],
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(needsTerms: needsTerms),
                        decoration: InputDecoration(
                          labelText: l10n.confirmPasswordLabel,
                          prefixIcon: const Icon(Icons.lock_outline),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return l10n.errorRequired;
                          if (value != _password.text) return l10n.errorPasswordsDontMatch;
                          return null;
                        },
                      ),
                      if (needsTerms) ...[
                        const SizedBox(height: 16),
                        _TermsCheckbox(
                          value: _accepted,
                          enabled: !busy,
                          error: _showTermsError || _fieldErrors.containsKey('acceptTerms')
                              ? l10n.errorTermsNotAccepted
                              : null,
                          onChanged: (value) => setState(() {
                            _accepted = value;
                            if (value) _showTermsError = false;
                          }),
                          termsTap: _termsTap,
                          privacyTap: _privacyTap,
                        ),
                      ],
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Semantics(liveRegion: true, child: Text(_error!, style: TextStyle(color: scheme.error))),
                        ),
                      const SizedBox(height: 24),
                      SubmitButton(
                        label: l10n.savePasswordButton,
                        status: _status,
                        onPressed: () => _submit(needsTerms: needsTerms),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The required «أوافق على الشروط والأحكام وسياسة الخصوصية» checkbox, with
/// links to A12 under it.
class _TermsCheckbox extends StatelessWidget {
  const _TermsCheckbox({
    required this.value,
    required this.enabled,
    required this.onChanged,
    required this.termsTap,
    required this.privacyTap,
    this.error,
  });

  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  final TapGestureRecognizer termsTap;
  final TapGestureRecognizer privacyTap;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final link = theme.textTheme.bodyMedium?.copyWith(
      color: scheme.primary,
      decoration: TextDecoration.underline,
      decorationColor: scheme.primary,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CheckboxListTile(
          value: value,
          onChanged: enabled ? (checked) => onChanged(checked ?? false) : null,
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          isError: error != null,
          title: Text(l10n.acceptTermsLabel),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 48),
          child: Text.rich(TextSpan(children: [
            TextSpan(text: l10n.termsTitle, style: link, recognizer: termsTap),
            const TextSpan(text: '   '),
            TextSpan(text: l10n.privacyTitle, style: link, recognizer: privacyTap),
          ])),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 48, top: 4),
            child: Semantics(
              liveRegion: true,
              child: Text(error!, style: theme.textTheme.bodySmall?.copyWith(color: scheme.error)),
            ),
          ),
      ],
    );
  }
}
