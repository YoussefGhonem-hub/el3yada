import 'package:flutter/material.dart';

import '../../../core/widgets/app_logo.dart';
import '../../../l10n/gen/app_localizations.dart';

/// A1: shown while the saved session is being read.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppLogoMark(),
            const SizedBox(height: 12),
            Text(l10n.appTitle, style: theme.textTheme.headlineMedium),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text(l10n.loading),
          ],
        ),
      ),
    );
  }
}
