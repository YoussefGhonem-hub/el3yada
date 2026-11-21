import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/app_format.dart';
import '../../../core/network/api_error_text.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/shake_on_error.dart';
import '../../../core/widgets/skeleton_loading.dart';
import '../../../core/widgets/state_switcher.dart';
import '../../../core/widgets/submit_button.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../clinic/domain/clinic_permissions.dart';
import '../../patients/clinic_paths.dart';
import '../../patients/presentation/widgets/clinic_ui.dart';
import '../application/billing_providers.dart';
import '../application/screenshot_picker.dart';
import '../data/billing_repository.dart';
import '../domain/billing_models.dart';
import 'billing_widgets.dart';

/// D20: submit a payment (`billingPay`). The InstaPay box (address, account
/// name and the exact amount, each with a copy button) and the admin's
/// instructions, then the form: 1 to 3 screenshots (required), the amount
/// (pre-filled), the transfer date, an optional reference, sender and note.
class SubmitPaymentScreen extends ConsumerWidget {
  const SubmitPaymentScreen({super.key, required this.invoiceId});

  final String invoiceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paths = ref.watch(clinicPathsProvider);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: ClinicGate(
        builder: (context, clinic) {
          if (!clinic.can(ClinicPermission.billingPay)) {
            return const AdminErrorView(
              error: ApiException(
                kind: ApiErrorKind.http,
                status: 403,
                code: ApiCodes.permissionDenied,
              ),
            );
          }
          final detail = ref.watch(invoiceDetailProvider(invoiceId));
          return LayoutBuilder(
            builder: (context, constraints) {
              final gutter = clinicGutter(constraints.maxWidth);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 12),
                    child: ClinicHeader(
                      title: l10n.billPayTitle,
                      subtitle: detail.value == null
                          ? null
                          : l10n.billInvoiceOfMonth(
                              invoiceMonthLabel(context, detail.value!.invoice),
                            ),
                      backFallback: paths.invoice(invoiceId),
                    ),
                  ),
                  Expanded(
                    child: AsyncStateSwitcher<InvoiceDetail>(
                      value: detail,
                      loading: (context) => const SkeletonLoading(
                        loading: true,
                        child: SizedBox(height: 320),
                      ),
                      error: (context, error) => AdminErrorView(
                        error: error,
                        onRetry: () =>
                            ref.invalidate(invoiceDetailProvider(invoiceId)),
                      ),
                      data: (context, data) => data.invoice.canPay
                          ? _PayForm(
                              detail: data,
                              gutter: gutter,
                              wide: constraints.maxWidth >= 840,
                            )
                          : Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  l10n.billErrorNotPayable,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _PayForm extends ConsumerStatefulWidget {
  const _PayForm({
    required this.detail,
    required this.gutter,
    required this.wide,
  });

  final InvoiceDetail detail;
  final double gutter;
  final bool wide;

  @override
  ConsumerState<_PayForm> createState() => _PayFormState();
}

class _PayFormState extends ConsumerState<_PayForm> {
  static const _maxShots = 3;

  final _formKey = GlobalKey<FormState>();
  int _shakes = 0;
  late final TextEditingController _amount = TextEditingController(
    text: AppFormat.egpNumber(widget.detail.invoice.totalDuePiasters),
  );
  final _reference = TextEditingController();
  final _sender = TextEditingController();
  final _note = TextEditingController();
  late DateTime _date = ClinicFormat.today();
  final List<ScreenshotFile> _shots = [];
  bool _shotsMissing = false;
  SubmitStatus _status = SubmitStatus.idle;
  Object? _error;

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    _sender.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final room = _maxShots - _shots.length;
    if (room <= 0) return;
    final picked = await ref.read(screenshotPickerProvider).pick(max: room);
    if (picked.isEmpty) return;
    setState(() {
      _shots.addAll(picked.take(room));
      _shotsMissing = false;
    });
  }

  Future<void> _pickDate() async {
    final today = ClinicFormat.today();
    final chosen = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: today.subtract(const Duration(days: 120)),
      lastDate: today,
    );
    if (chosen != null)
      setState(
        () => _date = DateTime.utc(chosen.year, chosen.month, chosen.day),
      );
  }

  Future<void> _submit() async {
    final valid = _formKey.currentState!.validate();
    setState(() => _shotsMissing = _shots.isEmpty);
    if (!valid || _shots.isEmpty) {
      setState(() => _shakes++);
      return;
    }
    setState(() {
      _status = SubmitStatus.loading;
      _error = null;
    });
    try {
      await ref
          .read(billingRepositoryProvider)
          .submitPayment(
            widget.detail.invoice.id,
            PaymentDraft(
              amountPiasters: AppFormat.parseEgp(_amount.text)!,
              transferDate: _date,
              reference: _text(_reference),
              senderName: _text(_sender),
              note: _text(_note),
              screenshots: List.of(_shots),
            ),
          );
      if (!mounted) return;
      setState(() => _status = SubmitStatus.success);
      // Leave first: refreshing the detail would swap this form for the
      // "can't be paid" message and unmount it before the redirect.
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      showAdminSnack(context, AppLocalizations.of(context).billSubmittedSnack);
      final container = ProviderScope.containerOf(context);
      context.go(
        ref.read(clinicPathsProvider).invoice(widget.detail.invoice.id),
      );
      refreshBillingIn(container);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _status = SubmitStatus.idle;
        _error = error;
      });
      setState(() => _shakes++);
      // The status changed meanwhile (an admin acted, or another device paid): show it.
      if (error.code == BillingCodes.invoiceNotPayable) refreshBilling(ref);
    }
  }

  String? _text(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final info = ref.watch(paymentInfoProvider);
    final side = widget.wide ? widget.gutter + 120 : widget.gutter;

    final instapay = SectionCard(
      title: l10n.billInstapayTitle,
      icon: Icons.account_balance_wallet_outlined,
      child: info.when(
        loading: () => const SizedBox(
          height: 96,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) => AdminErrorView(
          error: error,
          onRetry: () => ref.invalidate(paymentInfoProvider),
        ),
        data: (data) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (data.instapayAddress != null)
              _CopyRow(
                label: l10n.billInstapayAddress,
                value: data.instapayAddress!,
              ),
            if (data.instapayAccountName != null)
              _CopyRow(
                label: l10n.billInstapayAccount,
                value: data.instapayAccountName!,
              ),
            _CopyRow(
              label: l10n.billInstapayAmount,
              value: AppFormat.egpNumber(
                widget.detail.invoice.totalDuePiasters,
              ),
              display: AppFormat.egp(
                context,
                widget.detail.invoice.totalDuePiasters,
              ),
            ),
            if (data.instructions(language) != null) ...[
              const SizedBox(height: 8),
              Text(
                data.instructions(language)!,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );

    final form = Form(
      key: _formKey,
      child: SectionCard(
        title: l10n.billPaymentDetails,
        icon: Icons.edit_note,
        child: ShakeOnError(
          trigger: _shakes,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ScreenshotsField(
                shots: _shots,
                missing: _shotsMissing,
                onAdd: _shots.length >= _maxShots ? null : _pick,
                onRemove: (index) => setState(() => _shots.removeAt(index)),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.next,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: l10n.billAmountTransferred,
                  suffixText: l10n.billEgpUnit,
                ),
                validator: (value) {
                  final parsed = AppFormat.parseEgp(value ?? '');
                  if (parsed == null || parsed < 1) return l10n.billErrorAmount;
                  return null;
                },
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: l10n.billTransferDate,
                    suffixIcon: const Icon(
                      Icons.calendar_today_outlined,
                      size: 20,
                    ),
                  ),
                  child: Text(ClinicFormat.day(context, _date)),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _reference,
                textDirection: TextDirection.ltr,
                maxLength: 100,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: l10n.billReferenceOptional,
                  counterText: '',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _sender,
                maxLength: 60,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: l10n.billSenderOptional,
                  counterText: '',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _note,
                maxLength: 500,
                maxLines: 3,
                inputFormatters: [LengthLimitingTextInputFormatter(500)],
                decoration: InputDecoration(
                  labelText: l10n.billNoteOptional,
                  counterText: '',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    l10n.apiError(_error!),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SubmitButton(
                label: l10n.billSubmitPayment,
                status: _status,
                onPressed: _status == SubmitStatus.idle ? _submit : null,
              ),
            ],
          ),
        ),
      ),
    );

    return ListView(
      padding: EdgeInsets.fromLTRB(side, 0, side, 32),
      children: [
        if (widget.wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: instapay),
              const SizedBox(width: 20),
              Expanded(child: form),
            ],
          )
        else ...[
          instapay,
          const SizedBox(height: 16),
          form,
        ],
      ],
    );
  }
}

/// A value with a copy button (D20's InstaPay box).
class _CopyRow extends StatelessWidget {
  const _CopyRow({required this.label, required this.value, this.display});

  final String label;
  final String value;

  /// What is shown, when it differs from what is copied («300 ج.م» vs `300`).
  final String? display;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                LtrText(display ?? value, style: theme.textTheme.titleMedium),
              ],
            ),
          ),
          IconButton(
            tooltip: l10n.billCopy,
            icon: const Icon(Icons.copy_outlined),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: value));
              if (context.mounted) showAdminSnack(context, l10n.billCopied);
            },
          ),
        ],
      ),
    );
  }
}

/// 1 to 3 screenshots: thumbnails with a remove button, and Add.
class _ScreenshotsField extends StatelessWidget {
  const _ScreenshotsField({
    required this.shots,
    required this.missing,
    required this.onAdd,
    required this.onRemove,
  });

  final List<ScreenshotFile> shots;
  final bool missing;
  final VoidCallback? onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.billScreenshots, style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          l10n.billScreenshotsHint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final (i, shot) in shots.indexed)
              Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      shot.bytes,
                      width: 88,
                      height: 88,
                      fit: BoxFit.cover,
                      semanticLabel: l10n.billScreenshotN(i + 1),
                    ),
                  ),
                  PositionedDirectional(
                    top: -8,
                    end: -8,
                    child: IconButton.filledTonal(
                      visualDensity: VisualDensity.compact,
                      iconSize: 16,
                      tooltip: l10n.billRemoveScreenshot,
                      onPressed: () => onRemove(i),
                      icon: const Icon(Icons.close),
                    ),
                  ),
                ],
              ),
            if (onAdd != null)
              OutlinedButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text(l10n.billAddScreenshot),
              ),
          ],
        ),
        if (missing) ...[
          const SizedBox(height: 6),
          Semantics(
            liveRegion: true,
            child: Text(
              l10n.billErrorScreenshotRequired,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
