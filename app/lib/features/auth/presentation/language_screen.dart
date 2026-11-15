import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/app_settings.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/staggered_entrance.dart';
import '../../../l10n/gen/app_localizations.dart';

/// A2: the language choice, once, on first launch. Pre-selected from the
/// device language (Arabic when the device uses neither). Picking an option
/// previews the whole screen in that language; Continue saves it.
class LanguageScreen extends ConsumerStatefulWidget {
  const LanguageScreen({super.key});

  @override
  ConsumerState<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends ConsumerState<LanguageScreen> {
  late String _selected = ref.read(appSettingsProvider).locale.languageCode;

  void _select(String code) {
    setState(() => _selected = code);
    // Preview: the app switches language (and direction) at once.
    ref.read(appSettingsProvider.notifier).setLocaleForPreview(Locale(code));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: StaggerGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const StaggeredEntrance(index: 0, child: Center(child: AppLogoMark(size: 64))),
                    const SizedBox(height: 24),
                    StaggeredEntrance(
                      index: 1,
                      child: Semantics(
                        header: true,
                        child: Text(l10n.languageTitle, textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
                      ),
                    ),
                    const SizedBox(height: 8),
                    StaggeredEntrance(
                      index: 2,
                      child: Text(
                        l10n.languageBody,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
                    const SizedBox(height: 32),
                    StaggeredEntrance(
                      index: 3,
                      child: _LanguageOption(
                        label: 'العربية',
                        sample: 'أهلاً بك في العيادة',
                        textDirection: TextDirection.rtl,
                        selected: _selected == 'ar',
                        onTap: () => _select('ar'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    StaggeredEntrance(
                      index: 4,
                      child: _LanguageOption(
                        label: 'English',
                        sample: 'Welcome to el3yada',
                        textDirection: TextDirection.ltr,
                        selected: _selected == 'en',
                        onTap: () => _select('en'),
                      ),
                    ),
                    const SizedBox(height: 32),
                    StaggeredEntrance(
                      index: 5,
                      child: FilledButton(
                        onPressed: () => ref.read(appSettingsProvider.notifier).chooseLanguage(Locale(_selected)),
                        child: Text(l10n.continueButton),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.label,
    required this.sample,
    required this.textDirection,
    required this.selected,
    required this.onTap,
  });

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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: selected ? scheme.primaryContainer : scheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? scheme.primary : scheme.outlineVariant, width: selected ? 2 : 1),
          ),
          child: Row(
            children: [
              Expanded(
                // Each option is written in its own language and direction,
                // whatever the screen's language is right now.
                child: Directionality(
                  textDirection: textDirection,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: theme.textTheme.titleLarge),
                      Text(sample, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ),
              Icon(selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: selected ? scheme.primary : scheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}
