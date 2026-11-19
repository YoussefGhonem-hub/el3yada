import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/platform/contact_launcher.dart';
import '../application/patient_providers.dart';
import '../domain/patient_models.dart';
import 'patient_format.dart';
import 'patient_routes.dart';
import 'widgets/patient_widgets.dart';

/// P3 Doctor info: name, title, specialty, and one card per branch with address (maps),
/// phones (call, WhatsApp), working hours, prices, payment methods and amenities.
/// Book (P15) arrives with Phase 6 and Chat (P12) with Phase 5.
class DoctorInfoScreen extends ConsumerWidget {
  const DoctorInfoScreen({super.key, required this.doctorId});

  final String doctorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(doctorInfoProvider(doctorId));
    return Scaffold(
      appBar: AppBar(title: Text(info.value == null ? '' : context.doctorName(info.value!.doctor))),
      body: AsyncValueView(
        value: info,
        onRetry: () => ref.invalidate(doctorInfoProvider(doctorId)),
        data: (data) => _DoctorInfoBody(info: data),
      ),
    );
  }
}

class _DoctorInfoBody extends ConsumerWidget {
  const _DoctorInfoBody({required this.info});

  final DoctorInfo info;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final arabic = context.isArabic;
    final degrees = arabic ? info.degreesAr ?? info.degreesEn : info.degreesEn ?? info.degreesAr;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ContentWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(context.doctorName(info.doctor), style: theme.textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(
                '${info.doctor.displayTitle(arabic: arabic)} · ${info.specialty.displayName(arabic: arabic)}',
                style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              if (degrees != null) ...[const SizedBox(height: 4), Text(degrees, style: theme.textTheme.bodyMedium)],
              const SizedBox(height: 4),
              Text(l10n.fileNumber(info.fileNumber), style: theme.textTheme.bodySmall),
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.folder_shared_outlined),
                label: Text(l10n.thisDoctorsRecords),
                onPressed: () {
                  ref.read(selectedDoctorProvider.notifier).select(info.doctor.id);
                  context.go(PatientRoutes.file());
                },
              ),
              const SizedBox(height: 24),
              Text(l10n.branchesTitle, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              if (info.branches.isEmpty) EmptyState(icon: Icons.store_mall_directory_outlined, message: l10n.noBranches),
              for (final branch in info.branches) ...[
                _BranchCard(branch: branch),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _BranchCard extends StatelessWidget {
  const _BranchCard({required this.branch});

  final BranchInfo branch;

  Future<void> _open(BuildContext context, Future<bool> Function() action) async {
    final messenger = ScaffoldMessenger.of(context);
    final message = context.l10n.couldNotOpen;
    if (!await action()) messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final closed = branch.status == BranchStatus.temporarilyClosed;

    // Group periods by weekday, in the clinic's week order (Saturday first, spec 8).
    const weekOrder = [6, 7, 1, 2, 3, 4, 5];
    final byDay = {for (final d in weekOrder) d: branch.workingHours.where((p) => p.weekday == d).toList()};

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(branch.displayName(arabic: context.isArabic), style: theme.textTheme.titleMedium)),
                if (branch.isDefault) Chip(label: Text(l10n.mainBranch), visualDensity: VisualDensity.compact),
              ],
            ),
            if (closed) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: scheme.errorContainer, borderRadius: BorderRadius.circular(8)),
                child: Text(
                  [
                    l10n.branchTemporarilyClosed,
                    ?branch.closedMessage,
                    if (branch.reopenDate != null) l10n.reopensOn(context.date(branch.reopenDate!)),
                  ].join('\n'),
                  style: TextStyle(color: scheme.onErrorContainer),
                ),
              ),
            ],
            const SizedBox(height: 12),
            // Address → maps.
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.place_outlined),
              title: Text(branch.address.singleLine),
              subtitle: branch.address.landmark == null ? null : Text(branch.address.landmark!),
              trailing: IconButton(
                tooltip: l10n.openInMaps,
                icon: const Icon(Icons.map_outlined),
                onPressed: () => _open(context, () => ContactLauncher.maps(branch.address.mapsQuery)),
              ),
            ),
            // Phones → call / WhatsApp.
            for (final phone in branch.phones)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.call_outlined),
                title: Text(context.localPhone(phone.number), textDirection: TextDirection.ltr),
                subtitle: Text(context.phoneLabel(phone.label)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: l10n.call,
                      icon: const Icon(Icons.phone_forwarded_outlined),
                      onPressed: () => _open(context, () => ContactLauncher.call(phone.number)),
                    ),
                    if (phone.isWhatsapp)
                      IconButton(
                        tooltip: l10n.whatsApp,
                        icon: const Icon(Icons.chat_outlined),
                        onPressed: () => _open(context, () => ContactLauncher.whatsApp(phone.number)),
                      ),
                  ],
                ),
              ),
            const Divider(height: 24),
            Text(l10n.workingHours, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            if (branch.workingHours.isEmpty)
              Text(l10n.workingHoursNotSet, style: TextStyle(color: scheme.onSurfaceVariant))
            else
              for (final entry in byDay.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 110, child: Text(context.weekday(entry.key))),
                      Expanded(
                        child: Text(
                          entry.value.isEmpty
                              ? l10n.closedDay
                              : entry.value
                                  .map((p) => [
                                        l10n.timeRange(context.clock(p.start), context.clock(p.end)),
                                        ?p.label,
                                      ].join(' '))
                                  .join('\n'),
                          style: TextStyle(color: entry.value.isEmpty ? scheme.onSurfaceVariant : null),
                        ),
                      ),
                    ],
                  ),
                ),
            const Divider(height: 24),
            Text(l10n.visitPrices, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            _PriceRow(label: l10n.visitTypeExamination, value: context.price(branch.prices.examinationPiasters)),
            _PriceRow(label: l10n.visitTypeConsultation, value: context.price(branch.prices.consultationPiasters)),
            if (branch.paymentMethods.isNotEmpty || branch.amenities.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final method in branch.paymentMethods)
                    Chip(avatar: const Icon(Icons.payments_outlined, size: 18), label: Text(context.paymentMethod(method))),
                  for (final amenity in branch.amenities)
                    Chip(avatar: const Icon(Icons.check_circle_outline, size: 18), label: Text(context.amenity(amenity))),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [Expanded(child: Text(label)), Text(value, style: Theme.of(context).textTheme.titleSmall)]),
      );
}
