import 'package:material_ui/material_ui.dart';

import '../../../../core/validation/egyptian_phone.dart';
import '../../../../core/validation/map_links.dart';
import '../../../../core/validation/validators.dart';
import '../../../../core/widgets/map_link_field.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../application/registration_form.dart';
import '../../domain/doctor_registration.dart';
import '../../domain/reference_lists.dart';
import '../../domain/registration_rules.dart';
import '../registration_text.dart';
import 'license_preview.dart';

/// What A4's review step and A6 show, from the form or from the server.
class SummaryData {
  const SummaryData({
    required this.fullName,
    required this.email,
    required this.phone,
    required this.title,
    required this.specialty,
    required this.extraSpecialties,
    required this.licenseNumber,
    required this.license,
    required this.branchName,
    required this.governorate,
    required this.city,
    required this.addressDetails,
    this.landmark,
    this.mapUrl,
    required this.phones,
    this.examinationPricePiasters,
    this.consultationPricePiasters,
  });

  /// The review step (A4 step 4).
  factory SummaryData.fromForm(RegistrationForm form, String languageCode) {
    String? optional(TextEditingController controller) {
      final value = controller.text.trim();
      return value.isEmpty ? null : value;
    }

    int? price(TextEditingController controller) {
      try {
        return RegistrationRules.parsePrice(controller.text);
      } on FormatException {
        return null;
      }
    }

    final mobile = Validators.normalizeEgyptianMobile(form.phone.text);
    return SummaryData(
      fullName: RegistrationRules.collapseSpaces(form.fullName.text),
      email: form.email.text.trim().toLowerCase(),
      phone: mobile == null ? form.phone.text.trim() : EgyptianPhone.display(mobile),
      title: form.titlePreset?.of(languageCode) ?? form.titleValue,
      specialty: form.specialty?.name(languageCode) ?? '',
      extraSpecialties: [for (final extra in form.extraSpecialties) extra.name(languageCode)],
      licenseNumber: RegistrationRules.normalizeLicenseNumber(form.licenseNumber.text) ?? form.licenseNumber.text.trim(),
      license: form.license != null
          ? LicenseThumbnail(file: form.license, size: 56)
          : SubmittedLicenseThumbnail(contentType: form.keptLicenseType, size: 56),
      branchName: form.branchName.text.trim(),
      governorate: _governorate(form.governorate ?? '', languageCode),
      city: form.city.text.trim(),
      addressDetails: form.addressDetails.text.trim(),
      landmark: optional(form.landmark),
      mapUrl: MapLinks.isGoogleMaps(form.mapUrl.text) ? MapLinks.extract(form.mapUrl.text) : null,
      phones: [
        for (final entry in form.phones)
          BranchPhone(
            number: EgyptianPhone.display(EgyptianPhone.normalize(entry.number.text) ?? entry.number.text.trim()),
            label: entry.label,
            isWhatsapp: entry.isWhatsapp,
          ),
      ],
      examinationPricePiasters: price(form.examinationPrice),
      consultationPricePiasters: price(form.consultationPrice),
    );
  }

  /// A6: the registration as the server has it.
  factory SummaryData.fromView(DoctorRegistration view, String languageCode) {
    final branch = view.branch ?? const RegistrationBranch();
    final title = DoctorTitles.find(view.title);
    return SummaryData(
      fullName: view.fullName,
      email: view.email ?? '',
      phone: view.phone == null ? '' : EgyptianPhone.display(view.phone!),
      title: languageCode == 'ar' ? view.title : (view.titleEn ?? title?.en ?? view.title),
      specialty: view.specialty.name(languageCode),
      extraSpecialties: [for (final extra in view.extraSpecialties) extra.name(languageCode)],
      licenseNumber: view.licenseNumber,
      license: SubmittedLicenseThumbnail(contentType: view.licenseContentType, size: 56),
      branchName: languageCode == 'en' && (branch.nameEn?.isNotEmpty ?? false) ? branch.nameEn! : branch.nameAr,
      governorate: _governorate(branch.governorate, languageCode),
      city: branch.city,
      addressDetails: branch.addressDetails,
      landmark: branch.landmark,
      mapUrl: branch.mapUrl,
      phones: [
        for (final phone in branch.phones) phone.copyWith(number: EgyptianPhone.display(phone.number)),
      ],
      examinationPricePiasters: view.examinationPricePiasters,
      consultationPricePiasters: view.consultationPricePiasters,
    );
  }

  /// Skeleton content while A6 loads.
  static const placeholder = SummaryData(
    fullName: 'سامي عبد الله محمد',
    email: 'doctor@example.com',
    phone: '01012345678',
    title: 'استشاري',
    specialty: 'أطفال وحديثي الولادة',
    extraSpecialties: [],
    licenseNumber: '45678',
    license: SizedBox.square(dimension: 56),
    branchName: 'فرع المعادي',
    governorate: 'القاهرة',
    city: 'المعادي',
    addressDetails: '12 شارع 9، الدور الثالث، شقة 5',
    phones: [BranchPhone(number: '0223581234')],
    examinationPricePiasters: 30000,
    consultationPricePiasters: 15000,
  );

  static String _governorate(String value, String languageCode) => Governorates.find(value)?.of(languageCode) ?? value;

  final String fullName;
  final String email;
  final String phone;
  final String title;
  final String specialty;
  final List<String> extraSpecialties;
  final String licenseNumber;
  final Widget license;
  final String branchName;
  final String governorate;
  final String city;
  final String addressDetails;
  final String? landmark;

  /// A Google Maps link, or null.
  final String? mapUrl;
  final List<BranchPhone> phones;
  final int? examinationPricePiasters;
  final int? consultationPricePiasters;
}

/// The three summary cards (account, professional, branch). With [onEdit]
/// each card has an "Edit" button that returns the step to open (0–2).
/// [columns] 2 puts the branch card beside the other two (wide screens).
class RegistrationSummary extends StatelessWidget {
  const RegistrationSummary({super.key, required this.data, this.onEdit, this.columns = 1});

  final SummaryData data;
  final ValueChanged<int>? onEdit;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final d = data;
    final separator = l10n.regListSeparator;
    final address = [
      d.addressDetails,
      [d.city, d.governorate].where((part) => part.isNotEmpty).join(separator),
    ].where((part) => part.isNotEmpty).join('\n');

    final account = _SummaryCard(
      title: l10n.regStepAccount,
      onEdit: onEdit == null ? null : () => onEdit!(0),
      rows: [
        _Row(l10n.regFullNameLabel, d.fullName),
        _Row(l10n.regEmailLabel, d.email, ltr: true),
        _Row(l10n.regMobileLabel, d.phone, ltr: true),
      ],
    );
    final professional = _SummaryCard(
      title: l10n.regStepProfessional,
      onEdit: onEdit == null ? null : () => onEdit!(1),
      rows: [
        _Row(l10n.regTitleLabel, d.title),
        _Row(l10n.regSpecialtyLabel, d.specialty),
        if (d.extraSpecialties.isNotEmpty) _Row(l10n.regExtraSpecialtiesShort, d.extraSpecialties.join(separator)),
        _Row(l10n.regLicenseNumberLabel, d.licenseNumber, ltr: true),
        _Row(l10n.regLicenseFileShort, null, child: d.license),
      ],
    );
    final branch = _SummaryCard(
      title: l10n.regStepBranch,
      onEdit: onEdit == null ? null : () => onEdit!(2),
      rows: [
        _Row(l10n.regBranchNameLabel, d.branchName),
        _Row(l10n.regAddressLabel, address),
        if (d.landmark != null && d.landmark!.isNotEmpty) _Row(l10n.regLandmarkShort, d.landmark),
        if (d.mapUrl != null)
          _Row(
            l10n.mapLinkShort,
            null,
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: OpenMapLinkButton(url: d.mapUrl),
            ),
          ),
        _Row(l10n.regPhonesLabel, null, child: _Phones(phones: d.phones)),
        _Row(
          l10n.regExaminationPrice,
          d.examinationPricePiasters == null ? l10n.regNotSet : l10n.regPrice(d.examinationPricePiasters!),
        ),
        _Row(
          l10n.regConsultationPrice,
          d.consultationPricePiasters == null ? l10n.regNotSet : l10n.regPrice(d.consultationPricePiasters!),
        ),
      ],
    );

    if (columns > 1) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Column(children: [account, const SizedBox(height: 12), professional])),
          const SizedBox(width: 12),
          Expanded(child: branch),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [account, const SizedBox(height: 12), professional, const SizedBox(height: 12), branch],
    );
  }
}

class _Row {
  const _Row(this.label, this.value, {this.ltr = false, this.child});

  final String label;
  final String? value;
  final bool ltr;
  final Widget? child;
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.title, required this.rows, this.onEdit});

  final String title;
  final List<_Row> rows;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 8, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Row(
                children: [
                  Expanded(child: Semantics(header: true, child: Text(title, style: theme.textTheme.titleMedium))),
                  if (onEdit != null)
                    Semantics(
                      button: true,
                      label: l10n.regEditSection(title),
                      excludeSemantics: true,
                      onTap: onEdit,
                      child: TextButton.icon(
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: Text(l10n.regEdit),
                      ),
                    ),
                ],
              ),
            ),
            for (final row in rows)
              Padding(
                padding: const EdgeInsetsDirectional.only(top: 10, end: 8),
                child: MergeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(row.label, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                      const SizedBox(height: 2),
                      row.child ??
                          Text(
                            row.value == null || row.value!.isEmpty ? '—' : row.value!,
                            textDirection: row.ltr ? TextDirection.ltr : null,
                            style: theme.textTheme.bodyLarge,
                          ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Phones extends StatelessWidget {
  const _Phones({required this.phones});

  final List<BranchPhone> phones;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final phone in phones)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(phone.number, textDirection: TextDirection.ltr, style: theme.textTheme.bodyLarge),
                Text(l10n.regPhoneLabelName(phone.label), style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                if (phone.isWhatsapp)
                  DecoratedBox(
                    decoration: BoxDecoration(color: scheme.secondaryContainer, borderRadius: BorderRadius.circular(8)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      child: Text(
                        l10n.regPhoneWhatsapp,
                        style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSecondaryContainer),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
