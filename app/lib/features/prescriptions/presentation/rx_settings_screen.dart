import 'dart:async';
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error_text.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/save_bar.dart';
import '../../../core/widgets/skeleton_loading.dart';
import '../../../core/widgets/state_switcher.dart';
import '../../../core/widgets/submit_button.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../clinic_admin/clinic_admin_routes.dart';
import '../../clinic_admin/presentation/widgets/clinic_admin_widgets.dart' show ClinicPage;
import '../../patients/presentation/widgets/clinic_ui.dart';
import '../application/prescriptions_providers.dart';
import '../application/rx_pdf_source.dart';
import '../application/rx_printer.dart';
import '../data/prescriptions_repository.dart';
import '../domain/prescription_models.dart';
import '../pdf/rx_pdf.dart';

/// D22 «رأس الروشتة والطباعة»: logo and signature, clinic colour,
/// prescription language, paper (A5, A4, custom [S]), pre-printed paper
/// with its margins, footer text, a live preview and a test print. Doctor
/// only. The names come from the D22 profile, the branches from D28.
class RxSettingsScreen extends ConsumerWidget {
  const RxSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        body: AsyncStateSwitcher<RxSettings>(
          value: ref.watch(rxSettingsProvider),
          loading: (context) => const SkeletonLoading(loading: true, child: SizedBox.expand()),
          error: (context, error) => AdminErrorView(error: error, onRetry: () => ref.invalidate(rxSettingsProvider)),
          data: (context, settings) => _RxSettingsForm(key: ValueKey(settings.updatedAt), saved: settings),
        ),
      );
}

/// The clinic colours offered as swatches; any `#RRGGBB` can be typed too.
const rxColorSwatches = ['#0F4C45', '#0B5C8E', '#1F3A68', '#5B2A86', '#7A1F2B', '#8A4B12', '#2E6B30', '#1A1A1A'];

class _RxSettingsForm extends ConsumerStatefulWidget {
  const _RxSettingsForm({super.key, required this.saved});

  final RxSettings saved;

  @override
  ConsumerState<_RxSettingsForm> createState() => _RxSettingsFormState();
}

class _RxSettingsFormState extends ConsumerState<_RxSettingsForm> {
  late RxSettings _draft = widget.saved;
  late final _hex = TextEditingController(text: widget.saved.accentColor);
  late final _width = TextEditingController(text: _mm(widget.saved.customWidthMm));
  late final _height = TextEditingController(text: _mm(widget.saved.customHeightMm));
  late final _top = TextEditingController(text: _mm(widget.saved.marginTopMm));
  late final _bottom = TextEditingController(text: _mm(widget.saved.marginBottomMm));
  late final _footer = TextEditingController(text: widget.saved.footerText);
  SubmitStatus _status = SubmitStatus.idle;
  String? _error;
  int _failures = 0;
  Map<String, String> _fieldErrors = const {};
  RxImageKind? _uploading;

  /// The live preview, rebuilt a moment after the last change.
  Uint8List? _preview;
  bool _previewFailed = false;
  Timer? _previewTimer;
  int _previewRequest = 0;

  static String _mm(double? value) => value == null ? '' : (value == value.roundToDouble() ? '${value.toInt()}' : '$value');

  @override
  void initState() {
    super.initState();
    _schedulePreview();
  }

  @override
  void dispose() {
    _previewTimer?.cancel();
    for (final c in [_hex, _width, _height, _top, _bottom, _footer]) {
      c.dispose();
    }
    super.dispose();
  }

  int get _dirty {
    final a = _draft;
    final b = widget.saved;
    return [
      a.language != b.language,
      a.accentColor.toUpperCase() != b.accentColor.toUpperCase(),
      a.paperSize != b.paperSize,
      a.customWidthMm != b.customWidthMm,
      a.customHeightMm != b.customHeightMm,
      a.preprinted != b.preprinted,
      a.marginTopMm != b.marginTopMm,
      a.marginBottomMm != b.marginBottomMm,
      (a.footerText ?? '') != (b.footerText ?? ''),
    ].where((changed) => changed).length;
  }

  void _change(RxSettings settings) {
    setState(() {
      _draft = settings;
      _fieldErrors = const {};
      _error = null;
    });
    _schedulePreview();
  }

  double? _number(TextEditingController controller) => double.tryParse(controller.text.trim().replaceAll(',', '.'));

  void _schedulePreview() {
    _previewTimer?.cancel();
    _previewTimer = Timer(const Duration(milliseconds: 450), _buildPreview);
  }

  Future<void> _buildPreview() async {
    final request = ++_previewRequest;
    final settings = _draft.copyWith(hasLogo: widget.saved.hasLogo, hasSignature: widget.saved.hasSignature);
    try {
      final source = ref.read(rxPdfSourceProvider);
      final data = await source.sample(settings, l10n: lookupAppLocalizations(Locale(settings.english ? 'en' : 'ar')));
      final pdf = await buildRxPdf(data, await RxPdfFonts.load());
      if (!mounted || request != _previewRequest) return;
      setState(() {
        _preview = pdf;
        _previewFailed = false;
      });
    } on Object {
      if (!mounted || request != _previewRequest) return;
      setState(() => _previewFailed = true);
    }
  }

  Future<void> _testPrint() async {
    final l10n = AppLocalizations.of(context);
    final pdf = _preview;
    if (pdf == null) return;
    try {
      await ref.read(rxPrinterProvider).print(pdf, name: 'el3yada-test-print');
    } on Object {
      if (mounted) showAdminSnack(context, l10n.rxPrintFailed, error: true);
    }
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _status = SubmitStatus.loading;
      _error = null;
      _fieldErrors = const {};
    });
    try {
      await ref.read(prescriptionsRepositoryProvider).updateRxSettings(_draft);
      if (!mounted) return;
      setState(() => _status = SubmitStatus.success);
      showAdminSnack(context, l10n.rxSettingsSaved);
      rxSettingsChanged(ref);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _status = SubmitStatus.idle;
        _failures++;
        _fieldErrors = {
          for (final MapEntry(:key, :value) in error.fieldCodes.entries) key: l10n.fieldError(value) ?? l10n.apiError(error),
        };
        _error = l10n.apiError(error);
      });
    }
  }

  void _discard() {
    final saved = widget.saved;
    _hex.text = saved.accentColor;
    _width.text = _mm(saved.customWidthMm);
    _height.text = _mm(saved.customHeightMm);
    _top.text = _mm(saved.marginTopMm);
    _bottom.text = _mm(saved.marginBottomMm);
    _footer.text = saved.footerText ?? '';
    _change(saved);
  }

  /// D22 logo or signature: picked, shrunk on the device (≤ 1000 px, PNG),
  /// then the server re-encodes it the same way.
  Future<void> _pickImage(RxImageKind kind) async {
    final l10n = AppLocalizations.of(context);
    final file = await openFile(acceptedTypeGroups: [
      XTypeGroup(label: l10n.rxImagesGroup, extensions: const ['jpg', 'jpeg', 'png', 'webp'], mimeTypes: const ['image/*']),
    ]);
    if (file == null || !mounted) return;
    setState(() => _uploading = kind);
    try {
      final bytes = await shrinkImage(await file.readAsBytes());
      await ref.read(prescriptionsRepositoryProvider).uploadRxImage(kind, bytes, 'image.png');
      if (!mounted) return;
      rxSettingsChanged(ref);
    } on ApiException catch (error) {
      if (mounted) showAdminSnack(context, l10n.apiError(error), error: true);
    } on Object {
      if (mounted) showAdminSnack(context, l10n.regErrorFileContent, error: true);
    } finally {
      if (mounted) setState(() => _uploading = null);
    }
  }

  Future<void> _removeImage(RxImageKind kind) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _uploading = kind);
    try {
      await ref.read(prescriptionsRepositoryProvider).deleteRxImage(kind);
      if (mounted) rxSettingsChanged(ref);
    } on ApiException catch (error) {
      if (mounted) showAdminSnack(context, l10n.apiError(error), error: true);
    } finally {
      if (mounted) setState(() => _uploading = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dirty = _dirty;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Column(
      children: [
        Expanded(
          child: ClinicPage(
            maxWidth: 1180,
            bottomBarVisible: dirty > 0,
            builder: (context, width) {
              final wide = width >= 900;
              final header = ClinicHeader(
                title: l10n.rxSettingsTitle,
                subtitle: l10n.rxSettingsSubtitle,
                backFallback: ClinicAdminRoutes.doctorSettings,
              );
              final form = _form(context);
              final preview = _previewCard(context, wide: wide);
              if (!wide) return [header, const SizedBox(height: 16), ...form, const SizedBox(height: 16), preview];
              return [
                header,
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: form)),
                    const SizedBox(width: 24),
                    SizedBox(width: 420, child: preview),
                  ],
                ),
              ];
            },
          ),
        ),
        SaveBar(
          visible: dirty > 0,
          dirty: dirty,
          status: _status,
          error: _error,
          failures: _failures,
          bottomInset: bottom,
          onDiscard: _discard,
          onSave: _save,
        ),
      ],
    );
  }

  List<Widget> _form(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final draft = _draft;
    const gap = SizedBox(height: 16);
    return [
      SectionCard(
        title: l10n.rxSettingsHeaderGroup,
        icon: Icons.badge_outlined,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.rxSettingsNamesHint, style: theme.textTheme.bodySmall),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final kind in RxImageKind.values)
                  _ImageTile(
                    kind: kind,
                    present: kind == RxImageKind.logo ? widget.saved.hasLogo : widget.saved.hasSignature,
                    busy: _uploading == kind,
                    onPick: () => _pickImage(kind),
                    onRemove: () => _removeImage(kind),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text(l10n.rxSettingsColor, style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final hex in rxColorSwatches)
                  _Swatch(
                    hex: hex,
                    selected: draft.accentColor.toUpperCase() == hex,
                    onTap: () {
                      _hex.text = hex;
                      _change(draft.copyWith(accentColor: hex));
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 200,
              child: TextField(
                controller: _hex,
                textDirection: TextDirection.ltr,
                maxLength: 7,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[#0-9A-Fa-f]'))],
                decoration: InputDecoration(labelText: l10n.rxSettingsHex, errorText: _fieldErrors['accentColor']),
                onChanged: (value) {
                  if (RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(value)) _change(draft.copyWith(accentColor: value.toUpperCase()));
                },
              ),
            ),
            TextField(
              controller: _footer,
              maxLength: 300,
              decoration: InputDecoration(labelText: l10n.rxSettingsFooter, helperText: l10n.rxSettingsFooterHint),
              onChanged: (value) => _change(draft.copyWith(footerText: () => value.trim().isEmpty ? null : value)),
            ),
          ],
        ),
      ),
      gap,
      SectionCard(
        title: l10n.rxSettingsPrintGroup,
        icon: Icons.print_outlined,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.rxSettingsLanguage, style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'ar', label: Text(l10n.rxSettingsArabic)),
                ButtonSegment(value: 'en', label: Text(l10n.rxSettingsEnglish)),
              ],
              selected: {draft.language},
              onSelectionChanged: (value) => _change(draft.copyWith(language: value.first)),
            ),
            const SizedBox(height: 20),
            Text(l10n.rxSettingsPaper, style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<RxPaperSize>(
              segments: [
                ButtonSegment(value: RxPaperSize.a5, label: Text(l10n.rxPaperA5)),
                ButtonSegment(value: RxPaperSize.a4, label: Text(l10n.rxPaperA4)),
                ButtonSegment(value: RxPaperSize.custom, label: Text(l10n.rxPaperCustom)),
              ],
              selected: {draft.paperSize},
              onSelectionChanged: (value) => _change(draft.copyWith(
                paperSize: value.first,
                customWidthMm: () => value.first == RxPaperSize.custom ? (_number(_width) ?? 148) : null,
                customHeightMm: () => value.first == RxPaperSize.custom ? (_number(_height) ?? 210) : null,
              )),
            ),
            if (draft.paperSize == RxPaperSize.custom) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _width,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: l10n.rxPaperWidth,
                        suffixText: l10n.rxMm,
                        errorText: _fieldErrors['customWidthMm'],
                      ),
                      onChanged: (_) => _change(draft.copyWith(customWidthMm: () => _number(_width))),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _height,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: l10n.rxPaperHeight,
                        suffixText: l10n.rxMm,
                        errorText: _fieldErrors['customHeightMm'],
                      ),
                      onChanged: (_) => _change(draft.copyWith(customHeightMm: () => _number(_height))),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.rxPreprinted),
              subtitle: Text(l10n.rxPreprintedHint),
              value: draft.preprinted,
              onChanged: (value) => _change(draft.copyWith(preprinted: value)),
            ),
            if (draft.preprinted)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _top,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: l10n.rxMarginTop,
                        suffixText: l10n.rxMm,
                        errorText: _fieldErrors['marginTopMm'],
                      ),
                      onChanged: (_) => _change(draft.copyWith(marginTopMm: () => _number(_top))),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _bottom,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: l10n.rxMarginBottom,
                        suffixText: l10n.rxMm,
                        errorText: _fieldErrors['marginBottomMm'],
                      ),
                      onChanged: (_) => _change(draft.copyWith(marginBottomMm: () => _number(_bottom))),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    ];
  }

  Widget _previewCard(BuildContext context, {required bool wide}) {
    final l10n = AppLocalizations.of(context);
    final view = ref.watch(rxPdfViewProvider);
    return SectionCard(
      title: l10n.rxSettingsPreview,
      icon: Icons.visibility_outlined,
      trailing: TextButton.icon(
        onPressed: _preview == null ? null : _testPrint,
        icon: const Icon(Icons.print_outlined),
        label: Text(l10n.rxTestPrint),
      ),
      child: SizedBox(
        height: wide ? 600 : 460,
        child: _previewFailed
            ? Center(child: Text(l10n.rxPreviewFailed))
            : _preview == null
                ? const SkeletonLoading(loading: true, child: SizedBox.expand())
                : ClipRRect(borderRadius: BorderRadius.circular(12), child: view(_preview!, maxPageWidth: 380)),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.hex, required this.selected, required this.onTap});

  final String hex;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // The prescription's own colours (data, printed on paper), not theme colours.
    final color = Color(0xFF000000 | int.parse(hex.substring(1), radix: 16));
    return Semantics(
      button: true,
      selected: selected,
      label: hex,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: selected ? scheme.onSurface : scheme.outlineVariant, width: selected ? 3 : 1),
          ),
          child: selected ? Icon(Icons.check, color: scheme.surface, size: 20) : null,
        ),
      ),
    );
  }
}

class _ImageTile extends ConsumerWidget {
  const _ImageTile({required this.kind, required this.present, required this.busy, required this.onPick, required this.onRemove});

  final RxImageKind kind;
  final bool present;
  final bool busy;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final image = present ? ref.watch(rxImageProvider(kind)).value : null;
    return SizedBox(
      width: 220,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(kind == RxImageKind.logo ? l10n.rxLogo : l10n.rxSignature, style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Container(
            height: 96,
            width: double.infinity,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              // The image sits on paper colour, as it prints.
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: busy
                ? const CircularProgressIndicator()
                : image != null
                    ? Padding(padding: const EdgeInsets.all(8), child: Image.memory(image, fit: BoxFit.contain))
                    : Icon(kind == RxImageKind.logo ? Icons.image_outlined : Icons.draw_outlined, color: scheme.outline),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            children: [
              TextButton.icon(
                onPressed: busy ? null : onPick,
                icon: const Icon(Icons.upload_outlined),
                label: Text(present ? l10n.rxReplaceImage : l10n.rxUploadImage),
              ),
              if (present) TextButton(onPressed: busy ? null : onRemove, child: Text(l10n.rxRemoveImage)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shrinks an image to at most [maxEdge] px on its long edge and returns a
/// PNG (transparency kept for signatures). Smaller uploads, same result: the
/// server stores at most 1000 px too.
Future<Uint8List> shrinkImage(Uint8List bytes, {int maxEdge = 1000}) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  final descriptor = await ui.ImageDescriptor.encoded(buffer);
  final longest = descriptor.width > descriptor.height ? descriptor.width : descriptor.height;
  final scale = longest > maxEdge ? maxEdge / longest : 1.0;
  final codec = await descriptor.instantiateCodec(
    targetWidth: (descriptor.width * scale).round(),
    targetHeight: (descriptor.height * scale).round(),
  );
  final frame = await codec.getNextFrame();
  final png = await frame.image.toByteData(format: ui.ImageByteFormat.png);
  frame.image.dispose();
  codec.dispose();
  descriptor.dispose();
  buffer.dispose();
  if (png == null) throw StateError('The image could not be encoded.');
  return png.buffer.asUint8List();
}
