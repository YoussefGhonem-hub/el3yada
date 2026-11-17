import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/app_format.dart';
import '../../../../core/network/api_error_text.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/motion.dart';
import '../../../../core/widgets/map_link_field.dart';
import '../../../../core/widgets/skeleton_loading.dart';
import '../../../../core/widgets/staggered_entrance.dart';
import '../../../../core/widgets/state_switcher.dart';
import '../../../../core/widgets/submit_button.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../admin_routes.dart';
import '../../application/admin_controllers.dart';
import '../../data/admin_repository.dart';
import '../../domain/admin_models.dart';
import '../widgets/admin_widgets.dart';
import 'license_viewer.dart';
import 'trial_parts.dart';

/// Called after a review succeeded, once the success check has shown.
typedef OnReviewed = void Function(DoctorRegistration registration, ReviewDecision decision);

/// AD3 as a page: phones (opened from AD2 with a container transform) and
/// links (`/admin/signups/{doctorId}`, the «طبيب جديد» notification).
class SignupReviewPage extends ConsumerWidget {
  const SignupReviewPage({super.key, required this.doctorId, this.onReviewed});

  final String doctorId;

  /// Null: the page tells AD2, shows a message and goes back by itself.
  final OnReviewed? onReviewed;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        body: SignupReviewView(
          doctorId: doctorId,
          showBack: true,
          onReviewed: onReviewed ??
              (registration, decision) {
                ref.read(signupsControllerProvider.notifier).reviewed(registration.doctorId);
                showAdminSnack(context, reviewedMessage(AppLocalizations.of(context), registration, decision));
                final navigator = Navigator.of(context);
                if (navigator.canPop()) navigator.pop();
              },
        ),
      );
}

/// The message after a review.
String reviewedMessage(AppLocalizations l10n, DoctorRegistration registration, ReviewDecision decision) =>
    decision == ReviewDecision.approve
        ? l10n.adminApprovedMessage(registration.fullName)
        : l10n.adminRejectedMessage(registration.fullName);

/// AD3: everything the doctor submitted in A4, the license, earlier reviews,
/// and Approve / Reject. Used full screen and as the desktop detail pane.
class SignupReviewView extends ConsumerWidget {
  const SignupReviewView({super.key, required this.doctorId, required this.onReviewed, this.showBack = false});

  final String doctorId;
  final OnReviewed onReviewed;
  final bool showBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(registrationDetailProvider(doctorId));
    return AsyncStateSwitcher<RegistrationDetail>(
      value: detail,
      loading: (context) => const _ReviewSkeleton(),
      error: (context, error) => Column(
        children: [
          if (showBack)
            const Padding(
              padding: EdgeInsetsDirectional.only(start: 8, top: 8),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: AdminBackButton(fallback: AdminRoutes.signups),
              ),
            ),
          Expanded(
            child: AdminErrorView(
              error: error,
              onRetry: () => ref.invalidate(registrationDetailProvider(doctorId)),
            ),
          ),
        ],
      ),
      data: (context, detail) => _ReviewContent(
        key: ValueKey(detail.registration.status),
        detail: detail,
        showBack: showBack,
        onReviewed: onReviewed,
      ),
    );
  }
}

class _ReviewContent extends ConsumerStatefulWidget {
  const _ReviewContent({super.key, required this.detail, required this.showBack, required this.onReviewed});

  final RegistrationDetail detail;
  final bool showBack;
  final OnReviewed onReviewed;

  @override
  ConsumerState<_ReviewContent> createState() => _ReviewContentState();
}

class _ReviewContentState extends ConsumerState<_ReviewContent> {
  SubmitStatus _approve = SubmitStatus.idle;
  bool _busy = false;

  DoctorRegistration get _registration => widget.detail.registration;

  Future<void> _onApprove() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await confirmAction(
      context,
      title: l10n.adminApproveTitle(_registration.fullName),
      message: l10n.adminApproveBody,
      confirmLabel: l10n.adminApprove,
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _approve = SubmitStatus.loading;
      _busy = true;
    });
    try {
      final result = await ref
          .read(adminRepositoryProvider)
          .reviewDoctorRegistration(doctorId: _registration.doctorId, decision: ReviewDecision.approve);
      if (!mounted) return;
      setState(() => _approve = SubmitStatus.success);
      await Future<void>.delayed(Motion.of(context).reduced ? Duration.zero : Motion.slow);
      if (mounted) widget.onReviewed(result, ReviewDecision.approve);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _approve = SubmitStatus.idle;
        _busy = false;
      });
      _handleError(error);
    }
  }

  Future<void> _onReject() async {
    final result = await showDialog<DoctorRegistration>(
      context: context,
      builder: (context) => _RejectDialog(registration: _registration),
    );
    if (result == null || !mounted) return;
    if (result.status == DoctorStatuses.pendingApproval) {
      // The dialog hit REGISTRATION_NOT_PENDING: someone else answered.
      _handleError(const ApiException(kind: ApiErrorKind.http, status: 409, code: 'REGISTRATION_NOT_PENDING'));
      return;
    }
    widget.onReviewed(result, ReviewDecision.reject);
  }

  void _handleError(ApiException error) {
    final l10n = AppLocalizations.of(context);
    showAdminSnack(context, l10n.apiError(error), error: true);
    if (error.code == 'REGISTRATION_NOT_PENDING') {
      // Another admin answered first: show the current status, and drop it from AD2.
      ref.read(signupsControllerProvider.notifier).reviewed(_registration.doctorId);
      ref.invalidate(registrationDetailProvider(_registration.doctorId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final registration = _registration;
    final reviews = widget.detail.reviews;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final gutter = width >= 600 ? 24.0 : 16.0;
        final twoColumns = width >= 900;
        final bottomInset = MediaQuery.paddingOf(context).bottom;
        // Phones keep the actions at the end of the page: a fixed bar would
        // sit on top of the floating navigation bar and hide too much.
        final stickyActions = width >= 600;
        final actions = registration.isPending
            ? _ActionBar(
                sticky: stickyActions,
                bottomInset: stickyActions ? bottomInset : 0,
                gutter: stickyActions ? gutter : 0,
                busy: _busy,
                approveStatus: _approve,
                onApprove: _onApprove,
                onReject: _onReject,
              )
            : null;

        final header = _ReviewHeader(
          registration: registration,
          reviews: reviews,
          showBack: widget.showBack,
          compact: width < 600,
        );
        final license = LicenseCard(
          doctorId: registration.doctorId,
          doctorName: registration.fullName,
          previewHeight: twoColumns ? 320 : 220,
        );
        final details = <Widget>[
          if (registration.isApproved) DoctorTrialSection(registration: registration),
          _AccountSection(registration: registration),
          _ProfessionalSection(registration: registration),
          if (registration.branch != null) _BranchSection(branch: registration.branch!),
          _PricesSection(registration: registration),
          if (reviews.isNotEmpty) _HistorySection(reviews: reviews),
        ];

        var index = 0;
        Widget enter(Widget child) => StaggeredEntrance(index: index++, child: child);
        const gap = SizedBox(height: 16);

        final body = twoColumns
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: Column(children: [for (final section in details) ...[enter(section), gap]]),
                  ),
                  const SizedBox(width: 16),
                  Expanded(flex: 4, child: enter(license)),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [enter(license), gap, for (final section in details) ...[enter(section), gap]],
              );

        return Column(
          children: [
            Expanded(
              child: StaggerGroup(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    gutter,
                    widget.showBack ? 8 : gutter,
                    gutter,
                    16 + (actions != null && stickyActions ? 0 : bottomInset),
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          enter(header),
                          gap,
                          body,
                          if (actions != null && !stickyActions) actions,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (actions != null && stickyActions) actions,
          ],
        );
      },
    );
  }
}

/// Approve and Reject: a bar fixed under the content on tablets and
/// desktops, a card at the end of the page on phones.
class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.sticky,
    required this.bottomInset,
    required this.gutter,
    required this.busy,
    required this.approveStatus,
    required this.onApprove,
    required this.onReject,
  });

  final bool sticky;
  final double bottomInset;
  final double gutter;
  final bool busy;
  final SubmitStatus approveStatus;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final reject = OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.error,
        side: BorderSide(color: scheme.error, width: 2),
      ),
      onPressed: busy ? null : onReject,
      icon: const Icon(Icons.close),
      label: Text(l10n.adminReject),
    );
    final approve = SubmitButton(label: l10n.adminApprove, status: approveStatus, onPressed: onApprove);
    if (!sticky) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.adminReviewHint, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
              const SizedBox(height: 16),
              approve,
              const SizedBox(height: 12),
              reject,
            ],
          ),
        ),
      );
    }
    return Material(
      color: scheme.surfaceContainerLow,
      child: DecoratedBox(
        decoration: BoxDecoration(border: Border(top: BorderSide(color: scheme.outlineVariant))),
        child: Padding(
          padding: EdgeInsets.fromLTRB(gutter, 12, gutter, 12 + bottomInset),
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 520) {
                return Row(
                  children: [
                    Expanded(child: reject),
                    const SizedBox(width: 12),
                    Expanded(flex: 2, child: approve),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.adminReviewHint,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(width: 160, child: reject),
                  const SizedBox(width: 12),
                  SizedBox(width: 200, child: approve),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The "ticket" at the top: who, what, where from, and the status.
class _ReviewHeader extends StatelessWidget {
  const _ReviewHeader({
    required this.registration,
    required this.reviews,
    required this.showBack,
    required this.compact,
  });

  final DoctorRegistration registration;
  final List<RegistrationReview> reviews;
  final bool showBack;

  /// Phone width: a smaller name.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final language = Localizations.localeOf(context).languageCode;
    final resubmitted = reviews.any((r) => r.decision == ReviewDecision.reject) && registration.isPending;
    final lastRejection = reviews.where((r) => r.decision == ReviewDecision.reject).firstOrNull;
    final (statusLabel, statusTone) = switch (registration.status) {
      DoctorStatuses.pendingApproval => (l10n.adminStatusPending, PillTone.warning),
      DoctorStatuses.active => (l10n.adminStatusActive, PillTone.positive),
      DoctorStatuses.rejected => (l10n.adminStatusRejected, PillTone.danger),
      DoctorStatuses.suspended => (l10n.adminStatusSuspended, PillTone.danger),
      _ => (l10n.adminStatusDisabled, PillTone.neutral),
    };
    final specialty = registration.specialty.name(language);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: scheme.primaryContainer,
            padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 20, 8),
            child: Row(
              children: [
                if (showBack) const AdminBackButton(fallback: AdminRoutes.signups) else const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    registration.isPending || registration.status == DoctorStatuses.rejected
                        ? l10n.adminReviewTitle
                        : l10n.adminDoctorTitle,
                    style: theme.textTheme.titleSmall?.copyWith(color: scheme.onPrimaryContainer),
                  ),
                ),
                StatusPill(label: statusLabel, tone: statusTone),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InitialAvatar(name: registration.fullName, size: compact ? 48 : 56),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          l10n.adminDoctorName(registration.fullName),
                          style: compact ? theme.textTheme.titleLarge : theme.textTheme.headlineSmall,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        registration.title.isEmpty ? specialty : '${registration.title} · $specialty',
                        style: theme.textTheme.titleSmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                      if (registration.branch != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${registration.branch!.governorate}${l10n.adminListSeparator}${registration.branch!.city}',
                          style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Icon(Icons.schedule, size: 16, color: scheme.onSurfaceVariant),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              l10n.adminSubmittedAt(
                                AppFormat.relative(context, registration.submittedAt),
                                AppFormat.dateTime(context, registration.submittedAt),
                              ),
                              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ),
                        ],
                      ),
                      if (resubmitted || !registration.emailVerified) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (resubmitted)
                              StatusPill(icon: Icons.replay, label: l10n.adminResubmitted, tone: PillTone.warning),
                            if (!registration.emailVerified)
                              StatusPill(icon: Icons.mark_email_unread_outlined, label: l10n.adminEmailNotVerified),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (resubmitted && lastRejection?.reason != null)
            Container(
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: scheme.tertiaryContainer, borderRadius: BorderRadius.circular(14)),
              child: MergeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.adminPreviousRejection,
                      style: theme.textTheme.labelLarge?.copyWith(color: scheme.onTertiaryContainer),
                    ),
                    const SizedBox(height: 4),
                    Text(lastRejection!.reason!, style: TextStyle(color: scheme.onTertiaryContainer)),
                  ],
                ),
              ),
            ),
          if (!registration.isPending && registration.statusReason != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: InfoRow(label: l10n.adminRejectReasonLabel, value: registration.statusReason),
            ),
        ],
      ),
    );
  }
}

class _AccountSection extends StatelessWidget {
  const _AccountSection({required this.registration});

  final DoctorRegistration registration;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SectionCard(
      icon: Icons.person_outline,
      title: l10n.adminSectionAccount,
      child: ResponsiveGrid(children: [
        InfoRow(label: l10n.adminFieldFullName, value: registration.fullName),
        InfoRow(label: l10n.adminFieldFullNameEn, value: registration.fullNameEn),
        InfoRow(
          label: l10n.adminFieldEmail,
          child: registration.email == null
              ? null
              : Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    LtrText(registration.email!, style: Theme.of(context).textTheme.bodyLarge),
                    StatusPill(
                      label: registration.emailVerified ? l10n.adminEmailVerified : l10n.adminEmailNotVerified,
                      tone: registration.emailVerified ? PillTone.positive : PillTone.neutral,
                    ),
                  ],
                ),
        ),
        InfoRow(
          label: l10n.adminFieldMobile,
          value: registration.phone == null ? null : AppFormat.phone(registration.phone!),
          ltr: true,
        ),
        InfoRow(
          label: l10n.adminFieldLanguage,
          value: registration.locale == 'en' ? l10n.languageEnglish : l10n.languageArabic,
        ),
      ]),
    );
  }
}

class _ProfessionalSection extends StatelessWidget {
  const _ProfessionalSection({required this.registration});

  final DoctorRegistration registration;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    return SectionCard(
      icon: Icons.workspace_premium_outlined,
      title: l10n.adminSectionProfessional,
      child: ResponsiveGrid(children: [
        InfoRow(label: l10n.adminFieldTitle, value: registration.title.isEmpty ? null : registration.title),
        InfoRow(label: l10n.adminFieldTitleEn, value: registration.titleEn),
        InfoRow(label: l10n.adminFieldSpecialty, value: registration.specialty.name(language)),
        InfoRow(
          label: l10n.adminFieldExtraSpecialties,
          value: registration.extraSpecialties.isEmpty
              ? null
              : registration.extraSpecialties.map((s) => s.name(language)).join(l10n.adminListSeparator),
        ),
        InfoRow(label: l10n.adminFieldLicenseNumber, value: registration.licenseNumber, ltr: true),
        InfoRow(label: l10n.adminFieldDegreesAr, value: registration.degreesAr),
        InfoRow(label: l10n.adminFieldDegreesEn, value: registration.degreesEn),
      ]),
    );
  }
}

class _BranchSection extends StatelessWidget {
  const _BranchSection({required this.branch});

  final RegistrationBranch branch;

  /// The detailed address as the doctor wrote it, then area, city and
  /// governorate on their own line.
  String _address(AppLocalizations l10n) {
    final place = [?branch.area, branch.city, branch.governorate].join(l10n.adminListSeparator);
    return [branch.addressDetails.trim(), place].where((part) => part.isNotEmpty).join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return SectionCard(
      icon: Icons.storefront_outlined,
      title: l10n.adminSectionBranch,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ResponsiveGrid(children: [
            InfoRow(label: l10n.adminFieldBranchName, value: branch.nameAr),
            InfoRow(label: l10n.adminFieldBranchNameEn, value: branch.nameEn),
          ]),
          const SizedBox(height: 16),
          InfoRow(label: l10n.adminFieldAddress, value: _address(l10n)),
          if (branch.mapUrl != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: OpenMapLinkButton(url: branch.mapUrl),
            ),
          ],
          const SizedBox(height: 16),
          ResponsiveGrid(children: [
            InfoRow(label: l10n.adminFieldLandmark, value: branch.landmark),
            InfoRow(label: l10n.adminFieldBranchEmail, value: branch.email, ltr: true),
          ]),
          const SizedBox(height: 16),
          InfoRow(
            label: l10n.adminFieldPhones,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final phone in branch.phones)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        LtrText(AppFormat.phone(phone.number), style: theme.textTheme.bodyLarge),
                        StatusPill(label: switch (phone.label) {
                          'mobile' => l10n.adminPhoneMobile,
                          'landline' => l10n.adminPhoneLandline,
                          _ => l10n.adminPhoneReception,
                        }),
                        if (phone.isWhatsapp) StatusPill(label: l10n.supportWhatsapp, tone: PillTone.positive),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PricesSection extends StatelessWidget {
  const _PricesSection({required this.registration});

  final DoctorRegistration registration;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    String? price(int? piasters) => piasters == null ? null : AppFormat.egp(context, piasters);
    return SectionCard(
      icon: Icons.sell_outlined,
      title: l10n.adminSectionPrices,
      child: ResponsiveGrid(children: [
        InfoRow(label: l10n.adminFieldExamPrice, value: price(registration.examinationPricePiasters), ltr: true),
        InfoRow(label: l10n.adminFieldConsultPrice, value: price(registration.consultationPricePiasters), ltr: true),
      ]),
    );
  }
}

class _HistorySection extends StatelessWidget {
  const _HistorySection({required this.reviews});

  final List<RegistrationReview> reviews;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SectionCard(
      icon: Icons.history,
      title: l10n.adminSectionReviews,
      child: Column(
        children: [
          for (final review in reviews)
            MergeSemantics(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      review.decision == ReviewDecision.approve ? Icons.check_circle_outline : Icons.cancel_outlined,
                      color: review.decision == ReviewDecision.approve ? scheme.primary : scheme.error,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            review.decision == ReviewDecision.approve
                                ? l10n.adminReviewApprovedBy(review.reviewedByName ?? l10n.adminSystem)
                                : l10n.adminReviewRejectedBy(review.reviewedByName ?? l10n.adminSystem),
                            style: theme.textTheme.titleSmall,
                          ),
                          Text(
                            AppFormat.dateTime(context, review.at),
                            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                          if (review.reason != null) ...[
                            const SizedBox(height: 4),
                            Text(review.reason!),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Reject needs a reason (3–500 characters) that the doctor sees on A7.
/// Pops with the updated registration, or with the unchanged one when the
/// request was already reviewed.
class _RejectDialog extends ConsumerStatefulWidget {
  const _RejectDialog({required this.registration});

  final DoctorRegistration registration;

  @override
  ConsumerState<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends ConsumerState<_RejectDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reason = TextEditingController();
  SubmitStatus _status = SubmitStatus.idle;
  String? _serverError;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _serverError = null;
      _error = null;
    });
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _status = SubmitStatus.loading);
    try {
      final result = await ref.read(adminRepositoryProvider).reviewDoctorRegistration(
            doctorId: widget.registration.doctorId,
            decision: ReviewDecision.reject,
            reason: _reason.text.trim(),
          );
      if (!mounted) return;
      setState(() => _status = SubmitStatus.success);
      await Future<void>.delayed(Motion.of(context).reduced ? Duration.zero : Motion.slow);
      if (mounted) Navigator.of(context).pop(result);
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.code == 'REGISTRATION_NOT_PENDING') {
        Navigator.of(context).pop(widget.registration);
        return;
      }
      setState(() {
        _status = SubmitStatus.idle;
        _serverError = l10n.fieldError(error.fieldCodes['reason']);
        _error = _serverError == null ? l10n.apiError(error) : null;
      });
      _formKey.currentState?.validate();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final presets = [l10n.adminRejectPresetLicense, l10n.adminRejectPresetNumber, l10n.adminRejectPresetBranch];
    final busy = _status != SubmitStatus.idle;
    return AlertDialog(
      title: Text(l10n.adminRejectTitle(widget.registration.fullName)),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, minWidth: 280),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.adminRejectBody, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _reason,
                  enabled: !busy,
                  autofocus: true,
                  minLines: 3,
                  maxLines: 6,
                  maxLength: 500,
                  decoration: InputDecoration(labelText: l10n.adminRejectReasonLabel, alignLabelWithHint: true),
                  validator: (value) {
                    if (_serverError != null) return _serverError;
                    final text = value?.trim() ?? '';
                    if (text.length < 3) return l10n.adminErrorReasonRequired;
                    return null;
                  },
                ),
                const SizedBox(height: 4),
                Text(l10n.adminRejectPresets, style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final preset in presets)
                      ActionChip(
                        label: Text(preset),
                        onPressed: busy
                            ? null
                            : () {
                                _reason.text = preset;
                                _reason.selection = TextSelection.collapsed(offset: preset.length);
                              },
                      ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Semantics(liveRegion: true, child: Text(_error!, style: TextStyle(color: scheme.error))),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: busy ? null : () => Navigator.of(context).pop(), child: Text(l10n.adminCancel)),
        SizedBox(
          width: 160,
          child: Theme(
            // A destructive submit: the same morphing button, in the error colour.
            data: theme.copyWith(colorScheme: scheme.copyWith(primary: scheme.error, onPrimary: scheme.onError)),
            child: SubmitButton(label: l10n.adminReject, status: _status, onPressed: _submit),
          ),
        ),
      ],
    );
  }
}

/// Shaped like the header and the first sections.
class _ReviewSkeleton extends StatelessWidget {
  const _ReviewSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget block(int lines) => Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [
                  CircleAvatar(radius: 24),
                  SizedBox(width: 16),
                  Expanded(child: Text('------------------------', maxLines: 1, overflow: TextOverflow.clip)),
                ]),
                for (var i = 0; i < lines; i++) ...[
                  const SizedBox(height: 12),
                  const Text('---------------------------------------', maxLines: 1, overflow: TextOverflow.clip),
                ],
              ],
            ),
          ),
        );
    return SkeletonLoading(
      loading: true,
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [block(2), const SizedBox(height: 16), block(5), const SizedBox(height: 16), block(3)],
      ),
    );
  }
}
