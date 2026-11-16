import 'package:flutter/widgets.dart';

import '../../../core/validation/egyptian_phone.dart';
import '../../../core/validation/map_links.dart';
import '../../../core/validation/validators.dart';
import '../domain/doctor_registration.dart';
import '../domain/license_file.dart';
import '../domain/reference_lists.dart';
import '../domain/registration_rules.dart';
import '../domain/specialty.dart';

/// Field keys: the API's JSON paths, so a server error (`errorCodes`) lands
/// on the same field as the app's own check.
abstract final class RegField {
  static const fullName = 'fullName';
  static const email = 'email';
  static const phone = 'phone';
  static const password = 'password';

  /// App only: the API never sees the confirmation.
  static const confirmPassword = 'confirmPassword';
  static const title = 'title';
  static const specialty = 'specialtyId';
  static const extraSpecialties = 'extraSpecialtyIds';
  static const licenseNumber = 'licenseNumber';
  static const license = 'license';
  static const branchName = 'branch.nameAr';
  static const governorate = 'branch.governorate';
  static const city = 'branch.city';
  static const addressDetails = 'branch.addressDetails';
  static const landmark = 'branch.landmark';
  static const mapUrl = 'branch.mapUrl';
  static const phones = 'branch.phones';
  static String phoneNumber(int index) => 'branch.phones[$index].number';
  static const examinationPrice = 'examinationPricePiasters';
  static const consultationPrice = 'consultationPricePiasters';
  static const acceptTerms = 'acceptTerms';

  /// The A4 step (0–3) that shows [key]. Keys no step shows (`data`,
  /// `device.*`) belong to the review step, which shows them as a message.
  static int stepOf(String key) {
    if (const {fullName, email, phone, password, confirmPassword, 'locale'}.contains(key)) return 0;
    if (key.startsWith('branch') || key == examinationPrice || key == consultationPrice) return 2;
    if (key == title ||
        key.startsWith('titleEn') ||
        key.startsWith(specialty) ||
        key.startsWith(extraSpecialties) ||
        key == licenseNumber ||
        key == license ||
        const {'fullNameEn', 'degreesAr', 'degreesEn'}.contains(key)) {
      return 1;
    }
    return 3;
  }

  /// Keys the review step can't show next to a field.
  static bool isUnplaced(String key) => stepOf(key) == 3 && key != acceptTerms;
}

/// App-only error codes (the others are the API's field codes).
abstract final class RegErrors {
  static const required = 'REQUIRED';
  static const tooLong = 'TOO_LONG';
  static const invalidValue = 'INVALID_VALUE';
  static const passwordsDontMatch = 'PASSWORDS_DONT_MATCH';
  static const invalidAmount = 'INVALID_AMOUNT';
  static const invalidMapLink = 'INVALID_MAP_LINK';
}

/// One branch phone row in step 3.
class PhoneEntry {
  PhoneEntry({String number = '', this.label = BranchPhone.reception, this.isWhatsapp = false})
      : number = TextEditingController(text: number);

  final TextEditingController number;
  String label;
  bool isWhatsapp;

  /// Keeps each row's state when one above it is removed.
  final Key key = UniqueKey();
}

/// Everything typed and chosen in A4, kept while the user moves between the
/// steps (Back never loses data). [resubmit] is A7 "Edit and resubmit": no
/// password, no Terms, and the license is optional (kept unless replaced).
///
/// Errors are kept per field key ([RegField]) as codes; the screen turns
/// them into ARB messages. Editing a field clears its error.
class RegistrationForm extends ChangeNotifier {
  RegistrationForm({this.resubmit = false}) {
    for (final (controller, key) in [
      (fullName, RegField.fullName),
      (email, RegField.email),
      (phone, RegField.phone),
      (password, RegField.password),
      (confirmPassword, RegField.confirmPassword),
      (titleText, RegField.title),
      (licenseNumber, RegField.licenseNumber),
      (branchName, RegField.branchName),
      (city, RegField.city),
      (addressDetails, RegField.addressDetails),
      (landmark, RegField.landmark),
      (mapUrl, RegField.mapUrl),
      (examinationPrice, RegField.examinationPrice),
      (consultationPrice, RegField.consultationPrice),
    ]) {
      _clearOnEdit(controller, () => key);
    }
    _addPhoneEntry(PhoneEntry());
  }

  final bool resubmit;

  // Step 1, account.
  final fullName = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  final password = TextEditingController();
  final confirmPassword = TextEditingController();

  // Step 2, professional.
  BilingualName? titlePreset;
  bool otherTitle = false;
  final titleText = TextEditingController();
  Specialty? specialty;
  List<Specialty> extraSpecialties = const [];
  final licenseNumber = TextEditingController();

  /// A newly chosen file.
  LicenseFile? license;

  /// A7: the type of the file already on the server, kept unless replaced.
  String? keptLicenseType;

  // Step 3, first branch and visit prices.
  final branchName = TextEditingController();

  /// The Arabic name from [Governorates], or a value the API already had.
  String? governorate;
  final city = TextEditingController();

  /// «العنوان بالتفصيل»: street, building, floor and apartment in one text.
  final addressDetails = TextEditingController();
  final landmark = TextEditingController();

  /// «لينك جوجل ماب», optional.
  final mapUrl = TextEditingController();
  final List<PhoneEntry> phones = [];
  final examinationPrice = TextEditingController();
  final consultationPrice = TextEditingController();

  // Step 4.
  bool acceptTerms = false;

  // Fields the form doesn't show, sent back unchanged on resubmit.
  String? _loadedTitle;
  String? _loadedTitleEn;
  String? _fullNameEn;
  String? _degreesAr;
  String? _degreesEn;
  RegistrationBranch _loadedBranch = const RegistrationBranch();

  Map<String, String> _errors = const {};

  /// Error codes by field key.
  Map<String, String> get errors => _errors;

  String? errorOf(String key) => _errors[key];

  bool get hasLicense => license != null || keptLicenseType != null;

  /// The `title` to send: the chosen preset (Arabic) or the typed text.
  String get titleValue => titlePreset?.ar ?? (otherTitle ? RegistrationRules.collapseSpaces(titleText.text) : '');

  /// `titleEn`: the preset's English name, or what the API had when the
  /// title is unchanged.
  String? get titleEnValue {
    if (_loadedTitleEn != null && titleValue == _loadedTitle) return _loadedTitleEn;
    return titlePreset?.en;
  }

  // ---------------------------------------------------------------------------
  // Changes

  void selectTitle(BilingualName preset) {
    titlePreset = preset;
    otherTitle = false;
    _clear(RegField.title);
  }

  void selectOtherTitle() {
    titlePreset = null;
    otherTitle = true;
    _clear(RegField.title);
  }

  void setSpecialty(Specialty value) {
    specialty = value;
    extraSpecialties = [for (final extra in extraSpecialties) if (extra.id != value.id) extra];
    _clear(RegField.specialty);
  }

  void addExtraSpecialty(Specialty value) {
    if (extraSpecialties.length >= RegistrationRules.maxExtraSpecialties || value.id == specialty?.id) return;
    if (extraSpecialties.any((extra) => extra.id == value.id)) return;
    extraSpecialties = [...extraSpecialties, value];
    _clear(RegField.extraSpecialties);
  }

  void removeExtraSpecialty(Specialty value) {
    extraSpecialties = [for (final extra in extraSpecialties) if (extra.id != value.id) extra];
    _clear(RegField.extraSpecialties);
  }

  void setLicense(LicenseFile file) {
    license = file;
    _clear(RegField.license);
  }

  /// A license problem found by the app (too large, wrong type).
  void setLicenseError(String code) => setErrors({..._errors, RegField.license: code});

  void removeLicense() {
    license = null;
    notifyListeners();
  }

  void setGovernorate(String value) {
    governorate = value;
    _clear(RegField.governorate);
  }

  void addPhone() {
    if (phones.length >= RegistrationRules.maxPhones) return;
    _addPhoneEntry(PhoneEntry());
    _clear(RegField.phones);
  }

  void removePhone(PhoneEntry entry) {
    if (phones.length <= 1) return;
    phones.remove(entry);
    entry.number.dispose();
    // Indices moved: drop the per-row errors rather than show them on the wrong row.
    _errors = {
      for (final error in _errors.entries)
        if (!error.key.startsWith('${RegField.phones}[')) error.key: error.value,
    };
    notifyListeners();
  }

  void setPhoneLabel(PhoneEntry entry, String label) {
    entry.label = label;
    notifyListeners();
  }

  void setPhoneWhatsapp(PhoneEntry entry, bool value) {
    entry.isWhatsapp = value;
    notifyListeners();
  }

  void setAcceptTerms(bool value) {
    acceptTerms = value;
    _clear(RegField.acceptTerms);
  }

  void setErrors(Map<String, String> errors, {bool reveal = false}) {
    _errors = Map.unmodifiable(errors);
    if (reveal) pendingReveal = true;
    notifyListeners();
  }

  /// Set with [setErrors]: the step showing the first error scrolls it into
  /// view once, then clears this.
  bool pendingReveal = false;

  /// Forces listeners to rebuild (a step re-reading the form).
  void touch() => notifyListeners();

  // ---------------------------------------------------------------------------
  // Validation (spec section 11)

  /// The errors of [step] (0–3), by field key. Empty when the step is valid.
  Map<String, String> validateStep(int step) {
    final errors = <String, String>{};
    void check(String key, String? code) {
      if (code != null) errors[key] = code;
    }

    String? requiredText(TextEditingController controller, {int? max, bool Function(String value)? valid, String? invalid}) {
      final value = controller.text.trim();
      if (value.isEmpty) return RegErrors.required;
      if (max != null && value.length > max) return RegErrors.tooLong;
      if (valid != null && !valid(value)) return invalid;
      return null;
    }

    String? optionalText(TextEditingController controller, int max) =>
        controller.text.trim().length > max ? RegErrors.tooLong : null;

    switch (step) {
      case 0:
        check(RegField.fullName, requiredText(fullName, valid: RegistrationRules.isFullName, invalid: 'INVALID_NAME'));
        check(
          RegField.email,
          requiredText(
            email,
            valid: (value) => value.length <= RegistrationRules.maxEmailLength && Validators.isEmail(value),
            invalid: 'INVALID_EMAIL',
          ),
        );
        check(
          RegField.phone,
          requiredText(phone, valid: (value) => Validators.normalizeEgyptianMobile(value) != null, invalid: 'INVALID_MOBILE'),
        );
        if (!resubmit) {
          check(
            RegField.password,
            password.text.isEmpty
                ? RegErrors.required
                : PasswordRules.isStrong(password.text)
                    ? null
                    : 'WEAK_PASSWORD',
          );
          check(
            RegField.confirmPassword,
            confirmPassword.text.isEmpty
                ? RegErrors.required
                : confirmPassword.text == password.text
                    ? null
                    : RegErrors.passwordsDontMatch,
          );
        }
      case 1:
        if (titlePreset == null) {
          check(
            RegField.title,
            otherTitle ? requiredText(titleText, max: RegistrationRules.maxTitleLength) : RegErrors.required,
          );
        }
        if (specialty == null) errors[RegField.specialty] = RegErrors.required;
        check(
          RegField.licenseNumber,
          requiredText(
            licenseNumber,
            valid: (value) => RegistrationRules.normalizeLicenseNumber(value) != null,
            invalid: 'INVALID_LICENSE_NUMBER',
          ),
        );
        if (!hasLicense) errors[RegField.license] = RegErrors.required;
      case 2:
        final limits = RegistrationRules.branchMaxLength;
        final name = branchName.text.trim();
        check(
          RegField.branchName,
          name.isEmpty
              ? RegErrors.required
              : name.length < 2 || name.length > limits['nameAr']!
                  ? RegErrors.invalidValue
                  : null,
        );
        if (governorate == null || governorate!.trim().isEmpty) errors[RegField.governorate] = RegErrors.required;
        check(RegField.city, requiredText(city, max: limits['city']));
        check(RegField.addressDetails, requiredText(addressDetails, max: limits['addressDetails']));
        check(RegField.landmark, optionalText(landmark, limits['landmark']!));
        // What is sent: just the link, when the pasted text has words around it.
        final link = MapLinks.extract(mapUrl.text);
        check(
          RegField.mapUrl,
          link.length > limits['mapUrl']!
              ? RegErrors.tooLong
              : link.isNotEmpty && !MapLinks.isGoogleMaps(link)
                  ? RegErrors.invalidMapLink
                  : null,
        );
        for (final (index, entry) in phones.indexed) {
          check(
            RegField.phoneNumber(index),
            requiredText(entry.number, valid: (value) => EgyptianPhone.normalize(value) != null, invalid: 'INVALID_PHONE'),
          );
        }
        for (final (key, controller) in [
          (RegField.examinationPrice, examinationPrice),
          (RegField.consultationPrice, consultationPrice),
        ]) {
          try {
            RegistrationRules.parsePrice(controller.text);
          } on FormatException {
            errors[key] = RegErrors.invalidAmount;
          }
        }
      case 3:
        if (!resubmit && !acceptTerms) errors[RegField.acceptTerms] = 'TERMS_NOT_ACCEPTED';
    }
    return errors;
  }

  /// Every step's errors together.
  Map<String, String> validateAll() => {for (var step = 0; step < 4; step++) ...validateStep(step)};

  /// The first step (0–3) with an error, or null.
  int? firstStepWithError() {
    if (_errors.isEmpty) return null;
    return _errors.keys.map(RegField.stepOf).reduce((a, b) => a < b ? a : b);
  }

  // ---------------------------------------------------------------------------
  // To and from the API

  /// The request body. Call after [validateAll] found no errors.
  RegistrationData toData({required String locale, Map<String, dynamic>? device}) {
    String? optional(TextEditingController controller) {
      final value = controller.text.trim();
      return value.isEmpty ? null : value;
    }

    // Just the link, when the pasted text has words around it.
    final mapLink = MapLinks.extract(mapUrl.text);

    return RegistrationData(
      fullName: RegistrationRules.collapseSpaces(fullName.text),
      email: email.text.trim().toLowerCase(),
      phone: Validators.normalizeEgyptianMobile(phone.text) ?? phone.text.trim(),
      password: resubmit ? null : password.text,
      locale: locale,
      title: titleValue,
      titleEn: titleEnValue,
      specialtyId: specialty!.id,
      extraSpecialtyIds: [for (final extra in extraSpecialties) extra.id],
      licenseNumber: RegistrationRules.normalizeLicenseNumber(licenseNumber.text) ?? licenseNumber.text.trim(),
      fullNameEn: _fullNameEn,
      degreesAr: _degreesAr,
      degreesEn: _degreesEn,
      examinationPricePiasters: RegistrationRules.parsePrice(examinationPrice.text),
      consultationPricePiasters: RegistrationRules.parsePrice(consultationPrice.text),
      branch: _loadedBranch.copyWith(
        id: null,
        nameAr: branchName.text.trim(),
        governorate: governorate!.trim(),
        city: city.text.trim(),
        addressDetails: addressDetails.text.trim(),
        landmark: optional(landmark),
        mapUrl: mapLink.isEmpty ? null : mapLink,
        phones: [
          for (final entry in phones)
            BranchPhone(
              number: EgyptianPhone.normalize(entry.number.text) ?? entry.number.text.trim(),
              label: entry.label,
              isWhatsapp: entry.isWhatsapp,
            ),
        ],
      ),
      acceptTerms: resubmit ? null : acceptTerms,
      device: resubmit ? null : device,
    );
  }

  /// A7: fills the form with what the doctor submitted before.
  void prefill(DoctorRegistration view) {
    fullName.text = view.fullName;
    email.text = view.email ?? '';
    phone.text = view.phone == null ? '' : EgyptianPhone.display(view.phone!);

    _loadedTitle = view.title;
    _loadedTitleEn = view.titleEn;
    titlePreset = DoctorTitles.find(view.title);
    otherTitle = titlePreset == null && view.title.trim().isNotEmpty;
    titleText.text = otherTitle ? view.title : '';
    specialty = view.specialty;
    extraSpecialties = [for (final extra in view.extraSpecialties) if (extra.id != view.specialty.id) extra];
    licenseNumber.text = view.licenseNumber;
    keptLicenseType = view.licenseContentType ?? LicenseFile.jpeg;
    _fullNameEn = view.fullNameEn;
    _degreesAr = view.degreesAr;
    _degreesEn = view.degreesEn;

    final branch = view.branch ?? const RegistrationBranch();
    _loadedBranch = branch;
    branchName.text = branch.nameAr;
    governorate = branch.governorate.trim().isEmpty ? null : (Governorates.find(branch.governorate)?.ar ?? branch.governorate);
    city.text = branch.city;
    addressDetails.text = branch.addressDetails;
    landmark.text = branch.landmark ?? '';
    mapUrl.text = branch.mapUrl ?? '';
    for (final entry in phones) {
      entry.number.dispose();
    }
    phones.clear();
    for (final phone in branch.phones.take(RegistrationRules.maxPhones)) {
      _addPhoneEntry(PhoneEntry(number: EgyptianPhone.display(phone.number), label: phone.label, isWhatsapp: phone.isWhatsapp));
    }
    if (phones.isEmpty) _addPhoneEntry(PhoneEntry());
    examinationPrice.text = view.examinationPricePiasters == null
        ? ''
        : RegistrationRules.formatPriceInput(view.examinationPricePiasters!);
    consultationPrice.text = view.consultationPricePiasters == null
        ? ''
        : RegistrationRules.formatPriceInput(view.consultationPricePiasters!);
    _errors = const {};
    notifyListeners();
  }

  // ---------------------------------------------------------------------------

  void _addPhoneEntry(PhoneEntry entry) {
    phones.add(entry);
    _clearOnEdit(entry.number, () => RegField.phoneNumber(phones.indexOf(entry)));
  }

  void _clearOnEdit(TextEditingController controller, String Function() key) {
    var last = controller.text;
    controller.addListener(() {
      if (controller.text == last) return; // selection or focus only
      last = controller.text;
      final field = key();
      // Typing a phone number also clears "add at least one number".
      final stale = {field, if (field.startsWith(RegField.phones)) RegField.phones};
      if (stale.any(_errors.containsKey)) {
        _errors = {
          for (final error in _errors.entries)
            if (!stale.contains(error.key)) error.key: error.value,
        };
        notifyListeners();
      }
    });
  }

  void _clear(String key) {
    if (_errors.containsKey(key)) {
      _errors = {
        for (final error in _errors.entries)
          if (error.key != key) error.key: error.value,
      };
    }
    notifyListeners();
  }

  @override
  void dispose() {
    for (final controller in [
      fullName,
      email,
      phone,
      password,
      confirmPassword,
      titleText,
      licenseNumber,
      branchName,
      city,
      addressDetails,
      landmark,
      mapUrl,
      examinationPrice,
      consultationPrice,
      for (final entry in phones) entry.number,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }
}
