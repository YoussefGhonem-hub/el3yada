import 'package:flutter/material.dart';

/// Colour tokens (spec section 12, Appearance). Widgets never use hard-coded
/// colours: they read `Theme.of(context).colorScheme` or [El3yadaColors].
abstract final class AppColors {
  static const brandSeed = Color(0xFF0B5C8E);
}

/// Colours that carry meaning, each with a light and a dark version.
@immutable
class El3yadaColors extends ThemeExtension<El3yadaColors> {
  const El3yadaColors({
    required this.examination,
    required this.onExamination,
    required this.consultation,
    required this.onConsultation,
    required this.allergy,
    required this.onAllergy,
  });

  /// Examination badge (كشف).
  final Color examination;
  final Color onExamination;

  /// Consultation badge (استشارة).
  final Color consultation;
  final Color onConsultation;

  /// Allergy warnings.
  final Color allergy;
  final Color onAllergy;

  static const light = El3yadaColors(
    examination: Color(0xFFD6E4FF),
    onExamination: Color(0xFF0B3D91),
    consultation: Color(0xFFD3F2E1),
    onConsultation: Color(0xFF0B5A33),
    allergy: Color(0xFFFFDAD6),
    onAllergy: Color(0xFF8C1D18),
  );

  static const dark = El3yadaColors(
    examination: Color(0xFF1E3A66),
    onExamination: Color(0xFFD6E4FF),
    consultation: Color(0xFF15452E),
    onConsultation: Color(0xFFC2EDD5),
    allergy: Color(0xFF5C1712),
    onAllergy: Color(0xFFFFDAD6),
  );

  @override
  El3yadaColors copyWith({
    Color? examination,
    Color? onExamination,
    Color? consultation,
    Color? onConsultation,
    Color? allergy,
    Color? onAllergy,
  }) =>
      El3yadaColors(
        examination: examination ?? this.examination,
        onExamination: onExamination ?? this.onExamination,
        consultation: consultation ?? this.consultation,
        onConsultation: onConsultation ?? this.onConsultation,
        allergy: allergy ?? this.allergy,
        onAllergy: onAllergy ?? this.onAllergy,
      );

  @override
  El3yadaColors lerp(El3yadaColors? other, double t) {
    if (other == null) return this;
    return El3yadaColors(
      examination: Color.lerp(examination, other.examination, t)!,
      onExamination: Color.lerp(onExamination, other.onExamination, t)!,
      consultation: Color.lerp(consultation, other.consultation, t)!,
      onConsultation: Color.lerp(onConsultation, other.onConsultation, t)!,
      allergy: Color.lerp(allergy, other.allergy, t)!,
      onAllergy: Color.lerp(onAllergy, other.onAllergy, t)!,
    );
  }
}

extension El3yadaThemeX on BuildContext {
  El3yadaColors get el3yadaColors => Theme.of(this).extension<El3yadaColors>()!;
}

abstract final class AppTheme {
  /// Set to 'IBM Plex Sans Arabic' once the font files are bundled (pubspec.yaml).
  static const String? fontFamily = null;

  static ThemeData light() => _build(Brightness.light, El3yadaColors.light);

  static ThemeData dark() => _build(Brightness.dark, El3yadaColors.dark);

  static ThemeData _build(Brightness brightness, El3yadaColors colors) {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.brandSeed,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
      extensions: [colors],
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    );
  }
}

/// Layout breakpoints (spec section 4).
abstract final class Breakpoints {
  /// Below this: phone layout with a bottom navigation bar.
  static const double tablet = 600;

  /// From this width up: desktop layout with a side menu.
  static const double desktop = 1024;
}
