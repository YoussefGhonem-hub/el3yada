
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/app_settings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/motion.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/brand_backdrop.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/staggered_entrance.dart';
import '../../../l10n/gen/app_localizations.dart';

/// A2: the language choice, once, on first launch. Pre-selected from the
/// device language (Arabic when the device uses neither). Picking an option
/// previews the whole screen in that language; Continue saves it.
///
/// On the brand backdrop the logo writes itself above a bilingual welcome,
/// then the white sheet with the two choices springs up.
class LanguageScreen extends ConsumerStatefulWidget {
  const LanguageScreen({super.key});

  @override
  ConsumerState<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends ConsumerState<LanguageScreen> with SingleTickerProviderStateMixin {
  late String _selected = ref.read(appSettingsProvider).locale.languageCode;
  // The sheet rises while the logo is still finishing (the first 350 ms wait).
  late final AnimationController _sheet = AnimationController(vsync: this, duration: const Duration(milliseconds: 1250));
  static const Curve _rise = Interval(0.28, 1, curve: SpringCurve(bounce: 0.15));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_sheet.isDismissed) return;
    if (Motion.of(context).reduced) {
      _sheet.value = 1;
    } else {
      _sheet.forward();
    }
  }

  @override
  void dispose() {
    _sheet.dispose();
    super.dispose();
  }

  void _select(String code) {
    setState(() => _selected = code);
    // Preview: the app switches language (and direction) at once.
    ref.read(appSettingsProvider.notifier).setLocaleForPreview(Locale(code));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final insets = MediaQuery.paddingOf(context);

    final sheet = Container(
      constraints: const BoxConstraints(maxWidth: 560),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 40, offset: const Offset(0, -6))],
      ),
      padding: EdgeInsets.fromLTRB(24, 28, 24, 24 + insets.bottom),
      child: StaggerGroup(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StaggeredEntrance(
              index: 0,
              child: Semantics(
                header: true,
                child: Text(l10n.languageTitle, style: theme.textTheme.headlineSmall),
              ),
            ),
            const SizedBox(height: 6),
            StaggeredEntrance(
              index: 1,
              child: Text(
                l10n.languageBody,
                style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 24),
            StaggeredEntrance(
              index: 2,
              child: _LanguageOption(
                monogram: 'ع',
                label: 'العربية',
                sample: 'أهلاً بك في العيادة',
                textDirection: TextDirection.rtl,
                selected: _selected == 'ar',
                onTap: () => _select('ar'),
              ),
            ),
            const SizedBox(height: 12),
            StaggeredEntrance(
              index: 3,
              child: _LanguageOption(
                monogram: 'En',
                label: 'English',
                sample: 'Welcome to el3yada',
                textDirection: TextDirection.ltr,
                selected: _selected == 'en',
                onTap: () => _select('en'),
              ),
            ),
            const SizedBox(height: 28),
            StaggeredEntrance(
              index: 4,
              child: FilledButton(
                onPressed: () => ref.read(appSettingsProvider.notifier).chooseLanguage(Locale(_selected)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l10n.continueButton),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, size: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return Scaffold(
      backgroundColor: BrandBackdrop.colorsFor(theme.brightness)[1],
      body: BrandBackdrop(
        child: Column(
          children: [
            Expanded(
              child: SafeArea(
                bottom: false,
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const BrandMedallion(
                            child: AppLogoMark(
                              size: 92,
                              animate: true,
                              beat: true,
                              letterColor: Colors.white,
                              plusColor: AppColors.mint,
                            ),
                          ),
                          const SizedBox(height: 20),
                          // The welcome in both languages, whatever is selected.
                          Text(
                            'أهلاً بك',
                            textDirection: TextDirection.rtl,
                            style: theme.textTheme.headlineMedium?.copyWith(color: Colors.white),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Welcome',
                            textDirection: TextDirection.ltr,
                            style: theme.textTheme.titleLarge?.copyWith(color: AppColors.mint, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _sheet,
              builder: (context, child) {
                final t = _rise.transform(_sheet.value);
                return Transform.translate(
                  offset: Offset(0, (1 - t) * 420),
                  child: Opacity(opacity: (t * 3).clamp(0.0, 1.0), child: child),
                );
              },
              child: Center(child: sheet),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.monogram,
    required this.label,
    required this.sample,
    required this.textDirection,
    required this.selected,
    required this.onTap,
  });

  final String monogram;
  final String label;
  final String sample;
  final TextDirection textDirection;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      child: Pressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: Motion.normal,
          curve: Motion.enterCurve,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? scheme.primaryContainer.withValues(alpha: 0.55) : scheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: selected ? scheme.primary : scheme.outlineVariant, width: selected ? 2 : 1.2),
            boxShadow: [
              if (selected)
                BoxShadow(color: scheme.primary.withValues(alpha: 0.14), blurRadius: 18, offset: const Offset(0, 6)),
            ],
          ),
          // Each option is written in its own language and direction,
          // whatever the screen's language is right now.
          child: Directionality(
            textDirection: textDirection,
            child: Row(
              children: [
                AnimatedContainer(
                  duration: Motion.normal,
                  curve: Motion.enterCurve,
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? scheme.primary : scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    monogram,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: selected ? scheme.onPrimary : scheme.primary,
                      height: 1.1,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(sample, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _Check(selected: selected),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A ring that fills and pops a check when its option is selected.
class _Check extends StatelessWidget {
  const _Check({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reduced = Motion.of(context).reduced;
    return AnimatedContainer(
      duration: Motion.normal,
      curve: Motion.enterCurve,
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? scheme.primary : Colors.transparent,
        border: Border.all(color: selected ? scheme.primary : scheme.outline, width: 2),
      ),
      child: AnimatedSwitcher(
        duration: Motion.slow,
        switchInCurve: reduced ? Motion.enterCurve : Motion.springBouncy,
        transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
        child: selected
            ? Icon(Icons.check_rounded, key: const ValueKey(true), size: 18, color: scheme.onPrimary)
            : const SizedBox.shrink(key: ValueKey(false)),
      ),
    );
  }
}
