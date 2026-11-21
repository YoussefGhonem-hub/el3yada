import '../../../core/format/app_format.dart';
import '../../../core/validation/validators.dart';

/// How an AD13 setting is typed and checked. Mirrors `SettingKind` in
/// backend/src/El3yada.Api/Settings/SettingFields.cs.
enum SettingKind {
  /// Piasters on the wire, EGP with up to 2 decimals on screen.
  money,
  integer,
  boolean,
  text,
  email,

  /// Egyptian mobile, landline or 5-digit hotline.
  phone,

  /// Egyptian number or any international E.164 number.
  whatsapp,

  /// `major.minor.patch`, required.
  version,
}

/// The sections of AD13, in screen order.
enum SettingGroup { billing, payment, files, clinics, appVersions, maintenance, support, legal }

/// Why a value typed in AD13 is refused (before it reaches the server).
enum SettingProblem { required, notNumber, outOfRange, tooLong, invalidEmail, invalidPhone, invalidVersion }

/// One AD13 setting, by its `updateSettings` name.
class SettingFieldSpec {
  const SettingFieldSpec(
    this.name,
    this.kind,
    this.group, {
    this.min = 0,
    this.max = 0,
    this.maxLength = 0,
    this.appliesToNewOnly = false,
    this.multiline = false,
    this.rtl,
  });

  final String name;
  final SettingKind kind;
  final SettingGroup group;

  /// Integer and money ranges, in wire units (piasters for money).
  final int min;
  final int max;

  /// Text length limit.
  final int maxLength;

  /// AD13 note: "applies to new sessions/invoices only".
  final bool appliesToNewOnly;
  final bool multiline;

  /// The text's language direction: true for Arabic fields, false for
  /// English ones, null for neutral values (numbers, emails, phones).
  final bool? rtl;

  bool get isNumber => kind == SettingKind.money || kind == SettingKind.integer;

  /// The value as the edit field shows it.
  String display(Object? value) => switch (kind) {
        SettingKind.money => value is int ? AppFormat.egpNumber(value).replaceAll(',', '') : '',
        SettingKind.boolean => '${value == true}',
        _ => value?.toString() ?? '',
      };

  /// The problem with [text], or null when it can be sent.
  SettingProblem? check(String text) {
    final value = text.trim();
    switch (kind) {
      case SettingKind.money:
        if (value.isEmpty) return SettingProblem.required;
        final piasters = AppFormat.parseEgp(value);
        if (piasters == null) return SettingProblem.notNumber;
        return piasters < min || piasters > max ? SettingProblem.outOfRange : null;
      case SettingKind.integer:
        if (value.isEmpty) return SettingProblem.required;
        final number = int.tryParse(Validators.normalizeDigits(value));
        if (number == null) return SettingProblem.notNumber;
        return number < min || number > max ? SettingProblem.outOfRange : null;
      case SettingKind.boolean:
        return null;
      case SettingKind.text:
        return value.length > maxLength ? SettingProblem.tooLong : null;
      case SettingKind.email:
        return value.isEmpty || Validators.isEmail(value) && value.length <= 254 ? null : SettingProblem.invalidEmail;
      case SettingKind.phone:
        return value.isEmpty || isEgyptianPhone(value) ? null : SettingProblem.invalidPhone;
      case SettingKind.whatsapp:
        return value.isEmpty || isEgyptianPhone(value) || _international.hasMatch(_digits(value))
            ? null
            : SettingProblem.invalidPhone;
      case SettingKind.version:
        if (value.isEmpty) return SettingProblem.required;
        return _version.hasMatch(Validators.normalizeDigits(value)) ? null : SettingProblem.invalidVersion;
    }
  }

  /// The value to send for [text] (call [check] first). Empty optional
  /// text is sent as null, which clears it.
  Object? wire(String text) {
    final value = text.trim();
    return switch (kind) {
      SettingKind.money => AppFormat.parseEgp(value),
      SettingKind.integer => int.parse(Validators.normalizeDigits(value)),
      SettingKind.boolean => value == 'true',
      SettingKind.version => Validators.normalizeDigits(value),
      SettingKind.phone || SettingKind.whatsapp => value.isEmpty ? null : Validators.normalizeDigits(value),
      _ => value.isEmpty ? null : value,
    };
  }

  static final _version = RegExp(r'^\d{1,4}\.\d{1,4}\.\d{1,4}$');
  static final _landline = RegExp(r'^0[2-9]\d{7,8}$');
  static final _hotline = RegExp(r'^1\d{4}$');
  static final _international = RegExp(r'^\+[1-9]\d{7,14}$');

  static String _digits(String input) => Validators.normalizeDigits(input).replaceAll(RegExp(r'[\s\-().]'), '');

  /// The API's `EgyptianPhone.Normalize`: a mobile, a landline or a hotline.
  static bool isEgyptianPhone(String input) {
    if (Validators.normalizeEgyptianMobile(input) != null) return true;
    var digits = _digits(input);
    if (digits.startsWith('+20')) {
      digits = '0${digits.substring(3)}';
    } else if (digits.startsWith('0020')) {
      digits = '0${digits.substring(4)}';
    }
    return _landline.hasMatch(digits) || _hotline.hasMatch(digits);
  }
}

/// Every setting the admin can change, in screen order. Keep in step with
/// `SettingFields.All` in the API (names, kinds and ranges).
abstract final class SettingFields {
  static const maxLegalText = 100000;

  static const all = [
    SettingFieldSpec('examFeePiasters', SettingKind.money, SettingGroup.billing, max: 1000000, appliesToNewOnly: true),
    SettingFieldSpec('consultationFeePiasters', SettingKind.money, SettingGroup.billing,
        max: 1000000, appliesToNewOnly: true),
    SettingFieldSpec('gracePeriodDays', SettingKind.integer, SettingGroup.billing, max: 31, appliesToNewOnly: true),
    SettingFieldSpec('maxConsecutiveConsultations', SettingKind.integer, SettingGroup.billing,
        min: 1, max: 5, appliesToNewOnly: true),
    SettingFieldSpec('trialDays', SettingKind.integer, SettingGroup.billing, min: 1, max: 90, appliesToNewOnly: true),
    // Spec 6.17 BR-DEL2: days from a deletion request to the erasure.
    SettingFieldSpec('accountDeletionGraceDays', SettingKind.integer, SettingGroup.clinics, min: 7, max: 90, appliesToNewOnly: true),
    SettingFieldSpec('instapayAddress', SettingKind.text, SettingGroup.payment, maxLength: 200),
    SettingFieldSpec('instapayAccountName', SettingKind.text, SettingGroup.payment, maxLength: 100),
    SettingFieldSpec('instapayInstructionsAr', SettingKind.text, SettingGroup.payment,
        maxLength: 2000, multiline: true, rtl: true),
    SettingFieldSpec('instapayInstructionsEn', SettingKind.text, SettingGroup.payment,
        maxLength: 2000, multiline: true, rtl: false),
    SettingFieldSpec('maxUploadMb', SettingKind.integer, SettingGroup.files, min: 1, max: 200),
    SettingFieldSpec('maxAssistantsPerDoctor', SettingKind.integer, SettingGroup.clinics, max: 50),
    SettingFieldSpec('maxBranchesPerDoctor', SettingKind.integer, SettingGroup.clinics, min: 1, max: 50),
    SettingFieldSpec('minVersionAndroid', SettingKind.version, SettingGroup.appVersions),
    SettingFieldSpec('minVersionIos', SettingKind.version, SettingGroup.appVersions),
    SettingFieldSpec('minVersionWindows', SettingKind.version, SettingGroup.appVersions),
    SettingFieldSpec('minVersionMacos', SettingKind.version, SettingGroup.appVersions),
    SettingFieldSpec('maintenanceEnabled', SettingKind.boolean, SettingGroup.maintenance),
    SettingFieldSpec('maintenanceMessageAr', SettingKind.text, SettingGroup.maintenance,
        maxLength: 500, multiline: true, rtl: true),
    SettingFieldSpec('maintenanceMessageEn', SettingKind.text, SettingGroup.maintenance,
        maxLength: 500, multiline: true, rtl: false),
    SettingFieldSpec('supportPhone', SettingKind.phone, SettingGroup.support),
    SettingFieldSpec('supportWhatsapp', SettingKind.whatsapp, SettingGroup.support),
    SettingFieldSpec('supportEmail', SettingKind.email, SettingGroup.support),
    SettingFieldSpec('termsAr', SettingKind.text, SettingGroup.legal, maxLength: maxLegalText, multiline: true, rtl: true),
    SettingFieldSpec('termsEn', SettingKind.text, SettingGroup.legal,
        maxLength: maxLegalText, multiline: true, rtl: false),
    SettingFieldSpec('privacyAr', SettingKind.text, SettingGroup.legal,
        maxLength: maxLegalText, multiline: true, rtl: true),
    SettingFieldSpec('privacyEn', SettingKind.text, SettingGroup.legal,
        maxLength: maxLegalText, multiline: true, rtl: false),
  ];

  static final byName = {for (final field in all) field.name: field};

  static List<SettingFieldSpec> inGroup(SettingGroup group) => [
        for (final field in all)
          if (field.group == group) field,
      ];
}
