import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/network/api_error_text.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/motion.dart';
import '../../../core/widgets/settings_actions.dart';
import '../../../core/widgets/staggered_entrance.dart';
import '../../../core/widgets/submit_button.dart';
import '../../../core/widgets/success_check.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/data/auth_repository.dart';

/// A5 [S]: verify the email address. "We sent a verification link to …",
/// a field for the code printed in the email (desktop links open in a
/// browser, not the app), "I've verified" (reloads the account), and Resend
/// with a visible 60-second cooldown (the server's 429
/// `VERIFICATION_EMAIL_COOLDOWN` and its `Retry-After` set it too). Once
/// verified, the success check plays and Continue goes back: to the home
/// for an active doctor (pushed from the shell's banner or D24), or to A6
/// for a legacy sign-up still under review.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  /// The server allows one email a minute.
  static const resendCooldown = Duration(seconds: 60);

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  static const _tick = Duration(seconds: 1);

  final _code = TextEditingController();
  Timer? _timer;
  int _cooldown = 0;
  SubmitStatus _verifyStatus = SubmitStatus.idle;
  bool _checking = false;
  bool _sending = false;
  bool _verified = false;
  String? _codeError;
  String? _message;
  bool _messageIsError = false;

  AuthRepository get _repository => ref.read(authRepositoryProvider);
  AuthController get _auth => ref.read(authControllerProvider.notifier);

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  void _startCooldown(Duration length) {
    _timer?.cancel();
    setState(() => _cooldown = length.inSeconds);
    _timer = Timer.periodic(_tick, (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _cooldown--);
      if (_cooldown <= 0) timer.cancel();
    });
  }

  void _say(String? message, {bool error = false}) => setState(() {
        _message = message;
        _messageIsError = error;
      });

  Future<void> _resend() async {
    if (_sending || _cooldown > 0) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _sending = true);
    try {
      await _repository.resendVerificationEmail();
      if (!mounted) return;
      _say(l10n.regResent);
      _startCooldown(VerifyEmailScreen.resendCooldown);
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.code == ApiCodes.emailAlreadyVerified) {
        await _markVerified();
      } else if (error.code == ApiCodes.verificationEmailCooldown || error.code == ApiCodes.tooManyAttempts) {
        _say(l10n.apiError(error), error: true);
        _startCooldown(error.retryAfter ?? VerifyEmailScreen.resendCooldown);
      } else {
        _say(l10n.apiError(error), error: true);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// "I've verified": asks the API whether the email is verified now.
  Future<void> _check() async {
    if (_checking) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _checking = true);
    try {
      await _auth.reloadAccount();
      if (!mounted) return;
      if (ref.read(authControllerProvider).value?.emailVerified ?? false) {
        setState(() => _verified = true);
      } else {
        _say(l10n.regNotVerifiedYet, error: true);
      }
    } on ApiException catch (error) {
      if (mounted) _say(l10n.apiError(error), error: true);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _verifyCode() async {
    if (_verifyStatus != SubmitStatus.idle) return;
    final l10n = AppLocalizations.of(context);
    final code = _code.text.trim();
    if (code.isEmpty) {
      setState(() => _codeError = l10n.errorRequired);
      return;
    }
    setState(() {
      _verifyStatus = SubmitStatus.loading;
      _codeError = null;
      _message = null;
    });
    try {
      await _repository.verifyEmail(code);
      if (!mounted) return;
      await _markVerified();
    } on ApiException catch (error) {
      if (!mounted) return;
      final fieldCode = error.fieldCodes['token'] ?? error.code;
      setState(() {
        _verifyStatus = SubmitStatus.idle;
        _codeError = l10n.fieldError(fieldCode);
      });
      if (_codeError == null) _say(l10n.apiError(error), error: true);
    }
  }

  /// The API said the email is verified: show it, and refresh the session
  /// so A6 drops its card (best effort).
  Future<void> _markVerified() async {
    setState(() {
      _verified = true;
      _verifyStatus = SubmitStatus.idle;
    });
    try {
      await _auth.reloadAccount();
    } on ApiException {
      // The card on A6 goes away at the next refresh.
    }
  }

  void _continue() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.pending);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authControllerProvider).value;
    final verified = _verified || (session?.emailVerified ?? false);
    return Scaffold(
      appBar: AppBar(actions: const [SettingsActions(showLogout: false)]),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              // A crossfade, kept with reduced motion: it is a state change.
              child: AnimatedSwitcher(
                duration: Motion.normal,
                reverseDuration: Motion.normalExit,
                switchInCurve: Motion.enterCurve,
                switchOutCurve: Motion.exitCurveReversed,
                child: verified
                    ? KeyedSubtree(key: const ValueKey('verified'), child: _verifiedView())
                    : KeyedSubtree(key: const ValueKey('waiting'), child: _waitingView(session?.email ?? '')),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _waitingView(String email) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    var index = 0;
    Widget enter(Widget child) => StaggeredEntrance(index: index++, child: child);
    final busy = _verifyStatus != SubmitStatus.idle;

    return StaggerGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          enter(ExcludeSemantics(
            child: Center(
              child: DecoratedBox(
                decoration: BoxDecoration(color: scheme.primaryContainer, shape: BoxShape.circle),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Icon(Icons.mark_email_unread_outlined, size: 40, color: scheme.onPrimaryContainer),
                ),
              ),
            ),
          )),
          const SizedBox(height: 20),
          enter(Semantics(
            header: true,
            child: Text(l10n.regVerifyTitle, textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
          )),
          const SizedBox(height: 8),
          enter(Column(
            children: [
              Text(
                l10n.regVerifySentTo,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 4),
              Text(email, textAlign: TextAlign.center, textDirection: TextDirection.ltr, style: theme.textTheme.titleMedium),
            ],
          )),
          const SizedBox(height: 24),
          enter(Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l10n.regVerifyBody, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _code,
                    enabled: !busy,
                    textDirection: TextDirection.ltr,
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _verifyCode(),
                    onChanged: (_) {
                      if (_codeError != null) setState(() => _codeError = null);
                    },
                    decoration: InputDecoration(
                      labelText: l10n.resetCodeLabel,
                      prefixIcon: const Icon(Icons.pin_outlined),
                      errorText: _codeError,
                      errorMaxLines: 3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SubmitButton(label: l10n.regVerifyButton, status: _verifyStatus, onPressed: _verifyCode),
                ],
              ),
            ),
          )),
          const SizedBox(height: 16),
          enter(OutlinedButton.icon(
            onPressed: _checking || busy ? null : _check,
            icon: _checking
                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
            label: Text(l10n.regVerifiedCheck),
          )),
          const SizedBox(height: 8),
          // Not a live region: the countdown would be read out every second.
          enter(TextButton.icon(
            onPressed: _cooldown > 0 || _sending ? null : _resend,
            icon: const Icon(Icons.send_outlined),
            label: Text(_cooldown > 0 ? l10n.regResendIn(_cooldown) : l10n.regResend),
          )),
          AnimatedSize(
            duration: Motion.normal,
            curve: Motion.standardCurve,
            child: _message == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        _message!,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: _messageIsError ? scheme.error : scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _verifiedView() {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(child: SuccessCheck()),
        const SizedBox(height: 16),
        Semantics(
          header: true,
          liveRegion: true,
          child: Text(l10n.regVerifiedTitle, textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.regVerifiedBody,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 32),
        FilledButton(onPressed: _continue, child: Text(l10n.continueButton)),
      ],
    );
  }
}
