import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/platform/app_platform.dart';
import '../../../../core/theme/motion.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../application/registration_form.dart';
import '../../data/license_picker.dart';
import '../../domain/license_file.dart';
import '../registration_text.dart';
import 'license_preview.dart';

/// A4 step 2: the photo of the syndicate card or license. Phones choose
/// between the camera, their photos and files; desktops open the file
/// dialog. The file is checked (10 MB, JPEG/PNG/WebP/PDF by its bytes)
/// before it is accepted, so a wrong file never reaches the upload.
///
/// On A7 the file already sent is kept unless the doctor replaces it.
class LicenseField extends ConsumerStatefulWidget {
  const LicenseField({super.key, required this.form});

  final RegistrationForm form;

  @override
  ConsumerState<LicenseField> createState() => _LicenseFieldState();
}

class _LicenseFieldState extends ConsumerState<LicenseField> {
  bool _busy = false;

  Future<void> _choose() async {
    if (_busy) return;
    final desktop = ref.read(appPlatformProvider).isDesktop;
    final source = desktop ? LicenseSource.files : await _askSource();
    if (source == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final picked = await ref.read(licensePickerProvider).pick(source);
      if (picked == null) return;
      widget.form.setLicense(await loadLicense(picked));
    } on LicenseFileException catch (error) {
      widget.form.setLicenseError(error.code);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<LicenseSource?> _askSource() {
    final l10n = AppLocalizations.of(context);
    return showModalBottomSheet<LicenseSource>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (source, icon, label) in [
                (LicenseSource.camera, Icons.photo_camera_outlined, l10n.regSourceCamera),
                (LicenseSource.gallery, Icons.photo_library_outlined, l10n.regSourceGallery),
                (LicenseSource.files, Icons.upload_file_outlined, l10n.regSourceFiles),
              ])
                ListTile(
                  minTileHeight: 56,
                  leading: Icon(icon),
                  title: Text(label),
                  onTap: () => Navigator.of(context).pop(source),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final form = widget.form;
    final code = form.errorOf(RegField.license);
    final error = code == null ? null : l10n.regFieldError(RegField.license, code);
    final file = form.license;
    final kept = file == null && form.keptLicenseType != null;

    final Widget content;
    if (file != null || kept) {
      content = Row(
        key: ValueKey(file ?? 'kept'),
        children: [
          if (file != null) LicenseThumbnail(file: file) else SubmittedLicenseThumbnail(contentType: form.keptLicenseType),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file?.name ?? l10n.regLicenseCurrent,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: file == null ? null : TextDirection.ltr,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  file == null
                      ? '${l10n.regLicenseKind(form.keptLicenseType)} · ${l10n.regLicenseKept}'
                      : '${l10n.regLicenseKind(file.contentType)} · ${l10n.regFileSize(file.size)}',
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(onPressed: _busy ? null : _choose, child: Text(l10n.regLicenseReplace)),
          if (file != null && form.resubmit)
            IconButton(
              tooltip: l10n.regLicenseUndo,
              onPressed: form.removeLicense,
              icon: const Icon(Icons.undo),
            ),
        ],
      );
    } else {
      content = Row(
        key: const ValueKey('empty'),
        children: [
          ExcludeSemantics(
            child: DecoratedBox(
              decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(12)),
              child: SizedBox.square(
                dimension: 56,
                child: Icon(Icons.badge_outlined, color: scheme.onPrimaryContainer),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.regLicenseFileLabel, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(l10n.regLicenseFileHint, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _busy
              ? const SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2.5))
              : Icon(Icons.add_circle_outline, color: scheme.primary),
        ],
      );
    }

    final box = AnimatedContainer(
      duration: Motion.fast,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: error != null ? scheme.error : scheme.outline, width: error != null ? 2 : 1),
      ),
      padding: const EdgeInsets.all(12),
      child: AnimatedSwitcher(
        duration: Motion.normal,
        reverseDuration: Motion.normalExit,
        switchInCurve: Motion.enterCurve,
        switchOutCurve: Motion.exitCurveReversed,
        child: content,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (file == null && !kept)
          Semantics(
            button: true,
            label: l10n.regLicenseFileLabel,
            hint: error ?? l10n.regLicenseFileHint,
            excludeSemantics: true,
            onTap: _choose,
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(onTap: _busy ? null : _choose, borderRadius: BorderRadius.circular(16), child: box),
            ),
          )
        else
          box,
        if (error != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 12, top: 6),
            child: Semantics(
              liveRegion: true,
              child: Text(error, style: theme.textTheme.bodySmall?.copyWith(color: scheme.error)),
            ),
          ),
      ],
    );
  }
}
