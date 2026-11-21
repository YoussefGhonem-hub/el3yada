import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/app_format.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/skeleton_loading.dart';
import '../../../core/widgets/state_switcher.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../admin/presentation/widgets/admin_widgets.dart';
import '../../billing/presentation/billing_widgets.dart';
import '../../patients/presentation/widgets/clinic_ui.dart' show ClinicFormat;
import '../application/admin_billing_providers.dart';
import '../data/admin_billing_repository.dart';
import '../domain/admin_billing_models.dart';
import 'admin_billing_widgets.dart';
import 'paged_list.dart';

/// AD7: the payments waiting for review, oldest first: doctor, month, the
/// invoice total, the amount entered with a mismatch flag, and when it came.
class PaymentQueueScreen extends ConsumerWidget {
  const PaymentQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final state = ref.watch(paymentQueueProvider);
    final controller = ref.read(paymentQueueProvider.notifier);
    return LayoutBuilder(
      builder: (context, constraints) {
        final gutter = adminGutter(constraints.maxWidth);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 12),
              child: AdminHeader(
                title: l10n.abPaymentsTitle,
                subtitle: l10n.abPaymentsSubtitle(state.totalCount),
              ),
            ),
            Expanded(
              child: PagedGroupedList<PaymentQueueItem>(
                state: state,
                padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 32),
                onLoadMore: controller.loadMore,
                onRefresh: controller.refresh,
                onRetry: controller.reload,
                empty: (context) => EmptyState(
                  title: l10n.abPaymentsEmptyTitle,
                  message: l10n.abPaymentsEmptyBody,
                ),
                skeletonRow: const _QueueRowSkeleton(),
                itemBuilder: (context, item) =>
                    _QueueRow(item: item, language: language),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _QueueRowSkeleton extends StatelessWidget {
  const _QueueRowSkeleton();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    child: Row(
      children: [
        Expanded(child: Text('████████████  ████')),
        Text('██████'),
      ],
    ),
  );
}

class _QueueRow extends StatelessWidget {
  const _QueueRow({required this.item, required this.language});

  final PaymentQueueItem item;
  final String language;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => context.go('/admin/payments/${item.paymentId}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            InitialAvatar(name: item.doctor(language)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.doctor(language),
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${l10n.abInvoiceOf(ClinicFormat.month(context, item.month))} · ${AppFormat.relative(context, item.submittedAt)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 124),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  LtrText(
                    AppFormat.egp(context, item.amountPiasters),
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  if (item.mismatch)
                    StatusPill(
                      label: l10n.abAmountMismatch,
                      tone: PillTone.danger,
                      icon: Icons.warning_amber_rounded,
                    )
                  else
                    LtrText(
                      l10n.abInvoiceTotalShort(
                        AppFormat.egp(context, item.invoiceTotalPiasters),
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

// ---- AD8 -------------------------------------------------------------------------------------

/// AD8: the screenshots (tap to zoom), the doctor's entries next to the
/// invoice summary with the mismatch highlighted, the earlier attempts, and
/// **Approve** / **Reject** (preset reasons or free text).
class PaymentReviewScreen extends ConsumerStatefulWidget {
  const PaymentReviewScreen({super.key, required this.paymentId});

  final String paymentId;

  @override
  ConsumerState<PaymentReviewScreen> createState() =>
      _PaymentReviewScreenState();
}

class _PaymentReviewScreenState extends ConsumerState<PaymentReviewScreen> {
  bool _busy = false;

  Future<Uint8List> _load(String paymentId, int number) =>
      ref.read(adminBillingRepositoryProvider).screenshot(paymentId, number);

  Future<void> _approve(PaymentReview review) async {
    final l10n = AppLocalizations.of(context);
    final ok = await confirmAction(
      context,
      title: l10n.abApproveTitle,
      message: l10n.abApproveBody(
        AppFormat.egp(context, review.payment.amountPiasters),
        review.doctor.displayName(Localizations.localeOf(context).languageCode),
      ),
      confirmLabel: l10n.abApprove,
    );
    if (!ok || !mounted) return;
    await _run(
      () => ref
          .read(adminBillingRepositoryProvider)
          .approvePayment(widget.paymentId),
      l10n.abApprovedSnack,
    );
  }

  Future<void> _reject() async {
    final l10n = AppLocalizations.of(context);
    final reason = await askReason(
      context,
      title: l10n.abRejectTitle,
      message: l10n.abRejectBody,
      confirmLabel: l10n.abReject,
      presets: rejectionPresets(l10n),
      destructive: true,
    );
    if (reason == null || !mounted) return;
    await _run(
      () => ref
          .read(adminBillingRepositoryProvider)
          .rejectPayment(widget.paymentId, reason),
      l10n.abRejectedSnack,
    );
  }

  Future<void> _run(Future<Object?> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      ref.invalidate(paymentQueueProvider);
      ref.invalidate(adminDashboardProvider);
      ref.invalidate(paymentReviewProvider(widget.paymentId));
      showAdminSnack(context, done);
      context.go('/admin/payments');
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      showActionError(context, error);
      // Reviewed by another admin meanwhile: show how it ended.
      ref.invalidate(paymentReviewProvider(widget.paymentId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final review = ref.watch(paymentReviewProvider(widget.paymentId));
    return LayoutBuilder(
      builder: (context, constraints) {
        final gutter = adminGutter(constraints.maxWidth);
        final wide = constraints.maxWidth >= kAdminWideLayout;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 12),
              child: AdminHeader(
                title: l10n.abReviewTitle,
                subtitle: review.value == null
                    ? null
                    : review.value!.doctor.displayName(language),
                leading: const AdminBackButton(fallback: '/admin/payments'),
              ),
            ),
            Expanded(
              child: AsyncStateSwitcher<PaymentReview>(
                value: review,
                loading: (context) => const SkeletonLoading(
                  loading: true,
                  child: SizedBox(height: 360),
                ),
                error: (context, error) => AdminErrorView(
                  error: error,
                  onRetry: () =>
                      ref.invalidate(paymentReviewProvider(widget.paymentId)),
                ),
                data: (context, data) {
                  final pending =
                      data.payment.status == PaymentStatus.pendingReview;
                  final screenshots = _Screenshots(
                    payment: data.payment,
                    load: _load,
                  );
                  final entries = _Entries(review: data);
                  return Stack(
                    children: [
                      ListView(
                        padding: EdgeInsets.fromLTRB(
                          gutter,
                          0,
                          gutter,
                          pending ? 112 : 32,
                        ),
                        children: [
                          if (!pending) ...[
                            _ReviewedNotice(payment: data.payment),
                            const SizedBox(height: 16),
                          ],
                          if (wide)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 6, child: screenshots),
                                const SizedBox(width: 20),
                                Expanded(flex: 5, child: entries),
                              ],
                            )
                          else ...[
                            screenshots,
                            const SizedBox(height: 16),
                            entries,
                          ],
                          if (data.earlierAttempts.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            SectionCard(
                              title: l10n.abEarlierAttempts,
                              icon: Icons.history,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  for (final (i, attempt)
                                      in data.earlierAttempts.indexed) ...[
                                    if (i > 0) const Divider(height: 24),
                                    PaymentCard(
                                      payment: attempt,
                                      loadScreenshot: _load,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (pending)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: _ReviewBar(
                            busy: _busy,
                            onApprove: () => _approve(data),
                            onReject: _reject,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ReviewedNotice extends StatelessWidget {
  const _ReviewedNotice({required this.payment});

  final PaymentLine payment;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final approved = payment.status == PaymentStatus.approved;
    return StatusPill(
      label: approved
          ? l10n.abAlreadyApproved
          : l10n.abAlreadyRejected(payment.rejectionReason ?? ''),
      tone: approved ? PillTone.positive : PillTone.danger,
    );
  }
}

class _ReviewBar extends StatelessWidget {
  const _ReviewBar({
    required this.busy,
    required this.onApprove,
    required this.onReject,
  });

  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: busy ? null : onReject,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: scheme.error,
                        side: BorderSide(color: scheme.error),
                      ),
                      icon: const Icon(Icons.close),
                      label: Text(l10n.abReject),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: busy ? null : onApprove,
                      icon: const Icon(Icons.check),
                      label: Text(l10n.abApprove),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The screenshot viewer: the chosen image large (pinch to zoom) and a strip of numbers.
class _Screenshots extends StatefulWidget {
  const _Screenshots({required this.payment, required this.load});

  final PaymentLine payment;
  final Future<Uint8List> Function(String paymentId, int number) load;

  @override
  State<_Screenshots> createState() => _ScreenshotsState();
}

class _ScreenshotsState extends State<_Screenshots> {
  int _current = 1;
  late Future<Uint8List> _image = widget.load(widget.payment.id, _current);

  void _select(int number) => setState(() {
    _current = number;
    _image = widget.load(widget.payment.id, number);
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return SectionCard(
      title: l10n.abScreenshots,
      icon: Icons.image_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: ColoredBox(
              color: Colors.black,
              child: SizedBox(
                height: 360,
                child: FutureBuilder<Uint8List>(
                  future: _image,
                  builder: (context, snapshot) {
                    if (snapshot.hasError)
                      return Center(
                        child: AdminErrorView(
                          error: snapshot.error!,
                          onRetry: () => _select(_current),
                        ),
                      );
                    if (!snapshot.hasData)
                      return const Center(child: CircularProgressIndicator());
                    return InteractiveViewer(
                      maxScale: 6,
                      child: Image.memory(snapshot.data!, fit: BoxFit.contain),
                    );
                  },
                ),
              ),
            ),
          ),
          if (widget.payment.screenshots > 1) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                for (var n = 1; n <= widget.payment.screenshots; n++)
                  ChoiceChip(
                    label: Text(l10n.billScreenshotN(n)),
                    selected: n == _current,
                    onSelected: (_) => _select(n),
                  ),
              ],
            ),
          ],
          if (widget.payment.screenshots == 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                l10n.abNoScreenshots,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }
}

/// The doctor's entries next to the invoice summary, with the mismatch highlighted.
class _Entries extends StatelessWidget {
  const _Entries({required this.review});

  final PaymentReview review;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final theme = Theme.of(context);
    final payment = review.payment;
    final invoice = review.invoice;
    final entered = LtrText(
      AppFormat.egp(context, payment.amountPiasters),
      style: theme.textTheme.titleLarge?.copyWith(
        color: review.mismatch ? theme.colorScheme.error : null,
        fontWeight: FontWeight.w700,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          title: l10n.abInvoiceSummary,
          icon: Icons.receipt_long_outlined,
          trailing: InvoiceStatusPill(invoice.status),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InfoRow(
                label: l10n.abDoctor,
                value: review.doctor.displayName(language),
              ),
              const SizedBox(height: 12),
              InfoRow(
                label: l10n.abMonth,
                value: ClinicFormat.month(context, invoice.month),
              ),
              const SizedBox(height: 12),
              InfoRow(
                label: l10n.billTotalDue,
                value: AppFormat.egp(context, invoice.totalDuePiasters),
                ltr: true,
              ),
              const SizedBox(height: 12),
              InfoRow(
                label: l10n.abDueDate,
                value: ClinicFormat.day(context, invoice.dueDate),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: l10n.abDoctorEntries,
          icon: Icons.edit_note,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InfoRow(label: l10n.billAmountTransferred, child: entered),
              if (review.mismatch) ...[
                const SizedBox(height: 8),
                Semantics(
                  liveRegion: true,
                  child: StatusPill(
                    label: l10n.abMismatchBanner(
                      AppFormat.egp(context, invoice.totalDuePiasters),
                    ),
                    tone: PillTone.danger,
                    icon: Icons.warning_amber_rounded,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              InfoRow(
                label: l10n.billTransferDate,
                value: ClinicFormat.day(context, payment.transferDate),
              ),
              const SizedBox(height: 12),
              InfoRow(
                label: l10n.billReferenceOptional,
                value: payment.reference,
                ltr: true,
              ),
              const SizedBox(height: 12),
              InfoRow(
                label: l10n.billSenderOptional,
                value: payment.senderName,
              ),
              const SizedBox(height: 12),
              InfoRow(label: l10n.billNoteOptional, value: payment.note),
              const SizedBox(height: 12),
              InfoRow(
                label: l10n.abSubmitted,
                value: AppFormat.dateTime(context, payment.submittedAt),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
