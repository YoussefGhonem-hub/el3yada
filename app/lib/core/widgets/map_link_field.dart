import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/gen/app_localizations.dart';
import '../platform/external_links.dart';
import '../validation/map_links.dart';

/// «لينك جوجل ماب»: a pasted Google Maps link, with "Open in Google Maps"
/// to check it. Used by D29's Address tab and A4 step 3.
class MapLinkField extends StatelessWidget {
  const MapLinkField({super.key, required this.controller, this.errorText, this.enabled = true, this.fieldKey});

  final TextEditingController controller;
  final String? errorText;
  final bool enabled;

  /// The key of the text field itself (tests find it by this).
  final Key? fieldKey;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final link = value.text.trim();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: fieldKey,
              controller: controller,
              enabled: enabled,
              keyboardType: TextInputType.url,
              textDirection: TextDirection.ltr,
              autocorrect: false,
              enableSuggestions: false,
              inputFormatters: const [MapLinkFormatter()],
              decoration: InputDecoration(
                labelText: l10n.mapLinkLabel,
                hintText: 'https://maps.app.goo.gl/…',
                hintTextDirection: TextDirection.ltr,
                helperText: l10n.mapLinkHelp,
                helperMaxLines: 3,
                errorText: errorText,
                errorMaxLines: 3,
                prefixIcon: const Icon(Icons.link),
                suffixIcon: enabled && value.text.isNotEmpty
                    ? IconButton(tooltip: l10n.mapLinkClear, onPressed: controller.clear, icon: const Icon(Icons.close))
                    : null,
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: OpenMapLinkButton(url: MapLinks.isGoogleMaps(link) ? link : null),
            ),
          ],
        );
      },
    );
  }
}

/// "Open in Google Maps" for [url]; disabled while [url] is null. Says so
/// when no app could open it.
class OpenMapLinkButton extends ConsumerWidget {
  const OpenMapLinkButton({super.key, required this.url});

  final String? url;

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final uri = Uri.tryParse(url!);
    final opened = uri != null && await ref.read(externalLinkOpenerProvider)(uri);
    if (!opened && context.mounted) {
      final messenger = ScaffoldMessenger.maybeOf(context);
      final scheme = Theme.of(context).colorScheme;
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(AppLocalizations.of(context).mapLinkOpenFailed),
          behavior: SnackBarBehavior.floating,
          backgroundColor: scheme.error,
        ));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => OutlinedButton.icon(
        onPressed: url == null ? null : () => _open(context, ref),
        icon: const Icon(Icons.map_outlined),
        label: Text(AppLocalizations.of(context).mapLinkOpen),
      );
}

/// Keeps only the link when the text has words around it (a pasted share
/// text such as «Clinic name https://maps.app.goo.gl/…»).
class MapLinkFormatter extends TextInputFormatter {
  const MapLinkFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text;
    if (!MapLinks.hasLink(text)) return newValue;
    final link = MapLinks.extract(text);
    if (link == text) return newValue;
    return TextEditingValue(text: link, selection: TextSelection.collapsed(offset: link.length));
  }
}
