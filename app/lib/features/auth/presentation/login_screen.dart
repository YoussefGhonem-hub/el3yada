import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/config/env.dart';
import '../../../core/network/api_error_text.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/motion.dart';
import '../../../core/validation/validators.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/settings_actions.dart';
import '../../../core/widgets/shake_on_error.dart';
import '../../../core/widgets/submit_button.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../shell/role_shells.dart';
import '../../startup/startup.dart';
import '../application/auth_controller.dart';
import '../data/auth_repository.dart';
import '../domain/login_result.dart';
import '../domain/user_role.dart';

/// A1 splash and A3 login, as one screen.
///
/// The splash route and the login route build this widget inside pages with
/// the same key, so going from one to the other updates this screen in place
/// instead of replacing it. That is the signature moment (spec 12): the logo
/// draws itself in the centre, then rises into the login header while the
/// form slides up under it. With reduced motion the form simply appears.
///
/// [showForm] false is the splash; it releases [splashGateProvider] once the
/// logo has drawn, and the router then decides where to go.
class EntranceScreen extends ConsumerStatefulWidget {
  const EntranceScreen({super.key, required this.showForm});

  final bool showForm;

  /// Shared by the splash and login pages (see the class comment).
  static const pageKey = ValueKey('entrance');

  @override
  ConsumerState<EntranceScreen> createState() => _EntranceScreenState();
}

class _EntranceScreenState extends ConsumerState<EntranceScreen> with SingleTickerProviderStateMixin {
  /// The logo and app name, a fixed height so the splash can centre them.
  static const _headerHeight = 132.0;

  /// The login's height, used to centre it on tall screens.
  static const _loginHeight = 640.0;

  late final AnimationController _reveal;
  late final Animation<double> _rise;
  late final Animation<double> _formIn;
  Timer? _slowTimer;
  bool _slow = false;

  @override
  void initState() {
    super.initState();
    _reveal = AnimationController(vsync: this, duration: const Duration(milliseconds: 700), value: widget.showForm ? 1 : 0);
    _rise = _reveal.drive(CurveTween(curve: const Interval(0, 0.75, curve: Motion.spring)));
    _formIn = _reveal.drive(CurveTween(curve: const Interval(0.3, 1, curve: Motion.enterCurve)));
    if (!widget.showForm) {
      _slowTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _slow = true);
      });
    }
  }

  @override
  void didUpdateWidget(EntranceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.showForm && widget.showForm) {
      _slowTimer?.cancel();
      if (Motion.of(context).reduced) {
        _reveal.value = 1;
      } else {
        _reveal.forward();
      }
    }
  }

  @override
  void dispose() {
    _slowTimer?.cancel();
    _reveal.dispose();
    super.dispose();
  }

  void _onLogoDrawn() {
    final reduced = Motion.of(context).reduced;
    // A short beat after the plus pops in, so the mark reads as finished.
    Future<void>.delayed(reduced ? Duration.zero : Motion.fast, () {
      if (mounted) ref.read(splashGateProvider.notifier).release();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        actions: [
          FadeTransition(
            opacity: _formIn,
            child: IgnorePointer(ignoring: !widget.showForm, child: const SettingsActions(showLogout: false)),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final height = constraints.maxHeight;
            // Where the header rests in the login, and how far it starts below
            // that, at the centre where the splash drew it.
            final restTop = math.max(16.0, (height - _loginHeight) / 2);
            final splashOffset = math.max(0.0, (height - _headerHeight) / 2 - restTop);

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24, restTop, 24, 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AnimatedBuilder(
                        animation: _rise,
                        builder: (context, child) => Transform.translate(
                          offset: Offset(0, lerpDouble(splashOffset, 0, _rise.value)!),
                          child: child,
                        ),
                        child: SizedBox(
                          height: _headerHeight,
                          child: Column(
                            children: [
                              AppLogoMark(animate: !widget.showForm, onDrawn: widget.showForm ? null : _onLogoDrawn),
                              const SizedBox(height: 12),
                              Expanded(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    l10n.appTitle,
                                    style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (!widget.showForm)
                        Transform.translate(
                          offset: Offset(0, splashOffset),
                          child: AnimatedOpacity(
                            opacity: _slow ? 1 : 0,
                            duration: Motion.normal,
                            child: Text(
                              l10n.splashSlow,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ),
                        )
                      else
                        FadeTransition(
                          opacity: _formIn,
                          child: AnimatedBuilder(
                            animation: _formIn,
                            builder: (context, child) => Transform.translate(
                              offset: Offset(0, (1 - _formIn.value) * 24),
                              child: child,
                            ),
                            child: const _LoginForm(),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// A3: one form for every role.
class _LoginForm extends ConsumerStatefulWidget {
  const _LoginForm();

  @override
  ConsumerState<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends ConsumerState<_LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  SubmitStatus _status = SubmitStatus.idle;
  String? _error;

  /// Counts wrong-credential answers; each one shakes the form once.
  int _failures = 0;

  /// How long the check shows before the home screen opens.
  static const _successHold = Duration(milliseconds: 450);

  AuthController get _auth => ref.read(authControllerProvider.notifier);

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_status != SubmitStatus.idle) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final identifier = Validators.normalizeIdentifier(_identifier.text)!;
    await _run(() async {
      final result = await _auth.login(identifier, _password.text, commit: false);
      return switch (result) {
        SignedIn(:final session) => () => _auth.acceptSession(session),
        ChooseAccount() => await _chooseAccount(result),
      };
    });
  }

  /// "Log in as" (A3). Returns the step that signs in, or null if cancelled.
  Future<Future<void> Function()?> _chooseAccount(ChooseAccount choice) async {
    setState(() => _status = SubmitStatus.idle);
    final role = await showAccountChooser(context, choice.accounts);
    if (role == null || !mounted) return null;
    setState(() => _status = SubmitStatus.loading);
    final session = await _auth.selectAccount(choice.selectionToken, role, commit: false);
    return () => _auth.acceptSession(session);
  }

  /// Runs a sign-in step: loading, then the check, then the session is
  /// committed and the router opens the home screen.
  Future<void> _run(Future<Future<void> Function()?> Function() step) async {
    final l10n = AppLocalizations.of(context);
    final reduced = Motion.of(context).reduced;
    setState(() {
      _status = SubmitStatus.loading;
      _error = null;
    });
    try {
      final commit = await step();
      if (!mounted) return;
      if (commit == null) {
        setState(() => _status = SubmitStatus.idle);
        return;
      }
      setState(() => _status = SubmitStatus.success);
      if (!reduced) await Future<void>.delayed(_successHold);
      await commit();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _status = SubmitStatus.idle);
      // Disabled account or inactive clinic: the router is already opening A10.
      if (AuthBlock.codes.contains(error.code)) return;
      if (error.code == ApiCodes.patientDesktopNotSupported) {
        await _showPatientOnDesktopDialog(l10n);
        return;
      }
      setState(() {
        _error = l10n.apiError(error);
        if (error.code == ApiCodes.invalidCredentials) _failures++;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _status = SubmitStatus.idle;
          _error = l10n.errorUnknown;
        });
      }
    }
  }

  /// A14: patients use the mobile app only. The user stays signed out.
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
    final busy = _status != SubmitStatus.idle;

    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.appTagline,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 32),
          Text(l10n.loginTitle, style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),
          ShakeOnError(
            trigger: _failures == 0 ? null : _failures,
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _identifier,
                    enabled: !busy,
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
                      if (Validators.normalizeIdentifier(value) == null) return l10n.errorInvalidIdentifier;
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _password,
                    enabled: !busy,
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
                    validator: (value) => (value == null || value.isEmpty) ? l10n.errorRequired : null,
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: Motion.normal,
            curve: Motion.enterCurve,
            alignment: AlignmentDirectional.topStart,
            child: _error == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(_error!, style: TextStyle(color: scheme.error)),
                    ),
                  ),
          ),
          const SizedBox(height: 24),
          SubmitButton(label: l10n.signInButton, status: _status, onPressed: _submit),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: busy ? null : () => context.go(AppRoutes.forgotPassword),
                child: Text(l10n.forgotPassword),
              ),
              TextButton(
                onPressed: busy ? null : () => context.go(AppRoutes.register),
                child: Text(l10n.registerAsDoctor),
              ),
            ],
          ),
          if (Env.useFakeAuth) ...[
            const SizedBox(height: 24),
            _TestAccountsCard(onPick: _fillTestAccount),
          ],
        ],
      ),
    );
  }
}

/// «الدخول كـ: مريض / مساعد طبيب» (A3). A bottom sheet on phones, a dialog on
/// wider screens. Returns the chosen role, or null.
Future<UserRole?> showAccountChooser(BuildContext context, List<AccountChoice> accounts) {
  final wide = MediaQuery.sizeOf(context).width >= 600;
  Widget content(BuildContext context) => _AccountChooser(accounts: accounts);
  return wide
      ? showDialog<UserRole>(context: context, builder: (context) => Dialog(child: content(context)))
      : showModalBottomSheet<UserRole>(context: context, showDragHandle: true, builder: content);
}

class _AccountChooser extends StatelessWidget {
  const _AccountChooser({required this.accounts});

  final List<AccountChoice> accounts;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return SafeArea(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.chooseAccountTitle, style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(l10n.chooseAccountBody, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 16),
              for (final account in accounts)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      leading: Icon(account.role == UserRole.assistant ? Icons.badge_outlined : Icons.person_outline),
                      title: Text(account.role.label(l10n)),
                      subtitle: Text(account.role == UserRole.assistant && account.doctorName != null
                          ? l10n.assistantAtClinic(account.doctorName!)
                          : account.displayName),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).pop(account.role),
                    ),
                  ),
                ),
            ],
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
                title: Text('${entry.value.role.label(l10n)} · ${entry.value.name}'),
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
