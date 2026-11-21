import 'package:material_ui/material_ui.dart';

import '../../../../core/format/app_format.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../domain/branch_models.dart';
import '../widgets/clinic_admin_widgets.dart';
import 'branch_text.dart';

// AS17: an assistant with `scheduleManage` edits the schedule tabs of D29,
// and reads the Info, Address and Contact tabs (only the doctor changes them,
// BR-AS5).

/// «Only the doctor can change this», over a read-only tab.
class DoctorOnlyNote extends StatelessWidget {
  const DoctorOnlyNote({super.key});

  @override
  Widget build(BuildContext context) =>
      InfoBanner(icon: Icons.lock_outline, tone: PillTone.neutral, message: AppLocalizations.of(context).branchDoctorOnlyNote);
}

class _Facts extends StatelessWidget {
  const _Facts({required this.icon, required this.title, required this.rows});

  final IconData icon;
  final String title;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) => SectionCard(
        icon: icon,
        title: title,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, row) in rows.indexed) ...[if (i > 0) const SizedBox(height: 14), row],
          ],
        ),
      );
}

class BranchInfoReadOnly extends StatelessWidget {
  const BranchInfoReadOnly({super.key, required this.details});

  final BranchDetails details;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final info = details.info;
    return _Facts(
      icon: Icons.storefront_outlined,
      title: l10n.branchTabInfo,
      rows: [
        InfoRow(label: l10n.regBranchNameLabel, value: info.nameAr),
        InfoRow(label: l10n.adminFieldBranchNameEn, value: info.nameEn),
        InfoRow(label: l10n.branchDescription, value: info.description),
        InfoRow(label: l10n.branchStatusTitle, child: Align(alignment: AlignmentDirectional.centerStart, child: BranchStatusPill(status: details.status))),
        if (details.temporarilyClosed && details.closedMessage != null) InfoRow(label: l10n.branchPatientsSee, value: details.closedMessage),
      ],
    );
  }
}

class BranchAddressReadOnly extends StatelessWidget {
  const BranchAddressReadOnly({super.key, required this.address});

  final BranchAddress address;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _Facts(
      icon: Icons.map_outlined,
      title: l10n.branchTabAddress,
      rows: [
        InfoRow(label: l10n.regGovernorateLabel, value: address.governorate),
        InfoRow(label: l10n.regCityLabel, value: address.city),
        InfoRow(label: l10n.branchAreaLabel, value: address.area),
        InfoRow(label: l10n.addressDetailsLabel, value: address.details.isEmpty ? null : address.details),
        InfoRow(label: l10n.regLandmarkLabel, value: address.landmark),
        InfoRow(label: l10n.mapLinkLabel, value: address.mapUrl, ltr: true),
      ],
    );
  }
}

class BranchContactReadOnly extends StatelessWidget {
  const BranchContactReadOnly({super.key, required this.contact});

  final BranchContact contact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _Facts(
      icon: Icons.call_outlined,
      title: l10n.branchTabContact,
      rows: [
        for (final (i, phone) in contact.phones.indexed)
          InfoRow(
            label: [l10n.regPhoneLabel(i + 1), l10n.phoneLabelName(phone.label), if (phone.isWhatsapp) l10n.regPhoneWhatsapp].join(l10n.regListSeparator),
            value: AppFormat.phone(phone.number),
            ltr: true,
          ),
        InfoRow(label: l10n.branchEmailLabel, value: contact.email, ltr: true),
      ],
    );
  }
}
