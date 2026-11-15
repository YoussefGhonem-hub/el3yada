import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/app_format.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/skeleton_loading.dart';
import '../../../../core/widgets/state_switcher.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../auth/domain/user_role.dart';
import '../../../clinic/application/clinic_providers.dart';
import '../../../clinic/domain/clinic_permissions.dart';
import '../../application/clinic_admin_controllers.dart';
import '../../clinic_admin_routes.dart';
import '../../domain/branch_models.dart';
import '../../domain/price_models.dart';
import '../branches/branch_text.dart';
import '../widgets/clinic_admin_widgets.dart';
import 'price_editor.dart';

/// D37 (doctor) and AS19 (assistant with `pricesManage`): the doctor's
/// examination and consultation prices, each branch's own prices or «Use
/// the doctor's prices», and the history of every change (BR-PR5). An
/// assistant changes only their own branches (BR-AS13). New prices apply to
/// visits saved afterwards (BR-PR4). Archived branches are left out: patients
/// can't see or book them.
class VisitPricesScreen extends ConsumerWidget {
  const VisitPricesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final doctor = ref.watch(authControllerProvider.select((auth) => auth.value?.role)) == UserRole.doctor;
    final fallback = doctor ? ClinicAdminRoutes.doctorSettings : ClinicAdminRoutes.assistantSettings;
    final clinic = ref.watch(clinicContextProvider).value;
    final back = Align(
      alignment: AlignmentDirectional.centerStart,
      child: Padding(padding: const EdgeInsets.all(8), child: ClinicBackButton(fallback: fallback)),
    );

    // Hidden from assistants without the permission (spec 7.6); the route
    // sends them back too.
    if (clinic != null && !clinic.can(ClinicPermission.pricesManage)) {
      return Scaffold(
        body: Column(
          children: [back, Expanded(child: EmptyState(title: l10n.errorPermissionDenied))],
        ),
      );
    }

    final prices = ref.watch(pricesProvider);
    return Scaffold(
      body: AsyncStateSwitcher<PricesOverview>(
        value: prices,
        loading: (context) => const _PricesSkeleton(),
        error: (context, error) => Column(
          children: [
            back,
            Expanded(child: AdminErrorView(error: error, onRetry: () => ref.read(pricesProvider.notifier).reload())),
          ],
        ),
        data: (context, overview) => _PricesContent(overview: overview, fallback: fallback),
      ),
    );
  }
}

class _PricesContent extends ConsumerWidget {
  const _PricesContent({required this.overview, required this.fallback});

  final PricesOverview overview;
  final String fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(pricesProvider.notifier);
    final branches = [for (final b in overview.branches) if (b.status != BranchStatuses.archived) b];
    final doctorPrices = overview.doctor;

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.axis == Axis.vertical && notification.metrics.extentAfter < 400) {
          ref.read(priceHistoryProvider.notifier).loadMore();
        }
        return false;
      },
      child: ClinicPage(
        maxWidth: 1180,
        builder: (context, width) {
          final wide = width >= 980;
          const gap = SizedBox(height: 16);
          final header = AdminHeader(
            leading: ClinicBackButton(fallback: fallback),
            title: l10n.pricesTitle,
            subtitle: l10n.pricesSubtitle,
          );
          final note = InfoBanner(icon: Icons.schedule_outlined, message: l10n.pricesFutureOnly);
          final doctorTicket = TicketCard(
            stub: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: PriceEditor(
                key: ValueKey(('doctor', doctorPrices.examinationPricePiasters, doctorPrices.consultationPricePiasters)),
                fieldPrefix: 'doctor',
                saved: doctorPrices,
                onSave: (exam, consult) => controller.save(examination: exam, consultation: consult),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: _CardTitle(icon: Icons.person_outline, title: l10n.pricesDoctorTitle, subtitle: l10n.pricesDoctorBody),
            ),
          );
          final branchCards = [
            for (final branch in branches) ...[
              _BranchPricesCard(
                branch: branch,
                doctorPrices: doctorPrices,
                onSave: (exam, consult) => controller.save(branchId: branch.branchId, examination: exam, consultation: consult),
              ),
              gap,
            ],
          ];
          final branchesTitle = Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 8, 8),
            child: Semantics(
              header: true,
              child: Text(
                l10n.pricesBranchesTitle,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary),
              ),
            ),
          );
          const history = _PriceHistory();
          if (!wide) return [header, gap, note, gap, doctorTicket, gap, branchesTitle, ...branchCards, history];
          return [
            header,
            gap,
            note,
            gap,
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [doctorTicket, gap, branchesTitle, ...branchCards],
                  ),
                ),
                const SizedBox(width: 24),
                const Expanded(flex: 2, child: history),
              ],
            ),
          ];
        },
      ),
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle({required this.icon, required this.title, this.subtitle, this.trailing = const []});

  final IconData icon;
  final String title;
  final String? subtitle;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RowIcon(icon),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [Semantics(header: true, child: Text(title, style: theme.textTheme.titleMedium)), ...trailing],
              ),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(subtitle!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BranchPricesCard extends StatelessWidget {
  const _BranchPricesCard({required this.branch, required this.doctorPrices, required this.onSave});

  final BranchPriceRow branch;
  final PricePair doctorPrices;
  final Future<void> Function(int? examination, int? consultation) onSave;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final own = PricePair(
      examinationPricePiasters: branch.prices.examinationPricePiasters,
      consultationPricePiasters: branch.prices.consultationPricePiasters,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CardTitle(
              icon: Icons.store_mall_directory_outlined,
              title: branch.name(language),
              trailing: [
                if (branch.isDefault) const DefaultBranchPill(),
                if (branch.status != BranchStatuses.active) BranchStatusPill(status: branch.status),
              ],
            ),
            const SizedBox(height: 8),
            PriceEditor(
              key: ValueKey((branch.branchId, own.examinationPricePiasters, own.consultationPricePiasters, doctorPrices)),
              fieldPrefix: branch.branchId,
              saved: own,
              doctorPrices: doctorPrices,
              enabled: branch.assigned,
              onSave: onSave,
            ),
            if (!branch.assigned)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: InfoBanner(icon: Icons.lock_outline, tone: PillTone.neutral, message: l10n.pricesNotYourBranch),
              ),
          ],
        ),
      ),
    );
  }
}

/// BR-PR5: date, who, branch, old → new; newest first, page by page.
class _PriceHistory extends ConsumerWidget {
  const _PriceHistory();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(priceHistoryProvider);
    final controller = ref.read(priceHistoryProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 8, 8),
          child: Semantics(
            header: true,
            child: Text(
              l10n.pricesHistoryTitle,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary),
            ),
          ),
        ),
        Card(
          clipBehavior: Clip.antiAlias,
          child: StateSwitcher(
            state: state.view,
            loading: (context) => SkeletonLoading(
              loading: true,
              child: Column(children: [for (var i = 0; i < 3; i++) _HistoryRow.placeholder()]),
            ),
            empty: (context) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: EmptyState(title: l10n.pricesHistoryEmptyTitle, message: l10n.pricesHistoryEmptyBody),
            ),
            error: (context) => Padding(
              padding: const EdgeInsets.all(12),
              child: AdminErrorView(error: state.error!, onRetry: controller.reload, compact: true),
            ),
            content: (context) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, entry) in state.items.indexed) ...[
                  if (i > 0) const Divider(height: 1, indent: 68),
                  _HistoryRow(entry: entry),
                ],
                if (state.moreError != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: AdminErrorView(error: state.moreError!, onRetry: controller.loadMore, compact: true),
                  )
                else if (state.hasMore || state.loadingMore)
                  SkeletonLoading(loading: true, child: _HistoryRow.placeholder()),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry});

  static Widget placeholder() => _HistoryRow(
        entry: PriceHistoryEntry(
          id: '',
          changedAt: DateTime.now(),
          changedBy: const PriceChangedBy(name: '-------------', role: 'doctor'),
          before: const PricePair(examinationPricePiasters: 10000),
          after: const PricePair(examinationPricePiasters: 20000),
        ),
      );

  final PriceHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final language = Localizations.localeOf(context).languageCode;
    String money(int? piasters) => piasters == null ? l10n.pricesNotSet : AppFormat.egp(context, piasters);
    final lines = [
      if (entry.before.examinationPricePiasters != entry.after.examinationPricePiasters)
        l10n.pricesChange(
          l10n.regExaminationPrice,
          money(entry.before.examinationPricePiasters),
          money(entry.after.examinationPricePiasters),
        ),
      if (entry.before.consultationPricePiasters != entry.after.consultationPricePiasters)
        l10n.pricesChange(
          l10n.regConsultationPrice,
          money(entry.before.consultationPricePiasters),
          money(entry.after.consultationPricePiasters),
        ),
    ];
    final who = entry.changedBy.name ?? l10n.adminUnknownUser;
    final role = entry.changedBy.role == 'assistant' ? l10n.roleAssistant : l10n.roleDoctor;
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RowIcon(entry.branchId == null ? Icons.person_outline : Icons.store_mall_directory_outlined),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.branchName(language) ?? l10n.pricesDoctorTitle, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  for (final line in lines) Text(line, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 4),
                  Text(
                    l10n.pricesChangedBy(who, role, AppFormat.dateTime(context, entry.changedAt)),
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PricesSkeleton extends StatelessWidget {
  const _PricesSkeleton();

  @override
  Widget build(BuildContext context) => SkeletonLoading(
        loading: true,
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: const [
            Text('------------------'),
            SizedBox(height: 16),
            Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('--------------'),
                    SizedBox(height: 16),
                    Row(children: [
                      Expanded(child: TextField(decoration: InputDecoration(labelText: '------'))),
                      SizedBox(width: 12),
                      Expanded(child: TextField(decoration: InputDecoration(labelText: '------'))),
                    ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}
