import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/network/api_error_text.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/motion.dart';
import '../../../core/validation/validators.dart';
import '../../../core/widgets/password_checklist.dart';
import '../../../core/widgets/submit_button.dart';
import '../../../core/widgets/success_check.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../data/auth_repository.dart';

/// A8: forgot password.
///
/// - Email (doctors and admins): the API emails a reset link, which also
///   shows the token as a code. "I have a code" takes the code and a new
///   password here, for desktop users whose link opens in a browser.
/// - Mobile (patients and assistants): their doctor gets a request and gives
///   them a temporary password.
///
/// Either way the answer is the same whether or not the account exists.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

enum _Step { request, emailSent, phoneSent, code, reset }

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _requestForm = GlobalKey<FormState>();
  final _codeForm = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  _Step _step = _Step.request;
  SubmitStatus _status = SubmitStatus.idle;
  String? _error;
  Map<String, String> _fieldErrors = const {};

  @override
  void dispose() {
    _identifier.dispose();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  AuthRepository get _repository => ref.read(authRepositoryProvider);

  Future<void> _request() async {
    if (!(_requestForm.currentState?.validate() ?? false)) return;
    final identifier = Validators.normalizeIdentifier(_identifier.text)!;
    final byEmail = identifier.contains('@');
    await _run(
      () => byEmail ? _repository.requestPasswordResetEmail(identifier) : _repository.requestPatientPasswordReset(identifier),
      next: byEmail ? _Step.emailSent : _Step.phoneSent,
    );
  }

  Future<void> _reset() async {
    setState(() => _fieldErrors = const {});
    if (!(_codeForm.currentState?.validate() ?? false)) return;
    await _run(
      () => _repository.resetPassword(token: _code.text.trim(), newPassword: _password.text),
      next: _Step.reset,
    );
  }

  Future<void> _run(Future<void> Function() call, {required _Step next}) async {
    if (_status != SubmitStatus.idle) return;
    final l10n = AppLocalizations.of(context);
    setState(() {
      _status = SubmitStatus.loading;
      _error = null;
    });
    try {
      await call();
      if (!mounted) return;
      setState(() {
        _status = SubmitStatus.idle;
        _step = next;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _status = SubmitStatus.idle;
        _fieldErrors = error.fieldCodes;
        _error = error.fieldCodes.isEmpty ? l10n.apiError(error) : null;
      });
      _codeForm.currentState?.validate();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.forgotTitle)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              // A crossfade, kept with reduced motion: it is a state change.
              child: AnimatedSwitcher(
                duration: Motion.normal,
                reverseDuration: Motion.normalExit,
                switchInCurve: Motion.enterCurve,
                switchOutCurve: Motion.exitCurveReversed,
                child: KeyedSubtree(
                  key: ValueKey(_step),
                  child: switch (_step) {
                    _Step.request => _requestStep(l10n),
                    _Step.emailSent => _doneStep(
                        l10n,
                        title: l10n.forgotEmailSentTitle,
                        body: l10n.forgotEmailSentBody,
                        extra: TextButton(
                          onPressed: () => setState(() => _step = _Step.code),
                          child: Text(l10n.forgotHaveCode),
                        ),
                      ),
                    _Step.phoneSent => _doneStep(l10n, title: l10n.forgotPhoneSentTitle, body: l10n.forgotPhoneSentBody),
                    _Step.code => _codeStep(l10n),
                    _Step.reset => _doneStep(l10n, title: l10n.resetDoneTitle, body: l10n.resetDoneBody),
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _errorText() {
    final error = _error;
    if (error == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Semantics(
        liveRegion: true,
        child: Text(error, style: TextStyle(color: Theme.of(context).colorScheme.error)),
      ),
    );
  }

  Widget _requestStep(AppLocalizations l10n) => Form(
        key: _requestForm,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.forgotBody, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 24),
            TextFormField(
              controller: _identifier,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              textDirection: TextDirection.ltr,
              autofillHints: const [AutofillHints.username],
              textInputAction: TextInputAction.send,
              onFieldSubmitted: (_) => _request(),
              decoration: InputDecoration(
                labelText: l10n.identifierLabel,
                prefixIcon: const Icon(Icons.person_outline),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) return l10n.errorRequired;
                if (Validators.normalizeIdentifier(value) == null) return l10n.errorInvalidIdentifier;
                return null;
              },
            ),
            _errorText(),
            const SizedBox(height: 24),
            SubmitButton(label: l10n.forgotSubmit, status: _status, onPressed: _request),
          ],
        ),
      );

  Widget _codeStep(AppLocalizations l10n) => Form(
        key: _codeForm,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.resetCodeBody, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 24),
            TextFormField(
              controller: _code,
              autofocus: true,
              textDirection: TextDirection.ltr,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(labelText: l10n.resetCodeLabel, prefixIcon: const Icon(Icons.pin_outlined)),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? l10n.errorRequired
                  : l10n.fieldError(_fieldErrors['token']),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _password,
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(labelText: l10n.newPasswordLabel, prefixIcon: const Icon(Icons.lock_outline)),
              validator: (value) {
                final server = l10n.fieldError(_fieldErrors['newPassword']);
                if (server != null) return server;
                if (value == null || value.isEmpty) return l10n.errorRequired;
                return PasswordRules.isStrong(value) ? null : l10n.errorWeakPassword;
              },
            ),
            const SizedBox(height: 12),
            PasswordChecklist(controller: _password),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirm,
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _reset(),
              decoration: InputDecoration(labelText: l10n.confirmPasswordLabel, prefixIcon: const Icon(Icons.lock_outline)),
              validator: (value) {
                if (value == null || value.isEmpty) return l10n.errorRequired;
                return value == _password.text ? null : l10n.errorPasswordsDontMatch;
              },
            ),
            _errorText(),
            const SizedBox(height: 24),
            SubmitButton(label: l10n.savePasswordButton, status: _status, onPressed: _reset),
          ],
        ),
      );

  Widget _doneStep(AppLocalizations l10n, {required String title, required String body, Widget? extra}) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(child: SuccessCheck()),
        const SizedBox(height: 16),
        Semantics(
          header: true,
          liveRegion: true,
          child: Text(title, textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
        ),
        const SizedBox(height: 8),
        Text(
          body,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 32),
        FilledButton(onPressed: () => context.go(AppRoutes.login), child: Text(l10n.backToLogin)),
        if (extra != null) ...[const SizedBox(height: 8), extra],
      ],
    );
  }
}
