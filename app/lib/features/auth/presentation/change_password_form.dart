import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error_text.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/motion.dart';
import '../../../core/validation/validators.dart';
import '../../../core/widgets/password_checklist.dart';
import '../../../core/widgets/shake_on_error.dart';
import '../../../core/widgets/submit_button.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../application/auth_controller.dart';

/// Change password for a signed-in user (AD18, D22, D24, AS12): current
/// password, new password with the live checklist, confirm. The API signs
/// out the other devices. Field errors from the API show next to their
/// fields; the form shakes once when it can't be sent.
class ChangePasswordForm extends ConsumerStatefulWidget {
  const ChangePasswordForm({super.key, this.onChanged});

  /// After the password changed and the check has shown (a dialog closes here).
  final VoidCallback? onChanged;

  @override
  ConsumerState<ChangePasswordForm> createState() => _ChangePasswordFormState();
}

class _ChangePasswordFormState extends ConsumerState<ChangePasswordForm> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  SubmitStatus _status = SubmitStatus.idle;
  Map<String, String> _fieldErrors = const {};
  String? _error;
  int _failures = 0;

  @override
  void dispose() {
    _current.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final reduced = Motion.of(context).reduced;
    final messenger = ScaffoldMessenger.maybeOf(context);
    setState(() {
      _fieldErrors = const {};
      _error = null;
    });
    if (!(_formKey.currentState?.validate() ?? false)) {
      setState(() => _failures++);
      return;
    }
    setState(() => _status = SubmitStatus.loading);
    try {
      await ref.read(authControllerProvider.notifier).changePassword(_current.text, _password.text);
      if (!mounted) return;
      setState(() => _status = SubmitStatus.success);
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.adminPasswordChanged), behavior: SnackBarBehavior.floating));
      await Future<void>.delayed(reduced ? Duration.zero : Motion.slow);
      if (!mounted) return;
      _current.clear();
      _password.clear();
      _confirm.clear();
      _formKey.currentState?.reset();
      setState(() => _status = SubmitStatus.idle);
      widget.onChanged?.call();
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
    final scheme = Theme.of(context).colorScheme;
    final busy = _status != SubmitStatus.idle;
    final toggle = IconButton(
      tooltip: _obscure ? l10n.showPassword : l10n.hidePassword,
      icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
      onPressed: () => setState(() => _obscure = !_obscure),
    );
    return ShakeOnError(
      trigger: _failures == 0 ? null : _failures,
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _current,
                enabled: !busy,
                obscureText: _obscure,
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: l10n.adminCurrentPassword,
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: toggle,
                ),
                validator: (value) {
                  final server = l10n.fieldError(_fieldErrors['currentPassword']);
                  if (server != null) return server;
                  if (value == null || value.isEmpty) return l10n.errorRequired;
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _password,
                enabled: !busy,
                obscureText: _obscure,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: l10n.newPasswordLabel, prefixIcon: const Icon(Icons.key_outlined)),
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
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(labelText: l10n.confirmPasswordLabel, prefixIcon: const Icon(Icons.key_outlined)),
                validator: (value) {
                  if (value == null || value.isEmpty) return l10n.errorRequired;
                  if (value != _password.text) return l10n.errorPasswordsDontMatch;
                  return null;
                },
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Semantics(liveRegion: true, child: Text(_error!, style: TextStyle(color: scheme.error))),
                ),
              const SizedBox(height: 20),
              SubmitButton(label: l10n.adminChangePassword, status: _status, onPressed: _submit),
            ],
          ),
        ),
      ),
    );
  }
}
