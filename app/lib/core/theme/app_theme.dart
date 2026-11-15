import 'package:flutter/material.dart';

/// Brand colours from the chosen design ("queue ticket": pine and mint).
/// Widgets never use these directly: they read `Theme.of(context).colorScheme`
/// or [El3yadaColors], so light and dark come from one set of tokens
/// (spec section 12, Appearance).
abstract final class AppColors {
  /// Primary brand colour (buttons, selected items, the logo's ع).
  static const pine = Color(0xFF0F4C45);

  /// Light page background behind white cards.
  static const mintGround = Color(0xFFE6F2EC);

  /// Accent on pine surfaces: live dots, progress, the selected nav item.
  static const mint = Color(0xFF7CE0C3);

  /// Small "new" and attention marks. Never used for text on white.
  static const coral = Color(0xFFFF6B5A);

  /// Main text colour on light surfaces.
  static const ink = Color(0xFF12312C);
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
    required this.attention,
    required this.brandAccent,
  });

  /// Examination badge (كشف): always blue (spec section 12).
  final Color examination;
  final Color onExamination;

  /// Consultation badge (استشارة): always green.
  final Color consultation;
  final Color onConsultation;

  /// Allergy warnings: always red.
  final Color allergy;
  final Color onAllergy;

  /// Dot for unread or new items. Pair it with a label or count, never alone.
  final Color attention;

  /// The plus in the logo (AppLogoMark).
  final Color brandAccent;

  static const light = El3yadaColors(
    examination: Color(0xFFD6E4FF),
    onExamination: Color(0xFF0B3D91),
    consultation: Color(0xFFD3F2E1),
    onConsultation: Color(0xFF0B5A33),
    allergy: Color(0xFFFFDAD6),
    onAllergy: Color(0xFF8C1D18),
    attention: AppColors.coral,
    brandAccent: Color(0xFF2BB594),
  );

  static const dark = El3yadaColors(
    examination: Color(0xFF1E3A66),
    onExamination: Color(0xFFD6E4FF),
    consultation: Color(0xFF15452E),
    onConsultation: Color(0xFFC2EDD5),
    allergy: Color(0xFF5C1712),
    onAllergy: Color(0xFFFFDAD6),
    attention: Color(0xFFFF8A7D),
    brandAccent: Color(0xFFE3F1EC),
  );

  @override
  El3yadaColors copyWith({
    Color? examination,
    Color? onExamination,
    Color? consultation,
    Color? onConsultation,
    Color? allergy,
    Color? onAllergy,
    Color? attention,
    Color? brandAccent,
  }) =>
      El3yadaColors(
        examination: examination ?? this.examination,
        onExamination: onExamination ?? this.onExamination,
        consultation: consultation ?? this.consultation,
        onConsultation: onConsultation ?? this.onConsultation,
        allergy: allergy ?? this.allergy,
        onAllergy: onAllergy ?? this.onAllergy,
        attention: attention ?? this.attention,
        brandAccent: brandAccent ?? this.brandAccent,
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
      attention: Color.lerp(attention, other.attention, t)!,
      brandAccent: Color.lerp(brandAccent, other.brandAccent, t)!,
    );
  }
}

extension El3yadaThemeX on BuildContext {
  El3yadaColors get el3yadaColors => Theme.of(this).extension<El3yadaColors>()!;
}

abstract final class AppTheme {
  /// Bundled in pubspec.yaml (assets/fonts). Covers Arabic and Latin.
  static const String fontFamily = 'Alexandria';

  /// Every text colour pair below meets WCAG AA (4.5:1) on its surface.
  static const ColorScheme lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.pine,
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFCFE7DF),
    onPrimaryContainer: Color(0xFF0A3530),
    secondary: Color(0xFF1F7A6C),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: AppColors.mint,
    onSecondaryContainer: Color(0xFF06231C),
    tertiary: Color(0xFFB0402F),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFFFE3DF),
    onTertiaryContainer: Color(0xFF9E2A1C),
    error: Color(0xFFBA1A1A),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF93000A),
    surface: AppColors.mintGround,
    onSurface: AppColors.ink,
    onSurfaceVariant: Color(0xFF4C6964),
    surfaceDim: Color(0xFFD5E5DD),
    surfaceBright: Color(0xFFF2F8F5),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFFFFFFF),
    surfaceContainer: Color(0xFFF4FAF7),
    surfaceContainerHigh: Color(0xFFDCEBE4),
    surfaceContainerHighest: Color(0xFFD2E4DC),
    outline: Color(0xFF6F8C86),
    outlineVariant: Color(0xFFC9DED5),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: AppColors.ink,
    onInverseSurface: Color(0xFFE3F1EC),
    inversePrimary: AppColors.mint,
    surfaceTint: AppColors.pine,
  );

  static const ColorScheme darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: AppColors.mint,
    onPrimary: Color(0xFF06231C),
    primaryContainer: Color(0xFF12403A),
    onPrimaryContainer: Color(0xFFBFF0E1),
    secondary: Color(0xFF8FD5C4),
    onSecondary: Color(0xFF06231C),
    secondaryContainer: Color(0xFF1F4A43),
    onSecondaryContainer: Color(0xFFC5EDE3),
    tertiary: Color(0xFFFF9A8C),
    onTertiary: Color(0xFF4A100A),
    tertiaryContainer: Color(0xFF6B1E15),
    onTertiaryContainer: Color(0xFFFFDAD5),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: Color(0xFF0B1F1C),
    onSurface: Color(0xFFE3F1EC),
    onSurfaceVariant: Color(0xFFA5C4BC),
    surfaceDim: Color(0xFF0B1F1C),
    surfaceBright: Color(0xFF2A4842),
    surfaceContainerLowest: Color(0xFF071613),
    surfaceContainerLow: Color(0xFF102824),
    surfaceContainer: Color(0xFF132E2A),
    surfaceContainerHigh: Color(0xFF1A3833),
    surfaceContainerHighest: Color(0xFF22423C),
    outline: Color(0xFF6E8F88),
    outlineVariant: Color(0xFF2C4B45),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFFE3F1EC),
    onInverseSurface: AppColors.ink,
    inversePrimary: AppColors.pine,
    surfaceTint: AppColors.mint,
  );

  static ThemeData light() => _build(lightScheme, El3yadaColors.light);

  static ThemeData dark() => _build(darkScheme, El3yadaColors.dark);

  static ThemeData _build(ColorScheme scheme, El3yadaColors colors) {
    final rounded16 = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      fontFamily: fontFamily,
      extensions: [colors],
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: const Size(64, 52), shape: rounded16),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: rounded16,
          side: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      chipTheme: ChipThemeData(shape: const StadiumBorder(), side: BorderSide.none),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: scheme.secondaryContainer,
        backgroundColor: scheme.surfaceContainerLow,
      ),
      navigationRailTheme: NavigationRailThemeData(
        indicatorColor: scheme.secondaryContainer,
        backgroundColor: scheme.surfaceContainerLow,
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
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
