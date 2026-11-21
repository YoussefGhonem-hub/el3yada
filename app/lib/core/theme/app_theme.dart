import 'package:material_ui/material_ui.dart';

import 'page_transitions.dart';

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
    required this.onAttention,
    required this.brandAccent,
    required this.navBar,
    required this.onNavBar,
    required this.navIndicator,
    required this.onNavIndicator,
    required this.skeleton,
    required this.skeletonHighlight,
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

  /// Count text on an [attention] badge (5:1 or better).
  final Color onAttention;

  /// The plus in the logo (AppLogoMark).
  final Color brandAccent;

  /// The floating bottom bar: pine in light mode, an elevated surface in dark.
  final Color navBar;

  /// Unselected icons and labels on [navBar] (7:1 light, 5.9:1 dark).
  final Color onNavBar;

  /// The sliding pill behind the selected item (bar, rail and side menu).
  final Color navIndicator;

  /// Icon and label on [navIndicator] (6.2:1).
  final Color onNavIndicator;

  /// Skeleton placeholders and the highlight that sweeps across them.
  final Color skeleton;
  final Color skeletonHighlight;

  static const light = El3yadaColors(
    examination: Color(0xFFD6E4FF),
    onExamination: Color(0xFF0B3D91),
    consultation: Color(0xFFD3F2E1),
    onConsultation: Color(0xFF0B5A33),
    allergy: Color(0xFFFFDAD6),
    onAllergy: Color(0xFF8C1D18),
    attention: AppColors.coral,
    onAttention: AppColors.ink,
    brandAccent: Color(0xFF2BB594),
    navBar: AppColors.pine,
    onNavBar: Color(0xFFBFE3D8),
    navIndicator: AppColors.mint,
    onNavIndicator: AppColors.pine,
    skeleton: Color(0xFFDCEBE4),
    skeletonHighlight: Color(0xFFF2F8F5),
  );

  static const dark = El3yadaColors(
    examination: Color(0xFF1E3A66),
    onExamination: Color(0xFFD6E4FF),
    consultation: Color(0xFF15452E),
    onConsultation: Color(0xFFC2EDD5),
    allergy: Color(0xFF5C1712),
    onAllergy: Color(0xFFFFDAD6),
    attention: Color(0xFFFF8A7D),
    onAttention: AppColors.ink,
    brandAccent: Color(0xFFE3F1EC),
    navBar: Color(0xFF22423C),
    onNavBar: Color(0xFFA5C4BC),
    navIndicator: AppColors.mint,
    onNavIndicator: AppColors.pine,
    skeleton: Color(0xFF1A3833),
    skeletonHighlight: Color(0xFF2A4842),
  );

  /// Dark mode on desktop: graphite surfaces, so green marks only what
  /// matters (the menu, the selection, the main action). The menu keeps a
  /// deep pine; the meaning colours stay as they are.
  static const desktopDark = El3yadaColors(
    examination: Color(0xFF1E3A66),
    onExamination: Color(0xFFD6E4FF),
    consultation: Color(0xFF15452E),
    onConsultation: Color(0xFFC2EDD5),
    allergy: Color(0xFF5C1712),
    onAllergy: Color(0xFFFFDAD6),
    attention: Color(0xFFFF8A7D),
    onAttention: AppColors.ink,
    brandAccent: Color(0xFFE3F1EC),
    navBar: Color(0xFF0E2D28),
    onNavBar: Color(0xFFAFCCC4),
    navIndicator: AppColors.mint,
    onNavIndicator: AppColors.pine,
    skeleton: Color(0xFF232928),
    skeletonHighlight: Color(0xFF2F3634),
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
    Color? onAttention,
    Color? brandAccent,
    Color? navBar,
    Color? onNavBar,
    Color? navIndicator,
    Color? onNavIndicator,
    Color? skeleton,
    Color? skeletonHighlight,
  }) =>
      El3yadaColors(
        examination: examination ?? this.examination,
        onExamination: onExamination ?? this.onExamination,
        consultation: consultation ?? this.consultation,
        onConsultation: onConsultation ?? this.onConsultation,
        allergy: allergy ?? this.allergy,
        onAllergy: onAllergy ?? this.onAllergy,
        attention: attention ?? this.attention,
        onAttention: onAttention ?? this.onAttention,
        brandAccent: brandAccent ?? this.brandAccent,
        navBar: navBar ?? this.navBar,
        onNavBar: onNavBar ?? this.onNavBar,
        navIndicator: navIndicator ?? this.navIndicator,
        onNavIndicator: onNavIndicator ?? this.onNavIndicator,
        skeleton: skeleton ?? this.skeleton,
        skeletonHighlight: skeletonHighlight ?? this.skeletonHighlight,
      );

  @override
  El3yadaColors lerp(El3yadaColors? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return El3yadaColors(
      examination: mix(examination, other.examination),
      onExamination: mix(onExamination, other.onExamination),
      consultation: mix(consultation, other.consultation),
      onConsultation: mix(onConsultation, other.onConsultation),
      allergy: mix(allergy, other.allergy),
      onAllergy: mix(onAllergy, other.onAllergy),
      attention: mix(attention, other.attention),
      onAttention: mix(onAttention, other.onAttention),
      brandAccent: mix(brandAccent, other.brandAccent),
      navBar: mix(navBar, other.navBar),
      onNavBar: mix(onNavBar, other.onNavBar),
      navIndicator: mix(navIndicator, other.navIndicator),
      onNavIndicator: mix(onNavIndicator, other.onNavIndicator),
      skeleton: mix(skeleton, other.skeleton),
      skeletonHighlight: mix(skeletonHighlight, other.skeletonHighlight),
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

  /// Dark mode on desktop (Windows, macOS, Linux): neutral graphite instead
  /// of green-tinted surfaces and text. Mint stays the primary colour, so
  /// green shows up only on actions, the selection and focus.
  static const ColorScheme desktopDarkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: AppColors.mint,
    onPrimary: Color(0xFF06231C),
    primaryContainer: Color(0xFF1C3631),
    onPrimaryContainer: Color(0xFFBFF0E1),
    secondary: Color(0xFF8FD5C4),
    onSecondary: Color(0xFF06231C),
    secondaryContainer: Color(0xFF234640),
    onSecondaryContainer: Color(0xFFC5EDE3),
    tertiary: Color(0xFFFF9A8C),
    onTertiary: Color(0xFF4A100A),
    tertiaryContainer: Color(0xFF5E241D),
    onTertiaryContainer: Color(0xFFFFDAD5),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF8C1D18),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: Color(0xFF141817),
    onSurface: Color(0xFFE7ECEA),
    onSurfaceVariant: Color(0xFFA6B0AD),
    surfaceDim: Color(0xFF141817),
    surfaceBright: Color(0xFF353C3A),
    surfaceContainerLowest: Color(0xFF101413),
    surfaceContainerLow: Color(0xFF1C2120),
    surfaceContainer: Color(0xFF202625),
    surfaceContainerHigh: Color(0xFF272D2C),
    surfaceContainerHighest: Color(0xFF2F3634),
    outline: Color(0xFF7E8A87),
    outlineVariant: Color(0xFF323A38),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFFE7ECEA),
    onInverseSurface: Color(0xFF1C2120),
    inversePrimary: AppColors.pine,
    surfaceTint: AppColors.mint,
  );

  /// Built once: the themes hold callbacks (field colours by state, the
  /// back icon), which never compare equal, so a theme built on every
  /// rebuild would make `MaterialApp` animate between identical themes.
  static ThemeData light() => _light;

  static ThemeData dark() => _dark;

  /// Desktop (Windows, macOS, Linux): a larger type scale for reading at
  /// arm's length, standard density, and graphite surfaces in dark mode.
  /// Chosen in `El3yadaApp` by the platform, never by the window width.
  static ThemeData desktopLight() => _desktopLight;

  static ThemeData desktopDark() => _desktopDark;

  static final ThemeData _light = _build(lightScheme, El3yadaColors.light);
  static final ThemeData _dark = _build(darkScheme, El3yadaColors.dark);
  static final ThemeData _desktopLight = _build(lightScheme, El3yadaColors.light, desktop: true);
  static final ThemeData _desktopDark = _build(desktopDarkScheme, El3yadaColors.desktopDark, desktop: true);

  /// Desktop text uses the system UI font, as Microsoft Teams and Zoom do: Segoe UI on Windows, which covers Arabic.
  /// On macOS, where it isn't installed, Flutter falls back to the system font. Phones and tablets keep Alexandria.
  static const desktopFontFamily = 'Segoe UI';

  /// The desktop type ramp of Fluent 2, Microsoft Teams' design system: 14 px body text (Body 1), 12 px captions,
  /// semibold (600) for titles, buttons and labels, and regular (400) for everything else.
  static const TextTheme desktopTextTheme = TextTheme(
    displayLarge: TextStyle(fontSize: 40, fontWeight: FontWeight.w600),
    displayMedium: TextStyle(fontSize: 32, fontWeight: FontWeight.w600),
    displaySmall: TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
    headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
    headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
    headlineSmall: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
    titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
    titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    bodyLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w400),
    bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
    bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
    labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
    labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
  );

  /// Desktop: the page's canvas, the rounded surface every page sits on, over the app background (as in Teams).
  static Color desktopCanvas(ColorScheme scheme) =>
      scheme.brightness == Brightness.light ? scheme.surfaceContainerLowest : scheme.surfaceContainerLow;

  /// Desktop: a panel that groups cards on the canvas, such as a board column or a filters bar.
  static Color desktopPanel(ColorScheme scheme) => scheme.brightness == Brightness.light
      ? Color.lerp(scheme.surfaceContainerLowest, scheme.surface, 0.6)!
      : scheme.surfaceContainerHigh;

  /// Desktop cards: one step above the canvas, with a hairline border (Fluent cards).
  static Color desktopCard(ColorScheme scheme) =>
      scheme.brightness == Brightness.light ? scheme.surfaceContainerLowest : scheme.surfaceContainerHighest;

  static ThemeData _build(ColorScheme scheme, El3yadaColors colors, {bool desktop = false}) {
    const pill = StadiumBorder();
    // Desktop follows Fluent 2's medium size (Teams, Zoom): 32 px buttons and fields with 6 px corners, made for a
    // mouse. Phones keep 44 dp pills for touch.
    final family = desktop ? desktopFontFamily : fontFamily;
    final field = BorderRadius.circular(desktop ? 6 : 14);
    final OutlinedBorder buttonShape = desktop ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)) : pill;
    final buttonHeight = desktop ? 32.0 : 44.0;
    final tapTarget = desktop ? MaterialTapTargetSize.shrinkWrap : null;
    // Menus, dialogs and sheets sit above the page: in dark mode on desktop
    // they are a lighter graphite, not a darker one.
    final raised = desktop && scheme.brightness == Brightness.dark
        ? scheme.surfaceContainerHigh
        : scheme.surfaceContainerLowest;
    // Alexandria is a wide face, so sizes sit a step below Material's, like
    // Facebook's and LinkedIn's: 15 for body text, 20 for screen titles.
    // Semibold (600) only for headings and titles; body text stays regular.
    // No letter spacing: it breaks Arabic joins.
    const phoneTextTheme = TextTheme(
      displayLarge: TextStyle(fontSize: 44, fontWeight: FontWeight.w600),
      displayMedium: TextStyle(fontSize: 36, fontWeight: FontWeight.w600),
      displaySmall: TextStyle(fontSize: 30, fontWeight: FontWeight.w600),
      headlineLarge: TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
      headlineMedium: TextStyle(fontSize: 23, fontWeight: FontWeight.w600),
      headlineSmall: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
      titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      titleSmall: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500),
      bodyLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w400),
      bodyMedium: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w400),
      bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
      labelLarge: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500),
      labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
    );
    final textTheme = desktop ? desktopTextTheme : phoneTextTheme;
    // Compact buttons, as in Facebook and LinkedIn: 44 dp pills with 14 sp
    // semibold text (taps still get a 48 dp target). Desktop: 32 px, 14 px.
    final buttonText = TextStyle(fontFamily: family, fontSize: 14, fontWeight: FontWeight.w600);
    final buttonPadding = EdgeInsets.symmetric(horizontal: desktop ? 12 : 20);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      fontFamily: family,
      textTheme: textTheme,
      // Sizes are set per component below, so the density stays standard and
      // tests see what Windows shows.
      visualDensity: desktop ? VisualDensity.standard : null,
      materialTapTargetSize: tapTarget,
      extensions: [colors],
      // Flat top bars that sit on the page colour, also when content scrolls
      // under them. Titles are bold and start-aligned.
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: family,
          fontSize: 18,
          height: 1.3,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
      // Every automatic Back (screens outside the role areas) uses the same
      // rounded arrow as AppBackButton; it mirrors in Arabic.
      actionIconTheme: ActionIconThemeData(
        backButtonIconBuilder: (context) => const Icon(Icons.arrow_back_rounded),
      ),
      // Desktop cards sit on the page canvas: one step above it, with a hairline border, as Fluent cards do.
      cardTheme: CardThemeData(
        color: desktop ? desktopCard(scheme) : scheme.surfaceContainerLow,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: desktop
            ? RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: scheme.outlineVariant),
              )
            : RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: Size(64, buttonHeight),
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: buttonText,
          iconSize: desktop ? 16 : 18,
          tapTargetSize: tapTarget,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: Size(64, buttonHeight),
          padding: buttonPadding,
          shape: buttonShape,
          side: desktop ? BorderSide(color: scheme.outline) : BorderSide(color: scheme.primary, width: 1.2),
          foregroundColor: desktop ? scheme.onSurface : null,
          textStyle: buttonText,
          iconSize: desktop ? 16 : 18,
          tapTargetSize: tapTarget,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: Size(48, desktop ? 32 : 40),
          padding: EdgeInsets.symmetric(horizontal: desktop ? 8 : 12),
          shape: buttonShape,
          textStyle: buttonText.copyWith(fontWeight: desktop ? FontWeight.w600 : FontWeight.w500),
          iconSize: desktop ? 16 : 18,
          tapTargetSize: tapTarget,
        ),
      ),
      // Desktop icon buttons: 32 px squares with 20 px icons, as in Teams' toolbars.
      iconButtonTheme: desktop
          ? IconButtonThemeData(
              style: IconButton.styleFrom(
                minimumSize: const Size(32, 32),
                padding: const EdgeInsets.all(6),
                iconSize: 20,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            )
          : null,
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          minimumSize: Size(48, desktop ? 32 : 40),
          textStyle: buttonText.copyWith(fontWeight: desktop ? FontWeight.w400 : FontWeight.w500),
          tapTargetSize: tapTarget,
          shape: desktop ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)) : null,
        ),
      ),
      // Desktop lists, tabs, chips and check boxes: Fluent's denser rows.
      listTileTheme: desktop
          ? const ListTileThemeData(
              visualDensity: VisualDensity.compact,
              contentPadding: EdgeInsets.symmetric(horizontal: 12),
              minLeadingWidth: 24,
              horizontalTitleGap: 12,
            )
          : null,
      tabBarTheme: desktop
          ? TabBarThemeData(
              labelStyle: TextStyle(fontFamily: family, fontSize: 14, fontWeight: FontWeight.w600),
              unselectedLabelStyle: TextStyle(fontFamily: family, fontSize: 14, fontWeight: FontWeight.w400),
            )
          : null,
      checkboxTheme: desktop
          ? const CheckboxThemeData(
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            )
          : null,
      radioTheme: desktop
          ? const RadioThemeData(
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            )
          : null,
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
        highlightElevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      // Desktop fields are about 36 px tall (Fluent's medium field with a floating label).
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        isDense: true,
        contentPadding: desktop
            ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
            : const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        // Icons in desktop fields don't force the 48 px touch size, so a field with a search icon stays 36 px.
        prefixIconConstraints: desktop ? const BoxConstraints(minWidth: 36, minHeight: 32) : null,
        suffixIconConstraints: desktop ? const BoxConstraints(minWidth: 36, minHeight: 32) : null,
        border: OutlineInputBorder(borderRadius: field),
        enabledBorder: OutlineInputBorder(
          borderRadius: field,
          borderSide: BorderSide(color: scheme.outline, width: desktop ? 1 : 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: field,
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        // The field's icons turn brand colour while it has focus.
        prefixIconColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.focused) ? scheme.primary : scheme.onSurfaceVariant,
        ),
        floatingLabelStyle: WidgetStateTextStyle.resolveWith(
          (states) => TextStyle(
            fontWeight: FontWeight.w500,
            color: states.contains(WidgetState.error)
                ? scheme.error
                : states.contains(WidgetState.focused)
                    ? scheme.primary
                    : scheme.onSurfaceVariant,
          ),
        ),
      ),
      chipTheme: desktop
          ? ChipThemeData(
              // A hairline border, so action chips read as buttons on the canvas (Fluent).
              shape: const StadiumBorder(),
              side: BorderSide(color: scheme.outlineVariant),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              // A label style replaces the chip's default, so it carries its colour for every state.
              labelStyle: TextStyle(
                fontFamily: family,
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: WidgetStateColor.resolveWith(
                  (states) => states.contains(WidgetState.disabled)
                      ? scheme.onSurface.withValues(alpha: 0.38)
                      : states.contains(WidgetState.selected)
                          ? scheme.onSecondaryContainer
                          : scheme.onSurface,
                ),
              ),
            )
          : ChipThemeData(shape: const StadiumBorder(), side: BorderSide.none),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(desktop ? 8 : 16)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: raised,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: raised,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(desktop ? 12 : 28)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: raised,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(desktop ? 8 : 16)),
        textStyle: desktop ? TextStyle(fontFamily: family, fontSize: 14, color: scheme.onSurface) : null,
      ),
      // Drop-down menus (the branch picker) on desktop: rounded, like the
      // popup menus.
      menuTheme: desktop
          ? MenuThemeData(
              style: MenuStyle(
                backgroundColor: WidgetStatePropertyAll(raised),
                surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
                shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 8)),
              ),
            )
          : null,
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: scheme.inverseSurface, borderRadius: BorderRadius.circular(desktop ? 6 : 10)),
        textStyle: TextStyle(fontFamily: family, color: scheme.onInverseSurface, fontSize: 12),
        // With a mouse, tooltips wait for the pointer to rest.
        waitDuration: desktop ? const Duration(milliseconds: 400) : null,
      ),
      // Thin rounded scrollbars on desktop, where they always show.
      scrollbarTheme: desktop
          ? ScrollbarThemeData(
              thickness: const WidgetStatePropertyAll(6),
              radius: const Radius.circular(3),
              thumbColor: WidgetStatePropertyAll(scheme.onSurfaceVariant.withValues(alpha: 0.35)),
            )
          : null,
      // Forward and back: horizontal shared axis, mirrored in Arabic.
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          for (final platform in TargetPlatform.values) platform: const AppPageTransitionsBuilder(),
        },
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
