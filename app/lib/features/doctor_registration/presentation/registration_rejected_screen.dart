import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/widgets/status_layout.dart';
import '../../../core/widgets/support_contact.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../auth/application/auth_controller.dart';

/// A7: the admin rejected the sign-up. The admin's reason stands out in its
/// own card; "Edit and resubmit" opens A4 filled with the submitted data.
class RegistrationRejectedScreen extends ConsumerWidget {
  const RegistrationRejectedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final reason = ref.watch(authControllerProvider).value?.doctorStatusReason?.trim();
    return StatusLayout(
      icon: Icons.assignment_late_outlined,
      tone: StatusTone.error,
      title: l10n.regRejectedTitle,
      message: l10n.regRejectedBody,
      details: [
        _ReasonCard(reason: reason == null || reason.isEmpty ? null : reason),
        const SupportContact(),
      ],
      actions: [
        FilledButton.icon(
          onPressed: () => context.go(AppRoutes.resubmit),
          icon: const Icon(Icons.edit_outlined),
          label: Text(l10n.regEditAndResubmit),
        ),
        TextButton.icon(
          onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          icon: const Icon(Icons.logout),
          label: Text(l10n.logout),
        ),
      ],
    );
  }
}

/// The admin's reason, with an accent along its start edge.
class _ReasonCard extends StatelessWidget {
  const _ReasonCard({required this.reason});

  /// Null when the admin gave none.
  final String? reason;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      container: true,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ColoredBox(color: scheme.error, child: const SizedBox(width: 6)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          ExcludeSemantics(child: Icon(Icons.format_quote_rounded, size: 20, color: scheme.error)),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              l10n.regRejectedReason,
                              style: theme.textTheme.labelLarge?.copyWith(color: scheme.error),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        reason ?? l10n.regRejectedNoReason,
                        style: reason == null
                            ? theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant)
                            : theme.textTheme.titleMedium?.copyWith(height: 1.5),
                      ),
                    ],
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
