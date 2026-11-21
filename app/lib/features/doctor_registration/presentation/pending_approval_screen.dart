import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/routes.dart';
import '../../../core/network/api_error_text.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/settings_actions.dart';
import '../../../core/widgets/skeleton_loading.dart';
import '../../../core/widgets/staggered_entrance.dart';
import '../../../core/widgets/state_switcher.dart';
import '../../../core/widgets/submit_button.dart';
import '../../../core/widgets/support_contact.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_session.dart';
import '../application/registration_providers.dart';
import 'registration_text.dart';
import 'widgets/form_parts.dart';
import 'widgets/registration_summary.dart';

/// A6: the sign-up waits for the admin. "Your account is being reviewed",
/// the submitted data read-only (skeleton while it loads), the support
/// contact, Refresh and Log out. When the email isn't verified, a card opens
/// A5. Refresh reloads the account; once approved (or rejected) the router
/// leaves this screen by itself. Desktop puts the data beside the status.
class PendingApprovalScreen extends ConsumerStatefulWidget {
  const PendingApprovalScreen({super.key});

  @override
  ConsumerState<PendingApprovalScreen> createState() => _PendingApprovalScreenState();
}

class _PendingApprovalScreenState extends ConsumerState<PendingApprovalScreen> {
  SubmitStatus _status = SubmitStatus.idle;

  Future<void> _refresh() async {
    if (_status != SubmitStatus.idle) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _status = SubmitStatus.loading);
    try {
      await ref.read(authControllerProvider.notifier).reloadAccount();
      ref.invalidate(myRegistrationProvider);
      final status = ref.read(authControllerProvider).value?.doctorStatus;
      if (mounted && status == DoctorStatus.pendingApproval) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.regStillPending)));
      }
    } on ApiException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.apiError(error))));
    } finally {
      if (mounted) setState(() => _status = SubmitStatus.idle);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final session = ref.watch(authControllerProvider).value;

    final status = <Widget>[
      ExcludeSemantics(
        child: Center(
          child: DecoratedBox(
            decoration: BoxDecoration(color: scheme.primaryContainer, shape: BoxShape.circle),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Icon(Icons.hourglass_top, size: 40, color: scheme.onPrimaryContainer),
            ),
          ),
        ),
      ),
      Column(
        children: [
          Semantics(
            header: true,
            child: Text(l10n.regPendingTitle, textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.regPendingBody,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
      if (session != null && !session.emailVerified && session.email != null) _VerifyEmailCard(email: session.email!),
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SubmitButton(label: l10n.regRefresh, status: _status, onPressed: _refresh),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
            icon: const Icon(Icons.logout),
            label: Text(l10n.logout),
          ),
        ],
      ),
      const SupportContact(),
    ];

    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false, actions: const [SettingsActions(showLogout: false)]),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= Breakpoints.desktop;
              var index = 0;
              Widget enter(Widget child) => StaggeredEntrance(index: index++, child: child);
              List<Widget> spaced(List<Widget> children, double gap) => [
                    for (final (i, child) in children.indexed) ...[if (i > 0) SizedBox(height: gap), enter(child)],
                  ];

              final Widget content = wide
                  ? ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1080),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 4,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: spaced(status, 24),
                              ),
                            ),
                          ),
                          const SizedBox(width: 40),
                          Expanded(flex: 5, child: enter(const _SubmittedData())),
                        ],
                      ),
                    )
                  : ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: kRegistrationFormWidth),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: spaced([...status, const _SubmittedData()], 24),
                      ),
                    );

              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                child: Center(child: StaggerGroup(child: content)),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// "Verify your email" (A5), shown while the email isn't verified.
class _VerifyEmailCard extends StatelessWidget {
  const _VerifyEmailCard({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Pressable(
      onTap: () => context.push(AppRoutes.verifyEmail),
      borderRadius: BorderRadius.circular(20),
      semanticLabel: '${l10n.regVerifyCardTitle}. ${l10n.regVerifyCardBody(ltrIsolate(email))}',
      child: Card(
        color: scheme.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.mark_email_unread_outlined, color: scheme.onSecondaryContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.regVerifyCardTitle, style: theme.textTheme.titleSmall?.copyWith(color: scheme.onSecondaryContainer)),
                    const SizedBox(height: 2),
                    Text(
                      l10n.regVerifyCardBody(ltrIsolate(email)),
                      style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSecondaryContainer),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: scheme.onSecondaryContainer),
            ],
          ),
        ),
      ),
    );
  }
}

/// The registration as sent, read-only.
class _SubmittedData extends ConsumerWidget {
  const _SubmittedData();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final registration = ref.watch(myRegistrationProvider);
    final submittedAt = registration.value?.submittedAt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(header: true, child: Text(l10n.regSubmittedData, style: theme.textTheme.titleLarge)),
        if (submittedAt != null) ...[
          const SizedBox(height: 2),
          Text(
            l10n.regSubmittedOn((DateFormat.yMMMd(language)..useNativeDigits = false).format(submittedAt.toLocal())),
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
        const SizedBox(height: 12),
        AsyncStateSwitcher(
          value: registration,
          loading: (context) => const SkeletonLoading(loading: true, child: RegistrationSummary(data: SummaryData.placeholder)),
          data: (context, view) => RegistrationSummary(data: SummaryData.fromView(view, language)),
          error: (context, error) => Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(liveRegion: true, child: Text(l10n.regDataError, style: theme.textTheme.titleSmall)),
                  const SizedBox(height: 4),
                  Text(l10n.apiError(error), style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => ref.invalidate(myRegistrationProvider),
                    icon: const Icon(Icons.refresh),
                    label: Text(l10n.retryButton),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
