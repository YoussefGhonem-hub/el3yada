import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error_text.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/platform/device_identity.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/theme/motion.dart';
import '../../../core/theme/page_transitions.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/settings_actions.dart';
import '../../../core/widgets/shake_on_error.dart';
import '../../../core/widgets/skeleton_loading.dart';
import '../../../core/widgets/submit_button.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_session.dart';
import '../application/registration_form.dart';
import '../application/registration_providers.dart';
import '../data/registration_repository.dart';
import '../domain/doctor_registration.dart';
import '../domain/license_file.dart';
import 'steps/account_step.dart';
import 'steps/branch_step.dart';
import 'steps/professional_step.dart';
import 'steps/review_step.dart';
import 'widgets/form_parts.dart';
import 'widgets/step_progress.dart';
import 'welcome_dialog.dart';

/// A4: doctor registration in 4 steps (account, professional, first branch,
/// review), with a progress bar. [resubmit] is A7 "Edit and resubmit": the
/// same form filled from `myRegistration`, without the password and the
/// Terms, and the license kept unless replaced.
///
/// - Steps slide along the horizontal shared axis (mirrored in Arabic), Back
///   the other way; with reduced motion they crossfade. Back, the app bar's
///   arrow and Android's back button all go to the previous step and keep
///   what was entered.
/// - Next checks the step first (spec section 11). Submit checks every step;
///   errors from the server (`errorCodes` by JSON path) open the first step
///   with an error and mark the fields.
/// - Success: a new doctor is active at once, in a free trial (spec 6.16):
///   the welcome (the sign-up's one signature moment) says how long the
///   trial lasts, then the session is used and the router opens the home.
///   A7's resubmission (legacy doctors, still reviewed by the admin) reloads
///   the account and the router moves from A7 to A6.
class RegistrationScreen extends ConsumerStatefulWidget {
  const RegistrationScreen({super.key, this.resubmit = false});

  final bool resubmit;

  @override
  ConsumerState<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends ConsumerState<RegistrationScreen> {
  static const _reviewStep = 3;

  late final RegistrationForm _form = RegistrationForm(resubmit: widget.resubmit);
  ProviderSubscription<AsyncValue<DoctorRegistration>>? _registration;
  int _step = 0;
  bool _reverse = false;
  bool _prefilled = false;
  SubmitStatus _status = SubmitStatus.idle;
  String? _banner;
  int _failures = 0;

  bool get _busy => _status != SubmitStatus.idle;

  @override
  void initState() {
    super.initState();
    // Start loading the specialties for step 2 now.
    ref.read(specialtiesProvider);
    if (widget.resubmit) {
      _registration = ref.listenManual(myRegistrationProvider, (previous, next) {
        if (_prefill(next) && mounted) setState(() {});
      });
      _prefill(_registration!.read());
    }
  }

  @override
  void dispose() {
    _registration?.close();
    _form.dispose();
    super.dispose();
  }

  /// A7: fills the form once, when the registration arrives.
  bool _prefill(AsyncValue<DoctorRegistration> value) {
    if (_prefilled || !value.hasValue) return false;
    _form.prefill(value.requireValue);
    _prefilled = true;
    return true;
  }

  void _goTo(int step) {
    if (step == _step) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _reverse = step < _step;
      _step = step;
      _banner = null;
    });
  }

  void _back() {
    if (_step > 0 && !_busy) _goTo(_step - 1);
  }

  void _next() {
    final l10n = AppLocalizations.of(context);
    final errors = {
      for (final error in _form.errors.entries)
        if (RegField.stepOf(error.key) == _step) error.key: error.value,
      ..._form.validateStep(_step),
    };
    if (errors.isNotEmpty) {
      _form.setErrors({..._form.errors, ...errors}, reveal: true);
      setState(() {
        _banner = l10n.regFixErrors;
        _failures++;
      });
      return;
    }
    _goTo(_step + 1);
  }

  Future<void> _submit() async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context);
    final reduced = Motion.of(context).reduced;
    final errors = {..._form.errors, ..._form.validateAll()};
    if (errors.isNotEmpty) {
      _showErrors(errors, l10n.regFixErrors);
      return;
    }

    setState(() {
      _status = SubmitStatus.loading;
      _banner = null;
    });
    final repository = ref.read(registrationRepositoryProvider);
    final auth = ref.read(authControllerProvider.notifier);
    final locale = ref.read(appSettingsProvider).locale.languageCode;
    try {
      if (widget.resubmit) {
        await repository.resubmit(_form.toData(locale: locale), _form.license);
        await _finish(reduced);
        try {
          await auth.reloadAccount();
        } on ApiException {
          // Sent, but the account couldn't be read again (offline): move on anyway.
          final session = ref.read(authControllerProvider).value;
          if (session != null) {
            await auth.acceptSession(
              session.copyWith(doctorStatus: DoctorStatus.pendingApproval, doctorStatusReason: null),
            );
          }
        }
      } else {
        final device = await _device();
        final session = await repository.register(_form.toData(locale: locale, device: device), _form.license!);
        if (!mounted) return;
        setState(() => _status = SubmitStatus.success);
        // The welcome is the moment; then the router replaces this screen with the home.
        await showWelcomeDialog(context, trialDays: session.trial?.daysLeft);
        await auth.acceptSession(session);
      }
      // A6 must not show the registration as it was before this submission.
      if (mounted) {
        ref.invalidate(myRegistrationProvider);
        ref.invalidate(myLicenseProvider);
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      _showServerError(error);
    }
  }

  /// The check on Submit, held a moment before the next screen.
  Future<void> _finish(bool reduced) async {
    if (!mounted) return;
    setState(() => _status = SubmitStatus.success);
    if (!reduced) await Future<void>.delayed(Motion.slow);
  }

  void _showServerError(ApiException error) {
    final l10n = AppLocalizations.of(context);
    final fields = Map<String, String>.of(error.fieldCodes);
    if (error.code == RegistrationCodes.emailAlreadyRegistered) fields[RegField.email] = error.code!;
    if (error.code == RegistrationCodes.requestTooLarge || error.status == 413) {
      fields[RegField.license] = LicenseFileException.tooLarge;
    }
    final placed = fields.keys.any((key) => !RegField.isUnplaced(key));
    setState(() => _status = SubmitStatus.idle);
    if (!placed) {
      setState(() {
        _banner = l10n.apiError(error);
        _failures++;
      });
      return;
    }
    _showErrors(fields, l10n.regFixErrors);
  }

  /// Marks [errors] and opens the first step that has one.
  void _showErrors(Map<String, String> errors, String banner) {
    _form.setErrors(errors, reveal: true);
    final target = _form.firstStepWithError() ?? _step;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _reverse = target < _step;
      _step = target;
      _banner = banner;
      _failures++;
    });
  }

  Future<Map<String, dynamic>?> _device() async {
    try {
      return (await ref.read(deviceIdentityProvider.future)).toJson();
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final reduced = Motion.of(context).reduced;
    final labels = [l10n.regStepAccount, l10n.regStepProfessional, l10n.regStepBranch, l10n.regStepReview];
    final media = MediaQuery.of(context);
    // On a short screen with the keyboard open, the fields need the room.
    final compact = media.viewInsets.bottom > 0 && media.size.height - media.viewInsets.bottom < 480;

    final registration = widget.resubmit ? ref.watch(myRegistrationProvider) : null;
    final loading = widget.resubmit && !_prefilled;
    final failed = loading && registration!.hasError && !registration.isLoading;

    final Widget body;
    if (failed) {
      body = EmptyState(
        title: l10n.regDataError,
        message: l10n.apiError(registration.error!),
        actionLabel: l10n.retryButton,
        onAction: () => ref.invalidate(myRegistrationProvider),
      );
    } else if (loading) {
      body = SkeletonLoading(loading: true, child: AccountStep(form: _form, enabled: false));
    } else {
      body = ShakeOnError(
        trigger: _failures == 0 ? null : _failures,
        child: PageTransitionSwitcher(
          reverse: _reverse,
          duration: reduced ? Motion.normal : Motion.slow,
          // Each step fills the area and starts at the top, even when short.
          layoutBuilder: (entries) => Stack(fit: StackFit.expand, children: entries),
          transitionBuilder: (child, primary, secondary) => reduced
              ? FadeTransition(
                  opacity: primary,
                  child: FadeTransition(opacity: ReverseAnimation(secondary), child: child),
                )
              : DirectionalSharedAxisTransition(animation: primary, secondaryAnimation: secondary, child: child),
          child: KeyedSubtree(key: ValueKey(_step), child: _stepView(_step)),
        ),
      );
    }

    return PopScope(
      canPop: _step == 0 && !_busy,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.resubmit ? l10n.regResubmitTitle : l10n.regTitle),
          actions: const [SettingsActions(showLogout: false)],
        ),
        body: SafeArea(
          child: Column(
            children: [
              AnimatedSize(
                duration: Motion.normal,
                curve: Motion.standardCurve,
                child: compact || failed
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: kRegistrationFormWidth),
                            child: StepProgress(step: _step, labels: labels),
                          ),
                        ),
                      ),
              ),
              Expanded(child: body),
              if (!failed)
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    border: Border(top: BorderSide(color: scheme.outlineVariant)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: kRegistrationFormWidth),
                        child: _actions(l10n, enabled: !loading),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepView(int step) {
    final enabled = !_busy;
    return switch (step) {
      0 => AccountStep(form: _form, enabled: enabled, banner: _banner, onDone: _next),
      1 => ProfessionalStep(form: _form, enabled: enabled, banner: _banner),
      2 => BranchStep(form: _form, enabled: enabled, banner: _banner),
      _ => ReviewStep(form: _form, enabled: enabled, banner: _banner, onEdit: _goTo),
    };
  }

  Widget _actions(AppLocalizations l10n, {required bool enabled}) {
    final last = _step == _reviewStep;
    final Widget forward = last
        ? SubmitButton(
            label: widget.resubmit ? l10n.regResubmit : l10n.regSubmit,
            status: _status,
            onPressed: enabled ? _submit : null,
          )
        : FilledButton.icon(
            onPressed: enabled ? _next : null,
            iconAlignment: IconAlignment.end,
            icon: const Icon(Icons.arrow_forward),
            label: Text(l10n.regNext),
          );
    return Row(
      children: [
        AnimatedSize(
          duration: Motion.normal,
          curve: Motion.standardCurve,
          child: _step == 0
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsetsDirectional.only(end: 12),
                  child: OutlinedButton(
                    onPressed: _busy ? null : _back,
                    child: Text(l10n.regBack),
                  ),
                ),
        ),
        Expanded(child: forward),
      ],
    );
  }
}
