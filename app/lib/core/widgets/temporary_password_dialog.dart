import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/gen/app_localizations.dart';
import '../format/app_format.dart';
import '../theme/motion.dart';

/// The temporary password of a new or reset account, shown **once** (BR-P4,
/// BR-P5, BR-AS2), with Share via WhatsApp, Share via SMS and Copy. The
/// person must set their own password at first sign-in (A9).
///
/// The dialog can't be dismissed by tapping outside, so the password isn't
/// lost by accident; Done closes it.
Future<void> showTemporaryPasswordDialog(
  BuildContext context, {
  required String name,
  required String phone,
  required String password,
  String? title,
}) =>
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => TemporaryPasswordDialog(name: name, phone: phone, password: password, title: title),
    );

class TemporaryPasswordDialog extends StatefulWidget {
  const TemporaryPasswordDialog({
    super.key,
    required this.name,
    required this.phone,
    required this.password,
    this.title,
  });

  final String name;

  /// E.164 (`+201012345678`): where WhatsApp and SMS send it.
  final String phone;
  final String password;
  final String? title;

  @override
  State<TemporaryPasswordDialog> createState() => _TemporaryPasswordDialogState();
}

class _TemporaryPasswordDialogState extends State<TemporaryPasswordDialog> {
  bool _copied = false;

  String _message(AppLocalizations l10n) => l10n.tempPasswordMessage(AppFormat.phone(widget.phone), widget.password);

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.password));
    if (mounted) setState(() => _copied = true);
  }

  /// wa.me wants the international number without `+`.
  Future<void> _whatsApp(AppLocalizations l10n) => _open(Uri.parse(
      'https://wa.me/${widget.phone.replaceAll(RegExp(r'[^0-9]'), '')}?text=${Uri.encodeComponent(_message(l10n))}'));

  Future<void> _sms(AppLocalizations l10n) =>
      _open(Uri(scheme: 'sms', path: widget.phone, queryParameters: {'body': _message(l10n)}));

  Future<void> _open(Uri uri) async {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) => false);
    if (!opened && mounted) {
      // No WhatsApp or SMS app (desktop): copy the whole message instead.
      final l10n = AppLocalizations.of(context);
      await Clipboard.setData(ClipboardData(text: _message(l10n)));
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(l10n.tempPasswordMessageCopied)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final motion = Motion.of(context);
    return AlertDialog(
      icon: const Icon(Icons.key_outlined),
      title: Text(widget.title ?? l10n.tempPasswordTitle),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.tempPasswordBody(widget.name)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      widget.password,
                      textDirection: TextDirection.ltr,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(letterSpacing: 2, fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.tempPasswordCopy,
                    onPressed: _copy,
                    icon: AnimatedSwitcher(
                      duration: motion.reduced ? Duration.zero : Motion.fast,
                      child: Icon(_copied ? Icons.check : Icons.copy_outlined, key: ValueKey(_copied)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            AnimatedOpacity(
              opacity: _copied ? 1 : 0,
              duration: motion.reduced ? Duration.zero : Motion.fast,
              child: Text(l10n.tempPasswordCopied, textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _whatsApp(l10n),
                    icon: const Icon(Icons.chat_outlined),
                    label: Text(l10n.tempPasswordShareWhatsApp),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _sms(l10n),
                    icon: const Icon(Icons.sms_outlined),
                    label: Text(l10n.tempPasswordShareSms),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.done)),
      ],
    );
  }
}
