import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error_text.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/skeleton_loading.dart';
import '../../../core/widgets/staggered_entrance.dart';
import '../../../core/widgets/state_switcher.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../clinic_admin/clinic_admin_routes.dart';
import '../../clinic_admin/presentation/widgets/clinic_admin_widgets.dart' show ClinicPage;
import '../../patients/presentation/widgets/clinic_ui.dart';
import '../application/prescriptions_providers.dart';
import '../data/prescriptions_repository.dart';
import '../domain/prescription_models.dart';
import '../pdf/rx_text.dart';
import 'widgets/rx_widgets.dart';

/// D23 [S] «القوالب والمفضلة»: saved templates (rename, delete; they're used
/// from the editors' «من قالب») and the frequently used items behind "Used
/// before" (BR-CAT4), which can be removed. Doctor only.
class TemplatesScreen extends ConsumerWidget {
  const TemplatesScreen({super.key});

  Future<void> _rename(BuildContext context, WidgetRef ref, PrescriptionTemplate template) async {
    final l10n = AppLocalizations.of(context);
    final name = await askRxTemplateName(context, initial: template.name, title: l10n.rxRenameTemplate);
    if (name == null || !context.mounted) return;
    try {
      await ref.read(prescriptionsRepositoryProvider).updateTemplate(template, name: name);
      ref.invalidate(templatesProvider);
    } on ApiException catch (error) {
      if (context.mounted) showAdminSnack(context, l10n.apiError(error), error: true);
    }
  }

  Future<void> _deleteTemplate(BuildContext context, WidgetRef ref, PrescriptionTemplate template) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await confirmAction(
      context,
      title: l10n.rxDeleteTemplateTitle,
      message: l10n.rxDeleteTemplateBody(template.name),
      confirmLabel: l10n.rxDeleteTemplate,
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    try {
      await ref.read(prescriptionsRepositoryProvider).deleteTemplate(template.templateId);
      ref.invalidate(templatesProvider);
      if (context.mounted) showAdminSnack(context, l10n.rxTemplateDeleted);
    } on ApiException catch (error) {
      if (context.mounted) showAdminSnack(context, l10n.apiError(error), error: true);
    }
  }

  Future<void> _deleteItem(BuildContext context, WidgetRef ref, ItemHistoryEntry item) async {
    final l10n = AppLocalizations.of(context);
    try {
      await ref.read(prescriptionsRepositoryProvider).deleteHistoryItem(item.itemId);
      ref.invalidate(itemHistoryProvider);
      if (context.mounted) showAdminSnack(context, l10n.rxHistoryItemRemoved(item.name));
    } on ApiException catch (error) {
      if (context.mounted) showAdminSnack(context, l10n.apiError(error), error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final templates = ref.watch(templatesProvider(null));
    final history = ref.watch(itemHistoryProvider);
    return Scaffold(
      body: ClinicPage(
        builder: (context, width) {
          final wide = width >= 900;
          final header = ClinicHeader(
            title: l10n.rxTemplatesTitle,
            subtitle: l10n.rxTemplatesSubtitle,
            backFallback: ClinicAdminRoutes.doctorSettings,
          );
          final templatesCard = SectionCard(
            title: l10n.rxTemplatesGroup,
            icon: Icons.bookmarks_outlined,
            child: AsyncStateSwitcher<List<PrescriptionTemplate>>(
              value: templates,
              loading: (context) => const SkeletonLoading(loading: true, child: SizedBox(height: 120)),
              error: (context, error) => AdminErrorView(
                error: error,
                compact: true,
                onRetry: () => ref.invalidate(templatesProvider),
              ),
              data: (context, list) => list.isEmpty
                  ? EmptyState(title: l10n.rxNoTemplates, message: l10n.rxNoTemplatesBody)
                  : StaggerGroup(
                      child: Column(
                        children: [
                          for (final (i, template) in list.indexed)
                            StaggeredEntrance(
                              index: i,
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(rxKindIcon(template.kind)),
                                title: Text(template.name),
                                subtitle: Text(
                                  '${rxKindName(l10n, template.kind)}${l10n.adminListSeparator}${l10n.rxItemCount(template.itemCount)}',
                                ),
                                trailing: Wrap(
                                  children: [
                                    IconButton(
                                      tooltip: l10n.rxRenameTemplate,
                                      onPressed: () => _rename(context, ref, template),
                                      icon: const Icon(Icons.drive_file_rename_outline),
                                    ),
                                    IconButton(
                                      tooltip: l10n.rxDeleteTemplate,
                                      onPressed: () => _deleteTemplate(context, ref, template),
                                      icon: const Icon(Icons.delete_outline),
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
          final historyCard = SectionCard(
            title: l10n.rxFrequentGroup,
            subtitle: l10n.rxFrequentHint,
            icon: Icons.history,
            child: AsyncStateSwitcher<List<ItemHistoryEntry>>(
              value: history,
              loading: (context) => const SkeletonLoading(loading: true, child: SizedBox(height: 120)),
              error: (context, error) => AdminErrorView(
                error: error,
                compact: true,
                onRetry: () => ref.invalidate(itemHistoryProvider),
              ),
              data: (context, list) => list.isEmpty
                  ? Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(l10n.rxNoHistory))
                  : Column(
                      children: [
                        for (final item in list.take(100))
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(item.isDrug
                                ? Icons.medication_outlined
                                : (item.kind == 'lab' ? Icons.science_outlined : Icons.settings_overscan_outlined)),
                            title: Text([item.name, if (item.strength.isNotEmpty) item.strength].join(' · ')),
                            subtitle: Text(l10n.rxUsedTimes(item.useCount)),
                            trailing: IconButton(
                              tooltip: l10n.rxRemoveFromHistory,
                              onPressed: () => _deleteItem(context, ref, item),
                              icon: const Icon(Icons.close),
                            ),
                          ),
                      ],
                    ),
            ),
          );
          if (!wide) return [header, const SizedBox(height: 16), templatesCard, const SizedBox(height: 16), historyCard];
          return [
            header,
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: templatesCard),
                const SizedBox(width: 24),
                Expanded(child: historyCard),
              ],
            ),
          ];
        },
      ),
    );
  }
}
