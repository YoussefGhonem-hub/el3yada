import 'package:intl/intl.dart';

import '../../../core/network/api_error_text.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../application/registration_form.dart';
import '../domain/doctor_registration.dart';
import '../domain/license_file.dart';

/// A4–A7 texts that depend on the field as well as the code.
extension RegistrationText on AppLocalizations {
  /// The message for [code] on the field [key] (a [RegField]).
  String regFieldError(String key, String code) {
    if (key.startsWith(RegField.phones) && code == 'INVALID_VALUE') return regErrorPhoneRequired;
    return switch ((key, code)) {
      (RegField.title, RegErrors.required) => regErrorTitleRequired,
      (RegField.specialty, RegErrors.required) => regErrorSpecialtyRequired,
      (RegField.licenseNumber, RegErrors.required) => regErrorLicenseNumberRequired,
      (RegField.license, RegErrors.required) => regErrorLicenseRequired,
      (RegField.governorate, RegErrors.required) => regErrorGovernorateRequired,
      (RegField.branchName, RegErrors.invalidValue) => regErrorBranchName,
      (RegField.examinationPrice || RegField.consultationPrice, _) => regErrorPrice,
      (_, RegErrors.passwordsDontMatch) => errorPasswordsDontMatch,
      (_, LicenseFileException.pickFailed) => regErrorPickFailed,
      _ => fieldError(code) ?? errorUnknown,
    };
  }

  String regPhoneLabelName(String label) => switch (label) {
        BranchPhone.mobile => regPhoneTypeMobile,
        BranchPhone.landline => regPhoneTypeLandline,
        _ => regPhoneTypeReception,
      };

  /// `EGP 300` / `300 ج.م`, Western digits in both languages (spec 12).
  String regPrice(int piasters) {
    final amount = NumberFormat(piasters % 100 == 0 ? '#,##0' : '#,##0.00', 'en').format(piasters / 100);
    return regPriceValue(amount);
  }

  /// `850 KB`, `2.4 MB`.
  String regFileSize(int bytes) {
    if (bytes < 1024 * 1024) return regFileSizeKb((bytes / 1024).ceil());
    return regFileSizeMb(NumberFormat('0.0', 'en').format(bytes / (1024 * 1024)));
  }

  String regLicenseKind(String? contentType) =>
      LicenseFile.isImageType(contentType) ? regLicenseImage : regLicensePdf;
}

/// Keeps an email or number left-to-right inside an Arabic sentence
/// (Unicode LRI … PDI), so its dots and signs stay where they belong.
String ltrIsolate(String text) => '\u2066$text\u2069';
