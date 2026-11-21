import 'package:animations/animations.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_error_text.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/motion.dart';
import '../../../../core/theme/page_transitions.dart';
import '../../../../core/widgets/shake_on_error.dart';
import '../../../../core/widgets/submit_button.dart';
import '../../../../core/widgets/success_check.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../admin_billing/application/admin_billing_providers.dart';
import '../../../doctor_registration/application/registration_form.dart';
import '../../../doctor_registration/application/registration_providers.dart';
import '../../../doctor_registration/data/registration_repository.dart' show RegistrationCodes;
import '../../../doctor_registration/domain/license_file.dart';
import '../../../doctor_registration/presentation/steps/account_step.dart';
import '../../../doctor_registration/presentation/steps/branch_step.dart';
import '../../../doctor_registration/presentation/steps/professional_step.dart';
import '../../../doctor_registration/presentation/steps/review_step.dart';
import '../../../doctor_registration/presentation/registration_text.dart' show ltrIsolate;
import '../../../doctor_registration/presentation/widgets/form_parts.dart';
import '../../../doctor_registration/presentation/widgets/step_progress.dart';
import '../../application/admin_controllers.dart';
import '../../data/admin_repository.dart';
import '../../domain/admin_models.dart';
import '../widgets/admin_widgets.dart';

/// AD6 "Add doctor" [S]: the admin creates a doctor account directly. The
/// same four steps and field rules as sign-up (A4: account, professional with
/// the license, first branch, review), without the password and the Terms:
/// the doctor gets an email to choose a password. The account is active at
/// once with the service on (no free trial).
///
/// Opened from AD2 and AD4; [listPath] is where Back returns, and
/// [detailPath] opens the new doctor afterwards (AD3 or AD5).
class AddDoctorScreen extends ConsumerStatefulWidget {
  const AddDoctorScreen({super.key, required this.listPath, required this.detailPath});

  final String listPath;
  final String Function(String doctorId) detailPath;

  @override
  ConsumerState<AddDoctorScreen> createState() => _AddDoctorScreenState();
}

class _AddDoctorScreenState extends ConsumerState<AddDoctorScreen> {
  static const _reviewStep = 3;

  late final RegistrationForm _form = RegistrationForm(byAdmin: true)
    ..doctorLocale = ref.read(appSettingsProvider).locale.languageCode;
  int _step = 0;
  bool _reverse = false;
  SubmitStatus _status = SubmitStatus.idle;
  String? _banner;
  int _failures = 0;

  bool get _busy => _status != SubmitStatus.idle;

  @override
  void initState() {
    super.initState();
    // Start loading the specialties for step 2 now.
    ref.read(specialtiesProvider);
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
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
    final errors = {
      for (final error in _form.errors.entries)
        if (RegField.stepOf(error.key) == _step) error.key: error.value,
      ..._form.validateStep(_step),
    };
    if (errors.isNotEmpty) {
      _form.setErrors({..._form.errors, ...errors}, reveal: true);
      setState(() {
        _banner = AppLocalizations.of(context).regFixErrors;
        _failures++;
      });
      return;
    }
    _goTo(_step + 1);
  }

  Future<void> _submit() async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context);
    final errors = {..._form.errors, ..._form.validateAll()};
    if (errors.isNotEmpty) {
      _showErrors(errors, l10n.regFixErrors);
      return;
    }
    setState(() {
      _status = SubmitStatus.loading;
      _banner = null;
    });
    final DoctorRegistration created;
    try {
      created = await ref.read(adminRepositoryProvider).createDoctor(_form.toData(locale: _form.doctorLocale), _form.license!);
    } on ApiException catch (error) {
      if (mounted) _showServerError(error);
      return;
    }
    if (!mounted) return;
    setState(() => _status = SubmitStatus.success);
    // The lists behind this screen show the new doctor when they come back.
    ref.invalidate(signupsControllerProvider);
    ref.invalidate(adminDoctorsProvider);
    await showDialog<void>(
      context: context,
      builder: (context) => _AddedDialog(doctor: created),
    );
    if (mounted) context.go(widget.detailPath(created.doctorId));
  }

  void _showServerError(ApiException error) {
    final l10n = AppLocalizations.of(context);
    final fields = Map<String, String>.of(error.fieldCodes);
    if (error.code == RegistrationCodes.emailAlreadyRegistered) fields[RegField.email] = error.code!;
    if (error.code == RegistrationCodes.requestTooLarge || error.status == 413) {
      fields[RegField.license] = LicenseFileException.tooLarge;
    }
    setState(() => _status = SubmitStatus.idle);
    if (!fields.keys.any((key) => !RegField.isUnplaced(key))) {
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final reduced = Motion.of(context).reduced;
    final labels = [l10n.regStepAccount, l10n.regStepProfessional, l10n.regStepBranch, l10n.regStepReview];
    final media = MediaQuery.of(context);
    // On a short screen with the keyboard open, the fields need the room.
    final compact = media.viewInsets.bottom > 0 && media.size.height - media.viewInsets.bottom < 520;

    return PopScope(
      canPop: _step == 0 && !_busy,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final gutter = adminGutter(constraints.maxWidth);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 8),
                child: AdminHeader(
                  title: l10n.adminAddDoctor,
                  subtitle: compact ? null : l10n.adminAddDoctorSubtitle,
                  leading: AdminBackButton(fallback: widget.listPath),
                ),
              ),
              AnimatedSize(
                duration: Motion.normal,
                curve: Motion.standardCurve,
                child: compact
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: EdgeInsets.fromLTRB(gutter, 4, gutter, 12),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: kRegistrationFormWidth),
                            child: StepProgress(step: _step, labels: labels),
                          ),
                        ),
                      ),
              ),
              Expanded(
                child: ShakeOnError(
                  trigger: _failures == 0 ? null : _failures,
                  child: PageTransitionSwitcher(
                    reverse: _reverse,
                    duration: reduced ? Motion.normal : Motion.slow,
                    layoutBuilder: (entries) => Stack(fit: StackFit.expand, children: entries),
                    transitionBuilder: (child, primary, secondary) => reduced
                        ? FadeTransition(
                            opacity: primary,
                            child: FadeTransition(opacity: ReverseAnimation(secondary), child: child),
                          )
                        : DirectionalSharedAxisTransition(animation: primary, secondaryAnimation: secondary, child: child),
                    child: KeyedSubtree(key: ValueKey(_step), child: _stepView(_step)),
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surface,
                  border: Border(top: BorderSide(color: scheme.outlineVariant)),
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(gutter, 12, gutter, 12 + media.padding.bottom),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: kRegistrationFormWidth),
                      child: _actions(l10n),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
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

  Widget _actions(AppLocalizations l10n) {
    final Widget forward = _step == _reviewStep
        ? SubmitButton(label: l10n.adminAddDoctor, status: _status, onPressed: _submit)
        : FilledButton.icon(
            onPressed: _busy ? null : _next,
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
                  child: OutlinedButton(onPressed: _busy ? null : _back, child: Text(l10n.regBack)),
                ),
        ),
        Expanded(child: forward),
      ],
    );
  }
}

/// The doctor is in: who gets the email and what to do if it expires.
class _AddedDialog extends StatelessWidget {
  const _AddedDialog({required this.doctor});

  final DoctorRegistration doctor;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return AlertDialog(
      icon: const SuccessCheck(size: 64),
      title: Text(l10n.adminAddDoctorDoneTitle(doctor.fullName), textAlign: TextAlign.center),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Text(
          l10n.adminAddDoctorDoneBody(ltrIsolate(doctor.email ?? '')),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge,
        ),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        FilledButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.adminAddDoctorOpen)),
      ],
    );
  }
}
