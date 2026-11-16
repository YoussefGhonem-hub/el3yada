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
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/motion.dart';
import '../../../core/validation/validators.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/brand_backdrop.dart';
import '../../../core/widgets/settings_actions.dart';
import '../../../core/widgets/shake_on_error.dart';
import '../../../core/widgets/staggered_entrance.dart';
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
/// instead of replacing it. That is the signature moment (spec 12): on the
/// pine brand backdrop the logo writes itself in the centre, then rises and
/// shrinks into the header while a white sheet with the form springs up
/// under it (on wide windows the brand moves to the start side and the form
/// slides in from the end). With reduced motion the form simply appears.
///
/// [showForm] false is the splash; it releases [splashGateProvider] once the
/// logo has drawn, and the router then decides where to go.
class EntranceScreen extends ConsumerStatefulWidget {
  const EntranceScreen({super.key, required this.showForm});

  final bool showForm;

  /// Shared by the splash and login pages (see the class comment).
  static const pageKey = ValueKey('entrance');

  /// From this width the login is two side-by-side panels.
  static const double wideLayout = 840;

  @override
  ConsumerState<EntranceScreen> createState() => _EntranceScreenState();
}

class _EntranceScreenState extends ConsumerState<EntranceScreen> with SingleTickerProviderStateMixin {
  /// How far the sheet's rounded top reaches up into the brand area.
  static const _overlap = 28.0;

  late final AnimationController _reveal;
  late final Animation<double> _rise;
  late final Animation<double> _sheet;
  Timer? _slowTimer;
  bool _slow = false;

  @override
  void initState() {
    super.initState();
    _reveal = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
      value: widget.showForm ? 1 : 0,
    );
    _rise = _reveal.drive(CurveTween(curve: const Interval(0, 0.8, curve: SpringCurve(bounce: 0.18))));
    _sheet = _reveal.drive(CurveTween(curve: const Interval(0.12, 1, curve: SpringCurve(bounce: 0.15))));
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
      _slow = false;
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
    // A short beat after the rings fade, so the mark reads as finished.
    Future<void>.delayed(reduced ? Duration.zero : Motion.fast, () {
      if (mounted) ref.read(splashGateProvider.notifier).release();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final insets = MediaQuery.paddingOf(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final rtl = Directionality.of(context) == TextDirection.rtl;

    final brand = _Brand(
      showForm: widget.showForm,
      onDrawn: widget.showForm ? null : _onLogoDrawn,
      slow: _slow,
    );
    final form = widget.showForm ? const _LoginForm() : const SizedBox.shrink();

    return Scaffold(
      // The sheet scrolls its own content above the keyboard; the brand
      // area stays put.
      resizeToAvoidBottomInset: false,
      backgroundColor: BrandBackdrop.colorsFor(theme.brightness)[1],
      body: BrandBackdrop(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;
            final wide = w >= EntranceScreen.wideLayout;

            // Where the brand ends in the login.
            final brandWidth = wide ? math.max(360.0, w * 0.44) : w;
            final brandHeight = wide ? h : (h * 0.34).clamp(220.0, 300.0) + insets.top * 0.5;
            final sheetStart = wide ? brandWidth - _overlap : 0.0;
            final sheetTop = wide ? 0.0 : brandHeight - _overlap;

            final settings = Padding(
              padding: EdgeInsets.only(top: insets.top + 4),
              child: wide ? const SettingsActions(showLogout: false) : const OnBrand(child: SettingsActions(showLogout: false)),
            );

            final sheet = DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLowest,
                borderRadius: wide
                    ? BorderRadiusDirectional.horizontal(start: const Radius.circular(36)).resolve(Directionality.of(context))
                    : const BorderRadius.vertical(top: Radius.circular(36)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 40, offset: const Offset(0, -6)),
                ],
              ),
              child: wide
                  ? Center(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(40, insets.top + 72, 40, 40 + keyboard),
                        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: form),
                      ),
                    )
                  : Column(
                      children: [
                        const SizedBox(height: 12),
                        const _Grabber(),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + math.max(keyboard, insets.bottom)),
                            child: Center(
                              child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440), child: form),
                            ),
                          ),
                        ),
                      ],
                    ),
            );

            return AnimatedBuilder(
              animation: _reveal,
              builder: (context, _) {
                final rise = _rise.value;
                final slide = _sheet.value;
                // The brand's centre: the middle of the screen in the splash,
                // the middle of its own area in the login.
                final loginCentre = wide
                    ? Offset(brandWidth / 2, h / 2)
                    : Offset(w / 2, insets.top + 48 + (brandHeight - _overlap - insets.top - 48) / 2);
                final splashCentre = Offset(w / 2, h / 2);
                final centre = Offset.lerp(splashCentre, loginCentre, rise)!;
                final brandScale = lerpDouble(1, wide ? 0.92 : 0.66, rise)!;
                // Directional: the start side is on the right in Arabic.
                final centreX = rtl ? w - centre.dx : centre.dx;

                return Stack(
                  children: [
                    Positioned(
                      left: centreX - 160,
                      width: 320,
                      top: centre.dy - 130,
                      height: 260,
                      child: Transform.scale(scale: brandScale, child: brand),
                    ),
                    if (widget.showForm || slide > 0)
                      PositionedDirectional(
                        start: sheetStart,
                        end: 0,
                        top: sheetTop,
                        bottom: 0,
                        child: Transform.translate(
                          offset: wide
                              ? Offset((1 - slide) * (w - sheetStart + 40) * (rtl ? -1 : 1), 0)
                              : Offset(0, (1 - slide) * (h - sheetTop + 40)),
                          child: sheet,
                        ),
                      ),
                    PositionedDirectional(
                      end: wide ? 8 : 4,
                      top: 0,
                      child: Opacity(
                        opacity: slide.clamp(0.0, 1.0),
                        child: IgnorePointer(ignoring: !widget.showForm, child: settings),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// The logo in its glass medallion, the app name written on with a light
/// sweep, and the tagline. On the splash, "Connecting…" appears under it
/// when start-up is slow.
class _Brand extends StatelessWidget {
  const _Brand({required this.showForm, required this.onDrawn, required this.slow});

  final bool showForm;
  final VoidCallback? onDrawn;
  final bool slow;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        BrandMedallion(
          child: AppLogoMark(
            size: 92,
            animate: !showForm,
            beat: true,
            onDrawn: onDrawn,
            letterColor: Colors.white,
            plusColor: AppColors.mint,
          ),
        ),
        const SizedBox(height: 18),
        _Sweep(
          child: Text(
            l10n.appTitle,
            maxLines: 1,
            style: theme.textTheme.headlineLarge?.copyWith(color: Colors.white),
          ),
        ),
        const SizedBox(height: 6),
        AnimatedSwitcher(
          duration: Motion.normal,
          child: Text(
            slow && !showForm ? l10n.splashSlow : l10n.appTagline,
            key: ValueKey(slow && !showForm),
            maxLines: 1,
            style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.mint),
          ),
        ),
      ],
    );
  }
}

/// Writes its child on: a light band sweeps across once, start to end,
/// leaving the text fully drawn. Works for Arabic, whose letters must stay
/// joined, because it masks the whole line instead of splitting it.
class _Sweep extends StatefulWidget {
  const _Sweep({required this.child});

  final Widget child;

  @override
  State<_Sweep> createState() => _SweepState();
}

class _SweepState extends State<_Sweep> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller.isDismissed) {
      if (Motion.of(context).reduced) {
        _controller.value = 1;
      } else {
        _controller.forward();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        if (_controller.isCompleted) return child!;
        final t = Curves.easeOutCubic.transform(_controller.value);
        // Revealed up to t, with a soft edge and a bright band at the edge.
        return ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (bounds) => LinearGradient(
            begin: rtl ? Alignment.centerRight : Alignment.centerLeft,
            end: rtl ? Alignment.centerLeft : Alignment.centerRight,
            colors: const [Colors.white, Colors.white, Color(0x00FFFFFF)],
            stops: [0, (t * 1.3 - 0.3).clamp(0.0, 1.0), (t * 1.3).clamp(0.0, 1.0)],
          ).createShader(bounds),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// The small handle at the top of the phone's sheet.
class _Grabber extends StatelessWidget {
  const _Grabber();

  @override
  Widget build(BuildContext context) => Container(
        width: 44,
        height: 5,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.outlineVariant,
          borderRadius: BorderRadius.circular(3),
        ),
      );
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
    var order = 0;
    // Each part rises in a beat after the one above it.
    Widget enter(Widget child) => StaggeredEntrance(index: order++, child: child);

    return AutofillGroup(
      child: StaggerGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            enter(Semantics(
              header: true,
              child: Text(l10n.loginWelcome, style: theme.textTheme.headlineSmall),
            )),
            const SizedBox(height: 6),
            enter(Text(
              l10n.loginWelcomeBody,
              style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            )),
            const SizedBox(height: 24),
            ShakeOnError(
              trigger: _failures == 0 ? null : _failures,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    enter(TextFormField(
                      controller: _identifier,
                      enabled: !busy,
                      keyboardType: TextInputType.emailAddress,
                      // Phone numbers and emails always read left-to-right.
                      textDirection: TextDirection.ltr,
                      autofillHints: const [AutofillHints.username],
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: l10n.identifierLabel,
                        prefixIcon: const Icon(Icons.person_outline_rounded),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return l10n.errorRequired;
                        if (Validators.normalizeIdentifier(value) == null) return l10n.errorInvalidIdentifier;
                        return null;
                      },
                    )),
                    const SizedBox(height: 16),
                    enter(TextFormField(
                      controller: _password,
                      enabled: !busy,
                      obscureText: _obscure,
                      autofillHints: const [AutofillHints.password],
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: l10n.passwordLabel,
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          tooltip: _obscure ? l10n.showPassword : l10n.hidePassword,
                          icon: AnimatedSwitcher(
                            duration: Motion.fast,
                            transitionBuilder: (child, animation) => RotationTransition(
                              turns: animation.drive(Tween(begin: 0.75, end: 1)),
                              child: FadeTransition(opacity: animation, child: child),
                            ),
                            child: Icon(
                              _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              key: ValueKey(_obscure),
                            ),
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (value) => (value == null || value.isEmpty) ? l10n.errorRequired : null,
                    )),
                  ],
                ),
              ),
            ),
            enter(Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: busy ? null : () => context.go(AppRoutes.forgotPassword),
                child: Text(l10n.forgotPassword),
              ),
            )),
            AnimatedSize(
              duration: Motion.normal,
              curve: Motion.enterCurve,
              alignment: AlignmentDirectional.topStart,
              child: _error == null
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Semantics(
                        liveRegion: true,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: scheme.errorContainer,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline_rounded, size: 20, color: scheme.onErrorContainer),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(_error!, style: TextStyle(color: scheme.onErrorContainer)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 8),
            enter(SubmitButton(label: l10n.signInButton, status: _status, onPressed: _submit)),
            const SizedBox(height: 12),
            enter(OutlinedButton.icon(
              onPressed: busy ? null : () => context.go(AppRoutes.register),
              icon: const Icon(Icons.medical_services_outlined),
              label: Text(l10n.registerAsDoctor),
            )),
            if (Env.useFakeAuth) ...[
              const SizedBox(height: 28),
              enter(_TestAccountsCard(onPick: _fillTestAccount)),
            ],
          ],
        ),
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
      color: theme.colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
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
